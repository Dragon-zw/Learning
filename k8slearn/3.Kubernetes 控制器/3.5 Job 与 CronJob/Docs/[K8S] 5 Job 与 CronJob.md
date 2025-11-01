接下来给大家介绍另外一类资源对象：`<font style="color:#DF2A3F;">Job</font>`，我们在日常的工作中经常都会遇到一些需要进行批量数据处理和分析的需求，当然也会有按时间来进行调度的工作，在我们的 Kubernetes 集群中为我们提供了 `<font style="color:#DF2A3F;">Job</font>`<font style="color:#DF2A3F;"> </font>和 `<font style="color:#DF2A3F;">CronJob</font>`<font style="color:#DF2A3F;"> </font>两种资源对象来应对我们的这种需求。

`<font style="color:#DF2A3F;">Job</font>`<font style="color:#DF2A3F;"> </font>负责处理任务，即仅执行一次的任务，它保证批处理任务的一个或多个 Pod 成功结束。而`<font style="color:#DF2A3F;">CronJob</font>`<font style="color:#DF2A3F;"> </font>则就是在 `<font style="color:#DF2A3F;">Job</font>`<font style="color:#DF2A3F;"> </font>上加上了时间调度。

## 1 Job
我们用 `<font style="color:#DF2A3F;">Job</font>`<font style="color:#DF2A3F;"> </font>这个资源对象来创建一个任务，我们定义一个 `<font style="color:#DF2A3F;">Job</font>`<font style="color:#DF2A3F;"> </font>来执行一个倒计时的任务，对应的资源清单如下所示：

```yaml
# job-demo.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: job-demo
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: counter
        image: busybox
        command:
        - "bin/sh"
        - "-c"
        - "for i in 9 8 7 6 5 4 3 2 1; do echo $i; done"
```

我们可以看到 `<font style="color:#DF2A3F;">Job</font>`<font style="color:#DF2A3F;"> </font>中也是一个 Pod 模板，和之前的 Deployment、StatefulSet 之类的是一致的，只是 Pod 中的容器要求是一个任务，而不是一个常驻前台的进程了，因为需要退出，另外值得注意的是 `<font style="color:#DF2A3F;">Job</font>`<font style="color:#DF2A3F;"> </font>的 `<font style="color:#DF2A3F;">RestartPolicy</font>`<font style="color:#DF2A3F;"> </font>仅支持 `<font style="color:#DF2A3F;">Never</font>`<font style="color:#DF2A3F;"> </font>和 `<font style="color:#DF2A3F;">OnFailure</font>`<font style="color:#DF2A3F;"> </font>两种，不支持 `<font style="color:#DF2A3F;">Always</font>`，我们知道 `<font style="color:#DF2A3F;">Job</font>`<font style="color:#DF2A3F;"> </font>就相当于来执行一个批处理任务，执行完就结束了，如果支持 `<font style="color:#DF2A3F;">Always</font>`<font style="color:#DF2A3F;"> </font>的话是不是就陷入了死循环了？

直接创建这个 Job 对象：

```shell
➜  ~ kubectl apply -f job-demo.yaml
job.batch/job-demo created

➜  ~ kubectl get job
NAME       COMPLETIONS   DURATION   AGE
job-demo   1/1           6s         10s

➜  ~ kubectl get pods
NAME             READY   STATUS      RESTARTS   AGE
job-demo-fhjtd   0/1     Completed   0          25s
```

`<font style="color:#DF2A3F;">Job</font>`<font style="color:#DF2A3F;"> </font>对象创建成功后，我们可以查看下对象的详细描述信息：

