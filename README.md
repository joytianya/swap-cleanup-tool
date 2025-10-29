# Swap Cleanup Tool

自动监控和清理swap使用率的工具，当swap使用率超过80%时自动执行清理操作。

## 文件说明

- `swap_cleanup.sh` - 自动监控脚本，负责监控swap使用率和自动执行清理
- `interactive_cleanup.sh` - 交互式内存释放工具，支持手动选择清理选项
- `swap-cleanup.service` - systemd服务文件
- `swap-cleanup.timer` - systemd定时器文件，每1分钟检查一次
- `install_swap_cleanup.sh` - 一键安装脚本

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

### 交互式内存释放（推荐）

使用交互式工具可以手动选择清理选项:

```bash
sudo ./interactive_cleanup.sh
```

**功能特性:**
- 实时显示内存和Swap使用状态
- 支持多种清理选项:
  1. 清理页面缓存 (Page Cache)
  2. 清理目录项和inode缓存 (Dentries & Inodes)
  3. 清理所有缓存 (All Caches)
  4. 清理Swap
  5. 清理所有 (缓存 + Swap)
  6. 显示内存状态
- 彩色输出,清晰易读
- 所有操作记录到日志文件

### 查看状态
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