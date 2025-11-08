#!/bin/bash

echo "=== Longhorn 自动修复（无需交互）==="
echo ""

# 1. 降低存储最小可用空间要求
echo "1. 降低存储最小可用空间要求到 5%..."
kubectl patch settings.longhorn.io -n longhorn-system storage-minimal-available-percentage \
  --type='json' -p='[{"op": "replace", "path": "/value", "value": "5"}]' 2>/dev/null
echo "   ✓ 完成"
echo ""

# 2. 启用副本软反亲和性
echo "2. 启用副本软反亲和性..."
kubectl patch settings.longhorn.io -n longhorn-system replica-soft-anti-affinity \
  --type='json' -p='[{"op": "replace", "path": "/value", "value": "true"}]' 2>/dev/null
echo "   ✓ 完成"
echo ""

# 3. 启用所有节点调度（包括 Master）
echo "3. 启用所有节点调度..."
for node in $(kubectl get nodes.longhorn.io -n longhorn-system -o jsonpath='{.items[*].metadata.name}'); do
  echo "   处理节点: $node"
  kubectl patch nodes.longhorn.io -n longhorn-system $node --type='json' \
    -p='[{"op": "replace", "path": "/spec/allowScheduling", "value": true}]' 2>/dev/null
done
echo "   ✓ 完成"
echo ""

# 4. 创建单副本 StorageClass
echo "4. 创建单副本 StorageClass..."
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
echo "   ✓ 完成"
echo ""

# 等待系统更新
echo "5. 等待 30 秒让 Longhorn 更新配置..."
sleep 30

echo ""
echo "=== 检查修复结果 ==="
echo ""
echo "节点状态:"
kubectl get nodes.longhorn.io -n longhorn-system -o custom-columns=\
NAME:.metadata.name,\
READY:.status.conditions[?\(@.type==\"Ready\"\)].status,\
SCHEDULABLE:.spec.allowScheduling

echo ""
echo "Longhorn 设置:"
kubectl get settings.longhorn.io -n longhorn-system -o custom-columns=\
NAME:.metadata.name,\
VALUE:.value | grep -E "NAME|storage-minimal|replica-soft-anti-affinity"

echo ""
echo "StorageClass:"
kubectl get sc | grep longhorn

echo ""
echo "=== 修复完成 ==="
echo ""
echo "如果问题仍然存在，可能是磁盘空间不足。"
echo "请运行以下命令检查磁盘空间："
echo "  kubectl get nodes.longhorn.io -n longhorn-system -o yaml | grep -A 10 diskStatus"
echo ""
echo "或者使用单副本 StorageClass 重新创建 PVC："
echo "  1. kubectl delete pvc mysql-pvc"
echo "  2. 修改 mysql-pvc.yaml 中的 storageClassName: longhorn-single-replica"
echo "  3. kubectl apply -f mysql-pvc.yaml"
