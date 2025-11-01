> Link Reference：[Kubernetes 原生 Sidecar 与 OpenKruise Sidecar对比与实践](https://mp.weixin.qq.com/s/6-jopJYNRpr-BqBqBwdebQ)
>

## 0 OpenKruise 介绍
![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760428027755-90c3ad28-54ec-4541-a0eb-f092b1ecde5a.png)

[**<u>OpenKruise</u>**](https://openkruise.io/)**<u> 是一个基于 Kubernetes 的扩展套件，主要聚焦于云原生应用的自动化，比如部署、发布、运维以及可用性防护。</u>**<font style="color:#DF2A3F;">OpenKruise 提供的绝大部分能力都是基于 CRD 扩展来定义的，它们不存在于任何外部依赖，可以运行在任意纯净的 Kubernetes 集群中。</font>Kubernetes 自身提供的一些应用部署管理功能，对于大规模应用与集群的场景这些功能是远远不够的，**<u><font style="color:#601BDE;">OpenKruise 弥补了 Kubernetes 在应用部署、升级、防护、运维等领域的不足。</font></u>**

OpenKruise 提供了以下的一些核心能力：

+ **<font style="color:#DF2A3F;">增强版本的 Workloads(工作负载)</font>**：OpenKruise 包含了一系列增强版本的工作负载，比如 CloneSet、Advanced StatefulSet、Advanced DaemonSet、BroadcastJob 等。它们不仅<font style="color:#DF2A3F;">支持类似于 Kubernetes 原生 Workloads 的基础功能，还提供了如原地升级、可配置的扩缩容/发布策略、并发操作等。</font>其中，<font style="color:#DF2A3F;">原地升级是一种升级应用容器镜像甚至环境变量的全新方式，它只会用新的镜像重建 Pod 中的特定容器，整个 Pod 以及其中的其他容器都不会被影响。因此它带来了更快的发布速度，以及避免了对其他 Scheduler、CNI、CSI 等组件的负面影响。</font>
+ **<font style="color:#DF2A3F;">应用的旁路管理</font>**：OpenKruise 提供了多种通过旁路管理应用 Sidecar 容器、多区域部署的方式，“旁路” 意味着你可以不需要修改应用的 Workloads 来实现它们。比如，<font style="color:#DF2A3F;">SidecarSet 能帮助你在所有匹配的 Pod 创建的时候都注入特定的 sidecar 容器，甚至可以原地升级已经注入的 sidecar 容器镜像、并且对 Pod 中其他容器不造成影响。</font>而 WorkloadSpread 可以约束无状态 Workload 扩容出来 Pod 的区域分布，赋予单一 workload 的多区域和弹性部署的能力。
+ **<font style="color:#DF2A3F;">高可用性防护</font>**：OpenKruise 可以保护你的 Kubernetes 资源不受级联删除机制的干扰，包括 CRD、Namespace、以及几乎全部的 Workloads 类型资源。相比于 Kubernetes 原生的 PDB 只提供针对 Pod Eviction 的防护，PodUnavailableBudget 能够防护 Pod Deletion、Eviction、Update 等许多种 voluntary disruption 场景。
+ **<font style="color:#DF2A3F;">高级的应用运维能力</font>**：OpenKruise 也提供了很多高级的运维能力来帮助你更好地管理应用，比如<font style="color:#DF2A3F;">可以通过 ImagePullJob 来在任意范围的节点上预先拉取某些镜像，或者指定某个 Pod 中的一个或多个容器被原地重启。</font>

## 1 OpenKruise 架构
下图是 OpenKruise 的整体架构：

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1730551631831-2828be67-f4f2-41c7-b1a1-d33c436be41b.png)

首先我们要清楚所有 OpenKruise 的功能都是通过 Kubernetes CRD 来提供的：

```shell
➜ kubectl get crd | grep kruise.io
advancedcronjobs.apps.kruise.io                       2025-10-14T07:53:49Z
broadcastjobs.apps.kruise.io                          2025-10-14T07:53:49Z
clonesets.apps.kruise.io                              2025-10-14T07:53:49Z
containerrecreaterequests.apps.kruise.io              2025-10-14T07:53:49Z
daemonsets.apps.kruise.io                             2025-10-14T07:53:49Z
imagepulljobs.apps.kruise.io                          2025-10-14T07:53:49Z
nodeimages.apps.kruise.io                             2025-10-14T07:53:49Z
podunavailablebudgets.policy.kruise.io                2025-10-14T07:53:49Z
resourcedistributions.apps.kruise.io                  2025-10-14T07:53:49Z
sidecarsets.apps.kruise.io                            2025-10-14T07:53:49Z
statefulsets.apps.kruise.io                           2025-10-14T07:53:49Z
uniteddeployments.apps.kruise.io                      2025-10-14T07:53:49Z
workloadspreads.apps.kruise.io                        2025-10-14T07:53:49Z
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760428479343-13adcf99-3fd0-4c0a-a696-83d5543f8791.png)

其中 `<font style="color:#DF2A3F;">Kruise-manager</font>` 是一个运行控制器和 Webhook 的中心组件，它通过 Deployment 部署在 `<font style="color:#DF2A3F;">kruise-system</font>` 命名空间中。 从逻辑上来看，如 `<font style="color:#DF2A3F;">cloneset-controller</font>`、`<font style="color:#DF2A3F;">sidecarset-controller</font>` 这些的控制器都是独立运行的，不过为了减少复杂度，它们都被打包在一个独立的二进制文件、并运行在 `<font style="color:#DF2A3F;">kruise-controller-manager-xxx</font>` 这个 Pod 中。除了控制器之外，`<font style="color:#DF2A3F;">kruise-controller-manager-xxx</font>` 中还包含了针对 Kruise CRD 以及 Pod 资源的 Admission webhook。`<font style="color:#DF2A3F;">Kruise-manager</font>` 会创建一些 Webhook Configurations 来配置哪些资源需要感知处理、以及提供一个 Service 来给 Kube-Apiserver 调用。

<u>OpenKruise 从 v0.8.0 版本开始提供了一个新的 </u>`<u><font style="color:#DF2A3F;">Kruise-daemon</font></u>`<u> 组件，它通过 DaemonSet 部署到每个节点上，提供镜像预热、容器重启等功能。</u>

## 2 安装 OpenKruise
这里我们同样还是使用 Helm 方式来进行安装，需要注意从 v1.0.0 开始，OpenKruise 要求在 Kubernetes >= 1.16 以上版本的集群中安装和使用。

首先添加 charts 仓库：

```shell
➜ helm repo add openkruise https://openkruise.github.io/charts
➜ helm repo update
```

然后执行下面的命令安装最新版本的应用：

```shell
➜ helm upgrade --install kruise openkruise/kruise --version 1.0.1
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760428445753-887149c2-092f-47fa-b83e-ed1d0e8eaa79.png)

该 charts 在模板中默认定义了命名空间为 `<font style="color:#DF2A3F;">kruise-system</font>`，所以在安装的时候可以不用指定，如果你的环境访问 DockerHub 官方镜像较慢，则可以使用下面的命令将镜像替换成阿里云的镜像：

```shell
➜ helm upgrade --install kruise openkruise/kruise \
  --set manager.image.repository=openkruise-registry.cn-hangzhou.cr.aliyuncs.com/openkruise/kruise-manager \
  --version 1.0.1
```

应用部署完成后会在 `<font style="color:#DF2A3F;">kruise-system</font>` 命名空间下面运行 2 个 `<font style="color:#DF2A3F;">kruise-manager</font>` 的 Pod，同样它们之间采用 `<font style="color:#DF2A3F;">leader-election</font>` 的方式选主，同一时间只有一个提供服务，达到高可用的目的，此外还会以 DaemonSet 的形式启动 `<font style="color:#DF2A3F;">kruise-daemon</font>` 组件：

```shell
┌─────────────────────────────────────────┐
│   kruise-controller-manager (x2)        │
│   - 处理 API 请求                        │
│   - 管理 CRD 资源                        │
│   - Webhook 验证                         │
└──────────────┬──────────────────────────┘
               │ 下发指令
               ▼
┌──────────────────────────────────────────┐
│   kruise-daemon (每个节点)                │
│   - 镜像预热                              │
│   - 原地升级                              │
│   - 容器重启                              │
└──────────────────────────────────────────┘
```

```shell
###########################################################################
# kruise-controller-manager（2个副本）
# 作用： 核心控制器管理器，负责处理 Kruise 的所有 CRD 资源
# -------------------------------------------------------------------------
# 功能：
# -------------------------------------------------------------------------
# 管理 CloneSet、Advanced StatefulSet、SidecarSet、DaemonSet 等控制器
# 处理 Webhook 验证和变更请求
# 监听和协调 Kruise 自定义资源的状态
# 执行扩缩容、原地升级、灰度发布等逻辑
# 为什么有 2 个副本：
# -------------------------------------------------------------------------
# 高可用性 - 一个挂了另一个继续工作
# 通过 leader election 机制，只有一个是 active leader，另一个是 standby
###########################################################################
# kruise-daemon（3个副本 - 每个节点一个）
# 作用： DaemonSet 形式部署在每个节点上的守护进程
# -------------------------------------------------------------------------
# 功能：
# -------------------------------------------------------------------------
# 镜像预热（ImagePullJob）： 在节点上预先拉取镜像，加速 Pod 启动
# 容器重启： 支持原地重启容器而不重建 Pod
# 原地升级： 协助实现容器的原地升级（in-place update）
# 节点镜像管理： 管理节点上的容器镜像缓存
# 提供节点级别的操作能力： 与 kubelet 配合，执行更精细的容器操作
# 为什么每个节点一个：
# -------------------------------------------------------------------------
# 需要在每个节点上执行本地操作（镜像拉取、容器重启等）
# 你有 3 个节点（1 Master + 2 Worker），所以有 3 个 kruise-daemon
###########################################################################
➜ kubectl get pods -n kruise-system
NAME                                        READY   STATUS    RESTARTS   AGE
kruise-controller-manager-dc7d4d76c-8vg5k   1/1     Running   0          5m54s
kruise-controller-manager-dc7d4d76c-hv4ml   1/1     Running   0          5m54s
kruise-daemon-56mws                         1/1     Running   0          5m55s
kruise-daemon-d4plt                         1/1     Running   0          5m55s
kruise-daemon-vs7q5                         1/1     Running   0          5m55s
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760428800792-469c7a11-1cd1-47f0-9e92-3d7fa9f7edb9.png)

如果不想使用默认的参数进行安装，也可以自定义配置，可配置的 Values 值可以参考 Charts 文档 [https://github.com/openkruise/charts](https://github.com/openkruise/charts/tree/master/versions/1.0.1) 进行定制。

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760428830890-c5cf8d54-1258-426d-ad8a-e14b1af6120c.png)

```shell
# 拉取 OpenKruise 的 Helm-Chart
$ helm pull openkruise/kruise --version 1.0.1 --untar
```

## 3 CloneSet
`<font style="color:#DF2A3F;">CloneSet</font>`<font style="color:#DF2A3F;"> </font>控制器是 OpenKruise 提供的对原生 Deployment 的增强控制器，在使用方式上和 Deployment 几乎一致，如下所示是我们声明的一个 CloneSet 资源对象：

```yaml
# cloneset-demo-v1.yaml
apiVersion: apps.kruise.io/v1alpha1
kind: CloneSet
metadata:
  name: cs-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: cs
  template:
    metadata:
      labels:
        app: cs
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 80
```

直接创建上面的这个 CloneSet 对象：

```shell
➜ kubectl apply -f cloneset-demo-v1.yaml
cloneset.apps.kruise.io/cs-demo created

➜ kubectl get cloneset cs-demo
NAME      DESIRED   UPDATED   UPDATED_READY   READY   TOTAL   AGE
cs-demo   3         3         3               3       3       15s

# 查看 cloneset 的描述信息
➜ kubectl describe cloneset cs-demo
Name:         cs-demo
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  apps.kruise.io/v1alpha1
Kind:         CloneSet
[......]
Status:
  Available Replicas:      3
  Collision Count:         0
  Current Revision:        cs-demo-5c5f449787
  Label Selector:          app=cs
  Observed Generation:     1
  Ready Replicas:          3
  Replicas:                3
  Update Revision:         cs-demo-5c5f449787
  Updated Ready Replicas:  3
  Updated Replicas:        3
Events:
  Type    Reason            Age   From                 Message
  ----    ------            ----  ----                 -------
  Normal  SuccessfulCreate  25s   cloneset-controller  succeed to create pod cs-demo-25czf
  Normal  SuccessfulCreate  25s   cloneset-controller  succeed to create pod cs-demo-4rm6l
  Normal  SuccessfulCreate  25s   cloneset-controller  succeed to create pod cs-demo-2x8t4
```

该对象创建完成后我们可以通过 `<font style="color:#DF2A3F;">kubectl describe</font>` 命令查看对应的 Events 信息，可以发现 `<font style="color:#DF2A3F;">cloneset-controller</font>` 是直接创建的 Pod，这个和原生的 Deployment 就有一些区别了，Deployment 是通过 ReplicaSet 去创建的 Pod，所以从这里也可以看出来 CloneSet 是直接管理 Pod 的，3 个副本的 Pod 此时也创建成功了：

```shell
➜ kubectl get pods -l app=cs
NAME            READY   STATUS    RESTARTS   AGE
cs-demo-25czf   1/1     Running   0          115s
cs-demo-2x8t4   1/1     Running   0          115s
cs-demo-4rm6l   1/1     Running   0          115s