```shell
➜  ~ kubectl describe job job-demo
Name:             job-demo
Namespace:        default
Selector:         batch.kubernetes.io/controller-uid=804a6f54-7649-4030-bf18-389a619ffc58
Labels:           batch.kubernetes.io/controller-uid=804a6f54-7649-4030-bf18-389a619ffc58
                  batch.kubernetes.io/job-name=job-demo
                  controller-uid=804a6f54-7649-4030-bf18-389a619ffc58
                  job-name=job-demo
Annotations:      batch.kubernetes.io/job-tracking: 
Parallelism:      1
Completions:      1
Completion Mode:  NonIndexed
Start Time:       Tue, 14 Oct 2025 11:23:39 +0800
Completed At:     Tue, 14 Oct 2025 11:23:45 +0800
Duration:         6s
Pods Statuses:    0 Active (0 Ready) / 1 Succeeded / 0 Failed
Pod Template:
  Labels:  batch.kubernetes.io/controller-uid=804a6f54-7649-4030-bf18-389a619ffc58
           batch.kubernetes.io/job-name=job-demo
           controller-uid=804a6f54-7649-4030-bf18-389a619ffc58
           job-name=job-demo
  Containers:
   counter:
    Image:      busybox
    Port:       <none>
    Host Port:  <none>
    Command:
      bin/sh
      -c
      for i in 9 8 7 6 5 4 3 2 1; do echo $i; done
    Environment:  <none>
    Mounts:       <none>
  Volumes:        <none>
Events:
  Type    Reason            Age   From            Message
  ----    ------            ----  ----            -------
  Normal  SuccessfulCreate  35s   job-controller  Created pod: job-demo-fhjtd
  Normal  Completed         29s   job-controller  Job completed
```

可以看到，Job 对象在创建后，它的 Pod 模板，被自动加上了一个 `<font style="color:#DF2A3F;">controller-uid=< 一个随机字符串 ></font>` 这样的 Label 标签，而这个 Job 对象本身，则被自动加上了这个 Label 对应的 Selector，从而 保证了 Job 与它所管理的 Pod 之间的匹配关系。而 Job 控制器之所以要使用这种携带了 UID 的 Label，就是为了避免不同 Job 对象所管理的 Pod 发生重合。

我们可以看到很快 Pod 变成了 `<font style="color:#DF2A3F;">Completed</font>`<font style="color:#DF2A3F;"> </font>状态，这是因为容器的任务执行完成正常退出了，我们可以查看对应的日志：

```shell
# 查看 Job 的日志信息
➜  ~ kubectl logs job-demo-fhjtd
9
8
7
6
5
4
3
2
1

➜  ~ kubectl get pod
NAME             READY   STATUS      RESTARTS   AGE
job-demo-fhjtd   0/1     Completed   0          65s
```

上面我们这里的 Job 任务对应的 Pod 在运行结束后，会变成 `<font style="color:#DF2A3F;">Completed</font>`<font style="color:#DF2A3F;"> </font>状态，但是如果执行任务的 Pod 因为某种原因一直没有结束怎么办呢？同样我们可以在 Job 对象中通过设置字段 `<font style="color:#DF2A3F;">spec.activeDeadlineSeconds</font>` 来限制任务运行的最长时间，比如：

```yaml
spec:
  activeDeadlineSeconds: 100
```

那么当我们的任务 Pod 运行超过了 100s 后，这个 Job 的所有 Pod 都会被终止，并且， Pod 的终止原因会变成 `<font style="color:#DF2A3F;">DeadlineExceeded</font>`。

如果的任务执行失败了，会怎么处理呢，这个和定义的 `<font style="color:#DF2A3F;">restartPolicy</font>`<font style="color:#DF2A3F;"> </font>有关系，比如定义如下所示的 Job 任务，定义 `<font style="color:#DF2A3F;">restartPolicy: Never</font>` 的重启策略：

```yaml
# job-failed-demo.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: job-failed-demo
spec:
  template:
    spec:
      containers:
      - name: test-job
        image: busybox
        command: ["echo123", "test failed job!"] # 执行错误的命令
      restartPolicy: Never
```

直接创建上面的资源对象：

```shell
➜  ~ kubectl apply -f job-failed-demo.yaml
job.batch/job-failed-demo created

➜  ~ kubectl get job job-failed-demo -o yaml 
apiVersion: batch/v1
kind: Job
metadata:
  [......]
  name: job-failed-demo
  namespace: default
spec:
  backoffLimit: 6 # 重建 Pod 的次数
  completionMode: NonIndexed
  completions: 1
  parallelism: 1

➜  ~ kubectl get pod -l job-name=job-failed-demo
NAME                    READY   STATUS       RESTARTS   AGE
job-failed-demo-4m4xn   0/1     StartError   0          8m52s
job-failed-demo-klprb   0/1     StartError   0          9m5s
job-failed-demo-mwvz9   0/1     StartError   0          8m30s
job-failed-demo-nvx2p   0/1     StartError   0          3m44s
job-failed-demo-q9v82   0/1     StartError   0          2m13s
job-failed-demo-xtfh2   0/1     StartError   0          6m26s
job-failed-demo-zrmvt   0/1     StartError   0          7m48s
```

