<font style="color:rgb(28, 30, 33);">通过该控制器的名称我们可以看出它的用法：</font>`<font style="color:#DF2A3F;">Daemon</font>`<font style="color:rgb(28, 30, 33);">，就是用来部署守护进程的，</font>`<font style="color:#DF2A3F;">DaemonSet</font>`<font style="color:rgb(28, 30, 33);">用于在每个 Kubernetes 节点中将守护进程的副本作为后台进程运行，说白了就是在每个节点部署一个 Pod 副本，当节点加入到 Kubernetes 集群中，Pod 会被调度到该节点上运行，当节点从集群只能够被移除后，该节点上的这个 Pod 也会被移除，当然，如果我们删除 DaemonSet，所有和这个对象相关的 Pods 都会被删除。那么在哪种情况下我们会需要用到这种业务场景呢？其实这种场景还是比较普通的，比如：</font>

+ <font style="color:rgb(28, 30, 33);">集群存储守护程序，如 Glusterd、Ceph 要部署在每个节点上以提供持久性存储；</font>
+ <font style="color:rgb(28, 30, 33);">节点监控守护进程，如 Prometheus 监控集群，可以在每个节点上运行一个 </font>`<font style="color:#DF2A3F;">node-exporter</font>`<font style="color:rgb(28, 30, 33);"> 进程来收集监控节点的信息；</font>
+ <font style="color:rgb(28, 30, 33);">日志收集守护程序，如 Fluentd 或 Logstash，在每个节点上运行以收集容器的日志</font>
+ <font style="color:rgb(28, 30, 33);">节点网络插件，比如 Flannel、Calico，在每个节点上运行为 Pod 提供网络服务。</font>

<font style="color:rgb(28, 30, 33);">这里需要特别说明的一个就是关于 DaemonSet 运行的 Pod 的调度问题，正常情况下，Pod 运行在哪个节点上是由 Kubernetes 的调度器策略来决定的，然而，由 DaemonSet 控制器创建的 Pod 实际上提前已经确定了在哪个节点上了（Pod 创建时指定了</font>`<font style="color:#DF2A3F;">.spec.nodeName</font>`<font style="color:rgb(28, 30, 33);">），所以：</font>

+ `<font style="color:#DF2A3F;">DaemonSet</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">并不关心一个节点的 </font>`<font style="color:#DF2A3F;">unshedulable</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">字段，这个我们会在后面的调度章节和大家讲解的。</font>
+ `<font style="color:#DF2A3F;">DaemonSet</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">可以创建 Pod，即使调度器还没有启动。</font>

<font style="color:rgb(28, 30, 33);">下面我们直接使用一个示例来演示下，在每个节点上部署一个 Nginx Pod：</font>

```yaml
# nginx-ds.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nginx-ds
  namespace: default
spec:
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

<font style="color:rgb(28, 30, 33);">然后直接创建即可：</font>

```shell
➜  ~ kubectl apply -f nginx-ds.yaml
daemonset.apps/nginx-ds created
```

<font style="color:rgb(28, 30, 33);">创建完成后，我们查看 Pod 的状态：</font>

```shell
➜  ~ kubectl get nodes
NAME             STATUS   ROLES           AGE   VERSION
hkk8smaster001   Ready    control-plane   18h   v1.27.6
hkk8snode001     Ready    <none>          18h   v1.27.6
hkk8snode002     Ready    <none>          18h   v1.27.6

➜  ~ kubectl get pods -l k8s-app=nginx -o wide
NAME             READY   STATUS    RESTARTS   AGE   IP               NODE             NOMINATED NODE   READINESS GATES
nginx-ds-96kf8   1/1     Running   0          15s   192.244.51.210   hkk8snode002     <none>           <none>
nginx-ds-hn6zb   1/1     Running   0          15s   192.244.211.16   hkk8snode001     <none>           <none>
```

<font style="color:rgb(28, 30, 33);">我们观察可以发现除了 </font>`<font style="color:#DF2A3F;">hkk8smaster001</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">节点之外的 2 个节点上都有一个相应的 Pod 运行，因为 </font>`<font style="color:#DF2A3F;">hkk8smaster001</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">节点上默认被打上了</font>`<font style="color:#DF2A3F;">污点</font>`<font style="color:rgb(28, 30, 33);">，所以默认情况下不能调度普通的 Pod 上去，后面讲解调度器的时候会和大家学习如何调度上去。</font>

