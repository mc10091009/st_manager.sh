#!/bin/bash

# SillyTavern Termux 一键管理脚本
# 作者: Kilo Code (Generated for User)

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 默认安装目录
ST_DIR="$HOME/SillyTavern"
REPO_URL="https://github.com/SillyTavern/SillyTavern.git"
BACKUP_DIR="$HOME/st_backups"

# 打印信息函数
function print_info() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

function print_warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

function print_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# 初始化环境检查
function init_environment() {
    print_info "正在初始化 Termux 环境..."
    
    # 1. 更新 Termux 包
    print_info "正在更新 Termux 包 (pkg upgrade)..."
    yes | pkg upgrade
    
    # 2. 安装必要依赖
    print_info "正在安装必要依赖 (curl, git, nodejs, python, build-essential)..."
    pkg update && pkg install curl unzip git nodejs python build-essential jq -y
    
    # 3. 验证 Node.js 版本
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node -v)
        print_info "Node.js 已安装: $NODE_VERSION"
    else
        print_error "Node.js 安装失败，请尝试手动安装: pkg install nodejs"
        exit 1
    fi
    
    print_info "环境初始化完成！"
    sleep 2
}

# 备份数据
function backup_data() {
    if [ ! -d "$ST_DIR" ]; then
        print_error "SillyTavern 未安装，无法备份。"
        return
    fi

    mkdir -p "$BACKUP_DIR"
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="$BACKUP_DIR/st_backup_$TIMESTAMP.tar.gz"

    print_info "正在备份关键数据 (public, data, config.yaml)..."
    
    # 进入 ST 目录进行打包，避免包含绝对路径
    cd "$ST_DIR" || exit
    
    # 检查是否存在 config.yaml
    CONFIG_FILE=""
    if [ -f "config.yaml" ]; then
        CONFIG_FILE="config.yaml"
    fi

    # 打包 public, data 和 config.yaml (如果存在)
    if tar -czf "$BACKUP_FILE" public data $CONFIG_FILE 2>/dev/null; then
        print_info "备份成功！文件已保存至: $BACKUP_FILE"
    else
        print_error "备份失败！"
    fi
}

# 询问是否备份
function ask_backup() {
    read -p "操作前是否需要备份数据? (y/n, 默认 y): " choice
    choice=${choice:-y}
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        backup_data
    fi
}

# 安装 SillyTavern
function install_st() {
    if [ -d "$ST_DIR" ]; then
        print_warn "SillyTavern 目录已存在: $ST_DIR"
        read -p "是否删除旧目录并重新安装? (y/n): " choice
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            print_info "正在删除旧目录..."
            rm -rf "$ST_DIR"
        else
            print_info "取消安装。"
            return
        fi
    fi
    
    # 环境已在启动时检查，此处再次确认以防万一
    if ! command -v git &> /dev/null; then
        print_warn "Git 未找到，尝试重新安装..."
        pkg install git -y
    fi
    
    print_info "正在克隆 SillyTavern 仓库..."
    if git clone "$REPO_URL" "$ST_DIR"; then
        print_info "克隆成功！"
    else
        print_error "克隆失败，请检查网络连接。"
        return
    fi
    
    cd "$ST_DIR" || exit
    print_info "正在安装 npm 依赖 (这可能需要一些时间)..."
    npm install
    
    print_info "安装完成！你可以选择 '启动 SillyTavern' 来运行。"
}

