<font style="color:rgb(28, 30, 33);">上面我们讲解了 Service 的用法，我们可以通过 Service 生成的 ClusterIP(VIP) 来访问 Pod 提供的服务，但是在使用的时候还有一个问题：我们怎么知道某个应用的 VIP 呢？比如我们有两个应用，一个是 api 应用，一个是 db 应用，两个应用都是通过 Deployment 进行管理的，并且都通过 Service 暴露出了端口提供服务。api 需要连接到 db 这个应用，我们只知道 db 应用的名称和 db 对应的 Service 的名称，但是并不知道它的 VIP 地址，我们前面的 Service 课程中是不是学习到我们通过 ClusterIP 就可以访问到后面的 Pod 服务，如果我们知道了 VIP 的地址是不是就行了？</font>

## <font style="color:rgb(28, 30, 33);">1 环境变量</font>
<font style="color:rgb(28, 30, 33);">为了解决上面的问题，在之前的版本中，Kubernetes 采用了环境变量的方法，每个 Pod 启动的时候，会通过环境变量设置所有服务的 IP 和 Port 信息，这样 Pod 中的应用可以通过读取环境变量来获取依赖服务的地址信息，这种方法使用起来相对简单，但是有一个很大的问题就是依赖的服务必须在 Pod 启动之前就存在，不然是不会被注入到环境变量中的。比如我们首先创建一个 Nginx 服务：(</font>`<font style="color:#DF2A3F;">test-nginx.yaml</font>`<font style="color:rgb(28, 30, 33);">)</font>

```yaml
# test-nginx.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deploy
spec:
  replicas: 2
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
          image: nginx:1.7.9
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  labels:
    name: nginx-service
spec:
  ports:
    - port: 5000
      targetPort: 80
  selector:
    app: nginx
```

<font style="color:rgb(28, 30, 33);">创建上面的服务：</font>

```shell
➜  ~ kubectl apply -f test-nginx.yaml
deployment.apps "nginx-deploy" created
service "nginx-service" created

➜  ~ kubectl get pods -l app=nginx -o wide 
NAME                            READY   STATUS    RESTARTS   AGE   IP               NODE           NOMINATED NODE   READINESS GATES
nginx-deploy-57b754799f-prbz9   1/1     Running   0          20s   192.244.51.229   hkk8snode002   <none>           <none>
nginx-deploy-57b754799f-w6lkp   1/1     Running   0          20s   192.244.211.40   hkk8snode001   <none>           <none>

➜  ~ kubectl get svc nginx-service
NAME            TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
nginx-service   ClusterIP   192.96.249.206   <none>        5000/TCP   30s
```

<font style="color:rgb(28, 30, 33);">我们可以看到两个 Pod 和一个名为 nginx-service 的服务创建成功了，该 Service 监听的端口是 5000，同时它会把流量转发给它代理的所有 Pod（我们这里就是拥有 </font>`<font style="color:#DF2A3F;">app: nginx</font>`<font style="color:rgb(28, 30, 33);"> 标签的两个 Pod）。</font>

<font style="color:rgb(28, 30, 33);">现在我们再来创建一个普通的 Pod，观察下该 Pod 中的环境变量是否包含上面的 </font>`<font style="color:#DF2A3F;">nginx-service</font>`<font style="color:rgb(28, 30, 33);"> 的服务信息：（</font>`<font style="color:#DF2A3F;">test-pod.yaml</font>`<font style="color:rgb(28, 30, 33);">）</font>

```yaml
# test-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
    - name: test-service-pod
      image: busybox
      command: ['/bin/sh', '-c', 'env']
```

<font style="color:rgb(28, 30, 33);">然后创建该测试的 Pod：</font>

```shell
➜  ~ kubectl create -f test-pod.yaml
pod "test-pod" created
```

<font style="color:rgb(28, 30, 33);">等 Pod 创建完成后，我们查看日志信息：</font>

```shell
➜  ~ kubectl logs test-pod
KUBERNETES_SERVICE_PORT=443
KUBERNETES_PORT=tcp://192.96.0.1:443
HOSTNAME=test-pod
OPA_PORT_8443_TCP=tcp://192.96.161.3:8443
SHLVL=1
HOME=/root
NGINX_SERVICE_PORT_5000_TCP_ADDR=192.96.249.206
NGINX_SERVICE_PORT_5000_TCP_PORT=5000
NGINX_SERVICE_PORT_5000_TCP_PROTO=tcp
KUBERNETES_PORT_443_TCP_ADDR=192.96.0.1
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
NGINX_SERVICE_SERVICE_HOST=192.96.249.206
NGINX_SERVICE_PORT_5000_TCP=tcp://192.96.249.206:5000
KUBERNETES_PORT_443_TCP_PORT=443
KUBERNETES_PORT_443_TCP_PROTO=tcp
OPA_SERVICE_PORT_HTTPS=8443
NGINX_SERVICE_PORT=tcp://192.96.249.206:5000
NGINX_SERVICE_SERVICE_PORT=5000
OPA_SERVICE_HOST=192.96.161.3
KUBERNETES_SERVICE_PORT_HTTPS=443
KUBERNETES_PORT_443_TCP=tcp://192.96.0.1:443
OPA_PORT_8443_TCP_ADDR=192.96.161.3
KUBERNETES_SERVICE_HOST=192.96.0.1
PWD=/
OPA_PORT_8443_TCP_PORT=8443
OPA_PORT_8443_TCP_PROTO=tcp
OPA_PORT=tcp://192.96.161.3:8443
OPA_SERVICE_PORT=8443
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760608819930-eb664db2-f584-43c4-bb6b-b429e00f7dcf.png)

:::success
⚠️<font style="color:rgb(28, 30, 33);">Tips：</font>

<font style="color:rgb(28, 30, 33);">Pod 启动之后，会将当前 Kubernetes 系统当中的所处的 NameSpace 的 Service 以环境变量的形式注入到 Pod 当中。</font>

<font style="color:rgb(28, 30, 33);">但是后面创建的 Service，并不会注入到之前创建的 Pod 的环境变量当中。</font>

:::

<font style="color:rgb(28, 30, 33);">我们可以看到打印了很多环境变量信息，其中就包括我们刚刚创建的 nginx-service 这个服务，有 HOST、PORT、PROTO、ADDR 等，也包括其他已经存在的 Service 的环境变量，现在如果我们需要在这个 Pod 里面访问 nginx-service 的服务，我们是不是可以直接通过 </font>`<font style="color:#DF2A3F;">NGINX_SERVICE_SERVICE_HOST</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">和 </font>`<font style="color:#DF2A3F;">NGINX_SERVICE_SERVICE_PORT</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">就可以了，但是如果这个 Pod 启动起来的时候 nginx-service 服务还没启动起来，在环境变量中我们是无法获取到这些信息的，当然我们可以通过 </font>`<font style="color:#DF2A3F;">initContainer</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">之类的方法来确保 nginx-service 启动后再启动 Pod，但是这种方法毕竟增加了 Pod 启动的复杂性，所以这不是最优的方法，局限性太多了。</font>

