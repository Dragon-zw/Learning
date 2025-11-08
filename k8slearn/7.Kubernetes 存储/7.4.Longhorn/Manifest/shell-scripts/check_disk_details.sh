#!/bin/bash

echo "=== 详细检查 Longhorn 磁盘状态 ==="
echo ""

# 检查每个节点的详细磁盘信息
for node in $(kubectl get nodes.longhorn.io -n longhorn-system -o jsonpath='{.items[*].metadata.name}'); do
  echo "=========================================="
  echo "节点: $node"
  echo "=========================================="
  
  # 节点基本信息
  echo ""
  echo "节点配置:"
  kubectl get nodes.longhorn.io -n longhorn-system $node -o jsonpath='{.spec}' | jq '{allowScheduling, evictionRequested, disks}'
  
  echo ""
  echo "节点状态:"
  kubectl get nodes.longhorn.io -n longhorn-system $node -o jsonpath='{.status}' | jq '{conditions, diskStatus}'
  
  echo ""
  echo "磁盘详细信息:"
  kubectl get nodes.longhorn.io -n longhorn-system $node -o json | jq -r '
    .status.diskStatus | to_entries[] | 
    "磁盘ID: \(.key)
    路径: \(.value.diskPath // "N/A")
    类型: \(.value.diskType // "N/A")
    总容量: \((.value.storageMaximum / 1073741824) | floor)GB
    可用空间: \((.value.storageAvailable / 1073741824) | floor)GB
    已调度: \((.value.storageScheduled / 1073741824) | floor)GB
    使用率: \(100 - ((.value.storageAvailable / .value.storageMaximum) * 100) | floor)%
    可调度: \(.value.conditions[] | select(.type==\"Schedulable\") | .status)
    原因: \(.value.conditions[] | select(.type==\"Schedulable\") | .reason)
    消息: \(.value.conditions[] | select(.type==\"Schedulable\") | .message)
    "
  '
  
  echo ""
done

echo ""
echo "=========================================="
echo "汇总信息"
echo "=========================================="

# 统计可用节点和磁盘
TOTAL_NODES=$(kubectl get nodes.longhorn.io -n longhorn-system --no-headers | wc -l)
SCHEDULABLE_NODES=$(kubectl get nodes.longhorn.io -n longhorn-system -o json | jq '[.items[] | select(.spec.allowScheduling==true)] | length')
READY_NODES=$(kubectl get nodes.longhorn.io -n longhorn-system -o json | jq '[.items[] | select(.status.conditions[] | select(.type=="Ready" and .status=="True"))] | length')

echo ""
echo "节点统计:"
echo "  总节点数: $TOTAL_NODES"
echo "  可调度节点: $SCHEDULABLE_NODES"
echo "  就绪节点: $READY_NODES"

# 统计可用磁盘
echo ""
echo "磁盘统计:"
kubectl get nodes.longhorn.io -n longhorn-system -o json | jq -r '
  .items[] | 
  .metadata.name as $node |
  .status.diskStatus | to_entries[] |
  "\($node):\(.key): \(.value.conditions[] | select(.type==\"Schedulable\") | .status)"
' | awk '{
  total++
  if ($2 == "True") schedulable++
}
END {
  print "  总磁盘数: " total
  print "  可调度磁盘: " schedulable
  print "  不可调度磁盘: " (total - schedulable)
}'

# 计算总存储容量
echo ""
echo "存储容量:"
kubectl get nodes.longhorn.io -n longhorn-system -o json | jq -r '
  [.items[].status.diskStatus | to_entries[].value | 
   {max: .storageMaximum, avail: .storageAvailable, sched: .storageScheduled}
  ] | 
  {
    total: (map(.max) | add / 1073741824 | floor),
    available: (map(.avail) | add / 1073741824 | floor),
    scheduled: (map(.sched) | add / 1073741824 | floor)
  } |
  "  总容量: \(.total)GB\n  可用空间: \(.available)GB\n  已调度: \(.scheduled)GB\n  使用率: \(100 - (.available / .total * 100) | floor)%"
'

echo ""
echo "=========================================="
echo "问题诊断"
echo "=========================================="
echo ""

# 检查是否有足够的可调度磁盘
if [ "$SCHEDULABLE_NODES" -lt 3 ]; then
  echo "⚠ 警告: 可调度节点数 ($SCHEDULABLE_NODES) 少于 3"
  echo "  建议: 启用更多节点或使用副本软反亲和性"
fi

# 检查磁盘空间
kubectl get nodes.longhorn.io -n longhorn-system -o json | jq -r '
  .items[] | 
  .metadata.name as $node |
  .status.diskStatus | to_entries[] |
  select(.value.conditions[] | select(.type=="Schedulable" and .status=="False")) |
  "⚠ 节点 \($node) 磁盘 \(.key) 不可调度: \(.value.conditions[] | select(.type==\"Schedulable\") | .message)"
'

echo ""
echo "完成！"
