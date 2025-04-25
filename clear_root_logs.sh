#!/bin/bash

# ==============================================
# 一键清除所有操作痕迹 v2025.04.19
# 使用方法：sudo ./clear_root_logs.sh
# ==============================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 恢复默认颜色

# 检查是否以 root 运行
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}❌ 请使用 sudo 或以 root 用户运行此脚本！${NC}"
    exit 1
fi

# 显示 ASCII 标题
echo -e "${BLUE}"
cat << "EOF"
  ____ _                 _   _____ _               _    
 / ___| | ___  _   _  __| | |_   _| |__   ___  ___| | __
| |   | |/ _ \| | | |/ _` |   | | | '_ \ / _ \/ __| |/ /
| |___| | (_) | |_| | (_| |   | | | | | |  __/ (__|   < 
 \____|_|\___/ \__,_|\__,_|   |_| |_| |_|\___|\___|_|\_\
EOF
echo -e "${NC}"

# 进度条函数
progress_bar() {
    local duration=${1}
    local bar_length=50
    local sleep_interval=$(echo "scale=5; $duration/$bar_length" | bc)
    local progress=""
    local current=""

    for ((i=0; i<=$bar_length; i++)); do
        progress+="="
        current+=">"
        printf "\r[%-*s] %d%%" "$bar_length" "${progress:0:$i}${current:0:1}" "$((i*100/$bar_length))"
        sleep "$sleep_interval"
    done
    printf "\n"
}

# 1. 清除当前用户的 .bash_history
echo -e "${YELLOW}[1/7] 🧹 清除当前用户的 .bash_history...${NC}"
echo "" > ~/.bash_history
history -c
echo -e "${GREEN}✅ 当前用户命令历史已清空${NC}"
progress_bar 1

# 2. 清除所有用户的 .bash_history
echo -e "${YELLOW}[2/7] 🧹 清除所有用户的 .bash_history...${NC}"
for user in $(ls /home); do
    echo "" > "/home/$user/.bash_history"
done
echo "" > /root/.bash_history
echo -e "${GREEN}✅ 所有用户的命令历史已清空${NC}"
progress_bar 1

# 3. 清除 wtmp（成功登录记录）
echo -e "${YELLOW}[3/7] 🧹 清除 /var/log/wtmp...${NC}"
echo > /var/log/wtmp
echo -e "${GREEN}✅ wtmp 已清空${NC}"
progress_bar 1

# 4. 清除 btmp（失败登录记录）
echo -e "${YELLOW}[4/7] 🧹 清除 /var/log/btmp...${NC}"
echo > /var/log/btmp
echo -e "${GREEN}✅ btmp 已清空${NC}"
progress_bar 1

# 5. 清除 systemd-journald 日志
echo -e "${YELLOW}[5/7] 🧹 清除 systemd-journald 日志...${NC}"
journalctl --flush --rotate >/dev/null 2>&1
rm -rf /var/log/journal/*
systemctl restart systemd-journald >/dev/null 2>&1
echo -e "${GREEN}✅ journald 日志已清空${NC}"
progress_bar 1

# 6. 清除 auth.log（如果存在）
echo -e "${YELLOW}[6/7] 🧹 清除 /var/log/auth.log...${NC}"
if [ -f "/var/log/auth.log" ]; then
    echo > /var/log/auth.log
    echo -e "${GREEN}✅ auth.log 已清空${NC}"
else
    echo -e "${YELLOW}⚠️ /var/log/auth.log 不存在（可能使用 journald）${NC}"
fi
progress_bar 1

# 7. 可选：禁用 SSH 日志记录
echo -e "${YELLOW}[7/7] ⚙️ 是否禁用 SSH 日志记录？${NC}"
read -p "  选择 (y/N): " choice
if [[ "$choice" =~ [yY] ]]; then
    sed -i 's/^#*LogLevel.*/LogLevel QUIET/' /etc/ssh/sshd_config
    sed -i 's/^#*SyslogFacility.*/SyslogFacility AUTHPRIV/' /etc/ssh/sshd_config
    systemctl restart sshd >/dev/null 2>&1
    echo -e "${GREEN}✅ SSH 日志已禁用（LogLevel QUIET）${NC}"
else
    echo -e "${BLUE}⏩ 跳过 SSH 日志禁用${NC}"
fi
progress_bar 1

# 完成提示
echo -e "\n${GREEN}✅ 所有操作痕迹已彻底清除！${NC}"
echo -e "${BLUE}==========================================${NC}"
echo -e "${YELLOW}验证命令：${NC}"
echo -e "  ${BLUE}last root       ${NC}# 检查登录记录（应返回空）"
echo -e "  ${BLUE}history         ${NC}# 检查命令历史（应返回空）"
echo -e "  ${BLUE}journalctl -u sshd _UID=0  ${NC}# 检查 journald 日志"
echo -e "${BLUE}==========================================${NC}"