### <font style="color:rgb(28, 30, 33);">1.1 DNS</font>
<font style="color:rgb(28, 30, 33);">由于上面环境变量这种方式的局限性，我们需要一种更加智能的方案，其实我们可以自己思考一种比较理想的方案：那就是可以直接使用 Service 的名称，因为 Service 的名称不会变化，我们不需要去关心分配的 ClusterIP 的地址，因为这个地址并不是固定不变的，所以如果我们直接使用 Service 的名字，然后对应的 ClusterIP 地址的转换能够自动完成就很好了。我们知道名字和 IP 直接的转换是不是和我们平时访问的网站非常类似啊？他们之间的转换功能通过 DNS 就可以解决了，同样的，Kubernetes 也提供了 DNS 的方案来解决上面的服务发现的问题。</font>

<font style="color:rgb(28, 30, 33);">DNS 服务不是一个独立的系统服务，而是作为一种 addon 插件而存在，现在比较推荐的两个插件：kube-dns 和 CoreDNS，实际上在比较新点的版本中已经默认是 CoreDNS 了，因为 kube-dns 默认一个 Pod 中需要 3 个容器配合使用，CoreDNS 只需要一个容器即可，我们在前面使用 kubeadm 搭建集群的时候直接安装的就是 CoreDNS 插件：</font>

```shell
➜  ~ kubectl get pods -n kube-system -l k8s-app=kube-dns
NAME                       READY   STATUS    RESTARTS       AGE
coredns-5d78c9869d-nlm86   1/1     Running   1 (3d1h ago)   3d1h
coredns-5d78c9869d-qtqxj   1/1     Running   1 (3d1h ago)   3d1h
```

<font style="color:#DF2A3F;">CoreDns 是用 GO 写的高性能，高扩展性的 DNS 服务，基于 HTTP/2 Web 服务 Caddy 进行编写的。</font><u><font style="color:rgb(28, 30, 33);">CoreDns 内部采用插件机制，所有功能都是插件形式编写，用户也可以扩展自己的插件，以下是 Kubernetes 部署 CoreDns 时的默认配置：</font></u>

```yaml
➜  ~ kubectl get cm coredns -n kube-system -o yaml
apiVersion: v1
data:
  Corefile: |
    .:53 {
        errors  # 启用错误记录
        health  # 启用健康检查检查端点，8080:health
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {  # 处理 k8s 域名解析
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153  # 启用 metrics 指标，9153:metrics
        forward . /etc/resolv.conf  # 通过 resolv.conf 内的 nameservers 解析
        cache 30  # 启用缓存，所有内容限制为 30s 的TTL
        loop  # 检查简单的转发循环并停止服务
        reload  # 运行自动重新加载 corefile，热更新
        loadbalance  # 负载均衡，默认 round_robin
    }
kind: ConfigMap
metadata:
  creationTimestamp: "2025-10-13T08:22:53Z"
  name: coredns
  namespace: kube-system
  resourceVersion: "273"
  uid: 668a56e5-f66f-40db-8abc-e799ba93a451
```

+ <font style="color:rgb(28, 30, 33);">每个 </font>`<font style="color:#DF2A3F;">{}</font>`<font style="color:rgb(28, 30, 33);"> 代表一个 zone,格式是 </font>`<font style="color:#DF2A3F;">“Zone:port{}”</font>`<font style="color:rgb(28, 30, 33);">, 其中</font>`<font style="color:#DF2A3F;">"."</font>`<font style="color:rgb(28, 30, 33);">代表默认 zone</font>
+ `<font style="color:#DF2A3F;">{}</font>`<font style="color:rgb(28, 30, 33);"> 内的每个名称代表插件的名称，只有配置的插件才会启用，当解析域名时，会先匹配 zone（都未匹配会执行默认 zone），然后 zone 内的插件从上到下依次执行(这个顺序并不是配置文件内谁在前面的顺序，而是</font>`<font style="color:#DF2A3F;">core/dnsserver/zdirectives.go</font>`<font style="color:rgb(28, 30, 33);">内的顺序)，匹配后返回处理（执行过的插件从下到上依次处理返回逻辑），不再执行下一个插件</font>