➜ kubectl get pod cs-demo-4rm6l -o yaml 
apiVersion: v1
kind: Pod
metadata:
  [......]
  name: cs-demo-4rm6l
  namespace: default
  ownerReferences: # 属于 CloneSet 的资源对象下的资源
  - apiVersion: apps.kruise.io/v1alpha1
    blockOwnerDeletion: true
    controller: true
    kind: CloneSet
    name: cs-demo
[......]

# Deployment 资源对象下的 Pods 是属于是 ReplicaSet 来进行管理
```

CloneSet 虽然在使用上和 Deployment 比较类似，但还是有非常多比 Deployment 更高级的功能，下面我们来详细介绍下。

### 3.1 CloneSet 扩缩容
```shell
# CloneSet 的解释信息
$ kubectl explain CloneSet
GROUP:      apps.kruise.io
KIND:       CloneSet
VERSION:    v1alpha1

DESCRIPTION:
    CloneSet is the Schema for the clonesets API
    
FIELDS:
  apiVersion    <string>
    APIVersion defines the versioned schema of this representation of an object.
    Servers should convert recognized schemas to the latest internal value, and
    may reject unrecognized values. More info:
    https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources

  kind  <string>
    Kind is a string value representing the REST resource this object
    represents. Servers may infer this from the endpoint the client submits
    requests to. Cannot be updated. In CamelCase. More info:
    https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds

  metadata      <ObjectMeta>
    Standard object's metadata. More info:
    https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata

  spec  <Object>
    CloneSetSpec defines the desired state of CloneSet

  status        <Object>
    CloneSetStatus defines the observed state of CloneSet
```

CloneSet 在扩容的时候可以通过 `<u><font style="color:#DF2A3F;">ScaleStrategy.MaxUnavailable</font></u>`<u> 来限制扩容的步长，这样可以对服务应用的影响最小，可以设置一个绝对值或百分比，如果不设置该值，则表示不限制。</u>

比如我们在上面的资源清单中添加如下所示数据：

```yaml
# cloneset-demo-v2.yaml
apiVersion: apps.kruise.io/v1alpha1
kind: CloneSet
metadata:
  name: cs-demo
spec:
  minReadySeconds: 60
  scaleStrategy:
    maxUnavailable: 1
  replicas: 5
  [......]
```

上面我们配置 `<font style="color:#DF2A3F;">scaleStrategy.maxUnavailable</font>` 为 `<font style="color:#DF2A3F;">1</font>`，结合 `<font style="color:#DF2A3F;">minReadySeconds</font>`<font style="color:#DF2A3F;"> </font>参数，**<u><font style="color:#601BDE;">表示在扩容时，只有当上一个扩容出的 Pod 已经 Ready 超过一分钟后，CloneSet 才会执行创建下一个 Pod</font></u>**，比如这里我们扩容成 5 个副本，更新上面对象后查看 CloneSet 的事件：

```shell
➜ kubectl apply -f cloneset-demo-v2.yaml 
cloneset.apps.kruise.io/cs-demo configured

# 查看描述信息
➜ kubectl describe cloneset cs-demo
Name:         cs-demo
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  apps.kruise.io/v1alpha1
Kind:         CloneSet
[......]
Events:
  Type     Reason            Age                From                 Message
  ----     ------            ----               ----                 -------
  Normal   SuccessfulCreate  5m53s              cloneset-controller  succeed to create pod cs-demo-25czf
  Normal   SuccessfulCreate  5m53s              cloneset-controller  succeed to create pod cs-demo-4rm6l
  Normal   SuccessfulCreate  5m53s              cloneset-controller  succeed to create pod cs-demo-2x8t4
  Warning  ScaleUpLimited    85s                cloneset-controller  scaleUp is limited because of scaleStrategy.maxUnavailable, limit: 1
  Normal   SuccessfulCreate  85s                cloneset-controller  succeed to create pod cs-demo-nzm4j
  Warning  ScaleUpLimited    83s (x7 over 85s)  cloneset-controller  scaleUp is limited because of scaleStrategy.maxUnavailable, limit: 0
  Normal   SuccessfulCreate  24s                cloneset-controller  succeed to create pod cs-demo-sgdzp
```

可以看到第一时间扩容了一个 Pod，由于我们配置了 `<font style="color:#DF2A3F;">minReadySeconds: 60</font>`，也就是新扩容的 Pod 创建成功超过 1 分钟后才会扩容另外一个 Pod，上面的 Events 信息也能表现出来，查看 Pod 的 `<font style="color:#DF2A3F;">AGE</font>`<font style="color:#DF2A3F;"> </font>也能看出来扩容的 2 个 Pod 之间间隔了 1 分钟左右：

```shell
➜ kubectl get pods -l app=cs
NAME            READY   STATUS    RESTARTS   AGE
cs-demo-25czf   1/1     Running   0          7m15s
cs-demo-2x8t4   1/1     Running   0          7m15s
cs-demo-4rm6l   1/1     Running   0          7m15s
cs-demo-nzm4j   1/1     Running   0          2m47s
cs-demo-sgdzp   1/1     Running   0          106s
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760429530105-5409d44e-9c42-43b6-b46a-93cfb884e3d2.png)

:::color2
缩容可以删除指定 Pod 的名称

:::

当 CloneSet 被缩容时，我们还可以指定一些 Pod 来删除，这对于 StatefulSet 或者 Deployment 来说是无法实现的， StatefulSet 是根据序号来删除 Pod，而 Deployment/ReplicaSet 目前只能根据控制器里定义的排序来删除。<u><font style="color:#DF2A3F;">而 CloneSet 允许用户在缩小 replicas 数量的同时，指定想要删除的 Pod 名字</font></u>，如下所示：

```yaml
# cloneset-demo-v3.yaml 
apiVersion: apps.kruise.io/v1alpha1
kind: CloneSet
metadata:
  name: cs-demo
spec:
  minReadySeconds: 60
  scaleStrategy:
    maxUnavailable: 1
    podsToDelete:
    - cs-demo-sgdzp
  replicas: 4 # 从副本数 5 降低到 4
[......]
```

更新上面的资源对象后，会将应用缩到 4 个 Pod，如果在 `<font style="color:#DF2A3F;">podsToDelete</font>`<font style="color:#DF2A3F;"> </font>列表中指定了 Pod 名字，则控制器会优先删除这些 Pod，对于已经被删除的 Pod，控制器会自动从 `<font style="color:#DF2A3F;">podsToDelete</font>`<font style="color:#DF2A3F;"> </font>列表中清理掉。比如我们更新上面的资源对象后 `<font style="color:#DF2A3F;">cs-demo-79rcx</font>` 这个 Pod 会被移除，其余会保留下来：

```shell
➜ kubectl apply -f cloneset-demo-v3.yaml 
cloneset.apps.kruise.io/cs-demo configured

➜ kubectl get pods -l app=cs
NAME            READY   STATUS    RESTARTS   AGE
cs-demo-25czf   1/1     Running   0          25m
cs-demo-2x8t4   1/1     Running   0          25m
cs-demo-4rm6l   1/1     Running   0          25m
cs-demo-nzm4j   1/1     Running   0          23m
```

如果你只把 Pod 名字加到 `<font style="color:#DF2A3F;">podsToDelete</font>`，但没有修改 replicas 数量，那么控制器会先把指定的 Pod 删掉，然后再扩一个新的 Pod，另一种直接删除 Pod 的方式是在要删除的 Pod 上打 `<font style="color:#DF2A3F;">apps.kruise.io/specified-delete: true</font>` 标签。

相比于手动直接删除 Pod，<u>使用 </u>`<u><font style="color:#DF2A3F;">podsToDelete</font></u>`<u><font style="color:#DF2A3F;"> </font></u><u>或 </u>`<u><font style="color:#DF2A3F;">apps.kruise.io/specified-delete: true</font></u>`<u><font style="color:#DF2A3F;"> </font></u><u>方式会有 CloneSet 的 </u>`<u><font style="color:#DF2A3F;">maxUnavailable/maxSurge</font></u>`<u> 来保护删除， 并且会触发 </u>`<u><font style="color:#DF2A3F;">PreparingDelete</font></u>`<u> 生命周期的钩子。</u>

### 3.2 CloneSet 升级
CloneSet 一共提供了 3 种升级方式：

+ `<font style="color:#DF2A3F;">ReCreate</font>`: 删除旧 Pod 和它的 PVC，然后用新版本重新创建出来，这是默认的方式
+ `<font style="color:#DF2A3F;">InPlaceIfPossible</font>`: 会优先尝试原地升级 Pod，如果不行再采用重建升级
+ `<font style="color:#DF2A3F;">InPlaceOnly</font>`: 只允许采用原地升级，因此，用户只能修改上一条中的限制字段，如果尝试修改其他字段会被拒绝

这里有一个重要概念：**<font style="color:#DF2A3F;">原地升级</font>**，这也是 OpenKruise 提供的核心功能之一，当我们要升级一个 Pod 中镜像的时候，下图展示了**<font style="color:#DF2A3F;">重建升级</font>**和**<font style="color:#DF2A3F;">原地升级</font>**的区别：

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1730551630023-d5c3377c-6bdc-47ad-a81a-9f07d4428ad8.png)

**<u>重建升级</u>**<u>时我们需要删除旧 Pod、创建新 Pod：</u>

+ <u>Pod 名字和 uid 发生变化，因为它们是完全不同的两个 Pod 对象（比如 Deployment 升级）</u>
+ <u>Pod 名字可能不变、但 uid 变化，因为它们是不同的 Pod 对象，只是复用了同一个名字（比如 StatefulSet 升级）</u>
+ <u>Pod 所在 Node 名字可能发生变化，因为新 Pod 很可能不会调度到之前所在的 Node 节点</u>
+ <u>Pod IP 发生变化，因为新 Pod 很大可能性是不会被分配到之前的 IP 地址</u>

<u>但是对于</u>**<u>原地升级</u>**<u>，我们仍然复用同一个 Pod 对象，只是修改它里面的字段：</u>

+ <u>可以避免如</u>_<u>调度</u>_<u>、</u>_<u>分配 IP</u>_<u>、</u>_<u>挂载盘</u>_<u>等额外的操作和代价</u>
+ <u>更快的镜像拉取，因为会复用已有旧镜像的大部分 layer 层，只需要拉取新镜像变化的一些 layer</u>
+ <u>当一个容器在原地升级时，Pod 中的其他容器不会受到影响，仍然维持运行</u>

所以显然如果能用**<font style="color:#DF2A3F;">原地升级</font>**方式来升级我们的工作负载，对在线应用的影响是最小的。上面我们提到 CloneSet 升级类型支持 `<font style="color:#DF2A3F;">InPlaceIfPossible</font>`，这意味着 Kruise 会尽量对 Pod 采取原地升级，如果不能则退化到重建升级，以下的改动会被允许执行原地升级：

+ 更新 workload 中的 `<font style="color:#DF2A3F;">spec.template.metadata.*</font>`，比如 `<font style="color:#DF2A3F;">labels/annotations</font>`，Kruise 只会将 metadata 中的改动更新到存量 Pod 上。
+ 更新 workload 中的 `<font style="color:#DF2A3F;">spec.template.spec.containers[x].image</font>`，Kruise 会原地升级 Pod 中这些容器的镜像，而不会重建整个 Pod。
+ 从 Kruise v1.0 版本开始，更新 `<font style="color:#DF2A3F;">spec.template.metadata.labels/annotations</font>` 并且 container 中有配置 Env From 这些改动的 `<font style="color:#DF2A3F;">labels/anntations</font>`，Kruise 会原地升级这些容器来生效新的 Env 值。

否则，其他字段的改动，比如 `<font style="color:#DF2A3F;">spec.template.spec.containers[x].env</font>`<font style="color:#DF2A3F;"> 或 </font>`<font style="color:#DF2A3F;">spec.template.spec.containers[x].resources</font>`，都是会回退为重建升级。

比如我们将上面的应用升级方式设置为 `<font style="color:#DF2A3F;">InPlaceIfPossible</font>`，只需要在资源清单中添加 `<font style="color:#DF2A3F;">spec.updateStrategy.type: InPlaceIfPossible</font>` 即可：

```yaml
# cloneset-demo-v4.yaml
apiVersion: apps.kruise.io/v1alpha1
kind: CloneSet
metadata:
  name: cs-demo
spec:
  updateStrategy:
    type: InPlaceIfPossible
  minReadySeconds: 60
  scaleStrategy:
    maxUnavailable: 1 # 需要将指定删除 Pod 的名称的配置注释
  replicas: 4
  selector:
    matchLabels:
      app: cs
  template:
    metadata:
      labels:
        app: cs
    spec:
      containers:
        - name: nginx
          image: nginx:1.7.9 # 更新镜像版本
[......]
```

更新后可以发现 Pod 的状态并没有发生什么大的变化，名称、IP 都一样，唯一变化的是镜像 tag：

