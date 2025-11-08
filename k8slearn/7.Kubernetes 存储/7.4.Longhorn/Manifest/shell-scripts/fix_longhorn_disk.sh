#!/bin/bash

echo "=== Longhorn 磁盘问题诊断和修复 ==="
echo ""

# 1. 检查 Longhorn 节点状态
echo "1. 检查 Longhorn 节点状态："
kubectl get nodes -n longhorn-system -o wide
echo ""

# 2. 检查 Longhorn 节点详细信息
echo "2. 检查 Longhorn 节点资源："
kubectl get nodes.longhorn.io -n longhorn-system
echo ""

# 3. 检查磁盘空间
echo "3. 检查所有节点的磁盘空间："
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  echo "节点: $node"
  kubectl debug node/$node -it --image=busybox -- df -h /var/lib/longhorn 2>/dev/null || \
  kubectl get node $node -o json | jq -r '.status.allocatable'
  echo ""
done

# 4. 检查 Longhorn Manager 日志
echo "4. 检查 Longhorn Manager 日志（最近 20 行）："
kubectl logs -n longhorn-system -l app=longhorn-manager --tail=20
echo ""

# 5. 检查问题 Volume 状态
echo "5. 检查问题 Volume 状态："
kubectl get volumes.longhorn.io -n longhorn-system pvc-ce4c5cee-e4a9-4f03-b60e-8a0b10500d8d -o yaml
echo ""

# 6. 检查 Longhorn 设置
echo "6. 检查 Longhorn 存储设置："
kubectl get settings.longhorn.io -n longhorn-system
echo ""

echo "=== 常见修复方案 ==="
echo ""
echo "问题：disks are unavailable"
echo ""
echo "可能原因和解决方案："
echo ""
echo "1. 磁盘空间不足"
echo "   解决：清理磁盘空间或增加磁盘容量"
echo "   检查命令: df -h /var/lib/longhorn"
echo ""
echo "2. 节点磁盘未启用或调度被禁用"
echo "   解决：在 Longhorn UI 中启用节点磁盘"
echo "   或执行以下命令查看节点状态："
echo "   kubectl get nodes.longhorn.io -n longhorn-system -o yaml"
echo ""
echo "3. 副本数量设置过高（当前设置为 3）"
echo "   解决：减少副本数量或增加可用节点"
echo "   修改 StorageClass 的 numberOfReplicas 参数"
echo ""
echo "4. 磁盘标签或污点问题"
echo "   解决：检查节点标签和污点配置"
echo ""
