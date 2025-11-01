<font style="color:rgb(28, 30, 33);">在前面的学习中我们使用了一个 </font>`<font style="color:#DF2A3F;">kubectl scale</font>`<font style="color:rgb(28, 30, 33);"> 命令可以来实现 Pod 的扩缩容功能，但是这个是完全手动操作的，要应对线上的各种复杂情况，我们需要能够做到自动化去感知业务，来自动进行扩缩容。为此，Kubernetes 也为我们提供了这样的一个资源对象：</font>`<font style="color:#DF2A3F;">Horizontal Pod Autoscaling（Pod 水平自动伸缩）</font>`<font style="color:#DF2A3F;">，简称 </font>`<font style="color:#DF2A3F;">HPA</font>`<font style="color:rgb(28, 30, 33);">，HPA 通过监控分析一些控制器控制的所有 Pod 的负载变化情况来确定是否需要调整 Pod 的副本数量，这是 HPA 最基本的原理：</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1730551401222-6dfcd499-123b-4f69-8c25-289023e0f78b.png)

<font style="color:rgb(28, 30, 33);">我们可以简单的通过 </font>`<font style="color:#DF2A3F;">kubectl autoscale</font>`<font style="color:rgb(28, 30, 33);"> 命令来创建一个 HPA 资源对象，</font>`<font style="color:#DF2A3F;">HPA Controller</font>`<font style="color:rgb(28, 30, 33);"> 默认</font>`<font style="color:#DF2A3F;">30s</font>`<font style="color:rgb(28, 30, 33);">轮询一次（可通过 </font>`<font style="color:#DF2A3F;">kube-controller-manager</font>`<font style="color:rgb(28, 30, 33);"> 的</font>`<font style="color:#DF2A3F;">--horizontal-pod-autoscaler-sync-period</font>`<font style="color:rgb(28, 30, 33);"> 参数进行设置），查询指定的资源中的 Pod 资源使用率，并且与创建时设定的值和指标做对比，从而实现自动伸缩的功能。</font>

---

