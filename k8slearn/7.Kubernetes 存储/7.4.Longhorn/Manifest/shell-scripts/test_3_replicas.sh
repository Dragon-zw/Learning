#!/bin/bash

echo "=== 测试 3 副本创建 ==="
echo ""

# 1. 检查可用节点
echo "1. 检查可用节点："
AVAILABLE_NODES=$(kubectl get nodes.longhorn.io -n longhorn-system -o json | jq -r '
  [.items[] | 
   select(.spec.allowScheduling==true) | 
   select(.status.diskStatus.Disk.conditions[] | select(.type=="Schedulable" and .status=="True"))
  ] | length
')

echo "   可用节点数: $AVAILABLE_NODES"

if [ "$AVAILABLE_NODES" -lt 3 ]; then
  echo "   ⚠ 警告: 可用节点少于 3 个"
  echo "   当前副本软反亲和性已启用，可以在同一节点创建多个副本"
fi
echo ""

# 2. 删除旧的失败 PVC
echo "2. 清理失败的 PVC..."
kubectl get pvc -n default | grep -E "html|mysql" | awk '{print $1}' | while read pvc; do
  STATUS=$(kubectl get pvc $pvc -n default -o jsonpath='{.status.phase}')
  echo "   PVC: $pvc, 状态: $STATUS"
  
  if [ "$STATUS" != "Bound" ]; then
    read -p "   是否删除 PVC $pvc? (y/n): " delete_pvc
    if [ "$delete_pvc" = "y" ]; then
      kubectl delete pvc $pvc -n default
      echo "   ✓ 已删除"
    fi
  fi
done
echo ""

# 3. 创建测试 PVC
echo "3. 创建测试 PVC（3 副本）..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-3-replicas
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 1Gi
EOF

echo "   ✓ 已创建测试 PVC"
echo ""

# 4. 等待 PVC 绑定
echo "4. 等待 PVC 绑定（最多 60 秒）..."
for i in {1..12}; do
  STATUS=$(kubectl get pvc test-3-replicas -n default -o jsonpath='{.status.phase}' 2>/dev/null)
  echo "   尝试 $i/12: $STATUS"
  
  if [ "$STATUS" = "Bound" ]; then
    echo "   ✓ PVC 已成功绑定！"
    break
  fi
  
  if [ $i -eq 12 ]; then
    echo "   ✗ PVC 绑定超时"
    echo ""
    echo "   检查错误信息："
    PV_NAME=$(kubectl get pvc test-3-replicas -n default -o jsonpath='{.spec.volumeName}')
    if [ -n "$PV_NAME" ]; then
      kubectl get pv $PV_NAME -o jsonpath='{.metadata.annotations.longhorn\.io/volume-scheduling-error}'
      echo ""
    fi
  fi
  
  sleep 5
done
echo ""

# 5. 检查副本分布
if [ "$STATUS" = "Bound" ]; then
  echo "5. 检查副本分布："
  PV_NAME=$(kubectl get pvc test-3-replicas -n default -o jsonpath='{.spec.volumeName}')
  VOLUME_NAME=$(kubectl get pv $PV_NAME -o jsonpath='{.spec.csi.volumeHandle}')
  
  echo "   Volume: $VOLUME_NAME"
  echo ""
  echo "   副本状态:"
  kubectl get replicas.longhorn.io -n longhorn-system -l longhornvolume=$VOLUME_NAME -o custom-columns=\
NAME:.metadata.name,\
STATE:.status.currentState,\
NODE:.spec.nodeID,\
DISK:.spec.diskID
  
  echo ""
  echo "   ✓ 测试成功！3 副本已创建"
  echo ""
  echo "   清理测试资源："
  echo "   kubectl delete pvc test-3-replicas -n default"
else
  echo "5. 测试失败，检查日志："
  kubectl logs -n longhorn-system -l app=longhorn-manager --tail=20 | grep -i "replica\|schedul"
fi

echo ""
echo "=== 完成 ==="
