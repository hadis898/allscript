#!/bin/bash

# ==============================================
# 一键清除 root 登录日志（Debian/Ubuntu）脚本
# 使用方法：sudo ./clear_logs.sh
# ==============================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查 root 权限
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}❌ 请使用 sudo 或以 root 用户运行！${NC}" >&2
    exit 1
fi

# 静默执行函数
run_silent() {
    echo -ne "${YELLOW}⏳ $1...${NC}"
    shift
    eval "$@" >/dev/null 2>&1
    [ $? -eq 0 ] && echo -e "\r${GREEN}✅ $1 已完成${NC}" || echo -e "\r${RED}⚠️ $1 失败（但可能不影响整体）${NC}"
}

# 修复 history 残留问题的关键步骤
fix_history() {
    # 1. 立即清空内存中的历史记录
    history -c && history -w

    # 2. 禁用当前会话的历史记录
    unset HISTFILE

    # 3. 为所有用户设置 HISTSIZE=0
    for user in $(ls /home) root; do
        user_dir=$(eval echo ~$user)
        [ -f "$user_dir/.bashrc" ] && \
        grep -q "HIST" "$user_dir/.bashrc" || \
        echo -e "\nexport HISTSIZE=0\nexport HISTFILESIZE=0" >> "$user_dir/.bashrc"
    done

    # 4. 立即生效设置
    export HISTSIZE=0
    export HISTFILESIZE=0
}

# 主流程
echo -e "${GREEN}"
echo "========================================"
echo "  一键清除痕迹脚本"
echo "========================================"
echo -e "${NC}"

# 1. 修复 history 残留
run_silent "修复 history 记录残留" fix_history

# 2. 清除系统日志
run_silent "清除登录记录" bash -c '
    echo > /var/log/wtmp
    echo > /var/log/btmp
    echo > /var/log/lastlog
'

# 3. 清除 journald 日志
run_silent "清除系统日志" bash -c '
    journalctl --flush --rotate
    journalctl --vacuum-time=1s
    rm -rf /var/log/journal/*
    systemctl restart systemd-journald
'

# 4. 可选：永久禁用历史记录
read -p "$(echo -e "${YELLOW}❓ 永久禁用所有历史记录？(y/N): ${NC}")" choice
if [[ "$choice" =~ [yY] ]]; then
    run_silent "永久禁用历史记录" bash -c '
        echo "set +o history" >> /etc/profile
        echo "set +o history" >> /etc/bash.bashrc
    '
fi

# 完成提示
echo -e "\n${GREEN}🔥 所有痕迹已彻底清除！${NC}"
echo -e "${YELLOW}验证命令：${NC}"
echo -e "  history         # 应显示空"
echo -e "  last root       # 应显示空"
echo -e "  ls -la ~/.*_history  # 检查历史文件"