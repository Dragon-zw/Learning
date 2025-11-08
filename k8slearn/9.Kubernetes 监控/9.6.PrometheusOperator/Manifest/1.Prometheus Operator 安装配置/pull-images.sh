#!/bin/bash

echo "=== kube-prometheus 镜像拉取脚本 ==="
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

total=${#images[@]}
current=0

echo "总共需要拉取 $total 个镜像"
echo ""

# 拉取所有镜像
for image in "${images[@]}"; do
  current=$((current + 1))
  echo "[$current/$total] 拉取镜像: $image"
  
  if docker pull "$image"; then
    echo "  ✓ 成功"
  else
    echo "  ✗ 失败"
  fi
  echo ""
done

echo "=== 完成 ==="
echo ""
echo "检查已拉取的镜像:"
docker images | grep -E "prometheus|grafana|kube-state-metrics|configmap-reload|kube-rbac-proxy"
