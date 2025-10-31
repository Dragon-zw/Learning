<font style="color:rgb(28, 30, 33);">前面我们一起学习了 Pod 的原理和一些基本使用，但是在实际使用的时候并不会直接使用 Pod，而是会使用各种控制器来满足我们的需求，Kubernetes 中运行了一系列控制器来确保集群的当前状态与期望状态保持一致，它们就是 Kubernetes 的大脑。例如，ReplicaSet 控制器负责维护集群中运行的 Pod 数量；Node 控制器负责监控节点的状态，并在节点出现故障时及时做出响应。总而言之，</font>**<u><font style="color:#DF2A3F;">在 Kubernetes 中，每个控制器只负责某种类型的特定资源。</font></u>**

## <font style="color:rgb(28, 30, 33);">1 控制器</font>
<font style="color:rgb(28, 30, 33);">Kubernetes 控制器会监听资源的 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">创建/更新/删除</font>`<font style="color:rgb(28, 30, 33);"> 事件，并触发 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">Reconcile</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">调谐函数作为响应，整个调整过程被称作 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">“Reconcile Loop”（调谐循环）</font>`<font style="color:rgb(28, 30, 33);"> 或者 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">“Sync Loop”（同步循环）</font>`<font style="color:rgb(28, 30, 33);">。</font><u><font style="color:#DF2A3F;">Reconcile 是一个使用资源对象的命名空间和资源对象名称来调用的函数，使得资源对象的实际状态与 资源清单中定义的状态保持一致。（不断的将资源对象的实际状态和期望状态保持一致的过程）</font></u><font style="color:rgb(28, 30, 33);">调用完成后，Reconcile 会将资源对象的状态更新为当前实际状态。我们可以用下面的一段伪代码来表示这个过程：</font>

```go
for {
  desired := getDesiredState()  // 期望的状态
  current := getCurrentState()  // 当前实际状态
  if current == desired {  // 如果状态一致则什么都不做
    // nothing to do
  } else {  // 如果状态不一致则调整编排，到一致为止
    // change current to desired status
  }
}
```

<font style="color:rgb(28, 30, 33);">这个编排模型就是 Kubernetes 项目中的一个通用编排模式，即：</font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">控制循环（control loop）</font>`<font style="color:rgb(28, 30, 33);">。</font>

## <font style="color:rgb(28, 30, 33);">2 ReplicaSet</font>
<font style="color:rgb(28, 30, 33);">假如我们现在有一个 Pod 正在提供线上的服务，我们来想想一下我们可能会遇到的一些场景：</font>

+ <font style="color:rgb(28, 30, 33);">某次运营活动非常成功，网站访问量突然暴增</font>
+ <font style="color:rgb(28, 30, 33);">运行当前 Pod 的节点发生故障了，Pod 不能正常提供服务了</font>

<font style="color:rgb(28, 30, 33);">第一种情况，可能比较好应对，活动之前我们可以大概计算下会有多大的访问量，提前多启动几个 Pod 副本，活动结束后再把多余的 Pod 杀掉，虽然有点麻烦，但是还是能够应对这种情况的。</font>

<font style="color:rgb(28, 30, 33);">第二种情况，可能某天夜里收到大量报警说服务挂了，然后起来打开电脑在另外的节点上重新启动一个新的 Pod，问题可以解决。</font>

<font style="color:rgb(28, 30, 33);">但是如果我们都人工的去解决遇到的这些问题，似乎又回到了以前刀耕火种的时代了是吧？如果有一种工具能够来帮助我们自动管理 Pod 就好了，Pod 挂了自动帮我在合适的节点上重新启动一个 Pod，这样是不是遇到上面的问题我们都不需要手动去解决了。</font>

<font style="color:rgb(28, 30, 33);">而 ReplicaSet 这种资源对象就可以来帮助我们实现这个功能，</font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">ReplicaSet（RS）</font>`<font style="color:rgb(28, 30, 33);"> 的主要作用就是维持一组 Pod 副本的运行，保证一定数量的 Pod 在集群中正常运行，ReplicaSet 控制器会持续监听它说控制的这些 Pod 的运行状态，在 Pod 发送故障数量减少或者增加时会触发调谐过程，始终保持副本数量一定。</font>

<font style="color:rgb(28, 30, 33);">和 Pod 一样我们仍然还是通过 YAML 文件来描述我们的 ReplicaSet 资源对象，如下 YAML 文件是一个常见的 ReplicaSet 定义：</font>

