<font style="color:rgb(28, 30, 33);">前面我们使用 Prometheus 采集了 Kubernetes 集群中的一些监控数据指标，我们也尝试使用 promQL 语句查询出了一些数据，并且在 Prometheus 的 Dashboard 中进行了展示，但是明显可以感觉到 Prometheus 的图表功能相对较弱，所以一般情况下我们会一个第三方的工具来展示这些数据，今天我们要和大家使用到的就是 </font>[<font style="color:rgb(28, 30, 33);">Grafana</font>](http://grafana.com/)<font style="color:rgb(28, 30, 33);">。</font>

<font style="color:rgb(28, 30, 33);">Grafana 是一个可视化面板，有着非常漂亮的图表和布局展示，功能齐全的度量仪表盘和图形编辑器，支持 Graphite、zabbix、InfluxDB、Prometheus、OpenTSDB、Elasticsearch 等作为数据源，比 Prometheus 自带的图表展示功能强大太多，更加灵活，有丰富的插件，功能更加强大。</font>

## <font style="color:rgb(28, 30, 33);">安装</font>
<font style="color:rgb(28, 30, 33);">同样的我们将 grafana 安装到 Kubernetes 集群中，第一步去查看 grafana 的 docker 镜像的介绍，我们可以在 dockerhub 上去搜索，也可以在官网去查看相关资料，镜像地址如下：</font>[<font style="color:rgb(28, 30, 33);">https://hub.docker.com/r/grafana/grafana/</font>](https://hub.docker.com/r/grafana/grafana/)<font style="color:rgb(28, 30, 33);">，我们可以看到介绍中运行 grafana 容器的命令非常简单：</font>

```shell
$ docker run -d --name=grafana -p 3000:3000 grafana/grafana
```

<font style="color:rgb(28, 30, 33);">但是还有一个需要注意的是 Changelog 中 v5.1.0 版本的更新介绍：</font>

```plain
Major restructuring of the container
Usage of chown removed
File permissions incompatibility with previous versions
user id changed from 104 to 472
group id changed from 107 to 472
Runs as the grafana user by default (instead of root)
All default volumes removed
```

<font style="color:rgb(28, 30, 33);">特别需要注意第 3 条，userid 和 groupid 都有所变化，所以我们在运行的容器的时候需要注意这个变化。现在我们将这个容器转化成 Kubernetes 中的 Pod：</font>

```yaml
# grafana.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-pvc
  namespace: monitor
  labels:
    app: grafana
spec:
  storageClassName: longhorn
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitor
spec:
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      volumes:
        - name: storage
          persistentVolumeClaim:
            claimName: grafana-pvc
      securityContext:
        runAsUser: 0
      containers:
        - name: grafana
          image: grafana/grafana:8.4.6
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 3000
              name: grafana
          env:
            - name: GF_SECURITY_ADMIN_USER
              value: admin
            - name: GF_SECURITY_ADMIN_PASSWORD
              value: admin321
          readinessProbe:
            failureThreshold: 10
            httpGet:
              path: /api/health
              port: 3000
              scheme: HTTP
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 30
          livenessProbe:
            failureThreshold: 3
            httpGet:
              path: /api/health
              port: 3000
              scheme: HTTP
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 1
          resources:
            limits:
              cpu: 150m
              memory: 512Mi
            requests:
              cpu: 150m
              memory: 512Mi
          volumeMounts:
            - mountPath: /var/lib/grafana
              name: storage
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitor
spec:
  type: NodePort
  ports:
    - port: 3000
  selector:
    app: grafana
```

<font style="color:rgb(28, 30, 33);">我们使用了最新的镜像</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">grafana/grafana:8.4.6</font>`<font style="color:rgb(28, 30, 33);">，然后添加了健康检查、资源声明，另外两个比较重要的环境变量</font>`<font style="color:rgb(28, 30, 33);">GF_SECURITY_ADMIN_USER</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">和</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">GF_SECURITY_ADMIN_PASSWORD</font>`<font style="color:rgb(28, 30, 33);">，用来配置 grafana 的管理员用户和密码的，由于 grafana 将 dashboard、插件这些数据保存在</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">/var/lib/grafana</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">这个目录下面的，所以我们这里如果需要做数据持久化的话，就需要针对这个目录进行 volume 挂载声明，由于上面我们刚刚提到的 Changelog 中 grafana 的 userid 和 groupid 有所变化，所以我们这里增加一个</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">securityContext</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">的声明来进行声明使用 root 用户运行。最后，我们需要对外暴露 grafana 这个服务，所以我们需要一个对应的 Service 对象，当然用 NodePort 或者再建立一个 ingress 对象都是可行的。</font>

<font style="color:rgb(28, 30, 33);">现在我们直接创建上面的这些资源对象：</font>

```shell
$ kubectl apply -f grafana.yaml
deployment.apps "grafana" created
service "grafana" created
```

<font style="color:rgb(28, 30, 33);">创建完成后，我们可以查看 grafana 对应的 Pod 是否正常：</font>

```shell
$ kubectl get pods -n kube-mon -l app=grafana
NAME                       READY   STATUS    RESTARTS   AGE
grafana-5579769f64-vfn7q   1/1     Running   0          77s
$ kubectl logs -f grafana-5579769f64-vfn7q -n kube-mon
......
logger=settings var="GF_SECURITY_ADMIN_USER=admin"
t=2019-12-13T06:35:08+0000 lvl=info msg="Config overridden from Environment variable"
......
t=2019-12-13T06:35:08+0000 lvl=info msg="Initializing Stream Manager"
t=2019-12-13T06:35:08+0000 lvl=info msg="HTTP Server Listen" logger=http.server address=[::]:3000 protocol=http subUrl= socket=
```

<font style="color:rgb(28, 30, 33);">看到上面的日志信息就证明我们的 grafana 的 Pod 已经正常启动起来了。这个时候我们可以查看 Service 对象：</font>

```shell
$ kubectl get svc -n kube-mon
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)             AGE
grafana      NodePort    10.104.116.58   <none>        3000:31548/TCP      12m
......
```

<font style="color:rgb(28, 30, 33);">现在我们就可以在浏览器中使用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">http://<任意节点IP:31548></font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">来访问 grafana 这个服务了：</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734343835232-961af7c0-8e25-4e75-a353-f5b4245327e0.png)

<font style="color:rgb(28, 30, 33);">由于上面我们配置了管理员的，所以第一次打开的时候会跳转到登录界面，然后就可以用上面我们配置的两个环境变量的值来进行登录了，登录完成后就可以进入到下面 Grafana 的首页，然后点击</font>`<font style="color:rgb(28, 30, 33);">Add data source</font>`<font style="color:rgb(28, 30, 33);">进入添加数据源界面。</font>

<font style="color:rgb(28, 30, 33);">我们这个地方配置的数据源是</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">Prometheus</font>`<font style="color:rgb(28, 30, 33);">，我们这里 Prometheus 和 Grafana 都处于 kube-mon 这同一个 namespace 下面，所以我们这里的数据源地址：</font>`<font style="color:rgb(28, 30, 33);">http://prometheus:9090</font>`<font style="color:rgb(28, 30, 33);">（因为在同一个 namespace 下面所以直接用 Service 名也可以），然后其他的配置信息就根据实际情况了，比如 Auth 认证，我们这里没有，所以跳过即可，点击最下方的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">Save & Test</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">提示成功证明我们的数据源配置正确：</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734343828297-5e55d7fb-2d80-4515-9238-0f0e9bebf7cf.png)

## <font style="color:rgb(28, 30, 33);">导入 Dashboard</font>
<font style="color:rgb(28, 30, 33);">为了能够快速对系统进行监控，我们可以直接复用别人的 Grafana Dashboard，在 Grafana 的官方网站上就有很多非常优秀的第三方 Dashboard，我们完全可以直接导入进来即可。比如我们想要对所有的集群节点进行监控，也就是 node-exporter 采集的数据进行展示，这里我们就可以导入</font><font style="color:rgb(28, 30, 33);"> </font>[<font style="color:rgb(28, 30, 33);">https://grafana.com/grafana/dashboards/8919</font>](https://grafana.com/grafana/dashboards/8919)<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">这个 Dashboard。</font>

<font style="color:rgb(28, 30, 33);">在侧边栏点击 "+"，选择</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">Import</font>`<font style="color:rgb(28, 30, 33);">，在 Grafana Dashboard 的文本框中输入 8919 即可导入：</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734343829819-058d8db1-542e-4f2b-8232-720d296b81eb.png)

<font style="color:rgb(28, 30, 33);">进入导入 Dashboard 的页面，可以编辑名称，选择 Prometheus 的数据源：</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734343830490-85c18784-7bdc-477a-b9f4-5e0eb63afbd0.png)

<font style="color:rgb(28, 30, 33);">保存后即可进入导入的 Dashboard 页面。由于该 Dashboard 更新比较及时，所以基本上导入进来就可以直接使用了，我们也可以对页面进行一些调整，如果有的图表没有出现对应的图形，则可以编辑根据查询语句去 DEBUG。</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734343828396-c441578a-4c24-432c-a9f9-94390b2f8b8a.png)

