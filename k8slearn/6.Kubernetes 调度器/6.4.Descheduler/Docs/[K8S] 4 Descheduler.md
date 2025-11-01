<u><font style="color:#DF2A3F;">从 kube-scheduler 的角度来看，它是通过一系列算法计算出最佳节点运行 Pod，当出现新的 Pod 进行调度时，调度程序会根据其当时对 Kubernetes 集群的资源描述做出最佳调度决定</font></u>，但是 Kubernetes 集群是非常动态的，由于整个集群范围内的变化，比如一个节点为了维护，我们先执行了驱逐操作，这个节点上的所有 Pod 会被驱逐到其他节点去，但是当我们维护完成后，之前的 Pod 并不会自动回到该节点上来，<u><font style="color:#DF2A3F;">因为 Pod 一旦被绑定了节点是不会触发重新调度的，由于这些变化，Kubernetes 集群在一段时间内就可能会出现不均衡的状态，所以需要均衡器来重新平衡集群。</font></u>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761443873337-f84872ef-c40b-4ce1-844d-38fdf9240344.png)

当然我们可以去手动做一些集群的平衡，比如手动去删掉某些 Pod，触发重新调度就可以了，但是显然这是一个繁琐的过程，也不是解决问题的方式。为了解决实际运行中集群资源无法充分利用或浪费的问题，可以使用 [descheduler](https://github.com/kubernetes-sigs/descheduler) 组件对集群的 Pod 进行调度优化，`<u><font style="color:#DF2A3F;">descheduler</font></u>`<u><font style="color:#DF2A3F;"> 可以根据一些规则和配置策略来帮助我们重新平衡集群状态，其</font></u><u><font style="color:#2F4BDA;">核心原理是根据其策略配置找到可以被移除的 Pod 并驱逐它们，其本身并不会进行调度被驱逐的 Pod</font></u>，而是依靠默认的调度器来实现，目前支持的策略有：

+ <u>RemoveDuplicates</u>
+ <u>LowNodeUtilization</u>
+ <u>RemovePodsViolatingInterPodAntiAffinity</u>
+ <u>RemovePodsViolatingNodeAffinity</u>
+ <u>RemovePodsViolatingNodeTaints</u>
+ <u>RemovePodsViolatingTopologySpreadConstraint</u>
+ <u>RemovePodsHavingTooManyRestarts</u>
+ <u>PodLifeTime</u>

这些策略都是可以启用或者禁用的，作为策略的一部分，也可以配置与策略相关的一些参数，默认情况下，所有策略都是启用的。另外，还有一些通用配置，如下：

+ `<font style="color:#DF2A3F;">nodeSelector</font>`：限制要处理的节点
+ `<font style="color:#DF2A3F;">evictLocalStoragePods</font>`: 驱逐使用 LocalStorage 的 Pods
+ `<font style="color:#DF2A3F;">ignorePvcPods</font>`: 是否忽略配置 PVC 的 Pods，默认是 False
+ `<font style="color:#DF2A3F;">maxNoOfPodsToEvictPerNode</font>`：节点允许的最大驱逐 Pods 数

我们可以通过如下所示的 `<font style="color:#DF2A3F;">DeschedulerPolicy</font>` 来配置：

```yaml
apiVersion: 'descheduler/v1alpha1'
kind: 'DeschedulerPolicy'
nodeSelector: prod=dev
evictLocalStoragePods: true
maxNoOfPodsToEvictPerNode: 40
ignorePvcPods: false
strategies: # 配置策略
  [......]
```

## 1 安装
`<font style="color:#DF2A3F;">descheduler</font>` 可以以 `<font style="color:#DF2A3F;">Job</font>`、`<font style="color:#DF2A3F;">CronJob</font>` 或者 `<font style="color:#DF2A3F;">Deployment</font>` 的形式运行在 Kubernetes 集群内，同样我们可以使用 Helm Chart 来安装 `<font style="color:#DF2A3F;">descheduler</font>`：

```shell
# 添加 Helm Repo
➜ helm repo add descheduler https://kubernetes-sigs.github.io/descheduler/
```

通过 Helm Chart 我们可以配置 `<font style="color:#DF2A3F;">descheduler</font>` 以 `<font style="color:#DF2A3F;">CronJob</font>` 或者 `<font style="color:#DF2A3F;">Deployment</font>` 方式运行，默认情况下 `<font style="color:#DF2A3F;">descheduler</font>` 会以一个 `<font style="color:#DF2A3F;">critical</font> <font style="color:#DF2A3F;">pod</font>` 运行，以避免被自己或者 kubelet 驱逐了，需要确保集群中有 `<font style="color:#DF2A3F;">system-cluster-critical</font>` 这个 Priorityclass：

```shell
# Pod 优先级
# system-cluster-critical 通常是系统预定义的一个较高优先级的 PriorityClass
➜ kubectl get priorityclass system-cluster-critical
NAME                      VALUE        GLOBAL-DEFAULT   AGE
system-cluster-critical   2000000000   false            87d
```

使用 Helm Chart 安装默认情况下会以 `<font style="color:#DF2A3F;">CronJob</font>` 的形式运行，执行周期为 `<font style="color:#DF2A3F;">schedule: "*/2 * * * *"</font>`，这样每隔两分钟会执行一次 `<font style="color:#DF2A3F;">descheduler</font>` 任务，默认的配置策略如下所示：(使用该配置即可)

```yaml
# cm-descheduler.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: descheduler
data:
  policy.yaml: |
    apiVersion: "descheduler/v1alpha1"
    kind: "DeschedulerPolicy"
    strategies:
      LowNodeUtilization:
        enabled: true
        params:
          nodeResourceUtilizationThresholds:
            targetThresholds: # 低利用率阈值（%百分比的形式）
              cpu: 50
              memory: 50
              pods: 80
            thresholds: # 目标阈值（%百分比的形式）
              cpu: 20
              memory: 20
              pods: 20
      RemoveDuplicates: # 确保只有一个和 Pod 关联的 RS、Deployment 或者 Job 资源对象运行在同一节点上
        enabled: true
      RemovePodsViolatingInterPodAntiAffinity: # 确保从节点中删除违反 Pod 反亲和性的 Pod
        enabled: true
      RemovePodsViolatingNodeAffinity: # 确保从节点中删除违反节点亲和性的 Pod
        enabled: true
        params:
          nodeAffinityType:
          - requiredDuringSchedulingIgnoredDuringExecution
      RemovePodsViolatingNodeTaints: # 确保从节点中删除违反 NoSchedule 污点的 Pod
        enabled: true
```

```shell
# 引用资源清单文件
➜ kubectl create -f cm-descheduler.yaml 
configmap/descheduler created
```

通过配置 `<font style="color:#DF2A3F;">DeschedulerPolicy</font>` 的 `<font style="color:#DF2A3F;">strategies</font>`，可以指定 `<font style="color:#DF2A3F;">descheduler</font>` 的执行策略，这些策略都是可以启用或禁用的，下面我们会详细介绍，这里我们使用默认策略即可，使用如下命令直接安装即可：

```shell
# 指定第三方的镜像仓库
➜ helm upgrade --install descheduler descheduler/descheduler \
  --set image.repository=cnych/descheduler,podSecurityPolicy.create=false -n kube-system

➜ helm upgrade --install descheduler descheduler/descheduler \
  --set podSecurityPolicy.create=false -n kube-system
Release "descheduler" has been upgraded. Happy Helming!
NAME: descheduler
LAST DEPLOYED: Sun Oct 26 10:07:31 2025
NAMESPACE: kube-system
STATUS: deployed
REVISION: 2
TEST SUITE: None
NOTES:
Descheduler installed as a CronJob.
A DeschedulerPolicy has been applied for you. You can view the policy with:

kubectl get configmap -n kube-system descheduler -o yaml

If you wish to define your own policies out of band from this chart, you may define a configmap named descheduler.
To avoid a conflict between helm and your out of band method to deploy the configmap, please set deschedulerPolicy in values.yaml to an empty object as below.

deschedulerPolicy: {}
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761444343954-6c70e6d3-306e-4b75-8957-b249ce3c3c8e.png)

部署完成后会创建一个 `<font style="color:#DF2A3F;">CronJob</font>` 资源对象来平衡集群状态：

```shell
➜ kubectl get cronjob -n kube-system
NAME          SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
descheduler   */2 * * * *   False     1        115s            2m30s

➜ kubectl get job -n kube-system
NAME                   COMPLETIONS   DURATION   AGE
descheduler-29357406   1/1           20s        20s

➜ kubectl get pods -n kube-system -l job-name=descheduler-29357406
NAME                         READY   STATUS      RESTARTS   AGE
descheduler-29357406-ct4rm   0/1     Completed   0          39s
```

正常情况下就会创建一个对应的 Job 来执行 `<font style="color:#DF2A3F;">descheduler</font>` 任务，我们可以通过查看日志可以了解做了哪些平衡操作：

```shell
➜ kubectl logs -f descheduler-29357406-ct4rm -n kube-system
I1026 02:08:49.916204       1 named_certificates.go:53] "Loaded SNI cert" index=0 certName="self-signed loopback" certDetail="\"apiserver-loopback-client@1761444529\" [serving] validServingFor=[apiserver-loopback-client] issuer=\"apiserver-loopback-client-ca@1761444529\" (2025-10-26 01:08:48 +0000 UTC to 2028-10-26 01:08:48 +0000 UTC (now=2025-10-26 02:08:49.916139302 +0000 UTC))"
I1026 02:08:49.916246       1 secure_serving.go:211] Serving securely on [::]:10258
I1026 02:08:49.916272       1 tracing.go:87] Did not find a trace collector endpoint defined. Switching to NoopTraceProvider
I1026 02:08:49.916338       1 tlsconfig.go:243] "Starting DynamicServingCertificateController"
I1026 02:08:49.916611       1 envvar.go:172] "Feature gate default state" feature="InformerResourceVersion" enabled=false
I1026 02:08:49.916643       1 envvar.go:172] "Feature gate default state" feature="InOrderInformers" enabled=true
I1026 02:08:49.916663       1 envvar.go:172] "Feature gate default state" feature="WatchListClient" enabled=false
I1026 02:08:49.916677       1 envvar.go:172] "Feature gate default state" feature="ClientsAllowCBOR" enabled=false
I1026 02:08:49.916684       1 envvar.go:172] "Feature gate default state" feature="ClientsPreferCBOR" enabled=false
W1026 02:08:49.972349       1 descheduler.go:482] descheduler version 0.33.0 may not be supported on your version of Kubernetes v1.27.6.See compatibility docs for more info: https://github.com/kubernetes-sigs/descheduler#compatibility-matrix
I1026 02:08:49.982331       1 reflector.go:357] "Starting reflector" type="*v1.Node" resyncPeriod="0s" reflector="k8s.io/client-go/informers/factory.go:160"
I1026 02:08:49.982347       1 reflector.go:357] "Starting reflector" type="*v1.Namespace" resyncPeriod="0s" reflector="k8s.io/client-go/informers/factory.go:160"
I1026 02:08:49.982385       1 reflector.go:357] "Starting reflector" type="*v1.PodDisruptionBudget" resyncPeriod="0s" reflector="k8s.io/client-go/informers/factory.go:160"
I1026 02:08:49.982414       1 reflector.go:403] "Listing and watching" type="*v1.PodDisruptionBudget" reflector="k8s.io/client-go/informers/factory.go:160"
I1026 02:08:49.982394       1 reflector.go:403] "Listing and watching" type="*v1.Namespace" reflector="k8s.io/client-go/informers/factory.go:160"
I1026 02:08:49.982342       1 reflector.go:357] "Starting reflector" type="*v1.PriorityClass" resyncPeriod="0s" reflector="k8s.io/client-go/informers/factory.go:160"
I1026 02:08:49.982520       1 reflector.go:403] "Listing and watching" type="*v1.PriorityClass" reflector="k8s.io/client-go/informers/factory.go:160"
I1026 02:08:49.982394       1 reflector.go:403] "Listing and watching" type="*v1.Node" reflector="k8s.io/client-go/informers/factory.go:160"
I1026 02:08:49.982826       1 reflector.go:357] "Starting reflector" type="*v1.Pod" resyncPeriod="0s" reflector="k8s.io/client-go/informers/factory.go:160"
I1026 02:08:49.982873       1 reflector.go:403] "Listing and watching" type="*v1.Pod" reflector="k8s.io/client-go/informers/factory.go:160"
I1026 02:08:49.984788       1 reflector.go:430] "Caches populated" type="*v1.PodDisruptionBudget" reflector="k8s.io/client-go/informers/factory.go:160"
I1026 02:08:49.985104       1 reflector.go:430] "Caches populated" type="*v1.PriorityClass" reflector="k8s.io/client-go/informers/factory.go:160"
I1026 02:08:49.986608       1 reflector.go:430] "Caches populated" type="*v1.Namespace" reflector="k8s.io/client-go/informers/factory.go:160"
I1026 02:08:49.986636       1 reflector.go:430] "Caches populated" type="*v1.Node" reflector="k8s.io/client-go/informers/factory.go:160"
I1026 02:08:49.995347       1 reflector.go:430] "Caches populated" type="*v1.Pod" reflector="k8s.io/client-go/informers/factory.go:160"
I1026 02:08:50.082502       1 descheduler.go:397] Setting up the pod evictor
I1026 02:08:50.082775       1 toomanyrestarts.go:116] "Processing node" node="hkk8snode001"
I1026 02:08:50.083109       1 toomanyrestarts.go:116] "Processing node" node="hkk8snode002"
I1026 02:08:50.083314       1 toomanyrestarts.go:116] "Processing node" node="hkk8smaster001"
[......]
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761444728648-ff902a90-b2c4-4007-befb-b47f5b46f5c4.png)

