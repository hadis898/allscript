#!/bin/bash
# ==============================================
# 深度清除Linux所有登录IP痕迹 v2025.04.29
# 使用方法：sudo bash deep_clean_login_records.sh
# ==============================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 恢复默认颜色

# 检查 root 权限
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}❌ 错误: 请使用 sudo 或以 root 用户运行此脚本！${NC}" >&2
    exit 1
fi

echo -e "${GREEN}"
echo "=========================================="
echo "     深度清除登录IP痕迹工具"
echo "=========================================="
echo -e "${NC}"

# 1. 彻底清除所有标准登录记录文件
echo -e "${BLUE}[1/5] 清除标准登录记录...${NC}"

# 停止可能正在写入日志的服务
systemctl stop rsyslog 2>/dev/null
systemctl stop syslog 2>/dev/null
systemctl stop auditd 2>/dev/null
systemctl stop systemd-journald 2>/dev/null

# 完全删除并重建日志文件 - 使用备份和恢复权限模式
echo -e "  ${YELLOW}正在处理主要登录记录文件...${NC}"
for logfile in /var/log/wtmp /var/log/btmp /var/log/lastlog /var/run/utmp /run/utmp; do
    if [ -f "$logfile" ]; then
        # 保存原始权限
        owner=$(stat -c "%U:%G" "$logfile" 2>/dev/null || echo "root:root")
        perms=$(stat -c "%a" "$logfile" 2>/dev/null || echo "644")
        
        # 删除并重建文件
        rm -f "$logfile"
        touch "$logfile"
        chown "$owner" "$logfile" 2>/dev/null
        chmod "$perms" "$logfile" 2>/dev/null
        echo -e "  ${GREEN}✓ 已清除: $logfile${NC}"
    fi
done

# 处理备份和轮转的日志文件
echo -e "  ${YELLOW}正在清除日志备份文件...${NC}"
find /var/log -name "wtmp.*" -type f -delete
find /var/log -name "btmp.*" -type f -delete
echo -e "  ${GREEN}✓ 日志备份文件已清除${NC}"

# 2. 处理SSH相关记录
echo -e "${BLUE}[2/5] 清除SSH记录...${NC}"
for ssh_log in /var/log/auth.log /var/log/secure /var/log/auth.log.* /var/log/secure.*; do
    if [ -f "$ssh_log" ]; then
        > "$ssh_log"
        echo -e "  ${GREEN}✓ 已清除: $ssh_log${NC}"
    fi
done

# 如果存在SSH目录日志
if [ -d "/var/log/ssh" ]; then
    find /var/log/ssh -type f -exec truncate -s 0 {} \;
    echo -e "  ${GREEN}✓ 已清除: /var/log/ssh/ 目录${NC}"
fi

# 清除~/.ssh/known_hosts文件中的记录(可选)
echo -e "  ${YELLOW}正在清除SSH known_hosts文件...${NC}"
find /root/.ssh /home/*/.ssh -name "known_hosts" -exec truncate -s 0 {} \; 2>/dev/null
echo -e "  ${GREEN}✓ 已清除known_hosts文件${NC}"

# 3. 处理系统日志中可能包含的IP信息
echo -e "${BLUE}[3/5] 清除系统日志中的IP痕迹...${NC}"

# 清除journald日志
rm -rf /var/log/journal/*/* 2>/dev/null
echo -e "  ${GREEN}✓ 已清除journald日志${NC}"

# 清除其他系统日志
log_files=(
    "/var/log/syslog"
    "/var/log/messages"
    "/var/log/daemon.log"
    "/var/log/kern.log"
    "/var/log/dmesg"
    "/var/log/faillog"
    "/var/log/tallylog"
)

for log in "${log_files[@]}"; do
    if [ -f "$log" ]; then
        > "$log"
        echo -e "  ${GREEN}✓ 已清除: $log${NC}"
    fi
    
    # 处理轮转的日志文件
    for rotated in "$log".?*; do
        if [ -f "$rotated" ]; then
            > "$rotated"
            echo -e "  ${GREEN}✓ 已清除: $rotated${NC}"
        fi
    done
done

# 4. 清除其他可能记录IP的位置
echo -e "${BLUE}[4/5] 清除其他IP痕迹...${NC}"

# 清除历史命令
history -c 2>/dev/null
rm -f ~/.bash_history 2>/dev/null
find /home -name ".bash_history" -exec rm -f {} \; 2>/dev/null
find /root -name ".bash_history" -exec rm -f {} \; 2>/dev/null
echo -e "  ${GREEN}✓ 已清除命令历史${NC}"

# acct/psacct进程记账
if which accton >/dev/null 2>&1; then
    accton off 2>/dev/null
    rm -f /var/account/pacct* 2>/dev/null
    echo -e "  ${GREEN}✓ 已关闭并清除进程记账${NC}"
fi

# 清除临时文件中可能的IP记录
find /tmp -type f -exec truncate -s 0 {} \; 2>/dev/null
find /var/tmp -type f -exec truncate -s 0 {} \; 2>/dev/null
echo -e "  ${GREEN}✓ 已清除临时文件${NC}"

# 清除audit审计日志
if [ -d "/var/log/audit" ]; then
    find /var/log/audit -type f -name "audit.log*" -exec truncate -s 0 {} \;
    echo -e "  ${GREEN}✓ 已清除审计日志${NC}"
fi

# 5. 重启记录服务
echo -e "${BLUE}[5/5] 重启日志服务...${NC}"
systemctl restart systemd-journald 2>/dev/null
systemctl restart rsyslog 2>/dev/null
systemctl restart syslog 2>/dev/null
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null

# 清除内存中的缓存
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
sync

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✓ 清除完成! 所有登录IP痕迹已深度清除${NC}"
echo -e "${GREEN}========================================${NC}"

# 验证部分
echo -e "\n${YELLOW}验证命令:${NC}"
echo -e "  ${BLUE}last${NC}               # 应显示无记录"
echo -e "  ${BLUE}lastb${NC}              # 应显示无记录"
echo -e "  ${BLUE}lastlog${NC}            # 应显示无最后登录信息"
echo -e "  ${BLUE}grep -r \"IP地址\" /var/log/${NC}   # 检查IP是否存在于日志"

echo -e "\n${RED}警告: 为确保所有痕迹完全清除，强烈建议现在重启系统!${NC}"
echo -e "${YELLOW}重启命令: ${BLUE}shutdown -r now${NC}"

# 询问是否立即重启
read -p "$(echo -e "${YELLOW}是否立即重启系统以完成清除? (y/N): ${NC}")" choice
if [[ "$choice" =~ [yY] ]]; then
    echo -e "${GREEN}正在重启系统...${NC}"
    shutdown -r now
fi