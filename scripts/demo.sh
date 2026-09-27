#!/usr/bin/env bash
# Turn the hackathon VM on or off.
# Stopping it stops the CPU charge. The boot disk and the reserved IP still
# bill a small amount until the VM and civicpulse-ip are deleted.
set -euo pipefail

PROJECT="${CLOUDSDK_CORE_PROJECT:-civic-pulse-510013}"
ZONE="${CIVICPULSE_ZONE:-asia-south1-a}"
INSTANCE="${CIVICPULSE_INSTANCE:-civicpulse-demo}"
API_URL="${CIVICPULSE_API_URL:-https://8.231.113.7.sslip.io}"
PORTAL_URL="${CIVICPULSE_PORTAL_URL:-https://civic-pulse-510013.web.app}"

deploy_portal() {
  local infra root portal
  infra="$(cd "$(dirname "$0")/.." && pwd)"
  root="$(cd "$infra/.." && pwd)"
  portal="$root/civicpulse-institution-portal"
  if [[ ! -d "$portal" ]]; then
    echo "missing portal checkout: $portal" >&2
    exit 1
  fi
  if [[ -d "$portal/.git" ]]; then
    git -C "$portal" pull --ff-only
    echo "portal $(git -C "$portal" rev-parse --abbrev-ref HEAD) $(git -C "$portal" rev-parse --short HEAD)"
  fi
  local -a flutter
  if [[ -x "$HOME/snap/flutter/common/flutter/bin/flutter" ]]; then
    flutter=("$HOME/snap/flutter/common/flutter/bin/flutter")
  else
    flutter=(flutter)
  fi
  export TMPDIR="${TMPDIR:-$HOME/.cache/cp-tmp/infra}"
  mkdir -p "$TMPDIR"
  (
    cd "$portal"
    "${flutter[@]}" build web --dart-define=API_BASE_URL="$API_URL"
    if command -v firebase >/dev/null 2>&1; then
      firebase deploy --only hosting --project "$PROJECT"
    else
      npx --yes firebase-tools deploy --only hosting --project "$PROJECT"
    fi
  )
  echo "Portal $PORTAL_URL"
}

case "${1:-}" in
  on|start)
    gcloud compute instances start "$INSTANCE" --zone="$ZONE" --project="$PROJECT"
    echo "VM is starting. Docker brings the containers back."
    echo "API    $API_URL"
    echo "Portal $PORTAL_URL"
    ;;
  off|stop)
    gcloud compute instances stop "$INSTANCE" --zone="$ZONE" --project="$PROJECT"
    echo "VM stopped. CPU billing has stopped."
    echo "The 30 GB disk and the reserved IP civicpulse-ip still bill until you delete them."
    ;;
  status)
    gcloud compute instances describe "$INSTANCE" --zone="$ZONE" --project="$PROJECT" --format='value(status)'
    ;;
  refresh)
    status="$(gcloud compute instances describe "$INSTANCE" --zone="$ZONE" --project="$PROJECT" --format='value(status)')"
    if [[ "$status" != "RUNNING" ]]; then
      echo "VM is $status. Starting it first."
      gcloud compute instances start "$INSTANCE" --zone="$ZONE" --project="$PROJECT"
      for _ in $(seq 1 30); do
        status="$(gcloud compute instances describe "$INSTANCE" --zone="$ZONE" --project="$PROJECT" --format='value(status)')"
        [[ "$status" == "RUNNING" ]] && break
        sleep 5
      done
      if [[ "$status" != "RUNNING" ]]; then
        echo "VM did not reach RUNNING (last status: $status)" >&2
        exit 1
      fi
    fi
    # The VM copies were uploaded without a .git directory, so refresh
    # sends the local sibling trees and rebuilds there.
    remote_root="${CIVICPULSE_ROOT:-/opt/civicpulse}"
    local_root="$(cd "$(dirname "$0")/../.." && pwd)"
    sync_tree() {
      local name="$1"
      local src="$local_root/$name"
      local dest="$remote_root/$name"
      if [[ ! -d "$src" ]]; then
        echo "missing local checkout: $src" >&2
        exit 1
      fi
      echo "sync $name"
      gcloud compute ssh "$INSTANCE" --zone="$ZONE" --project="$PROJECT" --command="$(cat <<EOF
set -euo pipefail
dest=$(printf '%q' "$dest")
sudo mkdir -p "\$dest"
sudo find "\$dest" -mindepth 1 -maxdepth 1 ! -name .env ! -name ca.pem -exec rm -rf {} +
EOF
)"
      tar -C "$src" \
        --exclude .git \
        --exclude .env \
        --exclude .local \
        --exclude .venv \
        --exclude __pycache__ \
        --exclude build \
        --exclude .dart_tool \
        --exclude node_modules \
        -czf - . \
        | gcloud compute ssh "$INSTANCE" --zone="$ZONE" --project="$PROJECT" --command="sudo tar -xzf - -C $(printf '%q' "$dest")"
    }
    for name in civicpulse-infra civicpulse-server civicpulse-ai-service civicpulse-telephony-service civicpulse-notification-service; do
      sync_tree "$name"
    done
    gcloud compute ssh "$INSTANCE" --zone="$ZONE" --project="$PROJECT" --command="cd $(printf '%q' "$remote_root/civicpulse-infra") && sudo docker compose up -d --build"
    echo "API    $API_URL"
    deploy_portal
    ;;
  *)
    echo "Usage: $0 on|off|status|refresh" >&2
    exit 1
    ;;
esac