> Public Reference：
>
> 概念：[https://kubernetes.io/zh/docs/tasks/run-application/horizontal-pod-autoscale/#scaling-policies](https://kubernetes.io/zh/docs/tasks/run-application/horizontal-pod-autoscale/#scaling-policies)
>
> 实战：[https://kubernetes.io/zh/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/](https://kubernetes.io/zh/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/)
>

<font style="color:rgb(0, 0, 0);">Pod 自动扩容：可以根据 CPU/Memory 使用率或自定义指标（metrics）自动对 Pod 进行扩/缩容。</font>

<font style="color:rgb(0, 0, 0);">控制管理器每隔</font>`<font style="color:#DF2A3F;">30s</font>`<font style="color:rgb(0, 0, 0);">（可以通过</font>`<font style="color:#DF2A3F;">-horizontal-pod-autoscaler-sync-period</font>`<font style="color:rgb(0, 0, 0);">修改）查询</font>`<font style="color:#DF2A3F;">metrics</font>`<font style="color:rgb(0, 0, 0);">的资源使用情况[ 默认大于30s，只有检测到资源的变动后才会实现扩容|缩容 ]</font>

<font style="color:rgb(0, 0, 0);">支持三种</font>`<font style="color:#DF2A3F;">metrics</font>`<font style="color:rgb(0, 0, 0);">类型：</font>

+ <font style="color:rgb(0, 0, 0);">预定义metrics（比如Pod的CPU）以利用率的方式计算</font>
+ <font style="color:rgb(0, 0, 0);">自定义的 Pod metrics，以原始值（raw value）的方式计算</font>
+ <font style="color:rgb(0, 0, 0);">自定义的 Object metrics（通过应用程序暴露指标）</font>

<font style="color:rgb(0, 0, 0);">支持两种</font>`<font style="color:#DF2A3F;">metrics</font>`<font style="color:rgb(0, 0, 0);">查询方式：</font>

+ <font style="color:rgb(0, 0, 0);">Heapster</font>
+ <font style="color:rgb(0, 0, 0);">自定义的 REST API</font>

<font style="color:rgb(0, 0, 0);">支持多metrics</font>

Pod 水平自动扩缩（Horizontal Pod Autoscaler） 可以基于 CPU 利用率自动扩缩 ReplicationController、Deployment、ReplicaSet 和 StatefulSet 中的 Pod 数量。 除了 CPU 利用率，也可以基于其他应程序提供的 [自定义度量指标](https://git.k8s.io/community/contributors/design-proposals/instrumentation/custom-metrics-api.md) 来执行自动扩缩。 Pod 自动扩缩不适用于无法扩缩的对象，比如 DaemonSet。

Pod 水平自动扩缩特性由 Kubernetes API 资源和控制器实现。资源决定了控制器的行为。 控制器会周期性地调整副本控制器或 Deployment 中的副本数量，以使得类似 Pod 平均 CPU 利用率、平均内存利用率这类观测到的度量值与用户所设定的目标值匹配。

## <font style="color:rgb(28, 30, 33);">1 Metrics Server</font>
<font style="color:rgb(28, 30, 33);">在 HPA 的第一个版本中，我们需要 </font>`<font style="color:#DF2A3F;">Heapster</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">提供 CPU 和内存指标，在 HPA v2 过后就需要安装 Metrcis Server 了，</font>`<font style="color:#DF2A3F;">Metrics Server</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">可以通过标准的 Kubernetes API 把监控数据暴露出来，有了 </font>`<font style="color:#DF2A3F;">Metrics Server</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">之后，我们就完全可以通过标准的 Kubernetes API 来访问我们想要获取的监控数据了：</font>

```shell
https://10.96.0.1/apis/metrics.k8s.io/v1beta1/namespaces/<namespace-name>/pods/<pod-name>
```

<font style="color:rgb(28, 30, 33);">比如当我们访问上面的 API 的时候，我们就可以获取到该 Pod 的资源数据，这些数据其实是来自于 kubelet 的 </font>`<font style="color:#DF2A3F;">Summary API</font>`<font style="color:rgb(28, 30, 33);"> 采集而来的。不过需要说明的是我们这里可以通过标准的 API 来获取资源监控数据，并不是因为 </font>`<font style="color:#DF2A3F;">Metrics Server</font>`<font style="color:rgb(28, 30, 33);"> 就是 APIServer 的一部分，而是通过 Kubernetes 提供的 </font>`<font style="color:#DF2A3F;">Aggregator</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">汇聚插件来实现的，是独立于 APIServer 之外运行的。</font>

![](https://cdn.nlark.com/yuque/0/2024/jpeg/2555283/1730551401149-9a45f908-34a0-4a6a-94f5-bda1528731bd.jpeg)

### <font style="color:rgb(28, 30, 33);">1.1 聚合 API</font>
`<font style="color:#DF2A3F;">Aggregator</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">允许开发人员编写一个自己的服务，把这个服务注册到 Kubernetes 的 APIServer 里面去，这样我们就可以像原生的 APIServer 提供的 API 使用自己的 API 了，我们把自己的服务运行在 Kubernetes 集群里面，然后 Kubernetes 的 </font>`<font style="color:#DF2A3F;">Aggregator</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">通过 Service 名称就可以转发到我们自己写的 Service 里面去了。这样这个聚合层就带来了很多好处：</font>

+ <font style="color:rgb(28, 30, 33);">增加了 API 的扩展性，开发人员可以编写自己的 API 服务来暴露他们想要的 API。</font>
+ <font style="color:rgb(28, 30, 33);">丰富了 API，核心 kubernetes 团队阻止了很多新的 API 提案，通过允许开发人员将他们的 API 作为单独的服务公开，这样就无须社区繁杂的审查了。</font>
+ <font style="color:rgb(28, 30, 33);">开发分阶段实验性 API，新的 API 可以在单独的聚合服务中开发，当它稳定之后，在合并会 APIServer 就很容易了。</font>
+ <font style="color:rgb(28, 30, 33);">确保新 API 遵循 Kubernetes 约定，如果没有这里提出的机制，社区成员可能会被迫推出自己的东西，这样很可能造成社区成员和社区约定不一致。</font>

### <font style="color:rgb(28, 30, 33);">1.2 安装 Metrics Server</font>
<font style="color:rgb(28, 30, 33);">所以现在我们要使用 HPA，就需要在集群中安装 </font>`<font style="color:#DF2A3F;">Metrics Server</font>`<font style="color:rgb(28, 30, 33);"> 服务，要安装 </font>`<font style="color:#DF2A3F;">Metrics Server</font>`<font style="color:rgb(28, 30, 33);"> 就需要开启 </font>`<font style="color:#DF2A3F;">Aggregator</font>`<font style="color:rgb(28, 30, 33);">，因为 </font>`<font style="color:#DF2A3F;">Metrics Server</font>`<font style="color:rgb(28, 30, 33);"> 就是通过该代理进行扩展的，不过我们 Kubernetes </font><font style="color:#DF2A3F;">集群是通过 Kubeadm 搭建的，默认已经开启了</font><font style="color:rgb(28, 30, 33);">，如果是二进制方式安装的集群，需要单独配置 kube-apsierver 添加如下所示的参数：</font>

```bash
--requestheader-client-ca-file=<path to aggregator CA cert>
--requestheader-allowed-names=aggregator
--requestheader-extra-headers-prefix=X-Remote-Extra-
--requestheader-group-headers=X-Remote-Group
--requestheader-username-headers=X-Remote-User
--proxy-client-cert-file=<path to aggregator proxy cert>
--proxy-client-key-file=<path to aggregator proxy key>
```

<font style="color:rgb(28, 30, 33);">如果 </font>`<font style="color:#DF2A3F;">kube-proxy</font>`<font style="color:rgb(28, 30, 33);"> 没有和 APIServer 运行在同一台主机上，那么需要确保启用了如下 kube-apsierver 的参数：</font>

```bash
--enable-aggregator-routing=true
```

<font style="color:rgb(28, 30, 33);">对于这些证书的生成方式，我们可以查看官方文档：</font>[<font style="color:#117CEE;">https://github.com/kubernetes-sigs/apiserver-builder-alpha/blob/master/docs/concepts/auth.md</font>](https://github.com/kubernetes-sigs/apiserver-builder-alpha/blob/master/docs/concepts/auth.md)<font style="color:rgb(28, 30, 33);">。</font>

`<font style="color:#DF2A3F;">Aggregator</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">聚合层启动完成后，就可以来安装 </font>`<font style="color:#DF2A3F;">Metrics Server</font>`<font style="color:rgb(28, 30, 33);"> 了，我们可以获取该仓库的官方安装资源清单：</font>

```shell
# 官方仓库地址：https://github.com/kubernetes-sigs/metrics-server
➜  ~ wget https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.5.1/components.yaml
```

<font style="color:rgb(28, 30, 33);">在部署之前，修改 </font>`<font style="color:#DF2A3F;">components.yaml</font>`<font style="color:rgb(28, 30, 33);"> 的镜像地址为：</font>

```yaml
hostNetwork: true # 使用hostNetwork模式
containers:
  - name: metrics-server
    image: cnych/metrics-server:v0.5.1
```

<font style="color:rgb(28, 30, 33);">等部署完成后，可以查看 Pod 日志是否正常：</font>

```shell
➜  ~ kubectl apply -f components.yaml
➜  ~ kubectl get pods -n kube-system -l k8s-app=metrics-server
NAME                              READY   STATUS    RESTARTS   AGE
metrics-server-6f667d74b6-6c9ps   0/1     Running   0          7m52s
➜  ~ manifests kubectl logs -f metrics-server-6f667d74b6-6c9ps -n kube-system
I1115 10:06:02.381541       1 serving.go:341] Generated self-signed cert (/tmp/apiserver.crt, /tmp/apiserver.key)
E1115 10:06:02.735837       1 scraper.go:139] "Failed to scrape node" err="Get \"https://192.168.31.31:10250/stats/summary?only_cpu_and_memory=true\": x509: cannot validate certificate for 192.168.31.31 because it doesn't contain any IP SANs" node="master1"
E1115 10:06:02.744967       1 scraper.go:139] "Failed to scrape node" err="Get \"https://192.168.31.108:10250/stats/summary?only_cpu_and_memory=true\": x509: cannot validate certificate for 192.168.31.108 because it doesn't contain any IP SANs" node="node1"
I1115 10:06:02.751391       1 requestheader_controller.go:169] Starting RequestHeaderAuthRequestController
I1115 10:06:02.751410       1 shared_informer.go:240] Waiting for caches to sync for RequestHeaderAuthRequestController
I1115 10:06:02.751413       1 configmap_cafile_content.go:202] Starting client-ca::kube-system::extension-apiserver-authentication::requestheader-client-ca-file
I1115 10:06:02.751397       1 configmap_cafile_content.go:202] Starting client-ca::kube-system::extension-apiserver-authentication::client-ca-file
I1115 10:06:02.751423       1 shared_informer.go:240] Waiting for caches to sync for client-ca::kube-system::extension-apiserver-authentication::requestheader-client-ca-file
I1115 10:06:02.751424       1 shared_informer.go:240] Waiting for caches to sync for client-ca::kube-system::extension-apiserver-authentication::client-ca-file
I1115 10:06:02.751473       1 dynamic_serving_content.go:130] Starting serving-cert::/tmp/apiserver.crt::/tmp/apiserver.key
I1115 10:06:02.751822       1 secure_serving.go:202] Serving securely on [::]:443
I1115 10:06:02.751896       1 tlsconfig.go:240] Starting DynamicServingCertificateController
E1115 10:06:02.756987       1 scraper.go:139] "Failed to scrape node" err="Get \"https://192.168.31.46:10250/stats/summary?only_cpu_and_memory=true\": x509: cannot validate certificate for 192.168.31.46 because it doesn't contain any IP SANs" node="node2"
I1115 10:06:02.851642       1 shared_informer.go:247] Caches are synced for client-ca::kube-system::extension-apiserver-authentication::requestheader-client-ca-file
I1115 10:06:02.851739       1 shared_informer.go:247] Caches are synced for RequestHeaderAuthRequestController
I1115 10:06:02.851748       1 shared_informer.go:247] Caches are synced for client-ca::kube-system::extension-apiserver-authentication::client-ca-file
E1115 10:06:17.742350       1 scraper.go:139] "Failed to scrape node" err="Get \"https://192.168.31.108:10250/stats/summary?only_cpu_and_memory=true\": x509: cannot validate certificate for 192.168.31.108 because it doesn't contain any IP SANs" node="node1"
[......]
```

<font style="color:rgb(28, 30, 33);">因为部署集群的时候，CA 证书并没有把各个节点的 IP 签上去，所以这里 </font>`<font style="color:#DF2A3F;">Metrics Server</font>`<font style="color:rgb(28, 30, 33);"> 通过 IP 去请求时，提示签的证书没有对应的 IP（错误：</font>`<font style="color:#DF2A3F;">x509: cannot validate certificate for 192.168.31.108 because it doesn't contain any IP SANs</font>`<font style="color:rgb(28, 30, 33);">），我们可以添加一个</font>`<font style="color:#DF2A3F;">--kubelet-insecure-tls</font>`<font style="color:rgb(28, 30, 33);">参数跳过证书校验：</font>

