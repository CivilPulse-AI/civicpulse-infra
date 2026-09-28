#!/usr/bin/env bash
set -euo pipefail

INFRA="$(cd "$(dirname "$0")/.." && pwd)"
PIDS="$INFRA/.local/pids"

if [[ ! -f "$PIDS" ]]; then
  echo "Local stack is not running."
  exit 0
fi

while read -r pid; do
  [[ -z "$pid" ]] && continue
  kill -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
done <"$PIDS"
rm -f "$PIDS"
echo "Stopped local stack."
