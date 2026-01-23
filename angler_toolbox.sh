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
SCRIPT_URL="https://raw.githubusercontent.com/mc10091009/st_manager.sh/main/angler_toolbox.sh"

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
    DEPENDENCIES=("curl" "git" "node" "python" "tar" "jq" "lsof")
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
        pkg update && pkg install curl git nodejs python build-essential tar jq lsof -y
        
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

    # 检查是否存在 secrets.json
    if [ -f "secrets.json" ]; then
        BACKUP_ITEMS="$BACKUP_ITEMS secrets.json"
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

# 恢复数据
function restore_data() {
    if [ ! -d "$ST_DIR" ]; then
        print_error "SillyTavern 未安装，请先安装。"
        return
    fi

    print_info "正在搜索备份文件..."
    
    # 启用 nullglob 以处理没有匹配文件的情况
    shopt -s nullglob
    # 搜索 HOME 目录和备份目录下的压缩包
    local files=("$HOME"/*.tar.gz "$HOME"/*.tgz "$BACKUP_DIR"/*.tar.gz "$BACKUP_DIR"/*.tgz)
    shopt -u nullglob

    if [ ${#files[@]} -eq 0 ]; then
        print_error "未找到备份文件 (.tar.gz, .tgz)。"
        print_info "请将备份文件放入 $HOME 目录或 $BACKUP_DIR 目录。"
        return
    fi

    echo "请选择要恢复的备份文件:"
    local i=1
    for f in "${files[@]}"; do
        echo "$i. $(basename "$f")  [$(dirname "$f")]"
        ((i++))
    done

    read -p "请输入序号 (1-${#files[@]}): " choice
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#files[@]}" ]; then
        print_error "无效的选择。"
        return
    fi

    local selected_file="${files[$((choice-1))]}"
    
    print_warn "即将从 $(basename "$selected_file") 恢复数据。"
    print_warn "这将覆盖当前的 data, config.yaml 等文件！"
    read -p "确认继续吗? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_info "操作已取消。"
        return
    fi

    print_info "正在恢复..."
    
    # 确保进入 ST 目录
    cd "$ST_DIR" || exit
    
    if tar -xzf "$selected_file"; then
        print_info "恢复成功！"
        print_info "建议重启 SillyTavern 以应用更改。"
    else
        print_error "恢复失败，请检查备份文件是否损坏。"
    fi
}

# 备份与恢复菜单
function backup_restore_menu() {
    while true; do
        clear
        echo -e "${GREEN}=========================================${NC}"
        echo -e "${GREEN}         备份与恢复 (Backup & Restore)    ${NC}"
        echo -e "${GREEN}=========================================${NC}"
        echo "1. 备份数据 (Backup Data)"
        echo "   - 将 data, config.yaml 等关键文件打包备份到 $BACKUP_DIR"
        echo "2. 恢复数据 (Restore Data)"
        echo "   - 从 $HOME 或 $BACKUP_DIR 目录下的压缩包还原数据"
        echo "3. 返回上一级 (Return)"
        echo ""
        read -p "请输入选项 [1-3]: " choice
        
        case $choice in
            1) backup_data; read -p "按回车键继续..." ;;
            2) restore_data; read -p "按回车键继续..." ;;
            3) return ;;
            *) print_error "无效选项"; read -p "按回车键继续..." ;;
        esac
    done
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
    if npm install; then
        print_info "安装完成！你可以选择 '启动 SillyTavern' 来运行。"
    else
        print_error "npm 依赖安装失败，请检查网络或手动运行 'npm install'。"
    fi
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
    echo -e "${GREEN}推荐使用按版本号 (Tag) 切换版本${NC}"
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

# 检查并清理端口占用
function check_port() {
    local port=8000
    # 检查端口是否被占用
    if lsof -i :$port > /dev/null 2>&1; then
        print_warn "检测到端口 $port 被占用。"
        
        # 获取占用端口的 PID
        # lsof 输出格式: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
        # 使用 awk 提取第二列 (PID)，跳过第一行标题
        local pids=$(lsof -i :$port | awk 'NR>1 {print $2}' | sort -u)
        
        if [ -n "$pids" ]; then
            echo -e "${YELLOW}占用进程 PID: $pids${NC}"
            read -p "是否尝试终止这些进程以释放端口? (y/n): " choice
            if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
                for pid in $pids; do
                    print_info "正在终止进程 $pid ..."
                    kill -9 "$pid" 2>/dev/null
                done
                sleep 1
                # 再次检查
                if lsof -i :$port > /dev/null 2>&1; then
                    print_error "端口清理失败，请尝试手动处理。"
                    return 1
                else
                    print_info "端口已释放。"
                    return 0
                fi
            else
                print_info "跳过端口清理。"
                return 1
            fi
        fi
    fi
    return 0
}

# 启动 SillyTavern
function start_st() {
    if [ ! -d "$ST_DIR" ]; then
        print_error "SillyTavern 未安装，请先安装。"
        return
    fi
    
    # 启动前检查端口
    check_port
    
    cd "$ST_DIR" || exit

    if [ ! -d "node_modules" ]; then
        print_warn "检测到 node_modules 缺失，正在安装依赖..."
        if npm install; then
            print_info "依赖安装完成。"
        else
            print_error "依赖安装失败，无法启动。"
            return
        fi
    fi

    print_info "正在启动 SillyTavern..."
    node server.js
}

# 更新脚本自身
function update_self() {
    print_info "当前版本: $SCRIPT_VERSION"
    print_info "正在检查脚本更新..."
    # 使用用户提供的 GitHub 仓库
    SCRIPT_NAME="angler_toolbox.sh"
    TARGET_PATH="$HOME/$SCRIPT_NAME"
    
    if curl -s "$SCRIPT_URL" -o "${TARGET_PATH}.tmp"; then
        # 简单检查下载的文件是否有效
        if grep -q "#!/bin/bash" "${TARGET_PATH}.tmp"; then
            mv "${TARGET_PATH}.tmp" "$TARGET_PATH"
            chmod +x "$TARGET_PATH"
            print_info "脚本更新成功！正在重启..."
            # 传递参数 --skip-init 以跳过环境检查
            exec bash "$TARGET_PATH" --skip-init
        else
            rm "${TARGET_PATH}.tmp"
            print_error "下载的文件似乎无效，取消更新。"
        fi
    else
        print_error "下载失败，请检查网络连接。"
    fi
}

# 获取文件的绝对路径 (兼容性处理)
function get_abs_path() {
    if command -v realpath &> /dev/null; then
        realpath "$1"
    else
        readlink -f "$1"
    fi
}

# 确保 .bash_profile 存在并加载 .bashrc
function ensure_bash_profile() {
    PROFILE="$HOME/.bash_profile"
    BASHRC="$HOME/.bashrc"
    
    # 如果 .bash_profile 不存在，检查 .profile
    if [ ! -f "$PROFILE" ]; then
        if [ -f "$HOME/.profile" ]; then
            PROFILE="$HOME/.profile"
        else
            # 都不存在，创建 .bash_profile
            cat << 'EOF' > "$PROFILE"
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
EOF
            print_info "已创建 $PROFILE 并配置加载 .bashrc"
            return
        fi
    fi
    
    # 检查 PROFILE 是否加载了 .bashrc
    if ! grep -q ".bashrc" "$PROFILE"; then
        cat << 'EOF' >> "$PROFILE"

# Load .bashrc
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
EOF
        print_info "已更新 $PROFILE 以加载 .bashrc"
    fi
}

# 安装脚本到 HOME 目录
function install_script() {
    SCRIPT_NAME="angler_toolbox.sh"
    SCRIPT_PATH="$HOME/$SCRIPT_NAME"
    
    # 尝试获取当前脚本的绝对路径
    CURRENT_PATH=""
    if [ -f "$0" ]; then
        CURRENT_PATH=$(get_abs_path "$0")
    fi

    # 判断是否需要安装/复制
    # 如果当前运行的不是 HOME 下的脚本，则复制过去
    if [ "$CURRENT_PATH" != "$SCRIPT_PATH" ]; then
        # 如果当前脚本文件存在（本地运行），则复制
        if [ -f "$CURRENT_PATH" ]; then
             print_info "正在安装/更新脚本到 $SCRIPT_PATH ..."
             cp "$CURRENT_PATH" "$SCRIPT_PATH"
             chmod +x "$SCRIPT_PATH"
        # 如果当前是管道运行 (curl | bash)，且目标不存在，则下载
        elif [ ! -f "$SCRIPT_PATH" ]; then
             print_info "正在下载脚本到 $SCRIPT_PATH ..."
             if curl -s "$SCRIPT_URL" -o "$SCRIPT_PATH"; then
                 chmod +x "$SCRIPT_PATH"
             else
                 print_error "下载失败，无法安装脚本。"
             fi
        fi
    fi
}

# 开启自动启动
function enable_autostart() {
    install_script
    
    # 确保 Bash 环境下 .bash_profile 加载 .bashrc
    # Termux 默认是 Login Shell，只读取 .bash_profile / .profile
    ensure_bash_profile

    SCRIPT_NAME="angler_toolbox.sh"
    SCRIPT_PATH="$HOME/$SCRIPT_NAME"
    START_MARKER="# BEGIN ANGLER_TOOLBOX_AUTOSTART"
    END_MARKER="# END ANGLER_TOOLBOX_AUTOSTART"

    # 支持 bash 和 zsh
    CONFIG_FILES=("$HOME/.bashrc")
    if [ -f "$HOME/.zshrc" ]; then
        CONFIG_FILES+=("$HOME/.zshrc")
    fi

    for RC_FILE in "${CONFIG_FILES[@]}"; do
        # 确保文件存在
        touch "$RC_FILE"
        
        if grep -q "$START_MARKER" "$RC_FILE" 2>/dev/null; then
            print_info "自动启动已在 $RC_FILE 中开启。"
            continue
        fi

        # 使用单引号 EOF 避免变量展开，手动处理变量
        cat << 'EOF' >> "$RC_FILE"

# BEGIN ANGLER_TOOLBOX_AUTOSTART
if [ -z "$TMUX" ]; then
    if [ -f "$HOME/angler_toolbox.sh" ]; then
        bash "$HOME/angler_toolbox.sh"
    fi
fi
# END ANGLER_TOOLBOX_AUTOSTART
EOF
        print_info "已在 $RC_FILE 中开启自动启动。"
    done
}

# 关闭自动启动
function disable_autostart() {
    START_MARKER="# BEGIN ANGLER_TOOLBOX_AUTOSTART"
    END_MARKER="# END ANGLER_TOOLBOX_AUTOSTART"
    
    CONFIG_FILES=("$HOME/.bashrc" "$HOME/.zshrc")

    for RC_FILE in "${CONFIG_FILES[@]}"; do
        if [ -f "$RC_FILE" ]; then
            if grep -q "$START_MARKER" "$RC_FILE" 2>/dev/null; then
                # 使用 sed 删除标记之间的内容
                sed -i "/$START_MARKER/,/$END_MARKER/d" "$RC_FILE"
                print_info "已从 $RC_FILE 中取消自动启动。"
            fi
        fi
    done
}

# 切换自动启动状态
function toggle_autostart() {
    START_MARKER="# BEGIN ANGLER_TOOLBOX_AUTOSTART"
    IS_ENABLED=0
    
    # 检查是否在任意文件中开启
    if grep -q "$START_MARKER" "$HOME/.bashrc" 2>/dev/null; then IS_ENABLED=1; fi
    if [ -f "$HOME/.zshrc" ] && grep -q "$START_MARKER" "$HOME/.zshrc" 2>/dev/null; then IS_ENABLED=1; fi
    
    if [ $IS_ENABLED -eq 1 ]; then
        disable_autostart
    else
        enable_autostart
    fi
}

# 安全验证
function safe_verify() {
    local action="$1"
    print_warn "警告：即将执行【$action】！"
    print_warn "此操作不可逆，所有数据将会被清除，请确保你已完成备份数据操作！"
    read -p "确认要继续吗？(y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_info "操作已取消。"
        return 1
    fi

    local rand_num=$((RANDOM % 9000 + 1000))
    print_warn "二次验证：请输入随机数字 [ $rand_num ] 以确认删除："
    read -p "请输入: " input_num
    
    if [[ "$input_num" == "$rand_num" ]]; then
        return 0
    else
        print_error "验证码错误，操作已取消。"
        return 1
    fi
}

# 卸载 SillyTavern
function do_uninstall_st() {
    if [ -d "$ST_DIR" ]; then
        print_info "正在删除 SillyTavern 目录..."
        rm -rf "$ST_DIR"
        print_info "SillyTavern 已卸载。"
    else
        print_error "SillyTavern 未安装。"
    fi
}

# 执行卸载脚本
function do_uninstall_script() {
    disable_autostart
    local script_path="$HOME/angler_toolbox.sh"
    if [ -f "$script_path" ]; then
        rm "$script_path"
    fi
    print_info "脚本已卸载。再见！"
    exit 0
}

# 卸载 SillyTavern (带验证)
function uninstall_st_dir() {
    if [ ! -d "$ST_DIR" ]; then
        print_error "SillyTavern 未安装。"
        return
    fi
    
    if safe_verify "卸载 SillyTavern"; then
        do_uninstall_st
    fi
}

# 卸载脚本 (带验证)
function uninstall_script() {
    if safe_verify "卸载 Angler's Toolbox 脚本"; then
        do_uninstall_script
    fi
}

# 卸载全部
function uninstall_all() {
    if safe_verify "卸载 SillyTavern 和 管理脚本"; then
        do_uninstall_st
        do_uninstall_script
    fi
}

# 卸载管理菜单
function uninstall_menu() {
    echo "1. 卸载 SillyTavern (删除安装目录)"
    echo "2. 卸载此脚本 (删除脚本文件及自启配置)"
    echo "3. 卸载全部"
    echo "4. 返回上一级"
    read -p "请选择操作 [1-4]: " choice
    
    case $choice in
        1) uninstall_st_dir ;;
        2) uninstall_script ;;
        3) uninstall_all ;;
        4) return ;;
        *) print_error "无效选项" ;;
    esac
}

# 主菜单
function main_menu() {
    while true; do
        clear
        # 检查自启状态
        AUTOSTART_STATUS="${RED}未开启${NC}"
        if grep -q "# BEGIN ANGLER_TOOLBOX_AUTOSTART" "$HOME/.bashrc" 2>/dev/null; then
            AUTOSTART_STATUS="${GREEN}已开启${NC}"
        elif [ -f "$HOME/.zshrc" ] && grep -q "# BEGIN ANGLER_TOOLBOX_AUTOSTART" "$HOME/.zshrc" 2>/dev/null; then
            AUTOSTART_STATUS="${GREEN}已开启 (zsh)${NC}"
        fi

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
        echo "5. 备份与恢复 (Backup & Restore)"
        echo "6. 更新此脚本"
        echo -e "7. 设置开机自启 [当前: ${AUTOSTART_STATUS}]"
        echo "8. 卸载管理 (Uninstall)"
        echo "0. 退出"
        echo ""
        read -p "请输入选项 [0-8]: " option
        
        case $option in
            1) start_st; read -p "按回车键继续..." ;;
            2) install_st; read -p "按回车键继续..." ;;
            3) update_st; read -p "按回车键继续..." ;;
            4) rollback_st; read -p "按回车键继续..." ;;
            5) backup_restore_menu ;;
            6) update_self; read -p "按回车键继续..." ;;
            7) toggle_autostart; read -p "按回车键继续..." ;;
            8) uninstall_menu; read -p "按回车键继续..." ;;
            0) exit 0 ;;
            *) print_error "无效选项"; read -p "按回车键继续..." ;;
        esac
    done
}

# 首次运行检查自启
function check_first_run_autostart() {
    START_MARKER="# BEGIN ANGLER_TOOLBOX_AUTOSTART"
    IS_ENABLED=0
    if grep -q "$START_MARKER" "$HOME/.bashrc" 2>/dev/null; then IS_ENABLED=1; fi
    if [ -f "$HOME/.zshrc" ] && grep -q "$START_MARKER" "$HOME/.zshrc" 2>/dev/null; then IS_ENABLED=1; fi
    
    # 如果没有开启自启，询问用户
    if [ $IS_ENABLED -eq 0 ]; then
        echo ""
        print_info "检测到未开启开机自启。"
        read -p "是否设置 Termux 启动时自动运行此脚本? (y/n, 默认 y): " choice
        choice=${choice:-y}
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            enable_autostart
        else
            print_info "已跳过。你可以在菜单中手动开启。"
        fi
        sleep 1
    fi
}

# 脚本入口
# 检查是否跳过环境初始化
if [[ "$1" != "--skip-init" ]]; then
    init_environment
    install_script
    
    # 确保 .bash_profile 配置正确 (如果已开启自启)
    START_MARKER="# BEGIN ANGLER_TOOLBOX_AUTOSTART"
    if grep -q "$START_MARKER" "$HOME/.bashrc" 2>/dev/null; then
        ensure_bash_profile
    fi
    
    check_first_run_autostart
fi
main_menu