`<u><font style="color:#DF2A3F;">QoS</font></u>`<u> 是 </u>`<u><font style="color:#DF2A3F;">Quality of Service</font></u>`<u> 的缩写，即服务质量，为了实现资源被有效调度和分配的同时提高资源利用率，Kubernetes 针对不同服务质量的预期，通过 QoS 来对 Pod 进行服务质量管理，对于一个 Pod 来说，服务质量体现在两个具体的指标：CPU 和内存 Memory</u>。当节点上内存资源紧张时，Kubernetes 会根据预先设置的不同 QoS 类别进行相应处理。

## 1 资源限制
如果未做过节点 nodeSelector、亲和性（node affinity）或 Pod 亲和、反亲和性等高级调度策略设置，我们没有办法指定服务部署到指定节点上，这样就可能会造成 CPU 或内存等密集型的 Pod 同时分配到相同节点上，造成资源竞争。另一方面，如果未对资源进行限制，一些关键的服务可能会因为资源竞争因 OOM 等原因被 Kill 掉，或者被限制 CPU 使用。

我们知道对于每一个资源，<u><font style="color:#DF2A3F;">Container 可以指定具体的资源需求（requests）和限制（limits）</font></u>，requests 申请范围是0到节点的最大配置，而 limits 申请范围是 requests 到无限，即 `<font style="color:#DF2A3F;">0 <= requests <= Node Allocatable</font>`, `<font style="color:#DF2A3F;">requests <= limits <= Infinity</font>`。

+ _<u>对于 CPU，如果 Pod 中服务使用的 CPU 超过设置的 limits，Pod 不会被 kill 掉但会被限制，</u>__<u><font style="color:#DF2A3F;">因为 CPU 是可压缩资源，如果没有设置 limits，Pod 可以使用全部空闲的 CPU 资源。</font></u>_
+ _<u>对于内存 Memory，当一个 Pod 使用内存超过了设置的 limits，</u>__<u><font style="color:#DF2A3F;">Pod 中容器的进程会被 kernel 因 OOM kill 掉，当 container 因为 OOM 被 kill 掉时，系统倾向于在其原所在的机器上重启该 container 或本机或其他重新创建一个 Pod。</font></u>_

## 2 QoS 分类
Kubelet 提供 QoS 服务质量管理，支持系统级别的 OOM 控制。在 Kubernetes 中，QoS 主要分为<font style="color:#DF2A3F;"> </font>`<font style="color:#DF2A3F;">Guaranteed</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">Burstable</font>`<font style="color:#DF2A3F;"> 和 </font>`<font style="color:#DF2A3F;">Best-Effort</font>` 三类，优先级从高到低。

QoS 分类并不是通过一个配置项来直接配置的，而是通过配置 CPU/内存的 limits 与 requests 值的大小来确认服务质量等级的，我们通过使用 `<font style="color:#DF2A3F;">kubectl get pod xxx -o yaml</font>` 可以看到 pod 的配置输出中有 `<font style="color:#DF2A3F;">qosClass</font>` 一项，该配置的作用是为了给资源调度提供策略支持，调度算法根据不同的服务质量等级可以确定将 pod 调度到哪些节点上。

### 2.1 Guaranteed(有保证的)
系统用完了全部内存，且没有其他类型的容器可以被 kill 时，该类型的 Pods 会被 kill 掉，也就是说最后才会被考虑 kill 掉，属于该级别的 pod 有以下两种情况：

+ <u><font style="color:#DF2A3F;">Pod 中的所有容器都且仅设置了 CPU 和内存的 limits</font></u>
+ Pod 中的所有容器都设置了 CPU 和内存的 requests 和 limits ，且<u>单个容器内的 </u>`<u><font style="color:#DF2A3F;">requests==limits</font></u>`<u>（requests不等于0）</u>

pod 中的所有容器都且仅设置了 limits：

```yaml
containers:
  name: foo
    resources:
      limits:
        cpu: 10m
        memory: 1Gi
  name: bar
    resources:
      limits:
        cpu: 100m
        memory: 100Mi
```

因为如果一个容器只指明 limit 而未设定 requests，则 requests 的值等于 limit 值，所以上面 pod 的 QoS 级别属于 Guaranteed。