```yaml
# nginx-rs.yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-rs
  namespace: default
spec:
  replicas: 3 # 期望的 Pod 副本数量，默认值为1
  selector: # Label Selector，必须匹配 Pod 模板中的标签
    matchLabels:
      app: nginx
  template: # Pod 模板
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

<font style="color:rgb(28, 30, 33);">上面的 YAML 文件结构和我们之前定义的 Pod 看上去没太大两样，有常见的 apiVersion、kind、metadata，在 spec 下面描述 ReplicaSet 的基本信息，其中包含 3 个重要内容：</font>

+ <font style="color:rgb(28, 30, 33);">replias：表示期望的 Pod 的副本数量</font>
+ <font style="color:rgb(28, 30, 33);">selector：Label Selector，用来匹配要控制的 Pod 标签，需要和下面的 Pod 模板中的标签一致</font>
+ <font style="color:rgb(28, 30, 33);">template：Pod 模板，实际上就是以前我们定义的 Pod 内容，相当于把一个 Pod 的描述以模板的形式嵌入到了 ReplicaSet 中来。</font>

:::success
⚓Pod 模板

Pod 模板这个概念非常重要，因为后面我们讲解到的大多数控制器，都会使用 Pod 模板来统一定义它所要管理的 Pod。更有意思的是，我们还会看到其他类型的对象模板，比如 Volume 的模板等。

:::

<font style="color:rgb(28, 30, 33);">上面就是我们定义的一个普通的 ReplicaSet 资源清单文件，ReplicaSet 控制器会通过定义的 Label Selector 标签去查找集群中的 Pod 对象：</font>

![](https://cdn.nlark.com/yuque/0/2025/jpeg/2555283/1760368977173-e4cfa1c3-5efb-4f6a-b291-246e8dd34d6c.jpeg)

<font style="color:rgb(28, 30, 33);">我们直接来创建上面的资源对象：</font>

```shell
➜  ~ kubectl apply -f nginx-rs.yaml
replicaset.apps/nginx-rs created

# 查看 Replicas 的详细信息
➜  ~ kubectl get rs nginx-rs -o wide 
NAME       DESIRED   CURRENT   READY   AGE   CONTAINERS   IMAGES   SELECTOR
nginx-rs   3         3         3       15s   nginx        nginx    app=nginx
```

<font style="color:rgb(28, 30, 33);">通过查看 RS 可以看到当前资源对象的描述信息，包括</font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">DESIRED</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">CURRENT</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">READY</font>`<font style="color:rgb(28, 30, 33);">的状态值，创建完成后，可以利用如下命令查看下 Pod 列表：</font>

```shell
➜  ~ kubectl get pods -l app=nginx -o wide 
NAME             READY   STATUS    RESTARTS   AGE   IP               NODE             NOMINATED NODE   READINESS GATES
nginx-rs-4v8dl   1/1     Running   0          45s   192.244.22.210   hkk8smaster001   <none>           <none>
nginx-rs-8qkds   1/1     Running   0          45s   192.244.51.202   hkk8snode002     <none>           <none>
nginx-rs-tmzt6   1/1     Running   0          45s   192.244.211.10   hkk8snode001     <none>           <none>
```

<font style="color:rgb(28, 30, 33);">可以看到现在有 3 个 Pod，这 3 个 Pod 就是我们在 RS 中声明的 3 个副本，比如我们删除其中一个 Pod：</font>

```shell
➜  ~ kubectl delete pod nginx-rs-4v8dl
pod "nginx-rs-4v8dl" deleted
```

<font style="color:rgb(28, 30, 33);">然后再查看 Pod 列表：</font>

```shell
➜  ~ kubectl get pods -l app=nginx -o wide 
NAME             READY   STATUS    RESTARTS   AGE    IP               NODE             NOMINATED NODE   READINESS GATES
nginx-rs-8qkds   1/1     Running   0          105s   192.244.51.202   hkk8snode002     <none>           <none>
nginx-rs-tmzt6   1/1     Running   0          105s   192.244.211.10   hkk8snode001     <none>           <none>
nginx-rs-vr4q9   1/1     Running   0          15s    192.244.22.211   hkk8smaster001   <none>           <none>
```

