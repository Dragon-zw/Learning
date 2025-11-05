前面的章节中我们学习了用自定义的方式来对 Kubernetes 集群进行监控，基本上也能够完成监控报警的需求了（也可以使用 VM[VictoriaMetrics] 来代替 Prometheus 的使用 ）。但实际上对上 Kubernetes 来说，还有更简单方式来监控报警，那就是 [Prometheus Operator](https://prometheus-operator.dev/)。Prometheus Operator 为监控 Kubernetes 资源和 Prometheus 实例的管理提供了简单的定义，简化在 Kubernetes 上部署、管理和运行 Prometheus 和 Alertmanager 集群。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734344323308-7fc035d6-1333-477f-86bd-556281108f4b.png)

:::color2
需要将之前自定义的原生方式部署的 Prometheus 环境清理掉

:::

```shell
$ kubectl scale deployment -n monitor --replicas=0 --all
deployment.apps/alertmanager scaled
deployment.apps/grafana scaled
deployment.apps/prometheus scaled
deployment.apps/redis scaled

$ kubectl delete daemonset -n monitor node-exporter
```

## 1 Prometheus Operator 介绍
Prometheus Operator 为 Kubernetes 提供了对 Prometheus 机器相关监控组件的本地部署和管理方案，该项目的目的是为了简化和自动化基于 Prometheus 的监控栈配置，主要包括以下几个功能：

+ Kubernetes 自定义资源：使用 Kubernetes CRD 来部署和管理 Prometheus、Alertmanager 和相关组件。
+ 简化的部署配置：直接通过 Kubernetes 资源清单配置 Prometheus，比如版本、持久化、副本、保留策略等等配置。
+ Prometheus 监控目标配置：基于熟知的 Kubernetes 标签查询自动生成监控目标配置，无需学习 Prometheus 特地的配置。

首先我们先来了解下 Prometheus Operator 的架构图：

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734344332375-a801e335-ba0b-4fc3-831c-2415e3a3a679.png)

上图是 Prometheus-Operator 官方提供的架构图，各组件以不同的方式运行在 Kubernetes 集群中，其中 Operator 是最核心的部分，作为一个控制器，他会去创建 Prometheus、ServiceMonitor、AlertManager 以及 PrometheusRule 等 CRD 资源对象，然后会一直 Watch 并维持这些资源对象的状态。

在最新版本的 Operator 中提供了一下几个 CRD 资源对象：

+ `<font style="color:#DF2A3F;">Prometheus</font>`
+ `<font style="color:#DF2A3F;">Alertmanager</font>`
+ `<font style="color:#DF2A3F;">ServiceMonitor</font>`
+ `<font style="color:#DF2A3F;">PodMonitor</font>`
+ `<font style="color:#DF2A3F;">Probe</font>`
+ `<font style="color:#DF2A3F;">ThanosRuler</font>`
+ `<font style="color:#DF2A3F;">PrometheusRule</font>`
+ `<font style="color:#DF2A3F;">AlertmanagerConfig</font>`

###  1 Prometheus
该 CRD 声明定义了 Prometheus 期望在 Kubernetes 集群中运行的配置，提供了配置选项来配置副本、持久化、报警实例等。

对于每个 Prometheus CRD 资源，Operator 都会以 StatefulSet 形式在相同的命名空间下部署对应配置的资源，Prometheus Pod 的配置是通过一个包含 Prometheus 配置的名为 `<font style="color:#DF2A3F;"><prometheus-name></font>` 的 Secret 对象声明挂载的。

该 CRD 根据标签选择来指定部署的 Prometheus 实例应该覆盖哪些 `<font style="color:#DF2A3F;">ServiceMonitors</font>`，然后 Operator 会根据包含的 ServiceMonitors 生成配置，并在包含配置的 Secret 中进行更新。

如果未提供对 `<font style="color:#DF2A3F;">ServiceMonitor</font>` 的选择，则 Operator 会将 Secret 的管理留给用户，这样就可以提供自定义配置，同时还能享受 Operator 管理 Operator 的设置能力。

### 2 Alertmanager
该 CRD 定义了在 Kubernetes 集群中运行的 Alertmanager 的配置，同样提供了多种配置，包括持久化存储。

