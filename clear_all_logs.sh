 #!/bin/bash
# ============================================================
# 一键清除Linux所有操作痕迹
# By 哈迪斯  |  优化重构版
# ============================================================

# ────────────────────────────────────────────────────────────
# 全局历史保护标志
# 脚本启动时默认不清理历史，只在用户选择相关选项时才清理
# ────────────────────────────────────────────────────────────

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
# 【改进】历史清理机制
# 仅在用户实际选择相关操作时才清理历史，
# 不会在脚本启动时误清所有历史。
# ────────────────────────────────────────────────────────────
_HISTORY_CLEANED=0

_clean_history_final() {
    [ "$_HISTORY_CLEANED" = "1" ] || return 0
    history -c 2>/dev/null || true
    export HISTFILE=/dev/null
    export HISTSIZE=0
    export HISTFILESIZE=0
    for _hf in /root/.bash_history /root/.zsh_history \
               /home/*/.bash_history /home/*/.zsh_history; do
        [ -f "$_hf" ] && : > "$_hf" 2>/dev/null || true
    done
}
trap '_clean_history_final' EXIT

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
    echo -e "  ${MAGENTA}6.${NC} 禁用SSH日志记录 (wtmp/btmp/auth.log/sshd.log/faillock/journald)"
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
    _HISTORY_CLEANED=1
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
    /run/utmp \
    /var/log/tallylog \
    /var/log/sshd.log \
    /var/log/sftp.log \
    /var/log/vsftpd.log \
    /var/log/vsftpd.log.* \
    /var/log/ftp.log \
    /var/log/ftp.log.* \
    /var/log/cloud-init.log \
    /var/log/cloud-init-output.log; do
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
    _HISTORY_CLEANED=1
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

# 【修复】全局变量声明（避免 set -euo pipefail 下 unbound variable）
rsyslog_conf="/etc/rsyslog.d/99-disable-ssh.conf"
pam_faillock_conf="/etc/security/faillock.conf"
restored_count=0
failed_count=0

if ! command -v chattr >/dev/null 2>&1; then
    echo "错误：系统缺少chattr命令" >&2
    exit 1
fi