```shell
➜ kubectl apply -f cloneset-demo-v4.yaml 
cloneset.apps.kruise.io/cs-demo configured

➜ kubectl get pods -l app=cs
NAME            READY   STATUS    RESTARTS     AGE
cs-demo-25czf   1/1     Running   0            35m
cs-demo-2x8t4   1/1     Running   0            35m
cs-demo-4rm6l   1/1     Running   0            35m
cs-demo-nzm4j   1/1     Running   1 (7s ago)   30m

# 查看 cloneset 描述信息
➜ kubectl describe cloneset cs-demo
Name:         cs-demo
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  apps.kruise.io/v1alpha1
Kind:         CloneSet
[......]
Events:
  Type     Reason                      Age                From                 Message
  ----     ------                      ----               ----                 -------
  [......]
  Normal   SuccessfulUpdatePodInPlace  4m20s              cloneset-controller  successfully update pod cs-demo-nzm4j in-place(revision cs-demo-7cb9c88699)
  Normal   SuccessfulUpdatePodInPlace  3m18s              cloneset-controller  successfully update pod cs-demo-25czf in-place(revision cs-demo-7cb9c88699)
  Normal   SuccessfulUpdatePodInPlace  2m15s              cloneset-controller  successfully update pod cs-demo-4rm6l in-place(revision cs-demo-7cb9c88699)
  Normal   SuccessfulUpdatePodInPlace  73s                cloneset-controller  successfully update pod cs-demo-2x8t4 in-place(revision cs-demo-7cb9c88699)

# 查看 Pod 的描述信息
➜ kubectl describe pod cs-demo-nzm4j
[......]
Events:
  Type    Reason     Age                  From               Message
  ----    ------     ----                 ----               -------
  Normal  Scheduled  31m                  default-scheduler  Successfully assigned default/cs-demo-nzm4j to hkk8snode002
  Normal  Pulled     31m                  kubelet            Container image "nginx:alpine" already present on machine
  Normal  Created    2m13s (x2 over 31m)  kubelet            Created container nginx
  Normal  Started    2m13s (x2 over 31m)  kubelet            Started container nginx
  Normal  Killing    2m13s                kubelet            Container nginx definition changed, will be restarted
  Normal  Pulled     2m13s                kubelet            Container image "nginx:1.7.9" already present on machine
```

这就是原地升级的效果，原地升级整体工作流程如下图所示：

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1730551631918-91c064da-581e-4a33-a87d-b8c31ea10b66.png)

如果你在安装或升级 Kruise 的时候启用了 `<font style="color:#DF2A3F;">PreDownloadImageForInPlaceUpdate</font>`<font style="color:#DF2A3F;"> </font>这个 `<font style="color:#DF2A3F;">feature-gate(特性门控)</font>`，<u><font style="color:#601BDE;">CloneSet 控制器会自动在所有旧版本 Pod 所在节点上预热你正在灰度发布的新版本镜像</font></u>，这对于应用发布加速很有帮助。

默认情况下 CloneSet 每个新镜像预热时的并发度都是 1，也就是一个个节点拉镜像，如果需要调整，你可以在 CloneSet annotation 上设置并发度：

```yaml
# cloneset-demo-v5.yaml
apiVersion: apps.kruise.io/v1alpha1
kind: CloneSet
metadata:
  annotations:
    apps.kruise.io/image-predownload-parallelism: '5'
[......]  
spec:
  updateStrategy:
    partition: 2
    type: InPlaceIfPossible
  [......]
  template:
    spec:
      containers:
        - name: nginx
          image: nginx:latest # 更新镜像
```

:::color2
💡注意，为了避免大部分不必要的镜像拉取，目前只针对 `<font style="color:#DF2A3F;">replicas > 3</font>` 的 CloneSet 做自动预热。

:::

此外 CloneSet 还支持分批进行灰度，在 `<font style="color:#DF2A3F;">updateStrategy</font>`<font style="color:#DF2A3F;"> </font>属性中可以配置 `<font style="color:#DF2A3F;">partition</font>`<font style="color:#DF2A3F;"> </font>参数，该参数可以用来**<font style="color:#601BDE;">保留旧版本 Pod 的数量或百分比</font>**，默认为 0：

+ 如果是数字，控制器会将 `<font style="color:#DF2A3F;">(replicas - partition)</font>` 数量的 Pod 更新到最新版本
+ 如果是百分比，控制器会将 `<font style="color:#DF2A3F;">(replicas * (100% - partition))</font>` 数量的 Pod 更新到最新版本

比如，我们将上面示例中的的 image 更新为 `<font style="color:#DF2A3F;">nginx:latest</font>` 并且设置 `<font style="color:#DF2A3F;">partition=2</font>`，更新后，过一会查看可以发现只升级了 2 个 Pod：

```shell
➜ kubectl apply -f cloneset-demo-v5.yaml 
cloneset.apps.kruise.io/cs-demo configured
###############################################################################################
# -l app=cs
# 标签选择器，筛选出所有包含标签 app=cs的 Pod。
# app是标签键，cs是标签值，表示这些 Pod 属于某个应用（如 cs可能是某个微服务的缩写）。
# 例如，若 Pod 定义中有 metadata.labels: app: cs，则会被匹配到。
#
# -L controller-revision-hash
# 指定显示的标签列，仅展示 Pod 的 controller-revision-hash标签值。
# 该标签由 Kubernetes 控制器（如 Deployment、StatefulSet）自动生成，用于标识 Pod 模板的版本。
# 通过此参数，可快速查看 Pod 对应的控制器修订版本，便于调试滚动更新或回滚问题。
###############################################################################################
➜ kubectl get pods -l app=cs -L controller-revision-hash
NAME            READY   STATUS    RESTARTS      AGE    CONTROLLER-REVISION-HASH
cs-demo-dx4lb   1/1     Running   0             69s    cs-demo-6599fc6cdd
cs-demo-fv5gb   1/1     Running   0             3d7h   cs-demo-7cb9c88699
cs-demo-nngtm   1/1     Running   0             8s     cs-demo-6599fc6cdd
cs-demo-p4kmw   1/1     Running   0             3d6h   cs-demo-7cb9c88699
```

此外 CloneSet 还支持一些更高级的用法，比如可以定义优先级策略来控制 Pod 发布的优先级规则，还可以定义策略来将一类 Pod 打散到整个发布过程中，也可以暂停 Pod 发布等操作。

## 4 Advanced StatefulSet
该控制器在原生的 StatefulSet 基础上增强了发布能力，比如 `<font style="color:#DF2A3F;">maxUnavailable</font>`<font style="color:#DF2A3F;"> </font>并行发布、原地升级等，该对象的名称也是 StatefulSet，但是 apiVersion 是 `<font style="color:#DF2A3F;">apps.kruise.io/v1beta1</font>`，这个 CRD 的所有默认字段、默认行为与原生 StatefulSet 完全一致，除此之外还提供了一些 optional 字段来扩展增强的策略。因此，用户从原生 StatefulSet 迁移到 Advanced StatefulSet，只需要把 apiVersion 修改后提交即可：

```yaml
-  apiVersion: apps/v1
+  apiVersion: apps.kruise.io/v1beta1 # 使用不同的 APIVersion
   kind: StatefulSet
   metadata:
     name: sample
   spec:
     # ......
```

### 4.1 最大不可用
Advanced StatefulSet 在滚动更新策略中新增了 `<font style="color:#DF2A3F;">maxUnavailable</font>` 来支持并行 Pod 发布，它会保证发布过程中最多有多少个 Pod 处于不可用状态。<u>💡</u><u>注意，</u>`<u><font style="color:#DF2A3F;">maxUnavailable</font></u>`<u> 只能配合 </u>`<u><font style="color:#DF2A3F;">podManagementPolicy</font></u>`<u><font style="color:#DF2A3F;"> </font></u><u>为 Parallel 来使用</u>。

:::color2
💡`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">SatefulSet</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">的滚动升级支持 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">Partitions</font>`<font style="color:rgb(28, 30, 33);">的特性，可以通过</font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">.spec.updateStrategy.rollingUpdate.partition</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">进行设置，在设置 partition 后，SatefulSet 的 Pod 中序号大于或等于 partition 的 Pod 会在 StatefulSet 的模板更新后进行滚动升级，而其余的 Pod 保持不变。</font>

:::

这个策略的效果和 Deployment 中的类似，但是可能会导致发布过程中的 order 顺序不能严格保证，如果不配置 `<font style="color:#DF2A3F;">maxUnavailable</font>`，它的默认值为 1，也就是和原生 StatefulSet 一样只能串行发布 Pod，即使把 `<font style="color:#DF2A3F;">podManagementPolicy</font>`<font style="color:#DF2A3F;"> </font>配置为 Parallel 也是这样。

比如现在我们创建一个如下所示的 Advanced StatefulSet：

```yaml
# AdvancedStatefulSet-web-v1.yaml
apiVersion: apps.kruise.io/v1beta1
kind: StatefulSet
metadata:
  name: web
  namespace: default
spec:
  serviceName: 'nginx-headless'
  podManagementPolicy: Parallel
  replicas: 5
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 3
      # partition: 4
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx # @
    spec:
      containers:
        - name: nginx
          image: nginx
          ports:
            - name: web
              containerPort: 80
```

直接创建该对象，由于对象名称也是 StatefulSet，所以不能直接用 `<font style="color:#DF2A3F;">get sts</font>` 来获取了，要通过 `<font style="color:#DF2A3F;">get asts</font>` 获取：

```shell
➜ kubectl apply -f AdvancedStatefulSet-web-v1.yaml 
statefulset.apps.kruise.io/web created

➜ kubectl get asts
NAME   DESIRED   CURRENT   UPDATED   READY   AGE
web    5         5         5         5       10s

➜ kubectl get pods -l app=nginx -L controller-revision-hash
NAME    READY   STATUS    RESTARTS   AGE   CONTROLLER-REVISION-HASH
web-0   1/1     Running   0          85s   web-b486b4959
web-1   1/1     Running   0          85s   web-b486b4959
web-2   1/1     Running   0          85s   web-b486b4959
web-3   1/1     Running   0          85s   web-b486b4959
web-4   1/1     Running   0          85s   web-b486b4959
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760432075701-6c729756-13cd-4fbf-a9de-f0519b09f5ad.png)

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760432084269-e763bb26-1381-460c-91dd-d04f78736e39.png)

该应用下有五个 Pod，假设应用能容忍 3 个副本不可用，当我们把 StatefulSet 里的 Pod 升级版本的时候，可以通过以下步骤来做：

1. 设置 `<font style="color:#DF2A3F;">maxUnavailable=3</font>`
2. (可选) 如果需要灰度升级，<u>设置 </u>`<u><font style="color:#DF2A3F;">partition=4</font></u>`<u>，Partition 默认的意思是 order 大于等于这个数值的 Pod 才会更新</u>，在这里就只会更新 P4，即使我们设置了 `<font style="color:#DF2A3F;">maxUnavailable=3</font>`。
3. 在 P4 升级完成后，把 `<font style="color:#DF2A3F;">partition</font>` 调整为 `<font style="color:#DF2A3F;">0</font>`，此时，控制器会同时升级 P1、P2、P3 三个 Pod。注意，如果是原生 StatefulSet，只能串行升级 P3、P2、P1。
4. 一旦这三个 Pod 中有一个升级完成了，控制器会立即开始升级 P0。

比如这里我们把上面应用的镜像版本进行修改，更新后查看 Pod 状态，可以看到有 3 个 Pod 并行升级的：

```yaml
# AdvancedStatefulSet-web-v2.yaml
apiVersion: apps.kruise.io/v1beta1
kind: StatefulSet
metadata:
  name: web
  namespace: default
spec:
  serviceName: 'nginx-headless'
  podManagementPolicy: Parallel
  replicas: 5
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 3
      partition: 4
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx # @
    spec:
      containers:
        - name: nginx
          image: nginx:1.7.9 # 更新镜像版本
          ports:
            - name: web
              containerPort: 80
```

```shell
➜ kubectl apply -f AdvancedStatefulSet-web-v2.yaml 
statefulset.apps.kruise.io/web configured

# 更新镜像
➜ kubectl get pods -l app=nginx 
NAME    READY   STATUS    RESTARTS   AGE
web-0   1/1     Running   0          4m20s
web-1   1/1     Running   0          4m20s
web-2   1/1     Running   0          4m20s
web-3   1/1     Running   0          4m20s
web-4   1/1     Running   0          84s
```

```yaml
# AdvancedStatefulSet-web-v3.yaml
apiVersion: apps.kruise.io/v1beta1
kind: StatefulSet
metadata:
  name: web
  namespace: default
spec:
  serviceName: 'nginx-headless'
  podManagementPolicy: Parallel
  replicas: 5
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 3
      partition: 0
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx # @
    spec:
      containers:
        - name: nginx
          image: nginx:1.7.9
          ports:
            - name: web
              containerPort: 80
```

```shell
➜ kubectl apply -f AdvancedStatefulSet-web-v3.yaml 
statefulset.apps.kruise.io/web configured

