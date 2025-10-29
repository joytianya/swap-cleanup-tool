#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="${SCRIPT_DIR}/cache-cleanup.service"
TIMER_FILE="${SCRIPT_DIR}/cache-cleanup.timer"
SCRIPT_FILE="${SCRIPT_DIR}/cache_cleanup.sh"
INSTALL_DIR="/opt/cache-cleanup-tool"
LOG_FILE="/var/log/cache_cleanup.log"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run this script as root (e.g. via sudo)" >&2
  exit 1
fi

echo "Installing cache cleanup service..."

mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_FILE" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/cache_cleanup.sh"

cp "$SERVICE_FILE" /etc/systemd/system/
cp "$TIMER_FILE" /etc/systemd/system/

if [[ ! -f "$LOG_FILE" ]]; then
  touch "$LOG_FILE"
fi
chmod 640 "$LOG_FILE"
chown root:root "$LOG_FILE"

systemctl daemon-reload
systemctl enable cache-cleanup.timer
systemctl start cache-cleanup.timer

echo "Cache cleanup service installed and started."
echo "Timer runs cache cleanup every 15 minutes (5 minute delay after boot)."
echo "Check status with: systemctl status cache-cleanup.timer"
echo "View logs with: journalctl -u cache-cleanup.service"
