#!/usr/bin/env bash
set -euo pipefail

# 交互式内存管理工具
# 整合了缓存清理、Swap清理和进程管理功能

LOG_FILE="/var/log/swap_cleanup.log"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 全局变量
process_lines=()
process_count=20

usage() {
  cat <<'USAGE'
Usage: interactive_cleanup.sh [OPTIONS]

交互式内存管理工具 - 支持缓存清理、Swap清理和进程管理

Options:
  -n COUNT    显示进程数量 (默认: 20)
  -h, --help  显示帮助信息

功能:
  1. 系统缓存和Swap清理
  2. 查看和终止高内存占用进程
  3. 实时内存状态监控
USAGE
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
  case $1 in
    -n)
      process_count="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知选项: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! [[ "$process_count" =~ ^[0-9]+$ ]] || (( process_count <= 0 )); then
  echo "错误: COUNT 必须是正整数" >&2
  exit 1
fi

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOG_FILE" >/dev/null 2>&1
}

print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# ==================== 内存信息显示 ====================

show_memory_info() {
    print_color "$BLUE" "\n========== 当前内存状态 =========="

    # 物理内存信息
    local mem_info=$(free -h | grep "Mem:")
    local mem_total=$(echo $mem_info | awk '{print $2}')
    local mem_used=$(echo $mem_info | awk '{print $3}')
    local mem_free=$(echo $mem_info | awk '{print $4}')
    local mem_available=$(echo $mem_info | awk '{print $7}')

    # Swap信息
    local swap_info=$(free -h | grep "Swap:")
    local swap_total=$(echo $swap_info | awk '{print $2}')
    local swap_used=$(echo $swap_info | awk '{print $3}')
    local swap_free=$(echo $swap_info | awk '{print $4}')

    # 计算使用率
    local mem_percent=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    local swap_percent=$(free | grep Swap | awk '{if($2>0) printf "%.1f", $3/$2 * 100.0; else print "0"}')

    echo "物理内存:"
    echo "  总量: $mem_total"
    echo "  已用: $mem_used (${mem_percent}%)"
    echo "  可用: $mem_available"
    echo ""
    echo "Swap:"
    echo "  总量: $swap_total"
    echo "  已用: $swap_used (${swap_percent}%)"
    echo "  空闲: $swap_free"

    # 显示缓存信息
    local buffers=$(free -h | grep "Mem:" | awk '{print $6}')
    local cached=$(grep "^Cached:" /proc/meminfo | awk '{printf "%.1fG", $2/1024/1024}')
    echo ""
    echo "缓存:"
    echo "  Buffers: $buffers"
    echo "  Cached: $cached"

    print_color "$BLUE" "===================================\n"
}

# ==================== 缓存清理功能 ====================

cleanup_page_cache() {
    print_color "$YELLOW" "\n[1/3] 开始清理页面缓存..."
    log_message "Cleaning page cache (drop_caches=1)"

    sync
    echo 1 | sudo tee /proc/sys/vm/drop_caches > /dev/null

    if [ $? -eq 0 ]; then
        print_color "$GREEN" "✓ 页面缓存清理完成"
        log_message "Page cache cleaned successfully"
        return 0
    else
        print_color "$RED" "✗ 页面缓存清理失败"
        log_message "ERROR: Failed to clean page cache"
        return 1
    fi
}

cleanup_dentries_inodes() {
    print_color "$YELLOW" "\n[2/3] 开始清理目录项和inode缓存..."
    log_message "Cleaning dentries and inodes (drop_caches=2)"

    sync
    echo 2 | sudo tee /proc/sys/vm/drop_caches > /dev/null

    if [ $? -eq 0 ]; then
        print_color "$GREEN" "✓ 目录项和inode缓存清理完成"
        log_message "Dentries and inodes cleaned successfully"
        return 0
    else
        print_color "$RED" "✗ 目录项和inode缓存清理失败"
        log_message "ERROR: Failed to clean dentries and inodes"
        return 1
    fi
}

cleanup_all_cache() {
    print_color "$YELLOW" "\n[3/3] 开始清理所有缓存..."
    log_message "Cleaning all caches (drop_caches=3)"

    sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null

    if [ $? -eq 0 ]; then
        print_color "$GREEN" "✓ 所有缓存清理完成"
        log_message "All caches cleaned successfully"
        return 0
    else
        print_color "$RED" "✗ 所有缓存清理失败"
        log_message "ERROR: Failed to clean all caches"
        return 1
    fi
}

