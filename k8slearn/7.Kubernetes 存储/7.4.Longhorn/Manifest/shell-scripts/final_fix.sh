#!/bin/bash

echo "=== Longhorn 副本调度问题最终修复方案 ==="
echo ""

# 方案1: 启用 Master 节点调度（如果你想使用 Master 节点存储）
echo "选项 1: 启用 Master 节点调度"
echo "  当前 hkkck8smaster001 的 allowScheduling=false"
echo "  是否启用 Master 节点？(y/n)"
read -p "  输入选择: " enable_master

if [ "$enable_master" = "y" ]; then
  echo "  启用 Master 节点调度..."
  kubectl patch nodes.longhorn.io -n longhorn-system hkkck8smaster001 --type='json' \
    -p='[{"op": "replace", "path": "/spec/allowScheduling", "value": true}]'
  echo "  ✓ 已启用"
fi
echo ""

# 方案2: 降低存储最小可用空间要求
echo "选项 2: 降低存储最小可用空间要求"
echo "  当前设置: 15%"
echo "  建议降低到: 5%"
read -p "  是否降低？(y/n): " lower_storage

if [ "$lower_storage" = "y" ]; then
  echo "  降低存储最小可用空间要求到 5%..."
  kubectl patch settings.longhorn.io -n longhorn-system storage-minimal-available-percentage \
    --type='json' -p='[{"op": "replace", "path": "/value", "value": "5"}]'
  echo "  ✓ 已降低"
fi
echo ""

# 方案3: 启用副本软反亲和性
echo "选项 3: 启用副本软反亲和性（允许同节点多副本）"
echo "  当前设置: false"
read -p "  是否启用？(y/n): " enable_soft_anti

if [ "$enable_soft_anti" = "y" ]; then
  echo "  启用副本软反亲和性..."
  kubectl patch settings.longhorn.io -n longhorn-system replica-soft-anti-affinity \
    --type='json' -p='[{"op": "replace", "path": "/value", "value": "true"}]'
  echo "  ✓ 已启用"
fi
echo ""

# 方案4: 使用单副本 StorageClass（推荐）
echo "选项 4: 创建单副本 StorageClass（推荐用于测试环境）"
read -p "  是否创建？(y/n): " create_single

if [ "$create_single" = "y" ]; then
  echo "  创建单副本 StorageClass..."
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
  echo "  ✓ 已创建"
  echo ""
  echo "  现在需要重新创建 PVC："
  echo "  1. 删除现有 PVC: kubectl delete pvc mysql-pvc"
  echo "  2. 修改 PVC 使用新的 StorageClass: longhorn-single-replica"
  echo "  3. 重新创建 PVC"
fi
echo ""

# 等待系统更新
echo "等待 30 秒让 Longhorn 更新配置..."
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
echo "副本状态:"
kubectl get replicas.longhorn.io -n longhorn-system -l longhornvolume=pvc-aec30cba-1c06-4ea7-b56c-b1d47be221dc

echo ""
echo "Volume 状态:"
kubectl get volumes.longhorn.io -n longhorn-system pvc-aec30cba-1c06-4ea7-b56c-b1d47be221dc -o jsonpath='{.status.conditions[?(@.type=="Scheduled")]}' | jq '.'

echo ""
echo "=== 完成 ==="
