# 内存管理工具集 (Memory Management Toolkit)

一套完整的Linux内存管理工具，包含自动监控和交互式管理两种模式。

**主要功能:**
- 🤖 自动监控Swap使用率，超过阈值自动清理
- 🎯 交互式内存管理：缓存清理、Swap清理、进程管理
- 📊 实时内存状态监控
- 🔍 查看和终止高内存占用进程

## 文件说明

**核心工具:**
- `interactive_cleanup.sh` - **交互式内存管理工具（推荐）**，整合了缓存清理、Swap清理和进程管理功能
- `interactive_mem_cleanup.sh` - 交互式内存清理工具（专注进程管理）

**自动监控:**
- `swap_cleanup.sh` - 监控 swap 使用率并在超阈值后执行清理
- `swap-cleanup.service` - swap 自动清理 systemd 服务
- `swap-cleanup.timer` - swap 自动清理定时器（默认 1 分钟一次）
- `install_swap_cleanup.sh` - 安装 swap 自动清理服务
- `cache_cleanup.sh` - 监控内存占用并在压力过大时回收缓存
- `cache-cleanup.service` - 缓存清理 systemd 服务
- `cache-cleanup.timer` - 缓存清理定时器（默认 15 分钟一次）
- `install_cache_cleanup.sh` - 安装缓存清理服务

**辅助工具:**
- `top_mem_processes.sh` - 查看占用内存最多的进程

## 部署方法

### 方法1: 使用安装脚本（推荐）

```bash
# 1. 将整个目录复制到目标机器
scp -r swap-cleanup-tool/ user@target-server:/tmp/

# 2. 在目标机器上执行安装
cd /tmp/swap-cleanup-tool
sudo ./install_swap_cleanup.sh
```

### 方法2: 手动安装

```bash
# 1. 复制脚本到系统目录
sudo mkdir -p /opt/swap-cleanup-tool
sudo cp swap_cleanup.sh /opt/swap-cleanup-tool/
sudo cp interactive_cleanup.sh /opt/swap-cleanup-tool/
sudo chmod +x /opt/swap-cleanup-tool/swap_cleanup.sh
sudo chmod +x /opt/swap-cleanup-tool/interactive_cleanup.sh

# 2. 安装systemd服务
sudo cp swap-cleanup.service /etc/systemd/system/
sudo cp swap-cleanup.timer /etc/systemd/system/

# 3. 启用并启动服务
sudo systemctl daemon-reload
sudo systemctl enable swap-cleanup.timer
sudo systemctl start swap-cleanup.timer
```

## 使用方法

### 交互式内存管理（推荐）⭐

**新版统一工具** - 整合了系统清理和进程管理:

```bash
# 如果已安装
sudo /opt/swap-cleanup-tool/interactive_cleanup.sh

# 或在项目目录直接运行
sudo ./interactive_cleanup.sh

# 自定义显示进程数量
sudo ./interactive_cleanup.sh -n 50

# 查看帮助
./interactive_cleanup.sh --help
```

**功能特性:**

**系统清理:**
- 清理页面缓存 (Page Cache)
- 清理目录项和inode缓存 (Dentries & Inodes)
- 清理所有缓存 (All Caches)
- 清理Swap
- 清理所有 (缓存 + Swap)

**进程管理:**
- 查看Top N内存占用进程 (支持自定义数量: `-n 50`)
- 显示详细进程信息 (PID, 用户, 内存, 工作目录, 命令)
- 单个或批量终止进程
- 支持范围选择 (如: `1-5` 或 `1-3 7 9-11`)
- 按PID直接终止进程
- 显示将释放的总内存量

**其他特性:**
- 实时内存和Swap状态监控
- 彩色输出,界面友好
- 所有操作记录到日志文件
- 安全确认机制

**使用示例:**

进入进程管理模式后:
```
# 终止单个进程
1          # 终止序号1的进程

# 终止多个进程
1 3 5      # 终止序号1、3、5的进程

# 终止范围内的进程
1-5        # 终止序号1到5的所有进程

# 混合使用
1-3 7 9-11 # 终止1-3、7、9-11序号的进程

# 按PID终止
pid 12345  # 终止PID为12345的进程

# 刷新列表
r          # 刷新进程列表

# 返回主菜单
b          # 返回到主菜单
```

### 交互式内存清理（专业版）

快速分析内存使用并交互式清理进程：

```bash
# 直接运行（显示前20个占用内存最多的进程）
./interactive_mem_cleanup.sh

# 自定义显示数量
./interactive_mem_cleanup.sh -n 30

# 如需kill其他用户的进程，使用sudo
sudo ./interactive_mem_cleanup.sh
```

**功能特点：**
- 实时显示系统内存状态（总量、已用、空闲、swap等）
- 列出占用内存最多的进程（PID、用户、内存、**启动时间**、**工作目录**、命令）
- 支持**批量kill**进程（多个索引、范围选择）
- 显示每个进程的详细信息（内存、启动目录、启动时间等）
- 批量kill时显示总共将释放的内存大小
- 交互式确认，避免误操作
- 彩色界面，清晰直观

