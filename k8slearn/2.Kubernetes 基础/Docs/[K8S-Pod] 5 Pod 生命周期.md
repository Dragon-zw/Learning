![](https://cdn.nlark.com/yuque/0/2024/jpeg/2555283/1730550987061-edd10349-337d-4792-91cd-eef4a267e284.jpeg)

<font style="color:rgb(28, 30, 33);">前面我们已经了解了 Pod 的设计原理，接下来我们来了解下 Pod 的生命周期。下图展示了一个 Pod 的完整生命周期过程，其中包含 </font>`<font style="color:#DF2A3F;">Init Container(初始化容器)</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">Pod Hook(PostStart,PreStop)</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">健康检查</font>`<font style="color:rgb(28, 30, 33);"> 三个主要部分，接下来我们就来分别介绍影响 Pod 生命周期的部分：</font>

<font style="color:rgb(28, 30, 33);">首先在介绍 Pod 的生命周期之前，我们先了解下 Pod 的状态，因为 Pod 状态可以反应出当前我们的 Pod 的具体状态信息，也是我们分析排错的一个必备的方式。</font>

## <font style="color:rgb(28, 30, 33);">1 Pod 状态</font>
<font style="color:rgb(28, 30, 33);">首先先了解下 Pod 的状态值，我们可以通过 </font>`<font style="color:#DF2A3F;">kubectl explain pod.status</font>`<font style="color:rgb(28, 30, 33);"> 命令来了解关于 Pod 状态的一些信息</font>

<font style="color:rgb(28, 30, 33);">Pod 的状态定义在 </font>`<font style="color:#DF2A3F;">PodStatus</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">对象中，其中有一个 </font>`<font style="color:#DF2A3F;">phase</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">字段，下面是 </font>`<font style="color:#DF2A3F;">phase</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">的可能取值：</font>

+ <u><font style="color:rgb(28, 30, 33);">挂起（Pending）：Pod 信息已经提交给了集群，但是还没有被调度器调度到合适的节点或者 Pod 里的镜像正在下载</font></u>
+ <u><font style="color:rgb(28, 30, 33);">运行中（Running）：该 Pod 已经绑定到了一个节点上，Pod 中所有的容器都已被创建。至少有一个容器正在运行，或者正处于启动或重启状态</font></u>
+ <u><font style="color:rgb(28, 30, 33);">成功（Succeeded）：Pod 中的所有容器都被成功终止，并且不会再重启</font></u>
+ <u><font style="color:rgb(28, 30, 33);">失败（Failed）：Pod 中的所有容器都已终止了，并且至少有一个容器是因为失败终止。也就是说，容器以非</font></u>`<u><font style="color:#DF2A3F;">0</font></u>`<u><font style="color:rgb(28, 30, 33);">状态退出或者被系统终止</font></u>
+ <u><font style="color:rgb(28, 30, 33);">未知（Unknown）：因为某些原因无法取得 Pod 的状态，通常是因为与 Pod 所在主机通信失败导致的</font></u>

<font style="color:rgb(28, 30, 33);">除此之外，</font>`<font style="color:#DF2A3F;">PodStatus</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">对象中还包含一个 </font>`<font style="color:#DF2A3F;">PodCondition</font>`<font style="color:rgb(28, 30, 33);"> 的数组，里面包含的属性有：</font>

+ `<font style="color:#DF2A3F;">lastProbeTime</font>`<font style="color:rgb(28, 30, 33);">：最后一次探测 Pod Condition 的时间戳。</font>
+ `<font style="color:#DF2A3F;">lastTransitionTime</font>`<font style="color:rgb(28, 30, 33);">：上次 Condition 从一种状态转换到另一种状态的时间。</font>
+ `<font style="color:#DF2A3F;">message</font>`<font style="color:rgb(28, 30, 33);">：上次 Condition 状态转换的详细描述。</font>
+ `<font style="color:#DF2A3F;">reason</font>`<font style="color:rgb(28, 30, 33);">：Condition 最后一次转换的原因。</font>
+ `<font style="color:#DF2A3F;">status</font>`<font style="color:rgb(28, 30, 33);">：Condition 状态类型，可以为 “True”, “False”, and “Unknown”.</font>
+ `<font style="color:#DF2A3F;">type</font>`<font style="color:rgb(28, 30, 33);">：Condition 类型，包括以下方面：</font>
    - `<font style="color:#DF2A3F;">PodScheduled</font>`<font style="color:rgb(28, 30, 33);">（Pod 已经被调度到其他 node 里）</font>
    - `<font style="color:#DF2A3F;">Ready</font>`<font style="color:rgb(28, 30, 33);">（Pod 能够提供服务请求，可以被添加到所有可匹配服务的负载平衡池中）</font>
    - `<font style="color:#DF2A3F;">Initialized</font>`<font style="color:rgb(28, 30, 33);">（所有的</font>`<font style="color:#DF2A3F;">init containers</font>`<font style="color:rgb(28, 30, 33);">已经启动成功）</font>
    - `<font style="color:#DF2A3F;">Unschedulable</font>`<font style="color:rgb(28, 30, 33);">（调度程序现在无法调度 Pod，例如由于缺乏资源或其他限制）</font>
    - `<font style="color:#DF2A3F;">ContainersReady</font>`<font style="color:rgb(28, 30, 33);">（Pod 里的所有容器都是 Ready 状态）</font>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760361087914-4ae835c1-2893-4ba9-bfa5-b434f9cdc2a2.png)

## <font style="color:rgb(28, 30, 33);">2 重启策略</font>
<font style="color:rgb(28, 30, 33);">我们可以通过配置 </font>`<font style="color:#DF2A3F;">restartPolicy</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">字段来设置 Pod 中所有容器的重启策略，其可能值为 </font>`<font style="color:#DF2A3F;">Always</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">OnFailure</font>`<font style="color:#DF2A3F;"> </font>和<font style="color:#DF2A3F;"> </font>`<font style="color:#DF2A3F;">Never</font>`<font style="color:rgb(28, 30, 33);">，默认值为 </font>`<font style="color:#DF2A3F;">Always</font>`<font style="color:#DF2A3F;">，</font>`<font style="color:#DF2A3F;">restartPolicy</font>`<font style="color:rgb(28, 30, 33);"> 指通过 kubelet 在同一节点上重新启动容器。通过 kubelet 重新启动的退出容器将以指数增加延迟（10s，20s，40s…）重新启动，上限为 5 分钟，并在成功执行 10 分钟后重置。不同类型的的控制器可以控制 Pod 的重启策略：</font>

+ `<font style="color:#DF2A3F;">Job</font>`<font style="color:rgb(28, 30, 33);">：适用于一次性任务如批量计算，任务结束后 Pod 会被此类控制器清除。Job 的重启策略只能是</font>`<font style="color:#DF2A3F;">"OnFailure"</font>`<font style="color:#DF2A3F;">或者</font>`<font style="color:#DF2A3F;">"Never"</font>`<font style="color:rgb(28, 30, 33);">。</font>
+ `<font style="color:#DF2A3F;">ReplicaSet</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">Deployment</font>`<font style="color:rgb(28, 30, 33);">：此类控制器希望 Pod 一直运行下去，它们的重启策略只能是</font>`<font style="color:#DF2A3F;">"Always"</font>`<font style="color:rgb(28, 30, 33);">。</font>
+ `<font style="color:#DF2A3F;">DaemonSet</font>`<font style="color:rgb(28, 30, 33);">：每个节点上启动一个 Pod，很明显此类控制器的重启策略也应该是</font>`<font style="color:#DF2A3F;">"Always"</font>`<font style="color:rgb(28, 30, 33);">。</font>

---

在 Kubernetes 中，`restartPolicy` 是一个非常重要的字段，用于定义 Pod 中容器的重启行为。它决定了当容器退出时，Kubernetes 应该如何处理这些容器。`restartPolicy` 的可能值包括 `Always`、`OnFailure` 和 `Never`，下面分别解释它们的含义：

1. Always
+ **含义**: <font style="color:#DF2A3F;">无论容器以何种状态退出（成功或失败），Kubernetes 都会尝试重新启动该容器。</font>
+ **适用场景**: 
    - 适用于需要始终保持运行的服务型容器，例如 Web 服务器、数据库等。
    - 即使容器正常退出（退出码为 0），也会被重新启动。
+ **行为示例**:
    - 如果容器因为错误崩溃（退出码非 0），Kubernetes 会立即重新启动它。
    - 如果容器正常完成任务并退出（退出码为 0），Kubernetes 仍然会重新启动它。

2. OnFailure
+ **含义**: <font style="color:#DF2A3F;">仅当容器以失败状态退出（退出码非 0）时，Kubernetes 才会尝试重新启动该容器。如果容器正常退出（退出码为 0），则不会重新启动。</font>
+ **适用场景**:
    - 适用于批处理任务或一次性任务，例如数据处理脚本、定时任务等。
    - 只有在任务失败时才需要重试，成功完成的任务不需要重新运行。
+ **行为示例**:
    - 如果容器因错误崩溃（退出码非 0），Kubernetes 会重新启动它。
    - 如果容器成功完成任务并退出（退出码为 0），Kubernetes 不会重新启动它。

3. Never
+ **含义**: <font style="color:#DF2A3F;">无论容器以何种状态退出，Kubernetes 都不会尝试重新启动该容器。</font>
+ **适用场景**:
    - 适用于一次性任务或调试场景，例如需要手动检查容器日志或文件。
    - 如果容器退出后不需要自动恢复，则可以使用此策略。
+ **行为示例**:
    - 如果容器因错误崩溃（退出码非 0），Kubernetes 不会重新启动它。
    - 如果容器成功完成任务并退出（退出码为 0），Kubernetes 同样不会重新启动它。

:::success
总结对比

:::

| **重启策略** | **容器失败时的行为** | **容器成功时的行为** | **适用场景** |
| --- | --- | --- | --- |
| Always | 重新启动 | 重新启动 | 长期运行的服务 |
| OnFailure | 重新启动 | 不重新启动 | 批处理任务 |
| Never | 不重新启动 | 不重新启动 | 一次性任务 |


:::success
注意事项

:::

1. **默认值**: 如果未显式设置 `<font style="color:#DF2A3F;">restartPolicy</font>`，其默认值为 `<font style="color:#DF2A3F;">Always</font>`。
2. **Pod 生命周期**: `<font style="color:#DF2A3F;">restartPolicy</font>` 仅影响容器的重启行为，而不会影响整个 Pod 的生命周期。例如，即使容器不断失败并重启，Pod 本身仍会保持运行状态。
3. **与控制器的关系**: 在使用 Deployment、StatefulSet 等控制器时，`<font style="color:#DF2A3F;">restartPolicy</font>` 通常设置为 `<font style="color:#DF2A3F;">Always</font>`，因为这些控制器本身会管理 Pod 的生命周期和重启行为。<u>⚓</u><u>通过合理配置 </u>`<u><font style="color:#DF2A3F;">restartPolicy</font></u>`<u>，可以根据业务需求灵活控制容器的运行和恢复行为。</u>

## <font style="color:rgb(28, 30, 33);">3 初始化容器</font>
<font style="color:rgb(28, 30, 33);">了解了 Pod 状态后，首先来了解下 Pod 中最新启动的 </font>`<font style="color:#DF2A3F;">Init Container</font>`<font style="color:rgb(28, 30, 33);">，也就是我们平时常说的</font>**<font style="color:rgb(28, 30, 33);">初始化容器</font>**<font style="color:rgb(28, 30, 33);">。</font>`<font style="color:#DF2A3F;">Init Container</font>`<font style="color:rgb(28, 30, 33);">就是用来做初始化工作的容器，可以是一个或者多个，如果有多个的话，这些容器会按定义的顺序依次执行。我们知道一个 Pod 里面的所有容器是共享数据卷和 </font>`<font style="color:#DF2A3F;">Network Namespace</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">的，所以 </font>`<font style="color:#DF2A3F;">Init Container</font>`<font style="color:rgb(28, 30, 33);"> 里面产生的数据可以被主容器使用到。从上面的 Pod 生命周期的图中可以看出初始化容器是独立与主容器之外的，只有所有的`初始化容器执行完之后，主容器才会被启动。那么初始化容器有哪些应用场景呢：</font>

+ <font style="color:rgb(28, 30, 33);">等待其他模块 Ready：这个可以用来解决服务之间的依赖问题，比如我们有一个 Web 服务，该服务又依赖于另外一个数据库服务，但是在我们启动这个 Web 服务的时候我们并不能保证依赖的这个数据库服务就已经启动起来了，所以可能会出现一段时间内 Web 服务连接数据库异常。要解决这个问题的话我们就可以在 Web 服务的 Pod 中使用一个 </font>`<font style="color:#DF2A3F;">InitContainer</font>`<font style="color:rgb(28, 30, 33);">，在这个初始化容器中去检查数据库是否已经准备好了，准备好了过后初始化容器就结束退出，然后我们主容器的 Web 服务才被启动起来，这个时候去连接数据库就不会有问题了。</font>
+ <font style="color:rgb(28, 30, 33);">做初始化配置：比如集群里检测所有已经存在的成员节点，为主容器准备好集群的配置信息，这样主容器起来后就能用这个配置信息加入集群。</font>
+ <font style="color:rgb(28, 30, 33);">其它场景：如将 Pod 注册到一个中央数据库、配置中心等。</font>

<font style="color:rgb(28, 30, 33);">比如现在我们来实现一个功能，在 Nginx Pod 启动之前去重新初始化首页内容，如下所示的资源清单：（</font>`<font style="color:#DF2A3F;">init-pod.yaml</font>`<font style="color:rgb(28, 30, 33);">）</font>

```yaml
# init-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: init-demo
spec:
  volumes:
    - name: workdir
      emptyDir: {}
  initContainers: # 初始化容器
    - name: install
      image: busybox
      command:
        - wget
        - '-O'
        - '/work-dir/index.html'
        - http://www.baidu.com # https
      volumeMounts:
        - name: workdir
          mountPath: '/work-dir'
  containers:
    - name: web
      image: nginx
      ports:
        - containerPort: 80
      volumeMounts:
        - name: workdir
          mountPath: /usr/share/nginx/html
```

<font style="color:rgb(28, 30, 33);">上面的资源清单中我们首先在 Pod 顶层声明了一个名为 workdir 的 </font>`<font style="color:#DF2A3F;">Volume</font>`<font style="color:rgb(28, 30, 33);">，前面我们用了 hostPath 的模式，这里我们使用的是 </font>`<font style="color:#DF2A3F;">emptyDir{}</font>`<font style="color:rgb(28, 30, 33);">，这个是一个临时的目录，数据会保存在 kubelet 的工作目录下面，生命周期等同于 Pod 的生命周期。</font>

<font style="color:rgb(28, 30, 33);">然后我们定义了一个初始化容器，该容器会下载一个 html 文件到 </font>`<font style="color:#DF2A3F;">/work-dir</font>`<font style="color:rgb(28, 30, 33);"> 目录下面，但是由于我们又将该目录声明挂载到了全局的 Volume，同样的主容器 nginx 也将目录 </font>`<font style="color:#DF2A3F;">/usr/share/nginx/html</font>`<font style="color:rgb(28, 30, 33);"> 声明挂载到了全局的 Volume，所以在主容器的该目录下面会同步初始化容器中创建的 </font>`<font style="color:#DF2A3F;">index.html</font>`<font style="color:rgb(28, 30, 33);"> 文件。</font>

<font style="color:rgb(28, 30, 33);">直接创建上面的 Pod：</font>

```shell
➜  ~ kubectl apply -f init-pod.yaml
```

<font style="color:rgb(28, 30, 33);">创建完成后可以查看该 Pod 的状态：</font>

```shell
➜  ~ kubectl get pods
NAME        READY   STATUS            RESTARTS   AGE
init-demo   0/1     PodInitializing   0          3s

➜  ~ kubectl get pods
NAME                            READY   STATUS     RESTARTS   AGE
init-demo                       0/1     Init:0/1   0          5s
```

<font style="color:rgb(28, 30, 33);">可以发现 Pod 现在的状态处于 </font>`<font style="color:#DF2A3F;">Init:0/1</font>`<font style="color:rgb(28, 30, 33);"> 状态，意思就是现在第一个初始化容器还在执行过程中，此时我们可以查看 Pod 的详细信息：</font>

```shell
➜  ~ kubectl describe pod init-demo
Name:         init-demo
Namespace:    default
Priority:     0
Node:         node1/192.168.31.108
Start Time:   Mon, 01 Nov 2021 18:58:40 +0800
Labels:       <none>
Annotations:  <none>
Status:       Running
IP:           10.244.1.10
IPs:
  IP:  10.244.1.10
Init Containers:
  install:
    Container ID:  containerd://ca0020473b613729e4c853cd0c163023677a631432531ceacbb1aed1ae65bea9
    Image:         busybox
    Image ID:      docker.io/library/busybox@sha256:15e927f78df2cc772b70713543d6b651e3cd8370abf86b2ea4644a9fba21107f
    Port:          <none>
    Host Port:     <none>
    Command:
      wget
      -O
      /work-dir/index.html
      http://www.baidu.com
    State:          Terminated
      Reason:       Completed
      Exit Code:    0
      Started:      Mon, 01 Nov 2021 18:58:43 +0800
      Finished:     Mon, 01 Nov 2021 18:58:43 +0800
    Ready:          True
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-htmjf (ro)
      /work-dir from workdir (rw)
Containers:
  web:
    Container ID:   containerd://18f08b312af9c464f8cc1313b82cfaf05d1910c8dc35d91dddd2810a184a0bfd
    Image:          nginx
    Image ID:       docker.io/library/nginx@sha256:644a70516a26004c97d0d85c7fe1d0c3a67ea8ab7ddf4aff193d9f301670cf36
    Port:           80/TCP
    Host Port:      0/TCP
    State:          Running
      Started:      Mon, 01 Nov 2021 18:58:59 +0800
    Ready:          True
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /usr/share/nginx/html from workdir (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-htmjf (ro)
Conditions:
  Type              Status
  Initialized       True
  Ready             True
  ContainersReady   True
  PodScheduled      True
Volumes:
  workdir:
    Type:       EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:
    SizeLimit:  <unset>
  kube-api-access-htmjf:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    ConfigMapOptional:       <nil>
    DownwardAPI:             true
QoS Class:                   BestEffort
Node-Selectors:              <none>
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  34s   default-scheduler  Successfully assigned default/init-demo to node1
  Normal  Pulling    35s   kubelet            Pulling image "busybox"
  Normal  Pulled     32s   kubelet            Successfully pulled image "busybox" in 2.655408135s
  Normal  Created    32s   kubelet            Created container install
  Normal  Started    32s   kubelet            Started container install
  Normal  Pulling    31s   kubelet            Pulling image "nginx"
  Normal  Pulled     16s   kubelet            Successfully pulled image "nginx" in 15.385097955s
  Normal  Created    16s   kubelet            Created container web
  Normal  Started    16s   kubelet            Started container web
```

<font style="color:rgb(28, 30, 33);">从上面的描述信息里面可以看到初始化容器已经启动了，现在处于 </font>`<font style="color:#DF2A3F;">Running</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">状态，所以还需要稍等，到初始化容器执行完成后退出初始化容器会变成 </font>`<font style="color:#DF2A3F;">Completed</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">状态，然后才会启动主容器。待到主容器也启动完成后，Pod 就会变成</font>`<font style="color:#DF2A3F;">Running</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">状态，然后我们去访问下 Pod 主页，验证下是否有我们初始化容器中下载的页面信息：</font>

```shell
➜  ~ kubectl get pods -o wide
NAME        READY   STATUS    RESTARTS   AGE   IP              NODE           NOMINATED NODE   READINESS GATES
init-demo   1/1     Running   0          95s   192.244.211.7   hkk8snode001   <none>           <none>

# 访问 Pod-IP 内容
➜  ~ curl 192.244.211.7
<!DOCTYPE html>
<!--STATUS OK--><html> <head><meta http-equiv=content-type content=text/html;charset=utf-8><meta http-equiv=X-UA-Compatible content=IE=Edge><meta content=always name=referrer><link rel=stylesheet type=text/css href=http://s1.bdstatic.com/r/www/cache/bdorz/baidu.min.css><title>百度一下，你就知道</title></head> <body link=#0000cc> <div id=wrapper> <div id=head> <div class=head_wrapper> <div class=s_form> <div class=s_form_wrapper> <div id=lg> <img hidefocus=true src=//www.baidu.com/img/bd_logo1.png width=270 height=129> </div> <form id=form name=f action=//www.baidu.com/s class=fm> <input type=hidden name=bdorz_come value=1> <input type=hidden name=ie value=utf-8> <input type=hidden name=f value=8> <input type=hidden name=rsv_bp value=1> <input type=hidden name=rsv_idx value=1> <input type=hidden name=tn value=baidu><span class="bg s_ipt_wr"><input id=kw name=wd class=s_ipt value maxlength=255 autocomplete=off autofocus></span><span class="bg s_btn_wr"><input type=submit id=su value=百度一下 class="bg s_btn"></span> </form> </div> </div> <div id=u1> <a href=http://news.baidu.com name=tj_trnews class=mnav>新闻</a> <a href=http://www.hao123.com name=tj_trhao123 class=mnav>hao123</a> <a href=http://map.baidu.com name=tj_trmap class=mnav>地图</a> <a href=http://v.baidu.com name=tj_trvideo class=mnav>视频</a> <a href=http://tieba.baidu.com name=tj_trtieba class=mnav>贴吧</a> <noscript> <a href=http://www.baidu.com/bdorz/login.gif?login&amp;tpl=mn&amp;u=http%3A%2F%2Fwww.baidu.com%2f%3fbdorz_come%3d1 name=tj_login class=lb>登录</a> </noscript> <script>document.write('<a href="http://www.baidu.com/bdorz/login.gif?login&tpl=mn&u='+ encodeURIComponent(window.location.href+ (window.location.search === "" ? "?" : "&")+ "bdorz_come=1")+ '" name="tj_login" class="lb">登录</a>');</script> <a href=//www.baidu.com/more/ name=tj_briicon class=bri style="display: block;">更多产品</a> </div> </div> </div> <div id=ftCon> <div id=ftConw> <p id=lh> <a href=http://home.baidu.com>关于百度</a> <a href=http://ir.baidu.com>About Baidu</a> </p> <p id=cp>&copy;2017&nbsp;Baidu&nbsp;<a href=http://www.baidu.com/duty/>使用百度前必读</a>&nbsp; <a href=http://jianyi.baidu.com/ class=cp-feedback>意见反馈</a>&nbsp;京ICP证030173号&nbsp; <img src=//www.baidu.com/img/gs.gif> </p> </div> </div> </div> </body> </html>
```

## <font style="color:rgb(28, 30, 33);">4 Pod Hook</font>
<font style="color:rgb(28, 30, 33);">我们知道 Pod 是 Kubernetes 集群中的最小单元，而 Pod 是由容器组成的，所以在讨论 Pod 的生命周期的时候我们可以先来讨论下容器的生命周期。实际上 Kubernetes 为我们的容器提供了生命周期的钩子，就是我们说的 </font>`<font style="color:#DF2A3F;">Pod Hook</font>`<font style="color:rgb(28, 30, 33);">，Pod Hook 是由 kubelet 发起的，当容器中的进程启动前或者容器中的进程终止之前运行，这是包含在容器的生命周期之中。我们可以同时为 Pod 中的所有容器都配置 hook。</font>

<font style="color:rgb(28, 30, 33);">Kubernetes 为我们提供了两种钩子函数：</font>

+ `<font style="color:#DF2A3F;">PostStart</font>`<font style="color:rgb(28, 30, 33);">：这个钩子在容器创建后立即执行。但是，并不能保证钩子将在容器 </font>`<font style="color:#DF2A3F;">ENTRYPOINT</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">之前运行，因为没有参数传递给处理程序。主要用于资源部署、环境准备等。不过需要注意的是如果钩子花费太长时间以至于不能运行或者挂起，容器将不能达到 running 状态。</font>
+ `<font style="color:#DF2A3F;">PreStop</font>`<font style="color:rgb(28, 30, 33);">：这个钩子在容器终止之前立即被调用。它是阻塞的，意味着它是同步的，所以它必须在删除容器的调用发出之前完成。主要用于优雅关闭应用程序、通知其他系统等。如果钩子在执行期间挂起，Pod 阶段将停留在 running 状态并且永不会达到 failed 状态。</font>

<font style="color:rgb(28, 30, 33);">如果 </font>`<font style="color:#DF2A3F;">PostStart</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">或者 </font>`<font style="color:#DF2A3F;">PreStop</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">钩子失败， 它会杀死容器。所以我们应该让钩子函数尽可能的轻量。当然有些情况下，长时间运行命令是合理的， 比如在停止容器之前预先保存状态。</font>

<font style="color:rgb(28, 30, 33);">另外我们有两种方式来实现上面的钩子函数：</font>

+ `<font style="color:#DF2A3F;">Exec</font>`<font style="color:rgb(28, 30, 33);"> - 用于执行一段特定的命令，不过要注意的是该命令消耗的资源会被计入容器。</font>
+ `<font style="color:#DF2A3F;">HTTP</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">- 对容器上的特定的端点执行 HTTP 请求。</font>

<font style="color:rgb(28, 30, 33);">以下示例中，定义了一个 Nginx Pod，其中设置了 PostStart 钩子函数，即在容器创建成功后，写入一句话到 </font>`<font style="color:#DF2A3F;">/usr/share/message</font>`<font style="color:rgb(28, 30, 33);"> 文件中：</font>

```yaml
# pod-poststart.yaml
apiVersion: v1
kind: Pod
metadata:
  name: hook-demo1
spec:
  containers:
    - name: hook-demo1
      image: nginx
      lifecycle:
        postStart:
          exec:
            command:
              [
                '/bin/sh',
                '-c',
                'echo Hello from the postStart handler > /usr/share/message',
              ]
```

<font style="color:rgb(28, 30, 33);">直接创建上面的 Pod：</font>

```shell
# 引用资源清单文件
➜  ~ kubectl apply -f pod-poststart.yaml

➜  ~ kubectl get pods hook-demo1
NAME         READY   STATUS    RESTARTS   AGE
hook-demo1   1/1     Running   0          20s
```

<font style="color:rgb(28, 30, 33);">创建成功后可以查看容器中 </font>`<font style="color:#DF2A3F;">/usr/share/message</font>`<font style="color:rgb(28, 30, 33);"> 文件是否内容正确：</font>

```shell
➜  ~ kubectl exec -it hook-demo1 -- cat /usr/share/message
Hello from the postStart handler
```

<font style="color:rgb(28, 30, 33);">当用户请求删除含有 Pod 的资源对象时（如 Deployment 等），K8S 为了让应用程序优雅关闭（即让应用程序完成正在处理的请求后，再关闭软件），K8S 提供两种信息通知：</font>

+ <font style="color:rgb(28, 30, 33);">默认：K8S 通知 node 执行容器 </font>`<font style="color:#DF2A3F;">stop</font>`<font style="color:rgb(28, 30, 33);"> 命令，容器运行时会先向容器中 PID 为 </font>`<font style="color:#DF2A3F;">1</font>`<font style="color:rgb(28, 30, 33);"> 的进程发送系统信号 </font>`<font style="color:#DF2A3F;">SIGTERM</font>`<font style="color:rgb(28, 30, 33);">，然后等待容器中的应用程序终止执行，如果等待时间达到设定的超时时间，或者默认超时时间（30s），会继续发送 </font>`<font style="color:#DF2A3F;">SIGKILL</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">的系统信号强行 kill 掉进程</font>
+ <font style="color:rgb(28, 30, 33);">使用 Pod 生命周期（利用 </font>`<font style="color:#DF2A3F;">PreStop</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">回调函数），它在发送终止信号之前执行</font>

<font style="color:rgb(28, 30, 33);">默认所有的优雅退出时间都在 30 秒内，</font>`<font style="color:#DF2A3F;">kubectl delete</font>`<font style="color:rgb(28, 30, 33);"> 命令支持 </font>`<font style="color:#DF2A3F;">--grace-period=<seconds></font>`<font style="color:rgb(28, 30, 33);"> 选项，这个选项允许用户用他们自己指定的值覆盖默认值，值</font>`<font style="color:#DF2A3F;">0</font>`<font style="color:rgb(28, 30, 33);">代表强制删除 pod。 在 kubectl 1.5 及以上的版本里，执行强制删除时必须同时指定 </font>`<font style="color:#DF2A3F;">--force --grace-period=0</font>`<font style="color:rgb(28, 30, 33);">。</font>

<font style="color:rgb(28, 30, 33);">强制删除一个 Pod 是从集群中还有 etcd 里立刻删除这个 Pod，只是当 Pod 被强制删除时， APIServer 不会等待来自 Pod 所在节点上的 kubelet 的确认信息：Pod 已经被终止。在 API 里 Pod 会被立刻删除，在节点上， Pods 被设置成立刻终止后，在强行杀掉前还会有一个很小的宽限期。</font>

<font style="color:rgb(28, 30, 33);">以下示例中，定义了一个 Nginx Pod，其中设置了 </font>`<font style="color:#DF2A3F;">PreStop</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">钩子函数，即在容器退出之前，优雅的关闭 Nginx：</font>

```yaml
# pod-prestop.yaml
apiVersion: v1
kind: Pod
metadata:
  name: hook-demo2
spec:
  containers:
    - name: hook-demo2
      image: nginx
      lifecycle:
        preStop:
          exec:
            command: ['/usr/sbin/nginx', '-s', 'quit'] # 优雅退出

---
apiVersion: v1
kind: Pod
metadata:
  name: hook-demo3
spec:
  volumes: # 挂载到宿主机的目录路径
    - name: message
      hostPath:
        path: /tmp
  containers:
    - name: hook-demo2
      image: nginx
      ports:
        - containerPort: 80
      volumeMounts:
        - name: message
          mountPath: /usr/share/
      lifecycle:
        preStop:
          exec:
            command:
              [
                '/bin/sh',
                '-c',
                'echo Hello from the preStop Handler > /usr/share/message',
              ]
```

<font style="color:rgb(28, 30, 33);">上面定义的两个 Pod，一个是利用 </font>`<font style="color:#DF2A3F;">preStop</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">来进行优雅删除，另外一个是利用 </font>`<font style="color:#DF2A3F;">preStop</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">来做一些信息记录的事情，同样直接创建上面的 Pod：</font>

```shell
➜  ~ kubectl apply -f pod-prestop.yaml
pod/hook-demo2 created
pod/hook-demo3 created

➜  ~ kubectl get pods
NAME                            READY   STATUS    RESTARTS   AGE     IP               NODE           NOMINATED NODE   READINESS GATES
hook-demo2                      1/1     Running   0          75s     192.244.211.5    hkk8snode001   <none>           <none>
hook-demo3                      1/1     Running   0          75s     192.244.211.6    hkk8snode002   <none>           <none>
```

<font style="color:rgb(28, 30, 33);">创建完成后，我们可以直接删除 hook-demo2 这个 Pod，在容器删除之前会执行 preStop 里面的优雅关闭命令，这个用法在后面我们的滚动更新的时候用来保证我们的应用零宕机非常有用。第二个 Pod 我们声明了一个 hostPath 类型的 Volume，在容器里面声明挂载到了这个 Volume，所以当我们删除 Pod，退出容器之前，在容器里面输出的信息也会同样的保存到宿主机（一定要是 Pod 被调度到的目标节点）的 </font>`<font style="color:#DF2A3F;">/tmp</font>`<font style="color:rgb(28, 30, 33);"> 目录下面，我们可以查看 hook-demo3 这个 Pod 被调度的节点：</font>

```yaml
➜  ~ kubectl describe pod hook-demo3
Name:             hook-demo3
Namespace:        default
Priority:         0
Service Account:  default
Node:             hkk8snode002/192.168.178.37
[......]
```

<font style="color:rgb(28, 30, 33);">可以看到这个 Pod 被调度到了 </font>`<font style="color:#DF2A3F;">hkk8snode002</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">这个节点上，我们可以先到该节点上查看 </font>`<font style="color:#DF2A3F;">/tmp</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">目录下面目前没有任何内容：</font>

```shell
➜  ~ ls /tmp/
```

<font style="color:rgb(28, 30, 33);">现在我们来删除 hook-demo3 这个 Pod，安装我们的设定在容器退出之前会执行 </font>`<font style="color:#DF2A3F;">preStop</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">里面的命令，也就是会往 message 文件中输出一些信息：</font>

```shell
➜  ~ kubectl delete pod hook-demo3
pod "hook-demo3" deleted

# 进入到对应的主机目录查看文件
➜  ~ ls /tmp/
message
➜  ~ cat /tmp/message
Hello from the preStop Handler
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760362693203-1804eacb-1ad2-4db3-abda-3108bc0547fe.png)