# 更新镜像
➜ kubectl get pods -l app=nginx 
NAME    READY   STATUS              RESTARTS   AGE
web-0   1/1     Running             0          6m20s
web-1   0/1     ContainerCreating   0          5s
web-2   0/1     ContainerCreating   0          5s
web-3   0/1     ContainerCreating   0          5s
web-4   1/1     Running             0          3m25s
# 最后会将 web-0 Pod 进行更新
```

### 4.2 原地升级
Advanced StatefulSet 增加了 `<font style="color:#DF2A3F;">podUpdatePolicy</font>`<font style="color:#DF2A3F;"> </font>来允许用户指定重建升级还是原地升级。此外还在<font style="color:#DF2A3F;">原地升级中提供了 Graceful Period 选项，作为优雅原地升级的策略</font>。用户如果配置了 `<font style="color:#DF2A3F;">gracePeriodSeconds</font>`<font style="color:#DF2A3F;"> </font>这个字段，控制器在原地升级的过程中会先把 Pod Status 改为 Not-Ready，然后等一段时间（`<font style="color:#DF2A3F;">gracePeriodSeconds</font>`），最后再去修改 Pod spec 中的镜像版本。这样，就为 endpoints-controller 这些控制器留出了充足的时间来将 Pod 从 endpoints 端点列表中去除。

如果使用 `<font style="color:#DF2A3F;">InPlaceIfPossible</font>` 或 `<font style="color:#DF2A3F;">InPlaceOnly</font>`<font style="color:#DF2A3F;"> </font>策略，必须要增加一个 `<font style="color:#DF2A3F;">InPlaceUpdateReady readinessGate</font>`，用来在原地升级的时候控制器将 Pod 设置为 NotReady，比如设置上面的应用为原地升级的方式：

```yaml
# AdvancedStatefulSet-web-InPlaceIfPossible.yaml
apiVersion: apps.kruise.io/v1beta1
kind: StatefulSet
metadata:
  name: web
  namespace: default
spec:
  serviceName: 'nginx-headless'
  podManagementPolicy: Parallel
  replicas: 5
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      podUpdatePolicy: InPlaceIfPossible # 尽可能执行原地升级
      maxUnavailable: 3 # 允许并行更新，最大不可以实例数为3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      readinessGates:
        - conditionType: InPlaceUpdateReady # 一个新的条件，可确保 Pod 在发生原地更新时保持在 NotReady 状态
      containers:
        - name: nginx
          image: nginx
          ports:
            - name: web
              containerPort: 80
```

这里我们设置 `<font style="color:#DF2A3F;">updateStrategy.rollingUpdate.podUpdatePolicy</font>` 为 `<font style="color:#DF2A3F;">InPlaceIfPossible</font>`<font style="color:#DF2A3F;"> </font>模式，表示尽可能使用原地升级的方式进行更新，此外在 Pod 模板中我们还添加了一个 `<font style="color:#DF2A3F;">readinessGates</font>`<font style="color:#DF2A3F;"> </font>属性，可以用来确保 Pod 在发生原地更新时保持在 NotReady 状态。比如我们现在使用上面资源清单更新应用，然后重新修改镜像的版本更新，则会进行原地升级：

```shell
➜ kubectl apply -f AdvancedStatefulSet-web-InPlaceIfPossible.yaml 
statefulset.apps.kruise.io/web configured

➜ kubectl describe asts web
Events:
  Type    Reason                      Age                  From                    Message
  ----    ------                      ----                 ----                    -------
  Normal  SuccessfulUpdatePodInPlace  3m30s                statefulset-controller  successfully update pod web-4 in-place(revision web-84644dfc7d)
  Normal  SuccessfulUpdatePodInPlace  3m30s                statefulset-controller  successfully update pod web-3 in-place(revision web-84644dfc7d)
  Normal  SuccessfulUpdatePodInPlace  3m30s                statefulset-controller  successfully update pod web-2 in-place(revision web-84644dfc7d)
```

同样的 Advanced StatefulSet 也支持原地升级自动预热。

也可以通过设置 `<font style="color:#DF2A3F;">paused</font>` 为 `<font style="color:#DF2A3F;">true</font>` 来暂停发布，不过控制器还是会做 replicas 数量管理：

```yaml
apiVersion: apps.kruise.io/v1beta1
kind: StatefulSet
spec:
  # [......]
  updateStrategy:
    rollingUpdate:
      paused: true
```

另外 Advanced StatefulSet 还支持序号保留功能，通过在 `<font style="color:#DF2A3F;">reserveOrdinals</font>`<font style="color:#DF2A3F;"> </font>字段中写入需要保留的序号，Advanced StatefulSet 会自动跳过创建这些序号的 Pod，如果 Pod 已经存在，则会被删除。

注意，`<font style="color:#DF2A3F;">spec.replicas</font>` 是期望运行的 Pod 数量，`<font style="color:#DF2A3F;">spec.reserveOrdinals</font>` 是要跳过的序号。

```yaml
apiVersion: apps.kruise.io/v1beta1
kind: StatefulSet
spec:
  # [......]
  replicas: 4
  reserveOrdinals:
    - 1
```

比如上面的描述 `<font style="color:#DF2A3F;">replicas=4, reserveOrdinals=[1]</font>` 的 Advanced StatefulSet，表示实际运行的 Pod 序号为 [0,2,3,4]。

+ 如果要把 Pod-3 做迁移并保留序号，则把 3 追加到 reserveOrdinals 列表中，控制器会把 Pod-3 删除并创建 Pod-5（此时运行中 Pod 为 `<font style="color:#DF2A3F;">[0,2,4,5]</font>`）。
+ 如果只想删除 Pod-3，则把 3 追加到 reserveOrdinals 列表并同时把 replicas 减一修改为 3。控制器会把 Pod-3 删除（此时运行中 Pod 为 `<font style="color:#DF2A3F;">[0,2,4]</font>`）。

为了避免在一个新 Advanced StatefulSet 创建后有大量失败的 pod 被创建出来，从 Kruise v0.10.0 版本开始引入了在 scale strategy 中的 maxUnavailable 策略。

```yaml
apiVersion: apps.kruise.io/v1beta1
kind: StatefulSet
spec:
  # [......]
  replicas: 100
  scaleStrategy:
    maxUnavailable: 10% # percentage or absolute number
```

当这个字段被设置之后，Advanced StatefulSet 会保证创建 Pod 之后不可用 Pod 数量不超过这个限制值。比如说，上面这个 StatefulSet 一开始只会一次性创建 `<font style="color:#DF2A3F;">100 * 10%=10</font>` 个 Pod，在此之后，每当一个 Pod 变为 running、ready 状态后，才会再创建一个新 Pod 出来。

:::color2
注意，这个功能只允许在 `<font style="color:#DF2A3F;">podManagementPolicy</font>` 是 `<font style="color:#DF2A3F;">Parallel</font>`<font style="color:#DF2A3F;"> </font>的 StatefulSet 中使用。

:::

## 5 Advanced DaemonSet
这个控制器基于原生 DaemonSet 上增强了发布能力，比如灰度分批、按 `<font style="color:#DF2A3F;">Node Label</font>` 选择、暂停、热升级等。同样的该对象的 Kind 名字也是 DaemonSet，只是 apiVersion 是 `<font style="color:#DF2A3F;">apps.kruise.io/v1alpha1</font>`，这个 CRD 的所有默认字段、默认行为与原生 DaemonSet 完全一致，除此之外还提供了一些 optional 字段来扩展增强的策略。

因此，用户从原生 DaemonSet 迁移到 Advanced DaemonSet，只需要把 apiVersion 修改后提交即可：

```yaml
-  apiVersion: apps/v1
+  apiVersion: apps.kruise.io/v1alpha1
   kind: DaemonSet
   metadata:
     name: sample-ds
   spec:
     # ......
```

### 5.1 升级
Advanced DaemonSet 在 `<font style="color:#DF2A3F;">spec.updateStrategy.rollingUpdate</font>` 中有一个<font style="color:#DF2A3F;"> </font>`<font style="color:#DF2A3F;">rollingUpdateType</font>`<font style="color:#DF2A3F;"> </font>字段，标识了如何进行滚动升级：

+ `<font style="color:#DF2A3F;">Standard</font>`: 对于每个节点，控制器会先删除旧的 daemon Pod，再创建一个新 Pod，和原生 DaemonSet 行为一致。
+ `<font style="color:#DF2A3F;">Surging</font>`: 对于每个 node，控制器会先创建一个新 Pod，等它 ready 之后再删除老 Pod。

创建如下所示的资源对象：

```yaml
# AdvancedDaemon-nginx.yaml
apiVersion: apps.kruise.io/v1alpha1
kind: DaemonSet
metadata:
  name: nginx
  namespace: default
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      rollingUpdateType: Standard
  selector:
    matchLabels:
      k8s-app: nginx
  template:
    metadata:
      labels:
        k8s-app: nginx
    spec:
      containers:
        - image: nginx:1.7.9
          name: nginx
          ports:
            - name: http
              containerPort: 80
```

创建后需要通过 `<font style="color:#DF2A3F;">get daemon</font>` 来获取该对象：

```shell
➜ kubectl apply -f AdvancedDaemon-nginx.yaml 
daemonset.apps.kruise.io/nginx created

# 这里将 Master 节点的污点去除
➜ kubectl get daemon
NAME    DESIREDNUMBER   CURRENTNUMBER   UPDATEDNUMBERSCHEDULED   AGE
nginx   3               3               3                        10s

➜ kubectl get pods -l k8s-app=nginx -o wide
NAME          READY   STATUS    RESTARTS   AGE   IP               NODE             NOMINATED NODE   READINESS GATES
nginx-j72sm   1/1     Running   0          45s   192.244.211.46   hkk8snode001     <none>           1/1
nginx-k6gxt   1/1     Running   0          45s   192.244.51.232   hkk8snode002     <none>           1/1
nginx-mg757   1/1     Running   0          45s   192.244.22.223   hkk8smaster001   <none>           1/1
```

我们这里只有两个 Work 节点，所以一共运行了 2 个 Pod（Master 节点去掉污点，会加上 Master 节点的 Pod），每个节点上一个，和默认的 DaemonSet 行为基本一致。此外这个策略还支持用户通过配置 node 标签的 selector，来指定灰度升级某些特定类型 node 上的 Pod，比如现在我们只升级 hkk8snode001 节点的应用，则可以使用 `<font style="color:#DF2A3F;">selector</font>`<font style="color:#DF2A3F;"> </font>标签来标识：

```yaml
apiVersion: apps.kruise.io/v1alpha1
kind: DaemonSet
spec:
  # [......]
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      rollingUpdateType: Standard
      selector: # 选择只能更新的 Node 节点
        matchLabels:
          kubernetes.io/hostname: hkk8snode001
# [......]
    spec:
      containers:
        - image: nginx:1.8.1
```

更新应用后可以看到只会更新 hkk8snode001 节点上的 Pod：

```shell
➜ kubectl apply -f AdvancedDaemon-nginx.yaml 
daemonset.apps.kruise.io/nginx created

# 查看描述信息
➜ kubectl describe daemon nginx
Name:         nginx
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  apps.kruise.io/v1alpha1
Kind:         DaemonSet
[......]
Events:
  Type    Reason            Age   From                  Message
  ----    ------            ----  ----                  -------
  Normal  SuccessfulCreate  109s  daemonset-controller  Created pod: nginx-mg757
  Normal  SuccessfulCreate  109s  daemonset-controller  Created pod: nginx-j72sm
  Normal  SuccessfulCreate  109s  daemonset-controller  Created pod: nginx-k6gxt
  Normal  SuccessfulDelete  12s   daemonset-controller  Deleted pod: nginx-j72sm
  Normal  SuccessfulCreate  11s   daemonset-controller  Created pod: nginx-qn899

# 查看 Pod 的镜像信息
$ kubectl get pods -l k8s-app=nginx -o wide
NAME          READY   STATUS    RESTARTS   AGE     IP               NODE             NOMINATED NODE   READINESS GATES
nginx-k6gxt   1/1     Running   0          2m25s   192.244.51.232   hkk8snode002     <none>           1/1
nginx-mg757   1/1     Running   0          2m25s   192.244.22.223   hkk8smaster001   <none>           1/1
nginx-qn899   1/1     Running   0          45s     192.244.211.47   hkk8snode001     <none>           1/1
```

和前面两个控制器一样，Advanced DaemonSet 也支持分批灰度升级，使用 Partition 进行配置，Partition 的语义是**<font style="color:#DF2A3F;">保留旧版本 Pod 的数量</font>**，默认为 0，如果在发布过程中设置了 partition，则控制器只会将 `<font style="color:#DF2A3F;">(status.DesiredNumberScheduled - partition)</font>` 数量的 Pod 更新到最新版本。

```yaml
apiVersion: apps.kruise.io/v1alpha1
kind: DaemonSet
spec:
  # [......]
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 10
      paused: true # 暂停发布
```

同样 Advanced DaemonSet 也是支持原地升级的，只需要设置 `<font style="color:#DF2A3F;">rollingUpdateType</font>`<font style="color:#DF2A3F;"> </font>为支持原地升级的类型即可，比如这里我们将上面的应用升级方式设置为 `<font style="color:#DF2A3F;">InPlaceIfPossible</font>` 即可：

```yaml
apiVersion: apps.kruise.io/v1alpha1
kind: DaemonSet
spec:
  # [......]
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      rollingUpdateType: InPlaceIfPossible
```

更新后可以通过查看控制器的事件来验证是否是通过原地升级方式更新应用：

```shell
➜ kubectl apply -f AdvancedDaemon-nginx.yaml 
daemonset.apps.kruise.io/nginx configured