从日志中我们就可以清晰的知道因为什么策略驱逐了哪些 Pods。

## 2 PDB 中断预算
由于使用 `<font style="color:#DF2A3F;">descheduler</font>` 会将 Pod 驱逐进行重调度，但是如果一个服务的所有副本都被驱逐的话，则可能导致该服务不可用。如果服务本身存在单点故障，驱逐的时候肯定就会造成服务不可用了，这种情况我们强烈建议使用反亲和性和多副本来避免单点故障，但是如果服务本身就被打散在多个节点上，这些 Pod 都被驱逐的话，这个时候也会造成服务不可用了，这种情况下我们可以通过配置 `<font style="color:#DF2A3F;">PDB（PodDisruptionBudget）</font>` 对象来避免所有副本同时被删除，比如我们可以设置在驱逐的时候某应用最多只有一个副本不可用，则创建如下所示的资源清单即可：

```yaml
# pdb-demo.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: pdb-demo
spec:
  maxUnavailable: 1 # 设置最多不可用的副本数量，或者使用 minAvailable，可以使用整数或百分比
  selector:
    matchLabels: # 匹配Pod标签
      app: demo
```

```shell
$ kubectl apply -f pdb-demo.yaml 
poddisruptionbudget.policy/pdb-demo created
```

关于 PDB 的更多详细信息可以查看官方文档：[https://kubernetes.io/docs/tasks/run-application/configure-pdb/](https://kubernetes.io/docs/tasks/run-application/configure-pdb/)。

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761445621925-86eb1f89-c0b6-4ea4-b3eb-f73d40136ad0.png)

