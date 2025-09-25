# GitHub 项目创建指南

## 1. 在 GitHub 上创建新的 Repository

1. 访问 https://github.com/joytianya
2. 点击 "New" 或 "Create repository"
3. 填写以下信息：
   - **Repository name**: `swap-cleanup-tool`
   - **Description**: `Automatic swap usage monitoring and cleanup tool for Linux systems`
   - **Visibility**: Public (推荐) 或 Private
   - **不要** 勾选 "Add a README file"、"Add .gitignore"、"Choose a license" (我们已经有了)

## 2. 推送本地代码到 GitHub

在当前目录 (`/home/zxw/projects/dev/swap-cleanup-tool/`) 执行以下命令：

```bash
# 设置远程仓库地址
git remote add origin https://github.com/joytianya/swap-cleanup-tool.git

# 推送到主分支
git branch -M main
git push -u origin main
```

## 3. 验证上传

访问 https://github.com/joytianya/swap-cleanup-tool 确认所有文件已成功上传。

## 4. 可选：添加项目标签和主题

在 GitHub 项目页面：
1. 点击齿轮图标 (Settings)
2. 在 "Topics" 部分添加标签：
   - `linux`
   - `swap`
   - `system-administration`
   - `bash`
   - `systemd`
   - `monitoring`
   - `cleanup`

## 项目结构

```
swap-cleanup-tool/
├── README.md                    # 项目说明文档
├── LICENSE                      # MIT 许可证
├── .gitignore                   # Git 忽略文件
├── swap_cleanup.sh              # 主脚本
├── swap-cleanup.service         # Systemd 服务文件
├── swap-cleanup.timer           # Systemd 定时器文件
├── install_swap_cleanup.sh      # 一键安装脚本
└── GITHUB_SETUP.md             # 本说明文件
```

## 注意事项

- 确保您有 GitHub 账户的推送权限
- 如果使用 HTTPS 推送，可能需要个人访问令牌 (Personal Access Token)
- 如果使用 SSH，确保已配置 SSH 密钥