<font style="color:rgb(28, 30, 33);">另外 Hook 调用的日志没有暴露给 Pod，所以只能通过 </font>`<font style="color:#DF2A3F;">describe</font>`<font style="color:rgb(28, 30, 33);"> 命令来获取，如果有错误将可以看到 </font>`<font style="color:#DF2A3F;">FailedPostStartHook</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">或 </font>`<font style="color:#DF2A3F;">FailedPreStopHook</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">这样的 event。</font>

## <font style="color:rgb(28, 30, 33);">5 Pod 健康检查</font>
<font style="color:rgb(28, 30, 33);">现在在 Pod 的整个生命周期中，能影响到 Pod 的就只剩下健康检查这一部分了。在 Kubernetes 集群当中，我们可以通过配置</font>`<font style="color:#DF2A3F;">liveness probe（存活探针</font>`<font style="color:#DF2A3F;">）和 </font>`<font style="color:#DF2A3F;">readiness probe（可读性探针）</font>`<font style="color:rgb(28, 30, 33);"> 来影响容器的生命周期：</font>

+ <font style="color:rgb(28, 30, 33);">kubelet 通过使用 </font>`<u><font style="color:#DF2A3F;">liveness probe</font></u>`<u><font style="color:rgb(28, 30, 33);"> 来确定你的应用程序是否正在运行，通俗点将就是</font></u>**<u><font style="color:#DF2A3F;">是否还活着</font></u>**<font style="color:rgb(28, 30, 33);">。一般来说，如果你的程序一旦崩溃了， Kubernetes 就会立刻知道这个程序已经终止了，然后就会重启这个程序。而我们的 </font>`<u><font style="color:#DF2A3F;">liveness probe</font></u>`<u><font style="color:rgb(28, 30, 33);"> 的目的就是来捕获到当前应用程序还没有终止，还没有崩溃，如果出现了这些情况，那么就重启处于该状态下的容器，使应用程序在存在 Bug 的情况下依然能够继续运行下去。</font></u>
+ <font style="color:rgb(28, 30, 33);">kubelet 使用 </font>`<u><font style="color:#DF2A3F;">readiness probe</font></u>`<u><font style="color:rgb(28, 30, 33);"> 来确定容器是否已经就绪可以接收流量过来了。这个探针通俗点讲就是说</font></u>**<u><font style="color:#DF2A3F;">是否准备好了</font></u>**<font style="color:rgb(28, 30, 33);">，现在可以开始工作了。只有当 Pod 中的容器都处于就绪状态的时候 kubelet 才会认定该 Pod 处于就绪状态，因为一个 Pod 下面可能会有多个容器。</font><u><font style="color:rgb(28, 30, 33);">当然 Pod 如果处于非就绪状态，那么我们就会将他从 Service 的 Endpoints 列表中移除出来，这样我们的流量就不会被路由到这个 Pod 里面来了。</font></u>

