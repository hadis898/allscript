#!/bin/bash
# ============================================================
# 一键清除Linux所有操作痕迹
# By Uyiosa Idahosa
# ============================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # 恢复默认颜色

# 版本号常量
VERSION="v2025.04.27"

# 生成重复字符的函数
repeat_char() {
    local char="$1"
    local count="$2"
    local line=""
    for ((i=0; i<count; i++)); do
        line="${line}${char}"
    done
    echo "$line"
}

# Logo显示函数
show_logo() {
    clear
    echo -e "${CYAN}${BOLD}Linux系统痕迹清理与管理工具 ${GREEN}${VERSION}${NC}"
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

# 显示简单进度函数 (不依赖bc命令)
progress_bar() {
    local bar_size=30
    local char="#"
    local sleep_time=0.02  # 减少延迟时间提高性能
    
    echo -ne "${YELLOW}[${NC}"
    for i in $(seq 1 $bar_size); do
        sleep $sleep_time
        echo -ne "${GREEN}${char}${NC}"
    done
    echo -e "${YELLOW}] ${GREEN}完成!${NC}"
}

# 静默执行函数(带进度条)
run_silent() {
    local description="$1"
    echo -e "${CYAN}➜ ${BOLD}${description}${NC}"
    shift
    
    # 创建临时文件存储错误输出
    local temp_err=$(mktemp)
    local temp_out=$(mktemp)
    
    # 启动进程并将输出重定向到临时文件
    (timeout 300 "$@" >"$temp_out" 2>"$temp_err" || echo "错误代码: $?" >> "$temp_err") &
    local pid=$!
    
    # 显示进度条
    progress_bar
    
    # 等待进程完成，但设置超时避免无限等待
    if ! wait $pid 2>/dev/null; then
        kill -9 $pid 2>/dev/null || true
        echo -e "  ${RED}⚠️ 操作超时或被中断${NC}"
        cat "$temp_err" >> "$temp_out"
        echo "操作被终止(可能超时)" >> "$temp_out"
    fi
    
    # 检查是否有错误输出
    if [ -s "$temp_err" ]; then
        echo -e "  ${YELLOW}⚠️ 操作完成(有部分警告)${NC}"
        
        # 显示前5行错误信息
        echo -e "${YELLOW}警告详情 (前5行):${NC}"
        head -n 5 "$temp_err" | while read line; do
            echo -e "  ${RED}→ ${line}${NC}"
        done
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
    local default="$2"
    
    local prompt_symbol
    local yn_hint
    local response
    
    if [[ "$default" =~ [yY] ]]; then
        prompt_symbol="${GREEN}[Y/n]${NC}"
        yn_hint="Y"
    else
        prompt_symbol="${RED}[y/N]${NC}"
        yn_hint="N"
    fi
    
    echo -ne "${CYAN}$prompt ${prompt_symbol}:${NC} "
    read response
    
    if [[ -z "$response" ]]; then
        response=$yn_hint
    fi
    
    if [[ "$response" =~ [yY] ]]; then
        return 0
    else
        return 1
    fi
}

# 主菜单函数
show_menu() {
    local title="Linux系统痕迹清理与管理工具"
    
    echo -e "\n${MAGENTA}${BOLD}${title}${NC}\n"
    
    # 清理选项部分
    echo -e "${GREEN}清理选项:${NC}"
    echo -e "  ${MAGENTA}1.${NC} 清除命令历史及bash记录"
    echo -e "  ${MAGENTA}2.${NC} 清除登录日志和认证记录"
    echo -e "  ${MAGENTA}3.${NC} 清除系统日志与journald记录"
    echo -e "  ${MAGENTA}4.${NC} 清理临时文件和缓存"
    echo -e "  ${MAGENTA}5.${NC} 一键执行所有清理操作"
    
    # 禁用选项部分
    echo -e "\n${GREEN}禁用选项:${NC}"
    echo -e "  ${MAGENTA}6.${NC} 禁用SSH日志记录"
    echo -e "  ${MAGENTA}7.${NC} 永久禁用命令历史记录功能"
    
    # 恢复选项部分
    echo -e "\n${GREEN}恢复选项:${NC}"
    echo -e "  ${MAGENTA}8.${NC} 恢复SSH日志记录功能"
    echo -e "  ${MAGENTA}9.${NC} 恢复命令历史记录功能"
    echo -e "  ${MAGENTA}0.${NC} 退出程序\n"
    
    echo -ne "${CYAN}请选择操作选项 ${YELLOW}[0-9]${NC}: "
}

# 清除命令历史函数
clear_command_history() {
    # 创建临时脚本文件
    local temp_script=$(mktemp)
    
    # 将要执行的命令写入临时脚本文件
    cat > "$temp_script" << 'EOF'
#!/bin/bash
# 清空所有用户的历史文件
for user_home in /root /home/*; do
    if [ ! -d "$user_home" ]; then
        continue
    fi

    # 清理历史文件列表
    hist_files=(
        "$user_home/.bash_history"
        "$user_home/.zsh_history"
        "$user_home/.history" 
        "$user_home/.sh_history"
        "$user_home/.mysql_history"
        "$user_home/.python_history"
        "$user_home/.sqlite_history"
    )
    
    for hist_file in "${hist_files[@]}"; do
        if [ -f "$hist_file" ]; then
            # 检查文件权限并优化清理方式
            if [ -w "$hist_file" ]; then
                # 如果文件可写，先尝试移除不可变属性
                chattr -i "$hist_file" 2>/dev/null || true
                
                # 清空文件内容的几种方法尝试
                # 方法1: 使用重定向
                : > "$hist_file" 2>/dev/null || \
                # 方法2: 使用cat命令
                cat /dev/null > "$hist_file" 2>/dev/null || \
                # 方法3: 使用truncate命令
                truncate -s 0 "$hist_file" 2>/dev/null
                
                # 再次检查是否成功清空
                if [ -s "$hist_file" ]; then
                    # 如果文件仍有内容，尝试创建空文件替换
                    touch "$hist_file.new" 2>/dev/null && \
                    mv -f "$hist_file.new" "$hist_file" 2>/dev/null
                fi
            else
                # 文件不可写，但我们是root用户，尝试先修改权限
                chmod u+w "$hist_file" 2>/dev/null && \
                : > "$hist_file" 2>/dev/null && \
                chmod u-w "$hist_file" 2>/dev/null
            fi
        fi
    done
done

# 清除当前shell的历史
history -c 2>/dev/null || true
history -w 2>/dev/null || true

# 确保系统没有保留任何历史相关文件
find /var/spool/ /var/log/ /var/tmp/ /tmp/ -name "*history*" -type f 2>/dev/null | while read hist_file; do
    if [ -w "$hist_file" ]; then
        truncate -s 0 "$hist_file" 2>/dev/null || : > "$hist_file" 2>/dev/null
    else
        chmod u+w "$hist_file" 2>/dev/null && \
        truncate -s 0 "$hist_file" 2>/dev/null && \
        chmod u-w "$hist_file" 2>/dev/null
    fi
done
EOF

    # 添加执行权限
    chmod +x "$temp_script"
    
    # 执行临时脚本
    run_silent "正在清除命令历史" "$temp_script"
    
    # 清理临时脚本
    rm -f "$temp_script"
}

# 清除登录日志函数
clear_login_logs() {
    # 定义要清理的日志文件列表
    local log_files=(
        "/var/log/wtmp"
        "/var/log/btmp"
        "/var/log/lastlog"
        "/var/log/faillog"
        "/var/run/utmp"
        "/run/utmp"
    )
    
    # 定义要清理的auth日志模式
    local auth_patterns=(
        "/var/log/auth.log*"
        "/var/log/secure*"
        "/var/log/audit/audit.log*"
    )
    
    # 创建临时脚本文件而不是直接使用bash -c
    local temp_script=$(mktemp)
    
    # 将要执行的命令写入临时脚本文件
    cat > "$temp_script" << 'EOF'
#!/bin/bash
# 清理标准日志文件函数
clear_log_file() {
    local log_file="$1"
    if [ -f "$log_file" ]; then
        # 使用truncate命令更快速地清空文件
        truncate -s 0 "$log_file" 2>/dev/null || \
        cat /dev/null > "$log_file" 2>/dev/null || \
        echo > "$log_file" 2>/dev/null
        
        # 如果是lastlog，使用dd命令清空
        if [[ "$log_file" == *"lastlog"* ]]; then
            dd if=/dev/null of="$log_file" bs=1 count=0 2>/dev/null || true
        fi
    fi
}

# 并行清空标准日志文件
for log_file in "$@"; do
    clear_log_file "$log_file" &
done

# 并行清空auth日志文件
for pattern in "${auth_patterns[@]}"; do
    for auth_log in $pattern; do
        if [ -f "$auth_log" ]; then
            clear_log_file "$auth_log" &
        fi
    done
done

# 等待所有后台任务完成
wait

# 重启相关服务使更改生效，使用函数使代码更清晰
restart_service() {
    local service_name="$1"
    # 优先使用systemctl，失败则尝试service命令
    if systemctl is-active $service_name >/dev/null 2>&1; then
        systemctl restart $service_name >/dev/null 2>&1 &
    elif command -v service >/dev/null 2>&1 && service $service_name status >/dev/null 2>&1; then
        service $service_name restart >/dev/null 2>&1 &
    fi
}

# 并行重启服务
for svc in auditd rsyslog syslog syslog-ng; do
    restart_service $svc
done

# 等待所有服务重启完成
wait
EOF

    # 添加执行权限
    chmod +x "$temp_script"
    
    # 执行临时脚本，传递日志文件列表作为参数
    run_silent "正在清除登录记录" "$temp_script" "${log_files[@]}"
    
    # 清理临时脚本
    rm -f "$temp_script"
}

# 清除系统日志函数
clear_system_logs() {
    # 定义常见系统日志文件列表
    local system_logs=(
        "/var/log/syslog"
        "/var/log/messages"
        "/var/log/kern.log"
        "/var/log/dmesg"
        "/var/log/maillog"
        "/var/log/mail.log"
        "/var/log/cron"
        "/var/log/boot.log"
        "/var/log/daemon.log"
        "/var/log/debug"
        "/var/log/apt/history.log"
        "/var/log/apt/term.log"
        "/var/log/dpkg.log"
    )
    
    # 创建临时脚本文件
    local temp_script=$(mktemp)
    
    # 将要执行的命令写入临时脚本文件
    cat > "$temp_script" << 'EOF'
#!/bin/bash
# 清理journalctl日志函数
clear_journald_logs() {
    if ! command -v journalctl >/dev/null 2>&1; then
        return 0
    fi
    
    # 优化：使用vacuum-size代替vacuum-time更快
    journalctl --vacuum-size=1K >/dev/null 2>&1 &
    local pid1=$!
    
    # 并行执行其他journald操作
    {
        journalctl --flush --rotate >/dev/null 2>&1
        
        # 更彻底的清除方式
        if [ -d "/var/log/journal" ]; then
            find /var/log/journal -type f -delete >/dev/null 2>&1
        fi
        
        # 重新创建journal目录结构
        mkdir -p /var/log/journal >/dev/null 2>&1
    } &
    local pid2=$!
    
    # 等待所有journald操作完成
    wait $pid1 $pid2
    
    # 重启journald服务
    systemctl restart systemd-journald >/dev/null 2>&1 &
}

# 清理单个日志文件函数
clear_log_file() {
    local log_file="$1"
    if [ -f "$log_file" ]; then
        # 优先使用truncate命令，速度更快
        truncate -s 0 "$log_file" 2>/dev/null || \
        cat /dev/null > "$log_file" 2>/dev/null
    fi
}

# 启动journald清理（独立线程）
clear_journald_logs &

# 并行清理列表中的系统日志
for log_file in "$@"; do
    clear_log_file "$log_file" &
done

# 并行清空/var/log目录下的log文件（分组进行以减少进程数量）
{
    find /var/log -type f -name "*.log" -print0 | xargs -0 -P4 -n50 truncate -s 0 2>/dev/null || true
    find /var/log -type f -name "*.log.*" -print0 | xargs -0 -P4 -n50 truncate -s 0 2>/dev/null || true
} &

# 并行删除压缩日志文件
find /var/log -type f -name "*.gz" -delete 2>/dev/null &

# 并行清空其他日志文件
find /var/log -type f -size +0 -not -path "*/\.*" -print0 | \
    xargs -0 -P4 -n50 truncate -s 0 2>/dev/null &

# 等待所有清理任务完成
wait

# 重启日志服务函数
restart_logging_services() {
    # 函数化重启服务过程，更清晰
    restart_service() {
        local svc="$1"
        if systemctl is-active $svc >/dev/null 2>&1; then
            systemctl restart $svc >/dev/null 2>&1 &
        elif command -v service >/dev/null 2>&1 && service $svc status >/dev/null 2>&1; then
            service $svc restart >/dev/null 2>&1 &
        fi
    }
    
    # 并行重启所有日志服务
    for svc in rsyslog syslog syslog-ng; do
        restart_service $svc
    done
    
    # 等待所有重启任务完成
    wait
}

# 重启日志服务
restart_logging_services

# 清理dmesg缓冲区（最后执行，不影响之前的操作）
if command -v dmesg >/dev/null 2>&1; then
    dmesg -c >/dev/null 2>&1 || true
fi
EOF

    # 添加执行权限
    chmod +x "$temp_script"
    
    # 执行临时脚本，传递系统日志列表作为参数
    run_silent "正在清除系统日志" "$temp_script" "${system_logs[@]}"
    
    # 清理临时脚本
    rm -f "$temp_script"
}

# 禁用SSH日志
disable_ssh_logs() {
    # 创建临时脚本文件
    local temp_script=$(mktemp)
    
    # 将要执行的命令写入临时脚本文件
    cat > "$temp_script" << 'EOF'
#!/bin/bash
if [ -f "/etc/ssh/sshd_config" ]; then
    # 备份原始配置(如果备份不存在)
    if [ ! -f "/etc/ssh/sshd_config.original" ]; then
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.original 2>/dev/null
    fi
    
    # 修改SSH配置
    sed -i "s/^#*LogLevel.*/LogLevel QUIET/" /etc/ssh/sshd_config
    sed -i "s/^#*SyslogFacility.*/SyslogFacility AUTHPRIV/" /etc/ssh/sshd_config
    
    # 添加或修改额外的日志设置
    if ! grep -q "^LogLevel QUIET" /etc/ssh/sshd_config; then
        echo "LogLevel QUIET" >> /etc/ssh/sshd_config
    fi
    
    # 完全禁用SSH日志记录（更强力的设置）
    for setting in "LogLevel QUIET" "SyslogFacility AUTHPRIV" "PrintLastLog no" "PrintMotd no"; do
        setting_name=$(echo "$setting" | cut -d" " -f1)
        
        # 如果已经有此设置，则修改它
        if grep -q "^$setting_name" /etc/ssh/sshd_config; then
            sed -i "s/^$setting_name.*/$setting/" /etc/ssh/sshd_config
        else
            # 否则添加新的设置
            echo "$setting" >> /etc/ssh/sshd_config
        fi
    done
    
    # 修改rsyslog配置禁止记录SSH日志（如果存在）
    if [ -d "/etc/rsyslog.d" ]; then
        # 创建自定义规则文件来禁止SSH日志
        echo "# 禁止记录SSH日志" > /etc/rsyslog.d/sshd-disable.conf
        echo "if \$programname == 'sshd' then stop" >> /etc/rsyslog.d/sshd-disable.conf
        
        # 重启rsyslog服务
        if command -v systemctl >/dev/null 2>&1; then
            systemctl restart rsyslog >/dev/null 2>&1
        elif command -v service >/dev/null 2>&1; then
            service rsyslog restart >/dev/null 2>&1
        fi
    fi
    
    # 修改主rsyslog配置文件（如果存在）
    if [ -f "/etc/rsyslog.conf" ]; then
        # 备份原始配置
        if [ ! -f "/etc/rsyslog.conf.original" ]; then
            cp /etc/rsyslog.conf /etc/rsyslog.conf.original 2>/dev/null
        fi
        
        # 添加SSH过滤规则到配置文件头部
        if ! grep -q "if \$programname == 'sshd'" /etc/rsyslog.conf; then
            sed -i '1s/^/# 禁止记录SSH日志\nif $programname == "sshd" then stop\n\n/' /etc/rsyslog.conf
        fi
    fi
    
    # 修改syslog配置（如果存在）
    if [ -f "/etc/syslog.conf" ]; then
        # 备份原始配置
        if [ ! -f "/etc/syslog.conf.original" ]; then
            cp /etc/syslog.conf /etc/syslog.conf.original 2>/dev/null
        fi
        
        # 注释掉与auth和sshd相关的行
        sed -i 's/^auth\.\*/#auth\.\*/' /etc/syslog.conf
        sed -i 's/^authpriv\.\*/#authpriv\.\*/' /etc/syslog.conf
    fi
    
    # 屏蔽SSH登录日志的PAM设置
    if [ -d "/etc/pam.d" ] && [ -f "/etc/pam.d/sshd" ]; then
        # 备份原始配置
        if [ ! -f "/etc/pam.d/sshd.original" ]; then
            cp /etc/pam.d/sshd /etc/pam.d/sshd.original 2>/dev/null
        fi
        
        # 注释掉pam_lastlog.so行
        sed -i 's/^session.*pam_lastlog.so/#&/' /etc/pam.d/sshd
        
        # 注释掉其他可能记录日志的PAM模块
        sed -i 's/^session.*pam_motd.so/#&/' /etc/pam.d/sshd
        sed -i 's/^session.*pam_mail.so/#&/' /etc/pam.d/sshd
    fi
    
    # 重启SSH服务
    if command -v service >/dev/null 2>&1; then
        service sshd restart >/dev/null 2>&1 || service ssh restart >/dev/null 2>&1
    elif command -v systemctl >/dev/null 2>&1; then
        systemctl restart sshd >/dev/null 2>&1 || systemctl restart ssh >/dev/null 2>&1
    fi
    
    # 立即清除现有的SSH日志
    for ssh_log in /var/log/auth.log /var/log/secure /var/log/sshd.log /var/log/auth.log.* /var/log/secure.* /var/log/messages; do
        if [ -f "$ssh_log" ]; then
            truncate -s 0 "$ssh_log" 2>/dev/null
        fi
    done
    
    echo "SSH日志已全面禁用并清除" >&2
else
    echo "SSH配置文件不存在" >&2
    exit 1
fi
EOF

    # 添加执行权限
    chmod +x "$temp_script"
    
    # 执行临时脚本
    run_silent "正在禁用SSH日志" "$temp_script"
    
    # 清理临时脚本
    rm -f "$temp_script"
}

# 恢复SSH日志记录功能
restore_ssh_logs() {
    # 创建临时脚本文件
    local temp_script=$(mktemp)
    
    # 将要执行的命令写入临时脚本文件
    cat > "$temp_script" << 'EOF'
#!/bin/bash
# 检查是否存在原始备份
if [ -f "/etc/ssh/sshd_config.original" ]; then
    # 恢复原始备份
    cp /etc/ssh/sshd_config.original /etc/ssh/sshd_config 2>/dev/null
    # 删除备份文件，确保下次禁用时可以创建新的备份
    rm -f "/etc/ssh/sshd_config.original" 2>/dev/null
else
    # 如果没有原始备份，尝试修改当前配置
    if [ -f "/etc/ssh/sshd_config" ]; then
        # 修改到默认日志级别
        sed -i "s/^LogLevel QUIET/LogLevel INFO/" /etc/ssh/sshd_config
        sed -i "s/^#*SyslogFacility.*/SyslogFacility AUTH/" /etc/ssh/sshd_config
        sed -i "s/^PrintLastLog no/PrintLastLog yes/" /etc/ssh/sshd_config
        sed -i "s/^PrintMotd no/PrintMotd yes/" /etc/ssh/sshd_config
    else
        echo "SSH配置文件不存在" >&2
        exit 1
    fi
fi

# 恢复rsyslog配置（如果被修改）
if [ -f "/etc/rsyslog.d/sshd-disable.conf" ]; then
    rm -f "/etc/rsyslog.d/sshd-disable.conf" 2>/dev/null
fi

# 恢复主rsyslog配置，仅当文件存在时操作
if [ -f "/etc/rsyslog.conf.original" ]; then
    cp /etc/rsyslog.conf.original /etc/rsyslog.conf 2>/dev/null
    rm -f "/etc/rsyslog.conf.original" 2>/dev/null
elif [ -f "/etc/rsyslog.conf" ]; then
    # 仅当文件存在时执行sed操作
    sed -i '/^# 禁止记录SSH日志$/d' /etc/rsyslog.conf
    sed -i '/^if $programname == "sshd" then stop$/d' /etc/rsyslog.conf
fi

# 恢复syslog配置
if [ -f "/etc/syslog.conf.original" ]; then
    cp /etc/syslog.conf.original /etc/syslog.conf 2>/dev/null
    rm -f "/etc/syslog.conf.original" 2>/dev/null
fi

# 恢复PAM配置
if [ -f "/etc/pam.d/sshd.original" ]; then
    cp /etc/pam.d/sshd.original /etc/pam.d/sshd 2>/dev/null
    rm -f "/etc/pam.d/sshd.original" 2>/dev/null
else
    # 如果没有备份，尝试取消注释被修改的行
    if [ -f "/etc/pam.d/sshd" ]; then
        sed -i 's/^#\(session.*pam_lastlog.so\)/\1/' /etc/pam.d/sshd
        sed -i 's/^#\(session.*pam_motd.so\)/\1/' /etc/pam.d/sshd
        sed -i 's/^#\(session.*pam_mail.so\)/\1/' /etc/pam.d/sshd
    fi
fi

# 重启相关服务
if command -v systemctl >/dev/null 2>&1; then
    systemctl restart rsyslog >/dev/null 2>&1
    systemctl restart sshd >/dev/null 2>&1 || systemctl restart ssh >/dev/null 2>&1
elif command -v service >/dev/null 2>&1; then
    service rsyslog restart >/dev/null 2>&1
    service sshd restart >/dev/null 2>&1 || service ssh restart >/dev/null 2>&1
fi

echo "SSH日志记录功能已恢复" >&2
EOF

    # 添加执行权限
    chmod +x "$temp_script"
    
    # 执行临时脚本
    run_silent "恢复SSH日志记录功能" "$temp_script"
    
    # 清理临时脚本
    rm -f "$temp_script"
}

# 永久禁用历史记录
disable_history_permanently() {
    # 创建临时脚本文件
    local temp_script=$(mktemp)
    
    # 将要执行的命令写入临时脚本文件
    cat > "$temp_script" << 'EOF'
#!/bin/bash
# 为所有用户添加全局设置
for profile in /etc/profile /etc/bash.bashrc /etc/profile.d/history.sh; do
    # 确保目录存在
    mkdir -p $(dirname "$profile") 2>/dev/null
    
    # 备份原始配置(如果文件存在且备份不存在)
    if [ -f "$profile" ] && [ ! -f "${profile}.original" ]; then
        cp "$profile" "${profile}.original" 2>/dev/null
    fi
    
    # 检查文件是否已经包含禁用历史的设置
    if [ -f "$profile" ] && grep -q "# 禁用命令历史记录 - 系统安全设置" "$profile"; then
        # 已经包含禁用设置，跳过此文件
        continue
    fi
    
    # 移除任何现有的HISTSIZE设置
    if [ -f "$profile" ]; then
        sed -i "/HISTSIZE=/d" "$profile" 2>/dev/null
        sed -i "/HISTFILESIZE=/d" "$profile" 2>/dev/null
        sed -i "/HISTLOG=/d" "$profile" 2>/dev/null
        sed -i "/unset HISTFILE/d" "$profile" 2>/dev/null
        sed -i "/readonly HISTFILE/d" "$profile" 2>/dev/null
        sed -i "/readonly HISTSIZE/d" "$profile" 2>/dev/null
        sed -i "/readonly HISTFILESIZE/d" "$profile" 2>/dev/null
    fi
    
    # 添加禁用历史的设置
    echo "# 禁用命令历史记录 - 系统安全设置" >> "$profile"
    echo "HISTSIZE=0" >> "$profile"
    echo "HISTFILESIZE=0" >> "$profile"
    echo "HISTLOG=" >> "$profile"
    echo "unset HISTFILE" >> "$profile"
    echo "export HISTSIZE HISTFILESIZE HISTLOG" >> "$profile"
done

# 为bash用户设置readonly属性（更强的保护）
# 确保history.sh文件中没有重复配置
if [ -f "/etc/profile.d/history.sh" ] && ! grep -q "readonly HISTFILE" "/etc/profile.d/history.sh"; then
    echo "readonly HISTFILE" >> /etc/profile.d/history.sh
    echo "readonly HISTSIZE" >> /etc/profile.d/history.sh
    echo "readonly HISTFILESIZE" >> /etc/profile.d/history.sh
fi

# 设置当前会话
export HISTSIZE=0
export HISTFILESIZE=0
unset HISTFILE 2>/dev/null || true
EOF

    # 添加执行权限
    chmod +x "$temp_script"
    
    # 执行临时脚本
    run_silent "永久禁用命令历史记录" "$temp_script"
    
    # 清理临时脚本
    rm -f "$temp_script"
}

# 恢复命令历史记录功能
restore_history_function() {
    # 创建临时脚本文件
    local temp_script=$(mktemp)
    
    # 将要执行的命令写入临时脚本文件
    cat > "$temp_script" << 'EOF'
#!/bin/bash
# 恢复原始配置文件
for profile in /etc/profile /etc/bash.bashrc /etc/profile.d/history.sh; do
    if [ -f "${profile}.original" ]; then
        cp "${profile}.original" "$profile" 2>/dev/null
        # 删除备份文件，确保下次禁用时可以创建新的备份
        rm -f "${profile}.original" 2>/dev/null
    else
        # 如果没有原始备份，清除禁用历史的设置
        if [ -f "$profile" ]; then
            sed -i "/# 禁用命令历史记录/d" "$profile" 2>/dev/null
            sed -i "/HISTSIZE=0/d" "$profile" 2>/dev/null
            sed -i "/HISTFILESIZE=0/d" "$profile" 2>/dev/null
            sed -i "/HISTLOG=/d" "$profile" 2>/dev/null
            sed -i "/unset HISTFILE/d" "$profile" 2>/dev/null
            sed -i "/export HISTSIZE HISTFILESIZE HISTLOG/d" "$profile" 2>/dev/null
            sed -i "/readonly HISTFILE/d" "$profile" 2>/dev/null
            sed -i "/readonly HISTSIZE/d" "$profile" 2>/dev/null
            sed -i "/readonly HISTFILESIZE/d" "$profile" 2>/dev/null
        fi
    fi
done

# 完全删除history.sh文件（如果存在）
if [ -f "/etc/profile.d/history.sh" ]; then
    rm -f "/etc/profile.d/history.sh" 2>/dev/null
fi

# 添加默认历史设置到profile
if [ -f "/etc/profile" ]; then
    echo "# 恢复默认命令历史记录设置" >> /etc/profile
    echo "HISTSIZE=1000" >> /etc/profile
    echo "HISTFILESIZE=2000" >> /etc/profile
    echo "export HISTSIZE HISTFILESIZE" >> /etc/profile
fi

# 设置当前会话（虽然readonly变量无法在当前会话修改）
export HISTSIZE=1000 2>/dev/null || true
export HISTFILESIZE=2000 2>/dev/null || true
EOF

    # 添加执行权限
    chmod +x "$temp_script"
    
    # 执行临时脚本
    run_silent "恢复命令历史记录功能" "$temp_script"
    
    # 清理临时脚本
    rm -f "$temp_script"
    
    echo -e "\n${RED}${BOLD}⚠️  重要提示：${NC}${YELLOW}注销并重新登录系统，才能生效。${NC}"
}

# 清理临时文件和缓存
clean_temp_files() {
    # 创建临时脚本文件
    local temp_script=$(mktemp)
    
    # 将要执行的命令写入临时脚本文件
    cat > "$temp_script" << 'EOF'
#!/bin/bash
# 清理/tmp目录 - 使用find命令的-mindepth参数避免删除目录本身
find /tmp -mindepth 1 -type f -delete 2>/dev/null

# 清理/var/tmp目录
find /var/tmp -mindepth 1 -type f -delete 2>/dev/null

# 清理所有用户的缓存目录 - 修复通配符问题
for user_home in /home/*; do
    if [ -d "$user_home/.cache" ]; then
        find "$user_home/.cache" -mindepth 1 -delete 2>/dev/null
    fi
done

# 清理root用户缓存 - 修复通配符问题
if [ -d "/root/.cache" ]; then
    find "/root/.cache" -mindepth 1 -delete 2>/dev/null
fi

# 清理apt缓存(如果存在) - 并行执行
if command -v apt-get >/dev/null 2>&1; then
    apt-get clean -y >/dev/null 2>&1 &
fi

# 清理yum缓存(如果存在) - 并行执行
if command -v yum >/dev/null 2>&1; then
    yum clean all >/dev/null 2>&1 &
fi

# 清理dnf缓存(如果存在) - 并行执行
if command -v dnf >/dev/null 2>&1; then
    dnf clean all >/dev/null 2>&1 &
fi

# 等待所有后台任务完成
wait
EOF

    # 添加执行权限
    chmod +x "$temp_script"
    
    # 执行临时脚本
    run_silent "清理临时文件和缓存" "$temp_script"
    
    # 清理临时脚本
    rm -f "$temp_script"
}

# 执行所有清理操作
run_all_operations() {
    echo -e "\n${GREEN}${BOLD}开始全面系统痕迹清理${NC}\n"
    
    # 定义要执行的操作数组
    local operations=(
        "clear_command_history"
        "clear_login_logs"
        "clear_system_logs"
        "clean_temp_files"
    )
    
    # 遍历执行所有操作
    for op in "${operations[@]}"; do
        $op
        
        # 检查操作是否成功，如果失败给出提示但继续执行
        if [ $? -ne 0 ]; then
            echo -e "${YELLOW}⚠️ ${op} 操作完成但有些警告，继续执行其他操作...${NC}\n"
        fi
    done
    
    echo -e "\n${GREEN}${BOLD}全面系统痕迹清理操作已完成${NC}"
    echo -e "\n${CYAN}✓ 所有痕迹已被清除，系统现在处于安全状态！${NC}\n"
}

# 显示验证命令
show_verification_commands() {
    echo -e "\n${YELLOW}${BOLD}验证清理效果的命令:${NC}\n"
    
    echo -e "${BOLD}${GREEN}可用命令:${NC}"
    echo -e "  ${CYAN}➜ ${NC}${BOLD}last${NC}                     ${YELLOW}# 检查登录记录${NC}"
    echo -e "  ${CYAN}➜ ${NC}${BOLD}history${NC}                  ${YELLOW}# 检查命令历史${NC}"
    echo -e "  ${CYAN}➜ ${NC}${BOLD}journalctl -u sshd${NC}       ${YELLOW}# 检查SSH日志${NC}"
    echo -e "  ${CYAN}➜ ${NC}${BOLD}ls -la /var/log/${NC}         ${YELLOW}# 检查系统日志${NC}"
    echo -e "  ${CYAN}➜ ${NC}${BOLD}cat ~/.bash_history${NC}      ${YELLOW}# 检查bash历史文件${NC}\n"
}

# 显示退出消息
show_exit_message() {
    echo -e "\n${GREEN}${BOLD}感谢使用本工具，再见！${NC}\n"
}

# 显示恢复完成消息
show_restore_complete() {
    echo -e "\n${GREEN}${BOLD}恢复操作已成功完成！${NC}"
    echo -e "${YELLOW}某些更改可能需要注销并重新登录系统后才能完全生效。${NC}\n"
}

# 主函数
main() {
    # 记录开始时间，用于性能监控
    local start_time=$(date +%s)
    
    show_logo
    check_root
    
    # 处理命令行参数
    case "$1" in
        -a|--all)
            run_all_operations
            show_verification_commands
            
            # 计算总执行时间
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            echo -e "${CYAN}总执行时间: ${duration} 秒${NC}"
            exit 0
            ;;
        -h|--help)
            # 显示帮助信息
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
        
        # 使用case语句处理用户选择
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
                exit 0
                ;;
            *)
                echo -e "${RED}无效的选择，请重新输入${NC}"
                sleep 1
                ;;
        esac
        
        # 如果选择了有效操作，显示验证命令并询问是否继续
        if [[ $choice =~ [1-9] ]]; then
            # 根据操作类型显示不同的完成消息
            if [[ $choice == "8" || $choice == "9" ]]; then
                show_restore_complete
            else
                show_verification_commands
            fi
            
            # 询问是否继续其他操作
            if confirm "是否继续其他操作" "y"; then
                continue
            else
                show_exit_message
                exit 0
            fi
        fi
    done
}

# 启动程序(支持 -a 或 --all 参数直接执行所有操作)
main "$@"