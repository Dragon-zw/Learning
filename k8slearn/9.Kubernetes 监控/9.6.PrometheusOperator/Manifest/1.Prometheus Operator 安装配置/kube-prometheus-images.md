# kube-prometheus 镜像列表

## 镜像统计

kube-prometheus 总共使用 **10 个镜像**

## 详细镜像列表

### 1. Prometheus Operator
- **镜像**: `quay.io/prometheus-operator/prometheus-operator:v0.86.0`
- **仓库**: quay.io
- **Tag**: v0.86.0
- **用途**: Prometheus Operator 核心组件，管理 Prometheus、Alertmanager 等资源

### 2. Prometheus
- **镜像**: `quay.io/prometheus/prometheus:v3.6.0`
- **仓库**: quay.io
- **Tag**: v3.6.0
- **用途**: Prometheus 监控服务器，负责采集和存储时序数据

### 3. Alertmanager
- **镜像**: `quay.io/prometheus/alertmanager:v0.28.1`
- **仓库**: quay.io
- **Tag**: v0.28.1
- **用途**: 告警管理器，处理 Prometheus 发送的告警

### 4. Node Exporter
- **镜像**: `quay.io/prometheus/node-exporter:v1.9.1`
- **仓库**: quay.io
- **Tag**: v1.9.1
- **用途**: 节点监控导出器，采集节点级别的系统指标

### 5. Kube State Metrics
- **镜像**: `registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.17.0`
- **仓库**: registry.k8s.io
- **Tag**: v2.17.0
- **用途**: Kubernetes 状态指标导出器，暴露集群资源状态

### 6. Grafana
- **镜像**: `grafana/grafana:12.2.0`
- **仓库**: docker.io (默认)
- **Tag**: 12.2.0
- **用途**: 可视化仪表板，展示监控数据

### 7. Prometheus Adapter
- **镜像**: `registry.k8s.io/prometheus-adapter/prometheus-adapter:v0.12.0`
- **仓库**: registry.k8s.io
- **Tag**: v0.12.0
- **用途**: 自定义指标 API 适配器，支持 HPA 基于自定义指标扩缩容

### 8. Blackbox Exporter
- **镜像**: `quay.io/prometheus/blackbox-exporter:v0.27.0`
- **仓库**: quay.io
- **Tag**: v0.27.0
- **用途**: 黑盒监控导出器，用于探测 HTTP、TCP、ICMP 等服务

### 9. Kube RBAC Proxy
- **镜像**: `quay.io/brancz/kube-rbac-proxy:v0.20.0`
- **仓库**: quay.io
- **Tag**: v0.20.0
- **用途**: RBAC 代理，为指标端点提供认证和授权

### 10. ConfigMap Reload
- **镜像**: `ghcr.io/jimmidyson/configmap-reload:v0.15.0`
- **仓库**: ghcr.io (GitHub Container Registry)
- **Tag**: v0.15.0
- **用途**: ConfigMap 热重载工具，监控配置变化并触发重载

## 镜像仓库分布

| 仓库 | 镜像数量 | 镜像列表 |
|------|---------|---------|
| quay.io | 6 | prometheus-operator, prometheus, alertmanager, node-exporter, blackbox-exporter, kube-rbac-proxy |
| registry.k8s.io | 2 | kube-state-metrics, prometheus-adapter |
| docker.io | 1 | grafana |
| ghcr.io | 1 | configmap-reload |

## 镜像拉取脚本

```bash
#!/bin/bash

# kube-prometheus 镜像列表
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

# 拉取所有镜像
for image in "${images[@]}"; do
  echo "拉取镜像: $image"
  docker pull "$image"
done

echo "所有镜像拉取完成！"
```

## 镜像导出和导入脚本

### 导出镜像
```bash
#!/bin/bash

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

mkdir -p kube-prometheus-images

for image in "${images[@]}"; do
  filename=$(echo "$image" | tr '/:' '_')
  echo "导出镜像: $image -> ${filename}.tar"
  docker save "$image" -o "kube-prometheus-images/${filename}.tar"
done

echo "所有镜像已导出到 kube-prometheus-images/ 目录"
```

### 导入镜像
```bash
#!/bin/bash

for tar_file in kube-prometheus-images/*.tar; do
  echo "导入镜像: $tar_file"
  docker load -i "$tar_file"
done

echo "所有镜像导入完成！"
```

## 镜像推送到私有仓库

```bash
#!/bin/bash

# 设置私有仓库地址
PRIVATE_REGISTRY="your-registry.com"

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

for image in "${images[@]}"; do
  # 提取镜像名称和标签
  image_name=$(echo "$image" | awk -F'/' '{print $NF}')
  
  # 打标签
  new_image="${PRIVATE_REGISTRY}/${image_name}"
  echo "打标签: $image -> $new_image"
  docker tag "$image" "$new_image"
  
  # 推送到私有仓库
  echo "推送镜像: $new_image"
  docker push "$new_image"
done

echo "所有镜像已推送到私有仓库！"
```

## 版本信息

- **kube-prometheus 版本**: 基于 manifests 目录分析
- **Kubernetes 兼容性**: 建议 v1.21+
- **生成日期**: 2025-11-09
