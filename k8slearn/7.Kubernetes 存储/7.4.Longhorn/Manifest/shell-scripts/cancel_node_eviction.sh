#!/bin/bash

NODE_NAME="hkkck8snode003"

echo "=== 取消 Longhorn 节点驱逐 ==="
echo ""

# 1. 检查节点当前状态
echo "1. 检查节点 $NODE_NAME 当前状态："
kubectl get nodes.longhorn.io -n longhorn-system $NODE_NAME -o yaml | grep -A 5 "evictionRequested\|allowScheduling"
echo ""

# 2. 取消节点驱逐
echo "2. 取消节点驱逐..."
kubectl patch nodes.longhorn.io -n longhorn-system $NODE_NAME --type='json' \
  -p='[{"op": "replace", "path": "/spec/evictionRequested", "value": false}]'

if [ $? -eq 0 ]; then
  echo "✓ 成功取消节点驱逐"
else
  echo "✗ 取消驱逐失败"
fi
echo ""

# 3. 启用节点调度
echo "3. 启用节点调度..."
kubectl patch nodes.longhorn.io -n longhorn-system $NODE_NAME --type='json' \
  -p='[{"op": "replace", "path": "/spec/allowScheduling", "value": true}]'

if [ $? -eq 0 ]; then
  echo "✓ 成功启用节点调度"
else
  echo "✗ 启用调度失败"
fi
echo ""

# 4. 验证修改
echo "4. 验证节点状态："
kubectl get nodes.longhorn.io -n longhorn-system $NODE_NAME -o jsonpath='{.spec.evictionRequested}' && echo " (evictionRequested)"
kubectl get nodes.longhorn.io -n longhorn-system $NODE_NAME -o jsonpath='{.spec.allowScheduling}' && echo " (allowScheduling)"
echo ""

# 5. 检查所有节点状态
echo "5. 检查所有 Longhorn 节点状态："
kubectl get nodes.longhorn.io -n longhorn-system -o custom-columns=\
NAME:.metadata.name,\
READY:.status.conditions[?\(@.type==\"Ready\"\)].status,\
SCHEDULABLE:.spec.allowScheduling,\
EVICTION:.spec.evictionRequested
echo ""

echo "=== 完成 ==="
echo ""
echo "现在可以重试之前失败的操作"