```bash
args:
  - --cert-dir=/tmp
  - --secure-port=443
  - --kubelet-insecure-tls
  - --kubelet-preferred-address-types=InternalIP
```

<font style="color:rgb(28, 30, 33);">然后再重新安装即可成功！可以通过如下命令来验证：</font>

```bash
➜  ~ kubectl apply -f components.yaml
➜  ~ kubectl get pods -n kube-system -l k8s-app=metrics-server
NAME                              READY   STATUS    RESTARTS   AGE
metrics-server-85499dc4f5-mgpcb   1/1     Running   0          32s
➜  ~ kubectl logs -f metrics-server-85499dc4f5-mgpcb -n kube-system
I1115 10:14:19.401808       1 serving.go:341] Generated self-signed cert (/tmp/apiserver.crt, /tmp/apiserver.key)
I1115 10:14:19.840290       1 secure_serving.go:202] Serving securely on [::]:443
I1115 10:14:19.840395       1 requestheader_controller.go:169] Starting RequestHeaderAuthRequestController
I1115 10:14:19.840403       1 shared_informer.go:240] Waiting for caches to sync for RequestHeaderAuthRequestController
I1115 10:14:19.840411       1 dynamic_serving_content.go:130] Starting serving-cert::/tmp/apiserver.crt::/tmp/apiserver.key
I1115 10:14:19.840438       1 tlsconfig.go:240] Starting DynamicServingCertificateController
[......]
➜  ~ kubectl get apiservice | grep metrics
v1beta1.metrics.k8s.io                 kube-system/metrics-server   True        10m

➜  ~ kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes"
{"kind":"NodeMetricsList","apiVersion":"metrics.k8s.io/v1beta1","metadata":{},"items":[{"metadata":{"name":"hkk8smaster001","creationTimestamp":"2025-10-14T05:50:51Z","labels":{"beta.kubernetes.io/arch":"amd64","beta.kubernetes.io/os":"linux","ingress":"ingress","kubernetes.io/arch":"amd64","kubernetes.io/hostname":"hkk8smaster001","kubernetes.io/os":"linux","node-role.kubernetes.io/control-plane":"","node.kubernetes.io/exclude-from-external-load-balancers":""}},"timestamp":"2025-10-14T05:50:41Z","window":"20.114s","usage":{"cpu":"272335371n","memory":"4470464Ki"}},{"metadata":{"name":"hkk8snode001","creationTimestamp":"2025-10-14T05:50:51Z","labels":{"beta.kubernetes.io/arch":"amd64","beta.kubernetes.io/os":"linux","kubernetes.io/arch":"amd64","kubernetes.io/hostname":"hkk8snode001","kubernetes.io/os":"linux"}},"timestamp":"2025-10-14T05:50:44Z","window":"20.091s","usage":{"cpu":"90879614n","memory":"7789532Ki"}},{"metadata":{"name":"hkk8snode002","creationTimestamp":"2025-10-14T05:50:51Z","labels":{"beta.kubernetes.io/arch":"amd64","beta.kubernetes.io/os":"linux","kubernetes.io/arch":"amd64","kubernetes.io/hostname":"hkk8snode002","kubernetes.io/os":"linux"}},"timestamp":"2025-10-14T05:50:37Z","window":"10.027s","usage":{"cpu":"77108281n","memory":"6672856Ki"}}]}

# 查看
➜  ~ kubectl top nodes
NAME             CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%   
hkk8smaster001   273m         3%     4365Mi          13%       
hkk8snode001     91m          0%     7606Mi          11%       
hkk8snode002     78m          0%     6516Mi          10%    
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760421109613-e3e7bba4-4858-4bc5-90da-a845246ac52b.png)

<font style="color:rgb(28, 30, 33);">现在我们可以通过 </font>`<font style="color:#DF2A3F;">kubectl top</font>`<font style="color:rgb(28, 30, 33);"> 命令来获取到资源数据了，证明 </font>`<font style="color:#DF2A3F;">Metrics Server</font>`<font style="color:rgb(28, 30, 33);"> 已经安装成功了。</font>

## <font style="color:rgb(28, 30, 33);">2 HPA 对象</font>
<font style="color:rgb(28, 30, 33);">现在我们用 Deployment 来创建一个 Nginx Pod，然后利用 </font>`<font style="color:#DF2A3F;">HPA</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">来进行自动扩缩容。资源清单如下所示：</font>

