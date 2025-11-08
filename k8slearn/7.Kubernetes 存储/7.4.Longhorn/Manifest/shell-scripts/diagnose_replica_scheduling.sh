#!/bin/bash

VOLUME_NAME="pvc-aec30cba-1c06-4ea7-b56c-b1d47be221dc"

echo "=== Longhorn 副本调度失败诊断 ==="
echo ""

# 1. 检查 Volume 详细信息
echo "1. 检查 Volume 详细信息："
kubectl get volumes.longhorn.io -n longhorn-system $VOLUME_NAME -o yaml | grep -A 20 "spec:\|status:"
echo ""

# 2. 检查所有节点状态
echo "2. 检查所有 Longhorn 节点状态："
kubectl get nodes.longhorn.io -n longhorn-system -o custom-columns=\
NAME:.metadata.name,\
READY:.status.conditions[?\(@.type==\"Ready\"\)].status,\
SCHEDULABLE:.spec.allowScheduling,\
EVICTION:.spec.evictionRequested
echo ""

# 3. 检查节点磁盘状态
echo "3. 检查节点磁盘状态："
for node in $(kubectl get nodes.longhorn.io -n longhorn-system -o jsonpath='{.items[*].metadata.name}'); do
  echo "节点: $node"
  kubectl get nodes.longhorn.io -n longhorn-system $node -o jsonpath='{.status.diskStatus}' | jq '.' 2>/dev/null || echo "  无法获取磁盘状态"
  echo ""
done

# 4. 检查副本状态
echo "4. 检查副本状态："
kubectl get replicas.longhorn.io -n longhorn-system -l longhornvolume=$VOLUME_NAME -o wide
echo ""

# 5. 检查 Longhorn Manager 日志（查找调度错误）
echo "5. 检查 Longhorn Manager 日志（最近 50 行，过滤调度相关）："
kubectl logs -n longhorn-system -l app=longhorn-manager --tail=50 | grep -i "schedul\|replica\|$VOLUME_NAME" || echo "未找到相关日志"
echo ""

# 6. 检查节点资源
echo "6. 检查 Kubernetes 节点资源："
kubectl top nodes 2>/dev/null || echo "metrics-server 未安装，跳过"
echo ""

# 7. 检查磁盘空间要求
echo "7. 检查 Longhorn 设置："
kubectl get settings.longhorn.io -n longhorn-system -o custom-columns=\
NAME:.metadata.name,\
VALUE:.value | grep -E "NAME|storage-minimal|replica-soft-anti-affinity|replica-auto-balance"
echo ""

# 8. 检查节点标签和污点
echo "8. 检查节点标签和污点："
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  echo "节点: $node"
  echo "  标签:"
  kubectl get node $node -o jsonpath='{.metadata.labels}' | jq '.' 2>/dev/null | grep -i longhorn || echo "    无 Longhorn 相关标签"
  echo "  污点:"
  kubectl get node $node -o jsonpath='{.spec.taints}' | jq '.' 2>/dev/null || echo "    无污点"
  echo ""
done

echo "=== 常见原因和解决方案 ==="
echo ""
echo "replica scheduling failed 的常见原因："
echo ""
echo "1. 磁盘空间不足"
echo "   - 检查: df -h /var/lib/longhorn"
echo "   - 解决: 清理磁盘或增加容量"
echo ""
echo "2. 可调度节点数量不足"
echo "   - 需要的副本数: 3（默认）"
echo "   - 解决: 启用更多节点或减少副本数"
echo ""
echo "3. 节点磁盘被禁用"
echo "   - 解决: 在 Longhorn UI 中启用磁盘"
echo ""
echo "4. 磁盘空间低于最小要求"
echo "   - 默认要求: 25% 可用空间"
echo "   - 解决: 调整 storage-minimal-available-percentage"
echo ""
echo "5. 副本反亲和性限制"
echo "   - 同一节点不能有多个副本"
echo "   - 解决: 增加节点数量"
echo ""
