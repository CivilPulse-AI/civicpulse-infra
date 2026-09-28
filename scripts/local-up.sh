#!/usr/bin/env bash
# Start the four backends and the institution portal on this machine.
# No Docker. CockroachDB and Upstash still come from .env.
set -euo pipefail

INFRA="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$INFRA/.." && pwd)"
RUN="$INFRA/.local"
mkdir -p "$RUN/logs"

if [[ -f "$RUN/pids" ]]; then
  echo "Local stack already has a pid file. Run: make local-down" >&2
  exit 1
fi

if [[ ! -f "$INFRA/.env" ]]; then
  echo "Missing $INFRA/.env" >&2
  exit 1
fi

python3 - "$INFRA/.env" "$INFRA/ca.pem" "$RUN/env" << 'PY'
import shlex
import sys
from pathlib import Path

src, ca_path, dest = sys.argv[1:]
lines = Path(src).read_text().splitlines()
pairs = []
i = 0
while i < len(lines):
    line = lines[i]
    if not line.strip() or line.strip().startswith("#") or "=" not in line:
        i += 1
        continue
    key, value = line.split("=", 1)
    key = key.strip()
    if value.startswith('"') and not (len(value) > 1 and value.endswith('"')):
        i += 1
        while i < len(lines) and not lines[i].rstrip().endswith('"'):
            i += 1
        value = ""
    elif len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        value = value[1:-1]
    pairs.append((key, value))
    i += 1

overrides = {
    "TELEPHONY_PUBLIC_WS_URL": "ws://127.0.0.1:8002",
    "TELEPHONY_INTERNAL_URL": "http://127.0.0.1:8002",
    "AI_GRPC_ADDR": "127.0.0.1:50051",
    "CORE_GRPC_ADDR": "127.0.0.1:9090",
    "CORE_HTTP_URL": "http://127.0.0.1:8080",
    "HTTP_PORT": "8080",
}
if Path(ca_path).is_file():
    overrides["DATABASE_CA_CERT"] = ""
    overrides["DATABASE_CA_CERT_PATH"] = str(Path(ca_path).resolve())

seen = set()
out = []
for key, value in pairs:
    if key in overrides:
        value = overrides[key]
        seen.add(key)
    out.append(f"export {key}={shlex.quote(value)}")
for key, value in overrides.items():
    if key not in seen:
        out.append(f"export {key}={shlex.quote(value)}")
Path(dest).write_text("\n".join(out) + "\n")
Path(dest).chmod(0o600)
PY

set -a
# shellcheck disable=SC1091
source "$RUN/env"
set +a

if command -v fvm >/dev/null 2>&1; then
  FLUTTER=(fvm flutter)
elif command -v flutter >/dev/null 2>&1; then
  FLUTTER=(flutter)
else
  echo "flutter or fvm is not on PATH" >&2
  exit 1
fi

py_for() {
  local dir="$1"
  if [[ -x "$dir/.venv/bin/python" ]]; then
    echo "$dir/.venv/bin/python"
  else
    echo python3
  fi
}

launch() {
  local name="$1" dir="$2"
  shift 2
  python3 - "$dir" "$RUN/logs/$name.log" "$@" << 'PY' &
import os, sys
directory, log, *cmd = sys.argv[1:]
os.setsid()
os.chdir(directory)
fd = os.open(log, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o644)
os.dup2(fd, 1)
os.dup2(fd, 2)
os.execvp(cmd[0], cmd)
PY
  echo $! >>"$RUN/pids"
  echo "started $name (pid $!, log .local/logs/$name.log)"
}

AI_DIR="$ROOT/civicpulse-ai-service"
TEL_DIR="$ROOT/civicpulse-telephony-service"
AI_PY="$(py_for "$AI_DIR")"
TEL_PY="$(py_for "$TEL_DIR")"

launch ai "$AI_DIR" env PYTHONPATH="$AI_DIR:$AI_DIR/app/pb" "$AI_PY" -m uvicorn app.main:app --host 127.0.0.1 --port 8001
launch server "$ROOT/civicpulse-server" go run ./cmd/api
launch telephony "$TEL_DIR" env PYTHONPATH="$TEL_DIR:$TEL_DIR/app/pb" "$TEL_PY" -m uvicorn app.main:app --host 127.0.0.1 --port 8002
launch notifications "$ROOT/civicpulse-notification-service" go run ./cmd/worker

echo "waiting for http://127.0.0.1:8080/health"
ready=0
for _ in $(seq 1 60); do
  if curl -sf -m 2 http://127.0.0.1:8080/health >/dev/null; then
    ready=1
    break
  fi
  sleep 1
done
if [[ "$ready" != 1 ]]; then
  echo "API did not become healthy. See .local/logs/server.log" >&2
  exit 1
fi

launch portal "$ROOT/civicpulse-institution-portal" "${FLUTTER[@]}" run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8080

echo
echo "API        http://127.0.0.1:8080"
echo "GoAdmin    http://127.0.0.1:8080/admin"
echo "Portal     Chrome, API http://127.0.0.1:8080"
echo "Surveys    ws://127.0.0.1:8002"
echo
echo "Citizen app (phone or emulator):"
echo "  cd $ROOT/civicpulse-citizen-app"
echo "  ${FLUTTER[*]} run --dart-define=API_BASE_URL=http://127.0.0.1:8080"
echo
echo "Stop with: make local-down"
