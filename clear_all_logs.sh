#!/bin/bash
# ============================================================
# 一键清除Linux所有操作痕迹
# By 哈迪斯
# ============================================================

# 只清理历史不禁用历史记录功能
history -c 2>/dev/null || true
history -w 2>/dev/null || true

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
    local title="【痕迹清除 - 操作菜单】"
    
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
# 确保创建备份目录
mkdir -p /tmp/.history_backups 2>/dev/null
chmod 700 /tmp/.history_backups 2>/dev/null

# 清空所有用户的历史文件
for user_home in /root /home/*; do
    if [ ! -d "$user_home" ]; then
        continue
    fi

    user=$(basename "$user_home")
    timestamp=$(date +"%Y%m%d%H%M%S")

    # 清理历史文件列表
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
        if [ -f "$hist_file" ]; then
            # 如果有用户正在登录，尝试清除其活动shell的历史
            for pid in $(pgrep -u "$user" bash); do
                # 向每个bash进程发送history -c命令
                su - "$user" -c "kill -USR1 $pid && echo \"history -c && history -w\" >> /proc/$pid/fd/0" 2>/dev/null
            done
            
            # 检查文件权限并优化清理方式
            if [ -w "$hist_file" ]; then
                # 如果文件可写，先尝试移除不可变属性
                chattr -i "$hist_file" 2>/dev/null || true
                
                # 方法1: 先用shred安全地覆盖文件内容
                if command -v shred >/dev/null 2>&1; then
                    shred -fuz "$hist_file" 2>/dev/null || true
                fi
                
                # 方法2: 先将文件设置为追加模式
                chattr +a "$hist_file" 2>/dev/null || true
                
                # 方法3: 使用多种清空文件方式
                : > "$hist_file" 2>/dev/null || \
                cat /dev/null > "$hist_file" 2>/dev/null || \
                truncate -s 0 "$hist_file" 2>/dev/null || \
                echo -n "" > "$hist_file" 2>/dev/null
                
                # 方法4: 恢复文件属性
                chattr -a "$hist_file" 2>/dev/null || true
                
                # 方法5: 如果文件仍有内容，创建新的空文件替换
                if [ -s "$hist_file" ]; then
                    rm -f "$hist_file" 2>/dev/null
                    touch "$hist_file" 2>/dev/null
                fi
                
                # 设置合适的权限，确保文件可写
                chmod 600 "$hist_file" 2>/dev/null
            else
                # 文件不可写，尝试修改权限后清空
                chmod u+w "$hist_file" 2>/dev/null
                : > "$hist_file" 2>/dev/null
                chmod 600 "$hist_file" 2>/dev/null
            fi
            
            # 检查是否成功清空
            if [ -s "$hist_file" ]; then
                # 最后手段: 使用文件系统级删除重建
                rm -f "$hist_file" 2>/dev/null
                touch "$hist_file" 2>/dev/null
                chmod 600 "$hist_file" 2>/dev/null
            fi
        fi
    done
    
    # 注意：不再修改用户配置文件来禁用历史记录
done

# 注意：不再设置全局历史文件大小限制

# 清除当前shell的历史
history -c 2>/dev/null || true
history -w 2>/dev/null || true

# 确保系统没有保留任何历史相关文件
find /var/spool/ /var/log/ /var/tmp/ /tmp/ -name "*history*" -type f 2>/dev/null | while read hist_file; do
    if [ -w "$hist_file" ]; then
        rm -f "$hist_file" 2>/dev/null || truncate -s 0 "$hist_file" 2>/dev/null
    else
        chmod u+w "$hist_file" 2>/dev/null && rm -f "$hist_file" 2>/dev/null
    fi
done

# 注意：不再创建或更新.bash_logout文件

# 清除共享内存中的历史记录
ipcs -m | grep -v "0x" | awk '{print $1}' | xargs -n 1 ipcrm -m 2>/dev/null || true
EOF

    # 添加执行权限
    chmod +x "$temp_script"
    
    # 执行临时脚本
    run_silent "正在清除命令历史" "$temp_script"
    
    # 清理临时脚本
    rm -f "$temp_script"
    
    # 清除当前会话历史
    history -c 2>/dev/null || true
    history -w 2>/dev/null || true
    
    # 不再设置HISTSIZE=0，保留历史记录功能
}

# 永久禁用命令历史记录功能
disable_history_permanently() {
    # 创建临时脚本文件
    local temp_script=$(mktemp)
    
    # 将要执行的命令写入临时脚本文件
    cat > "$temp_script" << 'EOF'
#!/bin/bash
# 先清除已有历史
for user_home in /root /home/*; do
    if [ ! -d "$user_home" ]; then
        continue
    fi

    hist_files=(
        "$user_home/.bash_history"
        "$user_home/.zsh_history"
        "$user_home/.history" 
        "$user_home/.sh_history"
    )
    
    for hist_file in "${hist_files[@]}"; do
        if [ -f "$hist_file" ]; then
            # 完全删除历史文件
            rm -f "$hist_file" 2>/dev/null
            
            # 创建空文件并设置不可写属性
            touch "$hist_file" 2>/dev/null
            chmod 400 "$hist_file" 2>/dev/null
            
            # 设置不可变属性(如果支持)
            if command -v chattr >/dev/null 2>&1; then
                chattr +i "$hist_file" 2>/dev/null || true
            fi
        fi
    done
    
    # 修改用户配置文件
    for rc_file in "$user_home/.bashrc" "$user_home/.bash_profile" "$user_home/.profile" "$user_home/.zshrc"; do
        if [ -f "$rc_file" ]; then
            # 备份原始文件
            if [ ! -f "${rc_file}.original" ]; then
                cp "$rc_file" "${rc_file}.original" 2>/dev/null
            fi
            
            # 删除所有已存在的历史相关设置
            sed -i '/HIST/d' "$rc_file" 2>/dev/null
            
            # 添加永久禁用历史的配置
            echo -e "\n# 永久禁用命令历史记录 - 设置于 $(date)" >> "$rc_file"
            echo "export HISTFILE=/dev/null" >> "$rc_file"
            echo "export HISTSIZE=0" >> "$rc_file"
            echo "export HISTFILESIZE=0" >> "$rc_file"
            echo "export HISTIGNORE='*'" >> "$rc_file"
            echo "export HISTCONTROL=ignoreboth:erasedups" >> "$rc_file"
            echo "unset HISTFILE" >> "$rc_file"
            echo "set +o history" >> "$rc_file"
            
            # 为bash用户添加trap
            if [[ "$rc_file" == *"bash"* ]]; then
                echo "shopt -s histappend" >> "$rc_file"
                echo "readonly HISTFILE" >> "$rc_file"
                echo "readonly HISTSIZE" >> "$rc_file"
                echo "readonly HISTFILESIZE" >> "$rc_file"
                echo "trap 'history -c; history -w' EXIT" >> "$rc_file"
            fi
            
            # 为zsh用户添加特定配置
            if [[ "$rc_file" == *"zsh"* ]]; then
                echo "unsetopt SHARE_HISTORY" >> "$rc_file"
                echo "unsetopt APPEND_HISTORY" >> "$rc_file"
                echo "unsetopt INC_APPEND_HISTORY" >> "$rc_file"
                echo "setopt NO_HISTORY" >> "$rc_file"
                echo "fc -p /dev/null" >> "$rc_file"
            fi
        fi
    done
done

# 设置全局配置
if [ -d "/etc/profile.d" ]; then
    cat > "/etc/profile.d/disable_history.sh" << 'EOL'
#!/bin/bash
# 全局禁用命令历史记录 - 创建于 $(date)
export HISTFILE=/dev/null
export HISTSIZE=0
export HISTFILESIZE=0
export HISTIGNORE='*'
export HISTCONTROL=ignoreboth:erasedups
unset HISTFILE
set +o history
# 确保这些配置不能被修改
readonly HISTFILE
readonly HISTSIZE
readonly HISTFILESIZE
# 退出时清除历史
trap 'history -c; history -w' EXIT
EOL
    chmod +x "/etc/profile.d/disable_history.sh"
fi

if [ -f "/etc/profile" ]; then
    # 添加到全局配置
    if ! grep -q "禁用命令历史" "/etc/profile"; then
        echo -e "\n# 禁用命令历史记录 - 添加于 $(date)" >> /etc/profile
        echo "export HISTFILE=/dev/null" >> /etc/profile
        echo "export HISTSIZE=0" >> /etc/profile
        echo "export HISTFILESIZE=0" >> /etc/profile
        echo "unset HISTFILE" >> /etc/profile
        echo "set +o history" >> /etc/profile
    fi
fi

# 创建或修改全局bash配置
if [ -f "/etc/bash.bashrc" ]; then
    if ! grep -q "禁用历史记录" "/etc/bash.bashrc"; then
        echo -e "\n# 全局禁用历史记录 - 添加于 $(date)" >> /etc/bash.bashrc
        echo "export HISTFILE=/dev/null" >> /etc/bash.bashrc
        echo "export HISTSIZE=0" >> /etc/bash.bashrc
        echo "export HISTFILESIZE=0" >> /etc/bash.bashrc
        echo "unset HISTFILE" >> /etc/bash.bashrc
        echo "set +o history" >> /etc/bash.bashrc
    fi
fi

# 确保所有用户的.bash_logout文件都有清理命令
for user_home in /root /home/*; do
    if [ ! -d "$user_home" ]; then
        continue
    fi
    
    logout_file="$user_home/.bash_logout"
    
    # 创建或更新logout文件
    cat > "$logout_file" << 'EOL'
#!/bin/bash
# 退出时清理历史记录 - 添加于 $(date)
history -c
history -w
export HISTFILE=/dev/null
export HISTSIZE=0
export HISTFILESIZE=0
# 清除并保护历史文件
if [ -f "$HOME/.bash_history" ]; then
    rm -f "$HOME/.bash_history"
    touch "$HOME/.bash_history"
    chmod 400 "$HOME/.bash_history"
fi
EOL
    
    # 设置适当的权限
    chmod 644 "$logout_file" 2>/dev/null
    chown $(stat -c "%U:%G" "$user_home") "$logout_file" 2>/dev/null || true
done

# 立即应用于当前会话
export HISTFILE=/dev/null
export HISTSIZE=0
export HISTFILESIZE=0
unset HISTFILE
set +o history
history -c
history -w

# 设置永久不可变属性于关键配置文件
if command -v chattr >/dev/null 2>&1; then
    chattr +i /etc/profile.d/disable_history.sh 2>/dev/null || true
fi

echo "命令历史功能已永久禁用" >&2
EOF

    # 添加执行权限
    chmod +x "$temp_script"
    
    # 执行临时脚本
    run_silent "正在永久禁用命令历史记录功能" "$temp_script"
    
    # 清理临时脚本
    rm -f "$temp_script"
    
    # 直接在当前会话中禁用历史
    export HISTFILE=/dev/null
    export HISTSIZE=0
    export HISTFILESIZE=0
    unset HISTFILE 2>/dev/null || true
    set +o history 2>/dev/null || true
    history -c 2>/dev/null || true
    history -w 2>/dev/null || true
    
    echo -e "\n${GREEN}${BOLD}命令历史记录功能已永久禁用！${NC}"
    echo -e "${YELLOW}所有用户将不再记录命令历史。${NC}"
    echo -e "${YELLOW}此设置将在系统重启后仍然生效。${NC}\n"
}

# 恢复命令历史记录功能
restore_history_function() {
    # 创建临时脚本文件
    local temp_script=$(mktemp)
    
    # 将要执行的命令写入临时脚本文件
    cat > "$temp_script" << 'EOF'
#!/bin/bash
# 恢复系统默认历史记录设置
# 定义辅助函数：删除所有历史变量设置
remove_history_settings() {
    local file="$1"
    if [ -f "$file" ]; then
        # 使用更精确的模式匹配，防止误删其他内容
        sed -i '/禁用.*历史/d' "$file" 2>/dev/null
        sed -i '/命令历史记录/d' "$file" 2>/dev/null
        sed -i '/HISTFILE=/d' "$file" 2>/dev/null
        sed -i '/HISTSIZE=/d' "$file" 2>/dev/null
        sed -i '/HISTFILESIZE=/d' "$file" 2>/dev/null
        sed -i '/HISTIGNORE=/d' "$file" 2>/dev/null
        sed -i '/HISTCONTROL=/d' "$file" 2>/dev/null
        sed -i '/unset HISTFILE/d' "$file" 2>/dev/null
        sed -i '/set [+|-]o history/d' "$file" 2>/dev/null
        sed -i '/readonly HIST/d' "$file" 2>/dev/null
        sed -i '/^shopt -s histappend/d' "$file" 2>/dev/null
        sed -i '/trap.*history/d' "$file" 2>/dev/null
    fi
}

# ==== 步骤1：首先处理全局配置文件 ====
# 移除全局配置文件中的历史禁用设置
echo "正在处理全局配置文件..." >&2

# 移除禁用历史的配置文件
for config_file in "/etc/profile.d/disable_history.sh" "/etc/profile.d/no_history.sh"; do
    if [ -f "$config_file" ]; then
        # 先尝试移除只读属性
        if command -v chattr >/dev/null 2>&1; then
            chattr -i "$config_file" 2>/dev/null || true
        fi
        # 尝试删除文件，如果无法删除，尝试清空内容
        rm -f "$config_file" 2>/dev/null || truncate -s 0 "$config_file" 2>/dev/null || true
    fi
done

# 移除全局profile中的设置
for global_file in "/etc/profile" "/etc/bash.bashrc" "/etc/bashrc"; do
    remove_history_settings "$global_file"
done

# ==== 步骤2：新建恢复历史的配置文件 ====
echo "正在创建恢复历史记录的配置..." >&2

# 创建恢复历史的配置文件
if [ -d "/etc/profile.d" ]; then
    cat > "/etc/profile.d/restore_history.sh" << 'EOL'
#!/bin/bash
# 恢复命令历史记录功能 - 创建于 $(date)

# 这段代码会清除只读属性并恢复历史功能
if [ -n "$BASH_VERSION" ]; then
    # 使用子shell技术绕过只读限制
    bash -c '
        # 导出正常的历史设置
        export HISTSIZE=1000
        export HISTFILESIZE=2000
        export HISTCONTROL=ignoredups
        # 重新启用历史
        set -o history
    ' >/dev/null 2>&1 || true
    
    # 下面这些命令可能会报错，但我们忽略错误继续执行
    # 因为这些变量可能被设为了只读
    HISTSIZE=1000 2>/dev/null || true
    HISTFILESIZE=2000 2>/dev/null || true
    HISTCONTROL=ignoredups 2>/dev/null || true
    set -o history 2>/dev/null || true
fi
EOL
    chmod +x "/etc/profile.d/restore_history.sh"
fi

# ==== 步骤3：处理所有用户配置 ====
echo "正在处理用户配置文件..." >&2

# 恢复所有用户的配置
for user_home in /root /home/*; do
    if [ ! -d "$user_home" ]; then
        continue
    fi
    
    # 恢复历史文件权限
    hist_files=(
        "$user_home/.bash_history"
        "$user_home/.zsh_history"
        "$user_home/.history" 
        "$user_home/.sh_history"
    )
    
    for hist_file in "${hist_files[@]}"; do
        if [ -f "$hist_file" ]; then
            # 移除不可变属性(如果有)
            if command -v chattr >/dev/null 2>&1; then
                chattr -i "$hist_file" 2>/dev/null || true
            fi
            
            # 确保文件可写
            chmod 600 "$hist_file" 2>/dev/null
            
            # 如果文件为空，创建新的历史文件
            if [ ! -s "$hist_file" ]; then
                touch "$hist_file" 2>/dev/null
                chmod 600 "$hist_file" 2>/dev/null
            fi
        else
            # 如果历史文件不存在，创建一个新的
            touch "$hist_file" 2>/dev/null
            chmod 600 "$hist_file" 2>/dev/null
        fi
    done
    
    # 处理用户配置文件
    for rc_file in "$user_home/.bashrc" "$user_home/.bash_profile" "$user_home/.profile" "$user_home/.zshrc"; do
        # 如果有备份，恢复备份
        if [ -f "${rc_file}.original" ]; then
            cp -f "${rc_file}.original" "$rc_file" 2>/dev/null
            rm -f "${rc_file}.original" 2>/dev/null
        else
            # 否则清除所有历史相关设置
            remove_history_settings "$rc_file"
            
            # 添加新的历史设置 - 仅当文件存在时
            if [ -f "$rc_file" ]; then
                echo -e "\n# 历史记录默认设置 - 恢复于 $(date)" >> "$rc_file"
                echo "# 以下设置通过子shell方式实现，避免只读变量问题" >> "$rc_file"
                echo "if [ -n \"\$BASH_VERSION\" ]; then" >> "$rc_file"
                echo "    # 在子shell中设置历史变量" >> "$rc_file"
                echo "    bash -c '" >> "$rc_file"
                echo "        export HISTSIZE=1000" >> "$rc_file"
                echo "        export HISTFILESIZE=2000" >> "$rc_file"
                echo "        export HISTCONTROL=ignoredups" >> "$rc_file"
                echo "        set -o history" >> "$rc_file"
                echo "    ' >/dev/null 2>&1 || true" >> "$rc_file"
                echo "    " >> "$rc_file"
                echo "    # 尝试直接设置(可能会报错，但忽略)" >> "$rc_file"
                echo "    HISTSIZE=1000 2>/dev/null || true" >> "$rc_file"
                echo "    HISTFILESIZE=2000 2>/dev/null || true" >> "$rc_file"
                echo "    HISTCONTROL=ignoredups 2>/dev/null || true" >> "$rc_file"
                echo "    set -o history 2>/dev/null || true" >> "$rc_file"
                echo "fi" >> "$rc_file"
            fi
            
            # 对于zsh特定的设置
            if [[ "$rc_file" == *"zsh"* ]]; then
                sed -i '/unsetopt.*HISTORY/d' "$rc_file" 2>/dev/null
                sed -i '/setopt NO_HISTORY/d' "$rc_file" 2>/dev/null
                sed -i '/fc -p/d' "$rc_file" 2>/dev/null
                
                # 添加zsh特定的恢复设置
                echo "# ZSH历史设置 - 恢复于 $(date)" >> "$rc_file"
                echo "HISTSIZE=1000" >> "$rc_file"
                echo "SAVEHIST=1000" >> "$rc_file"
                echo "setopt SHARE_HISTORY" >> "$rc_file"
                echo "setopt APPEND_HISTORY" >> "$rc_file"
            fi
        fi
    done
    
    # 恢复bash_logout文件
    logout_file="$user_home/.bash_logout"
    if [ -f "${logout_file}.original" ]; then
        cp -f "${logout_file}.original" "$logout_file" 2>/dev/null
        rm -f "${logout_file}.original" 2>/dev/null
    else
        # 删除清理历史的相关命令
        sed -i '/清理历史/d' "$logout_file" 2>/dev/null
        sed -i '/history -c/d' "$logout_file" 2>/dev/null
        sed -i '/history -w/d' "$logout_file" 2>/dev/null
        sed -i '/HIST/d' "$logout_file" 2>/dev/null
        sed -i '/bash_history/d' "$logout_file" 2>/dev/null
    fi
done

# ==== 步骤4：使用更激进的方法处理只读变量 ====
echo "正在处理只读变量问题..." >&2

# 创建一个解除只读变量的启动脚本
cat > "/etc/profile.d/99-fix-readonly-history.sh" << 'EOL'
#!/bin/bash
# 修复只读历史变量 - 创建于 $(date)

# 这个脚本通过一种特殊方法解决只读变量问题
# 原理是创建一个新的shell环境，从而绕过只读属性

# 函数：检测是否有只读历史变量
check_readonly_hist() {
    ( readonly -p | grep -q "HIST" ) && return 0 || return 1
}

# 如果检测到只读历史变量
if check_readonly_hist; then
    # 创建一个临时启动脚本
    export BASH_ENV=$(mktemp)
    echo 'export HISTFILE=~/.bash_history' > $BASH_ENV
    echo 'export HISTSIZE=1000' >> $BASH_ENV
    echo 'export HISTFILESIZE=2000' >> $BASH_ENV
    echo 'export HISTCONTROL=ignoredups' >> $BASH_ENV
    echo 'set -o history' >> $BASH_ENV
    chmod +x $BASH_ENV
    
    # 让用户重新登录
    if [ -n "$DISPLAY" ]; then
        # 图形界面提示
        which zenity >/dev/null 2>&1 && \
        zenity --info --text="历史记录功能已恢复，请重新登录以完全生效" >/dev/null 2>&1 &
    else
        echo -e "\n\033[1;32m历史记录功能已恢复，请重新登录以完全生效\033[0m" >&2
    fi
fi
EOL

chmod +x "/etc/profile.d/99-fix-readonly-history.sh"

# 尝试强制重置当前Shell的历史变量 - 这是一个更激进的方法
# 创建一个临时脚本，尝试用新进程完全替代当前Shell环境
cat > "/tmp/force_history_reset.sh" << 'EOL'
#!/bin/bash
# 这个脚本用于强制重置历史记录设置
# 原理是创建一个全新的Shell进程

# 创建一个临时初始化文件
TEMP_INIT=$(mktemp)
cat > $TEMP_INIT << 'INIT'
# 初始化历史设置
export HISTFILE=~/.bash_history
export HISTSIZE=1000
export HISTFILESIZE=2000
export HISTCONTROL=ignoredups
set -o history
INIT

# 使用新的初始化文件启动一个交互式Shell
echo "正在尝试重置历史记录设置..."
echo "如果看到此消息，表示历史记录功能已部分恢复"
echo "请完全退出并重新登录以确保所有更改生效"

# 添加到用户的登录脚本中自动执行重置
for user_home in /root /home/*; do
    if [ -d "$user_home" ]; then
        login_file="$user_home/.bash_profile"
        # 只在文件存在且尚未包含重置命令时添加
        if [ -f "$login_file" ] && ! grep -q "历史记录已重置" "$login_file"; then
            echo -e "\n# 历史记录已重置 - $(date)" >> "$login_file"
            echo "# 此行将在下次登录后自动删除" >> "$login_file"
            echo "echo '历史记录功能已恢复正常'" >> "$login_file"
            echo "sed -i '/历史记录已重置/,+3d' \"$login_file\" 2>/dev/null" >> "$login_file"
        fi
    fi
done

# 清理临时文件
rm -f $TEMP_INIT
EOL

chmod +x "/tmp/force_history_reset.sh"

# 提示用户重新登录
echo "命令历史记录功能已恢复，请重新登录以确保所有设置生效" >&2
echo "如果历史记录仍然无法正常工作，请尝试运行: /tmp/force_history_reset.sh" >&2

# ==== 步骤5：尝试为当前会话恢复历史功能 ====
echo "正在尝试为当前会话恢复历史功能..." >&2

# 下面这些命令会尝试恢复历史，但可能会因为只读属性而失败
# 我们不关心错误输出，所以全部重定向到/dev/null
(
    # 尝试在子shell中设置变量
    HISTFILE=~/.bash_history
    HISTSIZE=1000 
    HISTFILESIZE=2000
    HISTCONTROL=ignoredups 
    set -o history
) >/dev/null 2>&1 || true

# 最后的解决方案：如果我们有执行exec替换当前Shell的权限
if [ "$(id -u)" -eq 0 ]; then
    # 只有root用户才尝试这个方法，避免普通用户Shell中断
    echo "正在尝试立即恢复当前会话的历史记录功能..." >&2
    
    # 创建一个临时初始化脚本
    TEMP_SHELL_INIT=$(mktemp)
    cat > "$TEMP_SHELL_INIT" << 'EOINIT'
export HISTFILE=~/.bash_history
export HISTSIZE=1000
export HISTFILESIZE=2000
export HISTCONTROL=ignoredups
set -o history
EOINIT
    
    # 为临时脚本添加执行权限
    chmod +x "$TEMP_SHELL_INIT"
    
    # 告诉用户我们要做什么
    echo "即将尝试重启Shell会话以恢复历史功能..." >&2
    
    # 选择性执行 - 有些环境可能不允许这样做
    # exec env -i bash --rcfile "$TEMP_SHELL_INIT" -i || true
fi

echo "命令历史记录功能恢复完成" >&2
EOF

    # 添加执行权限
    chmod +x "$temp_script"
    
    # 执行临时脚本
    run_silent "正在恢复命令历史记录功能" "$temp_script"
    
    # 清理临时脚本
    rm -f "$temp_script"
    
    echo -e "\n${GREEN}${BOLD}命令历史记录功能已恢复！${NC}"
    echo -e "${YELLOW}重要提示：由于历史变量可能被设为只读，完全恢复可能需要您执行以下操作:${NC}"
    echo -e "${CYAN}1. 重新启动系统${NC}"
    echo -e "${CYAN}2. 或者完全退出当前shell会话后重新登录${NC}"
    echo -e "${YELLOW}您当前会话中历史记录可能仍然无法正常工作，这是正常的。${NC}"
    echo -e "${YELLOW}如需立即强制恢复，可以尝试执行：${CYAN}/tmp/force_history_reset.sh${NC}\n"
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
# 使用chattr命令禁用关键日志文件
if command -v chattr >/dev/null 2>&1; then
    # 设置不可变属性
    chattr +i /var/log/wtmp /var/log/btmp 2>/dev/null
    
    # 检查是否成功设置不可变属性
    lsattr /var/log/wtmp /var/log/btmp 2>/dev/null | grep -q "^-.*i.*-" && \
    echo "已成功锁定SSH日志文件，现在它们无法被修改" >&2 || \
    echo "警告：无法锁定某些日志文件，请检查系统权限" >&2
else
    echo "错误：系统缺少chattr命令，无法设置文件属性" >&2
    exit 1
fi

# 清空日志文件（如果可能）
for ssh_log in /var/log/auth.log /var/log/secure /var/log/sshd.log /var/log/auth.log.* /var/log/secure.* /var/log/messages; do
    if [ -f "$ssh_log" ] && [ -w "$ssh_log" ]; then
        truncate -s 0 "$ssh_log" 2>/dev/null
    fi
done

# 如果存在SSH配置，也进行日志禁用配置
if [ -f "/etc/ssh/sshd_config" ]; then
    # 备份原始配置(如果备份不存在)
    if [ ! -f "/etc/ssh/sshd_config.original" ]; then
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.original 2>/dev/null
    fi
    
    # 修改SSH配置减少日志记录
    sed -i "s/^#*LogLevel.*/LogLevel QUIET/" /etc/ssh/sshd_config 2>/dev/null
    sed -i "s/^#*PrintLastLog.*/PrintLastLog no/" /etc/ssh/sshd_config 2>/dev/null
    
    # 重启SSH服务
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart sshd >/dev/null 2>&1 || systemctl restart ssh >/dev/null 2>&1
    elif command -v service >/dev/null 2>&1; then
        service sshd restart >/dev/null 2>&1 || service ssh restart >/dev/null 2>&1
    fi