<font style="color:rgb(28, 30, 33);">CoreDNS 的 Service 地址一般情况下是固定的，类似于 kubernetes 这个 Service 地址一般就是第一个 IP 地址 </font>`<font style="color:#DF2A3F;">10.96.0.1</font>`<font style="color:rgb(28, 30, 33);">，CoreDNS 的 Service 地址就是 </font>`<font style="color:#DF2A3F;">192.96.0.10</font>`<font style="color:rgb(28, 30, 33);">，该 IP 被分配后，kubelet 会将使用 </font>`<font style="color:#DF2A3F;">--cluster-dns=<dns-service-ip></font>`<font style="color:rgb(28, 30, 33);"> 参数配置的 DNS 传递给每个容器。DNS 名称也需要域名，本地域可以使用参数</font>`<font style="color:#DF2A3F;">--cluster-domain = <default-local-domain></font>`<font style="color:rgb(28, 30, 33);"> 在 kubelet 中配置：</font>

```yaml
➜  ~ cat /var/lib/kubelet/config.yaml
[......]
clusterDNS:
- 192.96.0.10
clusterDomain: cluster.local
.[......]
```

<font style="color:rgb(28, 30, 33);">我们前面说了如果我们建立的 Service 如果支持域名形式进行解析，就可以解决我们的服务发现的功能，那么利用 kubedns 可以将 Service 生成怎样的 DNS 记录呢？</font>

+ <font style="color:rgb(28, 30, 33);">普通的 Service：会生成 </font>`<font style="color:#DF2A3F;">servicename.namespace.svc.cluster.local</font>`<font style="color:rgb(28, 30, 33);"> 的域名，会解析到 Service 对应的 ClusterIP 上，在 Pod 之间的调用可以简写成 </font>`<font style="color:#DF2A3F;">servicename.namespace</font>`<font style="color:rgb(28, 30, 33);">，如果处于同一个命名空间下面，甚至可以只写成 </font>`<font style="color:#DF2A3F;">servicename</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">即可访问</font>
+ <font style="color:rgb(28, 30, 33);">Headless Service：无头服务，就是把 clusterIP 设置为 None 的，会被解析为指定 Pod 的 IP 列表，同样还可以通过 </font>`<font style="color:#DF2A3F;">podname.servicename.namespace.svc.cluster.local</font>`<font style="color:rgb(28, 30, 33);"> 访问到具体的某一个 Pod。</font>

<font style="color:rgb(28, 30, 33);">接下来我们来使用一个简单 Pod 来测试下 Service 的域名访问：</font>

```shell
# busybox 的最新版无法很好的模拟
➜  ~ kubectl run -it --image busybox:1.28.3 test-dns --restart=Never --rm /bin/sh
If you don't see a command prompt, try pressing enter.
/ # cat /etc/resolv.conf
search opa.svc.cluster.local svc.cluster.local cluster.local
nameserver 192.96.0.10
options ndots:5
```

<font style="color:rgb(28, 30, 33);">我们进入到 Pod 中，查看 </font>`<font style="color:#DF2A3F;">/etc/resolv.conf</font>`<font style="color:rgb(28, 30, 33);"> 中的内容，可以看到 </font>`<font style="color:#DF2A3F;">nameserver</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">的地址 </font>`<font style="color:#DF2A3F;">192.96.0.10</font>`<font style="color:rgb(28, 30, 33);">，该 IP 地址即是在安装 CoreDNS 插件的时候集群分配的一个固定的静态 IP 地址，我们可以通过下面的命令进行查看：</font>

```shell
➜  ~ kubectl get svc kube-dns -n kube-system
NAME       TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)                  AGE
kube-dns   ClusterIP   192.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   3d1h
```

<font style="color:rgb(28, 30, 33);">也就是说我们这个 Pod 现在默认的 </font>`<font style="color:#DF2A3F;">nameserver</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">就是 </font>`<font style="color:#DF2A3F;">kube-dns</font>`<font style="color:rgb(28, 30, 33);"> 的地址，现在我们来访问下前面我们创建的 nginx-service 服务：</font>

```shell
/ # wget -q -O- nginx-service.default.svc.cluster.local
# 命令执行不会有任何的结果

# Service 对外暴露的端口是 5000
➜  ~ kubectl get svc nginx-service
NAME            TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
nginx-service   ClusterIP   192.96.249.206   <none>        5000/TCP   30s
```

<font style="color:rgb(28, 30, 33);">可以看到上面我们使用 </font>`<font style="color:#DF2A3F;">wget</font>`<font style="color:rgb(28, 30, 33);"> 命令去访问 nginx-service 服务的域名的时候被 Hang 住了，没有得到期望的结果，这是因为上面我们建立 Service 的时候暴露的端口是 5000：</font>

```shell
/ # wget -q -O- nginx-service.default.svc.cluster.local:5000
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

:::color3
💡<font style="color:rgb(28, 30, 33);">无头服务会将 </font>`<font style="color:#DF2A3F;">ClusterIP = None</font>`<font style="color:rgb(28, 30, 33);">，Headless Service 会将 Service 解析成后端 Endpoint 的 IP 列表。</font>

:::

<font style="color:rgb(28, 30, 33);">加上 5000 端口，就正常访问到服务，再试一试访问：</font>`<font style="color:#DF2A3F;">nginx-service.default.svc</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">nginx-service.default</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">nginx-service</font>`<font style="color:rgb(28, 30, 33);">，不出意外这些域名都可以正常访问到期望的结果。</font>