# 更新 SillyTavern
function update_st() {
    if [ ! -d "$ST_DIR" ]; then
        print_error "SillyTavern 未安装，请先安装。"
        return
    fi
    
    ask_backup

    cd "$ST_DIR" || exit
    print_info "正在拉取最新代码..."
    git fetch --all

    echo "1. 更新到最新版 (Latest)"
    echo "2. 选择版本号/Tag (Select Tag)"
    read -p "请选择更新方式 [1-2]: " update_choice

    if [[ "$update_choice" == "2" ]]; then
        echo -e "${YELLOW}最近的 10 个版本号 (Tags)：${NC}"
        git tag --sort=-creatordate | head -n 10
        echo ""
        read -p "请输入要切换的版本号 (例如 1.10.0): " target_tag
        if [ -z "$target_tag" ]; then
            print_error "输入为空，取消操作。"
            return
        fi
        target_ref="tags/$target_tag"
    else
        target_ref="origin/release" # 默认更新到 release 分支，通常比 main 稳定，或者根据需求改为 main
        # 检查 release 分支是否存在，不存在则使用 main
        if ! git show-ref --verify --quiet refs/remotes/origin/release; then
             target_ref="origin/main"
        fi
    fi
    
    print_info "正在更新到 $target_ref ..."
    if git reset --hard "$target_ref"; then
        print_info "代码更新成功，正在更新依赖..."
        npm install
        print_info "更新完成！"
    else
        print_error "更新失败，请检查网络或版本号是否正确。"
    fi
}

# 版本回退/切换
function rollback_st() {
    if [ ! -d "$ST_DIR" ]; then
        print_error "SillyTavern 未安装，请先安装。"
        return
    fi
    
    ask_backup

    cd "$ST_DIR" || exit
    print_info "正在获取版本记录..."
    git fetch --all
    
    echo "1. 按 Commit Hash 回退"
    echo "2. 按版本号 (Tag) 切换"
    read -p "请选择方式 [1-2]: " rb_choice

    if [[ "$rb_choice" == "2" ]]; then
        echo -e "${YELLOW}最近的 10 个版本号 (Tags)：${NC}"
        git tag --sort=-creatordate | head -n 10
        echo ""
        read -p "请输入要切换的版本号 (例如 1.10.0): " target
        if [ -z "$target" ]; then print_error "输入为空"; return; fi
        target="tags/$target"
    else
        echo -e "${YELLOW}最近的 10 个提交记录：${NC}"
        git log -n 10 --oneline
        echo ""
        read -p "请输入 Commit Hash (例如 a1b2c3d): " target
        if [ -z "$target" ]; then print_error "输入为空"; return; fi
    fi
    
    print_info "正在切换到 $target ..."
    if git reset --hard "$target"; then
        print_info "切换成功！正在重新安装依赖..."
        npm install
        print_info "操作完成！"
    else
        print_error "切换失败，请检查输入是否正确。"
    fi
}

# 启动 SillyTavern
function start_st() {
    if [ ! -d "$ST_DIR" ]; then
        print_error "SillyTavern 未安装，请先安装。"
        return
    fi
    
    cd "$ST_DIR" || exit
    print_info "正在启动 SillyTavern..."
    node server.js
}

# 主菜单
function main_menu() {
    while true; do
        clear
        echo -e "${GREEN}=========================================${NC}"
        echo -e "${GREEN}    SillyTavern Termux 一键管理脚本      ${NC}"
        echo -e "${GREEN}=========================================${NC}"
        echo "1. 安装 SillyTavern (Install)"
        echo "2. 更新 SillyTavern (Update)"
        echo "3. 启动 SillyTavern (Start)"
        echo "4. 版本回退/切换 (Rollback/Switch)"
        echo "5. 备份数据 (Backup)"
        echo "6. 退出 (Exit)"
        echo ""
        read -p "请输入选项 [1-6]: " option
        
        case $option in
            1) install_st; read -p "按回车键继续..." ;;
            2) update_st; read -p "按回车键继续..." ;;
            3) start_st; read -p "按回车键继续..." ;;
            4) rollback_st; read -p "按回车键继续..." ;;
            5) backup_data; read -p "按回车键继续..." ;;
            6) exit 0 ;;
            *) print_error "无效选项"; read -p "按回车键继续..." ;;
        esac
    done
}

# 脚本入口
# 脚本入口
# 首次运行或每次运行时检查环境
init_environment
main_menu