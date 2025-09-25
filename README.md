# Swap Cleanup Tool

自动监控和清理swap使用率的工具，当swap使用率超过80%时自动执行清理操作。

## 文件说明

- `swap_cleanup.sh` - 主脚本，负责监控swap使用率和执行清理
- `swap-cleanup.service` - systemd服务文件
- `swap-cleanup.timer` - systemd定时器文件，每5分钟检查一次
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