<font style="color:rgb(28, 30, 33);">和前面的钩子函数一样的，我们这两个探针的支持下面几种配置方式：</font>

+ `<font style="color:#DF2A3F;">exec</font>`<font style="color:rgb(28, 30, 33);">：执行一段命令</font>
+ `<font style="color:#DF2A3F;">http</font>`<font style="color:rgb(28, 30, 33);">：检测某个 http 请求</font>
+ `<font style="color:#DF2A3F;">tcpSocket</font>`<font style="color:rgb(28, 30, 33);">：使用此配置，kubelet 将尝试在指定端口上打开容器的套接字。如果可以建立连接，容器被认为是健康的，如果不能就认为是失败的。实际上就是检查端口。</font>

### 2.5.1 livenessProbe 和 readinessProbe 小总结
<font style="color:rgb(28, 30, 33);">我们先来给大家演示下存活探针的使用方法，首先我们用 exec 执行命令的方式来检测容器的存活，如下：</font>

```yaml
# liveness-exec.yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-exec
spec:
  containers:
    - name: liveness
      image: busybox
      args:
        - /bin/sh
        - -c
        - touch /tmp/healthy; sleep 30; rm -rf /tmp/healthy; sleep 600
      livenessProbe:
        exec:
          command:
            - cat
            - /tmp/healthy
        initialDelaySeconds: 5
        periodSeconds: 5
```