```yaml
# hpa-demo.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hpa-demo
spec:
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx
          ports:
            - containerPort: 80
```

<font style="color:rgb(28, 30, 33);">然后直接创建 Deployment，注意一定先把之前创建的具有 </font>`<font style="color:#DF2A3F;">app=nginx</font>`<font style="color:rgb(28, 30, 33);"> 的 Pod 先清除掉（注意该资源清单文件并没有配置资源限制字段 [requests | limits]）：</font>

```shell
➜  ~ kubectl apply -f hpa-demo.yaml
deployment.apps/hpa-demo created

➜  ~ kubectl get pods -l app=nginx
NAME                        READY   STATUS    RESTARTS   AGE
hpa-demo-7848d4b86f-khndb   1/1     Running   0          10s
```

<font style="color:rgb(28, 30, 33);">现在我们来创建一个 </font>`<font style="color:#DF2A3F;">HPA</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">资源对象，可以使用</font>`<font style="color:#DF2A3F;">kubectl autoscale</font>`<font style="color:rgb(28, 30, 33);">命令来创建：</font>

```shell
➜  ~ kubectl autoscale deployment hpa-demo --cpu-percent=10 --min=1 --max=10
horizontalpodautoscaler.autoscaling/hpa-demo autoscaled

# 查看 HPA 的资源信息
➜  ~ kubectl get hpa
NAME       REFERENCE             TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
hpa-demo   Deployment/hpa-demo   <unknown>/10%   1         10        0          5s
```

<font style="color:rgb(28, 30, 33);">此命令创建了一个关联资源 </font>`<font style="color:#DF2A3F;">hpa-demo</font>`<font style="color:rgb(28, 30, 33);"> 的 HPA，最小的 Pod 副本数为 1，最大为 10。HPA 会根据设定的 cpu 使用率（10%）动态的增加或者减少 Pod 数量。</font>

<font style="color:rgb(28, 30, 33);">当然我们依然还是可以通过创建 YAML 文件的形式来创建 HPA 资源对象。如果我们不知道怎么编写的话，可以查看上面命令行创建的 HPA 的 YAML 文件：</font>

```yaml
➜  ~ kubectl get hpa hpa-demo -o yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  creationTimestamp: "2025-10-14T05:52:28Z"
  name: hpa-demo
  namespace: default
  resourceVersion: "167330"
  uid: 44c8b487-bec6-4822-b849-7555ccc21a7a
