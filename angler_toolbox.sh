#!/bin/bash

# 钓鱼佬的工具箱 - SillyTavern Termux 管理脚本
# 作者: 10091009mc
# 版本: v1.3.0

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
SCRIPT_VERSION="v1.3.0"
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
    DEPENDENCIES=("curl" "git" "node" "python" "tar" "jq" "lsof" "fuser" "pgrep")
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
        pkg update && pkg install curl git nodejs python build-essential tar jq lsof psmisc procps -y
        
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

# 重新安装依赖 (修复 npm install 失败)
function reinstall_dependencies() {
    if [ ! -d "$ST_DIR" ]; then
        print_error "SillyTavern 未安装，请先安装。"
        return
    fi
    
    print_warn "此操作将重新下载并安装 SillyTavern 的运行依赖 (node_modules)。"
    print_warn "如果之前的安装失败或启动报错，可以尝试此操作。"
    read -p "确认继续吗? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_info "操作已取消。"
        return
    fi

    cd "$ST_DIR" || exit
    
    if [ -d "node_modules" ]; then
        print_info "正在清理旧的依赖文件..."
        rm -rf node_modules
    fi
    
    print_info "正在执行 npm install (这可能需要几分钟)..."
    if npm install; then
        print_info "依赖重新安装成功！"
    else
        print_error "依赖安装失败。请检查网络连接，或尝试更换 npm 源。"
    fi
}

# 检查并清理端口占用
function check_port() {
    local port=8000
    # 检查端口是否被占用
    # 尝试多种方式获取 PID，以兼容不同环境
    local pids=""
    
    # 方法 0: fuser (通常很可靠，需要 psmisc)
    if command -v fuser &> /dev/null; then
        pids=$(fuser $port/tcp 2>/dev/null)
    fi

    # 方法 1: lsof -t
    if [ -z "$pids" ] && command -v lsof &> /dev/null; then
        pids=$(lsof -t -i :$port 2>/dev/null)
    fi
    
    # 方法 2: netstat (如果 lsof 没找到或者没装)
    if [ -z "$pids" ] && command -v netstat &> /dev/null; then
        # netstat -nlp | grep :8000
        # 使用 grep -E 匹配 :8000 后跟空格或行尾，防止匹配到 80000
        pids=$(netstat -nlp 2>/dev/null | grep -E ":$port[[:space:]]" | awk '{print $7}' | cut -d'/' -f1 | sort -u)
    fi

    # 方法 3: ss (作为备选)
    if [ -z "$pids" ] && command -v ss &> /dev/null; then
        # ss -lptn 'sport = :8000'
        pids=$(ss -lptn "sport = :$port" 2>/dev/null | grep "pid=" | sed 's/.*pid=\([0-9]*\).*/\1/' | sort -u)
    fi
    
    # 方法 4: 进程名匹配 (兜底方案)
    # 如果端口检查都失败了，但用户认为有占用，检查是否有 server.js 在运行
    if [ -z "$pids" ]; then
        if command -v pgrep &> /dev/null; then
            local node_pids=$(pgrep -f "server.js")
            if [ -n "$node_pids" ]; then
                 print_warn "未直接检测到端口 $port 占用，但发现正在运行的 'server.js' 进程。"
                 print_warn "这可能是 SillyTavern 进程。"
                 pids="$node_pids"
            fi
        fi
    fi

    if [ -n "$pids" ]; then
        # 规范化 PID 列表 (将换行符转为空格)
        pids=$(echo "$pids" | tr '\n' ' ' | xargs)
        
        print_warn "检测到可能占用端口或相关的进程。"
        echo -e "${YELLOW}进程 PID: $pids${NC}"
        
        # 尝试显示详细信息
        if command -v lsof &> /dev/null; then
            lsof -i :$port 2>/dev/null
        elif command -v netstat &> /dev/null; then
            netstat -nlp 2>/dev/null | grep -E ":$port[[:space:]]"
        fi
        
        read -p "是否尝试终止这些进程以释放端口? (y/n): " choice
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            for pid in $pids; do
                if [ -n "$pid" ]; then
                    print_info "正在终止进程 $pid ..."
                    kill -9 "$pid" 2>/dev/null
                fi
            done
            sleep 1
            # 再次检查
            local still_occupied=0
            if (command -v lsof >/dev/null && lsof -i :$port > /dev/null 2>&1); then still_occupied=1; fi
            if (command -v netstat >/dev/null && netstat -nlp | grep -q -E ":$port[[:space:]]"); then still_occupied=1; fi
            if (command -v pgrep >/dev/null && pgrep -f "server.js" >/dev/null); then still_occupied=1; fi

            if [ $still_occupied -eq 1 ]; then
                 print_error "清理可能未完全成功，请重试或手动检查。"
                 return 1
            else
                print_info "清理操作已执行。"
                return 0
            fi
        else
            print_info "跳过端口清理。"
            return 1
        fi
    else
        print_info "端口 $port 未被占用，也未发现 server.js 进程。"
    fi
    return 0
}

