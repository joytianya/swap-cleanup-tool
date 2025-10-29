#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="$SCRIPT_DIR/swap-cleanup.service"
TIMER_FILE="$SCRIPT_DIR/swap-cleanup.timer"
SCRIPT_FILE="$SCRIPT_DIR/swap_cleanup.sh"
INTERACTIVE_SCRIPT="$SCRIPT_DIR/interactive_cleanup.sh"

if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root (use sudo)"
    exit 1
fi

echo "Installing swap cleanup service..."

# Create installation directory
mkdir -p /opt/swap-cleanup-tool
cp "$SCRIPT_FILE" /opt/swap-cleanup-tool/
cp "$INTERACTIVE_SCRIPT" /opt/swap-cleanup-tool/
chmod +x /opt/swap-cleanup-tool/swap_cleanup.sh
chmod +x /opt/swap-cleanup-tool/interactive_cleanup.sh

# Install systemd files
cp "$SERVICE_FILE" /etc/systemd/system/
cp "$TIMER_FILE" /etc/systemd/system/

systemctl daemon-reload

systemctl enable swap-cleanup.timer
systemctl start swap-cleanup.timer

echo "Swap cleanup service installed and started successfully!"
echo ""
echo "Installed files:"
echo "  - /opt/swap-cleanup-tool/swap_cleanup.sh (automatic monitoring)"
echo "  - /opt/swap-cleanup-tool/interactive_cleanup.sh (interactive tool)"
echo ""
echo "Automatic monitoring:"
echo "  - Check swap usage every 1 minute"
echo "  - Auto cleanup when usage > 80%"
echo "  - Status: systemctl status swap-cleanup.timer"
echo "  - Logs: journalctl -u swap-cleanup.service"
echo ""
echo "Manual cleanup (interactive):"
echo "  sudo /opt/swap-cleanup-tool/interactive_cleanup.sh"