另外一个就是 Pod 中的所有容器都明确设置了 requests 和 limits，且单个容器内的 `<font style="color:#DF2A3F;">requests==limits</font>`：

```yaml
containers:
  name: foo
    resources:
      limits:
        cpu: 10m
        memory: 1Gi
      requests:
        cpu: 10m
        memory: 1Gi
  name: bar
    resources:
      limits:
        cpu: 100m
        memory: 100Mi
      requests:
        cpu: 100m
        memory: 100Mi
```

容器 foo 和 bar 内 resources 的 requests 和 limits 均相等，该 Pod 的 QoS 级别属于 Guaranteed。

### 2.2 Burstable(不稳定的)
<font style="color:#DF2A3F;">系统用完了全部内存，且没有 Best-Effort 类型的容器可以被 kill 时，该类型的 Pods 会被 kill 掉。Pod 中只要有一个容器的 requests 和 limits 的设置不相同，该 Pod 的 QoS 即为 Burstable。</font>

比如容器 foo 指定了 resource，而容器 bar 未指定：

```yaml
containers:
  name: foo
    resources:
      limits:
        cpu: 10m
        memory: 1Gi
      requests:
        cpu: 10m
        memory: 1Gi
  name: bar
```

或者容器 foo 设置了内存 limits，而容器 bar 设置了 CPU limits：

```yaml
containers:
  name: foo
    resources:
      limits:
        memory: 1Gi
  name: bar
    resources:
      limits:
        cpu: 100m
```

上面两种情况定义的 pod 都属于 Burstable 类别的 QoS。另外需要注意若容器指定了 requests 而未指定 limits，则 limits 的值等于节点资源的最大值；若容器指定了 limits 而未指定 requests，则 requests 的值等于 limits。

### 2.3 Best-Effort(尽最大努力)
<u><font style="color:#DF2A3F;">系统用完了全部内存时，该类型 Pods 会最先被 kill 掉。如果 Pod 中所有容器的 resources 均未设置 requests 与 limits，那么该 Pod 的 QoS 即为 Best-Effort。</font></u>

比如容器 foo 和容器 bar 均未设置 requests 和 limits：

```yaml
containers:
  name: foo
    resources:
  name: bar
    resources:
```

## 3 QoS 解析
首先<u>我们要明确在调度时</u>**<u><font style="color:#601BDE;">调度器只会根据 requests 值进行调度。当系统 OOM 上时对于处理不同 OOMScore 的进程表现不同，OOMScore 是针对 memory 的，当宿主上 memory 不足时系统会优先 kill 掉 OOMScore 值高的进程，可以使用</font></u>****<u> </u>**`**<u><font style="color:#DF2A3F;">cat /proc/$PID/oom_score</font></u>**`**<u> </u>****<u><font style="color:#601BDE;">命令查看进程的 OOMScore</font></u>****<u>。</u>**<u>OOMScore 的取值范围为 </u>`<u><font style="color:#DF2A3F;">[-1000, 1000]</font></u>`<u>，Guaranteed 类型的 pod 的默认值为 </u>`<u><font style="color:#DF2A3F;">-998</font></u>`<u>，Burstable pod 的值为 </u>`<u><font style="color:#DF2A3F;">2~999</font></u>`<u>，BestEffort pod 的值为 1000，也就是说当系统 OOM 时，首先会 Kill 掉 BestEffort pod 的进程，若系统依然处于 OOM 状态，然后才会 Kill 掉 Burstable pod，最后是 Guaranteed pod。</u>

Kubernetes 是通过 cgroup 给 pod 设置 QoS 级别的，kubelet 中有一个 `<font style="color:#DF2A3F;">--cgroups-per-qos</font>` 参数（默认启用），启用后 kubelet 会为不同 QoS 创建对应的 level cgroups，在 Qos level cgroups 下也会为 Pod 下的容器创建对应的 Level Cgroups，从 `<font style="color:#DF2A3F;">Qos –> pod –> container</font>`，层层限制每个 level cgroups 的资源使用量。由于我们这里使用的是 containerd 这种容器运行时，则 Cgroups 的路径与之前的 docker 不太一样：