# 查看 Daemon 的详细信息
➜ kubectl describe daemon nginx
Name:         nginx
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  apps.kruise.io/v1alpha1
Kind:         DaemonSet
[......]
Events:
  Type     Reason                            Age               From                  Message
  ----     ------                            ----              ----                  -------
  Normal   SuccessfulCreate                  16m               daemonset-controller  Created pod: nginx-k6gxt
  Normal   SuccessfulDelete                  14m               daemonset-controller  Deleted pod: nginx-j72sm
  Normal   SuccessfulCreate                  14m               daemonset-controller  Created pod: nginx-qn899
  Normal   SuccessfulDelete                  8s                daemonset-controller  Deleted pod: nginx-mg757
  Normal   SuccessfulCreate                  7s                daemonset-controller  Created pod: nginx-zg4qz
  Normal   SuccessfulDelete                  6s                daemonset-controller  Deleted pod: nginx-k6gxt
  Warning  numUnavailable >= maxUnavailable  5s (x16 over 8s)  daemonset-controller  default/nginx number of unavailable DaemonSet pods: 1, is equal to or exceeds allowed maximum: 1
  Normal   SuccessfulCreate                  4s                daemonset-controller  Created pod: nginx-ng8ds
```

## 6 BroadcastJob
这个控制器将 Pod 分发到集群中每个节点上，类似于 DaemonSet，但是 BroadcastJob 管理的 Pod 并不是长期运行的 daemon 服务，而是类似于 Job 的任务类型 Pod，在每个节点上的 Pod 都执行完成退出后，BroadcastJob 和这些 Pod 并不会占用集群资源。 这个控制器非常有利于做升级基础软件、巡检等过一段时间需要在整个集群中跑一次的工作。

比如我们声明一个如下所示的 BroadcastJob 对象：

```yaml
# BroadcastJob-bcj-demo.yaml
apiVersion: apps.kruise.io/v1alpha1
kind: BroadcastJob
metadata:
  name: bcj-demo
  namespace: default
spec:
  template:
    spec:
      restartPolicy: Never
      containers: # 一定不是一个常驻前台的进程，一定是一个任务，执行完成后需要退出的
        - name: counter
          image: busybox
          command:
            - '/bin/sh'
            - '-c'
            - 'for i in 9 8 7 6 5 4 3 2 1; do echo $i; done'
```

直接创建上面的资源对象，

```shell
➜ kubectl apply -f BroadcastJob-bcj-demo.yaml 
broadcastjob.apps.kruise.io/bcj-demo created

➜ kubectl get bcj bcj-demo
NAME       DESIRED   ACTIVE   SUCCEEDED   FAILED   AGE
bcj-demo   3         0        3           0        10s

➜ kubectl get pods -o wide -l broadcastjob-name=bcj-demo
NAME             READY   STATUS      RESTARTS   AGE   IP               NODE             NOMINATED NODE   READINESS GATES
bcj-demo-265bx   0/1     Completed   0          45s   192.244.211.48   hkk8snode001     <none>           1/1
bcj-demo-2qcst   0/1     Completed   0          45s   192.244.22.225   hkk8smaster001   <none>           1/1
bcj-demo-d25gq   0/1     Completed   0          45s   192.244.51.234   hkk8snode002     <none>           1/1
```

我们可以看到创建了一个 BroadcastJob 对象后，同时启动了两个 Pod 任务，每个节点上一个，这和原生的 Job 是不太一样的。创建的 BroadcastJob 一共有以下几种状态：

+ `<font style="color:#DF2A3F;">Desired</font>`<font style="color:#DF2A3F;"> </font>: 期望的 Pod 数量（等同于当前集群中匹配的节点数量）
+ `<font style="color:#DF2A3F;">Active</font>`<font style="color:#DF2A3F;"> </font>: 运行中的 Pod 数量
+ `<font style="color:#DF2A3F;">SUCCEEDED</font>`<font style="color:#DF2A3F;"> </font>: 执行成功的 Pod 数量
+ `<font style="color:#DF2A3F;">FAILED</font>`<font style="color:#DF2A3F;"> </font>: 执行失败的 Pod 数量

此外在 BroadcastJob 对象中还可以配置任务完成后的一些策略，比如配置 `<font style="color:#DF2A3F;">completionPolicy.ttlSecondsAfterFinished: 30</font>`，表示这个 Job 会在执行结束后 `<font style="color:#DF2A3F;">30s</font>` 被删除。

```yaml
apiVersion: apps.kruise.io/v1alpha1
kind: BroadcastJob
# [......]
spec:
  completionPolicy:
    type: Always
    ttlSecondsAfterFinished: 30
  # [......]
```

配置 `<font style="color:#DF2A3F;">completionPolicy.activeDeadlineSeconds</font>` 为 `<font style="color:#DF2A3F;">10</font>`，表示这个 Job 会在运行超过 10s 之后被标记为失败，并把下面还在运行的 Pod 删除掉。

```yaml
apiVersion: apps.kruise.io/v1alpha1
kind: BroadcastJob
# [......]
spec:
  completionPolicy:
    type: Always
    activeDeadlineSeconds: 10
  # [......]
```

`<font style="color:#DF2A3F;">completionPolicy</font>` 类型除了 `<font style="color:#DF2A3F;">Always</font>` 之外还可以设置为 `<font style="color:#DF2A3F;">Never</font>`，表示这个 Job 会持续运行即使当前所有节点上的 Pod 都执行完成了。

```yaml
apiVersion: apps.kruise.io/v1alpha1
kind: BroadcastJob
# [......]
spec:
  completionPolicy:
    type: Never
  # [......]
```

## 7 AdvancedCronJob
AdvancedCronJob 是对于原生 CronJob 的扩展版本，根据用户设置的 schedule 规则，周期性创建 Job 执行任务，而 AdvancedCronJob 的 template 支持多种不同的 job 资源：

```yaml
apiVersion: apps.kruise.io/v1alpha1
kind: AdvancedCronJob
spec:
  template:
    # Option 1: use jobTemplate, which is equivalent to original CronJob
    jobTemplate:
      # [......]
    # Option 2: use broadcastJobTemplate, which will create a BroadcastJob object when cron schedule triggers
    broadcastJobTemplate:
      # [......]
```

+ `<font style="color:#DF2A3F;">jobTemplate</font>`：与原生 CronJob 一样创建 Job 执行任务
+ `<font style="color:#DF2A3F;">broadcastJobTemplate</font>`：周期性创建 BroadcastJob 执行任务

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1730551629995-655a3150-1959-44a0-a093-15778452482c.png)

```yaml
# AdvancedCronJob-acj-test.yaml
apiVersion: apps.kruise.io/v1alpha1
kind: AdvancedCronJob
metadata:
  name: acj-test
spec:
  schedule: '*/1 * * * *'
  template:
    broadcastJobTemplate:
      spec:
        completionPolicy:
          type: Always
          ttlSecondsAfterFinished: 30
        template:
          spec:
            restartPolicy: Never
            containers: # 一定不是一个常驻前台的进程，一定是一个任务，执行完成后需要退出的
              - name: counter
                image: busybox
                command:
                  - '/bin/sh'
                  - '-c'
                  - 'for i in 9 8 7 6 5 4 3 2 1; do echo $i; done'
```

上述 YAML 定义了一个 `<font style="color:#DF2A3F;">AdvancedCronJob</font>`，每分钟创建一个 `<font style="color:#DF2A3F;">BroadcastJob</font>` 对象，这个 `<font style="color:#DF2A3F;">BroadcastJob</font>` 会在所有节点上运行一个 job 任务。

```shell
➜ kubectl apply -f AdvancedCronJob-acj-test.yaml
advancedcronjob.apps.kruise.io/acj-test created

➜ kubectl get acj
NAME       SCHEDULE      TYPE           LASTSCHEDULETIME   AGE
acj-test   */1 * * * *   BroadcastJob                      10s

➜ kubectl get bcj
NAME                  DESIRED   ACTIVE   SUCCEEDED   FAILED   AGE
acj-test-1760434260   3         0        3           0        10s

➜ kubectl get pods -l broadcastjob-name=acj-test-1760434260 -o wide 
NAME                        READY   STATUS      RESTARTS   AGE   IP               NODE             NOMINATED NODE   READINESS GATES
acj-test-1760434260-9df4p   0/1     Completed   0          10s   192.244.22.227   hkk8smaster001   <none>           1/1
acj-test-1760434260-ndlb2   0/1     Completed   0          10s   192.244.51.236   hkk8snode002     <none>           1/1
acj-test-1760434260-t2ldq   0/1     Completed   0          10s   192.244.211.50   hkk8snode001     <none>           1/1
```

## 8 SidecarSet
SidecarSet 支持通过 Admission Webhook 来自动为集群中创建的符合条件的 Pod 注入 Sidecar 容器，除了在 Pod 创建时候注入外，SidecarSet 还提供了为 Pod 原地升级其中已经注入的 Sidecar 容器镜像的能力。SidecarSet 将 Sidecar 容器的定义和生命周期与业务容器解耦，它主要用于管理无状态的 Sidecar 容器，比如监控、日志等 Agent。

比如我们定义一个如下所示的 SidecarSet 资源对象：

```yaml
# sidecarset.yaml
apiVersion: apps.kruise.io/v1alpha1
kind: SidecarSet
metadata:
  name: test-sidecarset
spec:
  selector: # 匹配的 Pods 才会添加 sidecar Container
    matchLabels:
      app: nginx
  updateStrategy:
    type: RollingUpdate
    maxUnavailable: 1
  containers:
    - name: sidecar1
      image: busybox
      command: ['sleep', '999d']
      volumeMounts:
        - name: log-volume
          mountPath: /var/log
  volumes: # this field will be merged into pod.spec.volumes
    - name: log-volume
      emptyDir: {}
```

直接创建这个资源对象即可：

```shell
➜ kubectl apply -f sidecarset.yaml 
sidecarset.apps.kruise.io/test-sidecarset created

➜ kubectl get sidecarset
NAME              MATCHED   UPDATED   READY   AGE
test-sidecarset   0         0         0       10s
```

需要注意上面我们在定义 <u><font style="color:#DF2A3F;">SidecarSet 对象的时候里面有一个非常重要的属性就是 Label Selector</font></u>，会去匹配具有 `<font style="color:#DF2A3F;">app=nginx</font>` 的 Pod，然后向其中注入下面定义的 `<font style="color:#DF2A3F;">sidecar1</font>`<font style="color:#DF2A3F;"> </font>这个容器，比如定义如下所示的一个 Pod，该 Pod 中包含 `<font style="color:#DF2A3F;">app=nginx</font>` 的标签，这样可以和上面的 SidecarSet 对象匹配：

```yaml
# test-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: nginx # matches the SidecarSet's selector
  name: test-pod
spec:
  containers:
    - name: app
      image: nginx:1.7.9
      ports:
        - containerPort: 80
```

直接创建上面的资源对象：

```shell
➜ kubectl apply -f test-pod.yaml 
pod/test-pod created

➜ kubectl get pod test-pod
NAME       READY   STATUS    RESTARTS   AGE
test-pod   2/2     Running   0          15s
```

可以看到该 Pod 中有 2 个容器，被自动注入了上面定义的 `<font style="color:#DF2A3F;">sidecar1</font>`<font style="color:#DF2A3F;"> </font>容器：

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761210800943-b50c98e9-65dc-4663-908b-c0fb54f00c98.png)

```yaml
➜ kubectl get pod test-pod -o yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: nginx
  name: test-pod
  namespace: default
[......]
spec:
  containers:
  - command:
    - sleep
    - 999d
    env:
    - name: IS_INJECTED
      value: "true"
    image: busybox
    imagePullPolicy: Always
    name: sidecar1
    resources: {}
    terminationMessagePath: /dev/termination-log
    terminationMessagePolicy: File
    volumeMounts:
    - mountPath: /var/log
      name: log-volume
    - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      name: kube-api-access-vkkx6
      readOnly: true
  - image: nginx:1.7.9
    imagePullPolicy: IfNotPresent
    name: app
    resources: {}
    terminationMessagePath: /dev/termination-log
    terminationMessagePolicy: File
    volumeMounts:
    - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      name: kube-api-access-vkkx6
      readOnly: true
  volumes:
  - name: kube-api-access-vkkx6
    projected:
      defaultMode: 420
      sources:
      - serviceAccountToken:
          expirationSeconds: 3607
          path: token
      - configMap:
          items:
          - key: ca.crt
            path: ca.crt
          name: kube-root-ca.crt
      - downwardAPI:
          items:
          - fieldRef:
              apiVersion: v1
              fieldPath: metadata.namespace
            path: namespace
  - emptyDir: {}
    name: log-volume
......
```

现在我们去更新 SidecarSet 中的 sidecar 容器镜像替换成 `<font style="color:#DF2A3F;">busybox:1.35.0</font>`：

```shell
➜ kubectl patch sidecarset test-sidecarset --type='json' -p='[{"op": "replace", "path": "/spec/containers/0/image", "value": "busybox:1.35.0"}]'
sidecarset.apps.kruise.io/test-sidecarset patched
```

更新后再去查看 Pod 中的 sidecar 容器：

```shell
➜ kubectl get pod test-pod
NAME       READY   STATUS    RESTARTS   AGE
test-pod   2/2     Running   0          2m15s

