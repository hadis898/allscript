#!/usr/bin/env bash

# 系统工具一键管理脚本
# 作者：大灰狼
# 版本：1.0.0
# 功能：提供PVE、SSH、系统工具的快速配置

# 定义颜色常量
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly PLAIN='\033[0m'

# 定义GitHub代理
readonly GITHUB_PROXY='https://gh.7761.cf/https://github.com/shidahuilang/pve'

# 检查root权限
check_root() {
    [[ $EUID -ne 0 ]] && {
        echo -e "[${RED}错误${PLAIN}] 请使用root权限运行脚本!"
        exit 1
    }
}

# 显示菜单
show_menu() {
    echo -e "${GREEN}========== 系统工具管理脚本 ==========${PLAIN}"
    echo -e "${GREEN}1. PVE直通配置 + 硬件监控${PLAIN}"
    echo -e "${GREEN}2. PVE一键升级 + LXC源配置${PLAIN}"
    echo -e "${GREEN}3. SSH & BBR配置 + Root登录设置${PLAIN}"
    echo -e "${GREEN}4. 多系统SSH一键开启${PLAIN}"
    echo -e "${GREEN}5. 黑群晖CPU识别修复${PLAIN}"
    echo -e "${GREEN}6. 黑群晖自动挂载白群晖${PLAIN}"
    echo -e "${GREEN}7. 系统交换分区快速配置${PLAIN}"
    echo -e "${GREEN}0. 退出脚本${PLAIN}"
    echo -e "${GREEN}=====================================${PLAIN}"
}

# 执行脚本
execute_script() {
    local script_name=$1
    bash -c "$(curl -fsSL ${GITHUB_PROXY}/${script_name})"
}

# 主程序
main() {
    check_root

    while true; do
        show_menu
        read -p "请输入要执行的操作编号: " operation

        case $operation in
            1)
                execute_script "pve.sh"
                ;;
            2)
                execute_script "pvehy.sh"
                ;;
            3)
                execute_script "lang.sh"
                ;;
            4)
                execute_script "ssh.sh"
                ;;
            5)
                wget -qO ch_cpuinfo_cn.sh "${GITHUB_PROXY}/ch_cpuinfo_cn.sh" && sudo bash ch_cpuinfo_cn.sh
                ;;
            6)
                execute_script "arpl.sh"
                ;;
            7)
                execute_script "swap.sh"
                ;;
            0)
                echo -e "${GREEN}感谢使用，再见！${PLAIN}"
                exit 0
                ;;
            *)
                echo -e "${RED}输入的操作编号无效，请重新输入。${PLAIN}"
                sleep 2
                ;;
        esac

        read -p "是否继续? [Y/n]: " continue_choice
        [[ $continue_choice == [nN] ]] && break
    done
}

# 运行主程序
main
