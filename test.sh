#!/bin/bash

# Debian BBR 一键优化脚本
# 功能：优化系统TCP性能，开启BBR加速
# 作者：Claude
# 版本：1.0

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
PLAIN='\033[0m'

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误：请使用root用户运行此脚本！${PLAIN}"
        exit 1
    fi
}

# 检查系统版本
check_system() {
    if [[ -f /etc/debian_version ]]; then
        source /etc/os-release
        if [[ "${ID}" == "debian" || "${ID}" == "ubuntu" ]]; then
            echo -e "${GREEN}系统检测通过：${PLAIN}${CYAN}${PRETTY_NAME}${PLAIN}"
        else
            echo -e "${RED}错误：本脚本仅支持Debian/Ubuntu系统！${PLAIN}"
            exit 1
        fi
    else
        echo -e "${RED}错误：本脚本仅支持Debian/Ubuntu系统！${PLAIN}"
        exit 1
    fi
}

# 检查内核版本
check_kernel() {
    kernel_version=$(uname -r | cut -d- -f1)
    if version_ge $kernel_version 4.9; then
        echo -e "${GREEN}内核版本检测通过：${PLAIN}${CYAN}$kernel_version${PLAIN}，已满足BBR最低要求(4.9+)"
    else
        echo -e "${YELLOW}警告：当前内核版本${PLAIN}${CYAN}$kernel_version${PLAIN}${YELLOW}不满足BBR最低要求(4.9+)，将为您升级内核${PLAIN}"
    fi
}

# 版本比较
version_ge() {
    test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"
}

# 更新系统
update_system() {
    echo -e "${CYAN}正在更新系统...${PLAIN}"
    apt update -y
    apt upgrade -y
}

# 安装依赖
install_dependencies() {
    echo -e "${CYAN}正在安装必要依赖...${PLAIN}"
    apt install -y wget curl gnupg lsb-release apt-transport-https ca-certificates
}

# 升级内核
upgrade_kernel() {
    echo -e "${CYAN}正在升级系统内核...${PLAIN}"
    
    # 安装新版本内核
    apt install -y linux-image-generic linux-headers-generic
    
    # 更新grub
    update-grub
    
    echo -e "${GREEN}内核升级完成，将在重启后生效${PLAIN}"
    
    # 询问是否立即重启
    read -p "是否立即重启系统以应用新内核？(y/n): " restart
    if [[ "${restart}" == "y" || "${restart}" == "Y" ]]; then
        reboot
    fi
}

# 开启BBR
enable_bbr() {
    echo -e "${CYAN}正在开启BBR...${PLAIN}"
    
    # 检查是否已开启
    if lsmod | grep bbr; then
        echo -e "${GREEN}BBR 已经启用！${PLAIN}"
        return
    fi
    
    # 配置sysctl参数
    cat > /etc/sysctl.d/99-bbr.conf << EOF
# BBR 配置
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
    
    # 应用配置
    sysctl -p /etc/sysctl.d/99-bbr.conf
    
    # 检查是否开启成功
    if lsmod | grep bbr; then
        echo -e "${GREEN}BBR 开启成功！${PLAIN}"
    else
        echo -e "${YELLOW}BBR 可能未成功开启，请重启系统后再次检查${PLAIN}"
    fi
}

# 优化系统参数
optimize_system() {
    echo -e "${CYAN}正在优化系统参数...${PLAIN}"
    
    # 创建系统参数优化配置
    cat > /etc/sysctl.d/98-network-performance.conf << EOF
# 网络性能优化

# 增加TCP连接数限制
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535

# 增加系统文件句柄数
fs.file-max = 1000000

# 增加UDP和TCP缓冲区大小
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# 开启SYN洪水攻击保护
net.ipv4.tcp_syncookies = 1

# 开启TIME-WAIT复用
net.ipv4.tcp_tw_reuse = 1

# 减少TIME-WAIT socket的数量
net.ipv4.tcp_max_tw_buckets = 5000

# 增加本地端口范围
net.ipv4.ip_local_port_range = 1024 65000

# 设置TCP FIN超时时间
net.ipv4.tcp_fin_timeout = 30

# 设置TCP保活时间
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 3

# 关闭IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    
    # 应用配置
    sysctl -p /etc/sysctl.d/98-network-performance.conf
    
    # 优化系统限制
    if ! grep -q "* soft nofile 1000000" /etc/security/limits.conf; then
        cat >> /etc/security/limits.conf << EOF

# 系统限制优化
* soft nofile 1000000
* hard nofile 1000000
* soft nproc 65535
* hard nproc 65535
EOF
    fi
    
    echo -e "${GREEN}系统参数优化完成！${PLAIN}"
}