+ Guaranteed （有保证的）类型的 cgroup level 会直接创建在 `<font style="color:#DF2A3F;">RootCgroup/system.slice/containerd.service/kubepods-pod<uid>.slice:cri-containerd:<container-id></font>` 下
+ Burstable （不稳定）的创建在 `<font style="color:#DF2A3F;">RootCgroup/system.slice/containerd.service/kubepods-burstable-pod<uid>.slice:cri-containerd:<container-id></font>` 下
+ BestEffort （尽最大努力）类型的创建在 `<font style="color:#DF2A3F;">RootCgroup/system.slice/containerd.service/kubepods-besteffort-pod<uid>.slice:cri-containerd:<container-id></font>` 下

我们可以通过 `<font style="color:#DF2A3F;">mount | grep cgroup</font>` 命令查看 RootCgroup：

```shell
➜ mount | grep cgroup
tmpfs on /sys/fs/cgroup type tmpfs (ro,nosuid,nodev,noexec,mode=755)
cgroup on /sys/fs/cgroup/systemd type cgroup (rw,nosuid,nodev,noexec,relatime,xattr,release_agent=/usr/lib/systemd/systemd-cgroups-agent,name=systemd)
cgroup on /sys/fs/cgroup/blkio type cgroup (rw,nosuid,nodev,noexec,relatime,blkio)
cgroup on /sys/fs/cgroup/cpuset type cgroup (rw,nosuid,nodev,noexec,relatime,cpuset)
cgroup on /sys/fs/cgroup/cpu,cpuacct type cgroup (rw,nosuid,nodev,noexec,relatime,cpuacct,cpu)
cgroup on /sys/fs/cgroup/memory type cgroup (rw,nosuid,nodev,noexec,relatime,memory)
cgroup on /sys/fs/cgroup/perf_event type cgroup (rw,nosuid,nodev,noexec,relatime,perf_event)
cgroup on /sys/fs/cgroup/devices type cgroup (rw,nosuid,nodev,noexec,relatime,devices)
cgroup on /sys/fs/cgroup/pids type cgroup (rw,nosuid,nodev,noexec,relatime,pids)
cgroup on /sys/fs/cgroup/hugetlb type cgroup (rw,nosuid,nodev,noexec,relatime,hugetlb)
cgroup on /sys/fs/cgroup/net_cls,net_prio type cgroup (rw,nosuid,nodev,noexec,relatime,net_prio,net_cls)
cgroup on /sys/fs/cgroup/freezer type cgroup (rw,nosuid,nodev,noexec,relatime,freezer)
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761495614380-3c3dc101-fe5f-41ca-a5ae-6283534c3f3b.png)

在 cgroup 的每个子系统下都会创建 QoS level cgroups， 此外在对应的 QoS level cgroups 还会为 pod 创建 Pod level cgroups。比如我们创建一个如下所示的 Pod：

```yaml
# qos-demo.yaml
apiVersion: v1
kind: Pod
metadata:
  name: qos-demo
spec:
  containers:
  - name: nginx
    image: nginx:latest
    resources:
      requests:
        cpu: 250m
        memory: 1Gi
      limits:
        cpu: 500m
        memory: 2Gi
```

直接创建上面的资源对象即可：

```shell
# 引用资源清单文件
➜ kubectl apply -f qos-demo.yaml
pod/qos-demo created

➜ kubectl get pods qos-demo -o wide
NAME       READY   STATUS    RESTARTS   AGE   IP               NODE           NOMINATED NODE   READINESS GATES
qos-demo   1/1     Running   0          20s   192.244.211.36   hkk8snode001   <none>           <none>

➜ kubectl get pods qos-demo -o yaml | grep uid
  uid: 76602608-e9c6-4a04-9a5a-8f7cb382a17e
  
➜ kubectl get pods qos-demo -o yaml | grep qosClass
  qosClass: Burstable # 不稳定的，设置了 request 和 limits 但是不相等。
