#!/bin/bash
# ============================================================
# 一键清除Linux所有操作痕迹
# By 哈迪斯
# ============================================================

# ────────────────────────────────────────────────────────────
# 【Bug修复】父shell历史彻底清理
# 问题根因：直接执行脚本时，history -c 只清子进程内存历史，
#   父shell（登录的bash）退出时仍把内存历史 history -w 写回文件，
#   导致执行脚本的那条命令依然残留在 ~/.bash_history。
# 解法：
#   1. 立即把所有历史文件内容清空（文件还在，内容为空）
#   2. export HISTFILE=/dev/null → 父shell退出时写入黑洞，不留文件
#   3. 注册 EXIT trap → 脚本任何退出路径都触发最终清理
# ────────────────────────────────────────────────────────────
_clean_history_final() {
    history -c 2>/dev/null || true
    export HISTFILE=/dev/null
    export HISTSIZE=0
    export HISTFILESIZE=0
    # 清空所有用户的历史文件
    for _hf in /root/.bash_history /root/.zsh_history \
               /home/*/.bash_history /home/*/.zsh_history; do
        [ -f "$_hf" ] && : > "$_hf" 2>/dev/null || true
    done
}
trap '_clean_history_final' EXIT

# 立即执行：清空文件 + 让后续写操作指向 /dev/null
history -c 2>/dev/null || true
export HISTFILE=/dev/null
export HISTSIZE=0
export HISTFILESIZE=0
for _hf in /root/.bash_history /root/.zsh_history \
           /home/*/.bash_history /home/*/.zsh_history; do
    [ -f "$_hf" ] && : > "$_hf" 2>/dev/null || true
done

# ────────────────────────────────────────────────────────────
# 颜色 & 常量
# ────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

VERSION="v2025.04.27-fix1"

# ────────────────────────────────────────────────────────────
# 工具函数
# ────────────────────────────────────────────────────────────

show_logo() {
    clear
    echo -e "${CYAN}${BOLD}【Linux系统痕迹清理与管理工具】 ${GREEN}${VERSION}${NC}"
    echo -e "${GREEN}安全、高效、无痕迹操作${NC}\n"
}

# 检查 root 权限
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}${BOLD}❌ 错误: 需要管理员权限${NC}"
        echo -e "${YELLOW}请使用 sudo 或以 root 用户运行此脚本！${NC}" >&2
        exit 1
    fi
    echo -e "${GREEN}✅ 权限检查通过${NC}"
}