<font style="color:rgb(28, 30, 33);">基本上我们可以用下图来描述 DaemonSet 的拓扑图：</font>

![](https://cdn.nlark.com/yuque/0/2024/jpeg/2555283/1730551288717-e34aa937-d704-4090-a110-5e13a0d07ca7.jpeg)

<font style="color:#DF2A3F;">集群中的 Pod 和 Node 是一一对应的关系，而 DaemonSet 会管理全部机器上的 Pod 副本，负责对它们进行更新和删除。</font>

<font style="color:rgb(28, 30, 33);">那么，DaemonSet 控制器是如何保证每个 Node 上有且只有一个被管理的 Pod 呢？</font>

+ <font style="color:rgb(28, 30, 33);">首先控制器从 Etcd 获取到所有的 Node 列表，然后遍历所有的 Node。</font>
+ <font style="color:rgb(28, 30, 33);">根据资源对象定义是否有调度相关的配置，然后分别检查 Node 是否符合要求。</font>
+ <font style="color:rgb(28, 30, 33);">在可运行 Pod 的节点上检查是否已有对应的 Pod，如果没有，则在这个 Node 上创建该 Pod；如果有，并且数量大于 1，那就把多余的 Pod 从这个节点上删除；如果有且只有一个 Pod，那就说明是正常情况。</font>

<font style="color:rgb(28, 30, 33);">实际上当我们学习了资源调度后，我们也可以自己用 Deployment 来实现 DaemonSet 的效果，这里我们明白 DaemonSet 如何使用的即可，当然该资源对象也有对应的更新策略，有 </font>`<font style="color:#DF2A3F;">OnDelete</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">和 </font>`<font style="color:#DF2A3F;">RollingUpdate</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">两种方式，默认是滚动更新。</font>

---

:::success
💎<font style="color:rgb(28, 30, 33);">DaemonSet</font>

:::

> <font style="color:rgb(28, 30, 33);">Reference：</font>[https://kubernetes.io/zh/docs/concepts/workloads/controllers/daemonset/](https://kubernetes.io/zh/docs/concepts/workloads/controllers/daemonset/)
>

`<font style="color:#E8323C;">DaemonSet 后台伴随线程，K8s集群的每个机器（每一个Node节点）都运行一个程序（默认Master除外，Master节点不会调度Pod过去[Master节点有污点]）</font>`

<font style="color:#E8323C;">无需指定副本数量</font><font style="color:rgb(28, 30, 33);">，没有相应的 </font>`<font style="color:#DF2A3F;">replicas</font>`<font style="color:rgb(28, 30, 33);"> 字段指定；因为默认给集群每个机器都部署一份（Master 节点除外）</font>

<font style="color:rgb(28, 30, 33);">DaemonSet 确保全部（或者某些）节点上运行一个 Pod 的副本。当有节点加入集群时， 也会为他们新增一个 Pod 。 当有节点从集群移除时，这些 Pod 也会被回收。删除 DaemonSet 将会删除它创建的所有 Pod。</font>

<font style="color:rgb(28, 30, 33);">DaemonSet 控制器确保所有（或一部分）的节点都运行了一个指定的 Pod 副本。</font>

+ <font style="color:#601BDE;">每当向集群中添加一个节点时，指定的 Pod 副本也将添加到该节点上</font>
+ <font style="color:#601BDE;">当节点从集群中移除时，Pod 也就被垃圾回收了</font>
+ <font style="color:#601BDE;">删除一个 DaemonSet 可以清理所有由其创建的 Pod</font>

<font style="color:rgb(0, 0, 0);">DaemonSet 保证在每个 Node 上都运行一个容器副本，常用来部署一些集群的日志、监控或者其他系统管理应用。典型的应用包括：</font>

+ <font style="color:#ED740C;">日志收集</font><font style="color:rgb(0, 0, 0);">，比如 fluentd，logstash 等</font>
+ <font style="color:#ED740C;">系统监控</font><font style="color:rgb(0, 0, 0);">，比如 Prometheus Node Exporter，Collectd，New Relic agent，Ganglia gmond 等</font>
+ <font style="color:#ED740C;">系统程序</font><font style="color:rgb(0, 0, 0);">，比如 kube-proxy，kube-dns，Glusterd，Ceph 等</font>

![](https://cdn.nlark.com/yuque/0/2023/png/2555283/1687602505964-aad7c1c9-66a1-455f-93ee-5a01c78ba934.png)