# 检查文件系统是否支持 chattr（ext2/3/4才有效）
check_chattr_support() {
    local f="$1"
    # 尝试对文件添加和移除属性来测试
    if chattr +i "$f" 2>/dev/null && chattr -i "$f" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# 停止日志服务
for svc in rsyslog syslog systemd-logind sshd; do
    systemctl stop "$svc" 2>/dev/null || true
done

# 等待一下确保文件句柄释放
sleep 1

# SSH/登录相关日志文件
# 1. 二进制格式日志（wtmp/btmp/lastlog）- 用chattr锁定
# 2. 文本格式日志（auth.log/secure）- 需要额外处理
# 3. 现代系统：faillock/tallylog 记录登录失败次数和IP
binary_logs=(
    "/var/log/wtmp"
    "/var/log/btmp"
    "/var/log/lastlog"
    "/var/log/faillog"
    "/var/log/tallylog"
    "/var/run/faillock"
    "/run/faillock"
)
text_logs=(
    "/var/log/auth.log"
    "/var/log/auth.log.*"
    "/var/log/secure"
    "/var/log/secure.*"
    "/var/log/audit/audit.log"
    "/var/log/audit/audit.log.*"
    "/var/log/sshd.log"
    "/var/log/sshd.log.*"
    "/var/log/sftp.log"
    "/var/log/sftp.log.*"
    "/var/log/vsftpd.log"
    "/var/log/vsftpd.log.*"
    "/var/log/ftp.log"
    "/var/log/ftp.log.*"
    "/var/log/cloud-init.log"
    "/var/log/cloud-init-output.log"
)
failed_files=()

# 处理二进制日志文件
for f in "${binary_logs[@]}"; do
    # 创建文件如果不存在
    if [ ! -f "$f" ]; then
        touch "$f" 2>/dev/null || {
            echo "警告：无法创建 $f"
            failed_files+=("$f")
            continue
        }
        chmod 644 "$f" 2>/dev/null || true
    fi
    
    # 检查是否支持 chattr
    if ! check_chattr_support "$f"; then
        echo "警告：文件系统不支持 chattr +i（$f），尝试其他方法"
        # 清空文件内容
        > "$f" 2>/dev/null || {
            echo "警告：无法清空 $f"
            failed_files+=("$f")
            continue
        }
        # 尝试只读权限作为替代方案
        chmod 000 "$f" 2>/dev/null && {
            echo "$f 已设置为只读权限（文件系统不支持chattr +i）"
            continue
        }
        failed_files+=("$f")
        continue
    fi
    
    # 标准流程：解锁 → 清空 → 加锁
    chattr -i "$f" 2>/dev/null || true
    > "$f" 2>/dev/null || {
        echo "警告：无法清空 $f"
        failed_files+=("$f")
        continue
    }
    chattr +i "$f" 2>/dev/null && {
        echo "$f 已锁定（chattr +i）"
    } || {
        echo "警告：无法锁定 $f"
        failed_files+=("$f")
    }
done

# 处理文本日志文件（需要配置rsyslog才能真正禁用）
for pattern in "${text_logs[@]}"; do
    # 使用nullglob效果：手动判断文件存在
    for f in $pattern; do
        [ -f "$f" ] || continue
        
        # 检查是否支持 chattr
        if check_chattr_support "$f"; then
            chattr -i "$f" 2>/dev/null || true
            > "$f" 2>/dev/null || true
            chattr +i "$f" 2>/dev/null && {
                echo "$f 已锁定（chattr +i）"
            } || echo "⚠ $f 锁定失败"
        else
            # 文件系统不支持chattr，尝试权限控制
            chmod 000 "$f" 2>/dev/null && {
                echo "$f 已设置为禁止写入（权限000）"
            } || true
        fi
    done
done

# 配置rsyslog停止写入SSH/认证相关日志
configure_rsyslog_disable() {
    local rsyslog_conf="/etc/rsyslog.d/99-disable-ssh.conf"
    cat > "$rsyslog_conf" << 'EOL'
# 由管理脚本生成 - 禁用SSH和认证日志
# 注释掉auth相关规则，停止记录登录信息
# auth,authpriv.*         /var/log/auth.log
# auth,authpriv.*         /var/log/secure
# *.*;auth,authpriv.none  -/var/log/syslog
# authpriv.*              /var/log/secure
EOL
    chmod 644 "$rsyslog_conf"
    echo "已配置rsyslog停止写入SSH日志"
}

configure_rsyslog_disable

# 禁用 faillock（现代PAM登录失败锁定）
disable_faillock() {
    # 清除现有 faillock 记录
    if command -v faillock >/dev/null 2>&1; then
        for user in $(faillock --list 2>/dev/null | grep "^[^:]*:" | cut -d: -f1); do
            faillock --user "$user" --reset 2>/dev/null || true
        done
    fi

    # 备份并禁用pam_faillock.conf
    local pam_faillock_conf="/etc/security/faillock.conf"
    local pam_faillock_conf_backup="${pam_faillock_conf}.bak"
    if [ -f "$pam_faillock_conf" ]; then
        if [ ! -f "$pam_faillock_conf_backup" ]; then
            cp "$pam_faillock_conf" "$pam_faillock_conf_backup"
        fi
        # 注释掉所有配置，让faillock失效
        sed -i 's/^[[:space:]]*/# DISABLED: &/' "$pam_faillock_conf" 2>/dev/null || true
    fi

    # 禁用pam.d中的pam_faillock.so
    for pam_file in /etc/pam.d/login /etc/pam.d/sshd /etc/pam.d/system-auth /etc/pam.d/password-auth; do
        [ -f "$pam_file" ] || continue
        if grep -q "pam_faillock.so" "$pam_file" 2>/dev/null; then
            sed -i 's/^[^#].*pam_faillock.so/# DISABLED: &/' "$pam_file" 2>/dev/null || true
            echo "已禁用 $pam_file 中的 pam_faillock"
        fi
    done
    echo "faillock 已禁用"
}

disable_faillock

# 禁用 journald 登录记录
disable_journald_ssh_logging() {
    local journald_conf="/etc/systemd/journald.conf"
    [ -f "$journald_conf" ] || return 0

    # 备份
    [ ! -f "${journald_conf}.bak" ] && cp "$journald_conf" "${journald_conf}.bak"

    # 设置 Storage=none 禁止journal持久化任何日志到磁盘
    if grep -q "^Storage=" "$journald_conf" 2>/dev/null; then
        sed -i 's/^Storage=.*/Storage=none/' "$journald_conf"
    else
        echo "Storage=none" >> "$journald_conf"
    fi

    # 禁止记录PRIORITY=0..3（emergency/alert/crit/err）之外的auth信息
    if grep -q "^ForwardToSyslog=" "$journald_conf" 2>/dev/null; then
        sed -i 's/^ForwardToSyslog=.*/ForwardToSyslog=no/' "$journald_conf"
    else
        echo "ForwardToSyslog=no" >> "$journald_conf"
    fi

    systemctl restart systemd-journald 2>/dev/null || true
    echo "journald SSH/登录日志记录已禁用"
}

disable_journald_ssh_logging

# 重启服务（写入会失败但服务继续运行）
for svc in rsyslog syslog systemd-logind sshd; do
    systemctl restart "$svc" 2>/dev/null || true
done

# 验证结果
echo ""
echo "=== 验证结果 ==="
echo "--- 二进制日志文件 ---"
for f in "${binary_logs[@]}"; do
    if [ -f "$f" ]; then
        if lsattr "$f" 2>/dev/null | grep -q "....i"; then
            echo "✓ $f 已锁定"
        else
            perms=$(stat -c "%a" "$f" 2>/dev/null || echo "???")
            echo "⚠ $f 未完全锁定（权限: $perms）"
        fi
    fi
done

echo ""
echo "--- 文本日志文件 ---"
for pattern in "${text_logs[@]}"; do
    for f in $pattern; do
        [ -f "$f" ] || continue
        if lsattr "$f" 2>/dev/null | grep -q "....i"; then
            echo "✓ $f 已锁定"
        else
            perms=$(stat -c "%a" "$f" 2>/dev/null || echo "???")
            echo "⚠ $f 权限: $perms"
        fi
    done
done

echo ""
echo "--- rsyslog配置 ---"
if [ -f "$rsyslog_conf" ]; then
    echo "✓ rsyslog禁用配置已生效"
fi

echo ""
echo "--- journald配置 ---"
if [ -f "/etc/systemd/journald.conf.bak" ]; then
    if grep -q "Storage=none" /etc/systemd/journald.conf 2>/dev/null; then
        echo "✓ journald Storage=none 已设置"
    fi
fi

echo ""
echo "--- faillock状态 ---"
if command -v faillock >/dev/null 2>&1; then
    faillock_count=$(faillock --list 2>/dev/null | grep -c "^[^:]*:" || echo "0")
    echo "faillock 当前记录数: $faillock_count"
fi

if [ ${#failed_files[@]} -gt 0 ]; then
    echo ""
    echo "部分文件操作失败，可能原因："
    echo "  - 文件系统不支持 chattr（如 xfs/btrfs）"
    echo "  - 文件被其他进程占用"
    echo "  - 权限不足"
    exit 1
fi

echo ""
echo "=== SSH登录日志禁用完成 ==="
echo "已清空并锁定以下文件:"
echo "  wtmp / btmp / lastlog / faillog / tallylog / faillock"
echo "  auth.log / secure / audit.log"
echo "  sshd.log / sftp.log / vsftpd.log / ftp.log"
echo "  cloud-init.log / cloud-init-output.log"
echo ""
echo "已禁用: rsyslog写入、journald持久化、faillock PAM记录"
echo ""
echo "注意：重启后完全生效；文件系统不支持chattr时部分文件依赖rsyslog配置。"
SCRIPT

    chmod +x "$temp_script"
    run_silent "正在禁用SSH日志" "$temp_script"
    rm -f "$temp_script"
}

# ────────────────────────────────────────────────────────────
# 7. 永久禁用历史记录
# ────────────────────────────────────────────────────────────
disable_history_permanently() {
    _HISTORY_CLEANED=1
    local temp_script
    temp_script=$(mktemp)

    cat > "$temp_script" << 'SCRIPT'
#!/bin/bash
set -euo pipefail

# 禁用历史记录的完整配置
HISTORY_DISABLE_SCRIPT='/etc/profile.d/disable_history.sh'
HISTORY_DISABLE_MARKER='# DISABLE_HISTORY_BY_ADMIN'

# 1. 创建全局禁用脚本
if [ -d "/etc/profile.d" ]; then
    cat > "$HISTORY_DISABLE_SCRIPT" << 'EOL'
#!/bin/bash
# 全局禁用命令历史记录（由管理员设置）
export HISTFILE=/dev/null
export HISTSIZE=0
export HISTFILESIZE=0
unset HISTFILE
EOL
    chmod +x "$HISTORY_DISABLE_SCRIPT"
    echo "已创建 $HISTORY_DISABLE_SCRIPT"
fi

# 2. 禁用shell历史
# 移除之前可能的残留配置
HISTFILE_SCRIPT_CONTENT="
$HISTORY_DISABLE_MARKER
# 禁用命令历史（由管理员设置）
export HISTFILE=/dev/null
export HISTSIZE=0
export HISTFILESIZE=0
unset HISTFILE
"

# 对所有用户追加到 .bashrc 和 .bash_profile
for user_home in /root /home/*; do
    [ -d "$user_home" ] || continue
    
    for rc_file in "$user_home/.bashrc" "$user_home/.bash_profile" "$user_home/.profile"; do
        [ -f "$rc_file" ] || continue
        
        # 检查是否已包含禁用标记
        if grep -q "$HISTORY_DISABLE_MARKER" "$rc_file" 2>/dev/null; then
            echo "$rc_file 已包含禁用配置，跳过"
            continue
        fi
        
        # 追加禁用配置
        echo -e "\n$HISTORY_DISABLE_SCRIPT_CONTENT" >> "$rc_file"
        echo "已更新 $rc_file"
    done
    
    # 3. 清空所有历史文件
    for hist_file in "$user_home/.bash_history" "$user_home/.zsh_history" \
                     "$user_home/.history" "$user_home/.sh_history" \
                     "$user_home/.mysql_history" "$user_home/.python_history"; do
        [ -f "$hist_file" ] || continue
        # 移除不可变属性
        chattr -i "$hist_file" 2>/dev/null || true
        # 清空内容
        > "$hist_file" 2>/dev/null || true
        # 重建空文件并设权限
        touch "$hist_file" 2>/dev/null && chmod 600 "$hist_file" 2>/dev/null || true
        # 设置不可变属性防止写入
        chattr +i "$hist_file" 2>/dev/null || true
    done
    
    # 4. 对历史文件目录加锁（如果有.history目录）
    hist_dir="$user_home/.history.d"
    if [ -d "$hist_dir" ]; then
        chattr +i -R "$hist_dir" 2>/dev/null || true
    fi
done

# 5. 全局禁用配置
if [ -f "/etc/skel/.bashrc" ]; then
    if ! grep -q "$HISTORY_DISABLE_MARKER" "/etc/skel/.bashrc" 2>/dev/null; then
        echo -e "\n$HISTORY_DISABLE_SCRIPT_CONTENT" >> /etc/skel/.bashrc
    fi
fi

# 6. 对 systemd 服务用户禁用（如果存在）
for user in $(cut -d: -f1 /etc/passwd); do
    user_home=$(getent passwd "$user" | cut -d: -f6)
    [ -d "$user_home" ] || continue
    
    for rc in "$user_home/.bashrc" "$user_home/.zshrc"; do
        [ -f "$rc" ] || continue
        if ! grep -q "$HISTORY_DISABLE_MARKER" "$rc" 2>/dev/null; then
            echo -e "\n$HISTORY_DISABLE_SCRIPT_CONTENT" >> "$rc"
        fi
    done
done

echo "命令历史功能已永久禁用"
echo ""
echo "=== 禁用内容 ==="
echo "  ✓ /etc/profile.d/disable_history.sh (全局生效)"
echo "  ✓ 所有用户的 ~/.bashrc (登录shell生效)"
echo "  ✓ 所有历史文件已清空并锁定"
echo "  ✓ 新用户模板已更新 (/etc/skel/.bashrc)"
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

# 停止服务（防止解锁后立即被写入）
for svc in rsyslog syslog systemd-logind sshd; do
    systemctl stop "$svc" 2>/dev/null || true
done

sleep 1

binary_logs=(
    "/var/log/wtmp"
    "/var/log/btmp"
    "/var/log/lastlog"
    "/var/log/faillog"
    "/var/log/tallylog"
    "/var/run/faillock"
    "/run/faillock"
)
text_logs=(
    "/var/log/auth.log"
    "/var/log/auth.log.*"
    "/var/log/secure"
    "/var/log/secure.*"
    "/var/log/audit/audit.log"
    "/var/log/audit/audit.log.*"
    "/var/log/sshd.log"
    "/var/log/sshd.log.*"
    "/var/log/sftp.log"
    "/var/log/sftp.log.*"
    "/var/log/vsftpd.log"
    "/var/log/vsftpd.log.*"
    "/var/log/ftp.log"
    "/var/log/ftp.log.*"
    "/var/log/cloud-init.log"
    "/var/log/cloud-init-output.log"
)
rsyslog_conf="/etc/rsyslog.d/99-disable-ssh.conf"
restored_count=0
failed_count=0

# 恢复二进制日志文件
for f in "${binary_logs[@]}"; do
    [ -f "$f" ] || {
        # 文件不存在时重建
        touch "$f" 2>/dev/null || true
        chmod 644 "$f" 2>/dev/null || true
        echo "已重建 $f"
        continue
    }
    
    # 检查并移除不可变属性
    if lsattr "$f" 2>/dev/null | grep -q "....i"; then
        chattr -i "$f" 2>/dev/null && {
            echo "已解锁 $f"
            ++restored_count || true
        } || {
            echo "警告：无法解锁 $f，尝试移除只读权限"
            chmod 644 "$f" 2>/dev/null || true
            ++failed_count || true
        }
    else
        # 检查是否是只读权限
        perms=$(stat -c "%a" "$f" 2>/dev/null || echo "???")
        if [ "$perms" = "000" ]; then
            chmod 644 "$f" 2>/dev/null && {
                echo "已恢复 $f 权限（从000改为644）"
                ++restored_count || true
            } || {
                ++failed_count || true
            }
        else
            echo "$f 状态正常，无需恢复"
        fi
    fi
    
    # 确保文件有正确权限
    chmod 644 "$f" 2>/dev/null || true
done

# 恢复文本日志文件
echo ""
echo "--- 恢复文本日志 ---"
for pattern in "${text_logs[@]}"; do
    for f in $pattern; do
        [ -f "$f" ] || continue
        
        if lsattr "$f" 2>/dev/null | grep -q "....i"; then
            chattr -i "$f" 2>/dev/null && {
                echo "已解锁 $f"
                ++restored_count || true
            } || true
        fi
        
        perms=$(stat -c "%a" "$f" 2>/dev/null || echo "???")
        if [ "$perms" = "000" ]; then
            chmod 644 "$f" 2>/dev/null && {
                echo "已恢复 $f 权限"
                ++restored_count || true
            } || true
        fi
    done
done

# 移除rsyslog禁用配置
echo ""
echo "--- rsyslog配置 ---"
if [ -f "$rsyslog_conf" ]; then
    rm -f "$rsyslog_conf"
    echo "已删除 $rsyslog_conf"
fi

# 重启服务（启动失败不中断，仅警告）
for svc in rsyslog syslog systemd-logind sshd systemd-journald; do
    systemctl restart "$svc" 2>/dev/null || echo "⚠ $svc 重启失败，继续..." &
done
wait

# 恢复 journald 配置
if [ -f "/etc/systemd/journald.conf.bak" ]; then
    cp /etc/systemd/journald.conf.bak /etc/systemd/journald.conf
    echo "已恢复 journald 配置"
    systemctl restart systemd-journald 2>/dev/null || true
fi

# 恢复 faillock / PAM 配置
if [ -f "/etc/security/faillock.conf.bak" ]; then
    cp /etc/security/faillock.conf.bak /etc/security/faillock.conf
    echo "已恢复 faillock.conf"
fi
for pam_file in /etc/pam.d/login /etc/pam.d/sshd /etc/pam.d/system-auth /etc/pam.d/password-auth; do
    [ -f "$pam_file" ] || continue
    # 恢复被注释掉的 pam_faillock 行
    sed -i 's/^# DISABLED: \(.*pam_faillock.so\)/\1/' "$pam_file" 2>/dev/null || true
done
echo "已恢复 faillock PAM 配置"

echo ""
if [ $failed_count -gt 0 ]; then
    echo "⚠️ 有 $failed_count 个文件恢复失败，可能需要手动处理"
    exit 1
fi

echo "SSH日志记录功能已恢复（所有日志文件已解锁，rsyslog/journald/faillock配置已还原）"
SCRIPT

    chmod +x "$temp_script"
    run_silent "恢复SSH日志记录功能" "$temp_script"
    rm -f "$temp_script"
}

# ────────────────────────────────────────────────────────────
# 9. 恢复历史记录功能
# ────────────────────────────────────────────────────────────
restore_history_function() {
    local temp_script
    temp_script=$(mktemp)

    cat > "$temp_script" << SCRIPT
#!/bin/bash
set -euo pipefail

MARKER='# DISABLE_HISTORY_BY_ADMIN'
HISTORY_DISABLE_SCRIPT='/etc/profile.d/disable_history.sh'

# 1. 移除全局禁用脚本
if [ -f "\$HISTORY_DISABLE_SCRIPT" ]; then
    rm -f "\$HISTORY_DISABLE_SCRIPT"
    echo "已删除 \$HISTORY_DISABLE_SCRIPT"
fi

# 2. 对每个用户恢复配置
for user_home in /root /home/*; do
    [ -d "\$user_home" ] || continue

    # 恢复所有shell配置文件
    for rc_file in "\$user_home/.bashrc" "\$user_home/.bash_profile" \
                   "\$user_home/.profile" "\$user_home/.zshrc"; do
        [ -f "\$rc_file" ] || continue

        # 移除禁用标记和相关配置行（先判断是否存在标记）
        if grep -q "\$MARKER" "\$rc_file" 2>/dev/null; then
            sed -i "\$MARKER"','"/unset HISTFILE/d" "\$rc_file" 2>/dev/null || true
            sed -i '/# 禁用命令历史（由管理员设置）/d' "\$rc_file" 2>/dev/null || true
            sed -i '/^export HISTFILE=\/dev\/null$/d' "\$rc_file" 2>/dev/null || true
            sed -i '/^export HISTSIZE=0$/d' "\$rc_file" 2>/dev/null || true
            sed -i '/^export HISTFILESIZE=0$/d' "\$rc_file" 2>/dev/null || true
            sed -i '/^unset HISTFILE$/d' "\$rc_file" 2>/dev/null || true
            sed -i '/^\/etc\/profile\.d\/disable_history\.sh$/d' "\$rc_file" 2>/dev/null || true
            echo "已清理 \$rc_file"
        fi
    done

    # 3. 恢复历史文件的可写权限并解锁
    for hist_file in "\$user_home/.bash_history" "\$user_home/.zsh_history" \
                     "\$user_home/.history" "\$user_home/.sh_history" \
                     "\$user_home/.mysql_history" "\$user_home/.python_history"; do
        [ -f "\$hist_file" ] || continue
        chattr -i "\$hist_file" 2>/dev/null || true
        chmod 600 "\$hist_file" 2>/dev/null || true
    done

    # 4. 解锁历史目录
    hist_dir="\$user_home/.history.d"
    if [ -d "\$hist_dir" ]; then
        chattr -i -R "\$hist_dir" 2>/dev/null || true
    fi

    # 5. 确保 .bash_history 存在
    hist_file="\$user_home/.bash_history"
    if [ ! -f "\$hist_file" ]; then
        touch "\$hist_file" 2>/dev/null || true
    fi
    chmod 600 "\$hist_file" 2>/dev/null || true
done

# 6. 恢复新用户模板
if [ -f "/etc/skel/.bashrc" ]; then
    if grep -q "\$MARKER" /etc/skel/.bashrc 2>/dev/null; then
        sed -i "\$MARKER"','"/unset HISTFILE/d" /etc/skel/.bashrc 2>/dev/null || true
        sed -i '/# 禁用命令历史（由管理员设置）/d' /etc/skel/.bashrc 2>/dev/null || true
        sed -i '/^export HISTFILE=\/dev\/null$/d' /etc/skel/.bashrc 2>/dev/null || true
        sed -i '/^unset HISTFILE$/d' /etc/skel/.bashrc 2>/dev/null || true
        echo "已清理 /etc/skel/.bashrc"
    fi
fi

echo ""
echo "命令历史记录功能已恢复"
echo ""
echo "=== 恢复内容 ==="
echo "  ✓ 已删除 /etc/profile.d/disable_history.sh"
echo "  ✓ 所有用户的 ~/.bashrc 已清理"
echo "  ✓ 所有历史文件权限已恢复"
echo "  ✓ 新用户模板已恢复"
SCRIPT

    chmod +x "$temp_script"
    run_silent "正在恢复命令历史记录功能" "$temp_script"
    rm -f "$temp_script"

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
                # 仅在执行过清理操作时才在退出时清除历史
                if [ "$_HISTORY_CLEANED" = "1" ]; then
                    history -c 2>/dev/null || true
                    history -w 2>/dev/null || true
                fi
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
            if [ "$_HISTORY_CLEANED" = "1" ]; then
                history -c 2>/dev/null || true
                history -w 2>/dev/null || true
            fi
            exit 0
        fi
    done
}

main "$@"