spec:
  maxReplicas: 10
  metrics:
  - resource:
      name: cpu
      target:
        averageUtilization: 10
        type: Utilization
    type: Resource
  minReplicas: 1
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: hpa-demo
status:
  conditions:
  - lastTransitionTime: "2025-10-14T05:52:43Z"
    message: the HPA controller was able to get the target's current scale
    reason: SucceededGetScale
    status: "True"
    type: AbleToScale
  - lastTransitionTime: "2025-10-14T05:52:43Z"
    message: 'the HPA was unable to compute the replica count: failed to get cpu utilization:
      missing request for cpu in container nginx of Pod hpa-demo-55f598f8d-r4xhs'
    reason: FailedGetResourceMetric
    status: "False"
    type: ScalingActive
  currentMetrics: null
  currentReplicas: 1
  desiredReplicas: 0
```

<font style="color:rgb(28, 30, 33);">然后我们可以根据上面的 YAML 文件就可以自己来创建一个基于 YAML 的 HPA 描述文件了。但是我们发现上面信息里面出现了一些 Fail 信息，我们来查看下这个 HPA 对象的信息：</font>

```shell
➜  ~ kubectl describe hpa hpa-demo
Name:                                                  hpa-demo
Namespace:                                             default
Labels:                                                <none>
Annotations:                                           <none>
CreationTimestamp:                                     Tue, 14 Oct 2025 13:52:28 +0800
Reference:                                             Deployment/hpa-demo
Metrics:                                               ( current / target )
  resource cpu on pods  (as a percentage of request):  <unknown> / 10%
Min replicas:                                          1
Max replicas:                                          10
Deployment pods:                                       1 current / 0 desired
Conditions:
  Type           Status  Reason                   Message
  ----           ------  ------                   -------
  AbleToScale    True    SucceededGetScale        the HPA controller was able to get the target's current scale
  ScalingActive  False   FailedGetResourceMetric  the HPA was unable to compute the replica count: failed to get cpu utilization: missing request for cpu in container nginx of Pod hpa-demo-55f598f8d-r4xhs
Events:
  Type     Reason                        Age               From                       Message
  ----     ------                        ----              ----                       -------
  Warning  FailedGetResourceMetric       0s (x3 over 30s)  horizontal-pod-autoscaler  failed to get cpu utilization: missing request for cpu in container nginx of Pod hpa-demo-55f598f8d-r4xhs
  Warning  FailedComputeMetricsReplicas  0s (x3 over 30s)  horizontal-pod-autoscaler  invalid metrics (1 invalid out of 1), first error is: failed to get cpu resource metric value: failed to get cpu utilization: missing request for cpu in container nginx of Pod hpa-demo-55f598f8d-r4xhs
```

<font style="color:rgb(28, 30, 33);">我们可以看到上面的事件信息里面出现了 </font>`<font style="color:#DF2A3F;">failed to get cpu utilization: missing request for cpu</font>`<font style="color:rgb(28, 30, 33);"> 这样的错误信息。这是因为我们上面创建的 Pod 对象</font>**<font style="color:rgb(28, 30, 33);">没有添加 request 资源</font>**<font style="color:rgb(28, 30, 33);">声明，这样导致 HPA 读取不到 CPU 指标信息，所以如果要想让 HPA 生效，对应的 Pod 资源必须添加 </font>`<font style="color:#DF2A3F;">requests</font>`<font style="color:rgb(28, 30, 33);"> 资源声明（HPA 的使用需要添加资源对象的资源限制），更新我们的资源清单文件：</font>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hpa-demo
spec:
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: 50Mi
              cpu: 50m
```

<font style="color:rgb(28, 30, 33);">然后重新更新 Deployment，重新创建 HPA 对象：</font>

