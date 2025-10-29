# Swap Cleanup Tool

自动监控和清理swap使用率的工具，当swap使用率超过80%时自动执行清理操作。

## 文件说明

- `swap_cleanup.sh` - 监控 swap 使用率并在超阈值后执行清理
- `swap-cleanup.service` - swap 自动清理 systemd 服务
- `swap-cleanup.timer` - swap 自动清理定时器（默认 1 分钟一次）
- `install_swap_cleanup.sh` - 安装 swap 自动清理服务
- `cache_cleanup.sh` - 监控内存占用并在压力过大时回收缓存
- `cache-cleanup.service` - 缓存清理 systemd 服务
- `cache-cleanup.timer` - 缓存清理定时器（默认 15 分钟一次）
- `install_cache_cleanup.sh` - 安装缓存清理服务
- `top_mem_processes.sh` - 查看占用内存最多的进程
- `interactive_mem_cleanup.sh` - **交互式内存清理工具**（一键分析并kill进程）

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
sudo chmod +x /opt/swap-cleanup-tool/swap_cleanup.sh

# 2. 安装systemd服务
sudo cp swap-cleanup.service /etc/systemd/system/
sudo cp swap-cleanup.timer /etc/systemd/system/

# 3. 启用并启动服务
sudo systemctl daemon-reload
sudo systemctl enable swap-cleanup.timer
sudo systemctl start swap-cleanup.timer
```

## 使用方法

### 交互式内存清理（推荐）

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

### 查看状态
```bash
# 查看定时器状态
systemctl status swap-cleanup.timer

# 查看服务日志
journalctl -u swap-cleanup.service

# 查看最近的日志
sudo tail -f /var/log/swap_cleanup.log
```

### 手动测试
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

# 停止服务
sudo systemctl stop swap-cleanup.timer
sudo systemctl disable swap-cleanup.timer

# 删除文件
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
OnUnitActiveSec=5min  # 默认5分钟，可以修改为其他值如10min、1h等
```

修改后需要重新加载配置：
```bash
sudo systemctl daemon-reload
sudo systemctl restart swap-cleanup.timer
```

## 日志位置

- 系统日志: `journalctl -u swap-cleanup.service`
- 应用日志: `/var/log/swap_cleanup.log`

## 注意事项

1. 清理过程中会短暂关闭swap，可能影响系统性能
2. 确保系统有足够的物理内存支持清理过程
3. 建议在测试环境先验证后再部署到生产环境
4. 脚本需要root权限运行
