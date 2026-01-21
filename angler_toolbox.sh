#!/bin/bash

# 钓鱼佬的工具箱 - SillyTavern Termux 管理脚本
# 作者: 10091009mc
# 版本: v1.2.0

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 默认安装目录
ST_DIR="$HOME/SillyTavern"
REPO_URL="https://github.com/SillyTavern/SillyTavern.git"
BACKUP_DIR="$HOME/st_backups"
SCRIPT_VERSION="v1.2.0"

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
    print_info "正在检查环境依赖..."
    
    # 检查必要命令是否存在
    DEPENDENCIES=("curl" "git" "node" "python" "jq" "unzip")
    MISSING_DEPS=()
    
    for dep in "${DEPENDENCIES[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            MISSING_DEPS+=("$dep")
        fi
    done
    
    # 如果有缺失的依赖，则进行安装
    if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
        print_warn "发现缺失依赖: ${MISSING_DEPS[*]}，正在安装..."
        
        # 更新 Termux 包
        print_info "正在更新 Termux 包 (pkg upgrade)..."
        yes | pkg upgrade
        
        # 安装依赖
        print_info "正在安装缺失依赖..."
        pkg update && pkg install curl unzip git nodejs python build-essential jq -y
        
        print_info "依赖安装完成！"
    else
        print_info "所有依赖已安装，跳过环境初始化。"
    fi
    
    # 验证 Node.js 版本
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node -v)
        print_info "Node.js 版本: $NODE_VERSION"
    else
        print_error "Node.js 安装失败，请尝试手动安装: pkg install nodejs"
        exit 1
    fi
    
    sleep 1
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

    print_info "正在备份关键数据 (data, config.yaml, 插件)..."
    
    # 进入 ST 目录进行打包，避免包含绝对路径
    cd "$ST_DIR" || exit
    
    # 准备备份列表
    BACKUP_ITEMS="data"
    
    # 检查是否存在 config.yaml
    if [ -f "config.yaml" ]; then
        BACKUP_ITEMS="$BACKUP_ITEMS config.yaml"
    fi

    # 检查是否存在第三方插件目录 (For all users)
    if [ -d "public/scripts/extensions/third-party" ]; then
        BACKUP_ITEMS="$BACKUP_ITEMS public/scripts/extensions/third-party"
    fi

    # 打包
    if tar -czf "$BACKUP_FILE" $BACKUP_ITEMS 2>/dev/null; then
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
    echo "2. 按版本号 (Tag) 切换 (推荐)"
    echo -e "${GREEN}推荐使用按版本号 (Tag) 按版本${NC}"
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

# 更新脚本自身
function update_self() {
    print_info "当前版本: $SCRIPT_VERSION"
    print_info "正在检查脚本更新..."
    # 使用用户提供的 GitHub 仓库
    SCRIPT_URL="https://raw.githubusercontent.com/mc10091009/st_manager.sh/main/angler_toolbox.sh"
    SCRIPT_NAME=$(basename "$0")
    
    if curl -s "$SCRIPT_URL" -o "${SCRIPT_NAME}.tmp"; then
        # 简单检查下载的文件是否有效
        if grep -q "#!/bin/bash" "${SCRIPT_NAME}.tmp"; then
            mv "${SCRIPT_NAME}.tmp" "$SCRIPT_NAME"
            chmod +x "$SCRIPT_NAME"
            print_info "脚本更新成功！正在重启..."
            # 传递参数 --skip-init 以跳过环境检查
            exec bash "$SCRIPT_NAME" --skip-init
        else
            rm "${SCRIPT_NAME}.tmp"
            print_error "下载的文件似乎无效，取消更新。"
        fi
    else
        print_error "下载失败，请检查网络连接。"
    fi
}

# 设置 Termux 启动时自动运行脚本
function setup_autostart() {
    BASHRC="$HOME/.bashrc"
    SCRIPT_PATH=$(realpath "$0")
    
    # 检查是否已经添加
    if grep -q "bash $SCRIPT_PATH" "$BASHRC"; then
        print_warn "已设置自动启动，正在取消..."
        # 使用 sed 删除包含脚本路径的行
        sed -i "\|bash $SCRIPT_PATH|d" "$BASHRC"
        print_info "已取消自动启动。"
    else
        print_info "正在设置 Termux 启动时自动运行此脚本..."
        echo "" >> "$BASHRC"
        echo "# Auto-start Angler's Toolbox" >> "$BASHRC"
        echo "if [ -z \"\$TMUX\" ]; then" >> "$BASHRC"
        echo "    bash $SCRIPT_PATH" >> "$BASHRC"
        echo "fi" >> "$BASHRC"
        print_info "设置成功！下次打开 Termux 时将自动运行此脚本。"
    fi
}

# 运行 Foxium 工具箱
function run_foxium() {
    print_info "准备启动 Foxium 工具箱..."
    print_warn "注意：需要挂梯子 (VPN) 才能使用。"
    print_warn "注意：Foxium 是第三方脚本，将下载到 HOME 目录并运行。"
    
    read -p "是否继续? (y/n): " choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        # 确保在 HOME 目录，确保在酒馆目录外面
        cd "$HOME" || exit
        
        print_info "正在下载并运行 Foxium..."
        curl -O -s https://raw.githubusercontent.com/dz114879/ST-foxium/refs/heads/main/foxium.sh && bash foxium.sh
    else
        print_info "已取消。"
    fi
}

# 主菜单
function main_menu() {
    while true; do
        clear
        echo -e "${GREEN}=========================================${NC}"
        echo -e "${GREEN}    钓鱼佬的工具箱 - ST 管理脚本         ${NC}"
        echo -e "${GREEN}    作者: 10091009mc   版本: ${SCRIPT_VERSION}      ${NC}"
        echo -e "${GREEN}=========================================${NC}"
        echo -e "${RED}${BOLD}警告: 不要买任何贩子的模型api都是骗人的${NC}"
        echo -e "${RED}${BOLD}警告: 反对商业化使用，此脚本是免费的，不会收费${NC}"
        echo -e "${GREEN}=========================================${NC}"
        echo "1. 启动 SillyTavern"
        echo "2. 安装 SillyTavern"
        echo "3. 更新 SillyTavern"
        echo "4. 版本回退/切换"
        echo "5. 备份数据"
        echo "6. 更新此脚本"
        echo "7. 设置/取消 开机自启"
        echo "8. Foxium 工具箱 (修复/优化/备份)"
        echo "9. 退出"
        echo ""
        read -p "请输入选项 [1-9]: " option
        
        case $option in
            1) start_st; read -p "按回车键继续..." ;;
            2) install_st; read -p "按回车键继续..." ;;
            3) update_st; read -p "按回车键继续..." ;;
            4) rollback_st; read -p "按回车键继续..." ;;
            5) backup_data; read -p "按回车键继续..." ;;
            6) update_self; read -p "按回车键继续..." ;;
            7) setup_autostart; read -p "按回车键继续..." ;;
            8) run_foxium; read -p "按回车键继续..." ;;
            9) exit 0 ;;
            *) print_error "无效选项"; read -p "按回车键继续..." ;;
        esac
    done
}

# 脚本入口
# 检查是否跳过环境初始化
if [[ "$1" != "--skip-init" ]]; then
    init_environment
fi
main_menu