<font style="color:rgb(28, 30, 33);">到这里我们是不是就实现了在集群内部通过 Service 的域名形式进行互相通信了，大家下去试着看看访问不同 namespace 下面的服务呢？</font>

## <font style="color:rgb(28, 30, 33);">2 给 Pod 添加 DNS 记录</font>
<font style="color:rgb(28, 30, 33);">我们都知道 StatefulSet 中的 Pod 是拥有单独的 DNS 记录的，比如一个 StatefulSet 名称为 etcd，而它关联的 Headless SVC 名称为 etcd-headless，那么 CoreDNS 就会为它的每个 Pod 解析如下的记录：</font>

```shell
# etcd-0.etcd-headless.default.svc.cluster.local
# etcd-1.etcd-headless.default.svc.cluster.local
# [exit......]
```

<font style="color:rgb(28, 30, 33);">那么除了 StatefulSet 管理的 Pod 之外，其他的 Pod 是否也可以生成 DNS 记录呢？</font>

<font style="color:rgb(28, 30, 33);">如下所示，我们这里只有一个 Headless 的 SVC，并没有 StatefulSet 管理的 Pod，而是 ReplicaSet 管理的 Pod，我们可以看到貌似也生成了类似于 StatefulSet 中的解析记录。</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570407716-1cb2ddc4-4d6b-4f4b-97d1-9b8accffee36.png)

<font style="color:rgb(28, 30, 33);">这是怎么做到的呢？按照我们常规的理解会认为这是一个 StatefulSet 管理的 Pod，但其实这里是不同的 ReplicaSet 而已。这里的实现其实是因为 Pod 自己本身也是可以有自己的 DNS 记录的，所以我们是可以去实现一个类似于 StatefulSet 的 Pod 那样的解析记录的。</font>

<font style="color:rgb(28, 30, 33);">首先我们来部署一个 Deployment 管理的普通应用，其定义如下：</font>

```yaml
# nginx.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 2
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:1.7.9
          ports:
            - containerPort: 80
```

<font style="color:rgb(28, 30, 33);">部署后创建了两个 Pod：</font>

```shell
➜  ~ kubectl apply -f nginx.yaml
deployment.apps/nginx created

➜  ~ kubectl get pod -l app=nginx -o wide
NAME                            READY   STATUS    RESTARTS   AGE    IP               NODE           NOMINATED NODE   READINESS GATES
nginx-57b754799f-9nljt          1/1     Running   0          10s    192.244.51.237   hkk8snode002   <none>           <none>
nginx-57b754799f-fsg4j          1/1     Running   0          10s    192.244.211.50   hkk8snode001   <none>           <none>
```

<font style="color:rgb(28, 30, 33);">然后定义如下的 Headless Service:</font>

```yaml
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  clusterIP: None
  ports:
    - name: http
      port: 80
      protocol: TCP
  selector: # Pod 的标签选择器
    app: nginx
  type: ClusterIP
```

<font style="color:rgb(28, 30, 33);">创建该 service，并尝试解析 service DNS：</font>

```shell
➜  ~ kubectl apply -f service.yaml
service/nginx created
➜  ~ kubectl get svc nginx
NAME    TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
nginx   ClusterIP   None         <none>        80/TCP    5s

➜  ~ dig @192.96.0.10 nginx.default.svc.cluster.local

; <<>> DiG 9.11.36-RedHat-9.11.36-8.el8 <<>> @192.96.0.10 nginx.default.svc.cluster.local
; (1 server found)
;; global options: +cmd
;; Got answer:
;; WARNING: .local is reserved for Multicast DNS
;; You are currently testing what happens when an mDNS query is leaked to DNS
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 56064
;; flags: qr aa rd; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
; COOKIE: 6151b613d52e7426 (echoed)
;; QUESTION SECTION:
;nginx.default.svc.cluster.local. IN    A

;; ANSWER SECTION:
nginx.default.svc.cluster.local. 30 IN  A       192.244.51.237
nginx.default.svc.cluster.local. 30 IN  A       192.244.211.50

;; Query time: 0 msec
;; SERVER: 192.96.0.10#53(192.96.0.10)
;; WHEN: Thu Oct 16 18:19:34 HKT 2025
;; MSG SIZE  rcvd: 166
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760609994522-04ebf63f-faf9-45aa-b899-7cc5d94525bc.png)

<font style="color:rgb(28, 30, 33);">然后我们对 nginx 的 FQDN 域名进行 dig 操作，可以看到返回了多条 A 记录，每一条对应一个 Pod。上面 dig 命令中使用的 </font>`<font style="color:#DF2A3F;">192.96.0.10</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">就是 kube-dns 的 Cluster IP，可以在 kube-system namespace 中查看：</font>

```shell
➜  ~ kubectl -n kube-system get svc kube-dns
NAME       TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)                  AGE
kube-dns   ClusterIP   192.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   3d5h
```

<font style="color:rgb(28, 30, 33);">接下来我们试试在 service 名字前面加上 Pod 名字交给 kube-dns 做解析：</font>