<font style="color:rgb(28, 30, 33);">可以看到又重新出现了一个 Pod，这个就是上面我们所说的 ReplicaSet 控制器为我们做的工作，我们在 YAML 文件中声明了 3 个副本，然后现在我们删除了一个副本，就变成了两个，这个时候 ReplicaSet 控制器监控到控制的 Pod 数量和期望的 3 不一致，所以就需要启动一个新的 Pod 来保持 3 个副本，这个过程上面我们说了就是</font>`<font style="color:rgb(28, 30, 33);background-color:rgb(246, 247, 248);">调谐</font>`<font style="color:rgb(28, 30, 33);">的过程。同样可以查看 RS 的描述信息来查看到相关的事件信息：</font>

```shell
➜  ~ kubectl describe rs nginx-rs
Name:         nginx-rs
Namespace:    default
Selector:     app=nginx
Labels:       <none>
Annotations:  <none>
Replicas:     3 current / 3 desired
Pods Status:  3 Running / 0 Waiting / 0 Succeeded / 0 Failed
Pod Template:
  Labels:  app=nginx
  Containers:
   nginx:
    Image:        nginx
    Port:         80/TCP
    Host Port:    0/TCP
    Environment:  <none>
    Mounts:       <none>
  Volumes:        <none>
Events:
  Type    Reason            Age   From                   Message
  ----    ------            ----  ----                   -------
  Normal  SuccessfulCreate  2m2s  replicaset-controller  Created pod: nginx-rs-tmzt6
  Normal  SuccessfulCreate  2m2s  replicaset-controller  Created pod: nginx-rs-8qkds
  Normal  SuccessfulCreate  2m2s  replicaset-controller  Created pod: nginx-rs-4v8dl
  Normal  SuccessfulCreate  31s   replicaset-controller  Created pod: nginx-rs-vr4q9
```

<font style="color:rgb(28, 30, 33);">可以发现最开始通过 ReplicaSet 控制器创建了 3 个 Pod，后面我们删除了 Pod 后， ReplicaSet 控制器又为我们创建了一个 Pod，和上面我们的描述是一致的。如果这个时候我们把 RS 资源对象的 Pod 副本更改为 2 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">spec.replicas=2</font>`<font style="color:rgb(28, 30, 33);">，这个时候我们来更新下资源对象：</font>

```shell
➜  ~ kubectl patch rs nginx-rs -p '{"spec":{"replicas":2}}' 
# 修改 Yaml 资源清单文件
# ➜  ~ kubectl apply -f rs.yaml
# replicaset.apps/nginx-rs configured

➜  ~ kubectl get rs nginx-rs
NAME       DESIRED   CURRENT   READY   AGE
nginx-rs   2         2         2       4m35s

# 查看 Replicas 的详细信息
➜  ~ kubectl describe rs nginx-rs
Name:         nginx-rs
Namespace:    default
Selector:     app=nginx
Labels:       <none>
Annotations:  <none>
Replicas:     2 current / 2 desired
Pods Status:  2 Running / 0 Waiting / 0 Succeeded / 0 Failed
Pod Template:
  Labels:  app=nginx
  Containers:
   nginx:
    Image:        nginx
    Port:         80/TCP
    Host Port:    0/TCP
    Environment:  <none>
    Mounts:       <none>
  Volumes:        <none>
Events:
  Type    Reason            Age    From                   Message
  ----    ------            ----   ----                   -------
  Normal  SuccessfulCreate  4m45s  replicaset-controller  Created pod: nginx-rs-tmzt6
  Normal  SuccessfulCreate  4m45s  replicaset-controller  Created pod: nginx-rs-8qkds
  Normal  SuccessfulCreate  4m45s  replicaset-controller  Created pod: nginx-rs-4v8dl
  Normal  SuccessfulCreate  3m14s  replicaset-controller  Created pod: nginx-rs-vr4q9
  Normal  SuccessfulDelete  26s    replicaset-controller  Deleted pod: nginx-rs-tmzt6
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760369807510-f42a8ae7-b713-48b1-be4d-bae9d59aba7a.png)

<font style="color:rgb(28, 30, 33);">可以看到 Replicaset 控制器在发现我们的资源声明中副本数变更为 2 后，就主动去删除了一个 Pod，这样副本数就和期望的始终保持一致了：</font>

```shell
➜  ~ kubectl get pods -l app=nginx -o wide 
NAME             READY   STATUS    RESTARTS   AGE     IP               NODE             NOMINATED NODE   READINESS GATES
nginx-rs-8qkds   1/1     Running   0          5m25s   192.244.51.202   hkk8snode002     <none>           <none>
nginx-rs-vr4q9   1/1     Running   0          3m55s   192.244.22.211   hkk8smaster001   <none>           <none>
```

<font style="color:rgb(28, 30, 33);">我们可以随便查看一个 Pod 的描述信息可以看到这个 Pod 的所属控制器信息：</font>

```shell
➜  ~ kubectl describe pod nginx-rs-8qkds
Name:             nginx-rs-8qkds
Namespace:        default
Priority:         0
Service Account:  default
Node:             hkk8snode002/192.168.178.37
Start Time:       Mon, 13 Oct 2025 23:31:44 +0800
Labels:           app=nginx
Annotations:      cni.projectcalico.org/containerID: 022333650d10525421eb1768bbb71f6e9db3ab8e2308ce878b4a7b1c7e29f559
                  cni.projectcalico.org/podIP: 192.244.51.202/32
                  cni.projectcalico.org/podIPs: 192.244.51.202/32
