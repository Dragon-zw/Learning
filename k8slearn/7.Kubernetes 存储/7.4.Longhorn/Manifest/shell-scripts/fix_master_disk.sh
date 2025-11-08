#!/bin/bash

echo "=== 修复 Master 节点磁盘问题 ==="
echo ""

# Master 节点的磁盘目录不存在，需要创建
echo "1. 在 Master 节点上创建 Longhorn 磁盘目录..."
echo "   需要在 hkkck8smaster001 上执行以下命令："
echo ""
echo "   sudo mkdir -p /var/lib/containerd/longhorn"
echo "   sudo chmod 755 /var/lib/containerd/longhorn"
echo ""
echo "   或者直接禁用 Master 节点调度（推荐）"
echo ""

read -p "是否禁用 Master 节点调度？(y/n): " disable_master

if [ "$disable_master" = "y" ]; then
  echo ""
  echo "2. 禁用 Master 节点调度..."
  kubectl patch nodes.longhorn.io -n longhorn-system hkkck8smaster001 --type='json' \
    -p='[{"op": "replace", "path": "/spec/allowScheduling", "value": false}]'
  echo "   ✓ 已禁用 Master 节点调度"
  echo ""
  echo "   现在你有 3 个可用的 Worker 节点用于存储副本"
else
  echo ""
  echo "2. 请手动在 Master 节点上创建目录后，重启 Longhorn Manager"
  echo "   kubectl rollout restart deployment/longhorn-manager -n longhorn-system"
fi

echo ""
echo "3. 等待 30 秒..."
sleep 30

echo ""
echo "=== 检查结果 ==="
kubectl get nodes.longhorn.io -n longhorn-system -o custom-columns=\
NAME:.metadata.name,\
SCHEDULABLE:.spec.allowScheduling,\
DISK_READY:.status.diskStatus.Disk.conditions[?\(@.type==\"Ready\"\)].status,\
DISK_SCHEDULABLE:.status.diskStatus.Disk.conditions[?\(@.type==\"Schedulable\"\)].status

echo ""
echo "可调度节点统计:"
kubectl get nodes.longhorn.io -n longhorn-system -o json | jq -r '
  [.items[] | select(.spec.allowScheduling==true and .status.diskStatus.Disk.conditions[] | select(.type=="Schedulable" and .status=="True"))] | 
  "  可用于副本调度的节点数: \(length)"
'

echo ""
echo "=== 完成 ==="