可以看到当我们设置成 `<font style="color:#DF2A3F;">Never</font>`<font style="color:#DF2A3F;"> </font>重启策略的时候，Job 任务执行失败后会不断创建新的 Pod，但是不会一直创建下去，会<u>根据 </u>`<u><font style="color:#DF2A3F;">spec.backoffLimit</font></u>`<u> 参数进行限制，默认为 </u>`<u><font style="color:#DF2A3F;">6</font></u>`<u>，通过该字段可以定义重建 Pod 的次数</u>，另外需要注意的是 Job 控制器重新创建 Pod 的间隔是呈指数增加的，即下一次重新创建 Pod 的动作会分别发生在 10s、20s、40s… 后。

但是如果我们设置的 `<font style="color:#DF2A3F;">restartPolicy: OnFailure</font>` 重启策略，则当 Job 任务执行失败后不会创建新的 Pod 出来，只会不断重启 Pod。

除此之外，我们还可以通过设置 `<font style="color:#DF2A3F;">spec.parallelism</font>` 参数来进行并行控制，该参数定义了一个 Job 在任意时间最多可以有多少个 Pod 同时运行。`<font style="color:#DF2A3F;">spec.completions</font>` 参数可以定义 Job 至少要完成的 Pod 数目。如下所示创建一个新的 Job 任务，设置允许并行数为 2，至少要完成的 Pod 数为 8：

```yaml
# job-para-demo.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: job-para-test
spec:
  parallelism: 2 # 并行数
  completions: 8 # 至少要完成的 Pod 数
  template:
    spec:
      containers:
      - name: test-job
        image: busybox
        command: ["echo", "test paralle job!"]
      restartPolicy: Never
```

创建完成后查看任务状态：

```shell
➜  ~ kubectl apply -f job-para-demo.yaml
job.batch/job-para-test created

➜  ~ kubectl get pod -l job-name=job-para-test
NAME                  READY   STATUS      RESTARTS   AGE
job-para-test-rj9zf   0/1     Completed   0          25s
job-para-test-xpctm   0/1     Completed   0          25s

➜  ~ kubectl get job
NAME            COMPLETIONS   DURATION   AGE
job-para-test   0/8           30s        30s

➜  ~ kubectl get job
NAME            COMPLETIONS   DURATION   AGE
job-para-test   8/8           120s       2m35s

➜  ~ kubectl get pod -l job-name=job-para-test
NAME                  READY   STATUS      RESTARTS   AGE
job-para-test-48hqh   0/1     Completed   0          85s
job-para-test-5vhln   0/1     Completed   0          79s
job-para-test-fmmb4   0/1     Completed   0          78s
job-para-test-rgtvx   0/1     Completed   0          73s
job-para-test-rj9zf   0/1     Completed   0          90s
job-para-test-xcspv   0/1     Completed   0          72s
job-para-test-xpctm   0/1     Completed   0          90s
job-para-test-xrpq4   0/1     Completed   0          83s
```

可以看到一次可以有 2 个 Pod 同时运行，需要 8 个 Pod 执行成功，如果不是8个成功，那么会根据 `<font style="color:#DF2A3F;">restartPolicy</font>`<font style="color:#DF2A3F;"> </font>的策略进行处理，可以认为是一种检查机制。

## 2 CronJob
`<font style="color:#DF2A3F;">CronJob</font>`<font style="color:#DF2A3F;"> </font>其实就是在 `<font style="color:#DF2A3F;">Job</font>`<font style="color:#DF2A3F;"> </font>的基础上加上了时间调度，我们可以在给定的时间点运行一个任务，也可以周期性地在给定时间点运行。这个实际上和我们 Linux 中的 `<font style="color:#DF2A3F;">crontab</font>`<font style="color:#DF2A3F;"> </font>就非常类似了。

一个 `<font style="color:#DF2A3F;">CronJob</font>`<font style="color:#DF2A3F;"> </font>对象其实就对应中 `<font style="color:#DF2A3F;">crontab</font>`<font style="color:#DF2A3F;"> </font>文件中的一行，它根据配置的时间格式周期性地运行一个 `<font style="color:#DF2A3F;">Job</font>`，格式和 `<font style="color:#DF2A3F;">crontab</font>`<font style="color:#DF2A3F;"> </font>也是一样的。

crontab 的格式为：`<font style="color:#DF2A3F;">分 时 日 月 星期 要运行的命令</font>` 。