<font style="color:rgb(28, 30, 33);">我们这里需要用到一个新的属性 </font>`<font style="color:#DF2A3F;">livenessProbe</font>`<font style="color:rgb(28, 30, 33);">，下面通过 exec 执行一段命令:</font>

+ `<font style="color:#DF2A3F;">periodSeconds</font>`<font style="color:rgb(28, 30, 33);">：表示让 kubelet 每隔 5 秒执行一次存活探针，也就是每 5 秒执行一次上面的 </font>`<font style="color:#DF2A3F;">cat /tmp/healthy</font>`<font style="color:rgb(28, 30, 33);"> 命令，如果命令执行成功了，将返回 0，那么 kubelet 就会认为当前这个容器是存活的，如果返回的是非 0 值，那么 kubelet 就会把该容器杀掉然后重启它。默认是 10 秒，最小 1 秒。</font>
+ `<font style="color:#DF2A3F;">initialDelaySeconds</font>`<font style="color:rgb(28, 30, 33);">：表示在第一次执行探针的时候要等待 5 秒，这样能够确保我们的容器能够有足够的时间启动起来。大家可以想象下，如果你的第一次执行探针等候的时间太短，是不是很有可能容器还没正常启动起来，所以存活探针很可能始终都是失败的，这样就会无休止的重启下去了，对吧？</font>