fi

echo "SSH日志已被禁用" >&2
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
# 移除日志文件的不可变属性
if command -v chattr >/dev/null 2>&1; then
    # 移除不可变属性
    chattr -i /var/log/wtmp /var/log/btmp 2>/dev/null
    
    # 检查是否成功移除不可变属性
    lsattr /var/log/wtmp /var/log/btmp 2>/dev/null | grep -q "^-.*i.*-" && \
    echo "警告：日志文件仍有不可变属性，可能需要更高权限" >&2 || \
    echo "已成功解锁SSH日志文件，现在可以正常记录" >&2
else
    echo "错误：系统缺少chattr命令，无法修改文件属性" >&2
    exit 1
fi

# 如果存在SSH配置备份，恢复它
if [ -f "/etc/ssh/sshd_config.original" ]; then
    # 恢复原始备份
    cp /etc/ssh/sshd_config.original /etc/ssh/sshd_config 2>/dev/null
    # 删除备份文件，确保下次禁用时可以创建新的备份
    rm -f "/etc/ssh/sshd_config.original" 2>/dev/null
elif [ -f "/etc/ssh/sshd_config" ]; then
    # 如果没有原始备份，尝试修改当前配置
    sed -i "s/^LogLevel QUIET/LogLevel INFO/" /etc/ssh/sshd_config 2>/dev/null
    sed -i "s/^PrintLastLog no/PrintLastLog yes/" /etc/ssh/sshd_config 2>/dev/null
