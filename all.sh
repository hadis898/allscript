#!/usr/bin/env bash

# 系统工具一键管理脚本
# 作者：哈迪斯
# 版本：1.1.0
# 功能：提供系统工具的快速配置与管理

# 颜色常量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

# GitHub仓库配置
GITHUB_REPO='hadis898/allscript'
GITHUB_BRANCH='main'

# 代理配置 (可以根据需要更换)
GITHUB_PROXIES=(
    "https://mirror.ghproxy.com/https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}"
    "https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}"
    "https://ghp.ci/https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}"
)

# 日志函数
log_error() {
    echo -e "${RED}[错误] $1${PLAIN}"
}

log_success() {
    echo -e "${GREEN}[成功] $1${PLAIN}"
}

log_info() {
    echo -e "${YELLOW}[信息] $1${PLAIN}"
}

# 网络检测函数
check_network() {
    if ! ping -c 2 github.com &> /dev/null; then
        log_error "无法连接GitHub，请检查网络"
        return 1
    fi
    return 0
}

# 下载脚本函数
download_script() {
    local script_name=$1
    local download_success=false

    for proxy in "${GITHUB_PROXIES[@]}"; do
        local download_url="${proxy}/${script_name}"
        log_info "尝试从 ${download_url} 下载脚本"

        # 使用curl下载并显示进度
        if curl -L -f --progress-bar "${download_url}" -o "/tmp/${script_name}"; then
            log_success "脚本 ${script_name} 下载成功"
            bash "/tmp/${script_name}"
            download_success=true
            break
        else
            log_error "从 ${download_url} 下载失败"
        fi
    done

    if [ "$download_success" = false ]; then
        log_error "所有代理下载失败，请检查网络或脚本地址"
        return 1
    fi
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "请使用root权限运行此脚本"
        exit 1
    fi
}

# 显示菜单
show_menu() {
    clear
    echo -e "${GREEN}========== 系统工具管理脚本 ==========${PLAIN}"
    echo -e "${GREEN}1. BBR-WARP设置${PLAIN}"
    echo -e "${GREEN}2. 开启BBR+root登录+密码设置${PLAIN}"
    echo -e "${GREEN}0. 退出脚本${PLAIN}"
    echo -e "${GREEN}=====================================${PLAIN}"
}

# 主程序
main() {
    check_root
    check_network || exit 1

    while true; do
        show_menu
        read -p "请输入要执行的操作编号: " operation

        case $operation in
            1)
                download_script "bbr-warp.sh"
                ;;
            2)
                download_script "bbr-root.sh"
                ;;
            0)
                log_info "感谢使用，再见！"
                exit 0
                ;;
            *)
                log_error "输入的操作编号无效，请重新输入"
                sleep 2
                ;;
        esac

        read -p "是否继续? [Y/n]: " continue_choice
        [[ ${continue_choice,,} != [nN] ]] || break
    done
}

# 执行主程序
main