```shell
➜  ~ kubectl get pod -l app=nginx 
NAME                     READY   STATUS    RESTARTS   AGE
nginx-57b754799f-9nljt   1/1     Running   0          4m40s
nginx-57b754799f-fsg4j   1/1     Running   0          4m40s

➜  ~ dig @192.96.0.10 nginx-57b754799f-9nljt.nginx.default.svc.cluster.local

; <<>> DiG 9.11.36-RedHat-9.11.36-8.el8 <<>> @192.96.0.10 nginx-57b754799f-9nljt.nginx.default.svc.cluster.local
; (1 server found)
;; global options: +cmd
;; Got answer:
;; WARNING: .local is reserved for Multicast DNS
;; You are currently testing what happens when an mDNS query is leaked to DNS
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 12153
;; flags: qr aa rd; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
; COOKIE: 7ce45908e116884a (echoed)
;; QUESTION SECTION:
;nginx-57b754799f-9nljt.nginx.default.svc.cluster.local.        IN A

;; AUTHORITY SECTION:
cluster.local.          30      IN      SOA     ns.dns.cluster.local. hostmaster.cluster.local. 1760609967 7200 1800 86400 30

;; Query time: 0 msec
;; SERVER: 192.96.0.10#53(192.96.0.10)
;; WHEN: Thu Oct 16 18:21:28 HKT 2025
;; MSG SIZE  rcvd: 188
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760610122936-b09a921d-9af0-4b26-9f34-402b3a2d85bc.png)

<font style="color:rgb(28, 30, 33);">可以看到并没有得到解析结果。官方文档中有一段 </font>`<font style="color:#DF2A3F;">Pod’s hostname and subdomain fields</font>`<font style="color:rgb(28, 30, 33);"> 说明：</font>

<u><font style="color:#DF2A3F;">Pod 规范中包含一个可选的 hostname 字段，可以用来指定 Pod 的主机名。当这个字段被设置时，它将优先于 Pod 的名字成为该 Pod 的主机名。</font></u>举个例子，给定一个 hostname 设置为 "my-host" 的 Pod， 该 Pod 的主机名将被设置为 "my-host"。<u>Pod 规约还有一个可选的 </u>`<u><font style="color:#DF2A3F;">subdomain</font></u>`<u> 字段，可以用来指定 Pod 的子域名。</u><u><font style="color:#601BDE;">举个例子，某 Pod 的 hostname 设置为 “foo”，subdomain 设置为 “bar”， 在名字空间 “my-namespace” 中对应的完全限定域名为 “</font></u>`<u><font style="color:#601BDE;">foo.bar.my-namespace.svc.cluster-domain.example</font></u>`<u><font style="color:#601BDE;">”。</font></u>

<font style="color:rgb(28, 30, 33);">现在我们编辑一下 </font>`<font style="color:#DF2A3F;">nginx.yaml</font>`<font style="color:rgb(28, 30, 33);"> 加上 </font>`<font style="color:#DF2A3F;">subdomain</font>`<font style="color:rgb(28, 30, 33);"> 测试下看看：</font>

```yaml
# Deployment-nginx.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 2
  template:
    metadata:
      labels:
        app: nginx
    spec:
      subdomain: nginx
      containers:
        - name: nginx
          image: nginx:1.7.9
          ports:
            - containerPort: 80
```

<font style="color:rgb(28, 30, 33);">更新部署再尝试解析 Pod DNS：</font>

```shell
➜  ~ kubectl apply -f Deployment-nginx.yaml
➜  ~ kubectl get pod -l app=nginx -o wide
NAME                     READY   STATUS    RESTARTS   AGE   IP               NODE           NOMINATED NODE   READINESS GATES
nginx-7f67cc7957-q767k   1/1     Running   0          4s    192.244.51.233   hkk8snode002   <none>           <none>
nginx-7f67cc7957-xgn9s   1/1     Running   0          5s    192.244.211.44   hkk8snode001   <none>           <none>

➜  ~ dig @192.96.0.10 nginx-7f67cc7957-xgn9s.nginx.default.svc.cluster.local

; <<>> DiG 9.11.36-RedHat-9.11.36-8.el8 <<>> @192.96.0.10 nginx-7f67cc7957-xgn9s.nginx.default.svc.cluster.local
; (1 server found)
;; global options: +cmd
;; Got answer:
;; WARNING: .local is reserved for Multicast DNS
;; You are currently testing what happens when an mDNS query is leaked to DNS
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 4726
;; flags: qr aa rd; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
; COOKIE: ff21661583e89c1c (echoed)
;; QUESTION SECTION:
;nginx-7f67cc7957-xgn9s.nginx.default.svc.cluster.local.        IN A

;; AUTHORITY SECTION:
cluster.local.          30      IN      SOA     ns.dns.cluster.local. hostmaster.cluster.local. 1760610308 7200 1800 86400 30

;; Query time: 0 msec
;; SERVER: 192.96.0.10#53(192.96.0.10)
;; WHEN: Thu Oct 16 18:25:32 HKT 2025
;; MSG SIZE  rcvd: 188
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760610511358-e16cb020-2d68-492a-a1c3-d0ab11bf75b7.png)

<font style="color:rgb(28, 30, 33);">可以看到依然不能解析，那就试试官方文档中的例子 ，不用 Deployment 直接创建 Pod 吧。第一步先将 </font>`<font style="color:#601BDE;">hostname</font>`<font style="color:rgb(28, 30, 33);"> 和 </font>`<font style="color:#601BDE;">subdomain</font>`<font style="color:#601BDE;"> </font><font style="color:rgb(28, 30, 33);">注释掉：</font>

