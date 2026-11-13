import json
from collections.abc import AsyncGenerator, Iterator
from types import SimpleNamespace
from typing import Any

import pytest
from httpx import AsyncClient

from app.api.v1.coach import coach_limiter, get_coach_client
from app.main import app
from tests.helpers import auth_headers

CHAT = "/api/v1/coach/chat"
WEEKLY = "/api/v1/coach/weekly"


def text_block(text: str) -> SimpleNamespace:
    return SimpleNamespace(type="text", text=text)


def tool_block(tool_id: str, name: str, **args: Any) -> SimpleNamespace:
    return SimpleNamespace(type="tool_use", id=tool_id, name=name, input=args)


def final(stop: str, *blocks: SimpleNamespace) -> SimpleNamespace:
    return SimpleNamespace(stop_reason=stop, content=list(blocks))


class FakeStream:
    def __init__(self, texts: list[str], message: SimpleNamespace, fail: bool) -> None:
        self._texts, self._message, self._fail = texts, message, fail

    async def __aenter__(self) -> "FakeStream":
        return self

    async def __aexit__(self, *exc: object) -> None:
        return None

    @property
    def text_stream(self) -> AsyncGenerator[str, None]:
        async def gen() -> AsyncGenerator[str, None]:
            for t in self._texts:
                yield t
            if self._fail:
                raise RuntimeError("mất kết nối")

        return gen()

    async def get_final_message(self) -> SimpleNamespace:
        return self._message


class FakeClient:
    """Phát lại kịch bản (danh sách (các mẩu text, tin nhắn cuối)) và ghi lại mọi yêu cầu."""

    def __init__(self, script: list[tuple[list[str], SimpleNamespace]], fail: bool = False) -> None:
        self.script = list(script)
        self.calls: list[dict[str, Any]] = []
        self.fail = fail
        self.messages = SimpleNamespace(stream=self._stream, create=self._create)

    def _stream(self, **kwargs: Any) -> FakeStream:
        # Chụp lịch sử tại thời điểm gọi vì vòng lặp sẽ tiếp tục thêm vào cùng một list
        self.calls.append({**kwargs, "messages": list(kwargs["messages"])})
        texts, message = self.script.pop(0)
        return FakeStream(texts, message, self.fail)

    async def _create(self, **kwargs: Any) -> SimpleNamespace:
        self.calls.append(kwargs)
        return self.script.pop(0)[1]


@pytest.fixture(autouse=True)
def no_real_local_llm(monkeypatch: pytest.MonkeyPatch) -> None:
    """Test không được gọi server MLX thật dù .env trên máy có cấu hình."""
    from app.core.config import settings

    monkeypatch.setattr(settings, "LOCAL_LLM_URL", "")


@pytest.fixture
def use_client() -> Iterator[Any]:
    coach_limiter.reset()

    def install(fake: FakeClient) -> FakeClient:
        app.dependency_overrides[get_coach_client] = lambda: fake
        return fake

    yield install
    coach_limiter.reset()


def events(body: str) -> list[dict[str, Any]]:
    return [json.loads(c[len("data: ") :]) for c in body.strip().split("\n\n") if c]


async def ask(client: AsyncClient, h: dict[str, str], text: str = "Chào") -> list[dict[str, Any]]:
    res = await client.post(CHAT, headers=h, json={"messages": [{"role": "user", "content": text}]})
    assert res.status_code == 200, res.text
    assert res.headers["content-type"].startswith("text/event-stream")
    out = events(res.text)
    assert out[0] == {"type": "meta", "provider": "claude"}
    return out[1:]


async def test_requires_auth(client: AsyncClient) -> None:
    assert (await client.post(CHAT, json={})).status_code == 401
    assert (await client.get(WEEKLY)).status_code == 401


async def test_disabled_without_api_key(client: AsyncClient) -> None:
    h = await auth_headers(client)
    res = await client.post(CHAT, headers=h, json={"messages": [{"role": "user", "content": "hi"}]})
    assert res.status_code == 503
    assert (await client.get(WEEKLY, headers=h)).status_code == 503


async def test_plain_answer_is_streamed(client: AsyncClient, use_client: Any) -> None:
    fake = use_client(FakeClient([(["Xin ", "chào!"], final("end_turn", text_block("Xin chào!")))]))
    h = await auth_headers(client)
    out = await ask(client, h)
    assert out == [
        {"type": "text", "text": "Xin "},
        {"type": "text", "text": "chào!"},
        {"type": "done"},
    ]
    call = fake.calls[0]
    assert "không thay thế tư vấn y tế" in call["system"]
    assert {t["name"] for t in call["tools"]} == {"get_stats", "get_goals", "log_entry"}
    assert "temperature" not in call and "tool_choice" not in call


