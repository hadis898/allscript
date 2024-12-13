#!/bin/bash

# 服务器初始化和安全配置脚本
# 1. 配置SSH远程访问
# 2. bbr优化网络性能
# 3. 准备基础系统环境

# 定义颜色常量，用于增强终端输出可读性
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # 恢复默认颜色

# 启用BBR（Bottleneck Bandwidth and Round-trip propagation time）内核拥塞控制算法
# 提高网络传输效率和性能
echo "正在配置网络性能优化 (BBR)"
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcpcongestioncontrol=bbr" >> /etc/sysctl.conf
sysctl -p

# 设置root用户密码
# 注意：生产环境中建议使用更复杂的密码
echo "正在重置root用户密码"
echo root:woaichiyu9527 | sudo chpasswd root

# 配置SSH远程访问
# 警告：仅在可信网络环境中启用root直接登录
echo "配置SSH远程访问设置"
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sudo service sshd restart

# 移除不常用的系统文档工具，减少系统占用
echo "清理系统不必要的文档工具"
apt -y remove man-db

# 更新系统并安装基础网络工具
echo "更新系统软件包并安装常用网络工具"
apt -y update && apt -y install curl wget

# 输出执行结果
echo -e "${GREEN}SSH root登录和密码验证已配置完成${NC}"
echo -e "${GREEN}root用户密码已重置${NC}"
echo -e "${GREEN}基础网络工具已安装${NC}"
echo -e "${GREEN}网络性能优化（BBR）已启用${NC}"

echo "服务器初始化脚本执行完毕！"
