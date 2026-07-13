#!/bin/bash
# ============================================================
# 禁用 Ubuntu 系统自动更新 / 锁定 K8s 相关软件包
# 执行方式: sudo bash disable-auto-update.sh
# ============================================================
set -e

echo ">>> 1/5 切换到 bash 作为默认 shell (替换 dash)"
rm -f /bin/sh
ln -s /bin/bash /bin/sh

echo ">>> 2/5 禁用 apt-daily 自动更新服务"
systemctl stop apt-daily.service apt-daily.timer 2>/dev/null || true
systemctl stop apt-daily-upgrade.service apt-daily-upgrade.timer 2>/dev/null || true
systemctl disable apt-daily.service apt-daily.timer 2>/dev/null || true
systemctl disable apt-daily-upgrade.service apt-daily-upgrade.timer 2>/dev/null || true
systemctl mask apt-daily.service apt-daily.timer 2>/dev/null || true
systemctl mask apt-daily-upgrade.service apt-daily-upgrade.timer 2>/dev/null || true

echo ">>> 3/5 彻底卸载/禁用 unattended-upgrades"
apt purge unattended-upgrades -y 2>/dev/null || true
# 删除可能残留的配置
rm -f /etc/apt/apt.conf.d/20auto-upgrades
rm -f /etc/apt/apt.conf.d/50unattended-upgrades

echo ">>> 4/5 禁用 snapd 自动刷新"
systemctl stop snapd.service snapd.socket 2>/dev/null || true
systemctl disable snapd.service snapd.socket 2>/dev/null || true
systemctl mask snapd.service 2>/dev/null || true
# 禁用 snap 自动刷新定时器
systemctl stop snapd.snap-repair.timer 2>/dev/null || true
systemctl disable snapd.snap-repair.timer 2>/dev/null || true
systemctl stop snap.lxd.activate.service 2>/dev/null || true
systemctl disable snap.lxd.activate.service 2>/dev/null || true

echo ">>> 5/5 加速 systemd-networkd-wait-online (减少启动等待)"
mkdir -p /etc/systemd/system/systemd-networkd-wait-online.service.d
cat > /etc/systemd/system/systemd-networkd-wait-online.service.d/override.conf << 'EOF'
[Service]
TimeoutStartSec=1
EOF
systemctl daemon-reload


echo ""
echo "=========================================="
echo " 完成。当前锁定状态:"
echo "=========================================="
echo ""
echo "已禁用服务: apt-daily, unattended-upgrades, snapd"