<font style="color:rgb(28, 30, 33);">我们在容器启动的时候，执行了如下命令：</font>

```shell
/bin/sh -c "touch /tmp/healthy; sleep 30; rm -rf /tmp/healthy; sleep 600"
```

<font style="color:rgb(28, 30, 33);">意思是说在容器最开始的 30 秒内创建了一个 </font>`<font style="color:#DF2A3F;">/tmp/healthy</font>`<font style="color:rgb(28, 30, 33);"> 文件，在这 30 秒内执行 </font>`<font style="color:#DF2A3F;">cat /tmp/healthy</font>`<font style="color:rgb(28, 30, 33);"> 命令都会返回一个成功的返回码。30 秒后，我们删除这个文件，现在执行 </font>`<font style="color:#DF2A3F;">cat /tmp/healthy</font>`<font style="color:rgb(28, 30, 33);"> 是不是就会失败了（默认检测失败 3 次才认为失败），所以这个时候就会重启容器了。</font>

<font style="color:rgb(28, 30, 33);">我们来创建下该 Pod，然后在 30 秒内，查看 Pod 的 Event：</font>

```yaml
➜  ~ kubectl apply -f liveness-exec.yaml
➜  ~ kubectl describe pod liveness-exec
Name:             liveness-exec
Namespace:        default
Priority:         0
Service Account:  default
Node:             hkk8snode001/192.168.178.36
[......]
Events:
  Type     Reason     Age               From               Message
  ----     ------     ----              ----               -------
  Normal   Scheduled  68s               default-scheduler  Successfully assigned default/liveness-exec to node1
  Normal   Pulling    68s               kubelet            Pulling image "busybox"
  Normal   Pulled     52s               kubelet            Successfully pulled image "busybox" in 15.352808024s
  Normal   Created    52s               kubelet            Created container liveness
  Normal   Started    52s               kubelet            Started container liveness
  Warning  Unhealthy  8s (x3 over 18s)  kubelet            Liveness probe failed: cat: can't open '/tmp/healthy': No such file or directory
  Normal   Killing    8s                kubelet            Container liveness failed liveness probe, will be restarted
```