async def test_log_entry_tool_writes_data(client: AsyncClient, use_client: Any) -> None:
    fake = use_client(
        FakeClient(
            [
                ([], final("tool_use", tool_block("t1", "log_entry", metric="water", value=500))),
                (["Đã ghi 500ml."], final("end_turn", text_block("Đã ghi 500ml."))),
            ]
        )
    )
    h = await auth_headers(client)
    out = await ask(client, h, "vừa uống 500ml")
    assert [e["type"] for e in out] == ["tool", "logged", "text", "done"]
    assert out[1]["metric"] == "water"
    logs = (await client.get("/api/v1/water", headers=h)).json()
    assert [w["amount_ml"] for w in logs] == [500]
    result = fake.calls[1]["messages"][-1]["content"][0]
    assert result["tool_use_id"] == "t1" and result["is_error"] is False


async def test_get_stats_tool_returns_user_data(client: AsyncClient, use_client: Any) -> None:
    fake = use_client(
        FakeClient(
            [
                ([], final("tool_use", tool_block("t1", "get_stats", days=3))),
                (["ok"], final("end_turn", text_block("ok"))),
            ]
        )
    )
    h = await auth_headers(client)
    await client.post("/api/v1/water", headers=h, json={"amount_ml": 750})
    await ask(client, h, "tuần này thế nào")
    payload = json.loads(fake.calls[1]["messages"][-1]["content"][0]["content"])
    assert len(payload["days"]) == 3
    assert payload["days"][-1]["water_ml"] == 750


async def test_tools_cannot_read_other_users(client: AsyncClient, use_client: Any) -> None:
    fake = use_client(
        FakeClient(
            [
                ([], final("tool_use", tool_block("t1", "get_stats", days=1))),
                (["ok"], final("end_turn", text_block("ok"))),
            ]
        )
    )
    a = await auth_headers(client, "a@example.com")
    b = await auth_headers(client, "b@example.com")
    await client.post("/api/v1/water", headers=a, json={"amount_ml": 900})
    await ask(client, b)
    payload = json.loads(fake.calls[1]["messages"][-1]["content"][0]["content"])
    assert payload["days"][0]["water_ml"] is None


async def test_invalid_tool_input_is_reported_to_model(
    client: AsyncClient, use_client: Any
) -> None:
    fake = use_client(
        FakeClient(
            [
                ([], final("tool_use", tool_block("t1", "log_entry", metric="water", value=-5))),
                (["Số ml không hợp lệ."], final("end_turn", text_block("x"))),
            ]
        )
    )
    h = await auth_headers(client)
    out = await ask(client, h)
    assert all(e["type"] != "logged" for e in out)
    assert fake.calls[1]["messages"][-1]["content"][0]["is_error"] is True
    assert (await client.get("/api/v1/water", headers=h)).json() == []


async def test_refusal_gets_safe_text(client: AsyncClient, use_client: Any) -> None:
    use_client(FakeClient([([], final("refusal"))]))
    h = await auth_headers(client)
    out = await ask(client, h)
    assert out[0]["type"] == "text" and "không thể giúp" in out[0]["text"]
    assert out[-1] == {"type": "done"}


async def test_upstream_failure_becomes_error_event(client: AsyncClient, use_client: Any) -> None:
    use_client(FakeClient([(["Xin"], final("end_turn"))], fail=True))
    h = await auth_headers(client)
    out = await ask(client, h)
    assert out[-1]["type"] == "error"


async def test_last_message_must_be_from_user(client: AsyncClient, use_client: Any) -> None:
    use_client(FakeClient([]))
    h = await auth_headers(client)
    body = {"messages": [{"role": "assistant", "content": "hi"}]}
    assert (await client.post(CHAT, headers=h, json=body)).status_code == 422


async def test_rate_limit(client: AsyncClient, use_client: Any) -> None:
    use_client(FakeClient([(["a"], final("end_turn")), (["b"], final("end_turn"))]))
    h = await auth_headers(client)
    old = coach_limiter.max_requests
    coach_limiter.max_requests = 1
    try:
        await ask(client, h)
        res = await client.post(
            CHAT, headers=h, json={"messages": [{"role": "user", "content": "lại"}]}
        )
        assert res.status_code == 429 and "Retry-After" in res.headers
    finally:
        coach_limiter.max_requests = old


async def test_weekly_is_generated_once_per_week(client: AsyncClient, use_client: Any) -> None:
    fake = use_client(FakeClient([([], final("end_turn", text_block("Tuần ổn, uống thêm nước.")))]))
    h = await auth_headers(client)
    first = (await client.get(WEEKLY, headers=h)).json()
    second = (await client.get(WEEKLY, headers=h)).json()
    assert first == second
    assert first["content"] == "Tuần ổn, uống thêm nước."
    assert first["model"] == "claude-sonnet-5-5"
    assert len(fake.calls) == 1