# ────────────────────────────────────────────────────────────
# 【Bug修复】run_silent：等待实际进程完成后再判断结果
#   原版进度条是固定时间假进度，进程结束状态判断混乱。
#   新版：真实等待子进程 → 显示结果，进度条改为spinner。
# ────────────────────────────────────────────────────────────
run_silent() {
    local description="$1"
    shift

    echo -e "${CYAN}➜ ${BOLD}${description}${NC}"

    local temp_err
    temp_err=$(mktemp)
    local temp_out
    temp_out=$(mktemp)

    # 后台执行，带超时保护
    (timeout 300 "$@" >"$temp_out" 2>"$temp_err") &
    local pid=$!

    # Spinner：等待实际进程完成
    local spin=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        echo -ne "  ${YELLOW}${spin[$i]}${NC} 处理中...\r"
        i=$(( (i+1) % ${#spin[@]} ))
        sleep 0.1
    done
    echo -ne "                    \r"

    # 等待并获取真实退出码
    local exit_code=0
    wait "$pid" 2>/dev/null || exit_code=$?

    # 【Bug修复】只有退出码非0才算失败，忽略正常的stderr输出
    if [ "$exit_code" -ne 0 ]; then
        echo -e "  ${YELLOW}⚠️ 操作完成但有警告 (退出码: ${exit_code})${NC}"
        if [ -s "$temp_err" ]; then
            echo -e "${YELLOW}警告详情 (前5行):${NC}"
            head -n 5 "$temp_err" | while IFS= read -r line; do
                echo -e "  ${RED}→ ${line}${NC}"
            done
        fi
        echo ""
        rm -f "$temp_err" "$temp_out"
        return 1
    else
        echo -e "  ${GREEN}✓ 操作成功完成${NC}\n"
        rm -f "$temp_err" "$temp_out"
        return 0
    fi
}

# 确认函数
confirm() {
    local prompt="$1"
    local default="${2:-N}"
    local prompt_symbol yn_hint response

    if [[ "$default" =~ [yY] ]]; then
        prompt_symbol="${GREEN}[Y/n]${NC}"
        yn_hint="Y"
    else
        prompt_symbol="${RED}[y/N]${NC}"
        yn_hint="N"
    fi

    echo -ne "${CYAN}$prompt ${prompt_symbol}:${NC} "
    read -r response

    [ -z "$response" ] && response=$yn_hint
    [[ "$response" =~ [yY] ]]
}

# 主菜单
show_menu() {
    echo -e "\n${MAGENTA}${BOLD}【痕迹清除 - 操作菜单】${NC}\n"

    echo -e "${GREEN}清理选项:${NC}"
    echo -e "  ${MAGENTA}1.${NC} 清除命令历史及bash记录"
    echo -e "  ${MAGENTA}2.${NC} 清除登录日志和认证记录"
    echo -e "  ${MAGENTA}3.${NC} 清除系统日志与journald记录"
    echo -e "  ${MAGENTA}4.${NC} 清理临时文件和缓存"
    echo -e "  ${MAGENTA}5.${NC} 一键执行所有清理操作  ${YELLOW}(完成后断开当前SSH会话)${NC}"

    echo -e "\n${GREEN}禁用选项:${NC}"
    echo -e "  ${MAGENTA}6.${NC} 禁用SSH日志记录 (chattr +i wtmp/btmp)"
    echo -e "  ${MAGENTA}7.${NC} 永久禁用命令历史记录功能"

    echo -e "\n${GREEN}恢复选项:${NC}"
    echo -e "  ${MAGENTA}8.${NC} 恢复SSH日志记录功能"
    echo -e "  ${MAGENTA}9.${NC} 恢复命令历史记录功能"
    echo -e "  ${MAGENTA}0.${NC} 退出程序\n"

    echo -ne "${CYAN}请选择操作选项 ${YELLOW}[0-9]${NC}: "
}

# ────────────────────────────────────────────────────────────
# 1. 清除命令历史
# ────────────────────────────────────────────────────────────
clear_command_history() {
    local temp_script
    temp_script=$(mktemp)

    cat > "$temp_script" << 'SCRIPT'
#!/bin/bash
set -euo pipefail

for user_home in /root /home/*; do
    [ -d "$user_home" ] || continue

    hist_files=(
        "$user_home/.bash_history"
        "$user_home/.zsh_history"
        "$user_home/.history"
        "$user_home/.sh_history"
        "$user_home/.mysql_history"
        "$user_home/.python_history"
        "$user_home/.sqlite_history"
        "$user_home/.lesshst"
        "$user_home/.node_repl_history"
        "$user_home/.psql_history"
        "$user_home/.rediscli_history"
    )

    for hist_file in "${hist_files[@]}"; do
        [ -f "$hist_file" ] || continue

        # 移除不可变属性（忽略失败）
        chattr -i "$hist_file" 2>/dev/null || true
        chattr -a "$hist_file" 2>/dev/null || true

        # 【Bug修复】shred后文件已删除，不应再对其chattr+a
        # 正确顺序：先安全覆盖内容，再清空/删除
        if command -v shred >/dev/null 2>&1; then
            shred -fuz "$hist_file" 2>/dev/null || true
        else
            : > "$hist_file" 2>/dev/null || \
            truncate -s 0 "$hist_file" 2>/dev/null || true
        fi

        # 重建空文件（shred -z会删除文件）
        touch "$hist_file" 2>/dev/null && chmod 600 "$hist_file" 2>/dev/null || true
    done
done

# 【Bug修复】共享内存清理：原版 grep -v "0x" 会保留表头行而非地址行
# 正确做法：grep "0x" 匹配地址行，再提取shmid字段（第2列）
ipcs -m 2>/dev/null | awk '/^0x/{print $2}' | xargs -r -n1 ipcrm -m 2>/dev/null || true

# 清理/var/log下散落的history文件
find /var/spool/ /var/log/ /var/tmp/ /tmp/ -name "*history*" -type f 2>/dev/null \
    | while IFS= read -r f; do
        chattr -i "$f" 2>/dev/null || true
        truncate -s 0 "$f" 2>/dev/null || rm -f "$f" 2>/dev/null || true
    done

history -c 2>/dev/null || true
history -w 2>/dev/null || true
SCRIPT

    chmod +x "$temp_script"
    run_silent "正在清除命令历史" "$temp_script"
    rm -f "$temp_script"

    # 再次确保当前shell不会在退出时写历史
    history -c 2>/dev/null || true
    export HISTFILE=/dev/null
    export HISTSIZE=0
    export HISTFILESIZE=0
}

# ────────────────────────────────────────────────────────────
# 2. 清除登录日志
# ────────────────────────────────────────────────────────────
clear_login_logs() {
    # 【Bug修复】将日志列表和auth模式直接写入脚本，
    #   原版把 auth_patterns 数组传给 heredoc 内的脚本，
    #   heredoc 是新进程，拿不到父shell的数组变量。
    local temp_script
    temp_script=$(mktemp)

    cat > "$temp_script" << 'SCRIPT'
#!/bin/bash
set -euo pipefail

clear_log_file() {
    local f="$1"
    [ -f "$f" ] || return 0
    chattr -i "$f" 2>/dev/null || true
    truncate -s 0 "$f" 2>/dev/null || \
    cat /dev/null > "$f" 2>/dev/null || true
}

# 标准登录日志
for log_file in \
    /var/log/wtmp \
    /var/log/btmp \
    /var/log/lastlog \
    /var/log/faillog \
    /var/run/utmp \
    /run/utmp; do
    clear_log_file "$log_file" &
done

# Auth 日志（用 glob 展开，不依赖父shell变量）
for pattern in \
    /var/log/auth.log \
    /var/log/auth.log.* \
    /var/log/secure \
    /var/log/secure.* \
    /var/log/audit/audit.log \
    /var/log/audit/audit.log.*; do
    # 使用 nullglob 效果：手动判断文件存在
    [ -f "$pattern" ] && clear_log_file "$pattern" &
done

wait

# 重启相关服务
restart_service() {
    local svc="$1"
    if systemctl is-active "$svc" >/dev/null 2>&1; then
        systemctl restart "$svc" >/dev/null 2>&1 &
    elif command -v service >/dev/null 2>&1; then
        service "$svc" status >/dev/null 2>&1 && \
        service "$svc" restart >/dev/null 2>&1 &
    fi
}

for svc in auditd rsyslog syslog syslog-ng; do
    restart_service "$svc"
done
wait
SCRIPT

    chmod +x "$temp_script"
    run_silent "正在清除登录记录" "$temp_script"
    rm -f "$temp_script"
}

# ────────────────────────────────────────────────────────────
# 3. 清除系统日志
# ────────────────────────────────────────────────────────────
clear_system_logs() {
    local temp_script
    temp_script=$(mktemp)

    cat > "$temp_script" << 'SCRIPT'
#!/bin/bash
set -euo pipefail

# 清理 journald
clear_journald_logs() {
    command -v journalctl >/dev/null 2>&1 || return 0

    # flush+rotate 后再 vacuum，顺序很重要
    journalctl --flush --rotate >/dev/null 2>&1 || true
    journalctl --vacuum-size=1K >/dev/null 2>&1 || true

    # 删除journal文件（vacuum后可能仍有残留）
    if [ -d "/var/log/journal" ]; then
        find /var/log/journal -type f -delete 2>/dev/null || true
        # 保留目录结构以便服务正常启动
        mkdir -p /var/log/journal 2>/dev/null || true
    fi

    systemctl restart systemd-journald >/dev/null 2>&1 || true
}

clear_journald_logs &

# 清理指定系统日志
for log_file in \
    /var/log/syslog \
    /var/log/messages \
    /var/log/kern.log \
    /var/log/dmesg \
    /var/log/maillog \
    /var/log/mail.log \
    /var/log/cron \
    /var/log/boot.log \
    /var/log/daemon.log \
    /var/log/debug \
    /var/log/apt/history.log \
    /var/log/apt/term.log \
    /var/log/dpkg.log; do
    [ -f "$log_file" ] && truncate -s 0 "$log_file" 2>/dev/null &
done

# 批量清空 /var/log 下其余日志
find /var/log -type f -name "*.log" -print0 \
    | xargs -0 -P4 -n50 truncate -s 0 2>/dev/null &
find /var/log -type f -name "*.log.*" -print0 \
    | xargs -0 -P4 -n50 truncate -s 0 2>/dev/null &
find /var/log -type f -name "*.gz" -delete 2>/dev/null &
find /var/log -type f -size +0 -not -path "*/\.*" -print0 \
    | xargs -0 -P4 -n50 truncate -s 0 2>/dev/null &

wait

# 重启日志服务
restart_service() {
    local svc="$1"
    if systemctl is-active "$svc" >/dev/null 2>&1; then
        systemctl restart "$svc" >/dev/null 2>&1 &
    fi
}
for svc in rsyslog syslog syslog-ng; do
    restart_service "$svc"
done
wait

# 清除 dmesg 缓冲区
command -v dmesg >/dev/null 2>&1 && dmesg -c >/dev/null 2>&1 || true
SCRIPT

    chmod +x "$temp_script"
    run_silent "正在清除系统日志" "$temp_script"
    rm -f "$temp_script"
}

# ────────────────────────────────────────────────────────────
# 4. 清理临时文件和缓存
# ────────────────────────────────────────────────────────────
clean_temp_files() {
    local temp_script
    temp_script=$(mktemp)

    cat > "$temp_script" << 'SCRIPT'
#!/bin/bash
set -euo pipefail

find /tmp -mindepth 1 -type f -delete 2>/dev/null || true
find /var/tmp -mindepth 1 -type f -delete 2>/dev/null || true

for user_home in /home/* /root; do
    [ -d "$user_home/.cache" ] || continue
    find "$user_home/.cache" -mindepth 1 -delete 2>/dev/null || true
done

command -v apt-get >/dev/null 2>&1 && apt-get clean -y >/dev/null 2>&1 &
command -v yum     >/dev/null 2>&1 && yum clean all >/dev/null 2>&1 &
command -v dnf     >/dev/null 2>&1 && dnf clean all >/dev/null 2>&1 &
wait
SCRIPT

    chmod +x "$temp_script"
    run_silent "清理临时文件和缓存" "$temp_script"
    rm -f "$temp_script"
}

# ────────────────────────────────────────────────────────────
# 5. 一键清理全部
# ────────────────────────────────────────────────────────────
run_all_operations() {
    echo -e "\n${GREEN}${BOLD}开始全面系统痕迹清理${NC}\n"

    local operations=(
        "clear_login_logs"
        "clear_system_logs"
        "clean_temp_files"
        "clear_command_history"   # 历史清理放最后
    )

    for op in "${operations[@]}"; do
        $op
        # shellcheck disable=SC2181
        if [ $? -ne 0 ]; then
            echo -e "${YELLOW}⚠️ ${op} 有部分警告，继续执行...${NC}\n"
        fi
    done

    history -c 2>/dev/null || true
    history -w 2>/dev/null || true

    echo -e "\n${GREEN}${BOLD}全面系统痕迹清理完成！${NC}"
    echo -e "${CYAN}✓ 仅清除历史记录，历史功能未被禁用${NC}\n"

    # 断开当前SSH会话：
    # 【重要】只 kill 当前会话的父进程（sshd子进程），
    #   绝不能用 pkill -u root 或 pkill sshd，
    #   那会杀掉 sshd daemon 本身导致所有新连接失败。
    echo -e "${YELLOW}即将断开当前SSH连接...${NC}"
    sleep 2

    # $PPID = 当前bash的父进程（即本次会话的sshd子进程或终端）
    # kill -HUP 让父进程挂断，等同于SSH连接断开，sshd服务本身不受影响
    kill -HUP "$PPID" 2>/dev/null || \
    kill -TERM "$PPID" 2>/dev/null || \
    exit 0
}

# ────────────────────────────────────────────────────────────
# 6. 禁用 SSH 日志
# ────────────────────────────────────────────────────────────
disable_ssh_logs() {
    local temp_script
    temp_script=$(mktemp)

    cat > "$temp_script" << 'SCRIPT'
#!/bin/bash
set -euo pipefail

if ! command -v chattr >/dev/null 2>&1; then
    echo "错误：系统缺少chattr命令" >&2
    exit 1
fi

# 【Bug修复】正确顺序：
#   1. 先移除可能已有的不可变属性（否则truncate会失败）
#   2. 停止正在写入这些文件的服务，防止清空后立刻被重新写入
#   3. 清空文件内容
#   4. 加锁（chattr +i），让后续任何写入尝试都失败
#   5. 重启服务（服务会尝试写入但因锁定而失败，不会记录新内容）

# 停止日志服务（临时）
for svc in rsyslog syslog systemd-logind; do
    systemctl stop "$svc" 2>/dev/null || true
done

for f in /var/log/wtmp /var/log/btmp /var/log/lastlog; do
    [ -f "$f" ] || continue
    chattr -i "$f" 2>/dev/null || true   # 先解锁
    truncate -s 0 "$f" 2>/dev/null || \  # 清空内容
    cat /dev/null > "$f" 2>/dev/null || true
    chattr +i "$f" 2>/dev/null           # 加不可变锁
done

# 重启服务（写入会失败但服务本身正常运行）
for svc in rsyslog syslog systemd-logind; do
    systemctl start "$svc" 2>/dev/null || true
done

echo "SSH登录日志已清空并锁定（wtmp/btmp/lastlog）"
SCRIPT

    chmod +x "$temp_script"
    run_silent "正在禁用SSH日志" "$temp_script"
    rm -f "$temp_script"
}

# ────────────────────────────────────────────────────────────
# 7. 永久禁用历史记录
# ────────────────────────────────────────────────────────────
disable_history_permanently() {
    local temp_script
    temp_script=$(mktemp)

    cat > "$temp_script" << 'SCRIPT'
#!/bin/bash
set -euo pipefail

if [ -d "/etc/profile.d" ]; then
    cat > "/etc/profile.d/disable_history.sh" << 'EOL'
#!/bin/bash
# 全局禁用命令历史记录
unset HISTFILE
export HISTSIZE=0
export HISTFILESIZE=0
EOL
    chmod +x "/etc/profile.d/disable_history.sh"
fi

# 对所有现有用户追加到 .bashrc（防止直接bash登录的情况）
for user_home in /root /home/*; do
    [ -d "$user_home" ] || continue
    rc_file="$user_home/.bashrc"
    if [ -f "$rc_file" ] && ! grep -q "disable_history" "$rc_file" 2>/dev/null; then
        echo -e "\n# 禁用命令历史（由管理员设置）\nunset HISTFILE" >> "$rc_file"
    fi
done

echo "命令历史功能已永久禁用"
SCRIPT

    chmod +x "$temp_script"
    run_silent "正在永久禁用命令历史记录功能" "$temp_script"
    rm -f "$temp_script"

    unset HISTFILE 2>/dev/null || true
    echo -e "\n${GREEN}${BOLD}命令历史记录功能已永久禁用！${NC}"
    echo -e "${YELLOW}需重新登录后对所有用户生效。${NC}\n"
}

# ────────────────────────────────────────────────────────────
# 8. 恢复 SSH 日志
# ────────────────────────────────────────────────────────────
restore_ssh_logs() {
    local temp_script
    temp_script=$(mktemp)

    cat > "$temp_script" << 'SCRIPT'
#!/bin/bash
set -euo pipefail

if ! command -v chattr >/dev/null 2>&1; then
    echo "错误：系统缺少chattr命令" >&2
    exit 1
fi

for f in /var/log/wtmp /var/log/btmp /var/log/lastlog; do
    [ -f "$f" ] && chattr -i "$f" 2>/dev/null || true
done
echo "SSH日志记录功能已恢复（wtmp/btmp/lastlog 已解锁）"
SCRIPT

    chmod +x "$temp_script"
    run_silent "恢复SSH日志记录功能" "$temp_script"
    rm -f "$temp_script"
}

# ────────────────────────────────────────────────────────────
# 9. 恢复历史记录功能
# 【Bug修复】原版只对root恢复HISTFILE，对其他用户无效
# ────────────────────────────────────────────────────────────
restore_history_function() {
    local temp_script
    temp_script=$(mktemp)

    cat > "$temp_script" << 'SCRIPT'
#!/bin/bash
set -euo pipefail

# 移除全局禁用配置
rm -f "/etc/profile.d/disable_history.sh" 2>/dev/null || true

# 对每个用户移除 .bashrc 中的禁用行
for user_home in /root /home/*; do
    [ -d "$user_home" ] || continue
    rc_file="$user_home/.bashrc"
    [ -f "$rc_file" ] || continue

    # 删除之前写入的禁用注释和 unset HISTFILE 行
    sed -i '/# 禁用命令历史（由管理员设置）/d' "$rc_file" 2>/dev/null || true
    sed -i '/^unset HISTFILE$/d'               "$rc_file" 2>/dev/null || true

    # 确保存在 .bash_history 文件
    hist_file="$user_home/.bash_history"
    [ -f "$hist_file" ] || touch "$hist_file" 2>/dev/null || true
    chmod 600 "$hist_file" 2>/dev/null || true
done

echo "命令历史记录功能已恢复"
SCRIPT

    chmod +x "$temp_script"
    run_silent "正在恢复命令历史记录功能" "$temp_script"
    rm -f "$temp_script"

    # 在当前会话中恢复（赋值变量不会报错，不需要 2>/dev/null）
    export HISTFILE=~/.bash_history

    echo -e "\n${GREEN}${BOLD}命令历史记录功能已恢复！${NC}"
    echo -e "${YELLOW}需重新登录或 source ~/.bashrc 后生效。${NC}\n"
}

# ────────────────────────────────────────────────────────────
# 显示验证命令
# ────────────────────────────────────────────────────────────
show_verification_commands() {
    echo -e "\n${YELLOW}${BOLD}验证清理效果的命令:${NC}\n"
    echo -e "  ${CYAN}➜ ${NC}${BOLD}last${NC}                     ${YELLOW}# 检查登录记录${NC}"
    echo -e "  ${CYAN}➜ ${NC}${BOLD}history${NC}                  ${YELLOW}# 检查命令历史${NC}"
    echo -e "  ${CYAN}➜ ${NC}${BOLD}journalctl -u sshd${NC}       ${YELLOW}# 检查SSH日志${NC}"
    echo -e "  ${CYAN}➜ ${NC}${BOLD}ls -la /var/log/${NC}         ${YELLOW}# 检查系统日志${NC}"
    echo -e "  ${CYAN}➜ ${NC}${BOLD}cat ~/.bash_history${NC}      ${YELLOW}# 检查bash历史文件${NC}\n"
}

show_restore_complete() {
    echo -e "\n${GREEN}${BOLD}恢复操作完成！${NC}"
    echo -e "${YELLOW}您可能需要重新登录或 source 配置文件使更改生效。${NC}\n"
}

show_exit_message() {
    echo -e "\n${GREEN}${BOLD}感谢使用本工具，再见！${NC}\n"
}

# ────────────────────────────────────────────────────────────
# 主函数
# ────────────────────────────────────────────────────────────
main() {
    local start_time
    start_time=$(date +%s)

    show_logo
    check_root

    case "${1:-}" in
        -a|--all)
            history -c 2>/dev/null || true
            run_all_operations
            show_verification_commands
            local end_time
            end_time=$(date +%s)
            echo -e "${CYAN}总执行时间: $((end_time - start_time)) 秒${NC}"
            history -c 2>/dev/null || true
            history -w 2>/dev/null || true
            exit 0
            ;;
        -h|--help)
            echo -e "${CYAN}${BOLD}Linux系统痕迹清理与管理工具 ${GREEN}${VERSION}${NC}"
            echo -e "${YELLOW}用法: $0 [选项]${NC}\n"
            echo -e "${GREEN}选项:${NC}"
            echo -e "  ${MAGENTA}-a, --all${NC}     执行所有清理操作"
            echo -e "  ${MAGENTA}-h, --help${NC}    显示此帮助信息"
            exit 0
            ;;
    esac

    # 主菜单循环
    while true; do
        show_menu
        read -r choice

        case $choice in
            1) clear_command_history ;;
            2) clear_login_logs ;;
            3) clear_system_logs ;;
            4) clean_temp_files ;;
            5) run_all_operations ;;
            6) disable_ssh_logs ;;
            7) disable_history_permanently ;;
            8) restore_ssh_logs ;;
            9) restore_history_function ;;
            0)
                show_exit_message
                # 【Bug修复】退出时 choice 已是 "0"，原版 [[ 0 =~ [1-5] ]] 永假
                # 改为：无论如何都最后清一次当前会话历史
                history -c 2>/dev/null || true
                history -w 2>/dev/null || true
                exit 0
                ;;
            *)
                echo -e "${RED}无效的选择，请重新输入${NC}"
                sleep 1
                continue
                ;;
        esac

        # 操作完成后的提示
        if [[ $choice =~ [89] ]]; then
            show_restore_complete
        else
            show_verification_commands
        fi

        if ! confirm "是否继续其他操作" "y"; then
            show_exit_message
            history -c 2>/dev/null || true
            history -w 2>/dev/null || true
            exit 0
        fi
    done
}

main "$@"
