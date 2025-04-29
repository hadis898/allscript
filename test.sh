#!/bin/bash

# 全面恢复命令历史功能脚本
# 适用于系统级别的只读变量问题

echo "正在进行系统级别命令历史功能恢复..."

# 检查系统级配置文件
SYSTEM_FILES=("/etc/bash.bashrc" "/etc/profile" "/etc/profile.d/*.sh" "/etc/environment" "/etc/bashrc")

echo "正在检查以下系统文件是否包含只读历史变量设置:"
for file in "${SYSTEM_FILES[@]}"; do
    if ls $file 1> /dev/null 2>&1; then
        echo "检查 $file ..."
        grep -l "readonly.*HIST" $file 2>/dev/null
    fi
done

# 备份并修改发现的文件
for file in "${SYSTEM_FILES[@]}"; do
    if ls $file 1> /dev/null 2>&1; then
        if grep -q "readonly.*HIST" $file 2>/dev/null; then
            echo "在 $file 中发现只读历史变量设置"
            cp $file ${file}.bak.$(date +%Y%m%d%H%M%S)
            echo "已备份 $file"
            sed -i '/readonly.*HIST/d' $file
            echo "从 $file 中移除了只读历史变量设置"
        fi
    fi
done

# 检查 /etc/profile.d/ 目录下的所有脚本
echo "检查 /etc/profile.d/ 目录下的脚本..."
for script in /etc/profile.d/*.sh; do
    if grep -q "readonly.*HIST" $script 2>/dev/null; then
        echo "在 $script 中发现只读历史变量设置"
        cp $script ${script}.bak.$(date +%Y%m%d%H%M%S)
        echo "已备份 $script"
        sed -i '/readonly.*HIST/d' $script
        echo "从 $script 中移除了只读历史变量设置"
    fi
done

# 创建一个新的脚本来设置正确的历史命令参数
cat > /etc/profile.d/history-settings.sh << 'EOF'
# 命令历史正确设置
export HISTSIZE=5000
export HISTFILESIZE=10000
export HISTCONTROL=ignoreboth
export HISTTIMEFORMAT="%F %T "
# 不将以下命令记录到历史中
export HISTIGNORE="ls:ll:history:w:pwd:exit:clear"
EOF

chmod +x /etc/profile.d/history-settings.sh
echo "已创建新的历史命令设置脚本: /etc/profile.d/history-settings.sh"

# 修复用户级配置
USER_HOMES=("/root" "/home/*")
for user_path in "${USER_HOMES[@]}"; do
    if ls $user_path 1> /dev/null 2>&1; then
        for user_home in $user_path; do
            if [ -d "$user_home" ]; then
                echo "检查用户目录: $user_home"
                if [ -f "$user_home/.bashrc" ]; then
                    if grep -q "readonly.*HIST" "$user_home/.bashrc"; then
                        echo "在 $user_home/.bashrc 中发现只读历史变量设置"
                        cp "$user_home/.bashrc" "$user_home/.bashrc.bak.$(date +%Y%m%d%H%M%S)"
                        sed -i '/readonly.*HIST/d' "$user_home/.bashrc"
                        echo "已修复 $user_home/.bashrc"
                    fi
                fi
                
                if [ -f "$user_home/.bash_profile" ]; then
                    if grep -q "readonly.*HIST" "$user_home/.bash_profile"; then
                        echo "在 $user_home/.bash_profile 中发现只读历史变量设置"
                        cp "$user_home/.bash_profile" "$user_home/.bash_profile.bak.$(date +%Y%m%d%H%M%S)"
                        sed -i '/readonly.*HIST/d' "$user_home/.bash_profile"
                        echo "已修复 $user_home/.bash_profile"
                    fi
                fi
                
                # 确保历史文件存在且有正确权限
                touch "$user_home/.bash_history"
                chown $(stat -c %U:%G "$user_home") "$user_home/.bash_history"
                chmod 600 "$user_home/.bash_history"
            fi
        done
    fi
done

echo "系统历史命令功能恢复完成！请重启系统或注销后重新登录使设置生效。"