➜ kubectl get pod test-pod
Name:             test-pod
Namespace:        default
Priority:         0
Service Account:  default
Node:             hkk8snode001/192.168.178.36
Start Time:       Tue, 14 Oct 2025 17:38:34 +0800
Labels:           app=nginx
[......]
Events:
  Type    Reason     Age                 From               Message
  ----    ------     ----                ----               -------
  Normal  Scheduled  2m46s               default-scheduler  Successfully assigned default/test-pod to hkk8snode001
  Normal  Pulling    2m45s               kubelet            Pulling image "busybox"
  Normal  Pulled     2m44s               kubelet            Successfully pulled image "busybox" in 1.574243977s (1.574256956s including waiting)
  Normal  Pulled     2m43s               kubelet            Container image "nginx:1.7.9" already present on machine
  Normal  Created    2m43s               kubelet            Created container app
  Normal  Started    2m43s               kubelet            Started container app
  Normal  Killing    45s                 kubelet            Container sidecar1 definition changed, will be restarted
  Normal  Pulling    14s                 kubelet            Pulling image "busybox:1.35.0"
  Normal  Pulled     7s                  kubelet            Successfully pulled image "busybox:1.35.0" in 7.675962725s (7.675984149s including waiting)
  Normal  Created    6s (x2 over 2m44s)  kubelet            Created container sidecar1
  Normal  Started    6s (x2 over 2m43s)  kubelet            Started container sidecar1

# 过滤镜像
➜ kubectl get pod test-pod -o yaml | grep busybox
    kruise.io/sidecarset-inplace-update-state: '{"test-sidecarset":{"revision":"f78z4854d9855xd6478fzx9c84645z2548v24z26455db46bdfzw44v49v98f2cw","updateTimestamp":"2025-10-14T09:40:35Z","lastContainerStatuses":{"sidecar1":{"imageID":"docker.io/library/busybox@sha256:ab33eacc8251e3807b85bb6dba570e4698c3998eca6f0fc2ccb60575a563ea74"}}}}'
    image: busybox:1.35.0
    image: docker.io/library/busybox:1.35.0
    imageID: docker.io/library/busybox@sha256:98ad9d1a2be345201bb0709b0d38655eb1b370145c7d94ca1fe9c421f76e245a
```

可以看到 Pod 中的 Sidecar 容器镜像被原地升级成 `<font style="color:#DF2A3F;">busybox:1.35.0</font>` 了， 对主容器没有产生任何影响。

### 8.1 同意特性
需要注意的是 Sidecar 的注入只会发生在 Pod 创建阶段，并且只有 Pod spec 会被更新，不会影响 Pod 所属的 workload template 模板。<font style="color:#DF2A3F;"> </font>`<font style="color:#DF2A3F;">spec.containers</font>` 除了默认的 Kubernetes Container 字段，还扩展了如下一些字段，来方便注入：

```yaml
# SidecarSet-BeforeAppContainer.yaml
apiVersion: apps.kruise.io/v1alpha1
kind: SidecarSet
metadata:
  name: sidecarset
spec:
  selector:
    matchLabels:
      app: sample
  containers:
    # 默认的K8S容器字段
    - name: nginx
      image: nginx:alpine
      volumeMounts:
        - mountPath: /nginx/conf
          name: nginx.conf
      # 扩展的sidecar容器字段
      podInjectPolicy: BeforeAppContainer
      shareVolumePolicy:
        type: disabled | enabled
      transferEnv:
        - sourceContainerName: main
          envName: PROXY_IP
  volumes:
    - Name: nginx.conf
      hostPath: /data/nginx/conf
```

+ `<font style="color:#DF2A3F;">podInjectPolicy</font>`<font style="color:#DF2A3F;"> </font>定义了容器 注入到 `<font style="color:#DF2A3F;">pod.spec.containers</font>` 中的位置
    - `<font style="color:#DF2A3F;">BeforeAppContainer</font>`：表示注入到 Pod 原 Containers 的前面（(默认) ）
    - `<font style="color:#DF2A3F;">AfterAppContainer</font>`： 表示注入到 Pod 原 Containers 的后面
+ 数据卷共享
    - 共享指定卷：通过 `<font style="color:#DF2A3F;">spec.volumes</font>` 来定义 Sidecar 自身需要的 Volume
    - 共享所有卷：通过 `<font style="color:#DF2A3F;">spec.containers[i].shareVolumePolicy.type = enabled | disabled</font>` 来控制是否挂载 pod 应用容器的卷，常用于日志收集等 Sidecar，配置为 `<font style="color:#DF2A3F;">enabled</font>`<font style="color:#DF2A3F;"> </font>后会把应用容器中所有挂载点注入 sidecar 同一路经下(Sidecar 中本身就有声明的数据卷和挂载点除外）
+ 环境变量共享：可以通过 `<font style="color:#DF2A3F;">spec.containers[i].transferEnv</font>` 来从别的容器获取环境变量，会把名为 `<font style="color:#DF2A3F;">sourceContainerName</font>`<font style="color:#DF2A3F;"> </font>容器中名为 `<font style="color:#DF2A3F;">envName</font>`<font style="color:#DF2A3F;"> </font>的环境变量拷贝到本容器

SidecarSet 不仅支持 sidecar 容器的原地升级，而且提供了非常丰富的升级、灰度策略。同样在 SidecarSet 对象中 `<font style="color:#DF2A3F;">updateStrategy</font>`<font style="color:#DF2A3F;"> </font>属性下面也可以配置 `<font style="color:#DF2A3F;">partition</font>`<font style="color:#DF2A3F;"> </font>来定义保留旧版本 Pod 的数量或百分比，默认为 0；同样还可以配置的有 `<font style="color:#DF2A3F;">maxUnavailable</font>`<font style="color:#DF2A3F;"> </font>属性，表示在发布过程中的最大不可用数量。

+ 当 `<font style="color:#DF2A3F;">{matched pod}=100,partition=50,maxUnavailable=10</font>`，控制器会发布 50 个 Pod 到新版本，但是同一时间只会发布 10 个 Pod，每发布好一个 Pod 才会再找一个发布，直到 50 个发布完成。
+ 当<font style="color:#DF2A3F;"> </font>`<font style="color:#DF2A3F;">{matched pod}=100,partition=80,maxUnavailable=30</font>`，控制器会发布 20 个 Pod 到新版本，因为满足 maxUnavailable 数量，所以这 20 个 Pod 会同时发布。

同样也可以设置 `<font style="color:#DF2A3F;">paused: true</font>` 来暂停发布，此时对于新创建的、扩容的 pod 依旧会实现注入能力，已经更新的 pod 会保持更新后的版本不动，还没有更新的 pod 会暂停更新。

```yaml
apiVersion: apps.kruise.io/v1alpha1
kind: SidecarSet
metadata:
  name: sidecarset
spec:
  # [......]
  updateStrategy:
    type: RollingUpdate
    maxUnavailable: 20%
    partition: 10
    paused: true
```

### 8.2 金丝雀发布
对于有金丝雀发布需求的业务，可以通过 `<font style="color:#DF2A3F;">selector</font>`<font style="color:#DF2A3F;"> </font>来实现，对于需要率先金丝雀灰度的 pod 打上固定的 `<font style="color:#DF2A3F;">[canary.release] = true</font>` 的标签，再通过 `<font style="color:#DF2A3F;">selector.matchLabels</font>` 来选中该 pod 即可。

比如现在我们有一个 3 副本的 Pod，也具有 `<font style="color:#DF2A3F;">app=nginx</font>` 的标签，如下所示

```yaml
# Deployment-nginx.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: default
spec:
  replicas: 3
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: ngx
          image: nginx:1.7.9
          ports:
            - containerPort: 80
```

创建后现在就具有 4 个 `<font style="color:#DF2A3F;">app=nginx</font>` 标签的 Pod 了，由于都匹配上面创建的 SidecarSet 对象，所以都会被注入一个 `<font style="color:#DF2A3F;">sidecar1</font>`<font style="color:#DF2A3F;"> </font>的容器，镜像为 `<font style="color:#DF2A3F;">busybox</font>`：

```shell
➜ kubectl apply -f Deployment-nginx.yaml 
deployment.apps/nginx created

➜ kubectl get pods -l app=nginx
NAME                     READY   STATUS    RESTARTS        AGE
nginx-678766d944-4s9rn   2/2     Running   0               15s
nginx-678766d944-cfqx9   2/2     Running   0               15s
nginx-678766d944-z24z5   2/2     Running   0               15s
test-pod                 2/2     Running   1 (5m59s ago)   8m30s
```

现在如果我们想为 `<font style="color:#DF2A3F;">test-pod</font>` 这个应用来执行灰度策略，将 Sidecar 容器镜像更新成 `<font style="color:#DF2A3F;">busybox:1.35.0</font>`，则可以在 `<font style="color:#DF2A3F;">updateStrategy</font>`<font style="color:#DF2A3F;"> </font>下面添加 `<font style="color:#DF2A3F;">selector.matchLabels</font>` 属性 `<font style="color:#DF2A3F;">canary.release: "true"</font>`：

```yaml
# test-sidecarset.yaml
apiVersion: apps.kruise.io/v1alpha1
kind: SidecarSet
metadata:
  name: test-sidecarset
spec:
  selector:
    matchLabels:
      app: nginx
  updateStrategy:
    type: RollingUpdate
    selector:
      matchLabels:
        canary.release: 'true'
  containers:
    - name: sidecar1
      image: busybox:1.35.0
      command: ['sleep', '999d']
      volumeMounts:
        - name: log-volume
          mountPath: /var/log
  volumes: # this field will be merged into pod.spec.volumes
    - name: log-volume
      emptyDir: {}
  # [......]
```

然后同样需要给 `<font style="color:#DF2A3F;">test-pod</font>` 添加上 `<font style="color:#DF2A3F;">canary.release=true</font>` 这个标签：

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: nginx
    canary.release: 'true'
  name: test-pod
spec:
  containers:
    - name: app
      image: nginx:1.7.9
```

更新后可以发现 test-pod 的 sidecar 镜像更新了，其他 Pod 没有变化，这样就实现了 sidecar 的灰度功能：

```shell
➜ kubectl describe pod test-pod
Name:             test-pod
Namespace:        default
Priority:         0
Service Account:  default
Node:             hkk8snode001/192.168.178.36
Start Time:       Tue, 14 Oct 2025 17:38:34 +0800
Labels:           app=nginx
                  canary.release=true
[......]
Events:
  Type    Reason     Age                From               Message
  ----    ------     ----               ----               -------
  Normal  Scheduled  13m                default-scheduler  Successfully assigned default/test-pod to hkk8snode001
  Normal  Pulling    13m                kubelet            Pulling image "busybox"
  Normal  Pulled     12m                kubelet            Successfully pulled image "busybox" in 1.574243977s (1.574256956s including waiting)
  Normal  Pulled     12m                kubelet            Container image "nginx:1.7.9" already present on machine
  Normal  Created    12m                kubelet            Created container app
  Normal  Started    12m                kubelet            Started container app
  Normal  Killing    11m                kubelet            Container sidecar1 definition changed, will be restarted
  Normal  Pulling    10m                kubelet            Pulling image "busybox:1.35.0"
  Normal  Pulled     10m                kubelet            Successfully pulled image "busybox:1.35.0" in 7.675962725s (7.675984149s including waiting)
  Normal  Created    10m (x2 over 12m)  kubelet            Created container sidecar1
  Normal  Started    10m (x2 over 12m)  kubelet            Started container sidecar1
```

### 8.3 热升级
:::color2
<font style="color:#DF2A3F;">SidecarSet 原地升级会先停止旧版本的容器，然后创建新版本的容器，这种方式适合不影响 Pod 服务可用性的 sidecar 容器，比如说日志收集的 Agent。</font>

:::

但是对于很多代理或运行时的 sidecar 容器，例如 Istio Envoy，这种升级方法就有问题了，Envoy 作为 Pod 中的一个代理容器，代理了所有的流量，如果直接重启，Pod 服务的可用性会受到影响，如果需要单独升级 envoy sidecar，就需要复杂的优雅终止和协调机制，所以我们为这种 sidecar 容器的升级提供了一种新的解决方案。

```yaml
# SidecarSet-hotupgrade-sidecarset.yaml
apiVersion: apps.kruise.io/v1alpha1
kind: SidecarSet
metadata:
  name: hotupgrade-sidecarset
spec:
  selector: # 匹配的 Pods 标签
    matchLabels:
      app: hotupgrade
  containers:
    - name: sidecar
      image: openkruise/hotupgrade-sample:sidecarv1 # 镜像
      imagePullPolicy: Always
      lifecycle:
        postStart:
          exec:
            command:
              - /bin/sh
              - /migrate.sh
      upgradeStrategy:
        upgradeType: HotUpgrade
        hotUpgradeEmptyImage: openkruise/hotupgrade-sample:empty # 镜像
```

```shell
# 引用资源清单文件
$ kubectl apply -f SidecarSet-hotupgrade-sidecarset.yaml 
sidecarset.apps.kruise.io/hotupgrade-sidecarset created
```

+ `<font style="color:#DF2A3F;">upgradeType</font>`: `<font style="color:#DF2A3F;">HotUpgrade</font>`<font style="color:#DF2A3F;"> </font>代表该 sidecar 容器的类型是热升级方案
+ `<font style="color:#DF2A3F;">hotUpgradeEmptyImage</font>`: 当热升级 sidecar 容器时，业务必须要提供一个 empty 容器用于热升级过程中的容器切换，empty 容器同 sidecar 容器具有相同的配置（除了镜像地址），例如：command、lifecycle、probe 等，但是它不做任何工作。
+ `<font style="color:#DF2A3F;">lifecycle.postStart</font>`: 在 postStart 这个 hook 中完成热升级过程中的状态迁移，该脚本需要由业务根据自身的特点自行实现，例如：nginx 热升级需要完成 Listen FD 共享以及 reload 操作。

