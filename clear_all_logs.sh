#!/bin/bash

# ==============================================
# 一键清除linux所有操作痕迹 v2025.04.19
# 使用方法：sudo ./clear_all_logs_silent.sh
# ==============================================

# 颜色定义（精简）
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # 恢复默认颜色

# 检查 root 权限
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}❌ 请使用 sudo 或以 root 用户运行此脚本！${NC}" >&2
    exit 1
fi

# 静默执行函数
run_silent() {
    echo -ne "${YELLOW}⏳ $1...${NC}"
    shift
    "$@" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "\r${GREEN}✅ $1 已完成${NC}"
    else
        echo -e "\r${RED}⚠️ $1 失败（但可能不影响整体）${NC}"
    fi
}

# 显示精简标题
echo -e "${GREEN}"
echo "========================================"
echo "  系统痕迹清理工具（静默模式）"
echo "========================================"
echo -e "${NC}"

# 1. 清除所有用户的 .bash_history
run_silent "清除命令历史" bash -c '
    echo "" > ~/.bash_history
    history -c
    for user in $(ls /home); do
        echo "" > "/home/$user/.bash_history"
    done
    echo "" > /root/.bash_history
'

# 2. 清除登录日志
run_silent "清除登录记录" bash -c '
    echo > /var/log/wtmp
    echo > /var/log/btmp
'

# 3. 清除系统日志
run_silent "清除系统日志" bash -c '
    journalctl --flush --rotate >/dev/null 2>&1
    rm -rf /var/log/journal/*
    systemctl restart systemd-journald >/dev/null 2>&1
    if [ -f "/var/log/auth.log" ]; then
        echo > /var/log/auth.log
    fi
'

# 4. 可选：禁用 SSH 日志
read -p "$(echo -e "${YELLOW}❓ 是否禁用 SSH 日志记录？(y/N): ${NC}")" choice
if [[ "$choice" =~ [yY] ]]; then
    run_silent "禁用 SSH 日志" bash -c '
        sed -i "s/^#*LogLevel.*/LogLevel QUIET/" /etc/ssh/sshd_config
        sed -i "s/^#*SyslogFacility.*/SyslogFacility AUTHPRIV/" /etc/ssh/sshd_config
        systemctl restart sshd >/dev/null 2>&1
    '
fi

# 完成提示
echo -e "\n${GREEN}🎉 所有痕迹已静默清理完毕！${NC}"
echo -e "${YELLOW}验证命令：${NC}"
echo -e "  last root       # 检查登录记录"
echo -e "  history         # 检查命令历史"
echo -e "  journalctl -u sshd _UID=0  # 检查系统日志"