# ---- AI local (server MLX) ----


def sse_lines(*chunks: str) -> list[str]:
    lines = [f"data: {json.dumps({'choices': [{'delta': {'content': c}}]})}" for c in chunks]
    return [*lines, "data: [DONE]"]


@pytest.fixture
def local_llm(monkeypatch: pytest.MonkeyPatch) -> Any:
    from app.services import coach_local

    state: dict[str, Any] = {"up": True, "bodies": [], "lines": []}

    async def available() -> bool:
        return state["up"]

    async def lines(body: dict[str, Any]) -> AsyncGenerator[str, None]:
        state["bodies"].append(body)
        for line in state["lines"]:
            yield line

    monkeypatch.setattr(coach_local, "is_available", available)
    monkeypatch.setattr(coach_local, "_lines", lines)
    return state


async def test_providers_endpoint(client: AsyncClient, use_client: Any, local_llm: Any) -> None:
    use_client(FakeClient([]))
    h = await auth_headers(client)
    url = "/api/v1/coach/providers"
    assert (await client.get(url, headers=h)).json() == {
        "claude": True,
        "local": True,
        "default": "local",
    }
    local_llm["up"] = False
    assert (await client.get(url, headers=h)).json()["default"] == "claude"


async def test_auto_prefers_local_and_sends_summary(
    client: AsyncClient, use_client: Any, local_llm: Any
) -> None:
    fake = use_client(FakeClient([]))
    local_llm["lines"] = sse_lines("<think>nghĩ", " xong</think>Chào ", "bạn")
    h = await auth_headers(client)
    await client.post("/api/v1/water", headers=h, json={"amount_ml": 750})
    res = await client.post(CHAT, headers=h, json={"messages": [{"role": "user", "content": "hi"}]})
    out = events(res.text)
    assert out[0] == {"type": "meta", "provider": "local"}
    assert "".join(e.get("text", "") for e in out) == "Chào bạn"
    assert out[-1] == {"type": "done"}
    assert fake.calls == []  # không gọi Claude
    body = local_llm["bodies"][0]
    assert body["messages"][0]["role"] == "system"
    assert '"water_ml": 750' in body["messages"][0]["content"]  # số liệu đã tóm tắt sẵn
    assert body["chat_template_kwargs"] == {"enable_thinking": False}


async def test_auto_falls_back_to_claude_when_local_down(
    client: AsyncClient, use_client: Any, local_llm: Any
) -> None:
    use_client(FakeClient([(["ok"], final("end_turn", text_block("ok")))]))
    local_llm["up"] = False
    h = await auth_headers(client)
    out = await ask(client, h)  # ask() kiểm tra meta là claude
    assert out[0] == {"type": "text", "text": "ok"}


async def test_explicit_local_when_down_is_503(
    client: AsyncClient, use_client: Any, local_llm: Any
) -> None:
    use_client(FakeClient([]))
    local_llm["up"] = False
    h = await auth_headers(client)
    body = {"messages": [{"role": "user", "content": "hi"}], "provider": "local"}
    res = await client.post(CHAT, headers=h, json=body)
    assert res.status_code == 503 and "local" in res.json()["detail"]


async def test_explicit_claude_ignores_local(
    client: AsyncClient, use_client: Any, local_llm: Any
) -> None:
    use_client(FakeClient([(["ok"], final("end_turn", text_block("ok")))]))
    h = await auth_headers(client)
    body = {"messages": [{"role": "user", "content": "hi"}], "provider": "claude"}
    out = events((await client.post(CHAT, headers=h, json=body)).text)
    assert out[0] == {"type": "meta", "provider": "claude"}
    assert local_llm["bodies"] == []


def test_think_filter_handles_split_tags() -> None:
    from app.services.coach_local import _ThinkFilter

    f = _ThinkFilter()
    parts = ["Xin <th", "ink>bí mật</th", "ink>\nChào", " bạn"]
    assert "".join(f.feed(p) for p in parts) + f.flush() == "Xin Chào bạn"


async def test_weekly_works_with_local_only(
    client: AsyncClient, use_client: Any, local_llm: Any
) -> None:
    use_client(None)  # không có khóa Claude
    local_llm["lines"] = sse_lines("<think>x</think>Tuần ", "tốt.")
    h = await auth_headers(client)
    first = (await client.get(WEEKLY, headers=h)).json()
    second = (await client.get(WEEKLY, headers=h)).json()
    assert first == second
    assert first["content"] == "Tuần tốt."
    assert first["model"] == "Qwen3.5-9B-MLX-4bit"
    assert len(local_llm["bodies"]) == 1