# 手动检查端口菜单项
function manual_check_port() {
    check_port
    read -p "按回车键继续..."
}

# 播放静音音频保活
function start_silent_audio() {
    if ! command -v termux-media-player &> /dev/null; then
        print_warn "未检测到 termux-media-player，正在安装 Termux API..."
        pkg install termux-api -y
    fi

    print_warn "⚠️  注意：此功能需要手机安装 'Termux:API' APP 才能生效！"
    print_warn "如果未安装，请前往 F-Droid 下载安装 Termux:API 应用。"
    
    # 检查是否已在播放
    if pgrep -f "termux-media-player" > /dev/null; then
        print_warn "静音音频似乎已在运行。"
        read -p "是否重新启动? (y/n): " choice
        if [[ "$choice" != "y" && "$choice" != "Y" ]]; then return; fi
        pkill -f "termux-media-player"
    fi

    print_info "正在下载 0分贝静音音频..."
    # 下载一个极小的静音文件
    SILENT_MP3="$HOME/.silent_audio.mp3"
    if [ ! -f "$SILENT_MP3" ]; then
        # 使用 base64 生成一个最小的 mp3 文件 (1秒静音)
        echo "SUQzBAAAAAAAI1RTU0UAAAAPAAADTGF2ZjU4LjI5LjEwMAAAAAAAAAAAAAAA//uQZAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAWgAAAA0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAtL//uQZAAAAAAA0AAAAAAAAAAAAAABAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP/7kGQAAAAAADQAAAAAAAAAAAAAAEAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" | base64 -d > "$SILENT_MP3"
    fi
    
    print_info "正在后台循环播放静音音频..."
    # 后台循环播放
    (while true; do termux-media-player play "$SILENT_MP3"; sleep 1; done) &
    
    print_info "已开启！这将强制系统认为 Termux 正在播放媒体，从而防止杀后台。"
    print_warn "注意：这可能会稍微增加耗电量。"
}

# 停止静音音频
function stop_silent_audio() {
    print_info "正在停止静音音频..."
    pkill -f "termux-media-player"
    # 同时也杀掉循环脚本的子shell (可能需要更精确的匹配，这里简单处理)
    # 实际上上面的 while loop 是在子 shell 中运行，直接 kill 掉 termux-media-player 可能不够
    # 但通常用户重启 Termux 也就没了。这里做个简单的清理。
    print_info "已停止。"
}

