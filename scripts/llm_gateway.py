"""Cổng bảo vệ đứng trước server MLX để mở ra Internet (Tailscale Funnel).

mlx_lm.server không có xác thực, nên không được mở thẳng. Cổng này chỉ chuyển tiếp hai đường
`GET /v1/models` và `POST /v1/chat/completions`, bắt buộc `Authorization: Bearer <khóa>`,
giới hạn kích thước yêu cầu và stream kết quả về nguyên vẹn.

Biến môi trường: GATEWAY_KEY (bắt buộc), UPSTREAM (mặc định http://host.docker.internal:8090).
"""

import hmac
import os

import httpx
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse, Response, StreamingResponse

KEY = os.environ.get("GATEWAY_KEY", "")
UPSTREAM = os.environ.get("UPSTREAM", "http://host.docker.internal:8090").rstrip("/")
MAX_BODY = 256 * 1024

app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)


def _check(request: Request) -> None:
    got = request.headers.get("authorization", "")
    if len(KEY) < 24 or not hmac.compare_digest(got, f"Bearer {KEY}"):
        raise HTTPException(401, "Unauthorized")


@app.get("/v1/models")
async def models(request: Request) -> Response:
    _check(request)
    try:
        async with httpx.AsyncClient(timeout=5) as http:
            res = await http.get(f"{UPSTREAM}/v1/models")
    except httpx.HTTPError:
        return JSONResponse({"detail": "upstream down"}, status_code=502)
    return Response(res.content, res.status_code, media_type="application/json")


@app.post("/v1/chat/completions")
async def chat(request: Request) -> Response:
    _check(request)
    body = await request.body()
    if len(body) > MAX_BODY:
        raise HTTPException(413, "Too large")
    client = httpx.AsyncClient(timeout=httpx.Timeout(180, connect=5))
    try:
        req = client.build_request(
            "POST",
            f"{UPSTREAM}/v1/chat/completions",
            content=body,
            headers={"content-type": "application/json"},
        )
        upstream = await client.send(req, stream=True)
    except httpx.HTTPError:
        await client.aclose()
        return JSONResponse({"detail": "upstream down"}, status_code=502)

    async def relay():
        try:
            async for chunk in upstream.aiter_raw():
                yield chunk
        finally:
            await upstream.aclose()
            await client.aclose()

    return StreamingResponse(
        relay(),
        status_code=upstream.status_code,
        media_type=upstream.headers.get("content-type", "application/json"),
        headers={"Cache-Control": "no-cache"},
    )
