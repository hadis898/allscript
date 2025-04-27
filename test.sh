#!/bin/bash
# 恢复历史记录功能的脚本

# 恢复各个配置文件的备份
for config_file in ~/.bashrc ~/.bash_profile ~/.profile ~/.inputrc /etc/profile /etc/bash.bashrc; do
    if [ -f "${config_file}.original" ]; then
        sudo cp "${config_file}.original" "${config_file}" 2>/dev/null
        sudo rm -f "${config_file}.original" 2>/dev/null
        echo "已恢复 ${config_file} 的原始备份"
    fi
done

# 删除可能存在的history.sh文件
sudo rm -f /etc/profile.d/history.sh 2>/dev/null

# 恢复bash_logout文件
if [ -f ~/.bash_logout.original ]; then
    sudo cp ~/.bash_logout.original ~/.bash_logout 2>/dev/null
    sudo rm -f ~/.bash_logout.original 2>/dev/null
    echo "已恢复 ~/.bash_logout 的原始备份"
else
    # 删除可能存在的清理历史记录命令
    sudo sed -i '/# 退出时清理当前会话历史/d' ~/.bash_logout 2>/dev/null
    sudo sed -i '/history -c/d' ~/.bash_logout 2>/dev/null
    sudo sed -i '/history -w/d' ~/.bash_logout 2>/dev/null
    echo "已清理 ~/.bash_logout 中的历史记录禁用命令"
fi

# 设置正确的历史记录参数
echo "# 恢复默认历史记录设置 - $(date)" >> ~/.bashrc
echo "HISTSIZE=1000" >> ~/.bashrc
echo "HISTFILESIZE=2000" >> ~/.bashrc
echo "export HISTSIZE HISTFILESIZE" >> ~/.bashrc

# 立即应用设置
HISTSIZE=1000
HISTFILESIZE=2000
export HISTSIZE HISTFILESIZE

echo "历史记录功能已恢复，请注销并重新登录以完全生效"