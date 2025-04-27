#!/bin/bash
# ============================================================
# 一键清除Linux所有操作痕迹 v2025.04.27
# By Uyiosa Idahosa2
# 使用方法：sudo ./clear_all_logs.sh
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
    echo -e "${BLUE}${BOLD}"
    echo "  ██████╗██╗     ███████╗ █████╗ ██████╗     ████████╗██████╗  █████╗  ██████╗███████╗"
    echo " ██╔════╝██║     ██╔════╝██╔══██╗██╔══██╗    ╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██╔════╝"
    echo " ██║     ██║     █████╗  ███████║██████╔╝       ██║   ██████╔╝███████║██║     █████╗  "
    echo " ██║     ██║     ██╔══╝  ██╔══██║██╔══██╗       ██║   ██╔══██╗██╔══██║██║     ██╔══╝  "
    echo " ╚██████╗███████╗███████╗██║  ██║██║  ██║       ██║   ██║  ██║██║  ██║╚██████╗███████╗"
    echo "  ╚═════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝       ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚══════╝"
    echo -e "${NC}"
    echo -e "${CYAN}${BOLD}                 一键清除Linux所有操作痕迹 ${VERSION}${NC}"
    echo -e "${YELLOW}                       安全、高效、无痕迹操作${NC}\n"
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
    
    echo -ne "${YELLOW}[${NC}"
    for i in $(seq 1 $bar_size); do
        sleep 0.05
        echo -ne "${GREEN}${char}${NC}"
    done
    echo -e "${YELLOW}] ${GREEN}完成!${NC}"
}

