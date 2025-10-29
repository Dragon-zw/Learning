#!/bin/bash
echo "=== 停止并删除 nerdctl 容器 ==="
nerdctl stop $(nerdctl ps -aq) 2>/dev/null || true
nerdctl rm $(nerdctl ps -aq) 2>/dev/null || true

echo "=== 删除 nerdctl0 网桥 ==="
ip link set nerdctl0 down 2>/dev/null || true
ip link delete nerdctl0 2>/dev/null || true

echo "=== 备份 nerdctl CNI 配置 ==="
mv /etc/cni/net.d/nerdctl-bridge.conflist /etc/cni/net.d/nerdctl-bridge.conflist.bak 2>/dev/null || true

echo "=== 验证删除 ==="
ip addr show nerdctl0 2>/dev/null && echo "nerdctl0 仍然存在" || echo "nerdctl0 已删除"