所以如果我们使用 `<font style="color:#DF2A3F;">descheduler</font>` 来重新平衡集群状态，那么我们强烈建议给应用创建一个对应的 `<font style="color:#DF2A3F;">PodDisruptionBudget</font>` 对象进行保护。

## 3 策略
### 3.1 PodLifeTime
该策略用于驱逐比 `<font style="color:#DF2A3F;">maxPodLifeTimeSeconds</font>` 更旧的 Pods，可以通过 `<font style="color:#DF2A3F;">podStatusPhases</font>` 来配置哪类状态的 Pods 会被驱逐，建议为每个应用程序创建一个 PDB，以确保应用程序的可用性，比如我们可以配置如下所示的策略来<u><font style="color:#DF2A3F;">驱逐运行超过 7 天的 Pod</font></u>：

```yaml
# PodLifeTime.yaml
apiVersion: 'descheduler/v1alpha1'
kind: 'DeschedulerPolicy'
strategies:
  'PodLifeTime':
    enabled: true
    params:
      maxPodLifeTimeSeconds: 604800 # Pods 运行最多7天
```

### 3.2 RemoveDuplicates
<u>该策略确保只有一个和 Pod 关联的 RS、Deployment 或者 Job 资源对象运行在同一节点上</u>。如果还有更多的 Pod 则将这些重复的 Pod 进行驱逐，以便更好地在集群中分散 Pod。如果某些节点由于某些原因崩溃了，这些节点上的 Pod 漂移到了其他节点，导致多个与 RS 关联的 Pod 在同一个节点上运行，就有可能发生这种情况，一旦出现故障的节点再次准备就绪，就可以<u><font style="color:#DF2A3F;">启用该策略来驱逐这些重复的 Pod</font></u>。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570729030-5af0fe81-480e-4e79-8b1d-e5ce117e65ee.png)