Status:           Running
IP:               192.244.51.202
IPs:
  IP:           192.244.51.202
Controlled By:  ReplicaSet/nginx-rs
[......]
```

<font style="color:rgb(28, 30, 33);">另外被 ReplicaSet 持有的 Pod 有一个 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">metadata.ownerReferences</font>`<font style="color:rgb(28, 30, 33);"> 指针指向当前的 ReplicaSet，表示当前 Pod 的所有者，这个引用主要会被集群中的</font>**<font style="color:#DF2A3F;">垃圾收集器</font>**<font style="color:rgb(28, 30, 33);">使用以清理失去所有者的 Pod 对象。这个 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">ownerReferences</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">和数据库中的</font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">外键</font>`<font style="color:rgb(28, 30, 33);">是不是非常类似。可以通过将 Pod 资源描述信息导出查看：</font>

```shell
➜  ~ kubectl get pod nginx-rs-8qkds -o yaml
apiVersion: v1
kind: Pod
metadata:
  annotations:
    cni.projectcalico.org/containerID: 022333650d10525421eb1768bbb71f6e9db3ab8e2308ce878b4a7b1c7e29f559
    cni.projectcalico.org/podIP: 192.244.51.202/32
    cni.projectcalico.org/podIPs: 192.244.51.202/32
  creationTimestamp: "2025-10-13T15:31:44Z"
  generateName: nginx-rs-
  labels:
    app: nginx
  name: nginx-rs-8qkds
  namespace: default
  ownerReferences:
  - apiVersion: apps/v1
    blockOwnerDeletion: true
    controller: true
    kind: ReplicaSet
    name: nginx-rs
    uid: 9b360ab3-d4e7-42ae-8405-524dd21cf196
  resourceVersion: "55746"
  uid: f039efdd-3351-4fba-85b3-05cbe1db3021
spec:
  [......]
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760369955878-2d2d58e4-c180-4b4f-8568-c6c29a3f6da8.png)

<font style="color:rgb(28, 30, 33);">我们可以看到 Pod 中有一个 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">metadata.ownerReferences</font>`<font style="color:rgb(28, 30, 33);"> 的字段指向了 ReplicaSet 资源对象。如果要彻底删除 Pod，我们就只能删除 RS 对象：</font>

```shell
➜  ~ kubectl delete rs nginx-rs
# 或者执行 kubectl delete -f nginx-rs.yaml

# 所关联的 Pod 也就已经删除了
➜  ~ kubectl get pods -l app=nginx -o wide 
No resources found in default namespace.
```

<font style="color:rgb(28, 30, 33);">这就是 ReplicaSet 对象的基本使用。</font>

## <font style="color:rgb(28, 30, 33);">3 Replication Controller（可忽略）</font>
<font style="color:rgb(28, 30, 33);">Replication Controller 简称 RC，实际上 RC 和 RS 的功能几乎一致，RS 算是对 RC 的改进，目前唯一的一个区别就是 RC 只支持基于等式的 selector（</font>`<font style="color:#DF2A3F;">env=dev</font>`<font style="color:rgb(28, 30, 33);"> 或 </font>`<font style="color:#DF2A3F;">environment!=qa</font>`<font style="color:rgb(28, 30, 33);">），但 RS 还支持基于集合的 selector（version in (v1.0, v2.0)），这对复杂的运维管理就非常方便了。</font>

<font style="color:rgb(28, 30, 33);">比如上面资源对象如果我们要使用 RC 的话，对应的 selector 是这样的：</font>

```yaml
selector:
  app: nginx
```

<font style="color:rgb(28, 30, 33);">RC 只支持单个 Label 的等式，而 RS 中的 Label Selector 支持</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);background-color:rgb(246, 247, 248);">matchLabels</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">和</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);background-color:rgb(246, 247, 248);">matchExpressions</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">两种形式：</font>