+ 第 1 列分钟 0～59
+ 第 2 列小时 0～23
+ 第 3 列日 1～31
+ 第 4 列月 1～12
+ 第 5 列星期 0～7（0和7表示星期天）
+ 第 6 列要运行的命令

现在，我们用 `<font style="color:#DF2A3F;">CronJob</font>`<font style="color:#DF2A3F;"> </font>来管理我们上面的 `<font style="color:#DF2A3F;">Job</font>`<font style="color:#DF2A3F;"> </font>任务，定义如下所示的资源清单：

```yaml
# cronjob-demo.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cronjob-demo
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: hello
            image: busybox
            args:
            - "bin/sh"
            - "-c"
            - "for i in 9 8 7 6 5 4 3 2 1; do echo $i; done"
```

这里的 Kind 变成了 `<font style="color:#DF2A3F;">CronJob</font>`<font style="color:#DF2A3F;"> </font>了，要注意的是 `<font style="color:#DF2A3F;">.spec.schedule</font>` 字段是必须填写的，用来指定任务运行的周期，格式就和 `<font style="color:#DF2A3F;">crontab</font>`<font style="color:#DF2A3F;"> </font>一样，另外一个字段是 `<font style="color:#DF2A3F;">.spec.jobTemplate</font>`, 用来指定需要运行的任务，格式当然和 `<font style="color:#DF2A3F;">Job</font>`<font style="color:#DF2A3F;"> </font>是一致的。还有一些值得我们关注的字段 `<font style="color:#DF2A3F;">.spec.successfulJobsHistoryLimit</font>`<font style="color:#DF2A3F;">(默认为3) 和 </font>`<font style="color:#DF2A3F;">.spec.failedJobsHistoryLimit</font>`(默认为1)，表示历史限制，是可选的字段，指定可以保留多少完成和失败的 `Job`。然而，当运行一个 `<font style="color:#DF2A3F;">CronJob</font>`<font style="color:#DF2A3F;"> </font>时，`<font style="color:#DF2A3F;">Job</font>`<font style="color:#DF2A3F;"> </font>可以很快就堆积很多，所以一般推荐设置这两个字段的值，如果设置限制的值为 0，那么相关类型的 `<font style="color:#DF2A3F;">Job</font>`<font style="color:#DF2A3F;"> </font>完成后将不会被保留。

我们直接新建上面的资源对象：

```shell
➜  ~ kubectl apply -f cronjob-demo.yaml
cronjob "cronjob-demo" created
```

然后可以查看对应的 Cronjob 资源对象：

```shell
➜  ~ kubectl get cronjob
NAME           SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
cronjob-demo   */1 * * * *   False     0        9s              20s
```

稍微等一会儿查看可以发现多了几个 Job 资源对象，这个就是因为上面我们设置的 CronJob 资源对象，每 1 分钟执行一个新的 Job：

```shell
# Sleep 60s
➜  ~ kubectl get job
NAME                    COMPLETIONS   DURATION   AGE
cronjob-demo-29340218   1/1           5s         80s
cronjob-demo-29340219   1/1           5s         20s

# Sleep 60s
➜  ~ kubectl get pods
NAME                          READY   STATUS       RESTARTS   AGE
cronjob-demo-29340218-xgmdj   0/1     Completed    0          2m5s
cronjob-demo-29340219-wzgv4   0/1     Completed    0          65s
cronjob-demo-29340220-ggxmv   0/1     Completed    0          5s
```

这个就是 CronJob 的基本用法，一旦不再需要 CronJob，我们可以使用 `<font style="color:#DF2A3F;">kubectl</font>` 命令删除它：

```shell
➜  ~ kubectl delete cronjob cronjob-demo
cronjob "cronjob-demo" deleted
```

<font style="color:#DF2A3F;">不过需要注意的是这将会终止正在创建的 Job，但是运行中的 Job 将不会被终止，不会删除 Job 或 它们的 Pod。</font>

:::success
💎Job

:::

<font style="color:rgb(0, 0, 0);">一次性任务，运行完成后Pod销毁，不再重新启动新容器。</font>

Kubernetes中的 Job 对象将创建一个或多个 Pod，并确保指定数量的 Pod 可以成功执行到进程正常结束：

+ 当 Job 创建的 Pod 执行成功并正常结束时，Job 将记录成功结束的 Pod 数量
+ 当成功结束的 Pod 达到指定的数量时，Job 将完成执行
+ 删除 Job 对象时，将清理掉由 Job 创建的 Pod