## <font style="color:rgb(28, 30, 33);">自定义图表</font>
<font style="color:rgb(28, 30, 33);">导入现成的第三方 Dashboard 或许能解决我们大部分问题，但是毕竟还会有需要定制图表的时候，这个时候就需要了解如何去自定义图表了。</font>

<font style="color:rgb(28, 30, 33);">同样在侧边栏点击 "+"，选择 Dashboard，然后选择</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">Add new panel</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">创建一个图表：</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734343829668-470239a1-f8a3-4847-9bf0-7dc9847a29fa.png)

<font style="color:rgb(28, 30, 33);">然后在下方 Query 栏中选择</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">Prometheus</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">这个数据源：</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734343830490-ec4d3981-9a53-4c68-b56d-a42f60f6a182.png)

<font style="color:rgb(28, 30, 33);">然后在</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">Metrics</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">区域输入我们要查询的监控 PromQL 语句，比如我们这里想要查询集群节点 CPU 的使用率：</font>

```plain
(1 - sum(increase(node_cpu_seconds_total{mode="idle", instance=~"$node"}[1m])) by (instance) / sum(increase(node_cpu_seconds_total{instance=~"$node"}[1m])) by (instance)) * 100
```

<font style="color:rgb(28, 30, 33);">虽然我们现在还没有具体的学习过 PromQL 语句，但其实我们仔细分析上面的语句也不是很困难，集群节点的 CPU 使用率实际上就相当于排除空闲 CPU 的使用率，所以我们可以优先计算空闲 CPU 的使用时长，除以总的 CPU 时长就是使用率了，用 1 减掉过后就是 CPU 的使用率了，如果想用百分比来表示的话则乘以 100 即可。</font>