对于每个 Alertmanager 资源，Operator 都会在相同的命名空间中部署一个对应配置的 StatefulSet，Alertmanager Pods 被配置为包含一个名为 `<font style="color:#DF2A3F;"><alertmanager-name></font>` 的 Secret，该 Secret 以 `<font style="color:#DF2A3F;">alertmanager.yaml</font>` 为 key 的方式保存使用的配置文件。

当有两个或更多配置的副本时，Operator 会在**<font style="color:#DF2A3F;">高可用</font>**模式下运行 Alertmanager 实例。

### 3 ThanosRuler
该 CRD 定义了一个 `<font style="color:#DF2A3F;">Thanos Ruler</font>` 组件的配置，以方便在 Kubernetes 集群中运行。通过 Thanos Ruler，可以跨多个 Prometheus 实例处理记录和警报规则。

一个 ThanosRuler 实例至少需要一个 `<font style="color:#DF2A3F;">queryEndpoint</font>`，它指向 `<font style="color:#DF2A3F;">Thanos Queriers</font>` 或 Prometheus 实例的位置。`<font style="color:#DF2A3F;">queryEndpoints</font>` 用于配置 Thanos 运行时的 `<font style="color:#DF2A3F;">--query</font>` 参数，更多信息也可以在 [Thanos 文档](https://prometheus-operator.dev/docs/operator/design/thanos.md)中找到。

### 4 ServiceMonitor
该 CRD 定义了如何监控一组动态的服务，使用标签选择来定义哪些 Service 被选择进行监控。这可以让团队制定一个如何暴露监控指标的规范，然后按照这些规范自动发现新的服务，而无需重新配置。

为了让 Prometheus 监控 Kubernetes 内的任何应用，需要存在一个 Endpoints 对象，Endpoints 对象本质上是 IP 地址的列表，通常 Endpoints 对象是由 Service 对象来自动填充的，Service 对象通过标签选择器匹配 Pod，并将其添加到 Endpoints 对象中。一个 Service 可以暴露一个或多个端口，这些端口由多个 Endpoints 列表支持，这些端点一般情况下都是指向一个 Pod。

Prometheus Operator 引入的这个 ServiceMonitor 对象就会发现这些 Endpoints 对象，并配置 Prometheus 监控这些 Pod。`<font style="color:#DF2A3F;">ServiceMonitorSpec</font>` 的 endpoints 部分就是用于配置这些 Endpoints 的哪些端口将被 scrape 指标的。

注意：endpoints（小写）是 ServiceMonitor CRD 中的字段，而 Endpoints（大写）是 Kubernetes 的一种对象。

ServiceMonitors 以及被发现的目标都可以来自任何命名空间，这对于允许跨命名空间监控的场景非常重要。使用 `<font style="color:#DF2A3F;">PrometheusSpec</font>` 的 `<font style="color:#DF2A3F;">ServiceMonitorNamespaceSelector</font>`，可以限制各自的 Prometheus 服务器选择的 ServiceMonitors 的命名空间。使用 `<font style="color:#DF2A3F;">ServiceMonitorSpec</font>` 的 `<font style="color:#DF2A3F;">namespaceSelector</font>`，可以限制 Endpoints 对象被允许从哪些命名空间中发现，要在所有命名空间中发现目标，`<font style="color:#DF2A3F;">namespaceSelector</font>` 必须为空：

```yaml
spec:
  namespaceSelector:
    any: true
```

### 5 PodMonitor
该 CRD 用于定义如何监控一组动态 pods，使用标签选择来定义哪些 pods 被选择进行监控。同样团队中可以制定一些规范来暴露监控的指标。

Pod 是一个或多个容器的集合，可以在一些端口上暴露 Prometheus 指标。

由 Prometheus Operator 引入的 PodMonitor 对象会发现这些 Pod，并为 Prometheus 服务器生成相关配置，以便监控它们。

`<font style="color:#DF2A3F;">PodMonitorSpec</font>` 中的 `<font style="color:#DF2A3F;">PodMetricsEndpoints</font>` 部分，用于配置 Pod 的哪些端口将被 scrape 指标，以及使用哪些参数。

PodMonitors 和发现的目标可以来自任何命名空间，这同样对于允许跨命名空间的监控用例是很重要的。使用 `<font style="color:#DF2A3F;">PodMonitorSpec</font>` 的 `<font style="color:#DF2A3F;">namespaceSelector</font>`，可以限制 Pod 被允许发现的命名空间，要在所有命名空间中发现目标，`<font style="color:#DF2A3F;">namespaceSelector</font>` 必须为空：

```yaml
spec:
  namespaceSelector:
    any: true
```

`<font style="color:#DF2A3F;">PodMonitor</font>` 和 `<font style="color:#DF2A3F;">ServieMonitor</font>` 最大的区别就是不需要有对应的 Service。

### 6 Probe
该 CRD 用于定义如何监控一组 Ingress 和静态目标。除了 target 之外，`<font style="color:#DF2A3F;">Probe</font>` 对象还需要一个 `<font style="color:#DF2A3F;">prober</font>`，它是监控的目标并为 Prometheus 提供指标的服务。例如可以通过使用 [blackbox-exporter](https://github.com/prometheus/blackbox_exporter/) 来提供这个服务。

### 7 PrometheusRule
用于配置 Prometheus 的 Rule 规则文件，包括 recording rules 和 alerting，可以自动被 Prometheus 加载。

### 8 AlertmanagerConfig
在以前的版本中要配置 Alertmanager 都是通过 Configmap 来完成的，在 v0.43 版本后新增该 CRD，可以将 Alertmanager 的配置分割成不同的子对象进行配置，允许将报警路由到自定义 Receiver 上，并配置抑制规则。

`<font style="color:#DF2A3F;">AlertmanagerConfig</font>` 可以在命名空间级别上定义，为 Alertmanager 提供一个聚合的配置。这里提供了一个如何使用它的[例子](https://prometheus-operator.dev/docs/operator/example/user-guides/alerting/alertmanager-config-example.yaml)。不过需要注意这个 CRD 还不稳定。

这样我们要在集群中监控什么数据，就变成了直接去操作 Kubernetes 集群的资源对象了，是这样比之前手动的方式就方便很多了。

## 2 安装 Prometheus-Operator
为了使用 Prometheus-Operator，这里我们直接使用 [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus.git) 这个项目来进行安装，该项目和 Prometheus-Operator 的区别就类似于 Linux 内核和 CentOS/Ubuntu 这些发行版的关系，真正起作用的是 Operator 去实现的，而 kube-prometheus 只是利用 Operator 编写了一系列常用的监控资源清单。不过需要注意 Kubernetes 版本和 `<font style="color:#DF2A3F;">kube-prometheus</font>` 的兼容：

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734344349704-b30c0f76-042f-466b-bd37-4b8acb3ad656.png)

我们可以直接使用 `<font style="color:#DF2A3F;">kube-prometheus</font>` 的 [Helm Charts](https://prometheus-community.github.io/helm-charts/) 来进行快速安装，也可以直接手动安装。

首先 clone 项目代码，我们这里直接使用默认的 `<font style="color:#DF2A3F;">main</font>` 分支即可：

```shell
$ git clone https://github.com/prometheus-operator/kube-prometheus.git
$ cd kube-prometheus
```

首先创建需要的命名空间和 CRDs，等待它们可用后再创建其余资源：

```shell
$ kubectl apply -f manifests/setup
customresourcedefinition.apiextensions.k8s.io/alertmanagerconfigs.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/alertmanagers.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/podmonitors.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/probes.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/prometheusrules.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/servicemonitors.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/thanosrulers.monitoring.coreos.com created
namespace/monitoring created
The CustomResourceDefinition "prometheuses.monitoring.coreos.com" is invalid: metadata.annotations: Too long: must have at most 262144 bytes
```

可以看到安装过程中会提示 `<font style="color:#DF2A3F;">Too long: must have at most 262144 bytes</font>`，只需要将 `<font style="color:#DF2A3F;">kubectl apply</font>` 改成 `<font style="color:#DF2A3F;">kubectl create</font>` 即可：

```shell
$ kubectl create -f manifests/setup
customresourcedefinition.apiextensions.k8s.io/alertmanagerconfigs.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/alertmanagers.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/podmonitors.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/probes.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/prometheuses.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/prometheusagents.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/prometheusrules.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/scrapeconfigs.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/servicemonitors.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/thanosrulers.monitoring.coreos.com created
namespace/monitoring created

$ kubectl get crd | grep coreos
alertmanagerconfigs.monitoring.coreos.com             2025-11-05T04:02:27Z
alertmanagers.monitoring.coreos.com                   2025-11-05T04:02:28Z
podmonitors.monitoring.coreos.com                     2025-11-05T04:02:28Z
probes.monitoring.coreos.com                          2025-11-05T04:02:28Z
prometheusagents.monitoring.coreos.com                2025-11-05T04:02:29Z
prometheuses.monitoring.coreos.com                    2025-11-05T04:02:28Z
prometheusrules.monitoring.coreos.com                 2025-11-05T04:02:29Z
scrapeconfigs.monitoring.coreos.com                   2025-11-05T04:02:30Z
servicemonitors.monitoring.coreos.com                 2025-11-05T04:02:30Z
thanosrulers.monitoring.coreos.com                    2025-11-05T04:02:30Z
```

这会创建一个名为 `<font style="color:#DF2A3F;">monitoring</font>` 的命名空间，以及相关的 CRD 资源对象声明。前面章节中我们讲解过 CRD 和 Operator 的使用，当我们声明完 CRD 过后，就可以来自定义资源清单了，但是要让我们声明的自定义资源对象生效就需要安装对应的 Operator 控制器，在 `<font style="color:#DF2A3F;">manifests</font>` 目录下面就包含了 Operator 的资源清单以及各种监控对象声明，比如 Prometheus、Alertmanager 等，直接应用即可：

```shell
$ kubectl create -f manifests/
```

不过需要注意有一些资源的镜像来自于 `<font style="color:#DF2A3F;">k8s.gcr.io</font>`，如果不能正常拉取，则可以将镜像替换成可拉取的：

+ `<font style="color:#DF2A3F;">prometheusAdapter-deployment.yaml</font>`：将 `<font style="color:#DF2A3F;">image: k8s.gcr.io/prometheus-adapter/prometheus-adapter:v0.9.1</font>` 替换为 `<font style="color:#DF2A3F;">cnych/prometheus-adapter:v0.9.1</font>`
+ `<font style="color:#DF2A3F;">kubeStateMetrics-deployment.yaml</font>`：将 `<font style="color:#DF2A3F;">image: k8s.gcr.io/kube-state-metrics/kube-state-metrics:v2.4.2</font>`<font style="color:#DF2A3F;"> </font>替换为 `<font style="color:#DF2A3F;">cnych/kube-state-metrics:v2.4.2</font>`

这会自动安装 prometheus-operator、node-exporter、kube-state-metrics、grafana、prometheus-adapter 以及 prometheus 和 alertmanager 等大量组件，如果没成功可以多次执行上面的安装命令。

```shell
# 查看 Pods 的信息
$ kubectl get pods -n monitoring -o wide 
NAME                                   READY   STATUS    RESTARTS   AGE     IP               NODE             NOMINATED NODE   READINESS GATES
alertmanager-main-0                    2/2     Running   0          115s    192.244.51.255   hkk8snode002     <none>           <none>
alertmanager-main-1                    2/2     Running   0          115s    192.244.22.194   hkk8smaster001   <none>           <none>
alertmanager-main-2                    2/2     Running   0          115s    192.244.211.42   hkk8snode001     <none>           <none>
blackbox-exporter-5cd8f5bc69-t8sxs     3/3     Running   0          3m15s   192.244.211.39   hkk8snode001     <none>           <none>
grafana-cd7897777-8hsrg                1/1     Running   0          3m15s   192.244.211.29   hkk8snode001     <none>           <none>
kube-state-metrics-5f58bb5c84-cvhsx    3/3     Running   0          3m15s   192.244.211.46   hkk8snode001     <none>           <none>
node-exporter-62z2l                    2/2     Running   0          3m15s   192.168.178.35   hkk8smaster001   <none>           <none>
node-exporter-bbx9q                    2/2     Running   0          3m15s   192.168.178.36   hkk8snode001     <none>           <none>
node-exporter-rr5nm                    2/2     Running   0          3m15s   192.168.178.37   hkk8snode002     <none>           <none>
prometheus-adapter-5bf6df9595-46v2h    1/1     Running   0          3m15s   192.244.211.60   hkk8snode001     <none>           <none>
prometheus-adapter-5bf6df9595-9dbnn    1/1     Running   0          3m15s   192.244.51.235   hkk8snode002     <none>           <none>
prometheus-k8s-0                       2/2     Running   0          115s    192.244.211.21   hkk8snode001     <none>           <none>
prometheus-k8s-1                       2/2     Running   0          115s    192.244.51.231   hkk8snode002     <none>           <none>
prometheus-operator-7f66959d7c-ghsmx   2/2     Running   0          3m15s   192.244.211.56   hkk8snode001     <none>           <none>

# 查看 Service 的信息
$ kubectl get svc -n monitoring
NAME                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
alertmanager-main       ClusterIP   192.96.40.200    <none>        9093/TCP,8080/TCP            4m18s
alertmanager-operated   ClusterIP   None             <none>        9093/TCP,9094/TCP,9094/UDP   2m52s
blackbox-exporter       ClusterIP   192.96.106.203   <none>        9115/TCP,19115/TCP           4m18s
grafana                 ClusterIP   192.96.70.155    <none>        3000/TCP                     4m16s
kube-state-metrics      ClusterIP   None             <none>        8443/TCP,9443/TCP            4m15s
node-exporter           ClusterIP   None             <none>        9100/TCP                     4m14s
prometheus-adapter      ClusterIP   192.96.4.13      <none>        443/TCP                      4m13s
prometheus-k8s          ClusterIP   192.96.167.78    <none>        9090/TCP,8080/TCP            4m14s
prometheus-operated     ClusterIP   None             <none>        9090/TCP                     2m51s
prometheus-operator     ClusterIP   None             <none>        8443/TCP                     4m13s
```

可以看到上面针对 Grafana、Alertmanager 和 Prometheus 都创建了一个类型为 ClusterIP 的 Service，当然如果我们想要在外网访问这两个服务的话可以通过创建对应的 Ingress 对象或者使用 NodePort 类型的 Service，我们这里为了简单，直接使用 NodePort 类型的服务即可，编辑 `<font style="color:#DF2A3F;">grafana</font>`、`<font style="color:#DF2A3F;">alertmanager-main</font>` 和 `<font style="color:#DF2A3F;">prometheus-k8s</font>` 这 3 个 Service，将服务类型更改为 `<font style="color:#DF2A3F;">NodePort</font>`:

```shell
# 将 type: ClusterIP 更改为 type: NodePort
$ kubectl edit service grafana -n monitoring
$ kubectl edit service alertmanager-main -n monitoring
$ kubectl edit service prometheus-k8s -n monitoring

# 使用 patch 的方式将 ClusterIP 改为 NodePort
$ kubectl patch service grafana -n monitoring --type='json' -p='[{"op":"replace","path":"/spec/type","value":"NodePort"}]'
$ kubectl patch service alertmanager-main -n monitoring --type='json' -p='[{"op":"replace","path":"/spec/type","value":"NodePort"}]'
$ kubectl patch service prometheus-k8s -n monitoring --type='json' -p='[{"op":"replace","path":"/spec/type","value":"NodePort"}]'

$ kubectl get svc -n monitoring
NAME                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                         AGE
alertmanager-main       NodePort    10.102.174.254   <none>        9093:32660/TCP,8080:31615/TCP   45m
grafana                 NodePort    10.105.33.193    <none>        3000:31837/TCP                  45m
prometheus-k8s          NodePort    10.109.250.233   <none>        9090:31664/TCP,8080:31756/TCP   45m
[......]
```

<details class="lake-collapse"><summary id="u72de4786"><span class="ne-text">配置 Ingress-Nginx 的方式访问</span></summary><pre data-language="yaml" id="K8ff3" class="ne-codeblock language-yaml"><code># Ingress-prometheus-operator.yaml</code></pre><p id="uf9a3aa08" class="ne-p"><span class="ne-text">引用资源清单文件</span></p><span id="dTaLP"></span></details>
更改完成后，我们就可以通过上面的 NodePort 去访问对应的服务了，比如查看 prometheus 的服务发现页面：

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734344324445-99f21e3b-aed5-4ef0-bde2-ec6232cbfabc.png)

可以看到已经监控上了很多指标数据了，上面我们可以看到 Prometheus 是两个副本，我们这里通过 Service 去访问，按正常来说请求是会去轮询访问后端的两个 Prometheus 实例的，但实际上我们这里访问的时候始终是路由到后端的一个实例上去，因为这里的 Service 在创建的时候添加了 `sessionAffinity: ClientIP` 这样的属性，会根据 `ClientIP` 来做 session 亲和性，所以我们不用担心请求会到不同的副本上去：

```yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/component: prometheus
    app.kubernetes.io/instance: k8s
    app.kubernetes.io/name: prometheus
    app.kubernetes.io/part-of: kube-prometheus
    app.kubernetes.io/version: 2.35.0
  name: prometheus-k8s
  namespace: monitoring
spec:
  ports:
    - name: web
      port: 9090
      targetPort: web
    - name: reloader-web
      port: 8080
      targetPort: reloader-web
  type: NodePort
  selector:
    app.kubernetes.io/component: prometheus
    app.kubernetes.io/instance: k8s
    app.kubernetes.io/name: prometheus
    app.kubernetes.io/part-of: kube-prometheus
  sessionAffinity: ClientIP
```

为什么会担心请求会到不同的副本上去呢？正常多副本应该是看成高可用的常用方案，理论上来说不同副本本地的数据是一致的，但是需要注意的是 Prometheus 的主动 Pull 拉取监控指标的方式，由于抓取时间不能完全一致，即使一致也不一定就能保证网络没什么问题，所以最终不同副本下存储的数据很大可能是不一样的，所以这里我们配置了 session 亲和性，可以保证我们在访问数据的时候始终是一致的。

## 配置
我们可以看到上面的监控指标大部分的配置都是正常的，只有两三个没有管理到对应的监控目标，比如 `kube-controller-manager` 和 `kube-scheduler` 这两个系统组件。

这其实就和 `ServiceMonitor` 的定义有关系了，我们先来查看下 kube-scheduler 组件对应的 ServiceMonitor 资源的定义，`manifests/kubernetesControlPlane-serviceMonitorKubeScheduler.yaml`：

```yaml
# kubernetesControlPlane-serviceMonitorKubeScheduler.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    app.kubernetes.io/name: kube-scheduler
    app.kubernetes.io/part-of: kube-prometheus
  name: kube-scheduler
  namespace: monitoring
spec:
  endpoints:
    - bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
      interval: 30s # 每30s获取一次信息
      port: https-metrics # 对应 service 的端口名
      scheme: https # 注意是使用 https 协议
      tlsConfig:
        insecureSkipVerify: true # 跳过安全校验
  jobLabel: app.kubernetes.io/name # 用于从中检索任务名称的标签
  namespaceSelector: # 表示去匹配某一命名空间中的 Service，如果想从所有的namespace中匹配用any:true
    matchNames:
      - kube-system
  selector: # 匹配的 Service 的 labels，如果使用 mathLabels，则下面的所有标签都匹配时才会匹配该 service，如果使用 matchExpressions，则至少匹配一个标签的 service 都会被选择
    matchLabels:
      app.kubernetes.io/name: kube-scheduler
```

上面是一个典型的 `ServiceMonitor` 资源对象的声明方式，通过 `selector.matchLabels` 在 `kube-system` 这个命名空间下面匹配具有 `app.kubernetes.io/name=kube-scheduler` 这样的 Service，但是我们系统中根本就没有对应的 Service：

```shell
$ kubectl get svc -n kube-system -l app.kubernetes.io/name=kube-scheduler
No resources found in kube-system namespace.
```

所以我们需要去创建一个对应的 Service 对象，才能与 `ServiceMonitor` 进行关联：

```yaml
apiVersion: v1
kind: Service
metadata:
  namespace: kube-system
  name: kube-scheduler
  labels: # 必须和上面的 ServiceMonitor 下面的 matchLabels 保持一致
    app.kubernetes.io/name: kube-scheduler
spec:
  selector:
    component: kube-scheduler
  ports:
    - name: https-metrics
      port: 10259
      targetPort: 10259 # 需要注意现在版本默认的安全端口是10259
```

其中最重要的是上面 labels 和 selector 部分，labels 区域的配置必须和我们上面的 ServiceMonitor 对象中的 selector 保持一致，selector 下面配置的是 `component=kube-scheduler`，为什么会是这个 label 标签呢，我们可以去 describe 下 kube-scheduler 这个 Pod：

```shell
$ kubectl describe pod kube-scheduler-master1 -n kube-system
Name:                 kube-scheduler-master1
Namespace:            kube-system
Priority:             2000001000
Priority Class Name:  system-node-critical
Node:                 master1/192.168.0.106
Start Time:           Tue, 17 May 2022 15:15:43 +0800
Labels:               component=kube-scheduler
                      tier=control-plane
......
```

我们可以看到这个 Pod 具有 `component=kube-scheduler` 和 `tier=control-plane` 这两个标签，而前面这个标签具有更唯一的特性，所以使用前面这个标签较好，这样上面创建的 Service 就可以和我们的 Pod 进行关联了，直接应用即可：

```shell
$ kubectl apply -f manifests/kubernetesControlPlane-serviceMonitorKubeScheduler.yaml
$ kubectl get svc -n kube-system -l app.kubernetes.io/name=kube-scheduler
NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)     AGE
kube-scheduler   ClusterIP   10.103.236.75   <none>        10259/TCP   5m9s
```

创建完成后，隔一小会儿后去 Prometheus 页面上查看 targets 下面 kube-scheduler 已经有采集的目标了，但是报了 `connect: connection refused` 这样的错误：

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734344324398-ff78950e-5822-4a22-98ea-e2a697a5f513.png)

这是因为 kube-scheduler 启动的时候默认绑定的是 `127.0.0.1` 地址，所以要通过 IP 地址去访问就被拒绝了，我们可以查看 master 节点上的静态 Pod 资源清单来确认这一点：

```yaml
# /etc/kubernetes/manifests/kube-scheduler.yaml
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    component: kube-scheduler
    tier: control-plane
  name: kube-scheduler
  namespace: kube-system
spec:
  containers:
  - command:
    - kube-scheduler
    - --authentication-kubeconfig=/etc/kubernetes/scheduler.conf
    - --authorization-kubeconfig=/etc/kubernetes/scheduler.conf
    - --bind-address=127.0.0.1  # 绑定了127.0.0.1
    - --kubeconfig=/etc/kubernetes/scheduler.conf
    - --leader-elect=true
    - --port=0  # 如果为0，则不提供 HTTP 服务，--secure-port 默认值：10259，通过身份验证和授权为 HTTPS 服务的端口，如果为 0，则不提供 HTTPS。
......
```

我们可以直接将上面的 `--bind-address=127.0.0.1` 更改为 `--bind-address=0.0.0.0` 即可，更改后 kube-scheduler 会自动重启，重启完成后再去查看 Prometheus 上面的采集目标就正常了。

可以用同样的方式来修复下 kube-controller-manager 组件的监控，创建一个如下所示的 Service 对象，只是端口改成 10257：

```yaml
# kubernetesControlPlane-serviceMonitorKubeControllerManager
apiVersion: v1
kind: Service
metadata:
  namespace: kube-system
  name: kube-controller-manager
  labels:
    app.kubernetes.io/name: kube-controller-manager
spec:
  selector:
    component: kube-controller-manager
  ports:
    - name: https-metrics
      port: 10257
      targetPort: 10257 # controller-manager 的安全端口为10257
```

然后将 kube-controller-manager 静态 Pod 的资源清单文件中的参数 `--bind-address=127.0.0.1` 更改为 `--bind-address=0.0.0.0`。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734344351164-62706b43-2afc-4481-bc99-9503818c634f.png)

上面的监控数据配置完成后，我们就可以去查看下 Grafana 下面的监控图表了，同样使用上面的 NodePort 访问即可，第一次登录使用 `admin:admin` 登录即可，进入首页后，我们可以发现其实 Grafana 已经有很多配置好的监控图表了。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734344351816-ce49fd74-83b6-45af-8db5-0c7f27e21205.png)

我们可以随便选择一个 Dashboard 查看监控图表信息。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734344352916-ea07f1de-d3d4-4267-be75-82094e80badf.png)

接下来我们再来学习如何完全自定义一个 `ServiceMonitor` 以及其他的相关配置。

如果要清理 Prometheus-Operator，可以直接删除对应的资源清单即可：

```shell
$ kubectl delete -f manifests/
$ kubectl delete -f manifests/setup/
```