cleanup_swap() {
    print_color "$YELLOW" "\n开始清理Swap..."
    log_message "Starting swap cleanup process"

    if ! command -v swapoff >/dev/null 2>&1 || ! command -v swapon >/dev/null 2>&1; then
        print_color "$RED" "✗ 错误: 找不到swapoff或swapon命令"
        log_message "ERROR: swapoff or swapon command not found"
        return 1
    fi

    local swap_devices=$(swapon --show=NAME --noheadings)

    if [ -z "$swap_devices" ]; then
        print_color "$YELLOW" "⚠ 没有活动的swap设备"
        log_message "No active swap devices found"
        return 0
    fi

    print_color "$YELLOW" "关闭swap..."
    log_message "Turning off swap..."

    if sudo swapoff -a; then
        print_color "$GREEN" "✓ Swap已关闭"
        log_message "Swap turned off successfully"
        sleep 2

        print_color "$YELLOW" "重新启用swap..."
        log_message "Turning swap back on..."

        if sudo swapon -a; then
            print_color "$GREEN" "✓ Swap已重新启用"
            print_color "$GREEN" "✓ Swap清理完成"
            log_message "Swap turned on successfully"
            log_message "Swap cleanup completed successfully"
            return 0
        else
            print_color "$RED" "✗ 错误: 重新启用swap失败"
            log_message "ERROR: Failed to turn swap back on"
            return 1
        fi
    else
        print_color "$RED" "✗ 错误: 关闭swap失败"
        log_message "ERROR: Failed to turn off swap"
        return 1
    fi
}

# ==================== 进程管理功能 ====================

get_process_cwd() {
  local pid=$1
  if [[ -d "/proc/$pid" ]]; then
    readlink "/proc/$pid/cwd" 2>/dev/null || echo "N/A"
  else
    echo "N/A"
  fi
}