```shell
➜  ~ kubectl apply -f hpa-demo.yaml
deployment.apps/hpa-demo configured

➜  ~ kubectl get pods -o wide -l app=nginx
NAME                       READY   STATUS    RESTARTS   AGE   IP               NODE           NOMINATED NODE   READINESS GATES
hpa-demo-f77b4487f-g9dmg   1/1     Running   0          49s   192.244.211.30   hkk8snode001   <none>           <none>

# HPA 重新创建
➜  ~ kubectl delete hpa hpa-demo
horizontalpodautoscaler.autoscaling "hpa-demo" deleted
➜  ~ kubectl autoscale deployment hpa-demo --cpu-percent=10 --min=1 --max=10
horizontalpodautoscaler.autoscaling/hpa-demo autoscaled

➜  ~ kubectl describe hpa hpa-demo
Name:                                                  hpa-demo
Namespace:                                             default
Labels:                                                <none>
Annotations:                                           <none>
CreationTimestamp:                                     Tue, 14 Oct 2025 13:55:01 +0800
Reference:                                             Deployment/hpa-demo
Metrics:                                               ( current / target )
  resource cpu on pods  (as a percentage of request):  <unknown> / 10%
Min replicas:                                          1
Max replicas:                                          10
Deployment pods:                                       0 current / 0 desired
Events:                                                <none>

➜  ~ kubectl get hpa
NAME       REFERENCE             TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
hpa-demo   Deployment/hpa-demo   0%/10%    1         10        1          35s
```

<font style="color:rgb(28, 30, 33);">现在可以看到 HPA 资源对象已经正常了，现在我们来增大负载进行测试，我们来创建一个 busybox 的 Pod，并且循环访问上面创建的 Pod：</font>

```shell
➜  ~ kubectl run -it --image busybox test-hpa --restart=Never --rm /bin/sh
If you don't see a command prompt, try pressing enter.
/ # while true; do wget -q -O- http://192.244.211.30; done
```

<font style="color:rgb(28, 30, 33);">然后观察 Pod 列表，可以看到，HPA 已经开始工作：</font>

```shell
➜  ~ kubectl get hpa
NAME       REFERENCE             TARGETS    MINPODS   MAXPODS   REPLICAS   AGE
hpa-demo   Deployment/hpa-demo   310%/10%   1         10        1          105s

➜  ~ kubectl get pods -l app=nginx --watch
NAME                       READY   STATUS              RESTARTS   AGE
hpa-demo-f77b4487f-h489x   1/1     Running             0          2m25s
hpa-demo-f77b4487f-pg4fz   0/1     ContainerCreating   0          10s
hpa-demo-f77b4487f-qrwv5   0/1     ContainerCreating   0          10s
hpa-demo-f77b4487f-s4vdz   0/1     ContainerCreating   0          10s
```

<font style="color:rgb(28, 30, 33);">我们可以看到已经自动拉起了很多新的 Pod，最后会定格在了我们上面设置的 10 个 Pod，同时查看资源 hpa-demo 的副本数量，副本数量已经从原来的 1 变成了 10 个：</font>

```shell
➜  ~ kubectl get deployment hpa-demo
NAME       READY   UP-TO-DATE   AVAILABLE   AGE
hpa-demo   10/10   10           10          4m55s
```

<font style="color:rgb(28, 30, 33);">查看 HPA 资源的对象了解工作过程：</font>

```shell
➜  ~ kubectl describe hpa hpa-demo
Name:                                                  hpa-demo
Namespace:                                             default
Labels:                                                <none>
Annotations:                                           <none>
CreationTimestamp:                                     Tue, 14 Oct 2025 13:55:01 +0800
Reference:                                             Deployment/hpa-demo
Metrics:                                               ( current / target )
  resource cpu on pods  (as a percentage of request):  15% (7m) / 10%
Min replicas:                                          1
Max replicas:                                          10
Deployment pods:                                       10 current / 10 desired
Conditions:
  Type            Status  Reason               Message
  ----            ------  ------               -------
  AbleToScale     True    ScaleDownStabilized  recent recommendations were higher than current one, applying the highest recent recommendation
  ScalingActive   True    ValidMetricFound     the HPA was able to successfully calculate a replica count from cpu resource utilization (percentage of request)
  ScalingLimited  True    TooManyReplicas      the desired replica count is more than the maximum replica count
Events:
  Type    Reason             Age   From                       Message
  ----    ------             ----  ----                       -------
  Normal  SuccessfulRescale  73s   horizontal-pod-autoscaler  New size: 4; reason: cpu resource utilization (percentage of request) above target
  Normal  SuccessfulRescale  58s   horizontal-pod-autoscaler  New size: 8; reason: cpu resource utilization (percentage of request) above target
  Normal  SuccessfulRescale  43s   horizontal-pod-autoscaler  New size: 10; reason: cpu resource utilization (percentage of request) above target
```

<font style="color:rgb(28, 30, 33);">同样的这个时候我们来关掉 </font>`<font style="color:#DF2A3F;">busybox</font>`<font style="color:rgb(28, 30, 33);"> 来减少负载，然后等待一段时间观察下 HPA 和 Deployment 对象：</font>