配置策略的时候，可以指定参数 `<font style="color:#DF2A3F;">excludeOwnerKinds</font>` 用于排除类型，这些类型下的 Pod 不会被驱逐：

```yaml
# RemoveDuplicates.yaml
apiVersion: 'descheduler/v1alpha1'
kind: 'DeschedulerPolicy'
strategies:
  'RemoveDuplicates':
    enabled: true
    params:
      removeDuplicates:
        excludeOwnerKinds:
          - 'ReplicaSet'
```

### 3.3 LowNodeUtilization(重要)
该策略主要<u>用于查找未充分利用的节点，并从其他节点驱逐 Pod，以便 kube-scheudler 重新将它们调度到未充分利用的节点上。该策略的参数可以通过字段 </u>`<u><font style="color:#DF2A3F;">nodeResourceUtilizationThresholds</font></u>`<u> 进行配置。</u>

**<u><font style="color:#DF2A3F;">节点的利用率不足可以通过配置 </font></u>**`**<u><font style="color:#DF2A3F;">thresholds</font></u>**`**<u><font style="color:#DF2A3F;"> 阈值参数来确定，可以通过 CPU、内存和 Pods 数量的百分比进行配置</font></u>**。如果节点的使用率均低于所有阈值，则认为该节点未充分利用。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570729109-8d898077-1485-434b-887e-f8748bdb9de0.png)