<font style="color:rgb(28, 30, 33);">我们可以观察到容器是正常启动的，在隔一会儿，比如 40s 后，再查看下 Pod 的 Event，在最下面有一条信息显示 liveness probe 失败了，容器将要重启。然后可以查看到 Pod 的 </font>`<font style="color:#DF2A3F;">RESTARTS</font>`<font style="color:rgb(28, 30, 33);"> 值加 1 了：</font>

```shell
➜  ~ kubectl get pods liveness-exec
NAME            READY   STATUS    RESTARTS      AGE
liveness-exec   1/1     Running   1 (25s ago)   105s
```

<font style="color:rgb(28, 30, 33);">同样的，我们还可以使用</font>`<font style="color:#DF2A3F;">HTTP GET</font>`<font style="color:rgb(28, 30, 33);">请求来配置我们的存活探针，我们这里使用一个 liveness 镜像来验证演示下：</font>

```yaml
# liveness-http.yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-http
spec:
  containers:
    - name: liveness
      image: cnych/liveness
      args:
        - /server
      livenessProbe:
        httpGet:
          path: /healthz
          port: 8080
          httpHeaders:
            - name: X-Custom-Header
              value: Awesome
        initialDelaySeconds: 3
        periodSeconds: 3
```

<font style="color:rgb(28, 30, 33);">同样的，根据 </font>`<font style="color:#DF2A3F;">periodSeconds</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">属性我们可以知道 kubelet 需要每隔 3 秒执行一次 </font>`<font style="color:#DF2A3F;">liveness Probe</font>`<font style="color:rgb(28, 30, 33);">，该探针将向容器中的 server 的 8080 端口发送一个 HTTP GET 请求。如果 server 的 </font>`<font style="color:#DF2A3F;">/healthz</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">路径的 handler 返回一个成功的返回码，kubelet 就会认定该容器是活着的并且很健康，如果返回失败的返回码，kubelet 将杀掉该容器并重启它。initialDelaySeconds 指定 kubelet 在该执行第一次探测之前需要等待 3 秒钟。</font>