```yaml
# individual-pods-example.yaml
apiVersion: v1
kind: Service
metadata:
  name: default-subdomain
spec:
  selector:
    name: busybox
  clusterIP: None
  ports:
    - name: foo # Actually, no port is needed.
      port: 1234
      targetPort: 1234
---
apiVersion: v1
kind: Pod
metadata:
  name: busybox1
  labels:
    name: busybox
spec:
  hostname: busybox-1
  subdomain: default-subdomain
  containers:
    - image: busybox:1.28
      command:
        - sleep
        - '3600'
      name: busybox
---
apiVersion: v1
kind: Pod
metadata:
  name: busybox2
  labels:
    name: busybox
spec:
  hostname: busybox-2
  subdomain: default-subdomain
  containers:
    - image: busybox:1.28
      command:
        - sleep
        - '3600'
      name: busybox
```

<font style="color:rgb(28, 30, 33);">部署然后尝试解析 Pod DNS (</font><u>💡</u><u><font style="color:rgb(28, 30, 33);">注意这里 hostname 和 Pod 的名字有区别，中间多了减号</font></u><font style="color:rgb(28, 30, 33);">)：</font>

```shell
➜ ~ kubectl apply -f individual-pods-example.yaml
service/default-subdomain created
pod/busybox1 created
pod/busybox2 created

➜ ~ dig @192.96.0.10 busybox-1.default-subdomain.default.svc.cluster.local

; <<>> DiG 9.11.36-RedHat-9.11.36-8.el8 <<>> @192.96.0.10 busybox-1.default-subdomain.default.svc.cluster.local
; (1 server found)
;; global options: +cmd
;; Got answer:
;; WARNING: .local is reserved for Multicast DNS
;; You are currently testing what happens when an mDNS query is leaked to DNS
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 31414
;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
; COOKIE: 0f5cde7a547a86ad (echoed)
;; QUESTION SECTION:
;busybox-1.default-subdomain.default.svc.cluster.local. IN A

;; ANSWER SECTION:
busybox-1.default-subdomain.default.svc.cluster.local. 30 IN A 192.244.211.38

;; Query time: 0 msec
;; SERVER: 192.96.0.10#53(192.96.0.10)
;; WHEN: Thu Oct 16 18:34:44 HKT 2025
;; MSG SIZE  rcvd: 163
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760610945824-c4dfccd2-6556-43b7-8611-71d320ea3092.png)

<font style="color:rgb(28, 30, 33);">现在我们看到有 ANSWER 记录回来了，</font>🚀<u><font style="color:#DF2A3F;">hostname 和 subdomain 二者都必须显式指定，缺一不可。</font></u><font style="color:rgb(28, 30, 33);">一开始我们的截图中的实现方式其实也是这种方式。</font>

<font style="color:rgb(28, 30, 33);">现在我们修改一下之前的 nginx deployment 加上 hostname，重新解析：</font>

+ 最终的 Yaml 文件如下：

```yaml
# Deployment-nginx.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 2
  template:
    metadata:
      labels:
        app: nginx
    spec:
      hostname: nginx
      subdomain: nginx
      containers:
        - name: nginx
          image: nginx:1.7.9
          ports:
            - containerPort: 80
```

+ 测试重新解析

```shell
➜  ~ dig @192.96.0.10 nginx.nginx.default.svc.cluster.local

; <<>> DiG 9.11.36-RedHat-9.11.36-8.el8 <<>> @192.96.0.10 nginx.nginx.default.svc.cluster.local
; (1 server found)
;; global options: +cmd
;; Got answer:
;; WARNING: .local is reserved for Multicast DNS
;; You are currently testing what happens when an mDNS query is leaked to DNS
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 46090
;; flags: qr aa rd; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
; COOKIE: 6b62d345b997e521 (echoed)
;; QUESTION SECTION:
;nginx.nginx.default.svc.cluster.local. IN A

;; ANSWER SECTION:
nginx.nginx.default.svc.cluster.local. 30 IN A  192.244.211.39
nginx.nginx.default.svc.cluster.local. 30 IN A  192.244.51.230

;; Query time: 0 msec
;; SERVER: 192.96.0.10#53(192.96.0.10)
;; WHEN: Thu Oct 16 18:36:49 HKT 2025
;; MSG SIZE  rcvd: 184
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760611025540-475fd07d-d342-4451-914b-8dd6812e1edf.png)

<font style="color:rgb(28, 30, 33);">可以看到解析成功了，但是因为 Deployment 中无法给每个 Pod 指定不同的 hostname，所以两个 Pod 有同样的 hostname，解析出来两个 IP，跟我们的本意就不符合了。不过知道了这种方式过后我们就可以自己去写一个 Operator 去直接管理 Pod 了，给每个 Pod 设置不同的 hostname 和一个 Headless SVC 名称的 subdomain，这样就相当于实现了 StatefulSet 中的 Pod 解析。</font>