此外，还有一个**<u><font style="color:#DF2A3F;">可配置的阈值 </font></u>**`**<u><font style="color:#DF2A3F;">targetThresholds</font></u>**`**<u><font style="color:#DF2A3F;">，用于计算可能驱逐 Pods 的潜在节点，该参数也可以配置 CPU、内存以及 Pods 数量的百分比进行配置</font></u>**。`<font style="color:#DF2A3F;">thresholds</font>` 和 `<font style="color:#DF2A3F;">targetThresholds</font>` 可以根据你的集群需求进行动态调整，如下所示示例：

```yaml
# LowNodeUtilization.yaml
apiVersion: 'descheduler/v1alpha1'
kind: 'DeschedulerPolicy'
strategies:
  'LowNodeUtilization':
    enabled: true
    params:
      nodeResourceUtilizationThresholds:
        thresholds: # 低利用率阈值（%百分比的形式）
          'cpu': 20
          'memory': 20
          'pods': 20
        targetThresholds: # 目标阈值（%百分比的形式）
          'cpu': 50
          'memory': 50
          'pods': 50
```

:::color1
Descheduler 会：

1. 发现节点 A 的所有指标都低于 20%（太闲）
2. 把节点 A 上的一些 Pod 驱逐掉
3. 这些 Pod 会被重新调度到节点 B（因为 B 低于 50% 目标阈值）
4. 节点 C 太忙了（超过 50%），不会接收新 Pod