:::success
 💎CronJob

:::

CronJob 创建 Job →  Job 启动 Pod 执行命令[ <font style="color:rgb(0, 0, 0);">CronJob 是在 Job 基础上加上了定时功能。</font> ]

> Reference：[https://crontab.guru/](https://crontab.guru/)
>

<font style="color:#DF2A3F;">CronJob 按照预定的时间计划（schedule）创建 Job（注意：启动的是Job不是Deployment，RS）</font>。一个 CronJob 对象类似于 crontab (cron table) 文件中的一行记录。该对象根据 [Cron](https://en.wikipedia.org/wiki/Cron) 格式定义的时间计划，周期性地创建 Job 对象。

:::color2
Scheduler 所有 CronJob 的 `<font style="color:#DF2A3F;">schedule</font>` 中所定义的时间，都是基于 Master 所在时区来进行计算的。

:::

一个 CronJob 在时间计划中的每次执行时刻，都创建 **大约** 一个 Job 对象。这里用到了 **大约** ，是因为在少数情况下会创建两个 Job 对象，或者不创建 Job 对象。尽管 K8S 尽最大的可能性避免这种情况的出现，但是并不能完全杜绝此现象的发生。因此，Job 程序必须是 [幂等的](https://www.kuboard.cn/glossary/idempotent.html)。[ <font style="color:#E8323C;">幂等：就是针对一个操作，不管做多少次，产生效果或返回的结果都是一样的</font> ]

当以下两个条件都满足时，Job 将至少运行一次：

+ `**<font style="color:#E8323C;">startingDeadlineSeconds</font>**`**<font style="color:#E8323C;"> </font>**启动的超时时间被设置为一个较大的值，或者不设置该值（默认值将被采纳）[ 启动的最后期限 ]
+ `**<font style="color:#E8323C;">concurrencyPolicy</font>**`**<font style="color:#E8323C;"> </font>**并发策略被设置为 `**<font style="color:#E8323C;">Allow</font>**`

```bash
# ┌───────────── 分钟 (0 - 59)
# │ ┌───────────── 小时 (0 - 23)
# │ │ ┌───────────── 月的某天 (1 - 31)
# │ │ │ ┌───────────── 月份 (1 - 12)
# │ │ │ │ ┌───────────── 周的某天 (0 - 6)（周日到周一；在某些系统上，7 也是星期日）
# │ │ │ │ │                          或者是 sun，mon，tue，web，thu，fri，sat
# │ │ │ │ │
# │ │ │ │ │
# * * * * *
```

## 3 思考
思考：那如果我们想要在每个节点上去执行一个 Job 或者 Cronjob 又该怎么来实现呢？

| **<font style="color:rgb(0, 0, 0);">方案</font>** | **<font style="color:rgb(0, 0, 0);">适用场景</font>** | **<font style="color:rgb(0, 0, 0);">优点</font>** | **<font style="color:rgb(0, 0, 0);">缺点</font>** |
| :--- | :--- | :--- | :--- |
| <font style="color:rgb(0, 0, 0);">DaemonSet</font> | <font style="color:rgb(0, 0, 0);">长期守护进程（如日志收集）</font> | <font style="color:rgb(0, 0, 0);">自动覆盖节点，Pod 与节点绑定</font> | <font style="color:rgb(0, 0, 0);">任务完成后 Pod 仍需运行，资源占用较高</font> |
| <font style="color:rgb(0, 0, 0);">Job + 节点选择</font> | <font style="color:rgb(0, 0, 0);">一次性全局任务</font> | <font style="color:rgb(0, 0, 0);">灵活控制任务执行节点</font> | <font style="color:rgb(0, 0, 0);">需手动管理节点标签，大规模集群配置复杂</font> |
| <font style="color:rgb(0, 0, 0);">CronJob</font> | <font style="color:rgb(0, 0, 0);">定时全局任务</font> | <font style="color:rgb(0, 0, 0);">定时执行，支持历史记录管理</font> | <font style="color:rgb(0, 0, 0);">需处理任务重叠问题，依赖节点标签一致性</font> |


<u><font style="color:rgb(0, 0, 0);">可以使用 OpenKruise 定义的资源对象来实现。例如：BroadcastJob、AdvancedCronJob 资源对象。</font></u>