# 检查BBR状态
check_bbr_status() {
    if lsmod | grep -q bbr; then
        echo -e "${GREEN}BBR 状态：${PLAIN}${CYAN}已启用${PLAIN}"
        sysctl net.ipv4.tcp_congestion_control
    else
        echo -e "${RED}BBR 状态：${PLAIN}${CYAN}未启用${PLAIN}"
    fi
}

# 显示系统信息
show_system_info() {
    echo -e "${CYAN}=======================================${PLAIN}"
    echo -e "${CYAN}系统信息：${PLAIN}"
    echo -e "${CYAN}=======================================${PLAIN}"
    
    echo -e "${CYAN}操作系统：${PLAIN}$(cat /etc/os-release | grep -w "PRETTY_NAME" | cut -d '=' -f2 | tr -d '"')"
    echo -e "${CYAN}内核版本：${PLAIN}$(uname -r)"
    echo -e "${CYAN}CPU型号：${PLAIN}$(cat /proc/cpuinfo | grep 'model name' | head -n 1 | cut -d ':' -f2 | sed 's/^[ \t]*//')"
    echo -e "${CYAN}CPU核心数：${PLAIN}$(grep -c 'processor' /proc/cpuinfo)"
    echo -e "${CYAN}系统负载：${PLAIN}$(cat /proc/loadavg | awk '{print $1 " " $2 " " $3}')"
    echo -e "${CYAN}内存使用：${PLAIN}$(free -h | grep Mem | awk '{print $3 "/" $2}')"
    echo -e "${CYAN}交换分区：${PLAIN}$(free -h | grep Swap | awk '{print $3 "/" $2}')"
    echo -e "${CYAN}运行时间：${PLAIN}$(uptime -p)"
    echo -e "${CYAN}BBR状态：${PLAIN}$(if lsmod | grep -q bbr; then echo "已启用"; else echo "未启用"; fi)"
    echo -e "${CYAN}当前拥塞控制算法：${PLAIN}$(sysctl net.ipv4.tcp_congestion_control | awk -F= '{print $2}' | tr -d ' ')"
    echo -e "${CYAN}=======================================${PLAIN}"
}

# 主菜单
show_menu() {
    clear
    echo -e "${CYAN}=======================================${PLAIN}"
    echo -e "${YELLOW}      Debian BBR 一键优化脚本 v1.0      ${PLAIN}"
    echo -e "${CYAN}=======================================${PLAIN}"
    echo -e "${CYAN}1.${PLAIN} ${GREEN}系统信息${PLAIN}"
    echo -e "${CYAN}2.${PLAIN} ${GREEN}升级系统${PLAIN}"
    echo -e "${CYAN}3.${PLAIN} ${GREEN}升级内核${PLAIN}"
    echo -e "${CYAN}4.${PLAIN} ${GREEN}开启BBR${PLAIN}"
    echo -e "${CYAN}5.${PLAIN} ${GREEN}优化系统参数${PLAIN}"
    echo -e "${CYAN}6.${PLAIN} ${GREEN}检查BBR状态${PLAIN}"
    echo -e "${CYAN}7.${PLAIN} ${GREEN}一键全部优化${PLAIN}"
    echo -e "${CYAN}0.${PLAIN} ${GREEN}退出脚本${PLAIN}"
    echo -e "${CYAN}=======================================${PLAIN}"
    
    read -p "请输入选项 [0-7]: " option
    
    case "$option" in
        0)
            echo -e "${GREEN}感谢使用，再见！${PLAIN}"
            exit 0
            ;;
        1)
            show_system_info
            ;;
        2)
            update_system
            ;;
        3)
            upgrade_kernel
            ;;
        4)
            enable_bbr
            ;;
        5)
            optimize_system
            ;;
        6)
            check_bbr_status
            ;;
        7)
            update_system
            install_dependencies
            check_kernel
            kernel_version=$(uname -r | cut -d- -f1)
            if ! version_ge $kernel_version 4.9; then
                upgrade_kernel
            fi
            enable_bbr
            optimize_system
            echo -e "${GREEN}系统优化完成！建议重启系统以应用所有优化。${PLAIN}"
            read -p "是否立即重启？(y/n): " reboot_now
            if [[ "${reboot_now}" == "y" || "${reboot_now}" == "Y" ]]; then
                reboot
            fi
            ;;
        *)
            echo -e "${RED}无效选项，请重试！${PLAIN}"
            ;;
    esac
    
    echo
    read -p "按任意键继续..." any_key
    show_menu
}

# 脚本入口
main() {
    check_root
    check_system
    show_menu
}

# 执行脚本
main