:::

需要注意的是：

+ 仅支持以下三种资源类型：cpu、memory、pods
+ `<font style="color:#DF2A3F;">thresholds</font>` 和 `<font style="color:#DF2A3F;">targetThresholds</font>` 必须配置相同的类型
+ 参数值的访问是 0-100（百分制）
+ 相同的资源类型，`<font style="color:#DF2A3F;">thresholds</font>` 的配置不能高于 `<font style="color:#DF2A3F;">targetThresholds</font>` 的配置

如果未指定任何资源类型，则默认是 100%，以避免节点从未充分利用变为过度利用。和 `<font style="color:#DF2A3F;">LowNodeUtilization</font>` 策略关联的另一个参数是 `<font style="color:#DF2A3F;">numberOfNodes</font>`，只有当未充分利用的节点数大于该配置值的时候，才可以配置该参数来激活该策略，该参数对于大型集群非常有用，其中有一些节点可能会频繁使用或短期使用不足，默认情况下，numberOfNodes 为 0。

### 3.4 RemovePodsViolatingInterPodAntiAffinity
<u><font style="color:#DF2A3F;">该策略可以确保从节点中删除违反 Pod 反亲和性的 Pod</font></u>，比如某个节点上有 podA 这个 Pod，并且 podB 和 podC（在同一个节点上运行）具有禁止它们在同一个节点上运行的反亲和性规则，则 podA 将被从该节点上驱逐，以便 podB 和 podC 运行正常运行。当 podB 和 podC 已经运行在节点上后，反亲和性规则被创建就会发送这样的问题。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570729255-d75ed075-e58e-4e5a-bdb2-2b57ec7da0b2.png)

要禁用该策略，直接配置成 false 即可：

```yaml
# RemovePodsViolatingInterPodAntiAffinity.yaml
apiVersion: 'descheduler/v1alpha1'
kind: 'DeschedulerPolicy'
strategies:
  'RemovePodsViolatingInterPodAntiAffinity':
    enabled: false
```

### 3.5 RemovePodsViolatingNodeTaints
<u>该策略可以确保从节点中删除违反 </u>`<u><font style="color:#DF2A3F;">NoSchedule</font></u>`<u> 污点的 Pod</u>，比如有一个名为 podA 的 Pod，通过配置容忍 `<font style="color:#DF2A3F;">key=value:NoSchedule</font>` 允许被调度到有该污点配置的节点上，如果节点的污点随后被更新或者删除了，则污点将不再被 Pods 的容忍满足，然后将被驱逐：

```yaml
# RemovePodsViolatingNodeTaints.yaml
apiVersion: 'descheduler/v1alpha1'
kind: 'DeschedulerPolicy'
strategies:
  'RemovePodsViolatingNodeTaints':
    enabled: true
```

### 3.6 RemovePodsViolatingNodeAffinity
<u><font style="color:#DF2A3F;">该策略确保从节点中删除违反节点亲和性的 Pod</font></u>。比如名为 podA 的 Pod 被调度到了节点 nodeA，podA 在调度的时候满足了节点亲和性规则 `<font style="color:#DF2A3F;">requiredDuringSchedulingIgnoredDuringExecution</font>`，但是随着时间的推移，节点 nodeA 不再满足该规则了，那么如果另一个满足节点亲和性规则的节点 nodeB 可用，则 podA 将被从节点 nodeA 驱逐，如下所示的策略配置示例：

