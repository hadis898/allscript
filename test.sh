#!/bin/bash

# 恢复命令历史功能脚本
# 用于修复命令历史记录配置问题

echo "正在检查并恢复命令历史功能..."

# 备份当前的 bashrc 文件
if [ -f ~/.bashrc ]; then
    cp ~/.bashrc ~/.bashrc.bak.$(date +%Y%m%d%H%M%S)
    echo "已备份 ~/.bashrc 文件"
fi

# 检查是否存在只读变量设置
grep -q "readonly.*HISTSIZE" ~/.bashrc
if [ $? -eq 0 ]; then
    echo "检测到 HISTSIZE 被设置为只读，正在删除相关设置..."
    sed -i '/readonly.*HISTSIZE/d' ~/.bashrc
fi

grep -q "readonly.*HISTFILESIZE" ~/.bashrc
if [ $? -eq 0 ]; then
    echo "检测到 HISTFILESIZE 被设置为只读，正在删除相关设置..."
    sed -i '/readonly.*HISTFILESIZE/d' ~/.bashrc
fi

# 添加正确的历史命令配置
cat >> ~/.bashrc << 'EOF'

# 命令历史设置
HISTSIZE=1000
HISTFILESIZE=2000
HISTCONTROL=ignoreboth
# 在历史文件中添加时间戳
HISTTIMEFORMAT="%F %T "
# 追加到历史文件而不是覆盖
shopt -s histappend
EOF

# 确保历史文件存在且有正确权限
touch ~/.bash_history
chmod 600 ~/.bash_history

echo "命令历史功能已恢复设置，请重新登录或执行以下命令使设置生效:"
echo "source ~/.bashrc"

echo "恢复完成！"