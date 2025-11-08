#!/bin/bash

echo "=== 启用 Longhorn 节点磁盘 ==="
echo ""

# 获取所有 Longhorn 节点
NODES=$(kubectl get nodes.longhorn.io -n longhorn-system -o jsonpath='{.items[*].metadata.name}')

echo "发现以下节点："
echo "$NODES"
echo ""

# 为每个节点启用磁盘调度
for node in $NODES; do
  echo "处理节点: $node"
  
  # 检查节点当前状态
  echo "  当前状态："
  kubectl get nodes.longhorn.io -n longhorn-system $node -o jsonpath='{.spec.allowScheduling}' && echo ""
  
  # 启用调度
  echo "  启用调度..."
  kubectl patch nodes.longhorn.io -n longhorn-system $node --type='json' \
    -p='[{"op": "replace", "path": "/spec/allowScheduling", "value": true}]'
  
  # 检查磁盘状态
  echo "  磁盘状态："
  kubectl get nodes.longhorn.io -n longhorn-system $node -o jsonpath='{.spec.disks}' | jq '.'
  
  echo ""
done

echo "=== 完成 ==="
echo ""
echo "请等待几分钟，然后检查 Volume 状态："
echo "kubectl get volumes.longhorn.io -n longhorn-system"
echo ""
echo "或访问 Longhorn UI 查看节点和磁盘状态"
