#!/bin/bash

echo "=== 快速修复 Longhorn 副本调度问题 ==="
echo ""

# 方案1: 检查并修复所有节点
echo "步骤 1: 确保所有节点可调度"
for node in $(kubectl get nodes.longhorn.io -n longhorn-system -o jsonpath='{.items[*].metadata.name}'); do
  echo "  处理节点: $node"
  
  # 取消驱逐
  kubectl patch nodes.longhorn.io -n longhorn-system $node --type='json' \
    -p='[{"op": "replace", "path": "/spec/evictionRequested", "value": false}]' 2>/dev/null
  
  # 启用调度
  kubectl patch nodes.longhorn.io -n longhorn-system $node --type='json' \
    -p='[{"op": "replace", "path": "/spec/allowScheduling", "value": true}]' 2>/dev/null
done
echo "  ✓ 完成"
echo ""

# 方案2: 降低存储最小可用空间要求
echo "步骤 2: 调整存储最小可用空间要求（从 25% 降到 10%）"
kubectl patch settings.longhorn.io -n longhorn-system storage-minimal-available-percentage \
  --type='json' -p='[{"op": "replace", "path": "/value", "value": "10"}]' 2>/dev/null
echo "  ✓ 完成"
echo ""

# 方案3: 启用副本软反亲和性（允许同节点多副本）
echo "步骤 3: 启用副本软反亲和性"
kubectl patch settings.longhorn.io -n longhorn-system replica-soft-anti-affinity \
  --type='json' -p='[{"op": "replace", "path": "/value", "value": "true"}]' 2>/dev/null
echo "  ✓ 完成"
echo ""

# 方案4: 检查节点数量，如果少于3个，建议减少副本数
NODE_COUNT=$(kubectl get nodes.longhorn.io -n longhorn-system --no-headers | wc -l)
echo "步骤 4: 检查节点数量"
echo "  当前节点数: $NODE_COUNT"

if [ $NODE_COUNT -lt 3 ]; then
  echo "  ⚠ 警告: 节点数少于 3，建议使用单副本 StorageClass"
  echo ""
  echo "  创建单副本 StorageClass:"
  cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-single-replica
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: Immediate
parameters:
  numberOfReplicas: "1"
  staleReplicaTimeout: "30"
  fromBackup: ""
  fsType: "ext4"
  dataLocality: "disabled"
EOF
  echo ""
  echo "  然后删除现有 PVC 并使用新的 StorageClass 重新创建"
else
  echo "  ✓ 节点数量充足"
fi
echo ""

# 等待系统更新
echo "步骤 5: 等待 Longhorn 更新状态（30秒）..."
sleep 30

# 检查结果
echo ""
echo "=== 检查修复结果 ==="
echo ""
echo "节点状态:"
kubectl get nodes.longhorn.io -n longhorn-system -o custom-columns=\
NAME:.metadata.name,\
READY:.status.conditions[?\(@.type==\"Ready\"\)].status,\
SCHEDULABLE:.spec.allowScheduling

echo ""
echo "Volume 状态:"
kubectl get volumes.longhorn.io -n longhorn-system | head -10

echo ""
echo "=== 完成 ==="
echo ""
echo "如果问题仍然存在，请运行诊断脚本："
echo "./diagnose_replica_scheduling.sh"