```

由于该 Pod 的设置的资源 `<font style="color:#DF2A3F;">requests != limits</font>`，所以其属于 Burstable 类别的 Pod，kubelet 会在其所属 QoS 下创建 `<font style="color:#DF2A3F;">RootCgroup/system.slice/containerd.service/kubepods-burstable-pod<uid>.slice:cri-containerd:<container-id></font>` 这个 Cgroup Level，比如我们查看内存这个子系统的 cgroup：

```shell
# 进入到对应的 hkk8snode001 节点中执行
# 还有一个 pause 容器的 cgroup level
➜ ls /sys/fs/cgroup/memory/system.slice/containerd.service/kubepods-burstable-pod489a19f2_8d75_474c_988f_5854b61b839f.slice:cri-containerd:4782243ba3260125513af20689fcea31b52eae1cbabeafeb1f7a52bcdcd5b44b
cgroup.clone_children           memory.kmem.tcp.max_usage_in_bytes  memory.oom_control
cgroup.event_control            memory.kmem.tcp.usage_in_bytes      memory.pressure_level
cgroup.procs                    memory.kmem.usage_in_bytes          memory.soft_limit_in_bytes
memory.failcnt                  memory.limit_in_bytes               memory.stat
memory.force_empty              memory.max_usage_in_bytes           memory.swappiness
memory.kmem.failcnt             memory.memsw.failcnt                memory.usage_in_bytes
memory.kmem.limit_in_bytes      memory.memsw.limit_in_bytes         memory.use_hierarchy
memory.kmem.max_usage_in_bytes  memory.memsw.max_usage_in_bytes     notify_on_release
memory.kmem.slabinfo            memory.memsw.usage_in_bytes         tasks
memory.kmem.tcp.failcnt         memory.move_charge_at_immigrate
memory.kmem.tcp.limit_in_bytes  memory.numa_stat
```

上面创建的应用容器进程 ID 会被写入到上面的 tasks 文件中：

```shell
➜ cat tasks
64133
64170
64171
64172
64173

➜ ps -aux |grep nginx
root      64133  0.0  0.0   8840  3488 ?        Ss   15:56   0:00 nginx: master process nginx -g daemon off;
101       64170  0.0  0.0   9228  1532 ?        S    15:56   0:00 nginx: worker process
101       64171  0.0  0.0   9228  1532 ?        S    15:56   0:00 nginx: worker process
101       64172  0.0  0.0   9228  1532 ?        S    15:56   0:00 nginx: worker process
101       64173  0.0  0.0   9228  1532 ?        S    15:56   0:00 nginx: worker process
```

这样我们的容器进程就会受到该 cgroup 的限制了，在 pod 的资源清单中我们设置了 memory 的 limits 值为 2Gi，kubelet 则会将该限制值写入到 `<font style="color:#DF2A3F;">memory.limit_in_bytes</font>` 中去：

```shell
➜ cat memory.limit_in_bytes
2147483648 # 2147483648 / 1024 / 1024 / 1024 = 2
```

同样对于 cpu 资源一样可以在对应的子系统中找到创建的对应 cgroup：

```shell
➜ ls /sys/fs/cgroup/cpu/system.slice/containerd.service/kubepods-burstable-pod489a19f2_8d75_474c_988f_5854b61b839f.slice:cri-containerd:4782243ba3260125513af20689fcea31b52eae1cbabeafeb1f7a52bcdcd5b44b
cgroup.clone_children  cpuacct.stat          cpu.cfs_period_us  cpu.rt_runtime_us  notify_on_release
cgroup.event_control   cpuacct.usage         cpu.cfs_quota_us   cpu.shares         tasks
cgroup.procs           cpuacct.usage_percpu  cpu.rt_period_us   cpu.stat

➜ cat tasks
64133
64170
64171
64172
64173

➜ cat cpu.cfs_quota_us
50000  # 500m
```

:::color1
最后关于 QoS 还有一点建议，

+ <u><font style="color:#DF2A3F;">如果资源充足，可将 QoS pods 类型均设置为 Guaranteed</font></u>。
+ <u><font style="color:#DF2A3F;">用计算资源换业务性能和稳定性，减少排查问题时间和成本。</font></u>如果<u><font style="color:#DF2A3F;">想更好的提高资源利用率，业务服务可以设置为 Guaranteed，而其他服务根据重要程度可分别设置为 Burstable 或 Best-Effort。</font></u>

:::

<details class="lake-collapse"><summary id="u3a00a46f"><span class="ne-text">小总结</span></summary><p id="uea952487" class="ne-p"><span class="ne-text">Kubernetes 在集群资源不足的情况下，删除 Pod 来释放资源的 QoS 顺序是 Best-Effort(最容易被删除) &gt; Burstable(中间区间) &gt; Guaranteed(最后被删除)</span></p></details>