## <font style="color:rgb(28, 30, 33);">3 Pod 的 DNS 策略</font>
<font style="color:rgb(28, 30, 33);">DNS 策略可以单独对 Pod 进行设定，目前 Kubernetes 支持以下特定 Pod 的 DNS 策略。这些策略可以在 Pod 规范中的 </font>`<font style="color:#DF2A3F;">dnsPolicy</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">字段设置：</font>

+ `<font style="color:#DF2A3F;">Default</font>`<font style="color:rgb(28, 30, 33);">: </font><u><font style="color:rgb(28, 30, 33);">有人说 Default 的方式，是使用宿主机的方式，这种说法并不准确。这种方式其实是让 kubelet 来决定使用何种 DNS 策略。而 kubelet 默认的方式，就是使用宿主机的 </font></u>`<u><font style="color:#DF2A3F;">/etc/resolv.conf</font></u>`<u><font style="color:rgb(28, 30, 33);">（可能这就是有人说使用宿主机的 DNS 策略的方式吧），但是，kubelet 是可以灵活来配置使用什么文件来进行 DNS 策略的，我们完全可以使用 kubelet 的参数 </font></u>`<u><font style="color:#DF2A3F;">--resolv-conf=/etc/resolv.conf</font></u>`<u><font style="color:rgb(28, 30, 33);"> 来决定你的 DNS 解析文件地址。</font></u>
+ `<font style="color:#DF2A3F;">ClusterFirst</font>`<font style="color:rgb(28, 30, 33);">: </font><u><font style="color:rgb(28, 30, 33);">这种方式，表示 Pod 内的 DNS 使用集群中配置的 DNS 服务，简单来说，就是使用 Kubernetes 中 kubeDNS 或 CoreDNS 服务进行域名解析</font></u><font style="color:rgb(28, 30, 33);">。如果解析不成功，才会使用宿主机的 DNS 配置进行解析。</font>
+ `<font style="color:#DF2A3F;">ClusterFirstWithHostNet</font>`<font style="color:rgb(28, 30, 33);">：在某些场景下，我们的 </font><u><font style="color:rgb(28, 30, 33);">Pod 是用 HostNetwork 模式启动的，一旦用 </font></u>`<u><font style="color:#DF2A3F;">HostNetwork</font></u>`<u><font style="color:rgb(28, 30, 33);"> 模式，表示这个 Pod 中的所有容器，都要使用宿主机的 </font></u>`<u><font style="color:#DF2A3F;">/etc/resolv.conf</font></u>`<u><font style="color:rgb(28, 30, 33);"> 配置进行 DNS 查询，但如果你还想继续使用 Kubernetes 的 DNS 服务，那就将 </font></u>`<u><font style="color:#DF2A3F;">dnsPolicy</font></u>`<u><font style="color:rgb(28, 30, 33);"> 设置为 </font></u>`<u><font style="color:#DF2A3F;">ClusterFirstWithHostNet</font></u>`<u><font style="color:rgb(28, 30, 33);">。</font></u>
+ `<font style="color:#DF2A3F;">None</font>`<font style="color:rgb(28, 30, 33);">: 表示空的 DNS 设置，这种方式一般用于想要自定义 DNS 配置的场景，往往需要和 </font>`<font style="color:#DF2A3F;">dnsConfig</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">配合一起使用达到自定义 DNS 的目的。</font>

需要注意的是 `<font style="color:#DF2A3F;">Default</font>`<font style="color:#DF2A3F;"> </font>并不是默认的 DNS 策略，如果未明确指定 dnsPolicy，则使用 `<font style="color:#DF2A3F;">ClusterFirst</font>`。

<font style="color:rgb(28, 30, 33);">下面的示例显示了一个 Pod，其 DNS 策略设置为 </font>`<font style="color:#DF2A3F;">ClusterFirstWithHostNet</font>`<font style="color:rgb(28, 30, 33);">，因为它已将 </font>`<font style="color:#DF2A3F;">hostNetwork</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">设置为 </font>`<font style="color:#DF2A3F;">true</font>`<font style="color:rgb(28, 30, 33);">。</font>

```yaml
# ClusterFirstWithHostNet-busybox.yaml
apiVersion: v1
kind: Pod
metadata:
  name: busybox
  namespace: default
spec:
  containers:
    - image: busybox:1.28
      command:
        - sleep
        - '3600'
      imagePullPolicy: IfNotPresent
      name: busybox
  restartPolicy: Always
  hostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet # 可以使用 Kubernetes DNS 解析
```

引用资源清单文件

```shell
$ kubectl apply -f ClusterFirstWithHostNet-busybox.yaml
pod/busybox created

$ kubectl get pod busybox -o wide 
NAME      READY   STATUS    RESTARTS   AGE   IP               NODE           NOMINATED NODE   READINESS GATES
busybox   1/1     Running   0          25s   192.168.178.36   hkk8snode001   <none>           <none>