整体来说热升级特性总共包含以下两个过程：

+ Pod 创建时，注入热升级容器
+ 原地升级时，完成热升级流程

#### 8.3.1 注入热升级容器
Pod 创建时，SidecarSet Webhook 将会注入两个容器：

+ `<font style="color:#DF2A3F;">{sidecarContainer.name}-1</font>`: 如下图所示 envoy-1，这个容器代表正在实际工作的 sidecar 容器，例如：envoy:1.16.0
+ `<font style="color:#DF2A3F;">{sidecarContainer.name}-2</font>`: 如下图所示 envoy-2，这个容器是业务配置的 hotUpgradeEmptyImage 容器，例如：empty:1.0，用于后面的热升级机制

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1730551629751-c968a4a0-8a4c-4790-b5cf-59475027ef5b.png)

#### 8.3.2 热升级流程
热升级流程主要分为三个步骤：

+ `<font style="color:#DF2A3F;">Upgrade</font>`: 将 empty 容器升级为当前最新的 sidecar 容器，例如：envoy-2.Image = envoy:1.17.0
+ `<font style="color:#DF2A3F;">Migration</font>`: `<font style="color:#DF2A3F;">lifecycle.postStart</font>` 完成热升级流程中的状态迁移，当迁移完成后退出
+ `<font style="color:#DF2A3F;">Reset</font>`: 状态迁移完成后，热升级流程将设置 envoy-1 容器为 empty 镜像，例如：envoy-1.Image = empty:1.0

上述三个步骤完成了热升级中的全部流程，当对 Pod 执行多次热升级时，将重复性的执行上述三个步骤。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1730551631902-a673254d-6aa6-46aa-bdcf-e450e0a50257.png)

这里我们以 OpenKruise 的官方示例来进行说明，首先创建上面的 `<font style="color:#DF2A3F;">hotupgrade-sidecarset</font>` 这个 SidecarSet。然后创建一个如下所示的 CloneSet 对象：

```yaml
# CloneSet-busybox.yaml
apiVersion: apps.kruise.io/v1alpha1
kind: CloneSet
metadata:
  labels:
    app: hotupgrade
  name: busybox
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hotupgrade
  template:
    metadata:
      labels:
        app: hotupgrade
    spec:
      containers:
        - name: busybox
          image: openkruise/hotupgrade-sample:busybox
```

```shell
# 引用资源清单文件
$ kubectl apply -f CloneSet-busybox.yaml
cloneset.apps.kruise.io/busybox created
```

创建完成后，CloneSet 管理的 Pod 已经注入 `<font style="color:#DF2A3F;">sidecar-1</font>` 和 `<font style="color:#DF2A3F;">sidecar-2</font>` 两个容器：

```shell
➜ kubectl get sidecarset hotupgrade-sidecarset
NAME                    MATCHED   UPDATED   READY   AGE
hotupgrade-sidecarset   1         1         0       2m30s

➜ kubectl get pods -l app=hotupgrade
NAME            READY   STATUS    RESTARTS   AGE
busybox-6jhpw   3/3     Running   0          110s

➜ kubectl describe pods busybox-6jhpw
Name:             busybox-6jhpw
Namespace:        default
Priority:         0
Service Account:  default
Node:             hkk8snode002/192.168.178.37
[......]
Controlled By:  CloneSet/busybox
Containers:
  sidecar-1:
    Container ID:   containerd://aeffa8946d63f0d4e7c496859f61d2f2af9ba9ee748906d102b92efa7a7e0027
    Image:          openkruise/hotupgrade-sample:sidecarv1
    Image ID:       docker.io/openkruise/hotupgrade-sample@sha256:3d677ca19712b67d2c264374736d71089d21e100eff341f6b4bb0f5288ec6f34
    Port:           <none>
    Host Port:      <none>
    State:          Running
      Started:      Tue, 14 Oct 2025 17:57:49 +0800
    Ready:          True
    Restart Count:  0
    Environment:
      IS_INJECTED:             true
      SIDECARSET_VERSION:       (v1:metadata.annotations['version.sidecarset.kruise.io/sidecar-1'])
      SIDECARSET_VERSION_ALT:   (v1:metadata.annotations['versionalt.sidecarset.kruise.io/sidecar-1'])
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-8v4rb (ro)
  sidecar-2:
    Container ID:   containerd://049cb60c47df3ce57b46ace83f37e456fa5de6a5f5c197ed7e8990b3d79edc94
    Image:          openkruise/hotupgrade-sample:empty
    Image ID:       docker.io/openkruise/hotupgrade-sample@sha256:606be602967c9f91c47e4149af4336c053e26225b717a1b5453ac8fa9a401cc5
    Port:           <none>
    Host Port:      <none>
    State:          Running
      Started:      Tue, 14 Oct 2025 17:58:09 +0800
    Ready:          True
    Restart Count:  0
    Environment:
      IS_INJECTED:             true
      SIDECARSET_VERSION:       (v1:metadata.annotations['version.sidecarset.kruise.io/sidecar-2'])
      SIDECARSET_VERSION_ALT:   (v1:metadata.annotations['versionalt.sidecarset.kruise.io/sidecar-2'])
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-8v4rb (ro)
  busybox: # 主容器
    Container ID:   containerd://e4d633a1788eb84802d984f886ce05740c26c21b62df8998690d81b563922ade
    Image:          openkruise/hotupgrade-sample:busybox
    Image ID:       docker.io/openkruise/hotupgrade-sample@sha256:08f9ede05850686e1200240e5e376fc76245dd2eb56299060120b8c3dba46dc9
    Port:           <none>
    Host Port:      <none>
    State:          Running
      Started:      Tue, 14 Oct 2025 17:58:24 +0800
    Ready:          True
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-8v4rb (ro)
[......]
```

busybox 主容器每 100 毫秒会请求一次 `<font style="color:#DF2A3F;">sidecar(version=v1)</font>`<font style="color:#DF2A3F;"> </font>服务：

```shell
➜ kubectl logs -f busybox-6jhpw -c busybox

➜ kubectl logs busybox-6jhpw -c busybox --tail 5
I1014 10:01:56.943342       1 main.go:39] request sidecar server success, and response(body=This is version(v1) sidecar)
I1014 10:01:57.054249       1 main.go:39] request sidecar server success, and response(body=This is version(v1) sidecar)
I1014 10:01:57.165272       1 main.go:39] request sidecar server success, and response(body=This is version(v1) sidecar)
I1014 10:01:57.276504       1 main.go:39] request sidecar server success, and response(body=This is version(v1) sidecar)
I1014 10:01:57.387566       1 main.go:39] request sidecar server success, and response(body=This is version(v1) sidecar)
[......]
```

现在我们去升级 sidecar 容器，将镜像修改为 `<font style="color:#DF2A3F;">openkruise/hotupgrade-sample:sidecarv2</font>`：

```shell
➜ kubectl patch sidecarset hotupgrade-sidecarset \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/containers/0/image", "value": "openkruise/hotupgrade-sample:sidecarv2"}]'
sidecarset.apps.kruise.io/hotupgrade-sidecarset patched
```

更新后再去观察 Pod 的状态，可以看到 sidecar-2 镜像正常更新了：

```shell
➜ kubectl get pod busybox-6jhpw
NAME            READY   STATUS    RESTARTS     AGE
busybox-6jhpw   3/3     Running   2 (5s ago)   5m20s # 只会重启对应的 Container

➜ kubectl describe pods busybox-6jhpw
[......]
Events:
  Type    Reason                 Age                  From                   Message
  ----    ------                 ----                 ----                   -------
  Normal  Scheduled              5m32s                default-scheduler      Successfully assigned default/busybox-6jhpw to hkk8snode002
  Normal  Pulling                5m31s                kubelet                Pulling image "openkruise/hotupgrade-sample:sidecarv1"
  Normal  Pulled                 5m16s                kubelet                Successfully pulled image "openkruise/hotupgrade-sample:sidecarv1" in 15.075010408s (15.07503446s including waiting)
  Normal  Pulling                5m11s                kubelet                Pulling image "openkruise/hotupgrade-sample:empty"
  Normal  Pulled                 4m56s                kubelet                Successfully pulled image "openkruise/hotupgrade-sample:empty" in 15.072926175s (15.073027071s including waiting)
  Normal  Pulling                4m56s                kubelet                Pulling image "openkruise/hotupgrade-sample:busybox"
  Normal  Pulled                 4m41s                kubelet                Successfully pulled image "openkruise/hotupgrade-sample:busybox" in 13.206898703s (14.71048993s including waiting)
  Normal  Created                4m41s                kubelet                Created container busybox
  Normal  Started                4m41s                kubelet                Started container busybox
  Normal  Pulling                41s                  kubelet                Pulling image "openkruise/hotupgrade-sample:sidecarv2"
  Normal  Killing                41s                  kubelet                Container sidecar-2 definition changed, will be restarted
  Normal  Created                28s (x2 over 4m56s)  kubelet                Created container sidecar-2
  Normal  Pulled                 28s                  kubelet                Successfully pulled image "openkruise/hotupgrade-sample:sidecarv2" in 13.287921388s (13.287965793s including waiting)
  Normal  Started                27s (x2 over 4m56s)  kubelet                Started container sidecar-2
```

并且在更新过程中观察 busybox 容器仍然会不断请求 sidecar 服务，但是并没有失败的请求出现：

```shell
➜ kubectl logs -f busybox-6jhpw -c busybox

➜ kubectl logs busybox-6jhpw -c busybox --tail 5
I1014 10:04:06.445032       1 main.go:39] request sidecar server success, and response(body=This is version(v2) sidecar)
I1014 10:04:06.556129       1 main.go:39] request sidecar server success, and response(body=This is version(v2) sidecar)
I1014 10:04:06.667486       1 main.go:39] request sidecar server success, and response(body=This is version(v2) sidecar)
I1014 10:04:06.778660       1 main.go:39] request sidecar server success, and response(body=This is version(v2) sidecar)
I1014 10:04:06.889747       1 main.go:39] request sidecar server success, and response(body=This is version(v2) sidecar)
[......]
```

整个热升级示例代码可以参考仓库的实现：`[https://github.com/openkruise/samples/tree/master/hotupgrade](https://github.com/openkruise/samples/tree/master/hotupgrade)`。

## 9 Container Restart
`<font style="color:#DF2A3F;">ContainerRecreateRequest</font>`<font style="color:#DF2A3F;"> </font>控制器可以帮助用户重启/重建存量 Pod 中一个或多个容器。和 Kruise 提供的原地升级类似，当一个容器重建的时候，Pod 中的其他容器还保持正常运行，重建完成后，Pod 中除了该容器的 restartCount 增加以外不会有什么其他变化。

为要重建容器的 Pod 提交一个 `<font style="color:#DF2A3F;">ContainerRecreateRequest</font>`<font style="color:#DF2A3F;"> </font>自定义资源（缩写 CRR）：

```yaml
# ContainerRecreateRequest.yaml
apiVersion: apps.kruise.io/v1alpha1
kind: ContainerRecreateRequest
metadata:
  namespace: <Pod-NameSpace>
  name: <CRR-Name>
spec:
  podName: <Pod-Name>
  containers: # 要重建的容器名字列表，至少要有 1 个
    - name: app
    - name: sidecar
  strategy:
    failurePolicy: Fail # 'Fail' 或 'Ignore'，表示一旦有某个容器停止或重建失败， CRR 立即结束
    orderedRecreate: false # 'true' 表示要等前一个容器重建完成了，再开始重建下一个
    terminationGracePeriodSeconds: 30 # 等待容器优雅退出的时间，不填默认用 Pod 中定义的
    unreadyGracePeriodSeconds: 3 # 在重建之前先把 Pod 设为 not ready，并等待这段时间后再开始执行重建
    minStartedSeconds: 10 # 重建后新容器至少保持运行这段时间，才认为该容器重建成功
  activeDeadlineSeconds: 300 # 如果 CRR 执行超过这个时间，则直接标记为结束（未结束的容器标记为失败）
  ttlSecondsAfterFinished: 1800 # CRR 结束后，过了这段时间自动被删除掉
```

例如：

```yaml
# ContainerRecreateRequest-Demo.yaml
apiVersion: apps.kruise.io/v1alpha1
kind: ContainerRecreateRequest
metadata:
  namespace: default
  name: busybox
spec:
  podName: busybox-75x98
  containers: # 要重建的容器名字列表，至少要有 1 个
    - name: sidecar-1
    - name: busybox
  strategy:
    failurePolicy: Fail # 'Fail' 或 'Ignore'，表示一旦有某个容器停止或重建失败， CRR 立即结束
    orderedRecreate: false # 'true' 表示要等前一个容器重建完成了，再开始重建下一个
    terminationGracePeriodSeconds: 30 # 等待容器优雅退出的时间，不填默认用 Pod 中定义的
    unreadyGracePeriodSeconds: 3 # 在重建之前先把 Pod 设为 not ready，并等待这段时间后再开始执行重建
    minStartedSeconds: 10 # 重建后新容器至少保持运行这段时间，才认为该容器重建成功
  activeDeadlineSeconds: 300 # 如果 CRR 执行超过这个时间，则直接标记为结束（未结束的容器标记为失败）
  ttlSecondsAfterFinished: 1800 # CRR 结束后，过了这段时间自动被删除掉
```

