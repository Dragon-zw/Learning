#!/bin/bash

echo "=== 修复 Longhorn 3 副本调度问题 ==="
echo ""

# 1. 检查当前节点状态
echo "1. 检查当前节点状态："
kubectl get nodes.longhorn.io -n longhorn-system -o custom-columns=\
NAME:.metadata.name,\
READY:.status.conditions[?\(@.type==\"Ready\"\)].status,\
SCHEDULABLE:.spec.allowScheduling,\
EVICTION:.spec.evictionRequested
echo ""

# 2. 检查每个节点的磁盘状态
echo "2. 检查每个节点的磁盘状态："
for node in $(kubectl get nodes.longhorn.io -n longhorn-system -o jsonpath='{.items[*].metadata.name}'); do
  echo "节点: $node"
  echo "  磁盘配置:"
  kubectl get nodes.longhorn.io -n longhorn-system $node -o jsonpath='{.spec.disks}' | jq -r 'to_entries[] | "    \(.key): allowScheduling=\(.value.allowScheduling), path=\(.value.path)"'
  echo "  磁盘状态:"
  kubectl get nodes.longhorn.io -n longhorn-system $node -o jsonpath='{.status.diskStatus}' | jq -r 'to_entries[] | "    \(.key): schedulable=\(.value.conditions[] | select(.type=="Schedulable") | .status), available=\(.value.storageAvailable), total=\(.value.storageMaximum)"'
  echo ""
done

# 3. 启用所有节点调度
echo "3. 启用所有节点调度..."
for node in $(kubectl get nodes.longhorn.io -n longhorn-system -o jsonpath='{.items[*].metadata.name}'); do
  echo "  启用节点: $node"
  
  # 取消驱逐
  kubectl patch nodes.longhorn.io -n longhorn-system $node --type='json' \
    -p='[{"op": "replace", "path": "/spec/evictionRequested", "value": false}]' 2>/dev/null
  
  # 启用调度
  kubectl patch nodes.longhorn.io -n longhorn-system $node --type='json' \
    -p='[{"op": "replace", "path": "/spec/allowScheduling", "value": true}]' 2>/dev/null
  
  # 启用磁盘调度
  DISKS=$(kubectl get nodes.longhorn.io -n longhorn-system $node -o jsonpath='{.spec.disks}' | jq -r 'keys[]')
  for disk in $DISKS; do
    echo "    启用磁盘: $disk"
    kubectl patch nodes.longhorn.io -n longhorn-system $node --type='json' \
      -p="[{\"op\": \"replace\", \"path\": \"/spec/disks/$disk/allowScheduling\", \"value\": true}]" 2>/dev/null
  done
done
echo "  ✓ 完成"
echo ""

# 4. 降低存储最小可用空间要求
echo "4. 降低存储最小可用空间要求..."
CURRENT=$(kubectl get settings.longhorn.io -n longhorn-system storage-minimal-available-percentage -o jsonpath='{.value}')
echo "  当前值: $CURRENT%"
echo "  设置为: 5%"
kubectl patch settings.longhorn.io -n longhorn-system storage-minimal-available-percentage \
  --type='json' -p='[{"op": "replace", "path": "/value", "value": "5"}]'
echo "  ✓ 完成"
echo ""

# 5. 禁用副本反亲和性（如果节点不足）
echo "5. 检查副本反亲和性设置..."
SOFT_ANTI=$(kubectl get settings.longhorn.io -n longhorn-system replica-soft-anti-affinity -o jsonpath='{.value}')
echo "  当前 replica-soft-anti-affinity: $SOFT_ANTI"

NODE_COUNT=$(kubectl get nodes.longhorn.io -n longhorn-system -o jsonpath='{.items[?(@.spec.allowScheduling==true)]}' | jq '. | length')
echo "  可调度节点数: $NODE_COUNT"

if [ "$NODE_COUNT" -lt 3 ]; then
  echo "  ⚠ 警告: 可调度节点少于 3 个，启用软反亲和性..."
  kubectl patch settings.longhorn.io -n longhorn-system replica-soft-anti-affinity \
    --type='json' -p='[{"op": "replace", "path": "/value", "value": "true"}]'
  echo "  ✓ 已启用软反亲和性（允许同节点多副本）"
else
  echo "  ✓ 节点数量充足"
fi
echo ""

# 6. 检查磁盘空间
echo "6. 检查实际磁盘空间使用情况..."
echo "  在每个节点上检查 /var/lib/containerd/longhorn 或 /var/lib/longhorn"
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  echo ""
  echo "  节点: $node"
  # 尝试获取磁盘使用情况
  kubectl get nodes.longhorn.io -n longhorn-system $node -o jsonpath='{.status.diskStatus}' 2>/dev/null | \
    jq -r 'to_entries[] | "    磁盘: \(.key)\n    可用: \(.value.storageAvailable / 1073741824 | floor)GB / \(.value.storageMaximum / 1073741824 | floor)GB\n    使用率: \(100 - (.value.storageAvailable / .value.storageMaximum * 100) | floor)%"' 2>/dev/null || \
    echo "    无法获取磁盘信息"
done
echo ""

# 7. 等待系统更新
echo "7. 等待 30 秒让 Longhorn 更新状态..."
sleep 30

# 8. 检查修复结果
echo ""
echo "=== 修复结果 ==="
echo ""
echo "节点状态:"
kubectl get nodes.longhorn.io -n longhorn-system -o custom-columns=\
NAME:.metadata.name,\
READY:.status.conditions[?\(@.type==\"Ready\"\)].status,\
SCHEDULABLE:.spec.allowScheduling

echo ""
echo "磁盘调度状态:"
for node in $(kubectl get nodes.longhorn.io -n longhorn-system -o jsonpath='{.items[*].metadata.name}'); do
  echo "节点: $node"
  kubectl get nodes.longhorn.io -n longhorn-system $node -o jsonpath='{.status.diskStatus}' | \
    jq -r 'to_entries[] | "  磁盘 \(.key): \(.value.conditions[] | select(.type=="Schedulable") | .status) - \(.value.conditions[] | select(.type=="Schedulable") | .message)"' 2>/dev/null
done

echo ""
echo "Longhorn 设置:"
kubectl get settings.longhorn.io -n longhorn-system -o custom-columns=\
NAME:.metadata.name,\
VALUE:.value | grep -E "NAME|storage-minimal|replica-soft-anti-affinity|replica-auto-balance"

echo ""
echo "=== 完成 ==="
echo ""
echo "如果问题仍然存在，请检查："
echo "1. 磁盘空间是否真的不足（需要至少 3GB 可用空间用于 3 个 1GB 副本）"
echo "2. 运行: kubectl logs -n longhorn-system -l app=longhorn-manager --tail=50 | grep -i 'no available disk'"
echo "3. 访问 Longhorn UI 查看详细的磁盘状态"
