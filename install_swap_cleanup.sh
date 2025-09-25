#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="$SCRIPT_DIR/swap-cleanup.service"
TIMER_FILE="$SCRIPT_DIR/swap-cleanup.timer"
SCRIPT_FILE="$SCRIPT_DIR/swap_cleanup.sh"

if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root (use sudo)"
    exit 1
fi

echo "Installing swap cleanup service..."

# Create installation directory
mkdir -p /opt/swap-cleanup-tool
cp "$SCRIPT_FILE" /opt/swap-cleanup-tool/
chmod +x /opt/swap-cleanup-tool/swap_cleanup.sh

# Install systemd files
cp "$SERVICE_FILE" /etc/systemd/system/
cp "$TIMER_FILE" /etc/systemd/system/

systemctl daemon-reload

systemctl enable swap-cleanup.timer
systemctl start swap-cleanup.timer

echo "Swap cleanup service installed and started successfully!"
echo "The service will check swap usage every 5 minutes."
echo "Check status with: systemctl status swap-cleanup.timer"
echo "View logs with: journalctl -u swap-cleanup.service"