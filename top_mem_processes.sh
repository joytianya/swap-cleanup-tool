#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: top_mem_processes.sh [COUNT]

Show the processes currently consuming the most resident memory.

Positional arguments:
  COUNT   Number of processes to show (default: 10)
USAGE
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  usage
  exit 0
fi

count="${1:-10}"

if ! [[ "$count" =~ ^[0-9]+$ ]] || (( count <= 0 )); then
  echo "Error: COUNT must be a positive integer" >&2
  usage >&2
  exit 1
fi

printf '%-8s %-10s %8s %6s %s\n' "PID" "USER" "RSS(MB)" "%MEM" "COMMAND"
ps --no-headers -eo pid,user,rss,%mem,command --sort=-rss |
  head -n "$count" |
  awk '{
    rss_mb = $3 / 1024
    cmd_index = index($0, $5)
    cmd = cmd_index ? substr($0, cmd_index) : ""
    printf "%-8s %-10s %8.1f %6s %s\n", $1, $2, rss_mb, $4, cmd
  }'