# 静默执行函数(带进度条)
run_silent() {
    echo -e "${CYAN}➜ ${BOLD}$1${NC}"
    shift
    
    # 创建临时文件存储错误输出
    local temp_err=$(mktemp)
    
    # 启动进程并将错误输出重定向到临时文件
    ("$@" >/dev/null 2>"$temp_err") &
    local pid=$!
    
    # 显示进度条(简化版)
    progress_bar
    
    # 等待进程完成
    wait $pid
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo -e "  ${GREEN}✓ 操作成功完成${NC}\n"
        rm -f "$temp_err"
        return 0
    else
        echo -e "  ${YELLOW}⚠️ 操作完成(有部分警告)${NC}"
        
        # 如果有错误输出，显示前5行
        if [ -s "$temp_err" ]; then
            echo -e "${YELLOW}警告详情 (前5行):${NC}"
            head -n 5 "$temp_err" | while read line; do
                echo -e "  ${RED}→ ${line}${NC}"
            done
            echo ""
        fi
        
        rm -f "$temp_err"
        return 1
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
    local width=70
    local title="【 清理与恢复操作菜单 】"
    local title_padding=$(( (width - ${#title}) / 2 ))
    
    local horizontal_line=$(repeat_char "─" $width)
    local title_space_prefix=$(repeat_char " " $title_padding)
    
    echo -e "\n${BOLD}${CYAN}╭${horizontal_line}╮${NC}"
    echo -e "${BOLD}${CYAN}│${MAGENTA}${BOLD}${title_space_prefix}${title}${title_space_prefix}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}├${horizontal_line}┤${NC}"
    
    # 清理选项部分 - 确保所有行的长度一致
    echo -e "${BOLD}${CYAN}│${GREEN}${BOLD}                      清理选项                           ${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│                                                                  │${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${MAGENTA}1.${NC} 清除命令历史及bash记录      ${MAGENTA}2.${NC} 清除登录日志和认证记录  ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${MAGENTA}3.${NC} 清除系统日志与journald记录  ${MAGENTA}4.${NC} 禁用SSH日志记录        ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${MAGENTA}5.${NC} 永久禁用命令历史记录功能    ${MAGENTA}6.${NC} 清理临时文件和缓存      ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${MAGENTA}7.${NC} 一键执行所有清理操作                                  ${BOLD}${CYAN}│${NC}"
    
    # 恢复选项部分 - 确保所有行的长度一致
    echo -e "${BOLD}${CYAN}│                                                                  │${NC}"
    echo -e "${BOLD}${CYAN}│${GREEN}${BOLD}                      恢复选项                           ${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│                                                                  │${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${MAGENTA}8.${NC} 恢复SSH日志记录功能         ${MAGENTA}9.${NC} 恢复命令历史记录功能    ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${MAGENTA}0.${NC} 退出程序                                              ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│                                                                  │${NC}"
    echo -e "${BOLD}${CYAN}╰${horizontal_line}╯${NC}"
    
    echo -ne "${CYAN}请选择操作选项 ${YELLOW}[0-9]${NC}: "
}

# 清除命令历史函数
clear_command_history() {
    run_silent "正在清除命令历史" bash -c '
        # 清空所有用户的.bash_history文件
        for user_home in /root /home/*; do
            if [ -d "$user_home" ]; then
                user=$(basename "$user_home")
                # 先将文件清空
                cat /dev/null > "$user_home/.bash_history" 2>/dev/null
                # 然后将文件属性设置为不可变（更彻底）
                chattr +a "$user_home/.bash_history" 2>/dev/null
                # 再次写入空内容
                cat /dev/null > "$user_home/.bash_history" 2>/dev/null
                # 恢复文件属性
                chattr -a "$user_home/.bash_history" 2>/dev/null
                
                # 处理其他可能的shell历史文件
                for hist_file in "$user_home/.zsh_history" "$user_home/.history" "$user_home/.sh_history"; do
                    if [ -f "$hist_file" ]; then
                        cat /dev/null > "$hist_file" 2>/dev/null
                    fi
                done
            fi
        done
        
        # 清除当前shell的历史
        history -c 2>/dev/null
        history -w 2>/dev/null
        
        # 确保系统没有保留任何bash_history相关文件
        find /var/spool/ /var/log/ /var/tmp/ /tmp/ -name "*history*" -type f -delete 2>/dev/null
    '
}

# 清除登录日志函数
clear_login_logs() {
    run_silent "正在清除登录记录" bash -c '
        # 清空标准日志文件
        cat /dev/null > /var/log/wtmp 2>/dev/null
        cat /dev/null > /var/log/btmp 2>/dev/null
        cat /dev/null > /var/log/lastlog 2>/dev/null
        cat /dev/null > /var/log/faillog 2>/dev/null
        
        # 清除utmp
        cat /dev/null > /var/run/utmp 2>/dev/null
        cat /dev/null > /run/utmp 2>/dev/null  # 某些系统使用/run而不是/var/run
        
        # 清除额外的auth日志
        for auth_log in /var/log/auth.log /var/log/secure /var/log/audit/audit.log /var/log/auth.log.* /var/log/secure.*; do
            if [ -f "$auth_log" ]; then
                cat /dev/null > "$auth_log" 2>/dev/null
            fi
        done
        
        # 设置文件大小为0（清空）
        truncate -s 0 /var/log/wtmp 2>/dev/null
        truncate -s 0 /var/log/btmp 2>/dev/null
        truncate -s 0 /var/log/lastlog 2>/dev/null
        truncate -s 0 /var/log/faillog 2>/dev/null
        
        # 尝试删除或清空lastlog数据库
        if [ -f "/var/log/lastlog" ]; then
            dd if=/dev/null of=/var/log/lastlog bs=1 count=0 2>/dev/null
        fi
        
        # 重启相关服务使更改生效
        if command -v service >/dev/null 2>&1; then
            service auditd restart >/dev/null 2>&1
            service rsyslog restart >/dev/null 2>&1
        elif command -v systemctl >/dev/null 2>&1; then
            systemctl restart auditd >/dev/null 2>&1
            systemctl restart rsyslog >/dev/null 2>&1
        fi
        
        # 确保所有日志服务已重启
        for svc in auditd rsyslog syslog syslog-ng; do
            if systemctl is-active $svc >/dev/null 2>&1; then
                systemctl restart $svc >/dev/null 2>&1
            elif service $svc status >/dev/null 2>&1; then
                service $svc restart >/dev/null 2>&1
            fi
        done
    '
}

# 清除系统日志函数
clear_system_logs() {
    run_silent "正在清除系统日志" bash -c '
        # 清除journalctl日志
        if command -v journalctl >/dev/null 2>&1; then
            journalctl --vacuum-time=1s >/dev/null 2>&1
            journalctl --flush --rotate >/dev/null 2>&1
            rm -rf /var/log/journal/* >/dev/null 2>&1
            
            # 更彻底的清除方式
            if [ -d "/var/log/journal" ]; then
                find /var/log/journal -type f -delete >/dev/null 2>&1
            fi
            
            # 重新创建journal目录结构（如果被完全删除）
            mkdir -p /var/log/journal >/dev/null 2>&1
            systemctl restart systemd-journald >/dev/null 2>&1
        fi
        
        # 清除常见系统日志文件
        for log_file in /var/log/syslog /var/log/messages /var/log/kern.log /var/log/dmesg /var/log/maillog /var/log/mail.log /var/log/cron /var/log/boot.log /var/log/daemon.log /var/log/debug /var/log/apt/history.log /var/log/apt/term.log /var/log/dpkg.log; do
            if [ -f "$log_file" ]; then
                cat /dev/null > "$log_file" 2>/dev/null
                # 使用truncate命令更可靠地清空文件
                truncate -s 0 "$log_file" 2>/dev/null
            fi
        done
        
        # 清空/var/log目录下的所有.log文件
        find /var/log -type f -name "*.log" -exec truncate -s 0 {} \; 2>/dev/null || true
        find /var/log -type f -name "*.log.*" -exec truncate -s 0 {} \; 2>/dev/null || true
        
        # 清空/var/log下的gz压缩日志文件
        find /var/log -type f -name "*.gz" -delete 2>/dev/null || true
        
        # 清空日志目录下的所有非文件夹文件
        find /var/log -type f -size +0 -not -path "*/\.*" -exec truncate -s 0 {} \; 2>/dev/null || true
        
        # 重启rsyslog服务
        if command -v service >/dev/null 2>&1; then
            service rsyslog restart >/dev/null 2>&1
        elif command -v systemctl >/dev/null 2>&1; then
            systemctl restart rsyslog >/dev/null 2>&1
        fi
        
        # 处理其他常见日志系统
        for svc in syslog syslog-ng; do
            if systemctl is-active $svc >/dev/null 2>&1; then
                systemctl restart $svc >/dev/null 2>&1
            elif service $svc status >/dev/null 2>&1; then
                service $svc restart >/dev/null 2>&1
            fi
        done
        
        # 清理dmesg缓冲区
        if command -v dmesg >/dev/null 2>&1; then
            dmesg -c >/dev/null 2>&1 || true
        fi
    '
}

# 禁用SSH日志
disable_ssh_logs() {
    run_silent "正在禁用SSH日志" bash -c '
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
            
            # 禁用SSH PAM日志
            if ! grep -q "^UsePAM no" /etc/ssh/sshd_config; then
                # 如果已经有UsePAM设置，则修改它
                if grep -q "^UsePAM" /etc/ssh/sshd_config; then
                    sed -i "s/^UsePAM.*/UsePAM no/" /etc/ssh/sshd_config
                else
                    # 否则添加新的设置
                    echo "UsePAM no" >> /etc/ssh/sshd_config
                fi
            fi
            
            # 禁用特定的SSH日志类型
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
            
            # 重启SSH服务
            if command -v service >/dev/null 2>&1; then
                service sshd restart >/dev/null 2>&1 || service ssh restart >/dev/null 2>&1
            elif command -v systemctl >/dev/null 2>&1; then
                systemctl restart sshd >/dev/null 2>&1 || systemctl restart ssh >/dev/null 2>&1
            fi
            
            # 验证设置是否生效
            if grep -q "^LogLevel QUIET" /etc/ssh/sshd_config && grep -q "^SyslogFacility AUTHPRIV" /etc/ssh/sshd_config; then
                echo "SSH日志设置已成功应用" >&2
            else
                echo "警告：SSH日志设置可能未正确应用" >&2
            fi
            
            # 清除现有SSH日志
            for ssh_log in /var/log/auth.log /var/log/secure /var/log/sshd.log; do
                if [ -f "$ssh_log" ]; then
                    truncate -s 0 "$ssh_log" 2>/dev/null
                fi
            done
        else
            echo "SSH配置文件不存在" >&2
            exit 1
        fi
    '
}

# 恢复SSH日志记录功能
restore_ssh_logs() {
    run_silent "恢复SSH日志记录功能" bash -c '
        # 检查是否存在原始备份
        if [ -f "/etc/ssh/sshd_config.original" ]; then
            # 恢复原始备份
            cp /etc/ssh/sshd_config.original /etc/ssh/sshd_config 2>/dev/null
            # 删除备份文件，确保下次禁用时可以创建新的备份
            rm -f "/etc/ssh/sshd_config.original" 2>/dev/null
            echo "已恢复SSH原始配置并删除备份文件" >&2
        else
            # 如果没有原始备份，尝试修改当前配置
            if [ -f "/etc/ssh/sshd_config" ]; then
                # 修改到默认日志级别
                sed -i "s/^LogLevel QUIET/LogLevel INFO/" /etc/ssh/sshd_config
                sed -i "s/^#*SyslogFacility.*/SyslogFacility AUTH/" /etc/ssh/sshd_config
            else
                echo "SSH配置文件不存在" >&2
                exit 1
            fi
        fi
        
        # 重启SSH服务
        if command -v service >/dev/null 2>&1; then
            service sshd restart >/dev/null 2>&1 || service ssh restart >/dev/null 2>&1
        elif command -v systemctl >/dev/null 2>&1; then
            systemctl restart sshd >/dev/null 2>&1 || systemctl restart ssh >/dev/null 2>&1
        fi
    '
}

# 永久禁用历史记录
disable_history_permanently() {
    run_silent "永久禁用命令历史记录" bash -c '
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
    '
}

# 恢复命令历史记录功能
restore_history_function() {
    run_silent "恢复命令历史记录功能" bash -c '
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
    '
    
    local width=60
    local title="命令历史恢复提示"
    local title_padding=$(( (width - ${#title}) / 2 ))
    
    local horizontal_line=$(repeat_char "─" $width)
    local title_space_prefix=$(repeat_char " " $title_padding)
    
    echo -e "\n${BOLD}${YELLOW}╭${horizontal_line}╮${NC}"
    echo -e "${BOLD}${YELLOW}│${RED}${BOLD}${title_space_prefix}${title}${title_space_prefix}${YELLOW}│${NC}"
    echo -e "${BOLD}${YELLOW}╰${horizontal_line}╯${NC}\n"
    
    echo -e "${RED}${BOLD}⚠️  重要提示：${NC}${YELLOW}由于历史记录变量可能被设为只读(readonly)，${NC}"
    echo -e "${YELLOW}命令历史记录功能恢复需要您${BOLD}完全注销并重新登录系统${NC}${YELLOW}才能生效。${NC}"
    echo -e "${YELLOW}即使当前显示恢复失败，重新登录后也应该能正常工作。${NC}\n"
}

# 清理临时文件和缓存
clean_temp_files() {
    run_silent "清理临时文件和缓存" bash -c '
        # 清理/tmp目录
        find /tmp -type f -delete 2>/dev/null
        
        # 清理/var/tmp目录
        find /var/tmp -type f -delete 2>/dev/null
        
        # 清理所有用户的缓存目录
        for user_home in /home/*; do
            if [ -d "$user_home/.cache" ]; then
                rm -rf "$user_home/.cache/*" 2>/dev/null
            fi
        done
        
        # 清理root用户缓存
        if [ -d "/root/.cache" ]; then
            rm -rf /root/.cache/* 2>/dev/null
        fi
        
        # 清理apt缓存(如果存在)
        if command -v apt-get >/dev/null 2>&1; then
            apt-get clean -y >/dev/null 2>&1
        fi
        
        # 清理yum缓存(如果存在)
        if command -v yum >/dev/null 2>&1; then
            yum clean all >/dev/null 2>&1
        fi
        
        # 清理dnf缓存(如果存在)
        if command -v dnf >/dev/null 2>&1; then
            dnf clean all >/dev/null 2>&1
        fi
    '
}

# 执行所有清理操作
run_all_operations() {
    local width=60
    local start_title="开始全面系统痕迹清理"
    local end_title="全面系统痕迹清理操作已完成"
    local start_padding=$(( (width - ${#start_title}) / 2 ))
    local end_padding=$(( (width - ${#end_title}) / 2 ))
    
    local horizontal_line=$(repeat_char "─" $width)
    local start_space=$(repeat_char " " $start_padding)
    local end_space=$(repeat_char " " $end_padding)
    
    # 开始清理消息
    echo -e "\n${BOLD}${MAGENTA}╭${horizontal_line}╮${NC}"
    echo -e "${BOLD}${MAGENTA}│${YELLOW}${BOLD}${start_space}${start_title}${start_space}${MAGENTA}│${NC}"
    echo -e "${BOLD}${MAGENTA}╰${horizontal_line}╯${NC}\n"
    
    # 执行所有操作
    clear_command_history
    clear_login_logs
    clear_system_logs
    disable_ssh_logs
    disable_history_permanently
    clean_temp_files
    
    # 完成清理消息
    echo -e "\n${BOLD}${GREEN}╭${horizontal_line}╮${NC}"
    echo -e "${BOLD}${GREEN}│${YELLOW}${BOLD}${end_space}${end_title}${end_space}${GREEN}│${NC}"
    echo -e "${BOLD}${GREEN}╰${horizontal_line}╯${NC}"
    
    echo -e "\n${CYAN}🎉 所有痕迹已被清除，系统现在处于安全状态！${NC}\n"
}

# 显示验证命令
show_verification_commands() {
    local width=60
    local title="验证清理效果的命令"
    local title_padding=$(( (width - ${#title}) / 2 ))
    
    local horizontal_line=$(repeat_char "─" $width)
    local title_space_prefix=$(repeat_char " " $title_padding)
    
    echo -e "\n${BOLD}${CYAN}╭${horizontal_line}╮${NC}"
    echo -e "${BOLD}${CYAN}│${YELLOW}${BOLD}${title_space_prefix}${title}${title_space_prefix}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}╰${horizontal_line}╯${NC}"
    
    echo -e "\n${BOLD}${GREEN}可用命令:${NC}"
    echo -e "  ${CYAN}➜ ${NC}${BOLD}last${NC}                     ${YELLOW}# 检查登录记录${NC}"
    echo -e "  ${CYAN}➜ ${NC}${BOLD}history${NC}                  ${YELLOW}# 检查命令历史${NC}"
    echo -e "  ${CYAN}➜ ${NC}${BOLD}journalctl -u sshd${NC}       ${YELLOW}# 检查SSH日志${NC}"
    echo -e "  ${CYAN}➜ ${NC}${BOLD}ls -la /var/log/${NC}         ${YELLOW}# 检查系统日志${NC}"
    echo -e "  ${CYAN}➜ ${NC}${BOLD}cat ~/.bash_history${NC}      ${YELLOW}# 检查bash历史文件${NC}"
    
    echo -e "\n${BOLD}${YELLOW}注意事项:${NC}"
    echo -e "  ${YELLOW}➣ 为确保命令历史完全清除，建议在运行此脚本后注销并重新登录系统。${NC}"
    echo -e "  ${YELLOW}➣ 某些系统日志可能需要root权限才能完全清除。${NC}"
    echo -e "  ${YELLOW}➣ 禁用SSH日志后，新的SSH连接将不会被记录。${NC}\n"
}

# 显示退出消息
show_exit_message() {
    local width=50
    local title="感谢使用本工具，再见！"
    local padding=$(( (width - ${#title}) / 2 ))
    
    local horizontal_line=$(repeat_char "─" $width)
    local space=$(repeat_char " " $padding)
    
    echo -e "\n${BOLD}${BLUE}╭${horizontal_line}╮${NC}"
    echo -e "${BOLD}${BLUE}│${GREEN}${BOLD}${space}${title}${space}${BLUE}│${NC}"
    echo -e "${BOLD}${BLUE}╰${horizontal_line}╯${NC}\n"
}

# 主函数
main() {
    show_logo
    check_root
    
    # 如果有命令行参数 "-a" 或 "--all"，则直接执行所有操作
    if [ "$1" == "-a" ] || [ "$1" == "--all" ]; then
        run_all_operations
        show_verification_commands
        exit 0
    fi
    
    # 显示成功完成的恢复操作消息
    show_restore_complete() {
        local width=50
        local title="恢复操作已完成"
        local padding=$(( (width - ${#title}) / 2 ))
        
        local horizontal_line=$(repeat_char "─" $width)
        local space=$(repeat_char " " $padding)
        
        echo -e "\n${BOLD}${GREEN}╭${horizontal_line}╮${NC}"
        echo -e "${BOLD}${GREEN}│${CYAN}${BOLD}${space}${title}${space}${GREEN}│${NC}"
        echo -e "${BOLD}${GREEN}╰${horizontal_line}╯${NC}\n"
    }
    
    while true; do
        show_menu
        read -p "" choice
        
        case $choice in
            1) clear_command_history ;;
            2) clear_login_logs ;;
            3) clear_system_logs ;;
            4) disable_ssh_logs ;;
            5) disable_history_permanently ;;
            6) clean_temp_files ;;
            7) run_all_operations ;;
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
        
        # 操作完成后显示验证命令
        if [[ $choice =~ [1-9] ]]; then
            # 如果是恢复功能，显示恢复完成消息
            if [[ $choice == "8" || $choice == "9" ]]; then
                show_restore_complete
            else
                show_verification_commands
            fi
            
            # 询问是否继续
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