```shell
# 查看 HPA 的信息
➜  ~ kubectl get hpa
NAME       REFERENCE             TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
hpa-demo   Deployment/hpa-demo   0%/10%    1         10        10         3m45s

➜  ~ kubectl get deployment hpa-demo
NAME       READY   UP-TO-DATE   AVAILABLE   AGE
hpa-demo   1/1     1            1           24m

# 清理环境
➜  ~ kubectl delete hpa hpa-demo
```

:::warning
☀️<font style="color:rgb(28, 30, 33);">"缩放间隙"</font>

<font style="color:rgb(28, 30, 33);">从 Kubernetes </font>`<font style="color:#DF2A3F;">v1.12</font>`<font style="color:rgb(28, 30, 33);"> 版本开始我们可以通过设置 </font>`<font style="color:#DF2A3F;">kube-controller-manager</font>`<font style="color:rgb(28, 30, 33);"> 组件的</font>`<font style="color:#DF2A3F;">--horizontal-pod-autoscaler-downscale-stabilization</font>`<font style="color:rgb(28, 30, 33);"> 参数来设置一个持续时间，用于指定在当前操作完成后，</font>`<font style="color:#DF2A3F;">HPA</font>`<font style="color:rgb(28, 30, 33);"> 必须等待多长时间才能执行另一次缩放操作。默认为</font>`<font style="color:#DF2A3F;">5分钟</font>`<font style="color:rgb(28, 30, 33);">，也就是默认需要等待5分钟后才会开始自动缩放。</font>

:::

<font style="color:rgb(28, 30, 33);">可以看到副本数量已经由 10 变为 1，当前我们只是演示了 CPU 使用率这一个指标，在后面的课程中我们还会学习到根据自定义的监控指标来自动对 Pod 进行扩缩容。</font>

## <font style="color:rgb(28, 30, 33);">3 内存</font>
<font style="color:rgb(28, 30, 33);">要使用基于内存或者自定义指标进行扩缩容（现在的版本都必须依赖 metrics-server 这个项目）。现在我们再用 Deployment 来创建一个 Nginx Pod，然后利用 HPA 来进行自动扩缩容。资源清单如下所示：</font>

```yaml
z'zz'z# hpa-mem-demo.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hpa-mem-demo
spec:
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      volumes:
        - name: increase-mem-script
          configMap:
            name: increase-mem-config
      containers:
        - name: nginx
          image: nginx
          ports:
            - containerPort: 80
          volumeMounts:
            - name: increase-mem-script
              mountPath: /etc/script
          resources:
            requests:
              memory: 50Mi
              cpu: 50m
          securityContext:
            privileged: true
```

<font style="color:rgb(28, 30, 33);">这里和前面普通的应用有一些区别，我们将一个名为 </font>`<font style="color:#DF2A3F;">increase-mem-config</font>`<font style="color:rgb(28, 30, 33);"> 的 ConfigMap 资源对象挂载到了容器中，该配置文件是用于后面增加容器内存占用的脚本，配置文件如下所示：</font>

```yaml
# increase-mem-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: increase-mem-config
data:
  increase-mem.sh: |
    #!/bin/bash
    mkdir /tmp/memory
    mount -t tmpfs -o size=40M tmpfs /tmp/memory
    dd if=/dev/zero of=/tmp/memory/block
    sleep 60
    rm /tmp/memory/block
    umount /tmp/memory
    rmdir /tmp/memory
```

<font style="color:rgb(28, 30, 33);">由于这里增加内存的脚本需要使用到 </font>`<font style="color:#DF2A3F;">mount</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">命令，这需要声明为特权模式，所以我们添加了 </font>`<font style="color:#DF2A3F;">securityContext.privileged=true</font>`<font style="color:rgb(28, 30, 33);"> 这个配置。现在我们直接创建上面的资源对象即可：</font>

```shell
# 引用资源清单文件
➜  ~ kubectl apply -f increase-mem-cm.yaml
➜  ~ kubectl apply -f hpa-mem-demo.yaml

# 查看 Pod 的信息
➜  ~ kubectl get pods -l app=nginx
NAME                            READY   STATUS    RESTARTS   AGE
hpa-mem-demo-794f79c48b-hjzg7   1/1     Running   0          10
```

<font style="color:rgb(28, 30, 33);">然后需要创建一个基于内存的 HPA 资源对象：</font>

```yaml
# hpa-mem.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: hpa-mem-demo
  namespace: default
spec:
  maxReplicas: 5
  minReplicas: 1
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: hpa-mem-demo
  metrics: # 指定内存的一个配置
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 30
```

<font style="color:rgb(28, 30, 33);">要注意这里使用的 </font>`<font style="color:#DF2A3F;">apiVersion</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">是 </font>`<font style="color:#DF2A3F;">autoscaling/v2</font>`<font style="color:rgb(28, 30, 33);">，然后 </font>`<font style="color:#DF2A3F;">metrics</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">属性里面指定的是内存的配置，直接创建上面的资源对象即可：</font>

```shell
➜  ~ kubectl apply -f hpa-mem.yaml
horizontalpodautoscaler.autoscaling/hpa-mem-demo created

➜  ~ kubectl get hpa
NAME           REFERENCE                 TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
hpa-mem-demo   Deployment/hpa-mem-demo   6%/30%    1         5         1          32s
```