<font style="color:rgb(28, 30, 33);">这里有一个需要注意的地方是在 PromQL 语句中有一个</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">instance=~"$node"</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">的标签，其实意思就是根据</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">$node</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">这个参数来进行过滤，也就是我们希望在 Grafana 里面通过参数化来控制每一次计算哪一个节点的 CPU 使用率。</font>

<font style="color:rgb(28, 30, 33);">所以这里就涉及到 Grafana 里面的参数使用。点击页面顶部的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">Dashboard Settings</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">按钮进入配置页面：</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734343831921-421a42a2-56b5-46ac-bfd0-e69e26e7bc9b.png)

<font style="color:rgb(28, 30, 33);">在左侧 tab 栏点击</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">Variables</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">进入参数配置页面，如果还没有任何参数，可以通过点击</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">Add Variable</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">添加一个新的变量：</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734343830671-5c1e6314-987a-47a5-ae8c-520f02e47e4f.png)

<font style="color:rgb(28, 30, 33);">这里需要注意的是变量的名称</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">node</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">就是上面我们在 PromQL 语句里面使用的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">$node</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">这个参数，这两个地方必须保持一致，然后最重要的就是参数的获取方式了，比如我们可以通过</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">Prometheus</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">这个数据源，通过</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">kubelet_node_name</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">这个指标来获取，在 Prometheus 里面我们可以查询该指标获取到的值为：</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734343833807-e1566b7c-e7a3-4a7f-9f6c-912ebd10cead.png)

<font style="color:rgb(28, 30, 33);">我们其实只是想要获取节点的名称，所以我们可以用正则表达式去匹配</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">node=xxx</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">这个标签，将匹配的值作为参数的值即可:</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734343831647-9780928f-2fb8-4753-89cd-b05bcd308666.png)

<font style="color:rgb(28, 30, 33);">在最下面的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">Preview of values</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">里面会有获取的参数值的预览结果。除此之外，我们还可以使用一个更方便的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">label_values</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">函数来获取，该函数可以用来直接获取某个指标的 label 值：</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734343838477-afc64fbe-6c61-4c23-b927-58851978244c.png)

<font style="color:rgb(28, 30, 33);">另外由于我们希望能够让用户自由选择一次性可以查询多少个节点的数据，所以我们将</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">Multi-value</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">以及</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">Include All option</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">都勾选上了，最后记得保存，保存后跳转到 Dashboard 页面就可以看到我们自定义的图表信息：</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734343834663-6db28af2-69d2-4286-a048-3fa171fd395c.png)

<font style="color:rgb(28, 30, 33);">而且还可以根据参数选择一个或者多个节点，当然图表的标题和大小都可以自由去更改：</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734343833313-70107a40-2f7e-42ab-aac8-3270564c46cb.png)

