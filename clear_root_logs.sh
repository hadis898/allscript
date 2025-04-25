#!/bin/bash

# ==============================================
# 一键清除 root 登录日志（Debian/Ubuntu）.
# 使用方法：sudo ./clear_root_logs.sh
# ==============================================

# 检查是否以 root 运行
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ 请使用 sudo 或以 root 用户运行此脚本！"
    exit 1
fi

# 1. 清除 wtmp（成功登录记录）
echo "[1/5] 清除 /var/log/wtmp（成功登录记录）..."
echo > /var/log/wtmp
echo "✅ wtmp 已清空"

# 2. 清除 btmp（失败登录记录）
echo "[2/5] 清除 /var/log/btmp（失败登录记录）..."
echo > /var/log/btmp
echo "✅ btmp 已清空"

# 3. 清除 systemd-journald 日志
echo "[3/5] 清除 systemd-journald 日志..."
journalctl --flush --rotate >/dev/null 2>&1
rm -rf /var/log/journal/*
systemctl restart systemd-journald >/dev/null 2>&1
echo "✅ journald 日志已清空"

# 4. 清除 auth.log（如果存在）
echo "[4/5] 清除 /var/log/auth.log（如果存在）..."
if [ -f "/var/log/auth.log" ]; then
    echo > /var/log/auth.log
    echo "✅ auth.log 已清空"
else
    echo "⚠️ /var/log/auth.log 不存在（可能使用 journald）"
fi

# 5. 可选：禁用 SSH 日志记录
read -p "❓ 是否禁用 SSH 日志记录？(y/N) " choice
if [[ "$choice" =~ [yY] ]]; then
    echo "[5/5] 禁用 SSH 日志记录..."
    sed -i 's/^#*LogLevel.*/LogLevel QUIET/' /etc/ssh/sshd_config
    sed -i 's/^#*SyslogFacility.*/SyslogFacility AUTHPRIV/' /etc/ssh/sshd_config
    systemctl restart sshd >/dev/null 2>&1
    echo "✅ SSH 日志已禁用（LogLevel QUIET）"
else
    echo "⏩ 跳过 SSH 日志禁用"
fi

# 完成
echo -e "\n🎉 所有 root 登录痕迹已清除！"
echo "运行以下命令验证："
echo "  last root      # 检查 wtmp"
echo "  lastb root     # 检查 btmp"
echo "  journalctl -u sshd _UID=0  # 检查 journald"