<details class="lake-collapse"><summary id="uf11dd2f8"><span class="ne-text" style="color: var(--ifm-alert-foreground-color)">返回码</span></summary><p id="u6604eb54" class="ne-p"><span class="ne-text" style="color: var(--ifm-alert-foreground-color); text-decoration: underline">通常来说，任何大于</span><code class="ne-code"><span class="ne-text" style="color: #DF2A3F; text-decoration: underline">200</span></code><span class="ne-text" style="color: var(--ifm-alert-foreground-color); text-decoration: underline">小于</span><code class="ne-code"><span class="ne-text" style="color: #DF2A3F; text-decoration: underline">400</span></code><span class="ne-text" style="color: var(--ifm-alert-foreground-color); text-decoration: underline">的状态码都会认定是成功的返回码。其他返回码都会被认为是失败的返回码。</span></p></details>
<font style="color:rgb(28, 30, 33);">我们可以来查看下上面的 healthz 的实现：</font>

```go
http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
    duration := time.Now().Sub(started)
    if duration.Seconds() > 10 {
        w.WriteHeader(500)
        w.Write([]byte(fmt.Sprintf("error: %v", duration.Seconds())))
    } else {
        w.WriteHeader(200)
        w.Write([]byte("ok"))
    }
})
```

<font style="color:rgb(28, 30, 33);">大概意思就是最开始前 10s 返回状态码 200，10s 过后就返回状态码 500。所以当容器启动 3 秒后，kubelet 开始执行健康检查。第一次健康检查会成功，因为是在 10s 之内，但是 10 秒后，健康检查将失败，因为现在返回的是一个错误的状态码了，所以 kubelet 将会杀掉和重启容器。</font>