$ kubectl exec -it busybox -- cat /etc/resolv.conf
search default.svc.cluster.local svc.cluster.local cluster.local
nameserver 192.96.0.10
options ndots:5
```

<details class="lake-collapse"><summary id="u7ee5882b"><span class="ne-text">Pod 的 DNS 策略可以通过 dnsPolicy 字段指定</span></summary><p id="ueed00a56" class="ne-p"><span class="ne-text">在 Kubernetes 中，Pod 的 DNS 策略可以通过 dnsPolicy 字段指定，主要有以下几种选项：</span></p><div data-type="success" class="ne-alert"><ol class="ne-ol"><li id="u99546f89" data-lake-index-type="0"><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">ClusterFirstWithHostNet</span></code><span class="ne-text">：</span></li></ol><p id="uf3a0e174" class="ne-p"><span class="ne-text">适用于使用 </span><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">hostNetwork: true</span></code><span class="ne-text"> 的 Pod。这种策略首先尝试使用集群的 DNS 进行解析，如果集群内没有找到相应的记录，则回退到宿主机的 DNS。</span><span class="ne-text" style="color: #DF2A3F; text-decoration: underline">它的设计目的是让在宿主网络中运行的 Pod 能够访问集群的 DNS，同时又能使用宿主机的 DNS 设置。</span></p><ol start="2" class="ne-ol"><li id="u86dd627f" data-lake-index-type="0"><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">ClusterFirst</span></code><span class="ne-text">：</span></li></ol><p id="u47b34ba9" class="ne-p"><span class="ne-text">这是 Kubernetes 的默认 DNS 策略。</span><span class="ne-text" style="color: #DF2A3F; text-decoration: underline">它优先使用集群内部的 DNS 解析服务，只有在集群 DNS 中找不到对应的记录时，才会回退到宿主机的 DNS。这个策略通常适用于大多数在 Kubernetes 集群中运行的应用。</span></p><ol start="3" class="ne-ol"><li id="u9ad380f6" data-lake-index-type="0"><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">Default</span></code><span class="ne-text">：</span></li></ol><p id="ufc9a4e0c" class="ne-p"><span class="ne-text">这个策略使 Pod 使用宿主节点的 DNS 配置，而不是集群的 DNS。这</span><span class="ne-text" style="color: #DF2A3F; text-decoration: underline">意味着 Pod 将直接使用宿主节点上配置的 DNS 服务器。一般不推荐使用，除非有特定需求。</span></p><ol start="4" class="ne-ol"><li id="u9e77f24f" data-lake-index-type="0"><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">None</span></code><span class="ne-text">：</span></li></ol><p id="u5a556b76" class="ne-p"><span class="ne-text">当设置为 None 时，Pod 不会自动配置 DNS。在这种情况下，用户必须在 dnsConfig 字段中手动提供 DNS 设置。这个选项通常用于</span><span class="ne-text" style="color: #DF2A3F; text-decoration: underline">需要自定义 DNS 配置的特殊场景。</span></p></div><p id="ua315ac42" class="ne-p"><span class="ne-text">示例配置</span></p><p id="u08752afc" class="ne-p"><span class="ne-text">以下是一个 Pod 的示例 YAML 配置，展示了如何使用不同的 DNS 策略：</span></p><pre data-language="yaml" id="WTp3b" class="ne-codeblock language-yaml"><code>apiVersion: v1
kind: Pod
metadata:
  name: example-pod
spec:
  containers:
  - name: example-container
    image: nginx
  dnsPolicy: ClusterFirstWithHostNet</code></pre><div data-type="color3" class="ne-alert"><p id="ude0f9571" class="ne-p"><span class="ne-text">☃️</span><span class="ne-text">总结</span></p><p id="ueee709c4" class="ne-p"><span class="ne-text">选择合适的 DNS 策略对于确保应用在 Kubernetes 中正常解析域名非常重要。ClusterFirst 是最常用的策略，而 ClusterFirstWithHostNet 则适用于需要宿主网络的场景。根据应用的需求合理配置，可以提升应用的可靠性和性能。</span></p></div></details>
## <font style="color:rgb(28, 30, 33);">4 Pod 的 DNS 配置</font>
<font style="color:rgb(28, 30, 33);">Pod 的 DNS 配置可让用户对 Pod 的 DNS 设置进行更多控制。</font>`<font style="color:#DF2A3F;">dnsConfig</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">字段是可选的，它可以与任何 </font>`<font style="color:#DF2A3F;">dnsPolicy</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">设置一起使用。 但是，</font>**<u><font style="color:#DF2A3F;">当 Pod 的 dnsPolicy 设置为 "None" 时，必须指定 dnsConfig 字段。</font></u>**

<font style="color:rgb(28, 30, 33);">用户可以在 dnsConfig 字段中指定以下属性：</font>

+ `<font style="color:#DF2A3F;">nameservers</font>`<font style="color:rgb(28, 30, 33);">：将用作于 Pod 的 DNS 服务器的 IP 地址列表。 最多可以指定 3 个 IP 地址。当 Pod 的 dnsPolicy 设置为 "None" 时，列表必须至少包含一个 IP 地址，否则此属性是可选的。所列出的服务器将合并到从指定的 DNS 策略生成的基本名称服务器，并删除重复的地址。</font>
+ `<font style="color:#DF2A3F;">searches</font>`<font style="color:rgb(28, 30, 33);">：用于在 Pod 中查找主机名的 DNS 搜索域的列表。此属性是可选的。 指定此属性时，所提供的列表将合并到根据所选 DNS 策略生成的基本搜索域名中。重复的域名将被删除，Kubernetes 最多允许 6 个搜索域。</font>
+ `<font style="color:#DF2A3F;">options</font>`<font style="color:rgb(28, 30, 33);">：可选的对象列表，其中每个对象可能具有 name 属性（必需）和 value 属性（可选）。此属性中的内容将合并到从指定的 DNS 策略生成的选项。重复的条目将被删除。</font>

<font style="color:rgb(28, 30, 33);">以下是具有自定义 DNS 设置的 Pod 示例：</font>

```yaml
# dns-example.yaml
apiVersion: v1
kind: Pod
metadata:
  namespace: default
  name: dns-example
spec:
  containers:
    - name: test
      image: nginx
  dnsPolicy: 'None'
  dnsConfig:
    nameservers:
      - 1.2.3.4
    searches:
      - ns1.svc.cluster-domain.example
      - my.dns.search.suffix
    options:
      - name: ndots
        value: '2'
      - name: edns0
```

<font style="color:rgb(28, 30, 33);">创建上面的 Pod 后，容器 </font>`<font style="color:#DF2A3F;">test</font>`<font style="color:rgb(28, 30, 33);"> 会在其 </font>`<font style="color:#DF2A3F;">/etc/resolv.conf</font>`<font style="color:rgb(28, 30, 33);"> 文件中获取以下内容：</font>

```shell
$ kubectl apply -f dns-example.yaml
pod/dns-example created

$ kubectl exec -it dns-example -- cat /etc/resolv.conf
search ns1.svc.cluster-domain.example my.dns.search.suffix
nameserver 1.2.3.4
options ndots:2 edns0
```

