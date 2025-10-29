#!/bin/bash

# 交互式内存释放工具
# 提供多种内存清理选项

LOG_FILE="/var/log/swap_cleanup.log"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOG_FILE"
}

print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

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

show_menu() {
    print_color "$BLUE" "\n========== 内存清理选项 =========="
    echo "1. 清理页面缓存 (Page Cache)"
    echo "2. 清理目录项和inode缓存 (Dentries & Inodes)"
    echo "3. 清理所有缓存 (All Caches)"
    echo "4. 清理Swap"
    echo "5. 清理所有 (缓存 + Swap)"
    echo "6. 显示内存状态"
    echo "0. 退出"
    print_color "$BLUE" "===================================="
    echo -n "请选择操作 [0-6]: "
}

main() {
    # 检查是否有root权限
    if [ "$EUID" -ne 0 ]; then
        print_color "$RED" "此脚本需要root权限运行"
        echo "请使用: sudo $0"
        exit 1
    fi

    print_color "$GREEN" "\n欢迎使用交互式内存释放工具\n"
    log_message "Interactive cleanup tool started"

    # 显示初始内存状态
    show_memory_info

    while true; do
        show_menu
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
            6)
                show_memory_info
                ;;
            0)
                print_color "$GREEN" "\n感谢使用! 再见!"
                log_message "Interactive cleanup tool exited"
                exit 0
                ;;
            *)
                print_color "$RED" "\n无效的选择,请输入0-6之间的数字"
                ;;
        esac

        echo ""
        read -p "按回车键继续..." dummy
    done
}

# 执行主程序
main