# 显示其他保活建议
function show_other_keep_alive_tips() {
    clear
    echo -e "${YELLOW}=== 其他无需电脑的保活技巧 ===${NC}"
    echo ""
    echo -e "${GREEN}1. 锁定后台任务 (最近任务锁)${NC}"
    echo "   - 打开手机的'最近任务'界面 (多任务界面)"
    echo "   - 找到 Termux，长按或点击菜单键"
    echo "   - 选择 '锁定' 或 '加锁' (通常显示为一个小锁头图标)"
    echo "   - 这样一键清理后台时就不会杀掉 Termux"
    echo ""
    echo -e "${GREEN}2. 开启悬浮窗权限${NC}"
    echo "   - 部分系统 (如 MIUI/HyperOS) 对拥有悬浮窗权限的应用更宽容"
    echo "   - 前往 系统设置 -> 应用管理 -> Termux -> 权限 -> 悬浮窗/显示在其他应用上层 -> 允许"
    echo ""
    echo -e "${GREEN}3. 开启通知权限${NC}"
    echo "   - 确保 Termux 的通知权限已开启，且不要屏蔽 'Wake lock' 通知"
    echo "   - 前台服务通知是 Android 系统判断应用是否活跃的重要依据"
    echo ""
    echo -e "${GREEN}4. 允许自启动 (部分国产ROM)${NC}"
    echo "   - 前往 手机管家/安全中心 -> 应用管理 -> 权限 -> 自启动管理"
    echo "   - 找到 Termux 并允许自启动"
    echo ""
}

# 防杀后台保活菜单
function keep_alive_menu() {
    while true; do
        clear
        echo -e "${CYAN}====================================================${NC}"
        echo -e "${BOLD}${PURPLE} 🛡️  防杀后台保活 (Keep Alive) ${NC}"
        echo -e "${CYAN}====================================================${NC}"
        echo -e "${BLUE}说明: 针对 Android 系统杀后台严重的解决方案${NC}"
        echo -e "${YELLOW}注意: 全部方法来自AI，每个人手机不同，无法逐一测试。${NC}"
        echo -e "${CYAN}----------------------------------------------------${NC}"
        
        echo -e " ${GREEN}1.${NC} 开启唤醒锁 (Wake Lock)"
        echo -e "    - 防止手机休眠导致 Termux 停止运行 (推荐)"
        echo -e " ${GREEN}2.${NC} 释放唤醒锁 (Release Lock)"
        echo -e "    - 关闭唤醒锁，允许手机正常休眠"
        echo -e " ${GREEN}3.${NC} 播放静音音频保活 (0dB Audio)"
        echo -e "    - 欺骗系统正在播放音乐，强力防杀 (无需电脑)"
        echo -e " ${GREEN}4.${NC} 停止静音音频"
        echo -e "    - 停止后台播放"
        echo -e " ${GREEN}5.${NC} 打开电池优化设置"
        echo -e "    - 手动将 Termux 设置为'不优化'/'无限制'"
        echo -e " ${GREEN}6.${NC} 其他保活技巧 (无需电脑)"
        echo -e "    - 任务锁定、悬浮窗、自启动等设置指南"
        echo -e " ${GREEN}7.${NC} 返回上一级"
        
        echo -e "${CYAN}====================================================${NC}"
        read -p " 请输入选项 [1-7]: " choice
        
        case $choice in
            1)
                print_info "正在申请唤醒锁..."
                termux-wake-lock
                print_info "已开启！通知栏应显示 'Termux - Wake lock held'。"
                read -p "按回车键继续..."
                ;;
            2)
                print_info "正在释放唤醒锁..."
                termux-wake-unlock
                print_info "已释放。"
                read -p "按回车键继续..."
                ;;
            3)
                start_silent_audio
                read -p "按回车键继续..."
                ;;
            4)
                stop_silent_audio
                read -p "按回车键继续..."
                ;;
            5)
                print_info "正在尝试打开电池优化设置..."
                print_warn "请在列表中找到 Termux，并设置为 '不优化' 或 '无限制'。"
                # 尝试通用的电池优化设置 Intent
                am start -a android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS 2>/dev/null || \
                am start -a android.settings.BATTERY_SAVER_SETTINGS 2>/dev/null || \
                print_error "无法自动打开设置页面，请手动前往系统设置 -> 应用 -> Termux -> 电池。"
                read -p "按回车键继续..."
                ;;
            6)
                show_other_keep_alive_tips
                read -p "按回车键继续..."
                ;;
            7) return ;;
            *) print_error "无效选项"; read -p "按回车键继续..." ;;
        esac
    done
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
    # 先清理旧配置，防止重复
    disable_autostart

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
if [ -z "$TMUX" ] && [ -z "$ANGLER_SESSION_GUARD" ]; then
    export ANGLER_SESSION_GUARD=1
    if [ -f "$HOME/angler_toolbox.sh" ]; then
        exec bash "$HOME/angler_toolbox.sh"
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
    
    CONFIG_FILES=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile" "$HOME/.zprofile" "$HOME/.bash_login")

    for RC_FILE in "${CONFIG_FILES[@]}"; do
        if [ -f "$RC_FILE" ]; then
            local modified=0
            
            # 1. 删除标记块
            if grep -q "$START_MARKER" "$RC_FILE" 2>/dev/null; then
                sed -i "/$START_MARKER/,/$END_MARKER/d" "$RC_FILE"
                print_info "已从 $RC_FILE 中移除标准自启配置。"
                modified=1
            fi
            
            # 2. 清理残留的旧版启动命令 (防止重复/双重启动)
            # 查找包含 angler_toolbox.sh 的行，且不是注释行(虽然 sed 会删掉整行)
            if grep -q "angler_toolbox.sh" "$RC_FILE" 2>/dev/null; then
                # 备份文件
                cp "$RC_FILE" "${RC_FILE}.bak_$(date +%s)"
                # 删除包含脚本名的行
                sed -i '/angler_toolbox.sh/d' "$RC_FILE"
                print_warn "已清理 $RC_FILE 中的残留启动命令 (已备份)。"
                modified=1
            fi
            
            if [ $modified -eq 0 ]; then
                print_info "$RC_FILE 中未发现自启配置。"
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

