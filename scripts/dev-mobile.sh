#!/usr/bin/env bash
# Chạy app trên iOS Simulator và TỰ động hot reload mỗi khi bạn lưu file Dart.
#   make mobile-dev                 # mặc định iPhone 13
#   make mobile-dev DEVICE="iPhone 16 Pro"
# Sửa code Swift (plugin liquid_glass) hoặc file cấu hình cần chạy lại script (hot reload không nạp Swift).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${1:-iPhone 13}"
PORT="$(grep -E '^BACKEND_PORT=' "$ROOT/.env" 2>/dev/null | cut -d= -f2 || true)"
PORT="${PORT:-8000}"
PIDFILE="$(mktemp -t healthtrack-flutter-pid)"
STAMP="$(mktemp -t healthtrack-flutter-stamp)"

open -a Simulator 2>/dev/null || true  # Xcode mới có thể không có app Simulator; máy ảo vẫn hiện trong Device Hub
cd "$ROOT/mobile"

# flutter run đọc phím từ stdin; cho stdin rỗng vì ta gửi tín hiệu thay vì gõ phím
flutter run -d "$DEVICE" --pid-file "$PIDFILE" \
  --dart-define="API_URL=http://localhost:${PORT}/api/v1" < /dev/null &
FLUTTER_PID=$!
trap 'kill "$FLUTTER_PID" 2>/dev/null || true; rm -f "$PIDFILE" "$STAMP"' EXIT INT TERM

echo ">> Theo dõi lib/ và packages/liquid_glass/lib/ ; lưu file .dart là app tự cập nhật."
until [ -s "$PIDFILE" ] || ! kill -0 "$FLUTTER_PID" 2>/dev/null; do sleep 1; done
touch "$STAMP"
while kill -0 "$FLUTTER_PID" 2>/dev/null; do
  sleep 1
  if [ -n "$(find lib packages/liquid_glass/lib -name '*.dart' -newer "$STAMP" -print -quit 2>/dev/null)" ]; then
    touch "$STAMP"
    echo ">> Phát hiện thay đổi, hot reload..."
    kill -USR1 "$(cat "$PIDFILE")" 2>/dev/null || true
  fi
done
