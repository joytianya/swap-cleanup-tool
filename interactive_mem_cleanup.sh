#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: interactive_mem_cleanup.sh [OPTIONS]

Interactive tool to analyze memory usage and kill processes to free memory.

Options:
  -n COUNT    Number of processes to display (default: 20)
  -h, --help  Show this help message

Examples:
  1           - Kill process at index 1
  1 3 5       - Kill processes at index 1, 3, and 5
  1-5         - Kill processes from index 1 to 5
  1-3 7 9-11  - Kill processes 1-3, 7, and 9-11
USAGE
}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

count=20

while [[ $# -gt 0 ]]; do
  case $1 in
    -n)
      count="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! [[ "$count" =~ ^[0-9]+$ ]] || (( count <= 0 )); then
  echo "Error: COUNT must be a positive integer" >&2
  exit 1
fi

# Function to display memory info
show_memory_info() {
  echo -e "${BLUE}=== Current Memory Status ===${NC}"
  free -h
  echo
}

# Function to get process working directory
get_process_cwd() {
  local pid=$1
  if [[ -d "/proc/$pid" ]]; then
    readlink "/proc/$pid/cwd" 2>/dev/null || echo "N/A"
  else
    echo "N/A"
  fi
}

# Function to display top processes
show_top_processes() {
  echo -e "${BLUE}=== Top $count Memory-Consuming Processes ===${NC}"
  printf "${YELLOW}%-6s %-8s %-10s %8s %5s %-18s %-30s %s${NC}\n" "INDEX" "PID" "USER" "RSS(MB)" "%MEM" "START" "CWD" "COMMAND"

  # Get process list and store in array
  mapfile -t process_lines < <(ps --no-headers -eo pid,user,rss,%mem,lstart,command --sort=-rss | head -n "$count")

  local idx=1
  for line in "${process_lines[@]}"; do
    # Parse: PID USER RSS %MEM START_TIME(5_fields) COMMAND
    read -r pid user rss mem_pct start_dow start_mon start_day start_time start_year rest <<< "$line"

    rss_mb=$(awk "BEGIN {printf \"%.1f\", $rss / 1024}")
    start_time_str="$start_mon $start_day $start_time"
    cwd=$(get_process_cwd "$pid")

    # Truncate CWD if too long
    if [[ ${#cwd} -gt 28 ]]; then
      cwd="...${cwd: -25}"
    fi

    # Don't truncate command - show full command
    local cmd_display="$rest"

    printf "%-6s %-8s %-10s %8s %5s %-18s %-30s %s\n" "[$idx]" "$pid" "$user" "$rss_mb" "$mem_pct" "$start_time_str" "$cwd" "$cmd_display"

    ((idx++))
  done
  echo
}

# Function to expand index ranges (e.g., "1-5" -> "1 2 3 4 5")
expand_ranges() {
  local input="$1"
  local result=""

  for part in $input; do
    if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      local start="${BASH_REMATCH[1]}"
      local end="${BASH_REMATCH[2]}"
      for ((i=start; i<=end; i++)); do
        result="$result $i"
      done
    elif [[ "$part" =~ ^[0-9]+$ ]]; then
      result="$result $part"
    fi
  done

  echo "$result"
}

# Function to show process details
show_process_details() {
  local pid=$1

  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  if ! ps -p "$pid" > /dev/null 2>&1; then
    echo -e "${RED}Process $pid no longer exists${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    return 1
  fi

  echo -e "${YELLOW}Process Details:${NC}"
  echo -e "  ${GREEN}PID:${NC} $pid"

  local cmd
  cmd=$(ps -p "$pid" -o command= 2>/dev/null || echo "N/A")
  echo -e "  ${GREEN}Command:${NC} $cmd"

  local user
  user=$(ps -p "$pid" -o user= 2>/dev/null || echo "N/A")
  echo -e "  ${GREEN}User:${NC} $user"

  local rss
  rss=$(ps -p "$pid" -o rss= 2>/dev/null || echo "0")
  local rss_mb=$(awk "BEGIN {printf \"%.1f\", $rss / 1024}")
  echo -e "  ${GREEN}Memory:${NC} ${rss_mb}MB"

  local cwd
  cwd=$(get_process_cwd "$pid")
  echo -e "  ${GREEN}Working Dir:${NC} $cwd"

  local start
  start=$(ps -p "$pid" -o lstart= 2>/dev/null || echo "N/A")
  echo -e "  ${GREEN}Start Time:${NC} $start"

  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to kill process
# Returns: 0=success (auto-refresh), 1=cancelled, 2=error (wait for user)
kill_process() {
  local pid=$1
  local signal=${2:-TERM}

  if ! show_process_details "$pid"; then
    return 2
  fi

  echo
  read -p "Kill this process? (y/N): " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    if kill -s "$signal" "$pid" 2>/dev/null; then
      echo -e "${GREEN}✓ Sent $signal signal to process $pid${NC}"
      sleep 1
      if ! ps -p "$pid" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Process terminated${NC}"
      else
        echo -e "${YELLOW}⚠ Process still running. May need KILL signal (-9)${NC}"
      fi
      echo -e "${BLUE}Refreshing in 2 seconds...${NC}"
      sleep 2
      return 0
    else
      echo -e "${RED}✗ Failed to kill process $pid. Need sudo?${NC}"
      return 2
    fi
  else
    echo "Cancelled"
    return 1
  fi
}

# Function to kill multiple processes
# Returns: 0=success (auto-refresh), 1=cancelled, 2=error (wait for user)
kill_multiple_processes() {
  local indices="$1"
  local pids=()
  local valid_indices=()

  # Collect all valid PIDs
  for idx in $indices; do
    if (( idx >= 1 && idx <= ${#process_lines[@]} )); then
      local line="${process_lines[$((idx-1))]}"
      local pid=$(echo "$line" | awk '{print $1}')
      if ps -p "$pid" > /dev/null 2>&1; then
        pids+=("$pid")
        valid_indices+=("$idx")
      else
        echo -e "${RED}✗ Process at index $idx (PID $pid) no longer exists${NC}"
      fi
    else
      echo -e "${RED}✗ Invalid index: $idx (max: ${#process_lines[@]})${NC}"
    fi
  done

  if [[ ${#pids[@]} -eq 0 ]]; then
    echo -e "${RED}No valid processes to kill${NC}"
    return 2
  fi

  echo -e "${YELLOW}Processes to kill (${#pids[@]} total):${NC}"
  echo

  local total_mem=0
  for i in "${!pids[@]}"; do
    local pid="${pids[$i]}"
    local idx="${valid_indices[$i]}"
    echo -e "${BLUE}[$idx]${NC}"
    show_process_details "$pid"
    echo

    local rss=$(ps -p "$pid" -o rss= 2>/dev/null || echo "0")
    total_mem=$((total_mem + rss))
  done

  local total_mem_mb=$(awk "BEGIN {printf \"%.1f\", $total_mem / 1024}")
  echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}Total memory to be freed: ${total_mem_mb}MB${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
  echo

  read -p "Kill all ${#pids[@]} processes? (y/N): " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    local success_count=0
    echo
    for pid in "${pids[@]}"; do
      if kill -s TERM "$pid" 2>/dev/null; then
        echo -e "${GREEN}✓ Sent TERM signal to process $pid${NC}"
        ((success_count++))
      else
        echo -e "${RED}✗ Failed to kill process $pid${NC}"
      fi
    done

    sleep 1
    echo
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Successfully signaled: $success_count/${#pids[@]} processes${NC}"

    # Check which processes are still running
    local still_running=0
    for pid in "${pids[@]}"; do
      if ps -p "$pid" > /dev/null 2>&1; then
        ((still_running++))
      fi
    done

    if [[ $still_running -gt 0 ]]; then
      echo -e "${YELLOW}⚠ $still_running processes still running${NC}"
    else
      echo -e "${GREEN}✓ All processes terminated${NC}"
    fi
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Refreshing in 2 seconds...${NC}"
    sleep 2
    return 0
  else
    echo "Cancelled"
    return 1
  fi
}

# Main loop
main() {
  while true; do
    clear
    show_memory_info
    show_top_processes

    echo -e "${GREEN}Options:${NC}"
    echo -e "  ${CYAN}[number]${NC}       - Kill process by index (e.g., ${CYAN}1${NC})"
    echo -e "  ${CYAN}[numbers]${NC}      - Kill multiple processes (e.g., ${CYAN}1 3 5${NC})"
    echo -e "  ${CYAN}[range]${NC}        - Kill process range (e.g., ${CYAN}1-5${NC})"
    echo -e "  ${CYAN}[mixed]${NC}        - Combined (e.g., ${CYAN}1-3 7 9-11${NC})"
    echo -e "  ${CYAN}p [pid]${NC}        - Kill process by PID"
    echo -e "  ${CYAN}r${NC}              - Refresh display"
    echo -e "  ${CYAN}q${NC}              - Quit"
    echo

    read -p "Enter your choice: " choice

    case "$choice" in
      q|Q)
        echo "Exiting..."
        exit 0
        ;;
      r|R)
        continue
        ;;
      p\ *|P\ *)
        pid=$(echo "$choice" | awk '{print $2}')
        if [[ "$pid" =~ ^[0-9]+$ ]]; then
          kill_process "$pid"
          result=$?
          if [[ $result -eq 0 ]]; then
            continue  # Auto-refresh
          fi
        else
          echo -e "${RED}Invalid PID${NC}"
        fi
        read -p "Press Enter to continue..."
        ;;
      *[0-9]*)
        # Expand ranges and get all indices
        expanded=$(expand_ranges "$choice")

        if [[ -z "$expanded" ]]; then
          echo -e "${RED}Invalid input${NC}"
          read -p "Press Enter to continue..."
          continue
        fi

        # Check if single or multiple
        local count_indices=$(echo "$expanded" | wc -w)

        if [[ $count_indices -eq 1 ]]; then
          # Single process
          idx=$expanded
          if (( idx >= 1 && idx <= ${#process_lines[@]} )); then
            line="${process_lines[$((idx-1))]}"
            pid=$(echo "$line" | awk '{print $1}')
            kill_process "$pid"
            result=$?
            if [[ $result -eq 0 ]]; then
              continue  # Auto-refresh
            fi
          else
            echo -e "${RED}Invalid index: $idx (max: ${#process_lines[@]})${NC}"
          fi
        else
          # Multiple processes
          kill_multiple_processes "$expanded"
          result=$?
          if [[ $result -eq 0 ]]; then
            continue  # Auto-refresh
          fi
        fi

        read -p "Press Enter to continue..."
        ;;
      *)
        echo -e "${RED}Invalid option${NC}"
        read -p "Press Enter to continue..."
        ;;
    esac
  done
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
  echo -e "${YELLOW}Warning: Running as root${NC}"
fi

main