# 运行 Foxium 工具箱
function run_foxium() {
    print_info "正在下载 Foxium 工具箱..."
    print_info "Foxium 工具箱是来自橘狐宝宝的【酒馆多功能修复/优化/备份小工具】"
    cd "$HOME" || exit
    if curl -O -s https://raw.githubusercontent.com/dz114879/ST-foxium/refs/heads/main/foxium.sh; then
        print_info "下载成功，正在启动..."
        bash foxium.sh
    else
        print_error "下载失败，请检查网络连接。"
        read -p "按回车键继续..."
    fi
}

# 主菜单
function main_menu() {
    while true; do
        clear
        # 检查自启状态
        AUTOSTART_STATUS="${RED}OFF${NC}"
        if grep -q "# BEGIN ANGLER_TOOLBOX_AUTOSTART" "$HOME/.bashrc" 2>/dev/null; then
            AUTOSTART_STATUS="${GREEN}ON${NC}"
        elif [ -f "$HOME/.zshrc" ] && grep -q "# BEGIN ANGLER_TOOLBOX_AUTOSTART" "$HOME/.zshrc" 2>/dev/null; then
            AUTOSTART_STATUS="${GREEN}ON (zsh)${NC}"
        fi

        # 使用简单的 ASCII 艺术字，避免特殊字符导致的乱码
        echo -e "${CYAN}"
        echo "    _                _           "
        echo "   / \   _ __   __ _| | ___ _ __ "
        echo "  / _ \ | '_ \ / _\` | |/ _ \ '__|"
        echo " / ___ \| | | | (_| | |  __/ |   "
        echo "/_/   \_\_| |_|\__, |_|\___|_|   "
        echo "               |___/             "
        echo -e "${NC}"

        echo -e "${CYAN}====================================================${NC}"
        echo -e "${BOLD}${PURPLE} 🎣 钓鱼佬的工具箱 (Angler's Toolbox) ${NC} ${YELLOW}${SCRIPT_VERSION}${NC}"
        echo -e "${CYAN}====================================================${NC}"
        echo -e "${BLUE} 作者: 10091009mc${NC}"
        echo -e "${RED} ⚠️  警告: 不要买任何贩子的模型API，都是骗人的！${NC}"
        echo -e "${RED} ⚠️  声明: 本脚本完全免费，禁止商业化使用！${NC}"
        echo -e "${CYAN}----------------------------------------------------${NC}"
        
        echo -e "${BOLD}${BLUE}【 🚀 核心功能 】${NC}"
        echo -e " ${GREEN}1.${NC} 启动 SillyTavern       ${GREEN}2.${NC} 安装 SillyTavern"
        echo -e " ${GREEN}3.${NC} 更新 SillyTavern       ${GREEN}4.${NC} 版本回退/切换"
        
        echo -e "\n${BOLD}${BLUE}【 🛠️  维护与修复 】${NC}"
        echo -e " ${GREEN}5.${NC} 重装依赖 (Fix npm)     ${GREEN}6.${NC} 备份与恢复"
        echo -e " ${GREEN}7.${NC} 端口检查与清理"
        
        echo -e "\n${BOLD}${BLUE}【 ⚙️  工具箱设置 】${NC}"
        echo -e " ${GREEN}8.${NC} 防杀后台保活         ${GREEN}9.${NC} 更新此脚本"
        echo -e " ${GREEN}10.${NC} 开机自启 [${AUTOSTART_STATUS}]    ${GREEN}11.${NC} 卸载管理"
        echo -e " ${GREEN}12.${NC} 运行 Foxium 工具箱"
        
        echo -e "\n${CYAN}----------------------------------------------------${NC}"
        echo -e "${YELLOW}提示: 若遇到脚本需退出两次才能关闭，请尝试先关闭再重新开启[开机自启]功能。${NC}"
        echo -e " ${GREEN}0.${NC} 退出脚本"
        echo -e "${CYAN}====================================================${NC}"
        
        read -p " 请输入选项 [0-12]: " option
        
        case $option in
            1) start_st; read -p "按回车键继续..." ;;
            2) install_st; read -p "按回车键继续..." ;;
            3) update_st; read -p "按回车键继续..." ;;
            4) rollback_st; read -p "按回车键继续..." ;;
            5) reinstall_dependencies; read -p "按回车键继续..." ;;
            6) backup_restore_menu ;;
            7) manual_check_port ;;
            8) keep_alive_menu ;;
            9) update_self; read -p "按回车键继续..." ;;
            10) toggle_autostart; read -p "按回车键继续..." ;;
            11) uninstall_menu; read -p "按回车键继续..." ;;
            12) run_foxium ;;
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
    
    # 检查是否存在重复配置 (导致需要退出两次的问题)
    # 统计所有配置文件中出现的次数
    local total_count=0
    for f in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile" "$HOME/.zprofile" "$HOME/.bash_login"; do
        if [ -f "$f" ]; then
            count=$(grep -c "angler_toolbox.sh" "$f" 2>/dev/null)
            total_count=$((total_count + count))
        fi
    done

    # 标准配置只在 .bashrc (或 .zshrc) 中有2处引用 (if check 和 bash run)
    # 如果总数超过2，说明可能有多个文件都配置了启动，或者同一个文件配置了多次
    if [ "$total_count" -gt 2 ] || ([ $IS_ENABLED -eq 0 ] && [ "$total_count" -gt 0 ]); then
        echo ""
        print_warn "检测到自启配置可能存在重复或旧版本残留 (发现 $total_count 处引用)。"
        print_warn "这可能导致需要连续退出两次脚本的问题。"
        read -p "是否尝试自动修复并重新开启自启? (y/n): " fix_choice
        if [[ "$fix_choice" == "y" || "$fix_choice" == "Y" ]]; then
            enable_autostart
            print_info "修复完成！"
            return
        fi
    fi

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