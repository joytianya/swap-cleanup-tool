#!/bin/bash

SWAP_THRESHOLD=80
LOG_FILE="/var/log/swap_cleanup.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOG_FILE"
}

get_swap_usage() {
    local swap_info=$(cat /proc/meminfo | grep -E "SwapTotal|SwapFree")
    local swap_total=$(echo "$swap_info" | grep SwapTotal | awk '{print $2}')
    local swap_free=$(echo "$swap_info" | grep SwapFree | awk '{print $2}')

    if [ "$swap_total" -eq 0 ]; then
        echo 0
        return
    fi

    local swap_used=$((swap_total - swap_free))
    local swap_usage_percent=$((swap_used * 100 / swap_total))
    echo $swap_usage_percent
}

cleanup_swap() {
    log_message "Starting swap cleanup process"

    if ! command -v swapoff >/dev/null 2>&1 || ! command -v swapon >/dev/null 2>&1; then
        log_message "ERROR: swapoff or swapon command not found"
        return 1
    fi

    local swap_devices=$(swapon --show=NAME --noheadings)

    if [ -z "$swap_devices" ]; then
        log_message "No active swap devices found"
        return 0
    fi

    log_message "Turning off swap..."
    if sudo swapoff -a; then
        log_message "Swap turned off successfully"
        sleep 2

        log_message "Turning swap back on..."
        if sudo swapon -a; then
            log_message "Swap turned on successfully"
            log_message "Swap cleanup completed successfully"
        else
            log_message "ERROR: Failed to turn swap back on"
            return 1
        fi
    else
        log_message "ERROR: Failed to turn off swap"
        return 1
    fi
}

main() {
    local current_usage=$(get_swap_usage)

    log_message "Current swap usage: ${current_usage}%"

    if [ "$current_usage" -ge "$SWAP_THRESHOLD" ]; then
        log_message "Swap usage (${current_usage}%) exceeds threshold (${SWAP_THRESHOLD}%)"
        cleanup_swap
    else
        log_message "Swap usage (${current_usage}%) is below threshold (${SWAP_THRESHOLD}%)"
    fi
}

if [ "$1" = "--test" ]; then
    echo "Testing swap monitoring..."
    current_usage=$(get_swap_usage)
    echo "Current swap usage: ${current_usage}%"
    echo "Threshold: ${SWAP_THRESHOLD}%"
    if [ "$current_usage" -ge "$SWAP_THRESHOLD" ]; then
        echo "Would perform cleanup (usage exceeds threshold)"
    else
        echo "No cleanup needed (usage below threshold)"
    fi
else
    main
fi