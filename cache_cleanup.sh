#!/usr/bin/env bash
set -euo pipefail

MEM_THRESHOLD="${MEM_THRESHOLD:-80}"
DROP_CACHES_LEVEL="${DROP_CACHES_LEVEL:-3}"
LOG_FILE="/var/log/cache_cleanup.log"

usage() {
  cat <<'USAGE'
Usage: cache_cleanup.sh [--test]

Monitor memory pressure and drop Linux caches when the used-memory
percentage is at or above the configured threshold.

Environment variables:
  MEM_THRESHOLD       Trigger cleanup when used memory >= threshold (default: 80)
  DROP_CACHES_LEVEL   Value written to /proc/sys/vm/drop_caches (default: 3)
  LOG_FILE            Log file path (default: /var/log/cache_cleanup.log)
USAGE
}

log_message() {
  local message="$1"
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "${timestamp} - ${message}" | tee -a "$LOG_FILE" >/dev/null
}

ensure_log_file() {
  local log_dir
  log_dir="$(dirname "$LOG_FILE")"
  mkdir -p "$log_dir"
  touch "$LOG_FILE"
}

get_memory_usage() {
  local mem_total mem_available mem_used mem_used_percent
  mem_total=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
  mem_available=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)

  if [[ -z "$mem_total" || -z "$mem_available" || "$mem_total" -eq 0 ]]; then
    echo 0
    return
  fi

  mem_used=$((mem_total - mem_available))
  mem_used_percent=$((mem_used * 100 / mem_total))
  echo "$mem_used_percent"
}

cleanup_cache() {
  log_message "Triggering cache cleanup (drop_caches=${DROP_CACHES_LEVEL})"
  sync
  echo "$DROP_CACHES_LEVEL" > /proc/sys/vm/drop_caches
  log_message "Cache cleanup completed"
}

main() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "This script must run as root" >&2
    exit 1
  fi

  ensure_log_file

  local mem_usage
  mem_usage="$(get_memory_usage)"
  log_message "Current memory usage: ${mem_usage}% (threshold: ${MEM_THRESHOLD}%)"

  if (( mem_usage >= MEM_THRESHOLD )); then
    log_message "Used memory (${mem_usage}%) exceeds threshold (${MEM_THRESHOLD}%)"
    cleanup_cache
  else
    log_message "Used memory (${mem_usage}%) below threshold (${MEM_THRESHOLD}%), skipping cleanup"
  fi
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  usage
  exit 0
fi

if [[ ${1:-} == "--test" ]]; then
  if [[ "${EUID}" -ne 0 ]]; then
    echo "--test can run without root, but cleanup requires root privileges" >&2
  else
    ensure_log_file
  fi
  current_usage="$(get_memory_usage)"
  echo "Current memory usage: ${current_usage}%"
  echo "Threshold: ${MEM_THRESHOLD}%"
  if (( current_usage >= MEM_THRESHOLD )); then
    echo "Would perform cache cleanup (used memory exceeds threshold)"
  else
    echo "No cleanup needed (used memory below threshold)"
  fi
  exit 0
fi

main
