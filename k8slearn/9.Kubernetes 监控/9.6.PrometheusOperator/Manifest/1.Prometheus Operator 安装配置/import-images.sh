#!/bin/bash

echo "=== kube-prometheus 镜像导入脚本 ==="
echo ""

export_dir="kube-prometheus-images"

# 检查目录是否存在
if [ ! -d "$export_dir" ]; then
  echo "错误: 目录 $export_dir 不存在"
  echo "请先运行 export-images.sh 导出镜像"
  exit 1
fi

# 统计 tar 文件数量
tar_count=$(ls -1 "$export_dir"/*.tar 2>/dev/null | wc -l)

if [ "$tar_count" -eq 0 ]; then
  echo "错误: 在 $export_dir 目录中没有找到 .tar 文件"
  exit 1
fi

echo "找到 $tar_count 个镜像文件"
echo ""

current=0

# 导入所有镜像
for tar_file in "$export_dir"/*.tar; do
  current=$((current + 1))
  
  echo "[$current/$tar_count] 导入镜像: $(basename $tar_file)"
  
  if docker load -i "$tar_file"; then
    echo "  ✓ 成功"
  else
    echo "  ✗ 失败"
  fi
  echo ""
done

echo "=== 完成 ==="
echo ""
echo "已导入的镜像:"
docker images | grep -E "prometheus|grafana|kube-state-metrics|configmap-reload|kube-rbac-proxy"