**操作说明：**
- 输入数字（如 `1`）：根据索引kill单个进程
- 输入多个数字（如 `1 3 5`）：批量kill多个进程
- 输入范围（如 `1-5`）：kill索引1到5的所有进程
- 输入混合（如 `1-3 7 9-11`）：kill索引1-3、7、9-11的进程
- 输入 `p [pid]`（如 `p 12345`）：根据PID kill进程
- 输入 `r`：刷新显示
- 输入 `q`：退出

### 查看占用内存的进程

```bash
# 查看前10个占用内存最多的进程
./top_mem_processes.sh

# 查看前20个
./top_mem_processes.sh 20
```

### 安装缓存清理服务

```bash
# 1. 复制整个目录到目标机器
scp -r swap-cleanup-tool/ user@target-server:/tmp/

# 2. 在目标机器上安装缓存清理服务
cd /tmp/swap-cleanup-tool
sudo ./install_cache_cleanup.sh
```

安装完成后：

```bash
# 查看缓存清理定时器状态
systemctl status cache-cleanup.timer

# 查看缓存清理日志
journalctl -u cache-cleanup.service

# 手动执行一次清理检查
sudo systemctl start cache-cleanup.service
```

默认会在内存使用率达到 80% 时执行 `sync` 并写入 `/proc/sys/vm/drop_caches`（值为 3，可通过环境变量 `DROP_CACHES_LEVEL` 调整）。

如需修改阈值，可以在 `/opt/cache-cleanup-tool/cache_cleanup.sh` 中调整 `MEM_THRESHOLD` 的默认值，或在 systemd 覆盖文件里设置环境变量：

```bash
sudo systemctl edit cache-cleanup.service

[Service]
Environment="MEM_THRESHOLD=75"
Environment="DROP_CACHES_LEVEL=2"
```

编辑后执行 `sudo systemctl daemon-reload && sudo systemctl restart cache-cleanup.timer` 生效。

### 查看Swap状态
```bash
# 查看定时器状态
systemctl status swap-cleanup.timer

# 查看服务日志
journalctl -u swap-cleanup.service

# 查看最近的日志
sudo tail -f /var/log/swap_cleanup.log
```

### 自动清理测试
```bash
# 测试脚本（不执行清理）
/opt/swap-cleanup-tool/swap_cleanup.sh --test

# 手动执行一次清理检查
sudo systemctl start swap-cleanup.service
```

### 停止和卸载
```bash
# 缓存清理
sudo systemctl stop cache-cleanup.timer
sudo systemctl disable cache-cleanup.timer
sudo rm /etc/systemd/system/cache-cleanup.service
sudo rm /etc/systemd/system/cache-cleanup.timer
sudo rm -rf /opt/cache-cleanup-tool

# Swap清理
sudo systemctl stop swap-cleanup.timer
sudo systemctl disable swap-cleanup.timer
sudo rm /etc/systemd/system/swap-cleanup.service
sudo rm /etc/systemd/system/swap-cleanup.timer
sudo rm -rf /opt/swap-cleanup-tool
sudo systemctl daemon-reload
```

## 配置说明

### 修改清理阈值
编辑 `/opt/swap-cleanup-tool/swap_cleanup.sh`，修改 `SWAP_THRESHOLD` 变量：
```bash
SWAP_THRESHOLD=80  # 默认80%，可以修改为其他值
```

### 修改检查频率
编辑 `/etc/systemd/system/swap-cleanup.timer`，修改 `OnUnitActiveSec` 值：
```ini
OnUnitActiveSec=1min  # 默认1分钟，可以修改为其他值如5min、10min、1h等
```

修改后需要重新加载配置：
```bash
sudo systemctl daemon-reload
sudo systemctl restart swap-cleanup.timer
```

## 日志位置

- 系统日志: `journalctl -u swap-cleanup.service`
- 应用日志: `/var/log/swap_cleanup.log`

## 内存清理说明

### 缓存清理 (drop_caches)
- **选项1 (Page Cache)**: 清理页面缓存，释放文件系统缓存的内存
- **选项2 (Dentries & Inodes)**: 清理目录项和inode缓存
- **选项3 (All Caches)**: 清理所有缓存 (等同于 echo 3 > /proc/sys/vm/drop_caches)
- 缓存清理是安全的，Linux会在需要时自动重建缓存

### Swap清理
- 通过 `swapoff -a` 和 `swapon -a` 将Swap中的数据重新加载到内存
- 可以释放Swap空间中的碎片化数据
- 需要足够的物理内存支持

## 注意事项

1. **交互式工具和所有清理操作都需要root权限**
2. 清理Swap过程中会短暂关闭swap，可能影响系统性能
3. 确保系统有足够的物理内存支持Swap清理过程
4. 缓存清理是安全的，但会暂时降低文件访问性能
5. 建议在测试环境先验证后再部署到生产环境
6. 所有操作都会记录到 `/var/log/swap_cleanup.log`