```yaml
# RemovePodsViolatingNodeAffinity.yaml
apiVersion: 'descheduler/v1alpha1'
kind: 'DeschedulerPolicy'
strategies:
  'RemovePodsViolatingNodeAffinity':
    enabled: true
    params:
      nodeAffinityType:
        - 'requiredDuringSchedulingIgnoredDuringExecution'
```

### 3.7 RemovePodsViolatingTopologySpreadConstraint
<u><font style="color:#DF2A3F;">该策略确保从节点驱逐违反拓扑分布约束的 Pods</font></u>，具体来说，它试图驱逐将拓扑域平衡到每个约束的 `<font style="color:#DF2A3F;">maxSkew</font>` 内所需的最小 Pod 数，不过该策略需要 Kubernetes 版本高于 1.18 才能使用。

默认情况下，此策略仅处理硬约束，如果将参数 `<font style="color:#DF2A3F;">includeSoftConstraints</font>` 设置为 True，也将支持软约束。

```yaml
# RemovePodsViolatingTopologySpreadConstraint.yaml
apiVersion: 'descheduler/v1alpha1'
kind: 'DeschedulerPolicy'
strategies:
  'RemovePodsViolatingTopologySpreadConstraint':
    enabled: true
    params:
      includeSoftConstraints: false
```

### 3.8 RemovePodsHavingTooManyRestarts
该策略确保从节点中删除重启次数过多的 Pods，它的参数包括 `<font style="color:#DF2A3F;">podRestartThreshold</font>`（这是应将 Pod 逐出的重新启动次数），以及包括`<font style="color:#DF2A3F;">InitContainers</font>`，它确定在计算中是否应考虑初始化容器的重新启动，策略配置如下所示：

```yaml
# RemovePodsHavingTooManyRestarts.yaml
apiVersion: 'descheduler/v1alpha1'
kind: 'DeschedulerPolicy'
strategies:
  'RemovePodsHavingTooManyRestarts':
    enabled: true
    params:
      podsHavingTooManyRestarts:
        podRestartThreshold: 100
        includingInitContainers: true
```

## 4 Filter Pods
在驱逐 Pods 的时候，有时并不需要所有 Pods 都被驱逐，`<font style="color:#DF2A3F;">descheduler</font>` 提供了两种主要的方式进行过滤：命名空间过滤和优先级过滤。

### 4.1 命名空间过滤
该策略可以配置是包含还是排除某些名称空间。可以使用该策略的有：

+ <u>PodLifeTime</u>
+ <u>RemovePodsHavingTooManyRestarts</u>
+ <u>RemovePodsViolatingNodeTaints</u>
+ <u>RemovePodsViolatingNodeAffinity</u>
+ <u>RemovePodsViolatingInterPodAntiAffinity</u>
+ <u>RemoveDuplicates</u>
+ <u>RemovePodsViolatingTopologySpreadConstraint</u>

比如只驱逐某些命令空间下的 Pods，则可以使用 `<font style="color:#DF2A3F;">include</font>` 参数进行配置，如下所示：

```yaml
# DeschedulerPolicy-include.yaml
apiVersion: 'descheduler/v1alpha1'
kind: 'DeschedulerPolicy'
strategies:
  'PodLifeTime':
    enabled: true
    params:
      podLifeTime:
        maxPodLifeTimeSeconds: 86400
      namespaces:
        include:
          - 'namespace1'
          - 'namespace2'
```

又或者要排除掉某些命令空间下的 Pods，则可以使用 `<font style="color:#DF2A3F;">exclude</font>` 参数配置，如下所示：

```yaml
# DeschedulerPolicy-exclude.yaml
apiVersion: 'descheduler/v1alpha1'
kind: 'DeschedulerPolicy'
strategies:
  'PodLifeTime':
    enabled: true
    params:
      podLifeTime:
        maxPodLifeTimeSeconds: 86400
      namespaces:
        exclude:
          - 'namespace1'
          - 'namespace2'
```

