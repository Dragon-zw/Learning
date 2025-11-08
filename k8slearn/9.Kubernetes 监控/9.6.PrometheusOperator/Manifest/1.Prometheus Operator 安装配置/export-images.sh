#!/bin/bash

echo "=== kube-prometheus 镜像导出脚本 ==="
echo ""

# 镜像列表
images=(
  "quay.io/prometheus-operator/prometheus-operator:v0.86.0"
  "quay.io/prometheus/prometheus:v3.6.0"
  "quay.io/prometheus/alertmanager:v0.28.1"
  "quay.io/prometheus/node-exporter:v1.9.1"
  "registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.17.0"
  "grafana/grafana:12.2.0"
  "registry.k8s.io/prometheus-adapter/prometheus-adapter:v0.12.0"
  "quay.io/prometheus/blackbox-exporter:v0.27.0"
  "quay.io/brancz/kube-rbac-proxy:v0.20.0"
  "ghcr.io/jimmidyson/configmap-reload:v0.15.0"
)

# 创建导出目录
export_dir="kube-prometheus-images"
mkdir -p "$export_dir"

total=${#images[@]}
current=0

echo "总共需要导出 $total 个镜像"
echo "导出目录: $export_dir"
echo ""

# 导出所有镜像
for image in "${images[@]}"; do
  current=$((current + 1))
  
  # 生成文件名（替换特殊字符）
  filename=$(echo "$image" | tr '/:' '_')
  tar_file="${export_dir}/${filename}.tar"
  
  echo "[$current/$total] 导出镜像: $image"
  echo "  文件: $tar_file"
  
  if docker save "$image" -o "$tar_file"; then
    size=$(du -h "$tar_file" | cut -f1)
    echo "  ✓ 成功 (大小: $size)"
  else
    echo "  ✗ 失败"
  fi
  echo ""
done

echo "=== 完成 ==="
echo ""
echo "导出的镜像文件:"
ls -lh "$export_dir"
echo ""
echo "总大小:"
du -sh "$export_dir"
echo ""
echo "打包所有镜像:"
echo "  tar -czf kube-prometheus-images.tar.gz $export_dir/"