show_top_processes() {
  print_color "$BLUE" "\n========== Top $process_count 内存占用进程 =========="
  printf "${YELLOW}%-6s %-8s %-10s %8s %5s %-18s %-30s %s${NC}\n" "序号" "PID" "USER" "RSS(MB)" "%MEM" "启动时间" "工作目录" "命令"

  # 获取进程列表并存储到数组
  mapfile -t process_lines < <(ps --no-headers -eo pid,user,rss,%mem,lstart,command --sort=-rss | head -n "$process_count")

  local idx=1
  for line in "${process_lines[@]}"; do
    # 解析: PID USER RSS %MEM START_TIME(5_fields) COMMAND
    read -r pid user rss mem_pct start_dow start_mon start_day start_time start_year rest <<< "$line"

    rss_mb=$(awk "BEGIN {printf \"%.1f\", $rss / 1024}")
    start_time_str="$start_mon $start_day $start_time"
    cwd=$(get_process_cwd "$pid")

    # 截断CWD如果太长
    if [[ ${#cwd} -gt 28 ]]; then
      cwd="...${cwd: -25}"
    fi

    local cmd_display="$rest"

    printf "%-6s %-8s %-10s %8s %5s %-18s %-30s %s\n" "[$idx]" "$pid" "$user" "$rss_mb" "$mem_pct" "$start_time_str" "$cwd" "$cmd_display"

    ((idx++))
  done
  print_color "$BLUE" "==================================================\n"
}

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

show_process_details() {
  local pid=$1

  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  if ! ps -p "$pid" > /dev/null 2>&1; then
    echo -e "${RED}进程 $pid 已不存在${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    return 1
  fi

  echo -e "${YELLOW}进程详情:${NC}"
  echo -e "  ${GREEN}PID:${NC} $pid"

  local cmd
  cmd=$(ps -p "$pid" -o command= 2>/dev/null || echo "N/A")
  echo -e "  ${GREEN}命令:${NC} $cmd"

  local user
  user=$(ps -p "$pid" -o user= 2>/dev/null || echo "N/A")
  echo -e "  ${GREEN}用户:${NC} $user"

  local rss
  rss=$(ps -p "$pid" -o rss= 2>/dev/null || echo "0")
  local rss_mb=$(awk "BEGIN {printf \"%.1f\", $rss / 1024}")
  echo -e "  ${GREEN}内存:${NC} ${rss_mb}MB"

  local cwd
  cwd=$(get_process_cwd "$pid")
  echo -e "  ${GREEN}工作目录:${NC} $cwd"

  local start
  start=$(ps -p "$pid" -o lstart= 2>/dev/null || echo "N/A")
  echo -e "  ${GREEN}启动时间:${NC} $start"

  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

kill_process() {
  local pid=$1
  local signal=${2:-TERM}

  if ! show_process_details "$pid"; then
    return 2
  fi

  echo
  read -p "确定要终止这个进程吗? (y/N): " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    if kill -s "$signal" "$pid" 2>/dev/null; then
      echo -e "${GREEN}✓ 已发送 $signal 信号到进程 $pid${NC}"
      sleep 1
      if ! ps -p "$pid" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 进程已终止${NC}"
      else
        echo -e "${YELLOW}⚠ 进程仍在运行。可能需要 KILL 信号 (-9)${NC}"
      fi
      echo -e "${BLUE}2秒后刷新...${NC}"
      sleep 2
      return 0
    else
      echo -e "${RED}✗ 终止进程 $pid 失败。需要sudo权限?${NC}"
      return 2
    fi
  else
    echo "已取消"
    return 1
  fi
}

kill_multiple_processes() {
  local indices="$1"
  local pids=()
  local valid_indices=()

  # 收集所有有效的PID
  for idx in $indices; do
    if (( idx >= 1 && idx <= ${#process_lines[@]} )); then
      local line="${process_lines[$((idx-1))]}"
      local pid=$(echo "$line" | awk '{print $1}')
      if ps -p "$pid" > /dev/null 2>&1; then
        pids+=("$pid")
        valid_indices+=("$idx")
      else
        echo -e "${RED}✗ 索引 $idx 的进程 (PID $pid) 已不存在${NC}"
      fi
    else
      echo -e "${RED}✗ 无效索引: $idx (最大: ${#process_lines[@]})${NC}"
    fi
  done

  if [[ ${#pids[@]} -eq 0 ]]; then
    echo -e "${RED}没有有效的进程可终止${NC}"
    return 2
  fi

  echo -e "${YELLOW}将要终止的进程 (共 ${#pids[@]} 个):${NC}"
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
  echo -e "${GREEN}将释放的总内存: ${total_mem_mb}MB${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
  echo

  read -p "确定要终止这 ${#pids[@]} 个进程吗? (y/N): " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    local success_count=0
    echo
    for pid in "${pids[@]}"; do
      if kill -s TERM "$pid" 2>/dev/null; then
        echo -e "${GREEN}✓ 已发送 TERM 信号到进程 $pid${NC}"
        ((success_count++))
      else
        echo -e "${RED}✗ 终止进程 $pid 失败${NC}"
      fi
    done

    sleep 1
    echo
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}成功发送信号: $success_count/${#pids[@]} 个进程${NC}"

    # 检查哪些进程仍在运行
    local still_running=0
    for pid in "${pids[@]}"; do
      if ps -p "$pid" > /dev/null 2>&1; then
        ((still_running++))
      fi
    done

    if [[ $still_running -gt 0 ]]; then
      echo -e "${YELLOW}⚠ $still_running 个进程仍在运行${NC}"
    else
      echo -e "${GREEN}✓ 所有进程已终止${NC}"
    fi
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}2秒后刷新...${NC}"
    sleep 2
    return 0
  else
    echo "已取消"
    return 1
  fi
}

# ==================== 主菜单 ====================

show_main_menu() {
    print_color "$BLUE" "\n========== 内存管理主菜单 =========="
    echo "系统清理:"
    echo "  1. 清理页面缓存 (Page Cache)"
    echo "  2. 清理目录项和inode缓存 (Dentries & Inodes)"
    echo "  3. 清理所有缓存 (All Caches)"
    echo "  4. 清理Swap"
    echo "  5. 清理所有 (缓存 + Swap)"
    echo ""
    echo "进程管理:"
    echo "  p. 查看和管理高内存占用进程"
    echo ""
    echo "其他:"
    echo "  m. 显示内存状态"
    echo "  0. 退出"
    print_color "$BLUE" "===================================="
    echo -n "请选择操作: "
}

process_management_mode() {
    while true; do
        clear
        show_memory_info
        show_top_processes

        echo -e "${GREEN}进程管理选项:${NC}"
        echo -e "  ${CYAN}[数字]${NC}        - 按序号终止进程 (例如: ${CYAN}1${NC})"
        echo -e "  ${CYAN}[多个数字]${NC}    - 终止多个进程 (例如: ${CYAN}1 3 5${NC})"
        echo -e "  ${CYAN}[范围]${NC}        - 终止范围内进程 (例如: ${CYAN}1-5${NC})"
        echo -e "  ${CYAN}[混合]${NC}        - 组合使用 (例如: ${CYAN}1-3 7 9-11${NC})"
        echo -e "  ${CYAN}pid [PID]${NC}     - 按PID终止进程"
        echo -e "  ${CYAN}r${NC}             - 刷新显示"
        echo -e "  ${CYAN}b${NC}             - 返回主菜单"
        echo

        read -p "请输入选择: " choice

        case "$choice" in
            b|B)
                return
                ;;
            r|R)
                continue
                ;;
            pid\ *|PID\ *)
                pid=$(echo "$choice" | awk '{print $2}')
                if [[ "$pid" =~ ^[0-9]+$ ]]; then
                    kill_process "$pid"
                    result=$?
                    if [[ $result -eq 0 ]]; then
                        continue
                    fi
                else
                    echo -e "${RED}无效的PID${NC}"
                fi
                read -p "按回车键继续..." dummy
                ;;
            *[0-9]*)
                # 展开范围并获取所有索引
                expanded=$(expand_ranges "$choice")

                if [[ -z "$expanded" ]]; then
                    echo -e "${RED}无效输入${NC}"
                    read -p "按回车键继续..." dummy
                    continue
                fi

                # 检查是单个还是多个
                local count_indices=$(echo "$expanded" | wc -w)

                if [[ $count_indices -eq 1 ]]; then
                    # 单个进程
                    idx=$expanded
                    if (( idx >= 1 && idx <= ${#process_lines[@]} )); then
                        line="${process_lines[$((idx-1))]}"
                        pid=$(echo "$line" | awk '{print $1}')
                        kill_process "$pid"
                        result=$?
                        if [[ $result -eq 0 ]]; then
                            continue
                        fi
                    else
                        echo -e "${RED}无效索引: $idx (最大: ${#process_lines[@]})${NC}"
                    fi
                else
                    # 多个进程
                    kill_multiple_processes "$expanded"
                    result=$?
                    if [[ $result -eq 0 ]]; then
                        continue
                    fi
                fi

                read -p "按回车键继续..." dummy
                ;;
            *)
                echo -e "${RED}无效选项${NC}"
                read -p "按回车键继续..." dummy
                ;;
        esac
    done
}

main() {
    # 检查是否有root权限（某些操作需要）
    if [ "$EUID" -ne 0 ]; then
        print_color "$YELLOW" "\n警告: 某些功能需要root权限"
        print_color "$YELLOW" "建议使用: sudo $0\n"
    fi

    print_color "$GREEN" "\n欢迎使用交互式内存管理工具\n"
    log_message "Interactive memory management tool started"

    # 显示初始内存状态
    show_memory_info

    while true; do
        show_main_menu
        read -r choice

        case $choice in
            1)
                print_color "$YELLOW" "\n>>> 执行: 清理页面缓存"
                cleanup_page_cache
                sleep 1
                show_memory_info
                ;;
            2)
                print_color "$YELLOW" "\n>>> 执行: 清理目录项和inode缓存"
                cleanup_dentries_inodes
                sleep 1
                show_memory_info
                ;;
            3)
                print_color "$YELLOW" "\n>>> 执行: 清理所有缓存"
                cleanup_all_cache
                sleep 1
                show_memory_info
                ;;
            4)
                print_color "$YELLOW" "\n>>> 执行: 清理Swap"
                cleanup_swap
                sleep 1
                show_memory_info
                ;;
            5)
                print_color "$YELLOW" "\n>>> 执行: 清理所有 (缓存 + Swap)"
                cleanup_all_cache
                sleep 1
                cleanup_swap
                sleep 1
                show_memory_info
                ;;
            p|P)
                process_management_mode
                show_memory_info
                ;;
            m|M)
                show_memory_info
                ;;
            0)
                print_color "$GREEN" "\n感谢使用! 再见!"
                log_message "Interactive memory management tool exited"
                exit 0
                ;;
            *)
                print_color "$RED" "\n无效的选择"
                ;;
        esac

        echo ""
        read -p "按回车键继续..." dummy
    done
}

# 执行主程序
main