<font style="color:rgb(28, 30, 33);">到这里证明 HPA 资源对象已经部署成功了，接下来我们对应用进行压测，将内存压上去，直接执行上面我们挂载到容器中的 </font>`<font style="color:#DF2A3F;">increase-mem.sh</font>`<font style="color:rgb(28, 30, 33);"> 脚本即可：</font>

```shell
➜  ~ kubectl exec -it hpa-mem-demo-794f79c48b-hjzg7 -- /bin/bash
root@hpa-mem-demo-794f79c48b-hjzg7:/# ls /etc/script/
increase-mem.sh
root@hpa-mem-demo-794f79c48b-hjzg7:/# source /etc/script/increase-mem.sh
dd: writing to '/tmp/memory/block': No space left on device
81921+0 records in
81920+0 records out
41943040 bytes (42 MB, 40 MiB) copied, 0.452755 s, 92.6 MB/s
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760421860720-5b01160e-ac57-4201-8aa3-5b0b2cdd3062.png)

<font style="color:rgb(28, 30, 33);">然后打开另外一个终端观察 HPA 资源对象的变化情况：</font>

```shell
➜  ~ kubectl get hpa -w
NAME           REFERENCE                 TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
hpa-mem-demo   Deployment/hpa-mem-demo   87%/30%   1         5         3          90s

# 查看 HPA 的描述信息
➜  ~ kubectl describe hpa hpa-mem-demo
Name:                                                     hpa-mem-demo
Namespace:                                                default
Labels:                                                   <none>
Annotations:                                              <none>
CreationTimestamp:                                        Tue, 14 Oct 2025 14:03:06 +0800
Reference:                                                Deployment/hpa-mem-demo
Metrics:                                                  ( current / target )
  resource memory on pods  (as a percentage of request):  24% (12785254400m) / 30%
Min replicas:                                             1
Max replicas:                                             5
Deployment pods:                                          5 current / 5 desired
Conditions:
  Type            Status  Reason               Message
  ----            ------  ------               -------
  AbleToScale     True    ScaleDownStabilized  recent recommendations were higher than current one, applying the highest recent recommendation
  ScalingActive   True    ValidMetricFound     the HPA was able to successfully calculate a replica count from memory resource utilization (percentage of request)
  ScalingLimited  True    TooManyReplicas      the desired replica count is more than the maximum replica count
Events:
  Type     Reason                        Age                    From                       Message
  ----     ------                        ----                   ----                       -------
  Warning  AmbiguousSelector             76s (x6 over 3m1s)     horizontal-pod-autoscaler  pods by selector app=nginx are controlled by multiple HPAs: [default/hpa-demo default/hpa-mem-demo]
  Warning  FailedComputeMetricsReplicas  76s (x6 over 3m1s)     horizontal-pod-autoscaler  pods by selector app=nginx are controlled by multiple HPAs: [default/hpa-demo default/hpa-mem-demo]
  Normal   SuccessfulRescale             61s                    horizontal-pod-autoscaler  New size: 4; reason: memory resource utilization (percentage of request) above target
  Normal   SuccessfulRescale             46s                    horizontal-pod-autoscaler  New size: 5; reason: memory resource utilization (percentage of request) above target
  
➜  ~ kubectl top pod 
NAME                            CPU(cores)   MEMORY(bytes)   
hpa-mem-demo-794f79c48b-4ksj6   0m           13Mi            
hpa-mem-demo-794f79c48b-hjzg7   0m           13Mi            
hpa-mem-demo-794f79c48b-hmld9   0m           13Mi            
hpa-mem-demo-794f79c48b-rkw5h   0m           7Mi             
hpa-mem-demo-794f79c48b-ws4w7   0m           13Mi  
```

<font style="color:rgb(28, 30, 33);">可以看到内存使用已经超过了我们设定的 30% 这个阈值了，HPA 资源对象也已经触发了自动扩容，变成了 4 个副本了：</font>

```shell
➜  ~ kubectl get pods -l app=nginx
NAME                            READY   STATUS    RESTARTS   AGE
hpa-mem-demo-794f79c48b-4ksj6   1/1     Running   0          114s
hpa-mem-demo-794f79c48b-hjzg7   1/1     Running   0          8m45s
hpa-mem-demo-794f79c48b-hmld9   1/1     Running   0          2m10s
hpa-mem-demo-794f79c48b-rkw5h   1/1     Running   0          2m10s
hpa-mem-demo-794f79c48b-ws4w7   1/1     Running   0          2m10s
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760422136649-a344811d-abaa-462e-b4cb-2b2853bb23c1.png)

<font style="color:rgb(28, 30, 33);">当内存释放掉后，controller-manager 默认 5 分钟过后会进行缩放，到这里就完成了基于内存的 HPA 操作。</font>

```shell
# 清理环境
➜  ~ kubectl delete hpa hpa-mem-demo 
horizontalpodautoscaler.autoscaling "hpa-mem-demo" deleted

➜  ~ kubectl delete deployment hpa-mem-demo
deployment.apps "hpa-mem-demo" deleted
```