### 4.2 优先级过滤
<u>所有策略都可以配置优先级阈值，只有在该阈值以下的 Pod 才会被驱逐，我们可以通过设置 </u>`<u><font style="color:#DF2A3F;">thresholdPriorityClassName</font></u>`<u>（将阈值设置为指定优先级类别的值）或 </u>`<u><font style="color:#DF2A3F;">thresholdPriority</font></u>`<u>（直接设置阈值）参数来指定该阈值。</u>默认情况下，该阈值设置为 `<font style="color:#DF2A3F;">system-cluster-critical</font>` 这个 PriorityClass 类的值。

比如使用 `<font style="color:#DF2A3F;">thresholdPriority</font>`：

```yaml
# DeschedulerPolicy-thresholdPriority.yaml
apiVersion: 'descheduler/v1alpha1'
kind: 'DeschedulerPolicy'
strategies:
  'PodLifeTime':
    enabled: true
    params:
      podLifeTime:
        maxPodLifeTimeSeconds: 86400
      thresholdPriority: 10000
```

或者使用 `<font style="color:#DF2A3F;">thresholdPriorityClassName</font>` 进行过滤：

```yaml
# DeschedulerPolicy-thresholdPriorityClassName.yaml
apiVersion: 'descheduler/v1alpha1'
kind: 'DeschedulerPolicy'
strategies:
  'PodLifeTime':
    enabled: true
    params:
      podLifeTime:
        maxPodLifeTimeSeconds: 86400
      thresholdPriorityClassName: 'priorityclass1'
```

:::color1
**☀️****<u>不过需要注意不能同时配置 </u>**`**<u><font style="color:#DF2A3F;">thresholdPriority</font></u>**`**<u> 和 </u>**`**<u><font style="color:#DF2A3F;">thresholdPriorityClassName</font></u>**`**<u>，如果指定的优先级类不存在，则 Descheduler 不会创建它，并且会引发错误。</u>**

:::

## 5 注意事项
当使用 Descheduler 驱除 Pods 的时候，需要注意以下几点：

+ 关键性 Pod 不会被驱逐，比如 `<font style="color:#DF2A3F;">priorityClassName</font>` 设置为 `<font style="color:#DF2A3F;">system-cluster-critical</font>` 或 `<font style="color:#DF2A3F;">system-node-critical</font>`<font style="color:#DF2A3F;"> </font>的 Pod
+ 不属于 RS(Replicas)、Deployment 或 Job 管理的 Pods 不会被驱逐
+ DaemonSet 创建的 Pods 不会被驱逐
+ 使用 `<font style="color:#DF2A3F;">LocalStorage</font>` 的 Pod 不会被驱逐，除非设置 `<font style="color:#DF2A3F;">evictLocalStoragePods: true</font>`
+ 具有 PVC 的 Pods 不会被驱逐，除非设置 `<font style="color:#DF2A3F;">ignorePvcPods: true</font>`
+ 在 `<font style="color:#DF2A3F;">LowNodeUtilization</font>` 和 `<font style="color:#DF2A3F;">RemovePodsViolatingInterPodAntiAffinity</font>` 策略下，Pods 按优先级从低到高进行驱逐，如果优先级相同，`<font style="color:#DF2A3F;">Besteffort</font>` 类型的 Pod 要先于 `<font style="color:#DF2A3F;">Burstable</font>` 和 `<font style="color:#DF2A3F;">Guaranteed</font>` 类型被驱逐
+ `<font style="color:#DF2A3F;">annotations</font>` 中带有 `<font style="color:#DF2A3F;">descheduler.alpha.kubernetes.io/evict</font>` 字段的 Pod 都可以被驱逐，该注释用于覆盖阻止驱逐的检查，用户可以选择驱逐哪个 Pods
+ 如果 Pods 驱逐失败，可以设置 `<font style="color:#DF2A3F;">--v=4</font>` 从 `<font style="color:#DF2A3F;">descheduler</font>` 日志中查找原因，如果驱逐违反 PDB 约束，则不会驱逐这类 Pods

