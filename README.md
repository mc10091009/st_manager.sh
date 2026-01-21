# SillyTavern Termux 一键管理脚本

> **作者**: 10091009mc
>
> **警告**: 不要买任何贩子的模型api都是骗人的。
>
> **声明**: 反对商业化使用，此脚本是免费的，不会收费。

这是一个专为 Android Termux 用户设计的 SillyTavern
(酒馆) 管理脚本。它提供了一个简单的菜单界面，帮助你轻松安装、更新、启动和回退 SillyTavern 版本。

## 功能特点

- **环境自动配置**: 脚本启动时会自动更新 Termux 并安装所有必要依赖 (Node.js, Git, Python 等)，无需手动敲命令配置环境。
- **一键安装**: 自动克隆 SillyTavern 仓库并完成安装。
- **一键更新**: 支持更新到最新版 (Latest) 或指定版本号 (Tag)，更新前会自动询问是否备份。
- **一键启动**: 快速启动 SillyTavern 服务。
- **版本切换/回退**: 支持按版本号 (Tag) 或 Commit Hash 切换版本，方便回退到稳定版。
- **数据备份**: 一键备份 `public`、`data` 目录和 `config.yaml` 到 `~/st_backups`，防止数据丢失。

## 使用方法

### 1. 准备工作

确保你已经安装了 [Termux](https://github.com/termux/termux-app/releases) (建议从 F-Droid 或 GitHub 下载，不要使用 Google
Play 版本)。

**注意：** 你不需要手动安装 Node.js 或 Git，脚本会自动为你处理好一切。

### 2. 一键运行

在 Termux 中复制并运行以下命令（请将 URL 替换为你实际上传后的 GitHub Raw 文件链接）：

**使用 curl (推荐):**

```bash
bash <(curl -s https://raw.githubusercontent.com/mc10091009/st_manager.sh/refs/heads/main/st_manager.sh)
```

**或者手动下载运行:**

```bash
# 下载脚本
curl -O https://raw.githubusercontent.com/你的用户名/你的仓库名/main/st_manager.sh

# 赋予执行权限
chmod +x st_manager.sh

# 运行脚本
./st_manager.sh
```

## 菜单说明

运行脚本后，你将看到以下菜单：

1. **启动 SillyTavern**: 启动服务，启动后在浏览器访问 `http://127.0.0.1:8000`。
2. **安装 SillyTavern**: 首次使用请选择此项。
3. **更新 SillyTavern**: 更新到最新版或指定版本，操作前可选择备份。
4. **版本回退/切换**: 切换到指定 Tag 或 Commit，操作前可选择备份。
5. **备份数据**: 手动备份关键数据到 `~/st_backups` 目录。
6. **Foxium 工具箱**: 运行 Foxium 修复/优化工具 (来自橘狐宝宝的工具)。
7. **更新此脚本**: 更新脚本自身到最新版。
8. **退出**: 退出脚本。

## 注意事项

- **备份重要性**: 在进行更新或回退操作前，脚本会提示备份。强烈建议选择 `y` 进行备份，以防数据丢失。
- 脚本默认将 SillyTavern 安装在 `~/SillyTavern` 目录下。
- 如果遇到网络问题导致下载失败，请尝试开启魔法上网或更换网络环境。

## License

**Non-Commercial License**

本脚本仅供个人学习和非商业用途使用。禁止将本脚本用于任何商业目的，包括但不限于出售、捆绑销售或作为付费服务的一部分。