<font style="color:rgb(28, 30, 33);">同样的，我们来创建下该 Pod 测试下效果，10 秒后，查看 Pod 的 event，确认 liveness probe 失败并重启了容器：</font>

```shell
# 引用资源清单文件
➜  ~ kubectl apply -f liveness-http.yaml
pod/liveness-http created

# 查看
➜  ~ kubectl describe pod liveness-http
Name:             liveness-http
Namespace:        default
Priority:         0
Service Account:  default
Node:             hkk8snode001/192.168.178.36
[......]
Events:
  Type     Reason     Age               From               Message
  ----     ------     ----              ----               -------
  Normal   Scheduled  39s               default-scheduler  Successfully assigned default/liveness-http to hkk8snode001
  Normal   Pulled     25s               kubelet            Successfully pulled image "cnych/liveness" in 14.625425773s (14.625436952s including waiting)
  Normal   Pulling    7s (x2 over 39s)  kubelet            Pulling image "cnych/liveness"
  Warning  Unhealthy  7s (x3 over 13s)  kubelet            Liveness probe failed: HTTP probe failed with statuscode: 500
  Normal   Killing    7s                kubelet            Container liveness failed liveness probe, will be restarted
  Normal   Created    5s (x2 over 25s)  kubelet            Created container liveness
  Normal   Started    5s (x2 over 24s)  kubelet            Started container liveness
  Normal   Pulled     5s                kubelet            Successfully pulled image "cnych/liveness" in 1.627497337s (1.627520678s including waiting)

# 查看 Pod 的状态
➜  ~ kubectl get pods liveness-http
NAME            READY   STATUS    RESTARTS      AGE
liveness-http   1/1     Running   3 (16s ago)   85s
```

<font style="color:rgb(28, 30, 33);">除了上面的 </font>`<font style="color:#DF2A3F;">exec</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">和 </font>`<font style="color:#DF2A3F;">httpGet</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">两种检测方式之外，还可以通过 </font>`<font style="color:#DF2A3F;">tcpSocket</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">方式来检测端口是否正常，大家可以按照上面的方式结合 </font>`<font style="color:#DF2A3F;">kubectl explain</font>`<font style="color:rgb(28, 30, 33);"> 命令自己来验证下这种方式。</font>

---

<font style="color:rgb(28, 30, 33);">另外前面我们提到了探针里面有一个 </font>`<font style="color:#DF2A3F;">initialDelaySeconds</font>`<font style="color:rgb(28, 30, 33);"> 的属性，可以来配置第一次执行探针的等待时间，对于启动非常慢的应用这个参数非常有用，比如 </font>`<font style="color:#DF2A3F;">Jenkins</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:#DF2A3F;">Gitlab</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">这类应用，但是如何设置一个合适的初始延迟时间呢？这个就和应用具体的环境有关系了，所以这个值往往不是通用的，这样的话可能就会导致一个问题，我们的资源清单在别的环境下可能就会健康检查失败了，为解决这个问题，在 Kubernetes v1.16 版本官方特地新增了一个 </font>`<font style="color:#DF2A3F;">startupProbe（启动探针）</font>`<font style="color:rgb(28, 30, 33);">，该探针将推迟所有其他探针，直到 Pod 完成启动为止，使用方法和存活探针一样：</font>

```yaml
startupProbe:
  httpGet:
    path: /healthz
    port: 8080
  failureThreshold: 30 # 尽量设置大点，失败的次数
  periodSeconds: 10 # 间隔 10s 秒钟
```

<font style="color:rgb(28, 30, 33);">比如</font>_<u><font style="color:#DF2A3F;">上面这里的配置表示我们的慢速容器最多可以有 5 分钟（30 个检查 * 10 秒= 300s）来完成启动</font></u>_<font style="color:rgb(28, 30, 33);">。</font>

<font style="color:rgb(28, 30, 33);">有的时候，应用程序可能暂时无法对外提供服务，例如，应用程序可能需要在启动期间加载大量数据或配置文件。在这种情况下，您不想杀死应用程序，也不想对外提供服务。那么这个时候我们就可以使用 </font>`<font style="color:#DF2A3F;">readiness probe</font>`<font style="color:rgb(28, 30, 33);"> 来检测和减轻这些情况，Pod 中的容器可以报告自己还没有准备，不能处理 Kubernetes 服务发送过来的流量。</font>`<font style="color:#DF2A3F;">readiness probe</font>`<font style="color:rgb(28, 30, 33);"> 的配置跟 </font>`<font style="color:#DF2A3F;">liveness probe</font>`<font style="color:rgb(28, 30, 33);"> 基本上一致的，唯一的不同是使用 </font>`<font style="color:#DF2A3F;">readinessProbe</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">而不是 </font>`<font style="color:#DF2A3F;">livenessProbe</font>`<font style="color:rgb(28, 30, 33);">，两者如果同时使用的话就可以确保流量不会到达还未准备好的容器，准备好过后，如果应用程序出现了错误，则会重新启动容器。对于就绪探针我们会在后面 Service 的章节和大家继续介绍。</font>

<font style="color:rgb(28, 30, 33);">另外除了上面的 </font>`<font style="color:#DF2A3F;">initialDelaySeconds</font>`<font style="color:rgb(28, 30, 33);"> 和 </font>`<font style="color:#DF2A3F;">periodSeconds</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">属性外，探针还可以配置如下几个参数：</font>

+ `<font style="color:#DF2A3F;">timeoutSeconds</font>`<font style="color:rgb(28, 30, 33);">：探测超时时间，默认 1 秒，最小 1 秒。</font>
+ `<font style="color:#DF2A3F;">successThreshold</font>`<font style="color:rgb(28, 30, 33);">：探测失败后，最少连续探测成功多少次才被认定为成功，默认是 1，但是如果是 </font>`<font style="color:#DF2A3F;">liveness</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">则必须是 1。最小值是 1。</font>
+ `<font style="color:#DF2A3F;">failureThreshold</font>`<font style="color:rgb(28, 30, 33);">：探测成功后，最少连续探测失败多少次才被认定为失败，默认是 3，最小值是 1。</font>