引用资源清单文件

```shell
$ kubectl create -f ContainerRecreateRequest-Demo.yaml
containerrecreaterequest.apps.kruise.io/busybox created

$ kubectl get ContainerRecreateRequest
NAME      PHASE        POD             NODE           AGE
busybox   Recreating   busybox-75x98   hkk8snode002   20s
# ->
$ kubectl get ContainerRecreateRequest
NAME      PHASE       POD             NODE           AGE
busybox   Completed   busybox-75x98   hkk8snode002   35s
# -> (Pods 重启次数增加)
$ kubectl get pods -l app=hotupgrade
NAME            READY   STATUS    RESTARTS      AGE
busybox-75x98   3/3     Running   4 (54s ago)   7m5s
```

查看 ContainerRecreateRequest 的资源对象

```shell
$ kubectl get ContainerRecreateRequest # 或者是 kubectl get crr
```

一般来说，列表中的容器会一个个被停止，但可能同时在被重建和启动，除非 `<font style="color:#DF2A3F;">orderedRecreate</font>`<font style="color:#DF2A3F;"> </font>被设置为 true。 `<font style="color:#DF2A3F;">unreadyGracePeriodSeconds</font>`<font style="color:#DF2A3F;"> </font>功能依赖于 `<font style="color:#DF2A3F;">KruisePodReadinessGate</font>`<font style="color:#DF2A3F;"> </font>这个 Feature-Gate，后者会在每个 Pod 创建的时候注入一个 `<font style="color:#DF2A3F;">readinessGate</font>`，否则，默认只会给 Kruise workload 创建的 Pod 注入 readinessGate，也就是说只有这些 Pod 才能在 CRR 重建时使用 `<font style="color:#DF2A3F;">unreadyGracePeriodSeconds</font>`。

用于重启 Pod 内的 Container 容器，而不需要将整个 Pod 重建。

## 10 ImagePullJob
`<font style="color:#DF2A3F;">NodeImage</font>`<font style="color:#DF2A3F;"> </font>和 `<font style="color:#DF2A3F;">ImagePullJob</font>`<font style="color:#DF2A3F;"> </font>是从 Kruise v0.8.0 版本开始提供的 CRD。Kruise 会自动为每个 Node 创建一个 NodeImage，它包含了哪些镜像需要在这个 Node 上做预热，比如我们这里 3 个节点，则会自动创建 3 个 NodeImage 对象：

```shell
➜ kubectl get nodeimage
NAME             DESIRED   PULLING   SUCCEED   FAILED   AGE
hkk8smaster001   0         0         0         0        132m
hkk8snode001     0         0         0         0        132m
hkk8snode002     0         0         0         0        132m
```

比如我们查看 hkk8snode001 节点上的 NodeImage 对象：

```yaml
➜ kubectl get nodeimage hkk8snode001 -o yaml
apiVersion: apps.kruise.io/v1alpha1
kind: NodeImage
metadata:
  creationTimestamp: "2025-10-14T07:54:20Z"
  generation: 1
  labels:
    beta.kubernetes.io/arch: amd64
    beta.kubernetes.io/os: linux
    kubernetes.io/arch: amd64
    kubernetes.io/hostname: hkk8snode001
    kubernetes.io/os: linux
  name: hkk8snode001
  resourceVersion: "183730"
  uid: d6689c92-d305-469a-b8e9-07f769468c92
spec: {}
status:
  desired: 0
  failed: 0
  pulling: 0
  succeeded: 0
```

比如我们希望在这个节点上拉去一个 `<font style="color:#DF2A3F;">ubuntu:latest</font>`<font style="color:#DF2A3F;"> </font>镜像，则可以按照如下所示的去修改 spec：

```yaml
[......]
spec:
  images:
    ubuntu:  # 镜像 name
      tags:
      - tag: latest  # 镜像 tag
        pullPolicy:
          ttlSecondsAfterFinished: 300  # [required] 拉取完成（成功或失败）超过 300s 后，将这个任务从 NodeImage 中清除
          timeoutSeconds: 600           # [optional] 每一次拉取的超时时间, 默认为 600
          backoffLimit: 3               # [optional] 拉取的重试次数，默认为 3
          activeDeadlineSeconds: 1200   # [optional] 整个任务的超时时间，无默认值
```

更新后我们可以从 status 中看到拉取进度以及结果，并且你会发现拉取完成 600s 后任务会被清除。

此外用户可以创建 `<font style="color:#DF2A3F;">ImagePullJob</font>`<font style="color:#DF2A3F;"> </font>对象，来指定一个镜像要在哪些节点上做预热。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1730551633066-a0c78d0b-612b-471f-bd94-04de7567a714.png)

比如创建如下所示的 `<font style="color:#DF2A3F;">ImagePullJob</font>`<font style="color:#DF2A3F;"> </font>资源对象：

```yaml
apiVersion: apps.kruise.io/v1alpha1
kind: ImagePullJob
metadata:
  name: job-with-always
spec:
  image: nginx:1.9.1 # [required] 完整的镜像名 name:tag
  parallelism: 10 # [optional] 最大并发拉取的节点梳理, 默认为 1
  selector: # [optional] 指定节点的 名字列表 或 标签选择器 (只能设置其中一种)
    names:
      - node-1
      - node-2
    matchLabels:
      node-type: xxx
  # podSelector:         # [optional] pod label 选择器来在这些 pod 所在节点上拉取镜像, 与 selector 不能同时设置.
  #  pod-label: xxx
  completionPolicy:
    type: Always # [optional] 默认为 Always
    activeDeadlineSeconds: 1200 # [optional] 无默认值, 只对 Alway 类型生效
    ttlSecondsAfterFinished: 300 # [optional] 无默认值, 只对 Alway 类型生效
  pullPolicy: # [optional] 默认 backoffLimit=3, timeoutSeconds=600
    backoffLimit: 3
    timeoutSeconds: 300
  pullSecrets:
    - secret-name1
    - secret-name2
```

例如：

```yaml
# ImagePullJob-job-with-always.yaml
apiVersion: apps.kruise.io/v1alpha1
kind: ImagePullJob
metadata:
  name: job-with-always
spec:
  image: nginx:1.9.1 # [required] 完整的镜像名 name:tag
  parallelism: 10 # [optional] 最大并发拉取的节点梳理, 默认为 1
  selector: # [optional] 指定节点的 名字列表 或 标签选择器 (只能设置其中一种)
    # names:
    #   - hkk8snode001
    #   - hkk8snode002
    matchLabels: # 节点选择器
      kubernetes.io/os: linux
  # podSelector:         # [optional] pod label 选择器来在这些 pod 所在节点上拉取镜像, 与 selector 不能同时设置.
  #  pod-label: xxx
  completionPolicy:
    type: Always # [optional] 默认为 Always
    activeDeadlineSeconds: 1200 # [optional] 无默认值, 只对 Alway 类型生效
    ttlSecondsAfterFinished: 300 # [optional] 无默认值, 只对 Alway 类型生效
  pullPolicy: # [optional] 默认 backoffLimit=3, timeoutSeconds=600
    backoffLimit: 3
    timeoutSeconds: 300
  # pullSecrets: # 私有仓库认证（可选）
  #   - secret-name1
  #   - secret-name2
```

```shell
# 引用资源清单文件
$ kubectl apply -f ImagePullJob-job-with-always.yaml 
imagepulljob.apps.kruise.io/job-with-always created

# 查看 nodeimages 资源对象
$ kubectl get nodeimages # nodeimages.apps.kruise.io 
NAME             DESIRED   PULLING   SUCCEED   FAILED   AGE
hkk8smaster001   1         1         0         0        169m
hkk8snode001     1         1         0         0        169m
hkk8snode002     1         1         0         0        169m

# 查看详细信息
$ kubectl describe nodeimages hkk8snode001
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760438707124-18f989f1-2245-4168-af4b-55ddbdae90a8.png)

我们可以在 `<font style="color:#DF2A3F;">selector</font>`<font style="color:#DF2A3F;"> </font>字段中指定节点的名字列表或标签选择器 (只能设置其中一种)，如果没有设置 selector 则会选择所有节点做预热。或者可以配置 `<font style="color:#DF2A3F;">podSelector</font>`<font style="color:#DF2A3F;"> </font>来在这些 Pod 所在节点上拉取镜像，podSelector 与 selector 不能同时设置。

同时，ImagePullJob 有两种 `<font style="color:#DF2A3F;">completionPolicy</font>`<font style="color:#DF2A3F;"> </font>类型:

+ `<font style="color:#DF2A3F;">Always</font>`：表示这个 Job 是一次性预热，不管成功、失败都会结束
+ `<font style="color:#DF2A3F;">activeDeadlineSeconds</font>`：整个 Job 的 deadline 结束时间
+ `<font style="color:#DF2A3F;">ttlSecondsAfterFinished</font>`：结束后超过这个时间，自动清理删除 Job
+ `<font style="color:#DF2A3F;">Never</font>`：表示这个 Job 是长期运行、不会结束，并且会每天都会在匹配的节点上重新预热一次指定的镜像

同样如果你要预热的镜像来自私有仓库，则可以通过 `<font style="color:#DF2A3F;">pullSecrets</font>`<font style="color:#DF2A3F;"> </font>来指定仓库的 Secret 信息。

## 11 容器启动顺序
`<font style="color:#DF2A3F;">Container Launch Priority</font>` 提供了控制一个 Pod 中容器启动顺序的方法。通常来说 Pod 容器的启动和退出顺序是由 Kubelet 管理的，Kubernetes 曾经有一个 [KEP](https://github.com/kubernetes/enhancements/tree/master/keps/sig-node/753-sidecar-containers) 计划在 container 中增加一个 type 字段来标识不同类型容器的启停优先级，但是由于 [sig-node 考虑到对现有代码架构的改动太大](https://github.com/kubernetes/enhancements/issues/753#issuecomment-713471597)，所以将该提案拒绝了。

<details class="lake-collapse"><summary id="u16746264"><span class="ne-text">作用说明</span></summary><p id="u57bb2aad" class="ne-p"><span class="ne-text">默认情况下，Kubernetes 在启动一个 Pod 时，会 并行地启动 Pod 内的所有容器，没有明确的先后顺序控制。但在某些场景下，你可能希望 某些容器先启动，另一些容器后启动，比如：</span></p><ul class="ne-ul"><li id="uaa481b55" data-lake-index-type="0"><span class="ne-text">Sidecar 容器依赖主容器初始化完成后再启动</span></li><li id="ud5e2ea14" data-lake-index-type="0"><span class="ne-text">日志收集、监控等辅助容器需要在主业务容器之后启动</span></li><li id="u63b03cba" data-lake-index-type="0"><span class="ne-text">有依赖关系的多个容器（如初始化容器逻辑分散到多个容器中）</span></li></ul></details>
这个功能作用在 Pod 对象上，不管它的 Owner 是什么类型的，因此可以适用于 Deployment、CloneSet 以及其他的 workload 种类。

比如我们可以设置按照容器顺序启动，只需要在 Pod 中定义一个 `<font style="color:#DF2A3F;">apps.kruise.io/container-launch-priority</font>` 的注解即可：

```yaml
apiVersion: v1
kind: Pod
  annotations:
    apps.kruise.io/container-launch-priority: Ordered
spec:
  containers:
  - name: sidecar
    # [......]
  - name: main
    # [......]
```

OpenKruise 会保证前面的容器（sidecar）会在后面容器（main）之前启动。

此外我们还可以按自定义顺序启动，但是需要在 Pod 容器中添加 `<font style="color:#DF2A3F;">KRUISE_CONTAINER_PRIORITY</font>`<font style="color:#DF2A3F;"> </font>这个环境变量:

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: main
      # [......]
    - name: sidecar
      env:
        - name: KRUISE_CONTAINER_PRIORITY
          value: '1'
      # [......]
```

该环境变量值的范围在 `<font style="color:#DF2A3F;">[-2147483647, 2147483647]</font>`，<u><font style="color:#DF2A3F;">不写默认是 0，权重高的容器，会保证在权重低的容器之前启动，但是需要注意相同权重的容器不保证启动顺序。</font></u>

其他的示例：

```yaml
# my-pod-container-priority.yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
  annotations:
    apps.kruise.io/container-launch-priority: |
      {
        "main-app": 1,
        "log-agent": 2,
        "monitor": 3
      }
spec:
  containers:
  - name: main-app
    image: my-main-app:latest
  - name: log-agent
    image: fluentd:latest
  - name: monitor
    image: prometheus-agent:latest
```

引用资源清单文件

```shell
$ kubectl apply -f 3.9.9.my-pod-container-priority.yaml
pod/my-pod created
```

除了这些常用的增强控制器之外 OpenKruise 还有很多高级的特性，可以前往官网 [https://openkruise.io](https://openkruise.io/) 了解更多信息。

> 中文文档：[https://openkruise.io/zh/docs](https://openkruise.io/zh/docs)
>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760438838882-e42b3216-cf12-4afe-aadd-c4808e150b6e.png)

