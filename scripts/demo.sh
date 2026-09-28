#!/usr/bin/env bash
# Turn the hackathon VM on or off.
# Stopping it stops the CPU charge. The boot disk and the reserved IP still
# bill a small amount until the VM and civicpulse-ip are deleted.
set -euo pipefail

PROJECT="${CLOUDSDK_CORE_PROJECT:-civic-pulse-510013}"
ZONE="${CIVICPULSE_ZONE:-asia-south1-a}"
INSTANCE="${CIVICPULSE_INSTANCE:-civicpulse-demo}"

case "${1:-}" in
  on|start)
    gcloud compute instances start "$INSTANCE" --zone="$ZONE" --project="$PROJECT"
    echo "VM is starting. Docker brings the containers back."
    echo "API    https://8.231.113.7.sslip.io"
    echo "Portal https://civic-pulse-510013.web.app"
    ;;
  off|stop)
    gcloud compute instances stop "$INSTANCE" --zone="$ZONE" --project="$PROJECT"
    echo "VM stopped. CPU billing has stopped."
    echo "The 30 GB disk and the reserved IP civicpulse-ip still bill until you delete them."
    ;;
  status)
    gcloud compute instances describe "$INSTANCE" --zone="$ZONE" --project="$PROJECT" --format='value(status)'
    ;;
  *)
    echo "Usage: $0 on|off|status" >&2
    exit 1
    ;;
esac
