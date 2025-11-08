#!/bin/bash

echo "=== 修复所有 Longhorn 节点 ==="
echo ""

# 获取所有 Longhorn 节点
NODES=$(kubectl get nodes.longhorn.io -n longhorn-system -o jsonpath='{.items[*].metadata.name}')

echo "发现以下节点："
echo "$NODES"
echo ""

# 为每个节点取消驱逐并启用调度
for node in $NODES; do
  echo "处理节点: $node"
  
  # 检查当前状态
  EVICTION=$(kubectl get nodes.longhorn.io -n longhorn-system $node -o jsonpath='{.spec.evictionRequested}' 2>/dev/null)
  SCHEDULING=$(kubectl get nodes.longhorn.io -n longhorn-system $node -o jsonpath='{.spec.allowScheduling}' 2>/dev/null)
  
  echo "  当前状态: evictionRequested=$EVICTION, allowScheduling=$SCHEDULING"
  
  # 如果正在驱逐，则取消
  if [ "$EVICTION" = "true" ]; then
    echo "  取消驱逐..."
    kubectl patch nodes.longhorn.io -n longhorn-system $node --type='json' \
      -p='[{"op": "replace", "path": "/spec/evictionRequested", "value": false}]' 2>/dev/null
  fi
  
  # 如果调度被禁用，则启用
  if [ "$SCHEDULING" = "false" ]; then
    echo "  启用调度..."
    kubectl patch nodes.longhorn.io -n longhorn-system $node --type='json' \
      -p='[{"op": "replace", "path": "/spec/allowScheduling", "value": true}]' 2>/dev/null
  fi
  
  echo "  ✓ 完成"
  echo ""
done

echo "=== 最终状态 ==="
kubectl get nodes.longhorn.io -n longhorn-system -o custom-columns=\
NAME:.metadata.name,\
READY:.status.conditions[?\(@.type==\"Ready\"\)].status,\
SCHEDULABLE:.spec.allowScheduling,\
EVICTION:.spec.evictionRequested

echo ""
echo "等待 30 秒让 Longhorn 更新状态..."
sleep 30

echo ""
echo "检查 Volume 状态："
kubectl get volumes.longhorn.io -n longhorn-system | grep -E "NAME|pvc-ce4c5cee"

echo ""
echo "=== 完成 ==="
