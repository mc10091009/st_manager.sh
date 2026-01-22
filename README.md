# 钓鱼佬的工具箱 - SillyTavern Termux 脚本

> **作者**: 10091009mc
>
> **警告**: 不要买任何贩子的模型api都是骗人的。
>
> **声明**: 反对商业化使用，此脚本是免费的，不会收费。

这是一个专为 Android Termux 用户设计的 SillyTavern (酒馆) 管理脚本。

## 🚀 快速开始

在 Termux 中复制并运行以下命令：

```bash
bash <(curl -s https://raw.githubusercontent.com/mc10091009/st_manager.sh/main/angler_toolbox.sh)
```

## ✨ 功能

- **一键安装/启动**: 自动配置环境 (Node.js, Git, jq 等) 并安装 SillyTavern。
- **版本管理**: 轻松更新、切换或回退版本。
- **数据备份**: 自动备份关键数据 (`data`, `config.yaml`, `secrets.json`, 插件) 到 `~/st_backups`。
- **开机自启**: 可设置 Termux 启动时自动运行此脚本。

## ⚠️ 注意事项

- 脚本会自动处理所有依赖，无需手动安装。
- 操作前建议使用脚本自带的备份功能。
- 仅供个人学习使用，禁止商业用途。
