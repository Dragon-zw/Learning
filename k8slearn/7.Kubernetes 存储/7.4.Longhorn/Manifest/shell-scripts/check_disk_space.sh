#!/bin/bash

echo "=== 检查所有节点的 Longhorn 磁盘空间 ==="
echo ""

# 检查每个节点的磁盘空间
for node in hkkck8smaster001 hkkck8snode001 hkkck8snode002 hkkck8snode003; do
  echo "节点: $node"
  echo "  检查 /var/lib/containerd/longhorn 磁盘空间："
  
  # 使用 kubectl exec 到节点检查磁盘空间
  kubectl get node $node &>/dev/null
  if [ $? -eq 0 ]; then
    # 尝试通过 debug 容器检查
    kubectl debug node/$node -it --image=busybox:1.28 -- df -h 2>/dev/null | grep -E "Filesystem|longhorn|/$" || \
    echo "    无法直接检查，请手动在节点上执行: df -h /var/lib/containerd/longhorn"
  fi
  echo ""
done

echo "=== 检查 Longhorn 节点磁盘配置 ==="
for node in $(kubectl get nodes.longhorn.io -n longhorn-system -o jsonpath='{.items[*].metadata.name}'); do
  echo ""
  echo "节点: $node"
  kubectl get nodes.longhorn.io -n longhorn-system $node -o jsonpath='{.spec.disks}' | jq '.'
done