fi

# 重启SSH服务
if command -v systemctl >/dev/null 2>&1; then
    systemctl restart sshd >/dev/null 2>&1 || systemctl restart ssh >/dev/null 2>&1
elif command -v service >/dev/null 2>&1; then
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
    
    # 定义要执行的操作数组，将清除命令历史放在最后
    local operations=(
        "clear_login_logs"
        "clear_system_logs"
        "clean_temp_files"
        "clear_command_history"
    )
    
    # 遍历执行所有操作
    for op in "${operations[@]}"; do
        $op
        
        # 检查操作是否成功，如果失败给出提示但继续执行
        if [ $? -ne 0 ]; then
            echo -e "${YELLOW}⚠️ ${op} 操作完成但有些警告，继续执行其他操作...${NC}\n"
        fi
    done
    
    # 再次清除当前shell的历史记录
    history -c 2>/dev/null || true
    history -w 2>/dev/null || true
    
    # 这里不再调用setup_logout_cleaner函数，避免禁用历史命令功能
    
    echo -e "\n${GREEN}${BOLD}全面系统痕迹清理操作已完成${NC}"
    echo -e "\n${CYAN}✓ 所有痕迹已被清除！${NC}"
    echo -e "\n${CYAN}✓ 历史命令功能未被禁用，仅清除了现有记录${NC}\n"
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
    echo -e "\n${GREEN}${BOLD}命令历史记录功能已恢复！${NC}"
    echo -e "${YELLOW}所有用户的命令历史将重新开始记录。${NC}"
    echo -e "${YELLOW}您可能需要重新登录或重启系统使所有更改生效。${NC}\n"
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
            # 清除当前历史但不禁用功能
            history -c 2>/dev/null || true
            
            run_all_operations
            show_verification_commands
            
            # 计算总执行时间
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            echo -e "${CYAN}总执行时间: ${duration} 秒${NC}"
            
            # 清理当前历史，但不禁用历史功能
            history -c 2>/dev/null || true
            history -w 2>/dev/null || true
            
            exit 0
            ;;
        -h|--help)
            # 显示帮助信息
            echo -e "${CYAN}${BOLD}Linux系统痕迹清理与管理工具 ${GREEN}${VERSION}${NC}"
            echo -e "${YELLOW}用法: $0 [选项]${NC}\n"
            echo -e "${GREEN}选项:${NC}"
            echo -e "  ${MAGENTA}-a, --all${NC}     执行所有清理操作（不禁用历史记录功能）"
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
                
                # 如果选择了清理操作，再次清除历史记录以确保完全清除
                if [[ $choice =~ [1-5] ]]; then
                    history -c 2>/dev/null || true
                    history -w 2>/dev/null || true
                fi
                
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