```yaml
selector:
  matchLabels:
    app: nginx
---
selector:
  matchExpressions: # 该选择器要求 Pod 包含名为 app 的标签
    - key: app
      operator: In
      values: # 并且标签的值必须是 nginx
        - nginx
```

:::success
⚓<u><font style="color:#DF2A3F;">总结：</font></u>

<u><font style="color:#DF2A3F;">总的来说 RS 是新一代的 RC，所以以后我们不使用 RC，直接使用 RS 即可，他们的功能都是一致的，但是实际上在实际使用中我们也不会直接使用 RS，而是使用更上层的类似于 Deployment 这样的资源对象。</font></u>

:::

总的来说 RS 是新一代的 RC，所以以后我们不使用 RC，直接使用 RS 即可，他们的功能都是一致的，但是实际上在实际使用中我们也不会直接使用 RS，而是使用更上层的类似于 Deployment 这样的资源对象。

<font style="color:rgb(0, 0, 0);">Kubernetes 官方建议使用 RS (ReplicaSet) 替代 RC (ReplicationController) 进行部署，RS 跟 RC 没有本质的不同，只是名字不一样，并且 </font><font style="color:#DF2A3F;">RS 支持集合式的 Selector</font><font style="color:rgb(0, 0, 0);">。</font>

![](https://cdn.nlark.com/yuque/0/2023/png/2555283/1687541293700-6416e105-921c-40d0-8d90-4e4fd8831425.png)

## 4 ReplicaSet 和 Replication Controller 区别
> ⚠️RC是老版[ 已经淘汰 ]，RS是新版（可以有复杂的选择器[ 表达式 ]），可以理解为RS 是 RC 的升级版。[ Selector 标签选择器会被 RS 控制 ]
>
> HPA 是可以自动监测指标实现自动扩容，RC/RS 需要手动 `<font style="color:#DF2A3F;">scale</font>` 控制副本数。ReplicaSet 会维持 Pod 的副本数与管理员期望的副本数保持一致。
>

:::success
范例：RC 和 RS 的区别

:::

1. 标签选择器：

<font style="color:rgb(0, 0, 0);">ReplicationController 使用标签选择器来确定哪些 Pod 属于自己所管理的集合；</font>ReplicasSet 使用更强大的标签选择器来定义复杂的选择规则，例如可以使用多个标签进行匹配

+ **<font style="color:#DF2A3F;">RC </font>**<font style="color:#DF2A3F;">的</font>`<font style="color:#DF2A3F;">selector</font>`<font style="color:#DF2A3F;">只能用等式</font><font style="color:rgb(51, 51, 51);">（比如</font>`<font style="color:#DF2A3F;">app=nginx</font>`<font style="color:rgb(51, 51, 51);">或者</font>`<font style="color:#DF2A3F;">app!=nginx</font>`<font style="color:rgb(51, 51, 51);">）来获取相关的pod。</font>
+ **<font style="color:#DF2A3F;">RS </font>**<font style="color:#DF2A3F;">除了支持等式还支持通过集合的方式</font><font style="color:rgb(51, 51, 51);">，比如</font>`<font style="color:#DF2A3F;">app in (nginx,nginx1.1)</font>`<font style="color:rgb(51, 51, 51);">，使用 </font>**<font style="color:rgb(51, 51, 51);">RS </font>**<font style="color:rgb(51, 51, 51);">可以让运维进行更复杂的查询。</font>
2. 滚动升级：

<font style="color:#D22D8D;">ReplicasSet 支持滚动升级（Rolling Update）策略，可以让管理员逐步更新Pod和应用程序版本，以便降低升级对系统可用性的影响。而 ReplicationController 没有内置的滚动升级功能，需要手动编写相关的脚本或者工具</font>

3. <font style="color:rgb(0, 0, 0);">副本数控制：</font>

<font style="color:rgb(0, 0, 0);">ReplicationController 只能控制一组 Pod 的固定数量，并确保该数量始终抱持不变，</font>ReplicasSet 可以根据需求，动态的增加或者减少 Pod 的数量，以适应负载变化和容量需求的变化

4. API 版本：

ReplicasSet 是 Kubernetes API 的扩展版本，提供了更多的功能和灵活性，而 <font style="color:rgb(0, 0, 0);">ReplicationController 是 </font>Kubernetes 早期版本中的一个基本控制器对象，已经逐渐淘汰

