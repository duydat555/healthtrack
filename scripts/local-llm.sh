#!/usr/bin/env bash
# Server AI local trên Mac Apple Silicon bằng MLX (API tương thích OpenAI).
# Dùng: scripts/local-llm.sh setup|start|stop|status|bench
#   LLM_MODEL  model trên Hugging Face (mặc định Qwen3.5 9B 4-bit)
#   LLM_PORT   cổng (mặc định 8090)
#   LLM_HOST   địa chỉ nghe (mặc định 127.0.0.1; Docker Desktop vẫn gọi được qua host.docker.internal)
set -euo pipefail

DIR="${LLM_HOME:-$HOME/.cache/healthtrack-llm}"
VENV="$DIR/venv"
MODEL="${LLM_MODEL:-mlx-community/Qwen3.5-9B-MLX-4bit}"
PORT="${LLM_PORT:-8090}"
HOST="${LLM_HOST:-127.0.0.1}"
PIDFILE="$DIR/server.pid"
LOG="$DIR/server.log"

running() { [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; }

case "${1:-}" in
setup)
  [[ "$(uname -m)" == "arm64" ]] || { echo "Cần Mac Apple Silicon"; exit 1; }
  mkdir -p "$DIR"
  [[ -d "$VENV" ]] || python3 -m venv "$VENV"
  "$VENV/bin/pip" install -q --upgrade mlx-lm
  echo "Đã cài mlx-lm. Chạy: scripts/local-llm.sh start"
  ;;
start)
  [[ -x "$VENV/bin/python" ]] || { echo "Chưa cài đặt, chạy: scripts/local-llm.sh setup"; exit 1; }
  if running; then echo "Server đang chạy (pid $(cat "$PIDFILE"))"; exit 0; fi
  nohup "$VENV/bin/python" -m mlx_lm server --model "$MODEL" --host "$HOST" --port "$PORT" \
    >"$LOG" 2>&1 &
  echo $! >"$PIDFILE"
  echo "Đang khởi động $MODEL ở http://$HOST:$PORT/v1 (lần đầu tải model vài GB, xem $LOG)"
  for _ in $(seq 1 120); do
    curl -sf "http://127.0.0.1:$PORT/v1/models" >/dev/null 2>&1 && { echo "Sẵn sàng"; exit 0; }
    running || { echo "Server thoát, xem $LOG"; exit 1; }
    sleep 5
  done
  echo "Quá thời gian chờ, xem $LOG"; exit 1
  ;;
stop)
  if running; then kill "$(cat "$PIDFILE")" && rm -f "$PIDFILE" && echo "Đã dừng"; else echo "Không chạy"; fi
  ;;
status)
  if running && curl -sf "http://127.0.0.1:$PORT/v1/models" >/dev/null; then
    echo "Đang chạy: $MODEL ở cổng $PORT"
  else
    echo "Không chạy"; exit 1
  fi
  ;;
bench)
  # Đo tốc độ sinh (token/giây) và thời gian tới token đầu của một câu hỏi tiếng Việt
  "$VENV/bin/python" - "$PORT" "$MODEL" <<'PY'
import json, sys, time, urllib.request
port, model = sys.argv[1], sys.argv[2]
body = {"model": model, "max_tokens": 300, "stream": True,
        "chat_template_kwargs": {"enable_thinking": False},
        "messages": [{"role": "user", "content": "Mình ngủ 6 tiếng, uống 1,2 lít nước, đi 5000 bước. Cho mình 3 lời khuyên ngắn."}]}
req = urllib.request.Request(f"http://127.0.0.1:{port}/v1/chat/completions",
                             json.dumps(body).encode(), {"Content-Type": "application/json"})
t0 = time.time(); first = None; n = 0
with urllib.request.urlopen(req) as r:
    for line in r:
        line = line.decode().strip()
        if not line.startswith("data:") or line.endswith("[DONE]"):
            continue
        delta = json.loads(line[5:])["choices"][0].get("delta", {}).get("content")
        if delta:
            first = first or time.time(); n += 1
total = time.time() - t0
print(f"model={model}\nthời gian tới token đầu: {first - t0:.2f}s\nsố mẩu: {n}, tốc độ: {n / (time.time() - first):.1f} mẩu/giây, tổng {total:.1f}s")
PY
  ;;
*)
  echo "Dùng: $0 setup|start|stop|status|bench"; exit 1
  ;;
esac
