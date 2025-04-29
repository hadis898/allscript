#!/bin/bash
# ==============================================
# 一键清除linux所有操作痕迹 v2025.04.25
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
# 1. 清除所有用户的 .bash_history 和当前会话的历史
run_silent "清除命令历史" bash -c '
    # 清空所有用户的.bash_history文件
    for user_home in /root /home/*; do
        if [ -d "$user_home" ]; then
            user=$(basename "$user_home")
            # 先将文件清空
            echo "" > "$user_home/.bash_history"
            # 然后将文件属性设置为不可变（可选，更彻底）
            chattr +a "$user_home/.bash_history" 2>/dev/null
            # 再次写入空内容
            echo "" > "$user_home/.bash_history"
            # 恢复文件属性
            chattr -a "$user_home/.bash_history" 2>/dev/null
            
            # 如果有用户正在登录，尝试清除其活动shell的历史
            for pid in $(pgrep -u "$user" bash); do
                # 向每个bash进程发送history -c命令
                su - "$user" -c "kill -USR1 $pid && echo \"history -c && history -w\" >> /proc/$pid/fd/0" 2>/dev/null
            done
        fi
    done
    
    # 清除当前shell的历史
    history -c
    history -w
'
# 2. 清除登录日志
run_silent "清除登录记录" bash -c '
    echo > /var/log/wtmp
    echo > /var/log/btmp
    echo > /var/log/lastlog 2>/dev/null
'
# 3. 清除系统日志
run_silent "清除系统日志" bash -c '
    journalctl --flush --rotate >/dev/null 2>&1
    rm -rf /var/log/journal/*
    systemctl restart systemd-journald >/dev/null 2>&1
    
    # 清除更多系统日志文件
    for log_file in /var/log/auth.log /var/log/syslog /var/log/messages /var/log/secure /var/log/dmesg; do
        if [ -f "$log_file" ]; then
            echo > "$log_file"
        fi
    done
    
    # 清除所有.log文件（更彻底，但可能会影响某些应用）
    find /var/log -type f -name "*.log" -exec sh -c "echo > {}" \; 2>/dev/null
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

# 5. 设置HISTSIZE=0来禁用当前会话的历史记录
run_silent "禁用历史记录功能" bash -c '
    # 为所有用户添加HISTSIZE=0到bash配置
    for profile in /etc/profile /etc/bash.bashrc /etc/profile.d/history.sh; do
        if [ -f "$profile" ] || [ "$profile" = "/etc/profile.d/history.sh" ]; then
            # 确保目录存在
            mkdir -p /etc/profile.d/
            # 添加或更新HISTSIZE设置
            grep -q "HISTSIZE=" "$profile" 2>/dev/null
            if [ $? -eq 0 ]; then
                sed -i "s/^HISTSIZE=.*/HISTSIZE=0/" "$profile"
                sed -i "s/^HISTFILESIZE=.*/HISTFILESIZE=0/" "$profile"
            else
                echo "HISTSIZE=0" >> "$profile"
                echo "HISTFILESIZE=0" >> "$profile"
            fi
        fi
    done
    
    # 设置当前会话的历史大小
    export HISTSIZE=0
    export HISTFILESIZE=0
'

# 完成提示
echo -e "\n${GREEN}🎉 所有痕迹已静默清理完毕！${NC}"
echo -e "${YELLOW}验证命令：${NC}"
echo -e "  last root       # 检查登录记录"
echo -e "  history         # 检查命令历史"
echo -e "  journalctl -u sshd _UID=0  # 检查系统日志"

# 提示重新登录以完全清除历史
echo -e "\n${YELLOW}注意：为确保命令历史完全清除，建议在运行此脚本后注销并重新登录。${NC}"