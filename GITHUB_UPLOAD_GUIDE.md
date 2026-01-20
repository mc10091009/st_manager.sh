# 如何将脚本上传到 GitHub 并获取一键链接

按照以下步骤，你可以将 `st_manager.sh` 和 `README.md` 上传到 GitHub，并生成给别人使用的一键安装命令。

## 第一步：创建 GitHub 仓库

1.  登录 [GitHub](https://github.com/)。
2.  点击右上角的 **+** 号，选择 **New repository**。
3.  **Repository name**: 输入一个名字，例如 `st-termux-script`。
4.  **Public/Private**: 选择 **Public** (公开)，否则别人无法下载。
5.  点击 **Create repository**。

## 第二步：上传文件 (网页版简单方法)

1.  在创建好的仓库页面，点击 **Add file** -> **Upload files**。
2.  将你电脑上的 `st_manager.sh` 和 `README.md` 拖进去。
3.  在下方的 "Commit changes" 框里，直接点击 **Commit changes** 按钮。

## 第三步：获取一键安装链接

1.  在仓库文件列表中，点击 `st_manager.sh` 文件。
2.  在文件详情页右上角，点击 **Raw** 按钮。
3.  浏览器地址栏的链接就是“原始链接”，格式通常是：
    `https://raw.githubusercontent.com/你的用户名/仓库名/main/st_manager.sh`
4.  复制这个链接。

## 第四步：生成最终命令

将你复制的链接替换到下面的命令中：

```bash
bash <(curl -s 你的Raw链接)
```

例如，如果你的链接是 `https://raw.githubusercontent.com/zhangsan/st-script/main/st_manager.sh`，那么最终命令就是：

```bash
bash <(curl -s https://raw.githubusercontent.com/zhangsan/st-script/main/st_manager.sh)
```

你可以把这个最终命令发给别人，或者更新到你的 `README.md` 中。

