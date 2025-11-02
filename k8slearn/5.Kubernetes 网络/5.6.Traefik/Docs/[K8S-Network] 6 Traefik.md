[Traefik](https://github.com/containous/traefik) 是一个开源的可以使服务发布变得轻松有趣的边缘路由器。它负责接收你系统的请求，然后使用合适的组件来对这些请求进行处理。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570571882-1acd32aa-0311-4e17-b645-dd072b40c62c.png)

除了众多的功能之外，Traefik 的与众不同之处还在于它会自动发现适合你服务的配置。当 Traefik 在检查你的服务时，会找到服务的相关信息并找到合适的服务来满足对应的请求。

Traefik 兼容所有主流的集群技术，比如 Kubernetes，Docker，Docker Swarm，AWS，Mesos，Marathon，等等；并且可以同时处理多种方式。（甚至可以用于在裸机上运行的比较旧的软件。）

使用 Traefik，不需要维护或者同步一个独立的配置文件：因为一切都会自动配置，实时操作的（无需重新启动，不会中断连接）。使用 Traefik，你可以花更多的时间在系统的开发和新功能上面，而不是在配置和维护工作状态上面花费大量时间。

## 1 核心概念
Traefik 是一个边缘路由器，是你整个平台的大门，拦截并路由每个传入的请求：它知道所有的逻辑和规则，这些规则确定哪些服务处理哪些请求；传统的反向代理需要一个配置文件，其中包含路由到你服务的所有可能路由，而 Traefik 会实时检测服务并自动更新路由规则，可以自动服务发现。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570578419-b1058026-78e5-4c0e-8b63-ab322c5558e7.png)

首先，当启动 Traefik 时，需要定义 `<font style="color:#DF2A3F;">entrypoints</font>`（入口点），然后，根据连接到这些 entrypoints 的**<font style="color:#DF2A3F;">路由</font>**来分析传入的请求，来查看他们是否与一组**<font style="color:#DF2A3F;">规则</font>**相匹配，如果匹配，则路由可能会将请求通过一系列**<font style="color:#DF2A3F;">中间件</font>**转换过后再转发到你的**<font style="color:#DF2A3F;">服务</font>**上去。在了解 Traefik 之前有几个核心概念我们必须要了解：

+ `<font style="color:#DF2A3F;">Providers</font>`  用来自动发现平台上的服务，可以是编排工具、容器引擎或者 key-value 存储等，比如 Docker、Kubernetes、File
+ `<font style="color:#DF2A3F;">Entrypoints</font>`  监听传入的流量（端口等…），是网络入口点，它们定义了接收请求的端口（HTTP 或者 TCP）。
+ `<font style="color:#DF2A3F;">Routers</font>`  分析请求（host, path, headers, SSL, …），负责将传入请求连接到可以处理这些请求的服务上去。
+ `<font style="color:#DF2A3F;">Services</font>`  将请求转发给你的应用（load balancing, …），负责配置如何获取最终将处理传入请求的实际服务。
+ `<font style="color:#DF2A3F;">Middlewares</font>`  中间件，用来修改请求或者根据请求来做出一些判断（authentication, rate limiting, headers, ...），中间件被附件到路由上，是一种在请求发送到你的**<font style="color:#DF2A3F;">服务</font>**之前（或者在服务的响应发送到客户端之前）调整请求的一种方法。

## 2 安装 Traefik
### 2.1 安装 Traefik Ingress
> Reference：[https://doc.traefik.io/traefik/getting-started/kubernetes/](https://doc.traefik.io/traefik/getting-started/kubernetes/)
>

参考资料（安装 Traefik）

[[K8S] 28 Traefik 2.3 的基本使用 & 29 Traefik 2.3 的高级使用 & 30 Traefik 2.3 代理TCP-UDP](https://www.yuque.com/seekerzw/xi8l23/uannyd354m77ksss#%E5%AE%89%E8%A3%85)

由于 Traefik 2.X 版本和之前的 1.X 版本不兼容，我们这里选择功能更加强大的 2.X 版本来和大家进行讲解。

在 Traefik 中的配置可以使用两种不同的方式：

+ 动态配置：完全动态的路由配置
+ 静态配置：启动配置

`<font style="color:#DF2A3F;">静态配置</font>`中的元素（这些元素不会经常更改）连接到 providers 并定义 Treafik 将要监听的 entrypoints。

在 Traefik 中有三种方式定义静态配置：在配置文件中、在命令行参数中、通过环境变量传递

`<font style="color:#DF2A3F;">动态配置</font>`包含定义系统如何处理请求的所有配置内容，这些配置是可以改变的，而且是无缝热更新的，没有任何请求中断或连接损耗。

这里我们还是使用 Helm 来快速安装 traefik，首先获取 Helm Chart 包：

```shell
# 需要将之前的 Ingress-Nginx 删除
$ helm uninstall -n ingress-nginx ingress-nginx
release "ingress-nginx" uninstalled
# 或者将 ingress-nginx Pod Kill 掉即可，副本数调整为 0

# 安装 Traefik
➜ git clone https://github.com/traefik/traefik-helm-chart
➜ cd traefik-helm-chart

➜ wget https://github.com/traefik/traefik-helm-chart/archive/refs/tags/v21.2.1.tar.gz
```

创建一个定制的 values 配置文件：

```yaml
# ci/deployment-prod.yaml Or traefik/values.yaml
deployment:
  enabled: true
  kind: Deployment

# 使用 IngressClass. Traefik 版本<2.3 或者 Kubernetes 版本 < 1.18.x 会被忽略
ingressClass:
  # 还没有进行完整的单元测试，Pending https://github.com/rancher/helm-unittest/pull/12
  enabled: true
  isDefaultClass: false

ingressRoute: # 不用自动创建，我们自己处理
  dashboard:
    enabled: false # true

#
# 配置 providers
#
providers:
  kubernetesCRD: # 开启 crd provider
    enabled: true
    allowCrossNamespace: true # 是否允许跨命名空间
    allowExternalNameServices: true # 是否允许使用 ExternalName 的服务

  kubernetesIngress: # 开启 ingress provider
    enabled: true
    allowExternalNameServices: true

logs:
  general:
    # format: json
    level: DEBUG
  access:
    enabled: true

ports:
  web:
    port: 8000
    hostPort: 80 # 使用 hostport 模式

  websecure:
    port: 8443
    hostPort: 443 # 使用 hostport 模式

  metrics:
    port: 9100
    hostPort: 9101

service: # host 模式就不需要创建 Service 了，云端环境可以用 Service 模式
  enabled: false

resources:
  requests:
    cpu: '100m'
    memory: '100Mi'
  limits:
    cpu: '100m'
    memory: '100Mi'

# tolerations:   # kubeadm 安装的集群默认情况下master是有污点，如果需要安装在master节点需要添加容忍
# - key: "node-role.kubernetes.io/master"
#   operator: "Equal"
#   effect: "NoSchedule"

nodeSelector: # 固定到 hkk8smaster001 这个边缘节点
  kubernetes.io/hostname: 'hkk8smaster001'
```

这里我们使用 HostPort 模式将 Traefik 固定到 `<font style="color:#DF2A3F;">hkk8smaster001</font>` 节点上，因为只有这个节点有外网 IP，所以我们这里 `<font style="color:#DF2A3F;">hkk8smaster001</font>` 是作为流量的入口点。直接使用上面的 values 文件安装 traefik：

```shell
➜ helm upgrade --install traefik ./traefik \
  -f ./traefik/ci/deployment-prod.yaml \
  --namespace kube-system
Release "traefik" does not exist. Installing it now.
NAME: traefik
LAST DEPLOYED: Wed Oct 29 08:56:23 2025
NAMESPACE: kube-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
Traefik Proxy v2.9.9 has been deployed successfully
on kube-system namespace !

# 查看 Pod 的状态信息
➜ kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
NAME                       READY   STATUS    RESTARTS   AGE
traefik-746f6c679-t7kg7    1/1     Running   0          3m15s

# 查看 Helm Release 的状态信息
➜ helm ls -n kube-system 
NAME                            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                                   APP VERSION   
traefik                         kube-system     7               2025-10-29 16:42:57.914684655 +0800 HKT deployed        traefik-21.2.1                          v2.9.9  
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761701339503-bb75043b-17be-43dd-a3f2-6b57692d556a.png)

安装完成后我们可以通过查看 Pod 的资源清单来了解 Traefik 的运行方式：

```shell
➜ kubectl get deployment -n kube-system traefik -o yaml
apiVersion: apps/v1
kind: Deployment
[......]
    spec:
      containers:
      - args:
        - --global.checknewversion
        - --global.sendanonymoususage
        - --entrypoints.metrics.address=:9100/tcp
        - --entrypoints.traefik.address=:9000/tcp
        - --entrypoints.web.address=:8000/tcp
        - --entrypoints.websecure.address=:8443/tcp
        - --api.dashboard=true
        - --ping=true
        - --metrics.prometheus=true
        - --metrics.prometheus.entrypoint=metrics
        - --providers.kubernetescrd
        - --providers.kubernetescrd.allowCrossNamespace=true
        - --providers.kubernetescrd.allowExternalNameServices=true
        - --providers.kubernetesingress
        - --providers.kubernetesingress.allowExternalNameServices=true
        - --entrypoints.websecure.http.tls=true
        - --log.level=DEBUG
        - --accesslog=true
        - --accesslog.fields.defaultmode=keep
        - --accesslog.fields.headers.defaultmode=drop
        image: docker.io/traefik:v2.9.9
[......]
```

其中 `<font style="color:#DF2A3F;">entryPoints</font>` 属性定义了 `<font style="color:#DF2A3F;">web</font>` 和 `<font style="color:#DF2A3F;">websecure</font>` 这两个入口点的，并开启 `<font style="color:#DF2A3F;">kubernetesingress</font>` 和 `<font style="color:#DF2A3F;">kubernetescrd</font>` 这两个 provider，也就是我们可以使用 Kubernetes 原本的 Ingress 资源对象，也可以使用 Traefik 自己扩展的 `<font style="color:#DF2A3F;">IngressRoute</font>` 这样的 CRD 资源对象。

### 2.2 创建 Traefik Dashboard
我们可以首先创建一个用于 Dashboard 访问的 IngressRoute 资源清单：

```shell
# 查看 API-Versions 
➜ kubectl api-resources --api-group='traefik.containo.us'
NAME                SHORTNAMES   APIVERSION                     NAMESPACED   KIND
ingressroutes                    traefik.containo.us/v1alpha1   true         IngressRoute
ingressroutetcps                 traefik.containo.us/v1alpha1   true         IngressRouteTCP
ingressrouteudps                 traefik.containo.us/v1alpha1   true         IngressRouteUDP
middlewares                      traefik.containo.us/v1alpha1   true         Middleware
middlewaretcps                   traefik.containo.us/v1alpha1   true         MiddlewareTCP
serverstransports                traefik.containo.us/v1alpha1   true         ServersTransport
tlsoptions                       traefik.containo.us/v1alpha1   true         TLSOption
tlsstores                        traefik.containo.us/v1alpha1   true         TLSStore
traefikservices                  traefik.containo.us/v1alpha1   true         TraefikService
    
➜ cat <<'__EOF__' | kubectl apply -f -
# IngressRoute-traefik-dashboard.yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: traefik-dashboard
  namespace: kube-system
spec:
  entryPoints:
  - web
  routes:
  - match: Host(`traefik.qikqiak.com`)  # 指定域名
    kind: Rule
    services:
    - name: api@internal
      kind: TraefikService  # 引用另外的 Traefik Service
__EOF__
```

```shell
# 查看创建的 Traefik IngressRoute
➜ kubectl get ingressroute -n kube-system
NAME                AGE
traefik-dashboard   10m

➜ kubectl get ingressroute -n kube-system -o yaml 
apiVersion: v1
items:
- apiVersion: traefik.containo.us/v1alpha1
  kind: IngressRoute
  metadata:
    annotations:
      kubectl.kubernetes.io/last-applied-configuration: |
        {"apiVersion":"traefik.containo.us/v1alpha1","kind":"IngressRoute","metadata":{"annotations":{},"name":"traefik-dashboard","namespace":"kube-system"},"spec":{"entryPoints":["web"],"routes":[{"kind":"Rule","match":"Host(`traefik.qikqiak.com`)","services":[{"kind":"TraefikService","name":"api@internal"}]}]}}
    creationTimestamp: "2025-10-29T01:11:59Z"
    generation: 2
    name: traefik-dashboard
    namespace: kube-system
    resourceVersion: "3543607"
    uid: b6c9cfdf-d608-4d16-b051-ec875a85dfdb
  spec:
    entryPoints:
    - web
    routes:
    - kind: Rule
      match: Host(`traefik.qikqiak.com`)
      services:
      - kind: TraefikService
        name: api@internal
kind: List
metadata:
  resourceVersion: ""
```

其中的 `<font style="color:#DF2A3F;">TraefikService</font>` 是 `<font style="color:#DF2A3F;">Traefik Service</font>` 的一个 CRD 实现，这里我们使用的 `<font style="color:#DF2A3F;">api@internal</font>` 这个 `<font style="color:#DF2A3F;">TraefikService</font>`，表示我们访问的是 Traefik 内置的应用服务。

部署完成后我们可以通过在本地 `<font style="color:#DF2A3F;">/etc/hosts</font>` 中添加上域名 `<font style="color:#DF2A3F;">traefik.qikqiak.com</font>` 的映射即可访问 Traefik 的 Dashboard 页面了（安装 Traefik Ingress 就初步完成了）：

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761701625306-0991d388-7c25-48f5-8355-3c068ce9839c.png)

:::success
💡info "注意"

另外需要注意的是默认情况下 Traefik 的 IngressRoute 已经允许跨 namespace 进行通信了，可以通过设置参数 `<font style="color:#DF2A3F;">--providers.kubernetescrd.allowCrossNamespace=true</font>` 开启（默认已经开启），开启后 IngressRoute 就可以引用 IngressRoute 命名空间以外的其他命名空间中的任何资源了。

:::

### 2.3 创建测试的 IngressRoute
如果要让 Traefik 去处理默认的 Ingress 资源对象，则我们就需要使用名为 `<font style="color:#DF2A3F;">traefik</font>`的 IngressClass 了，因为没有指定默认的：

```shell
➜ kubectl get ingressclass
NAME      CONTROLLER                      PARAMETERS   AGE
nginx     k8s.io/ingress-nginx            <none>       20m
traefik   traefik.io/ingress-controller   <none>       35m
```

创建如下所示的一个 Ingress 资源对象，这里的核心是 `<font style="color:#DF2A3F;">ingressClassName</font>` 要指向 `<font style="color:#DF2A3F;">traefik</font>` 这个 IngressClass：

```yaml
# my-nginx-by-traefik.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-nginx-by-traefik
  namespace: default
spec:
  ingressClassName: traefik # 使用 traefk 的 IngressClass
  rules:
    - host: ngdemo-by-traefik.qikqiak.com # 将域名映射到 my-nginx 服务
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service: # 将所有请求发送到 my-nginx 服务的 80 端口
                name: my-nginx
                port:
                  number: 80
```

直接创建上面的资源对象即可：

```shell
# 引用资源清单文件
➜ kubectl create -f my-nginx-by-traefik.yaml 
ingress.networking.k8s.io/my-nginx-by-traefik created

➜ kubectl get ingress my-nginx-by-traefik 
NAME                  CLASS     HOSTS                           ADDRESS   PORTS   AGE
my-nginx-by-traefik   traefik   ngdemo-by-traefik.qikqiak.com             80      30s
```

然后就可以正常访问 `<font style="color:#DF2A3F;">ngdemo-by-traefik.qikqiak.com</font>` 域名了：

```shell
➜ curl ngdemo-by-traefik.qikqiak.com
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
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

测试访问截图：

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761701932827-db0d86bb-95d3-4388-8b2b-cb4a2c812a87.png)

可以在 Traefik Dashboard 中查看对应的 Ingress 配置信息

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761702652761-00f876e7-01c7-4162-a31d-e28e287f1f57.png)

## 3 ACME(HTTPS)
> Traefik Reference：[https://doc.traefik.io/traefik/https/acme/](https://doc.traefik.io/traefik/https/acme/)
>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731988292046-cb56fad6-6870-499c-9487-ea22fc6d50ff.png)



Traefik 通过扩展 CRD 的方式来扩展 Ingress 的功能，除了默认的用 Secret 的方式可以支持应用的 HTTPS 之外，还支持自动生成 HTTPS 证书。

比如现在我们有一个如下所示的 `<font style="color:#DF2A3F;">whoami</font>` 应用：

```yaml
# install-whoami.yaml
apiVersion: v1
kind: Service
metadata:
  name: whoami
spec:
  ports:
    - protocol: TCP
      name: web
      port: 80
  selector:
    app: whoami
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: whoami
  labels:
    app: whoami
spec:
  replicas: 2
  selector:
    matchLabels:
      app: whoami
  template:
    metadata:
      labels:
        app: whoami
    spec:
      containers:
        - name: whoami
          image: containous/whoami
          ports:
            - name: web
              containerPort: 80
```

然后定义一个 IngressRoute 对象：

```yaml
# ingressroute-demo.yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: ingressroute-demo
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`who.qikqiak.com`) && PathPrefix(`/notls`)
      kind: Rule
      services:
        - name: whoami
          port: 80
```

通过 `<font style="color:#DF2A3F;">entryPoints</font>` 指定了我们这个应用的入口点是 `<font style="color:#DF2A3F;">web</font>`，也就是通过 80 端口访问，然后**<u>访问的规则就是要匹配 </u>**`**<u><font style="color:#DF2A3F;">who.qikqiak.com</font></u>**`**<u> 这个域名，并且具有 </u>**`**<u><font style="color:#DF2A3F;">/notls</font></u>**`**<u> 的路径前缀的请求才会被 </u>**`**<u><font style="color:#DF2A3F;">whoami</font></u>**`**<u> 这个 Service 所匹配。</u>**我们可以直接创建上面的几个资源对象，然后对域名做对应的解析后，就可以访问应用了：

```shell
$ kubectl create -f install-whoami.yaml -f ingressroute-demo.yaml 
service/whoami created
deployment.apps/whoami created
ingressroute.traefik.containo.us/ingressroute-demo created
```

浏览器测试访问：

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761703793309-15b6c65f-b6ab-4eb4-a0da-836fd97076b8.png)

在 `<font style="color:#DF2A3F;">IngressRoute</font>` 对象中我们定义了一些匹配规则，这些规则在 Traefik 中有如下定义方式：

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570571534-ca0f5a0d-3a88-4c2e-9af5-124a3fae819a.png)

如果我们需要用 HTTPS 来访问我们这个应用的话，就需要监听 `<font style="color:#DF2A3F;">websecure</font>` 这个入口点，也就是通过 443 端口来访问，同样用 HTTPS 访问应用必然就需要证书，这里我们用 `<font style="color:#DF2A3F;">openssl</font>` 来创建一个自签名的证书：

```shell
➜ openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=who.qikqiak.com"
```

然后通过 Secret 对象来引用证书文件：

```shell
# 要注意证书文件名称必须是 tls.crt 和 tls.key
➜ kubectl create secret tls who-tls --cert=tls.crt --key=tls.key
➜ kubectl get secret who-tls
NAME      TYPE                DATA   AGE
who-tls   kubernetes.io/tls   2      55s
```

这个时候我们就可以创建一个 HTTPS 访问应用的 IngressRoute 对象了：

```yaml
# ingressroute-tls-demo.yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: ingressroute-tls-demo
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`who.qikqiak.com`) && PathPrefix(`/tls`)
      kind: Rule
      services:
        - name: whoami
          port: 80
  tls:
    secretName: who-tls
```

```shell
➜ kubectl create -f ingressroute-tls-demo.yaml 
ingressroute.traefik.containo.us/ingressroute-tls-demo created
```

创建完成后就可以通过 HTTPS 来访问应用了，由于我们是自签名的证书，所以证书是不受信任的：

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761704876209-d9369b4f-4010-48e6-b1a4-a304d8fd7854.png)

除了手动提供证书的方式之外 **<u>Traefik 同样也支持使用 </u>**`**<u><font style="color:#DF2A3F;">Let’s Encrypt</font></u>**`**<u> 自动生成证书，要使用 </u>**`**<u><font style="color:#DF2A3F;">Let’s Encrypt</font></u>**`**<u> 来进行自动化 HTTPS，就需要首先开启 </u>**`**<u><font style="color:#DF2A3F;">ACME</font></u>**`**<u>，开启 </u>**`**<u><font style="color:#DF2A3F;">ACME</font></u>**`**<u> 需要通过静态配置的方式</u>**，也就是说可以通过环境变量、启动参数等方式来提供。

ACME 有多种校验方式 `<font style="color:#DF2A3F;">tlsChallenge</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">httpChallenge</font>`<font style="color:#DF2A3F;"> 和 </font>`<font style="color:#DF2A3F;">dnsChallenge</font>`<font style="color:#DF2A3F;"> </font>三种验证方式，之前更常用的是 http 这种验证方式，关于这几种验证方式的使用可以查看文档：[https://www.qikqiak.com/traefik-book/https/acme/](https://www.qikqiak.com/traefik-book/https/acme/) 了解他们之间的区别。要使用 tls 校验方式的话需要保证 Traefik 的 443 端口是可达的，dns 校验方式可以生成通配符的证书，只需要配置上 DNS 解析服务商的 API 访问密钥即可校验。我们这里用 DNS 校验的方式来为大家说明如何配置 ACME。

我们可以重新修改 Helm 安装的 values 配置文件，添加如下所示的定制参数：

```yaml
# ci/deployment-prod.yaml
# 需要将 Replicas 调整为 1，如果 Replicas 调整成多个副本会导致无法正常启动，因为会把证书保存到本地，会出现冲突
additionalArguments:
  # 使用 dns 验证方式
  - --certificatesResolvers.ali.acme.dnsChallenge.provider=alidns
  # 先使用staging环境进行验证，验证成功后再使用移除下面一行的配置
  # - --certificatesResolvers.ali.acme.caServer=https://acme-staging-v02.api.letsencrypt.org/directory
  # 邮箱配置
  - --certificatesResolvers.ali.acme.email=<ali_acme_email> # ych_1024@163.com
  # 保存 ACME 证书的位置
  - --certificatesResolvers.ali.acme.storage=/data/acme.json

envFrom:
  - secretRef:
      name: traefik-alidns-secret
      # ALICLOUD_ACCESS_KEY
      # ALICLOUD_SECRET_KEY
      # ALICLOUD_REGION_ID

persistence:
  enabled: true # 开启持久化
  accessMode: ReadWriteOnce
  size: 128Mi
  path: /data

# 由于上面持久化了ACME的数据，需要重新配置下面的安全上下文
securityContext:
  readOnlyRootFilesystem: false
  runAsGroup: 0
  runAsUser: 0
  runAsNonRoot: false
```

这样我们可以通过设置 `<font style="color:#DF2A3F;">--certificatesresolvers.ali.acme.dnschallenge.provider=alidns</font>` 参数来指定指定阿里云的 DNS 校验，要使用阿里云的 DNS 校验我们还需要配置 3 个环境变量：`<font style="color:#DF2A3F;">ALICLOUD_ACCESS_KEY</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">ALICLOUD_SECRET_KEY</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">ALICLOUD_REGION_ID</font>`，分别对应我们平时开发阿里云应用的时候的密钥，可以登录阿里云后台 [https://ram.console.aliyun.com/manage/ak](https://ram.console.aliyun.com/manage/ak) 获取，由于这是比较私密的信息，所以我们用 Secret 对象来创建：

```shell
$ kubectl create secret generic traefik-alidns-secret \
  --from-literal=ALICLOUD_ACCESS_KEY=<aliyun ak> \
  --from-literal=ALICLOUD_SECRET_KEY=<aliyun sk> \
  --from-literal=ALICLOUD_REGION_ID=cn-beijing \
  -n kube-system
```

创建完成后将这个 Secret 通过环境变量配置到 Traefik 的应用中，还有一个值得注意的是验证通过的证书我们这里存到 `<font style="color:#DF2A3F;">/data/acme.json</font>` 文件中，我们一定要将这个文件持久化，否则每次 Traefik 重建后就需要重新认证，而 `<font style="color:#DF2A3F;">Let’s Encrypt</font>` 本身校验次数是有限制的。所以我们在 values 中重新开启了数据持久化，不过开启过后需要我们提供一个可用的 PV 存储，由于我们将 Traefik 固定到 hkk8smaster001 节点上的，所以我们可以创建一个 hostpath 类型的 PV（后面会详细讲解）：

```shell
➜ cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: traefik
spec:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 128Mi
  hostPath:
    path: /data/k8s/traefik
EOF
```

然后使用如下所示的命令更新 Traefik：

```shell
➜ helm upgrade --install traefik ./traefik \
  -f ./traefik/ci/deployment-prod.yaml --namespace kube-system
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761705871394-e49818b4-b440-4ffe-9df0-fa534ab11873.png)

更新完成后现在我们来修改上面我们的 `<font style="color:#DF2A3F;">whoami</font>` 应用：

```yaml
# ingressroute-tls-demo.yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: ingressroute-tls-demo
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`who.qikqiak.com`) && PathPrefix(`/tls`)
      kind: Rule
      services:
        - name: whoami
          port: 80
  tls:
    # secretName: who-tlsk
    certResolver: ali
    domains:
      - main: '*.qikqiak.com'
```

其他的都不变，只需要将 TLS 部分改成我们定义的 `<font style="color:#DF2A3F;">ali</font>` 这个证书解析器，如果我们想要生成一个通配符的域名证书的话可以定义 `<font style="color:#DF2A3F;">domains</font>` 参数来指定，然后更新 IngressRoute 对象，这个时候我们再去用 HTTPS 访问我们的应用（当然需要将域名在阿里云 DNS 上做解析）：

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570581036-7abf040f-db3a-4b7e-b5c3-fa6014d804ae.png)

我们可以看到访问应用已经是受浏览器信任的证书了，查看证书我们还可以发现该证书是一个通配符的证书。

## 4 中间件 Middleware
中间件是 Traefik2.x 中一个非常有特色的功能，我们可以根据自己的各种需求去选择不同的中间件来满足服务，Traefik 官方已经内置了许多不同功能的中间件，其中一些可以修改请求，头信息，一些负责重定向，一些添加身份验证等等，而且中间件还可以通过链式组合的方式来适用各种情况。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570577768-490722b2-d1ab-45ca-8a02-800815106712.png)

### 4.1 (强制)跳转 HTTPS
同样比如上面我们定义的 whoami 这个应用，我们可以通过 `<font style="color:#DF2A3F;">https://who.qikqiak.com/tls</font>` 来访问到应用，但是如果我们用 `<font style="color:#DF2A3F;">http</font>` 来访问的话呢就不行了，就会 404 了，因为我们根本就没有简单 80 端口这个入口点，所以要想通过 `<font style="color:#DF2A3F;">http</font>` 来访问应用的话自然我们需要监听下 `<font style="color:#DF2A3F;">web</font>` 这个入口点：

```yaml
# ingressroutetls-http.yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: ingressroutetls-http
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`who.qikqiak.com`) && PathPrefix(`/tls`)
      kind: Rule
      services:
        - name: whoami
          port: 80
```

```shell
$ kubectl create -f ingressroutetls-http.yaml
ingressroute.traefik.containo.us/ingressroutetls-http created
```

浏览器可以直接访问成功`HTTP`：

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761707849945-890ca4be-5bfe-4ca7-8515-c5e6503fdf86.png)

注意这里我们创建的 IngressRoute 的 entryPoints 是 `<font style="color:#DF2A3F;">web</font>`，然后创建这个对象，这个时候我们就可以通过 HTTP 访问到这个应用了。

但是我们如果只希望用户通过 HTTPS 来访问应用的话呢？按照以前的知识，我们是不是可以让 HTTP 强制跳转到 HTTPS 服务去，对的，**<u><font style="color:#DF2A3F;">在 Traefik 中也是可以配置强制跳转的，只是这个功能现在是通过中间件来提供的了。</font></u>**如下所示，我们使用 `<font style="color:#DF2A3F;">redirectScheme</font>` 中间件来创建提供强制跳转服务：

```yaml
# Middleware-redirect-https.yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: redirect-https
spec:
  redirectScheme:
    scheme: https
```

```shell
$ kubectl create -f Middleware-redirect-https.yaml 
middleware.traefik.containo.us/redirect-https created
```

然后将这个中间件附加到 HTTP 的服务上面去，因为 HTTPS 的不需要跳转：

```yaml
# ingressroutetls-http.yaml
---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: ingressroutetls-http
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`who.qikqiak.com`) && PathPrefix(`/tls`)
      kind: Rule
      services:
        - name: whoami
          port: 80
      middlewares:
        - name: redirect-https
```

```shell
$ kubectl create -f ingressroutetls-http.yaml
ingressroute.traefik.containo.us/ingressroutetls-http created
```

这个时候我们再去访问 HTTP 服务可以发现就会自动跳转到 HTTPS 去了。

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761707908121-78e4a370-f587-4c02-810c-e8f8ca9de835.png)

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761707923291-60720cfd-bea3-4468-840d-db7155c89d49.png)

可以查看到 Traefik Dashboard 中的路由情况！

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761708049813-84ff091d-2d6e-4c19-a825-067e0e0ffab9.png)

### 4.2 URL Rewrite
接着我们再介绍如何使用 Traefik 来实现 URL Rewrite 操作，比如我们现部署一个 Nexus 应用，通过 IngressRoute 来暴露服务，对应的资源清单如下所示：

```yaml
# nexus.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nexus
  labels:
    app: nexus
spec:
  selector:
    matchLabels:
      app: nexus
  template:
    metadata:
      labels:
        app: nexus
    spec:
      containers:
        - image: cnych/nexus:3.20.1
          imagePullPolicy: IfNotPresent
          name: nexus
          ports:
            - containerPort: 8081
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: nexus
  name: nexus
spec:
  ports:
    - name: nexusport
      port: 8081
      targetPort: 8081
  selector:
    app: nexus
---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: nexus
  namespace: kube-system # 和Service不在同一个命名空间
spec:
  entryPoints:
    - web
  routes:
    - kind: Rule
      match: Host(`nexus.qikqiak.com`)
      services: # 指定跨命名空间的 nexus 服务
        - kind: Service
          name: nexus
          namespace: default
          port: 8081
```

由于我们开启了 Traefik 的跨命名空间功能（参数 `<font style="color:#DF2A3F;">--providers.kubernetescrd.allowCrossNamespace=true</font>`），所以可以引用其他命名空间中的 Service 或者中间件，直接部署上面的应用即可:

```shell
# 引用资源清单文件
➜ kubectl create -f nexus.yaml
deployment.apps/nexus created
service/nexus created
ingressroute.traefik.containo.us/nexus created

➜ kubectl get ingressroute -n kube-system nexus
NAME    AGE
nexus   40s

# 查看 Pod 的状态
➜ kubectl get pods -l app=nexus
NAME                     READY   STATUS    RESTARTS   AGE
nexus-6f78b79d4c-8xns6   1/1     Running   0          3m35s

➜ kubectl get service -l app=nexus
NAME    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
nexus   ClusterIP   192.96.91.205   <none>        8081/TCP   100s
```

部署完成后，我们根据 `<font style="color:#DF2A3F;">IngressRoute</font>` 对象中的配置，只需要将域名 `<font style="color:#DF2A3F;">nexus.qikqiak.com</font>` 解析到 Traefik 的节点即可访问：

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761708465891-31ca69a1-355c-40df-a007-d238e38ac8c4.png)

到这里我们都可以很简单的来完成，同样的现在我们有一个需求是目前我们只有一个域名可以使用，但是我们有很多不同的应用需要暴露，这个时候我们就只能通过 PATH 路径来进行区分了，比如**<u>我们现在希望当我们访问 </u>**`**<u><font style="color:#DF2A3F;">http:/nexus.qikqiak.com/foo</font></u>**`**<u> 的时候就是访问的我们的 Nexus 这个应用</u>**，当路径是 `<font style="color:#DF2A3F;">/bar</font>` 开头的时候是其他应用，这种需求是很正常的，这个时候我们就需要来做 URL Rewrite 了。

首先我们使用 [StripPrefix](https://www.qikqiak.com/traefik-book/middlewares/stripprefix/) 这个中间件，这个中间件的功能是**在转发请求之前从路径中删除前缀**，在使用中间件的时候我们只需要理解中间件操作的都是我们直接的请求即可，并不是真实的应用接收到请求过后来进行修改。

现在我们添加一个如下的中间件：

```yaml
# Middleware-strip-foo-path.yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: strip-foo-path
  namespace: default # 注意这里的中间件我们定义在default命名空间下面的
spec:
  stripPrefix:
    prefixes:
      - /foo
```

```shell
# 引用资源清单文件
$ kubectl create -f Middleware-strip-foo-path.yaml 
middleware.traefik.containo.us/strip-foo-path created
```

然后现在我们就需要从 `<font style="color:#DF2A3F;">http:/nexus.qikqiak.com/foo</font>` 请求中去匹配 `<font style="color:#DF2A3F;">/foo</font>` 的请求，把这个路径下面的请求应用到上面的中间件中去，因为最终我们的 Nexus 应用接收到的请求是不会带有 `<font style="color:#DF2A3F;">/foo</font>` 路径的，所以我们需要在请求到达应用之前将这个前缀删除，更新 IngressRoute 对象：

```yaml
# IngressRoute-nexus.yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: nexus
  namespace: kube-system
spec:
  entryPoints:
    - web
  routes:
    - kind: Rule
      match: Host(`nexus.qikqiak.com`) && PathPrefix(`/foo`) # 匹配 /foo 路径
      middlewares:
        - name: strip-foo-path
          namespace: default # 由于我们开启了traefik的跨命名空间功能，所以可以引用其他命名空间中的中间件
      services:
        - kind: Service
          name: nexus
          namespace: default
          port: 8081
```

```shell
# 引用资源清单文件
$ kubectl apply -f IngressRoute-nexus.yaml
Warning: resource ingressroutes/nexus is missing the kubectl.kubernetes.io/last-applied-configuration annotation which is required by kubectl apply. kubectl apply should only be used on resources created declaratively by either kubectl create --save-config or kubectl apply. The missing annotation will be patched automatically.
ingressroute.traefik.containo.us/nexus configured
```

创建中间件更新完成上面的 IngressRoute 对象后，这个时候我们前往浏览器中访问 `<font style="color:#DF2A3F;">http:/nexus.qikqiak.com/foo</font>`，这个时候发现我们的页面任何样式都没有了：

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761708987993-332d07f9-4f4b-49a9-9175-81c525e72efc.png)

开启 F12 开发者管理台再次访问！

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761709048936-1640f90f-2341-45b9-b636-557e2b29d820.png)

我们通过 Chrome 浏览器的 Network 可以查看到 `<font style="color:#DF2A3F;">/foo</font>`<font style="color:#DF2A3F;"> </font>路径的请求是 200 状态码，但是其他的静态资源对象确全都是 404 了，这是为什么呢？我们仔细观察上面我们的 IngressRoute 资源对象，我们现在是不是只匹配了 `<font style="color:#DF2A3F;">/foo</font>` 的请求，而我们的静态资源是 `<font style="color:#DF2A3F;">/static</font>`<font style="color:#DF2A3F;"> </font>路径开头的，当然就匹配不到了，所以就出现了 404，所以我们只需要加上这个 `<font style="color:#DF2A3F;">/static</font>` 路径的匹配就可以了，同样更新 IngressRoute 对象：

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: nexus
  namespace: kube-system
spec:
  entryPoints:
    - web
  routes:
    - kind: Rule
      match: Host(`nexus.qikqiak.com`) && PathPrefix(`/foo`)
      middlewares:
        - name: strip-foo-path
          namespace: default
      services:
        - kind: Service
          name: nexus
          namespace: default
          port: 8081
    - kind: Rule
      match: Host(`nexus.qikqiak.com`) && PathPrefix(`/static`) # 匹配 /static 的请求
      services:
        - kind: Service
          name: nexus
          namespace: default
          port: 8081
```

然后更新 IngressRoute 资源对象，这个时候再次去访问应用，可以发现页面样式已经正常了，也可以正常访问应用了：

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761709253931-fb4e6676-2923-4a74-86c7-301d998ccd08.png)

但进入应用后发现还是有错误提示信息，通过 Network 分析发现还有一些 `<font style="color:#DF2A3F;">/service</font>` 开头的请求是 404，当然我们再加上这个前缀的路径即可：

```yaml
# IngressRoute-nexus.yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: nexus
  namespace: kube-system
spec:
  entryPoints:
    - web
  routes:
    - kind: Rule
      match: Host(`nexus.qikqiak.com`) && PathPrefix(`/foo`)
      middlewares:
        - name: strip-foo-path
          namespace: default
      services:
        - kind: Service
          name: nexus
          namespace: default
          port: 8081
    # 需要正常访问的资源，则不需要进行 URL 重写
    - kind: Rule
      match: Host(`nexus.qikqiak.com`) && (PathPrefix(`/static`) || PathPrefix(`/service`)) # 匹配 /static 和 /service 的请求
      services:
        - kind: Service
          name: nexus
          namespace: default
          port: 8081
```

更新后，再次访问应用就已经完全正常了（全部资源都正常的加载 Loading 成功了！）：

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761709300281-53a721c4-4472-4002-a1c9-d21fdaa0d685.png)

Traefik 2.X 版本中的中间件功能非常强大，基本上官方提供的系列中间件可以满足我们大部分需求了，其他中间件的用法，可以参考文档：[https://www.qikqiak.com/traefik-book/middlewares/overview/](https://www.qikqiak.com/traefik-book/middlewares/overview/)。

## 5 Traefik Pilot [ 已不再支持 ]
### 5.1 Traefik Pilot 早期使用 Demo
虽然 Traefik 已经默认实现了很多中间件，可以满足大部分我们日常的需求，但是在实际工作中，用户仍然还是有自定义中间件的需求，这就 [Traefik Pilot](https://pilot.traefik.io/) 的功能了。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570578624-35d6f532-e8b5-4a6f-b8bd-7c7247cacd92.png)



Traefik Pilot 已经在 2022 年 10 月 4 日退出市场，不再支持了。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1732003692332-387a460a-2fce-4a23-89d9-9eb5334deb90.png)

Traefik Pilot 是一个 SaaS 平台，和 Traefik 进行链接来扩展其功能，它提供了很多功能，通过一个全局控制面板和 Dashboard 来增强对 Traefik 的观测和控制：

+ Traefik 代理和代理组的网络活动的指标
+ 服务健康问题和安全漏洞警报
+ 扩展 Traefik 功能的插件

在 Traefik 可以使用 `<font style="color:#DF2A3F;">Traefik Pilot</font>` 的功能之前，必须先连接它们，我们只需要对 Traefik 的静态配置进行少量更改即可。

Traefik 代理必须要能访问互联网才能连接到 `<font style="color:#DF2A3F;">Traefik Pilot</font>`，通过 HTTPS 在 443 端口上建立连接。

首先我们需要在 `<font style="color:#DF2A3F;">Traefik Pilot</font>` 主页上（[https://pilot.traefik.io/](https://pilot.traefik.io/)）创建一个帐户，注册新的 `<font style="color:#DF2A3F;">Traefik</font>` 实例并开始使用 `<font style="color:#DF2A3F;">Traefik</font> <font style="color:#DF2A3F;">Pilot</font>`。登录后，可以通过选择 `<font style="color:#DF2A3F;">Register New Traefik Instance</font>`来创建新实例。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570578981-224bca6e-af99-4620-9566-74ce13c9da06.png)

另外，当我们的 Traefik 尚未连接到 `<font style="color:#DF2A3F;">Traefik Pilot</font>` 时，Traefik Web UI 中将出现一个响铃图标，我们可以选择 `<font style="color:#DF2A3F;">Connect with Traefik Pilot</font>` 导航到 Traefik Pilot UI 进行操作。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570579747-f020a087-85af-4a69-8e73-491e3e8f0914.png)

登录完成后，`<font style="color:#DF2A3F;">Traefik Pilot</font>` 会生成一个新实例的令牌，我们需要将这个 Token 令牌添加到 Traefik 静态配置中。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570579918-378eaa7c-cf60-4376-b011-5778155b2a9c.png)

我们这里就是在 `<font style="color:#DF2A3F;">ci/deployment-prod.yaml</font>` 文件中启用 Pilot 的配置：

```yaml
# ci/deployment-prod.yaml
# Activate Pilot integration
pilot:
  enabled: true
  token: 'e079ea6e-536a-48c6-b3e3-f7cfaf94f477'
```

然后重新更新 Traefik：

```shell
➜ helm upgrade --install traefik \
  --namespace=kube-system ./traefik \
  -f ./traefik/ci/deployment-prod.yaml
```

更新完成后，我们在 Traefik 的 Web UI 中就可以看到 Traefik Pilot UI 相关的信息了。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570582012-04562745-0ca4-42f3-8b33-2bf1c0155774.png)

接下来我们就可以在 Traefik Pilot 的插件页面选择我们想要使用的插件，比如我们这里使用 [Demo Plugin](https://github.com/traefik/plugindemo) 这个插件。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570580661-2da5af54-23bf-40b3-afda-dfd4aa61f82d.png)

点击右上角的 `<font style="color:#DF2A3F;">Install Plugin</font>` 按钮安装插件会弹出一个对话框提示我们如何安装。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570581054-01fd9929-3ea2-4b67-b26e-304cec82bda4.png)

首先我们需要将当前 Traefik 注册到 Traefik Pilot（已完成），然后需要以静态配置的方式添加这个插件到 Traefik 中，这里我们同样更新 `<font style="color:#DF2A3F;">ci/deployment-prod.yaml</font>` 文件中的 Values 值即可：

```yaml
# ci/deployment-prod.yaml
# Activate Pilot integration
pilot:
  enabled: true
  token: 'e079ea6e-536a-48c6-b3e3-f7cfaf94f477'

additionalArguments:
  # 添加 demo plugin 的支持
  - --experimental.plugins.plugindemo.modulename=github.com/traefik/plugindemo
  - --experimental.plugins.plugindemo.version=v0.2.1
# 其他配置
```

同样重新更新 Traefik：

```shell
➜ helm upgrade --install traefik \
  --namespace=kube-system ./traefik \
  -f ./traefik/ci/deployment-prod.yaml
```

更新完成后创建一个如下所示的 Middleware 对象：

```yaml
➜ cat <<EOF | kubectl apply -f -
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: myplugin
spec:
  plugin:
    plugindemo:  # Traefik Pilot 插件名
      Headers:
        X-Demo: test
        Foo: bar
EOF
```

然后添加到上面的 whoami 应用的 IngressRoute 对象中去：

```yaml
# ingressroute-demo.yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: ingressroute-demo
  namespace: default
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`who.qikqiak.com`) && PathPrefix(`/notls`)
      kind: Rule
      services:
        - name: whoami # K8s Service
          port: 80
      middlewares:
        - name: myplugin # 使用上面新建的 middleware
```

更新完成后，当我们去访问 `<font style="color:#DF2A3F;">http://who.qikqiak.com/notls</font>` 的时候就可以看到新增了两个上面插件中定义的两个 Header。

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761724200548-b904a6b9-9c1a-4439-8c3e-3b01a0ebff46.png)

当然除了使用 Traefik Pilot 上开发者提供的插件之外，我们也可以根据自己的需求自行开发自己的插件，可以自行参考文档：[https://doc.traefik.io/traefik-pilot/plugins/plugin-dev/](https://doc.traefik.io/traefik-pilot/plugins/plugin-dev/)。

### 5.2 Traefik Pilot 小总结
:::success
<font style="color:rgb(0, 0, 0);">根据 Traefik 官方网站（</font>[https://pilot.traefik.io/](https://pilot.traefik.io/)<font style="color:rgb(0, 0, 0);">）2025年9月17日的最新公告，Traefik Pilot 自2022年10月4日起已不再提供任何服务。官方明确建议用户转向替代方案：</font>

+ <font style="color:rgb(0, 0, 0);">若需使用插件，可访问 Traefik Plugins（</font>[https://traefik-plugins.traefik.io/](https://traefik-plugins.traefik.io/) | [https://plugins.traefik.io/plugins](https://plugins.traefik.io/plugins)<font style="color:rgb(0, 0, 0);">）；</font>
+ <font style="color:rgb(0, 0, 0);">若需使用仪表盘，可访问 Traefik Hub（</font>[https://hub.traefik.io/](https://hub.traefik.io/)<font style="color:rgb(0, 0, 0);">）。</font>

<font style="color:rgb(0, 0, 0);">因此，Traefik Pilot 目前无法正常使用，任何尝试访问其服务的操作均会提示服务终止。</font>

:::

<details class="lake-collapse"><summary id="uaf58c99b"><span class="ne-text">尽管 Traefik Pilot 已停止服务，但结合其停止服务前（2020-2022年）的用户反馈及官方文档，其存在以下主要弊端：</span></summary><ol class="ne-ol"><li id="ue5e701db" data-lake-index-type="0"><strong><span class="ne-text">UI 交互不直观，学习成本较高</span></strong></li></ol><p id="ubc2e6514" class="ne-p"><span class="ne-text">早期用户反馈，Traefik Pilot 的仪表盘设计较为复杂，功能布局分散，新手需花费较多时间熟悉界面操作。例如，插件的安装、配置及监控功能未实现高度集成，导致用户需频繁切换页面完成操作。</span></p><ol start="2" class="ne-ol"><li id="ue6a23aa5" data-lake-index-type="0"><strong><span class="ne-text">指标数据延迟，实时性不足</span></strong></li></ol><p id="u624a9854" class="ne-p"><span class="ne-text">部分用户反映，Traefik Pilot 的监控指标（如请求 latency、错误率）存在一定延迟（约1-2分钟），无法满足对实时性要求较高的场景（如线上故障排查）。这一问题主要源于其数据收集与处理架构的优化不足。</span></p><ol start="3" class="ne-ol"><li id="uc7d2bda1" data-lake-index-type="0"><strong><span class="ne-text">插件生态不完善，兼容性问题</span></strong></li></ol><p id="uf883861b" class="ne-p"><span class="ne-text">Traefik Pilot 的插件市场虽提供了部分开源插件，但数量较少且功能覆盖有限（如缺乏针对特定业务场景的自定义插件）。此外，部分插件与 Traefik 核心版本的兼容性存在问题（如 v2.3 与 v2.4 版本的插件适配问题），导致用户需手动调整插件代码以确保正常运行。</span></p><ol start="4" class="ne-ol"><li id="u19c31ce0" data-lake-index-type="0"><strong><span class="ne-text">报警功能单一，灵活性不足</span></strong></li></ol><p id="u97e98a5b" class="ne-p"><span class="ne-text">Traefik Pilot 的报警功能仅支持 email 和 webhook 两种方式，且报警规则的配置较为简单（如仅能设置阈值触发，无法实现多条件组合报警）。这一缺陷导致用户无法根据复杂场景（如多指标联动、动态阈值）定制报警策略。</span></p></details>
<details class="lake-collapse"><summary id="uac7b38a1"><span class="ne-text">Traefik 官方推荐以下替代方案，以替代 Traefik Pilot 的核心功能：</span></summary><ol class="ne-ol"><li id="u859c18a5" data-lake-index-type="0"><strong><span class="ne-text">Traefik Plugins（</span></strong><code class="ne-code"><a href="https://traefik-plugins.traefik.io/" data-href="https://traefik-plugins.traefik.io/" target="_blank" class="ne-link"><strong><span class="ne-text">https://traefik-plugins.traefik.io/</span></strong></a><strong><span class="ne-text"> | </span></strong><a href="https://plugins.traefik.io/plugins" data-href="https://plugins.traefik.io/plugins" target="_blank" class="ne-link"><strong><span class="ne-text">https://plugins.traefik.io/plugins</span></strong></a></code><strong><span class="ne-text">）</span></strong></li></ol><div data-type="success" class="ne-alert"><p id="u9445ede3" class="ne-p"><span class="ne-text">Traefik Plugins 是 Traefik 官方推出的插件管理平台，提供更丰富的插件生态（涵盖流量整形、安全防护、日志分析等场景），且支持插件的在线搜索、安装及版本管理。与 Traefik Pilot 相比，其插件兼容性更优（适配 Traefik 最新版本），且界面设计更简洁。</span></p><p id="u50a2f79d" class="ne-p"><img src="https://cdn.nlark.com/yuque/0/2025/png/2555283/1761710153128-cbe4524d-b056-49e5-95fc-abf41f6543a2.png" width="1779" id="u3783aadf" class="ne-image"></p></div><ol start="2" class="ne-ol"><li id="u997478d9" data-lake-index-type="0"><strong><span class="ne-text">Traefik Hub（</span></strong><code class="ne-code"><a href="https://hub.traefik.io/" data-href="https://hub.traefik.io/" target="_blank" class="ne-link"><strong><span class="ne-text">https://hub.traefik.io/</span></strong></a></code><strong><span class="ne-text">）需要企业版（商用版） Traefik 才能正常使用！</span></strong></li></ol><div data-type="success" class="ne-alert"><p id="udadd4f7a" class="ne-p"><span class="ne-text">Traefik Hub 是 Traefik 官方的集中管理平台，提供仪表盘、服务发现、配置管理等功能，替代了 Traefik Pilot 的核心仪表盘功能。其优势在于：</span></p><ul class="ne-ul"><li id="u0ff6d9ca" data-lake-index-type="0"><strong><span class="ne-text">实时性</span></strong><span class="ne-text">：监控指标延迟降低至30秒内；</span></li><li id="uaf459d47" data-lake-index-type="0"><strong><span class="ne-text">灵活性</span></strong><span class="ne-text">：支持自定义仪表盘布局及多维度数据可视化；</span></li><li id="ufbf6a1a6" data-lake-index-type="0"><strong><span class="ne-text">集成性</span></strong><span class="ne-text">：可与 Traefik Enterprise（企业版）无缝集成，满足大规模生产环境需求。</span></li></ul></div></details>
## 6 Traefik 私有插件
上面我们介绍了可以使用 Traefik Pilot 来使用插件，但是这是一个 SaaS 服务平台，对于大部分企业场景下面不是很适用，我们更多的场景下需要在本地环境加载插件，为解决这个问题，在 Traefik v2.5 版本后，就提供了一种直接从本地存储目录加载插件的新方法，不需要启用 Traefik Pilot，只需要将插件源码放入一个名为 `<font style="color:#DF2A3F;">/plugins-local</font>` 的新目录，相对于当前工作目录去创建这个目录，比如我们直接使用的是 traefik 的 Docker 镜像，则入口点则是根目录<font style="color:#DF2A3F;"> </font>`<font style="color:#DF2A3F;">/</font>`，Traefik 本身会去构建你的插件，所以我们要做的就是编写源代码，并把它放在正确的目录下，让 Traefik 来加载它即可。

需要注意的是由于在每次启动的时候插件只加载一次，所以如果我们希望重新加载你的插件源码的时候需要重新启动 Traefik。

下面我们使用一个简单的自定义插件示例来说明如何使用私有插件。首先我们定义一个名为 `<font style="color:#DF2A3F;">Dockerfile.demo</font>` 的 Dockerfile 文件，先从 git 仓库中克隆插件源码，然后以 `<font style="color:#DF2A3F;">traefik:v2.9.9</font>` 为基础镜像，将插件源码拷贝到 `<font style="color:#DF2A3F;">/plugins-local</font>` 目录，如下所示：

```dockerfile
FROM alpine:3
ARG PLUGIN_MODULE=github.com/traefik/plugindemo
ARG PLUGIN_GIT_REPO=https://github.com/traefik/plugindemo.git
ARG PLUGIN_GIT_BRANCH=master
RUN apk add --update git && \
    git clone ${PLUGIN_GIT_REPO} /plugins-local/src/${PLUGIN_MODULE} \
      --depth 1 --single-branch --branch ${PLUGIN_GIT_BRANCH}

FROM traefik:v2.9.9
COPY --from=0 /plugins-local /plugins-local
```

我们这里使用的演示插件和上面 Pilot 中演示的是同一个插件，我们可以通过该插件去自定义请求头信息。

然后在 `<font style="color:#DF2A3F;">Dockerfile.demo</font>` 目录下面，构建镜像：

```shell
➜ docker build -f Dockerfile.demo -t dragonz/traefik-private-demo-plugin:v2.9.9 .
# 查看构建的镜像
➜ docker images dragonzw/traefik-private-demo-plugin:v2.9.9
REPOSITORY                             TAG       IMAGE ID       CREATED       SIZE
dragonzw/traefik-private-demo-plugin   v2.9.9    1012f52b56ff   4 hours ago   138MB

# 推送到镜像仓库
➜ docker push dragonzw/traefik-private-demo-plugin:v2.9.9
```

镜像构建完成后就可以使用这个镜像来测试 demo 插件了，同样我们这里直接去覆盖的 Values 文件，更新 `<font style="color:#DF2A3F;">ci/deployment-prod.yaml</font>` 文件中的 Values 值，将镜像修改成上面我们自定义的镜像地址：

```yaml
# ci/deployment-prod.yaml
image:
  name: dragonzw/traefik-private-demo-plugin
  tag: v2.9.9

# 其他省略

# 不需要开启 pilot 了
pilot:
  enabled: false

additionalArguments:
  # 添加 demo plugin 的本地支持
  - --experimental.localPlugins.plugindemo.moduleName=github.com/traefik/plugindemo
# 其他省略
```

注意上面我们添加 Traefik 的启动参数的时候使用的 `<font style="color:#DF2A3F;">--experimental.localPlugins</font>`。然后重新更新 Traefik：

```shell
➜ helm upgrade --install traefik ./traefik \
  -f ./traefik/ci/deployment-prod.yaml \
  --namespace kube-system
```

更新完成后就可以使用我们的私有插件来创建一个 Middleware 对象了：

```yaml
➜ cat <<EOF | kubectl apply -f -
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: my-private-plugin
spec:
  plugin:
    plugindemo:  # 插件名
      Headers:
        X-Demo: private-demo
        Foo: bar
EOF
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761724039456-e8e1df37-bbb5-42dd-84c9-3c3c15697e9c.png)

然后添加到上面的 whoami 应用的 IngressRoute 对象中去：

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: ingressroute-demo
  namespace: default
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`who.qikqiak.com`) && PathPrefix(`/notls`)
      kind: Rule
      services:
        - name: whoami # K8s Service
          port: 80
      middlewares:
        - name: my-private-plugin # 使用上面新建的 middleware
```

```shell
$ kubectl apply -f ingressroute-demo.yaml
Warning: resource ingressroutes/ingressroute-demo is missing the kubectl.kubernetes.io/last-applied-configuration annotation which is required by kubectl apply. kubectl apply should only be used on resources created declaratively by either kubectl create --save-config or kubectl apply. The missing annotation will be patched automatically.
ingressroute.traefik.containo.us/ingressroute-demo configured
```

更新上面的资源对象后，我们再去访问 `<font style="color:#DF2A3F;">http://who.qikqiak.com/notls</font>` 就可以看到新增了两个上面插件中定义的两个 Header，证明我们的私有插件配置成功了：

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761724194260-4aa528ad-a113-4dd2-918a-b4ba7a5286e2.png)

## 7 灰度发布
Traefik V2.0+ 的一个更强大的功能就是灰度发布，灰度发布我们有时候也会称为金丝雀发布（Canary），主要就是让一部分测试的服务也参与到线上去，经过测试观察看是否符号上线要求。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570582372-e540ca32-c18f-46a4-af7f-5b4790d17856.png)

比如现在我们有两个名为 `<font style="color:#DF2A3F;">appv1</font>` 和 `<font style="color:#DF2A3F;">appv2</font>` 的服务，我们希望通过 Traefik 来控制我们的流量，将 3⁄4 的流量路由到 appv1，1/4 的流量路由到 appv2 去，这个时候就可以利用 Traefik 2.0 中提供的**带权重的轮询（WRR）**来实现该功能，首先在 Kubernetes 集群中部署上面的两个服务。为了对比结果我们这里<u><font style="color:#DF2A3F;">提供的两个服务一个是 whoami，一个是 nginx，方便测试。</font></u>

appv1 服务的资源清单如下所示：

```yaml
# appv1.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: appv1
spec:
  selector:
    matchLabels:
      app: appv1
  template:
    metadata:
      labels:
        use: test
        app: appv1
    spec:
      containers:
        - name: whoami
          image: containous/whoami
          ports:
            - containerPort: 80
              name: portv1
---
apiVersion: v1
kind: Service
metadata:
  name: appv1
spec:
  selector:
    app: appv1
  ports:
    - name: http
      port: 80
      targetPort: portv1
```

appv2 服务的资源清单如下所示：

```yaml
# appv2.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: appv2
spec:
  selector:
    matchLabels:
      app: appv2
  template:
    metadata:
      labels:
        use: test
        app: appv2
    spec:
      containers:
        - name: nginx
          image: nginx
          ports:
            - containerPort: 80
              name: portv2
---
apiVersion: v1
kind: Service
metadata:
  name: appv2
spec:
  selector:
    app: appv2
  ports:
    - name: http
      port: 80
      targetPort: portv2
```

直接创建上面两个服务：

```shell
➜ kubectl apply -f appv1.yaml -f appv2.yaml
deployment.apps/appv1 created
service/appv1 created
deployment.apps/appv2 created
service/appv2 created

# 通过下面的命令可以查看服务是否运行成功
➜ kubectl get pods -l use=test
NAME                     READY   STATUS    RESTARTS   AGE
appv1-57fc87699f-2v29g   1/1     Running   0          55s
appv2-5cb6699ffc-w7vv8   1/1     Running   0          55s
➜ kubectl get pods -l use=test -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image
NAME                     IMAGE
appv1-57fc87699f-2v29g   containous/whoami
appv2-5cb6699ffc-w7vv8   nginx
```

在 Traefik 2.1 中新增了一个 `<font style="color:#DF2A3F;">TraefikService</font>` 的 CRD 资源，我们可以直接利用这个对象来配置 WRR，之前的版本需要通过 File Provider，比较麻烦，新建一个描述 WRR 的资源清单：

```yaml
# wrr.yaml
apiVersion: traefik.containo.us/v1alpha1
kind: TraefikService
metadata:
  name: app-wrr
spec:
  weighted:
    services:
      - name: appv1
        weight: 3 # 定义权重
        port: 80
        kind: Service # 可选，默认就是 Service
      - name: appv2
        weight: 1
        port: 80
```

然后为我们的灰度发布的服务创建一个 IngressRoute 资源对象：

```yaml
# wrr-ingressroute.yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: wrr-ingressroute
  namespace: default
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`wrr.qikqiak.com`)
      kind: Rule
      services:
        - name: app-wrr
          kind: TraefikService
```

引用资源清单文件

```shell
➜ kubectl create -f wrr.yaml -f wrr-ingressroute.yaml 
traefikservice.traefik.containo.us/app-wrr created
ingressroute.traefik.containo.us/wrr-ingressroute created
```

不过需要注意的是现在我们配置的 Service 不再是直接的 Kubernetes 对象了，而是上面我们定义的 TraefikService 对象，直接创建上面的两个资源对象，这个时候我们对域名 `<font style="color:#DF2A3F;">wrr.qikqiak.com</font>` 做上解析，去浏览器中连续访问 4 次，我们可以观察到 appv1 这应用会收到 3 次请求，而 appv2 这个应用只收到 1 次请求，符合上面我们的 `<font style="color:#DF2A3F;">3:1</font>`<font style="color:#DF2A3F;"> </font>的权重配置。

:::success
🌀但是基于权重的流量分配是主要按较大的比例范围内大致符合 `<font style="color:#DF2A3F;">3:1</font>` 的权重配置。

:::

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761725245857-edaefcb0-476b-4a1a-9065-7b764444ec22.png)

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570582562-ef1b8155-d620-495f-86b1-48b943cbd586.png)

:::success
⚠️ Traefik 在灰度发布的场景要比 Ingress-Nginx 要弱一点。Traefik 2.3 目前只支持权重的灰度方式。而 Ingress-Nginx 是支持权重 Weight，Header 以及 Cookie 的方式（Header > Cookie > Weight）。

:::

## 8 流量复制
除了灰度发布之外，Traefik 2.0 还引入了流量镜像服务，是一种可以将流入流量复制并同时将其发送给其他服务的方法，镜像服务可以获得给定百分比的请求同时也会忽略这部分请求的响应。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570582946-d6caa90d-6cc9-4a0f-b932-81dc00981b50.png)

现在我们部署两个 whoami 的服务，资源清单文件如下所示：

```yaml
# whoami-nginx-v1-v2.yaml
apiVersion: v1
kind: Service
metadata:
  name: v1
spec:
  ports:
    - protocol: TCP
      name: web
      port: 80
  selector:
    app: v1
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: v1
  labels:
    app: v1
spec:
  selector:
    matchLabels:
      app: v1
  template:
    metadata:
      labels:
        app: v1
    spec:
      containers:
        - name: v1
          image: nginx
          ports:
            - name: web
              containerPort: 80

---
apiVersion: v1
kind: Service
metadata:
  name: v2
spec:
  ports:
    - protocol: TCP
      name: web
      port: 80
  selector:
    app: v2
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: v2
  labels:
    app: v2
spec:
  selector:
    matchLabels:
      app: v2
  template:
    metadata:
      labels:
        app: v2
    spec:
      containers:
        - name: v2
          image: nginx
          ports:
            - name: web
              containerPort: 80
```

直接创建上面的资源对象：

```shell
➜ kubectl create -f whoami-nginx-v1-v2.yaml
service/v1 created
deployment.apps/v1 created
service/v2 created
deployment.apps/v2 created

# 查看对应的 Pods 和 Services 的信息
➜ kubectl get pods -l 'app in (v1,v2)' -o wide 
NAME                 READY   STATUS    RESTARTS   AGE    IP               NODE           NOMINATED NODE   READINESS GATES
v1-794f575b8-x6pjf   1/1     Running   0          118s   192.244.51.232   hkk8snode002   <none>           <none>
v2-666574774-s94rs   1/1     Running   0          118s   192.244.51.222   hkk8snode002   <none>           <none>

➜ kubectl get service v1 v2
NAME   TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
v1     ClusterIP   192.96.230.152   <none>        80/TCP    2m35s
v2     ClusterIP   192.96.251.223   <none>        80/TCP    2m35s
```

现在我们创建一个 IngressRoute 对象，将服务 v1 的流量复制 50% 到服务 v2，如下资源对象所示：

```yaml
# mirror-ingress-route.yaml
apiVersion: traefik.containo.us/v1alpha1
kind: TraefikService
metadata:
  name: app-mirror
spec:
  mirroring:
    name: v1 # 发送 100% 的请求到 K8S 的 Service "v1"
    port: 80
    mirrors:
      - name: v2 # 然后复制 50% 的请求到 v2
        percent: 50
        port: 80
---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: mirror-ingress-route
  namespace: default
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`mirror.qikqiak.com`)
      kind: Rule
      services:
        - name: app-mirror
          kind: TraefikService # 使用声明的 TraefikService 服务，而不是 K8S 的 Service
```

然后直接创建这个资源对象即可：

```shell
➜ kubectl apply -f mirror-ingress-route.yaml
traefikservice.traefik.containo.us/app-mirror created
ingressroute.traefik.containo.us/mirror-ingress-route created

# 查看创建的信息
➜ kubectl get traefikservice
NAME         AGE
app-mirror   2m25s
➜ kubectl get ingressroute mirror-ingress-route
NAME                   AGE
mirror-ingress-route   2m50s
```

Traefik Dashboard 查看路由信息

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761725753058-872040dd-b03c-4285-91c6-4a1b42e3d884.png)

这个时候我们在浏览器中去连续访问 4 次 `<font style="color:#DF2A3F;">mirror.qikqiak.com</font>`<font style="color:#DF2A3F;"> </font>可以发现有一半的请求也出现在了 `<font style="color:#DF2A3F;">v2</font>` 这个服务中： 

```shell
➜ for i in {1..4}; do echo "=== 请求 $i ==="; curl mirror.qikqiak.com; echo ""; done

➜ kubectl get pods -l 'app in (v1,v2)' -o wide 
NAME                 READY   STATUS    RESTARTS   AGE     IP               NODE           NOMINATED NODE   READINESS GATES
v1-794f575b8-x6pjf   1/1     Running   0          7m40s   192.244.51.232   hkk8snode002   <none>           <none>
v2-666574774-s94rs   1/1     Running   0          7m40s   192.244.51.222   hkk8snode002   <none>           <none>

# 查看 Pods 的日志情况
➜ kubectl logs v1-794f575b8-x6pjf --tail 4 
192.244.22.254 - - [29/Oct/2025:08:16:51 +0000] "GET / HTTP/1.1" 200 615 "-" "curl/7.61.1" "192.168.178.35"
192.244.22.254 - - [29/Oct/2025:08:16:51 +0000] "GET / HTTP/1.1" 200 615 "-" "curl/7.61.1" "192.168.178.35"
192.244.22.254 - - [29/Oct/2025:08:16:51 +0000] "GET / HTTP/1.1" 200 615 "-" "curl/7.61.1" "192.168.178.35"
192.244.22.254 - - [29/Oct/2025:08:16:51 +0000] "GET / HTTP/1.1" 200 615 "-" "curl/7.61.1" "192.168.178.35"

➜ kubectl logs v2-666574774-s94rs --tail 2
192.244.22.254 - - [29/Oct/2025:08:16:51 +0000] "GET / HTTP/1.1" 200 615 "-" "curl/7.61.1" "192.168.178.35"
192.244.22.254 - - [29/Oct/2025:08:16:51 +0000] "GET / HTTP/1.1" 200 615 "-" "curl/7.61.1" "192.168.178.35"
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761726287731-42cd04ab-f5b7-41aa-a058-a445e1ce9d14.png)

## 9 TCP
另外 Traefik 2.X 已经支持了 TCP 服务的（TCP 服务的支持 Ingress-Nginx 没有像 Traefik 配置方便），下面我们以 mongo 为例来了解下 Traefik 是如何支持 TCP 服务得。

### 9.1 简单 TCP 服务
首先部署一个普通的 mongo 服务，资源清单文件如下所示：（`<font style="color:#DF2A3F;">mongo.yaml</font>`）

```yaml
# mongo.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongo-traefik
  labels:
    app: mongo-traefik
spec:
  selector:
    matchLabels:
      app: mongo-traefik
  template:
    metadata:
      labels:
        app: mongo-traefik
    spec:
      containers:
        - name: mongo
          image: mongo:4.0
          ports:
            - containerPort: 27017
---
apiVersion: v1
kind: Service
metadata:
  name: mongo-traefik
spec:
  selector:
    app: mongo-traefik
  ports:
    - port: 27017
```

直接创建 mongo 应用：

```shell
➜ kubectl apply -f mongo.yaml
deployment.apps/mongo-traefik created
service/mongo-traefik created

# 查看 MongoDB 的信息
➜ kubectl get pod -l app=mongo-traefik
NAME                             READY   STATUS    RESTARTS   AGE
mongo-traefik-67c4748db8-kbsz4   1/1     Running   0          55s

➜ kubectl get service mongo-traefik
NAME            TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)     AGE
mongo-traefik   ClusterIP   192.96.162.100   <none>        27017/TCP   80s

➜ kubectl exec -it -n default mongo-traefik-67c4748db8-kbsz4 -- mongo --eval "db.version()"
MongoDB shell version v4.0.28
connecting to: mongodb://127.0.0.1:27017/?gssapiServiceName=mongodb
Implicit session: session { "id" : UUID("7f921122-e8b4-46b1-8b52-10aa7fd5e493") }
MongoDB server version: 4.0.28
4.0.28
```

创建成功后就可以来为 mongo 服务配置一个路由了。由于 Traefik 中使用 TCP 路由配置需要 `<font style="color:#DF2A3F;">SNI</font>`，而 `<font style="color:#DF2A3F;">SNI</font>` 又是依赖 `<font style="color:#DF2A3F;">TLS</font>` 的，所以我们需要配置证书才行，如果没有证书的话，我们可以使用通配符 `<font style="color:#DF2A3F;">*</font>` 进行配置，我们这里创建一个 `<font style="color:#DF2A3F;">IngressRouteTCP</font>` 类型的 CRD 对象（前面我们就已经安装了对应的 CRD 资源）：

```yaml
# mongo-ingressroute-tcp.yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRouteTCP
metadata:
  name: mongo-traefik-tcp
spec:
  entryPoints:
    - mongo
  routes:
    - match: HostSNI(`*`)
      services:
        - name: mongo-traefik
          port: 27017
```

```shell
# 引用资源清单文件
➜ kubectl create -f mongo-ingressroute-tcp.yaml 
ingressroutetcp.traefik.containo.us/mongo-traefik-tcp created

➜ kubectl get ingressroutetcp 
NAME                AGE
mongo-traefik-tcp   20s
```

要注意的是这里的 `<font style="color:#DF2A3F;">entryPoints</font>` 部分，是根据我们启动的 Traefik 的静态配置中的 entryPoints 来决定的，我们当然可以使用前面我们定义得 80 和 443 这两个入口点，但是也可以可以自己添加一个用于 mongo 服务的专门入口点，更新 `<font style="color:#DF2A3F;">values-prod.yaml</font>` 文件，新增 mongo 这个入口点：

```yaml
# values-prod.yaml
ports:
  web:
    port: 8000
    hostPort: 80
    
  websecure:
    port: 8443
    hostPort: 443
  
  mongo:
    port: 27017
    hostPort: 27017
    protocol: TCP
```

然后更新 Traefik 即可：

```shell
➜ helm upgrade --install traefik ./traefik \
  -f ./traefik/ci/deployment-prod.yaml \
  --namespace kube-system
false
Release "traefik" has been upgraded. Happy Helming!
NAME: traefik
LAST DEPLOYED: Wed Oct 29 16:36:03 2025
NAMESPACE: kube-system
STATUS: deployed
REVISION: 6
TEST SUITE: None
NOTES:
Traefik Proxy v2.9.9 has been deployed successfully
on kube-system namespace !

➜ kubectl describe pod -n kube-system $(kubectl get pod -n kube-system -l app.kubernetes.io/name=traefik -o name | awk -F'/' '{print $2}') 
[......]
Containers:
  traefik:
    Container ID:  containerd://7c365b565a12ebc627f1ff7c4dabad705da30dc09904d8c747d3df058b016a1f
    Image:         traefik:v2.9.9
    Image ID:      docker.io/library/traefik@sha256:7607abfb04839f13026b6f0698ab16cdeb8a66aa02045f3fde45dc71df5d2c59
    Ports:         9100/TCP, 27017/TCP, 9000/TCP, 8000/TCP, 8443/TCP
    Host Ports:    0/TCP, 27017/TCP, 0/TCP, 80/TCP, 443/TCP
    Args:
      --global.checknewversion
      --global.sendanonymoususage
      --entrypoints.metrics.address=:9100/tcp
      --entrypoints.mongo.address=:27017/tcp
      --entrypoints.traefik.address=:9000/tcp
      --entrypoints.web.address=:8000/tcp
      --entrypoints.websecure.address=:8443/tcp
      --api.dashboard=true
      --ping=true
      --metrics.prometheus=true
      --metrics.prometheus.entrypoint=metrics
      --providers.kubernetescrd
      --providers.kubernetesingress
      --entrypoints.websecure.http.tls=true
      --log.level=DEBUG
[......]

# 查看 Iptables 规则
➜ iptables -t nat -L | grep 27017
KUBE-SVC-OODSRQKH2JGK545L  tcp  --  anywhere             192.96.162.100       /* default/mongo-traefik cluster IP */ tcp dpt:27017
KUBE-SVC-IZQ7KAFJDD2KWY4O  tcp  --  anywhere             192.96.58.231        /* default/mongo cluster IP */ tcp dpt:27017
CNI-DN-ef4fc125381c4fa682a00  tcp  --  anywhere             anywhere             /* dnat name: "k8s-pod-network" id: "50a94397f8b7829adc7191a806a8679aeb5d459c8d375074bbc609a3bddc5212" */ multiport dports bacula-dir,27017,http,https
KUBE-MARK-MASQ  tcp  -- !192.244.0.0/16       192.96.58.231        /* default/mongo cluster IP */ tcp dpt:27017
KUBE-SEP-HLOBVEWELK4IPJ26  all  --  anywhere             anywhere             /* default/mongo -> 192.244.51.254:27017 */
DNAT       tcp  --  anywhere             anywhere             /* default/mongo */ tcp to:192.244.51.254:27017
KUBE-MARK-MASQ  tcp  -- !192.244.0.0/16       192.96.162.100       /* default/mongo-traefik cluster IP */ tcp dpt:27017
KUBE-SEP-OUL3N25EPOM7JDN4  all  --  anywhere             anywhere             /* default/mongo-traefik -> 192.244.211.6:27017 */
DNAT       tcp  --  anywhere             anywhere             /* default/mongo-traefik */ tcp to:192.244.211.6:27017
CNI-HOSTPORT-SETMARK  tcp  --  192.244.22.255       anywhere             tcp dpt:27017
CNI-HOSTPORT-SETMARK  tcp  --  localhost            anywhere             tcp dpt:27017
DNAT       tcp  --  anywhere             anywhere             tcp dpt:27017 to:192.244.22.255:27017
```

这里给入口点添加 `<font style="color:#DF2A3F;">hostPort</font>` 是为了能够通过节点的端口访问到服务，关于 entryPoints 入口点的更多信息，可以查看文档 [entrypoints](https://www.qikqiak.com/traefik-book/routing/entrypoints/) 了解更多信息。

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761727618027-b1194c9f-bdb3-4f4d-955f-102aaa13d67e.png)

然后更新 Traefik 后我们就可以直接创建上面的资源对象：

```shell
# 引用资源清单文件
➜ kubectl apply -f mongo-ingressroute-tcp.yaml
ingressroutetcp.traefik.containo.us/mongo-traefik-tcp configured
```

创建完成后，同样我们可以去 Traefik 的 Dashboard 页面上查看是否生效：

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761727583744-0eaf50ae-d4c9-4854-9ac5-b6d00dd39afa.png)

然后我们配置一个域名 `<font style="color:#DF2A3F;">mongo.local</font>` 解析到 Traefik 所在的节点，然后通过 27017 端口来连接 mongo 服务：

```shell
# 下载并安装 mongosh
$ sudo yum install -y https://downloads.mongodb.com/compass/mongodb-mongosh-2.1.1.x86_64.rpm
# 注意：MongoDB 5.0+ 版本已经将 mongo 命令替换为 mongosh，所以安装后使用 mongosh 命令即可。

# mongo.local Or traefik.qikqiak.com 本地 hosts 文件解析的定义
$ mongosh --host mongo.local --port 27017
Current Mongosh Log ID: 6902c916331744db41021174
Connecting to:          mongodb://mongo.local:27017/?directConnection=true&appName=mongosh+2.1.1
Using MongoDB:          4.0.28
Using Mongosh:          2.1.1
mongosh 2.5.8 is available for download: https://www.mongodb.com/try/download/shell

For mongosh info see: https://docs.mongodb.com/mongodb-shell/


To help improve our products, anonymous usage data is collected and sent to MongoDB periodically (https://www.mongodb.com/legal/privacy-policy).
You can opt-out by running the disableTelemetry() command.

------
   The server generated these startup warnings when booting
   2025-10-30T02:01:44.878+0000: 
   2025-10-30T02:01:44.878+0000: ** WARNING: Access control is not enabled for the database.
   2025-10-30T02:01:44.878+0000: **          Read and write access to data and configuration is unrestricted.
   2025-10-30T02:01:44.878+0000: 
   2025-10-30T02:01:44.879+0000: 
   2025-10-30T02:01:44.879+0000: ** WARNING: /sys/kernel/mm/transparent_hugepage/enabled is 'always'.
   2025-10-30T02:01:44.879+0000: **        We suggest setting it to 'never'
   2025-10-30T02:01:44.879+0000:
------

test> show dbs;
admin   32.00 KiB
config  12.00 KiB
local   32.00 KiB

########################################################################################
$ mongosh --host traefik.qikqiak.com --port 27017
Current Mongosh Log ID: 6902c96a0da4b5f7b09e73a7
Connecting to:          mongodb://traefik.qikqiak.com:27017/?directConnection=true&appName=mongosh+2.1.1
Using MongoDB:          4.0.28
Using Mongosh:          2.1.1
mongosh 2.5.8 is available for download: https://www.mongodb.com/try/download/shell

For mongosh info see: https://docs.mongodb.com/mongodb-shell/

------
   The server generated these startup warnings when booting
   2025-10-30T02:01:44.878+0000: 
   2025-10-30T02:01:44.878+0000: ** WARNING: Access control is not enabled for the database.
   2025-10-30T02:01:44.878+0000: **          Read and write access to data and configuration is unrestricted.
   2025-10-30T02:01:44.878+0000: 
   2025-10-30T02:01:44.879+0000: 
   2025-10-30T02:01:44.879+0000: ** WARNING: /sys/kernel/mm/transparent_hugepage/enabled is 'always'.
   2025-10-30T02:01:44.879+0000: **        We suggest setting it to 'never'
   2025-10-30T02:01:44.879+0000:
------

test> show dbs;
admin   32.00 KiB
config  48.00 KiB
local   32.00 KiB
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761790307784-469596a2-dc56-4b62-9f05-275b6ab82c90.png)

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761790330245-6ac48d3d-c864-42b1-9fae-6067e8f38ed2.png)

到这里我们就完成了将 mongo（TCP）服务暴露给外部用户了。

:::success
##### **<font style="color:rgb(0, 0, 0);">TCP Routers与HTTP Routers的routes有所不同：</font>**
+ <font style="color:rgb(51, 51, 51);">TCP Routers match 采用 HostSNI，而 HTTP Routers match 直接匹配 Host。</font>
+ <font style="color:rgb(51, 51, 51);">TCP Routers 只能定位 TCP 服务（不能定位HTTP服务）。</font>
+ <font style="color:rgb(51, 51, 51);">如果HTTP Routers 和 TCP Routers都侦听相同的入口点，则TCP Routers将在HTTP Routers之前应用。如果找不到与TCP Routers 匹配的</font><font style="color:rgb(0, 82, 217);">路由</font><font style="color:rgb(51, 51, 51);">，则HTTP Routers将接管。</font>

:::

### 9.2 带 TLS 证书的 TCP
上面我们部署的 mongo 是一个普通的服务，然后用 Traefik 代理的，但是有时候为了安全 mongo 服务本身还会使用 TLS 证书的形式提供服务，下面是用来生成 mongo TLS 证书的脚本文件：（`<font style="color:#DF2A3F;">generate-certificates.sh</font>`）

```shell
$ mkdir -p 01-mongo 02-tls-mongo certs
# 脚本存放在 certs 目录下
```

+ Old Version（GoLang 版本较旧）

```shell
#!/bin/bash
#
# From https://medium.com/@rajanmaharjan/secure-your-mongodb-connections-ssl-tls-92e2addb3c89

set -eu -o pipefail

DOMAINS="${1}"
CERTS_DIR="${2}"
[ -d "${CERTS_DIR}" ]
CURRENT_DIR="$(cd "$(dirname "${0}")" && pwd -P)"

GENERATION_DIRNAME="$(echo "${DOMAINS}" | cut -d, -f1)"

rm -rf "${CERTS_DIR}/${GENERATION_DIRNAME:?}" "${CERTS_DIR}/certs"

echo "== Checking Requirements..."
command -v go >/dev/null 2>&1 || echo "Golang is required"
command -v minica >/dev/null 2>&1 || go get github.com/jsha/minica >/dev/null

echo "== Generating Certificates for the following domains: ${DOMAINS}..."
cd "${CERTS_DIR}"
minica --ca-cert "${CURRENT_DIR}/minica.pem" --ca-key="${CURRENT_DIR}/minica-key.pem" --domains="${DOMAINS}"
mv "${GENERATION_DIRNAME}" "certs"
cat certs/key.pem certs/cert.pem > certs/mongo.pem

echo "== Certificates Generated in the directory ${CERTS_DIR}/certs"
```

+ New Version（GoLang 版本较新）

```shell
#!/bin/bash
# Golang 1.17.1版本的发布不再支持go get命令 
# From https://medium.com/@rajanmaharjan/secure-your-mongodb-connections-ssl-tls-92e2addb3c89
# GitHub https://github.com/jsha/minica

set -eu -o pipefail

DOMAINS="${1}"
CERTS_DIR="${2}"
[ -d "${CERTS_DIR}" ]
CURRENT_DIR="$(cd "$(dirname "${0}")" && pwd -P)"

GENERATION_DIRNAME="$(echo "${DOMAINS}" | cut -d, -f1)"

rm -rf "${CERTS_DIR}/${GENERATION_DIRNAME:?}" "${CERTS_DIR}/certs"

echo "== Checking Requirements..."
command -v go >/dev/null 2>&1 || echo "Golang is required"
command -v minica >/dev/null 2>&1 || go install github.com/jsha/minica@latest >/dev/null 

# 获取 Go bin 目录路径
GOBIN=$(go env GOPATH)/bin
export PATH=$PATH:$GOBIN

echo "== Generating Certificates for the following domains: ${DOMAINS}..."
cd "${CERTS_DIR}"
"${GOBIN}/minica" --ca-cert "${CURRENT_DIR}/minica.pem" --ca-key="${CURRENT_DIR}/minica-key.pem" --domains="${DOMAINS}"
mv "${GENERATION_DIRNAME}" "certs"
cat certs/key.pem certs/cert.pem > certs/mongo.pem

echo "== Certificates Generated in the directory ${CERTS_DIR}/certs"

# 官方使用方式
# $ cd /ANY/PATH
# $ git clone https://github.com/jsha/minica.git
# $ go build |OR| $ go install
```

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1732089280911-b186a45a-d9b7-416a-940a-2a684406eddd.png)

将上面证书放置到 certs 目录下面，然后我们新建一个 `<font style="color:#DF2A3F;">02-tls-mongo</font>` 的目录，在该目录下面执行如下命令来生成证书：

```shell
➜ bash ../certs/generate-certificates.sh mongo.local .
== Checking Requirements...
== Generating Certificates for the following domains: mongo.local...
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761791170506-01dbd7ab-a5cf-4d98-825a-0b8b39da5c5d.png)

最后的目录如下所示，在 `<font style="color:#DF2A3F;">02-tls-mongo</font>` 目录下面会生成包含证书的 certs 目录：

```shell
➜ tree .
.
├── 01-mongo
│   ├── mongo-ingressroute-tcp.yaml
│   └── mongo.yaml
├── 02-tls-mongo
│   └── certs
│       ├── cert.pem
│       ├── key.pem
│       └── mongo.pem
└── certs
    ├── generate-certificates.sh
    ├── minica-key.pem
    └── minica.pem
```

在 `<font style="color:#DF2A3F;">02-tls-mongo/certs</font>` 目录下面执行如下命令通过 Secret 来包含证书内容：

```shell
➜ kubectl create secret tls traefik-mongo-certs --cert=cert.pem --key=key.pem
secret/traefik-mongo-certs created
```

然后重新更新 `<font style="color:#DF2A3F;">IngressRouteTCP</font>` 对象，增加 TLS 配置：

```yaml
# mongo-traefik-tcp.yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRouteTCP
metadata:
  name: mongo-traefik-tcp
spec:
  entryPoints:
    - mongo
  routes:
    - match: HostSNI(`mongo.local`)
      services:
        - name: mongo-traefik
          port: 27017
  tls:
    secretName: traefik-mongo-certs
```

同样更新后，现在我们直接去访问应用就会被 hang 住（直到超时），因为我们没有提供证书：

```shell
➜ kubectl apply -f mongo-ingressroute-tcp.yaml 
ingressroutetcp.traefik.containo.us/mongo-traefik-tcp configured

# 下载并安装 mongosh
$ sudo yum install -y https://downloads.mongodb.com/compass/mongodb-mongosh-2.1.1.x86_64.rpm
# 注意：MongoDB 5.0+ 版本已经将 mongo 命令替换为 mongosh，所以安装后使用 mongosh 命令即可。

# mongo.local Or traefik.qikqiak.com 本地 hosts 文件解析的定义
➜ mongosh --host mongo.local --port 27017
Current Mongosh Log ID: 6902ce5c7d22f73f17977f06
Connecting to:          mongodb://mongo.local:27017/?directConnection=true&appName=mongosh+2.1.1
MongoServerSelectionError: Server selection timed out after 30000 ms
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761791621164-abdded8f-7961-446f-bf65-f13c3ad61279.png)

查看 Traefik Dashboard 的信息：

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761792104435-db4f2684-8d42-44cf-aedc-317971d09c79.png)

这个时候我们可以带上证书来进行连接：

```shell
# 新的 mongosh CLI 执行效果(在02-tls-mongo目录中执行)
➜ mongosh --host mongo.local --port 27017 --ssl \
>   --sslCAFile=../certs/minica.pem --sslPEMKeyFile=./certs/mongo.pem
WARNING: argument --ssl is deprecated and will be removed. Use --tls instead.
WARNING: argument --sslPEMKeyFile is deprecated and will be removed. Use --tlsCertificateKeyFile instead.
WARNING: argument --sslCAFile is deprecated and will be removed. Use --tlsCAFile instead.
Current Mongosh Log ID: 6902cf7000397764c0d532ec
Connecting to:          mongodb://mongo.local:27017/?directConnection=true&tls=true&tlsCertificateKeyFile=.%2Fcerts%2Fmongo.pem&tlsCAFile=..%2Fcerts%2Fminica.pem&appName=mongosh+2.1.1
Using MongoDB:          4.0.28
Using Mongosh:          2.1.1
mongosh 2.5.8 is available for download: https://www.mongodb.com/try/download/shell

For mongosh info see: https://docs.mongodb.com/mongodb-shell/

------
   The server generated these startup warnings when booting
   2025-10-30T02:01:44.878+0000: 
   2025-10-30T02:01:44.878+0000: ** WARNING: Access control is not enabled for the database.
   2025-10-30T02:01:44.878+0000: **          Read and write access to data and configuration is unrestricted.
   2025-10-30T02:01:44.878+0000: 
   2025-10-30T02:01:44.879+0000: 
   2025-10-30T02:01:44.879+0000: ** WARNING: /sys/kernel/mm/transparent_hugepage/enabled is 'always'.
   2025-10-30T02:01:44.879+0000: **        We suggest setting it to 'never'
   2025-10-30T02:01:44.879+0000:
------

test> show dbs;
admin   32.00 KiB
config  60.00 KiB
local   32.00 KiB

# 旧的 mongo CLI 执行效果(在02-tls-mongo目录中执行)
➜ mongo --host mongo.local --port 27017 --ssl \
  --sslCAFile=../certs/minica.pem --sslPEMKeyFile=./certs/mongo.pem
MongoDB shell version v4.0.3
connecting to: mongodb://mongo.local:27017/
Implicit session: session { "id" : UUID("e7409ef6-8ebe-4c5a-9642-42059bdb477b") }
MongoDB server version: 4.0.14
[......]
> show dbs;
admin   0.000GB
config  0.000GB
local   0.000GB
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761791879920-4ede6d23-d5de-49e6-8a11-9ff62f8ece30.png)

可以看到现在就可以连接成功了，这样就完成了一个使用 TLS 证书代理 TCP 服务的功能，这个时候如果我们使用其他的域名去进行连接就会报错了，因为现在我们指定的是特定的 HostSNI：

```shell
# 新的 mongosh CLI 执行效果(在02-tls-mongo目录中执行)
➜ mongosh --host mongo.k8s.local --port 27017 --ssl \
  --sslCAFile=../certs/minica.pem --sslPEMKeyFile=./certs/mongo.pem
WARNING: argument --ssl is deprecated and will be removed. Use --tls instead.
WARNING: argument --sslPEMKeyFile is deprecated and will be removed. Use --tlsCertificateKeyFile instead.
WARNING: argument --sslCAFile is deprecated and will be removed. Use --tlsCAFile instead.
Current Mongosh Log ID: 6902cfb040048d3c4aba6ef7
Connecting to:          mongodb://mongo.k8s.local:27017/?directConnection=true&tls=true&tlsCertificateKeyFile=.%2Fcerts%2Fmongo.pem&tlsCAFile=..%2Fcerts%2Fminica.pem&appName=mongosh+2.1.1
MongoNetworkError: getaddrinfo ENOTFOUND mongo.k8s.local

# 旧的 mongo CLI 执行效果(在02-tls-mongo目录中执行)
➜ mongo --host mongo.k8s.local --port 27017 --ssl \
  --sslCAFile=../certs/minica.pem --sslPEMKeyFile=./certs/mongo.pem
MongoDB shell version v4.0.3
connecting to: mongodb://mongo.k8s.local:27017/
2019-12-29T15:03:52.424+0800 E NETWORK  [js] SSL peer certificate validation failed: Certificate trust failure: CSSMERR_TP_NOT_TRUSTED; connection rejected
2019-12-29T15:03:52.429+0800 E QUERY    [js] Error: couldn't connect to server mongo.qikqiak.com:27017, connection attempt failed: SSLHandshakeFailed: SSL peer certificate validation failed: Certificate trust failure: CSSMERR_TP_NOT_TRUSTED; connection rejected :
connect@src/mongo/shell/mongo.js:257:13
@(connect):1:6
exception: connect failed
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761791939296-45d1696a-7871-4446-8ea0-16db7ea76ec8.png)

## 10 UDP
此外 Traefik 2.3.x 版本也已经提供了对 UDP 的支持，所以我们可以用于诸如 DNS 解析的服务提供负载。同样首先部署一个如下所示的 UDP 服务：

```yaml
# whoamiudp.yaml
apiVersion: v1
kind: Service
metadata:
  name: whoamiudp
spec:
  ports:
    - protocol: UDP
      name: udp
      port: 8080
  selector:
    app: whoamiudp
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: whoamiudp
  labels:
    app: whoamiudp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: whoamiudp
  template:
    metadata:
      labels:
        app: whoamiudp
    spec:
      containers:
        - name: whoamiudp
          image: containous/whoamiudp
          ports:
            - name: udp
              containerPort: 8080
```

```shell
$ kubectl create -f whoamiudp.yaml 
service/whoamiudp created
deployment.apps/whoamiudp created
```

直接部署上面的应用，部署完成后我们需要在 Traefik 中定义一个 UDP 的 entryPoint 入口点，修改我们部署 Traefik 的 `<font style="color:#DF2A3F;">values-prod.yaml</font>` 文件，增加 UDP 协议的入口点：

```yaml
# Configure ports
ports:
  web:
    port: 8000
    hostPort: 80
  
  websecure:
    port: 8443
    hostPort: 443
  
  metrics:
    port: 9100
    hostPort: 9101
    
  mongo:
    port: 27017
    hostPort: 27017
    protocol: TCP
  
  udpep:
    port: 18080
    hostPort: 18080
    protocol: UDP
```

我们这里定义了一个名为 udpep 的入口点，但是 protocol 协议是 UDP（此外 TCP 和 UDP 共用同一个端口也是可以的，但是协议一定要声明为不一样），然后重新更新 Traefik：

```shell
➜ helm upgrade --install traefik ./traefik \
  -f ./traefik/ci/deployment-prod.yaml \
  --namespace kube-system
false
Release "traefik" has been upgraded. Happy Helming!
NAME: traefik
LAST DEPLOYED: Wed Oct 29 16:36:03 2025
NAMESPACE: kube-system
STATUS: deployed
REVISION: 6
TEST SUITE: None
NOTES:
Traefik Proxy v2.9.9 has been deployed successfully
on kube-system namespace !
```

更新完成后我们可以导出 Traefik 部署的资源清单文件来检测是否增加上了 UDP 的入口点：

```shell
➜ kubectl get deployment traefik -n kube-system -o yaml
[......]
spec:
  containers:
  - args:
    - --entryPoints.mongo.address=:27017/tcp
    - --entryPoints.traefik.address=:9000/tcp
    - --entryPoints.udpep.address=:18080/udp
    - --entryPoints.web.address=:8000/tcp
    - --entryPoints.websecure.address=:8443/tcp
    - --api.dashboard=true
    - --ping=true
    - --providers.kubernetescrd
    - --providers.kubernetesingress
    name: traefik
    ports:
    - containerPort: 9100
      hostPort: 9101
      name: metrics
      protocol: TCP
    - containerPort: 27017
      hostPort: 27017
      name: mongo
      protocol: TCP
    - containerPort: 9000
      name: traefik
      protocol: TCP
    - containerPort: 18080
      hostPort: 18080
      name: udpep
      protocol: UDP
    - containerPort: 8000
      hostPort: 80
      name: web
      protocol: TCP
    - containerPort: 8443
      hostPort: 443
      name: websecure
      protocol: TCP
......
```

UDP 的入口点增加成功后，查看 Traefik Dashboard 的 Entrypoint 端点的信息：

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761728491421-23f65cd4-6a13-4b7f-be92-3a3e0a663ca7.png)

接下来我们可以创建一个 `<font style="color:#DF2A3F;">IngressRouteUDP</font>` 类型的资源对象，用来代理 UDP 请求：

```shell
➜ cat <<EOF | kubectl apply -f -
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRouteUDP
metadata:
  name: whoamiudp
spec:
  entryPoints:
  - udpep
  routes:
  - services:
    - name: whoamiudp
      port: 8080
EOF

➜ kubectl get ingressrouteudp
NAME        AGE
whoamiudp   30s

# 查看 whoamiudp ingressrouteudp 中的详细信息
➜ kubectl describe ingressrouteudp whoamiudp
```

Traefik Dashboard 的 UDP 信息查看：

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761728677230-77fe963d-68d1-4ff9-ab58-37d9a6480d71.png)

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761728708971-5802982e-c7c8-40a2-b743-dbbc00f17b83.png)

创建成功后我们首先在集群上通过 Service 来访问上面的 UDP 应用：

```shell
➜ kubectl get svc whoamiudp
NAME        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
whoamiudp   ClusterIP   192.96.183.77   <none>        8080/UDP   2m5s

➜ echo "WHO" | socat - udp4-datagram:192.96.183.77:8080
Hostname: whoamiudp-769bc747ff-4r7vg
IP: 127.0.0.1
IP: ::1
IP: 192.244.51.231
IP: fe80::e041:d7ff:fe9d:2dae

➜ echo "othermessage" | socat - udp4-datagram:192.96.183.77:8080
Received: othermessage
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761790483199-2598819a-1a93-48b4-ba43-c5236cbb23c1.png)

我们这个应用当我们输入 `<font style="color:#DF2A3F;">WHO</font>` 的时候，就会打印出访问的 Pod 的 Hostname 这些信息，如果不是则打印接收到字符串。现在我们通过 Traefik 所在节点的 IP（`<font style="color:#DF2A3F;">192.168.178.35</font>`）与 18080 端口来访问 UDP 应用进行测试：

```shell
# 查看 IPtables 的规则信息
➜ iptables -t nat -L | grep 18080
CNI-DN-eb46c3cfaa2146e1895ca  udp  --  anywhere             anywhere             /* dnat name: "k8s-pod-network" id: "eafecf841a212b1502b50a7d3c9f47ede0f87393281fcf5b444b00bf9299a229" */ multiport dports 18080
CNI-HOSTPORT-SETMARK  udp  --  192.244.22.193       anywhere             udp dpt:18080
CNI-HOSTPORT-SETMARK  udp  --  localhost            anywhere             udp dpt:18080
DNAT       udp  --  anywhere             anywhere             udp dpt:18080 to:192.244.22.193:18080

➜ echo "othermessage" | socat - udp4-datagram:192.168.178.35:18080
Received: othermessage

➜ echo "WHO" | socat - udp4-datagram:192.168.178.35:18080
Hostname: whoamiudp-769bc747ff-4r7vg
IP: 127.0.0.1
IP: ::1
IP: 192.244.51.231
IP: fe80::e041:d7ff:fe9d:2dae
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761790903274-c914ce95-20a8-4f23-9e12-a783f51e6257.png)

我们可以看到测试成功了，证明我就用 Traefik 来代理 UDP 应用成功了。除此之外 Traefik 还有很多功能，特别是强大的中间件和自定义插件的功能，为我们提供了不断扩展其功能的能力，我们完成可以根据自己的需求进行二次开发。

:::color2
Ingress 资源对象可以使用 Ingress-Nginx/Traefik 控制器进行实现，其目的就是把服务暴露到集群外部。实现 Kubernetes 集群南北流量的控制。

`<u><font style="color:#DF2A3F;">性能比例：Traefik 3 < Traefik 2 < Traefik 1 < Ingress-Nginx(Envoy|Istio) < HAProxy</font></u>`

:::

## 11 多控制器
有的业务场景下可能需要在一个集群中部署多个 Traefik，不同的实例控制不同的 IngressRoute 资源对象，要实现该功能有两种方法：

第一种方法：通过 Annotations 注解筛选:

+ 首先在 Traefik 中增加启动参数 `<font style="color:#DF2A3F;">--providers.kubernetescrd.ingressclass=traefik-in</font>`
+ 然后在 IngressRoute 资源对象中添加 `<font style="color:#DF2A3F;">kubernetes.io/ingress.class: traefik-in</font>`<font style="color:#DF2A3F;"> </font>注解即可

第二种方法：通过标签选择器进行过滤：

+ 首先在 Traefik 中增加启动参数 `<font style="color:#DF2A3F;">--providers.kubernetescrd.labelselector=ingressclass=traefik-out</font>`
+ 然后在 IngressRoute 资源对象中添加 `<font style="color:#DF2A3F;">ingressclass: traefik-out</font>` 这个标签即可

## 12 Traefik 匹配路径
```yaml
# whoami-ingressRoute.yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: simpleingressroute
spec:
  entryPoints:
  - web
  routes:
  - match: Host(`who.qikqiak.com`) && PathPrefix(`/notls`) # 匹配域名和路径
    kind: Rule
    services:
    - name: whoami # Kubernetes 服务名称
      port: 80
```

```shell
$ kubectl apply -f whoami-ingressRoute.yaml
$ kubectl get ingressroute whoami-ingressroute 
NAME                  AGE
whoami-ingressroute   15s
```

通过 `<font style="color:#DF2A3F;">entryPoints</font>`<font style="color:#DF2A3F;"> </font>指定了我们这个应用的入口点是 `<font style="color:#DF2A3F;">web</font>`，也就是通过 80 端口访问，然后访问的规则就是要匹配 `<font style="color:#DF2A3F;">who.qikqiak.com</font>` 这个域名，并且具有 `<font style="color:#DF2A3F;">/notls</font>` 的路径前缀的请求才会被 `<font style="color:#DF2A3F;">whoami</font>`<font style="color:#DF2A3F;"> </font>这个 Service 所匹配。我们可以直接创建上面的几个资源对象，然后对域名做对应的解析后，就可以访问应用了：`[http://who.qikqiak.com/notls](http://who.qikqiak.com/notls)`

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731853991686-7f701880-3bcf-4525-8111-950dd361f109.png)

在 `<font style="color:#DF2A3F;">IngressRoute</font>`<font style="color:#DF2A3F;"> </font>对象中我们定义了一些匹配规则，这些规则在 Traefik 中有如下定义方式：

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1730528265109-bf247942-c801-4999-83de-3d7ebe177393.png)

## 13 **Ingress-Nginx 和 Traefik 的比较：**
### 13.1 概述
:::color2
+ **Ingress-Nginx**：这是 Kubernetes 官方推荐的 Ingress 控制器之一。Nginx 是开源的、高性能的 HTTP 和反向代理服务器，因此 Ingress-Nginx 利用了 Nginx 的特性来管理和路由 Kubernetes 集群中的外部访问请求。
+ **Traefik**：Traefik 是另一个流行的 Ingress 控制器，专为云原生架构设计，支持多种后端服务（如 Kubernetes、Docker、Swarm、Mesos/Marathon 等），并且可以动态更新配置而无需重启。

:::

:::success
功能和特性

:::

**Ingress-Nginx**:

+ **稳定性和成熟度**：因为是基于 Nginx，稳定性和性能得到了广泛的验证。
+ **配置**：通过 Ingress 资源定义路由规则，支持复杂的 HTTP 请求路由、SSL 终止、重定向、虚拟主机等。
+ **扩展性**：支持自定义插件和 Lua 脚本扩展功能。
+ **健康检查**：提供了详细的健康检查配置。

**Traefik**:

+ **动态配置**：通过内置的 API 或事件监听器，可以动态更新路由规则而无需重启服务。
+ **服务发现**：支持多种服务发现机制，如 Kubernetes、Docker、Consul、Etcd 等。
+ **负载均衡**：提供多种负载均衡算法（如轮询、权重轮询等）。
+ **自动 HTTPS**：支持自动 Let's Encrypt SSL 证书管理。
+ **Metrics**：集成了 Prometheus 监控，提供丰富的指标。

:::success
性能

:::

+ **Ingress-Nginx** 基于 Nginx，有较高的性能表现，特别是在处理大量请求和复杂路由规则的情况下。
+ **Traefik** 在小规模和中等规模的环境中表现优秀，其动态配置和服务发现的特性在微服务环境中非常有用，<u><font style="color:#DF2A3F;">但 Traefik 在大规模环境下，可能会遇到一些性能瓶颈。</font></u>

:::success
易用性

:::

+ **Ingress-Nginx** 因为是基于 Kubernetes 的 Ingress 资源，配置相对直观，但对于高级配置，可能需要深入了解 Nginx 配置。
+ **Traefik** 的配置更简单直观，尤其是对于新手，Traefik 的文档非常友好，提供了许多例子和教程。

:::success
生态系统

:::

+ **Ingress-Nginx** 因为是基于 Nginx，所以可以利用 Nginx 的丰富生态系统，如各种模块和插件。
+ **Traefik** 也有自己的生态系统，但相对来说，扩展插件和社区支持可能不如 Ingress-Nginx 那么丰富。

### 13.2 总结
选择 Ingress-Nginx 还是 Traefik 取决于你的具体需求：

+ 如果你需要一个稳定的、高性能的 Ingress 控制器，并且有复杂的路由需求，**Ingress-Nginx** 可能是一个更好的选择。
+ 如果你更注重动态配置、服务发现、自动 HTTPS 以及简单易用的配置，**Traefik** 可能会更适合你的环境。

两者都是优秀的选择，最终的决定应基于你的 Kubernetes 集群规模、预期负载、服务发现需求以及对配置复杂度的容忍度。

## 14 <font style="color:rgb(0, 0, 0);">Traefik 与 APISIX 优劣势对比分析</font>
### <font style="color:rgb(0, 0, 0);">14.1 核心定位差异</font>
+ **<u><font style="color:#601BDE;">Traefik</font></u>**<u><font style="color:#601BDE;">：云原生动态反向代理与负载均衡器，专注于</font></u>**<u><font style="color:#601BDE;">微服务架构的流量入口管理</font></u>**<u><font style="color:#601BDE;">，强调</font></u>**<u><font style="color:#601BDE;">自动服务发现</font></u>**<u><font style="color:#601BDE;">与</font></u>**<u><font style="color:#601BDE;">零停机配置更新</font></u>**<u><font style="color:#601BDE;">，适合快速构建微服务流量转发通道。</font></u>
+ **<u><font style="color:#601BDE;">APISIX</font></u>**<u><font style="color:#601BDE;">：高性能云原生API网关，超越传统反向代理功能，提供</font></u>**<u><font style="color:#601BDE;">全生命周期API管理</font></u>**<u><font style="color:#601BDE;">（认证、限流、灰度发布、可观测性等），适合</font></u>**<u><font style="color:#601BDE;">复杂微服务架构</font></u>**<u><font style="color:#601BDE;">与</font></u>**<u><font style="color:#601BDE;">企业级API治理</font></u>**<u><font style="color:#601BDE;">场景。</font></u>

### <font style="color:rgb(0, 0, 0);">14.2 关键优势对比</font>
:::success
1. <font style="color:rgb(0, 0, 0);">性能表现</font>

:::

+ **<font style="color:rgb(0, 0, 0);">APISIX</font>**<font style="color:rgb(0, 0, 0);">：</font>

<font style="color:#601BDE;">采用</font>**<font style="color:#601BDE;">Nginx+etcd</font>**<font style="color:#601BDE;">架构，结合</font>**<font style="color:#601BDE;">动态配置热更新</font>**<font style="color:#601BDE;">与</font>**<font style="color:#601BDE;">高性能插件机制</font>**<font style="color:#601BDE;">，性能显著优于Traefik。</font>

    - <font style="color:rgb(0, 0, 0);">单核QPS可达</font>**<font style="color:rgb(0, 0, 0);">18,000-23,000</font>**<font style="color:rgb(0, 0, 0);">（无插件场景），启用限流、监控等插件后仍保持</font>**<font style="color:rgb(0, 0, 0);">7.8万+ QPS</font>**<font style="color:rgb(0, 0, 0);">（远超Traefik的2.6万+）。</font>
    - <font style="color:rgb(0, 0, 0);">延迟极低（<0.2ms），支持</font>**<font style="color:rgb(0, 0, 0);">百万级路由规则</font>**<font style="color:rgb(0, 0, 0);">的高效匹配（如NASA火星探测器数据处理场景）。</font>
+ **<font style="color:rgb(0, 0, 0);">Traefik</font>**<font style="color:rgb(0, 0, 0);">：</font>

<font style="color:#601BDE;">基于Go语言开发，性能优于传统反向代理（如Nginx），但</font>**<font style="color:#601BDE;">高并发场景下瓶颈明显</font>**<font style="color:#601BDE;">。</font>

    - <font style="color:rgb(0, 0, 0);">无插件场景QPS约</font>**<font style="color:rgb(0, 0, 0);">22,000</font>**<font style="color:rgb(0, 0, 0);">，启用插件后QPS下降至</font>**<font style="color:rgb(0, 0, 0);">1万以下</font>**<font style="color:rgb(0, 0, 0);">。</font>
    - <font style="color:rgb(0, 0, 0);">延迟较高（<20ms），不适合</font>**<font style="color:rgb(0, 0, 0);">百万级路由</font>**<font style="color:rgb(0, 0, 0);">或</font>**<font style="color:rgb(0, 0, 0);">超高频交易</font>**<font style="color:rgb(0, 0, 0);">场景。</font>

:::success
2. <font style="color:rgb(0, 0, 0);">功能丰富度</font>

:::

+ **<font style="color:rgb(0, 0, 0);">APISIX</font>**<font style="color:rgb(0, 0, 0);">：</font>

<font style="color:#601BDE;">提供</font>**<font style="color:#601BDE;">全栈API管理功能</font>**<font style="color:#601BDE;">，覆盖流量治理、安全、可观测性等全生命周期：</font>

    - **<font style="color:rgb(0, 0, 0);">流量治理</font>**<font style="color:rgb(0, 0, 0);">：支持</font>**<font style="color:rgb(0, 0, 0);">灰度发布（金丝雀/蓝绿）</font>**<font style="color:rgb(0, 0, 0);">、</font>**<font style="color:rgb(0, 0, 0);">动态路由</font>**<font style="color:rgb(0, 0, 0);">（基于路径、Header、Cookie等）、</font>**<font style="color:rgb(0, 0, 0);">熔断器</font>**<font style="color:rgb(0, 0, 0);">（智能过滤不健康节点）、</font>**<font style="color:rgb(0, 0, 0);">负载均衡</font>**<font style="color:rgb(0, 0, 0);">（轮询、哈希等算法）。</font>
    - **<font style="color:rgb(0, 0, 0);">安全防护</font>**<font style="color:rgb(0, 0, 0);">：支持</font>**<font style="color:rgb(0, 0, 0);">JWT/OAuth2认证</font>**<font style="color:rgb(0, 0, 0);">、</font>**<font style="color:rgb(0, 0, 0);">IP黑白名单</font>**<font style="color:rgb(0, 0, 0);">、</font>**<font style="color:rgb(0, 0, 0);">Rate Limiting</font>**<font style="color:rgb(0, 0, 0);">、</font>**<font style="color:rgb(0, 0, 0);">CORS</font>**<font style="color:rgb(0, 0, 0);">、</font>**<font style="color:rgb(0, 0, 0);">CSRF防护</font>**<font style="color:rgb(0, 0, 0);">等，满足企业级安全需求。</font>
    - **<font style="color:rgb(0, 0, 0);">可观测性</font>**<font style="color:rgb(0, 0, 0);">：集成</font>**<font style="color:rgb(0, 0, 0);">Prometheus</font>**<font style="color:rgb(0, 0, 0);">（监控）、</font>**<font style="color:rgb(0, 0, 0);">SkyWalking</font>**<font style="color:rgb(0, 0, 0);">（链路追踪）、</font>**<font style="color:rgb(0, 0, 0);">ELK</font>**<font style="color:rgb(0, 0, 0);">（日志分析），提供</font>**<font style="color:rgb(0, 0, 0);">全链路可视化</font>**<font style="color:rgb(0, 0, 0);">（请求路径、延迟分布、错误率）。</font>
    - **<font style="color:rgb(0, 0, 0);">多协议支持</font>**<font style="color:rgb(0, 0, 0);">：支持</font>**<font style="color:rgb(0, 0, 0);">TCP/UDP</font>**<font style="color:rgb(0, 0, 0);">、</font>**<font style="color:rgb(0, 0, 0);">Dubbo</font>**<font style="color:rgb(0, 0, 0);">、</font>**<font style="color:rgb(0, 0, 0);">MQTT</font>**<font style="color:rgb(0, 0, 0);">、</font>**<font style="color:rgb(0, 0, 0);">gRPC</font>**<font style="color:rgb(0, 0, 0);">、</font>**<font style="color:rgb(0, 0, 0);">HTTP/3</font>**<font style="color:rgb(0, 0, 0);">等协议，满足</font>**<font style="color:rgb(0, 0, 0);">异构系统</font>**<font style="color:rgb(0, 0, 0);">集成需求。</font>
+ **<font style="color:rgb(0, 0, 0);">Traefik</font>**<font style="color:rgb(0, 0, 0);">：</font>

<font style="color:#601BDE;">功能聚焦于</font>**<font style="color:#601BDE;">流量转发</font>**<font style="color:#601BDE;">与</font>**<font style="color:#601BDE;">基础安全</font>**<font style="color:#601BDE;">，</font>**<font style="color:#601BDE;">高级API管理功能缺失</font>**<font style="color:#601BDE;">：</font>

    - **<font style="color:rgb(0, 0, 0);">流量管理</font>**<font style="color:rgb(0, 0, 0);">：支持</font>**<font style="color:rgb(0, 0, 0);">动态路由</font>**<font style="color:rgb(0, 0, 0);">（基于标签）、</font>**<font style="color:rgb(0, 0, 0);">负载均衡</font>**<font style="color:rgb(0, 0, 0);">（轮询、最少连接）、</font>**<font style="color:rgb(0, 0, 0);">断路器</font>**<font style="color:rgb(0, 0, 0);">（自动重试），但</font>**<font style="color:rgb(0, 0, 0);">灰度发布</font>**<font style="color:rgb(0, 0, 0);">、</font>**<font style="color:rgb(0, 0, 0);">熔断</font>**<font style="color:rgb(0, 0, 0);">等功能需依赖第三方插件。</font>
    - **<font style="color:rgb(0, 0, 0);">安全防护</font>**<font style="color:rgb(0, 0, 0);">：支持</font>**<font style="color:rgb(0, 0, 0);">Let's Encrypt自动证书</font>**<font style="color:rgb(0, 0, 0);">、</font>**<font style="color:rgb(0, 0, 0);">IP白名单</font>**<font style="color:rgb(0, 0, 0);">、</font>**<font style="color:rgb(0, 0, 0);">基本认证</font>**<font style="color:rgb(0, 0, 0);">，但</font>**<font style="color:rgb(0, 0, 0);">OAuth2</font>**<font style="color:rgb(0, 0, 0);">、</font>**<font style="color:rgb(0, 0, 0);">JWT</font>**<font style="color:rgb(0, 0, 0);">等高级认证需额外配置。</font>
    - **<font style="color:rgb(0, 0, 0);">可观测性</font>**<font style="color:rgb(0, 0, 0);">：提供</font>**<font style="color:rgb(0, 0, 0);">基础监控</font>**<font style="color:rgb(0, 0, 0);">（请求计数、延迟），但</font>**<font style="color:rgb(0, 0, 0);">链路追踪</font>**<font style="color:rgb(0, 0, 0);">、</font>**<font style="color:rgb(0, 0, 0);">日志分析</font>**<font style="color:rgb(0, 0, 0);">需集成外部工具（如Jaeger、ELK）。</font>

:::success
3. <font style="color:rgb(0, 0, 0);">可扩展性</font>

:::

+ **<font style="color:rgb(0, 0, 0);">APISIX</font>**<font style="color:rgb(0, 0, 0);">：</font>

<font style="color:#601BDE;">支持</font>**<font style="color:#601BDE;">多语言插件开发</font>**<font style="color:#601BDE;">（Java、Go、Python、Rust），提供</font>**<font style="color:#601BDE;">Wasm</font>**<font style="color:#601BDE;">（WebAssembly）插件机制，允许开发者自定义功能（如认证、限流）。</font>

    - <font style="color:rgb(0, 0, 0);">插件生态丰富（80+场景），涵盖</font>**<font style="color:rgb(0, 0, 0);">JWT认证</font>**<font style="color:rgb(0, 0, 0);">、</font>**<font style="color:rgb(0, 0, 0);">SkyWalking链路追踪</font>**<font style="color:rgb(0, 0, 0);">、</font>**<font style="color:rgb(0, 0, 0);">限流</font>**<font style="color:rgb(0, 0, 0);">等，满足企业多样化需求。</font>
    - <font style="color:rgb(0, 0, 0);">支持</font>**<font style="color:rgb(0, 0, 0);">Serverless</font>**<font style="color:rgb(0, 0, 0);">（集成AWS Lambda、Azure Functions），实现</font>**<font style="color:rgb(0, 0, 0);">无服务器函数调用</font>**<font style="color:rgb(0, 0, 0);">。</font>
+ **<font style="color:rgb(0, 0, 0);">Traefik</font>**<font style="color:rgb(0, 0, 0);">：</font>

<font style="color:#601BDE;">插件开发</font>**<font style="color:#601BDE;">仅支持Go语言</font>**<font style="color:#601BDE;">，且需编译为动态库加载，</font>**<font style="color:#601BDE;">学习曲线陡峭</font>**<font style="color:#601BDE;">。</font>

    - <font style="color:rgb(0, 0, 0);">插件生态较小（100+），主要集中在</font>**<font style="color:rgb(0, 0, 0);">流量转发</font>**<font style="color:rgb(0, 0, 0);">与</font>**<font style="color:rgb(0, 0, 0);">基础安全</font>**<font style="color:rgb(0, 0, 0);">，</font>**<font style="color:rgb(0, 0, 0);">高级功能</font>**<font style="color:rgb(0, 0, 0);">（如灰度发布）需自定义开发。</font>

:::success
4. <font style="color:rgb(0, 0, 0);">云原生集成</font>

:::

+ **<font style="color:rgb(0, 0, 0);">APISIX</font>**<font style="color:rgb(0, 0, 0);">：</font>

<font style="color:rgb(0, 0, 0);">原生支持</font>**<font style="color:rgb(0, 0, 0);">Kubernetes</font>**<font style="color:rgb(0, 0, 0);">（通过Ingress Controller）、</font>**<font style="color:rgb(0, 0, 0);">Service Mesh</font>**<font style="color:rgb(0, 0, 0);">（如Istio），提供</font>**<font style="color:rgb(0, 0, 0);">统一入口</font>**<font style="color:rgb(0, 0, 0);">（南北向+东西向流量管理）。</font>

    - <font style="color:rgb(0, 0, 0);">支持</font>**<font style="color:rgb(0, 0, 0);">动态服务发现</font>**<font style="color:rgb(0, 0, 0);">（Consul、Nacos、Eureka、Zookeeper），无需手动配置上游服务。</font>
+ **<font style="color:rgb(0, 0, 0);">Traefik</font>**<font style="color:rgb(0, 0, 0);">：</font>

<font style="color:rgb(0, 0, 0);">与</font>**<font style="color:rgb(0, 0, 0);">Kubernetes</font>**<font style="color:rgb(0, 0, 0);">、</font>**<font style="color:rgb(0, 0, 0);">Docker</font>**<font style="color:rgb(0, 0, 0);">、</font>**<font style="color:rgb(0, 0, 0);">Swarm</font>**<font style="color:rgb(0, 0, 0);">等云原生工具深度集成，支持</font>**<font style="color:rgb(0, 0, 0);">自动服务发现</font>**<font style="color:rgb(0, 0, 0);">（通过标签识别Pod）。</font>

    - <font style="color:rgb(0, 0, 0);">提供</font>**<font style="color:rgb(0, 0, 0);">Kubernetes Ingress Controller</font>**<font style="color:rgb(0, 0, 0);">，但</font>**<font style="color:rgb(0, 0, 0);">功能简化</font>**<font style="color:rgb(0, 0, 0);">（如不支持灰度发布），需额外配置。</font>

:::success
5. <font style="color:rgb(0, 0, 0);">适用场景</font>

:::

+ **<font style="color:rgb(0, 0, 0);">APISIX</font>**<font style="color:rgb(0, 0, 0);">：</font>

<font style="color:#601BDE;">适合</font>**<font style="color:#601BDE;">复杂微服务架构</font>**<font style="color:#601BDE;">（如电商、金融、IoT）、</font>**<font style="color:#601BDE;">企业级API治理</font>**<font style="color:#601BDE;">（如灰度发布、熔断、安全）、</font>**<font style="color:#601BDE;">高并发场景</font>**<font style="color:#601BDE;">（如大促、直播）。</font>

    - <font style="color:rgb(0, 0, 0);">案例：NASA JPL（火星探测器数据处理）、荣耀（全球分布式网关，支撑2.5亿设备OTA升级）、B站（高并发视频流量管理）。</font>
+ **<font style="color:rgb(0, 0, 0);">Traefik</font>**<font style="color:rgb(0, 0, 0);">：</font>

<font style="color:#601BDE;">适合</font>**<font style="color:#601BDE;">中小型微服务项目</font>**<font style="color:#601BDE;">（如初创公司、内部系统）、</font>**<font style="color:#601BDE;">快速原型开发</font>**<font style="color:#601BDE;">（如本地测试、小规模部署）。</font>

    - <font style="color:rgb(0, 0, 0);">案例：个人博客、小型电商系统、内部工具链。</font>

### <font style="color:rgb(0, 0, 0);">14.3 劣势对比</font>
:::success
1. <font style="color:rgb(0, 0, 0);">APISIX</font>

:::

+ **<font style="color:rgb(0, 0, 0);">学习曲线较陡</font>**<font style="color:rgb(0, 0, 0);">：需掌握</font>**<font style="color:rgb(0, 0, 0);">Go/Java/Python</font>**<font style="color:rgb(0, 0, 0);">等语言开发插件，</font>**<font style="color:rgb(0, 0, 0);">配置复杂度高</font>**<font style="color:rgb(0, 0, 0);">（如路由规则、插件组合）。</font>
+ **<font style="color:rgb(0, 0, 0);">运维成本高</font>**<font style="color:rgb(0, 0, 0);">：需管理</font>**<font style="color:rgb(0, 0, 0);">etcd集群</font>**<font style="color:rgb(0, 0, 0);">（配置中心），</font>**<font style="color:rgb(0, 0, 0);">高可用部署</font>**<font style="color:rgb(0, 0, 0);">需额外配置（如多etcd节点）。</font>

:::success
2. <font style="color:rgb(0, 0, 0);">Traefik</font>

:::

+ **<font style="color:rgb(0, 0, 0);">功能局限性</font>**<font style="color:rgb(0, 0, 0);">：缺乏</font>**<font style="color:rgb(0, 0, 0);">高级API管理功能</font>**<font style="color:rgb(0, 0, 0);">（如灰度发布、熔断），</font>**<font style="color:rgb(0, 0, 0);">多协议支持不足</font>**<font style="color:rgb(0, 0, 0);">（如不支持Dubbo、MQTT）。</font>
+ **<font style="color:rgb(0, 0, 0);">性能瓶颈</font>**<font style="color:rgb(0, 0, 0);">：高并发场景下</font>**<font style="color:rgb(0, 0, 0);">QPS下降明显</font>**<font style="color:rgb(0, 0, 0);">，</font>**<font style="color:rgb(0, 0, 0);">延迟较高</font>**<font style="color:rgb(0, 0, 0);">，不适合</font>**<font style="color:rgb(0, 0, 0);">百万级路由</font>**<font style="color:rgb(0, 0, 0);">或</font>**<font style="color:rgb(0, 0, 0);">超高频交易</font>**<font style="color:rgb(0, 0, 0);">场景。</font>

### <font style="color:rgb(0, 0, 0);">14.4 总结与选择建议</font>
| **<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">维度</font>** | **<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">Traefik</font>** | **<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">APISIX</font>** |
| --- | --- | --- |
| **<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">核心优势</font>** | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">部署简单、自动服务发现、适合微服务快速构建</font> | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">高性能、全栈API管理、多协议支持、企业级安全</font> |
| **<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">核心劣势</font>** | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">功能局限、性能瓶颈、不适合复杂场景</font> | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">学习曲线陡、运维成本高</font> |
| **<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">推荐场景</font>** | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">中小型微服务项目、快速原型开发</font> | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">复杂微服务架构、企业级API治理、高并发场景</font> |


**<font style="color:rgb(0, 0, 0);">最终选择建议</font>**<font style="color:rgb(0, 0, 0);">：</font>

+ <font style="color:rgb(0, 0, 0);">若需</font>**<font style="color:rgb(0, 0, 0);">快速构建微服务流量入口</font>**<font style="color:rgb(0, 0, 0);">（如初创公司、内部系统），选</font>**<font style="color:rgb(0, 0, 0);">Traefik</font>**<font style="color:rgb(0, 0, 0);">；</font>
+ <font style="color:rgb(0, 0, 0);">若需</font>**<font style="color:rgb(0, 0, 0);">高级API管理</font>**<font style="color:rgb(0, 0, 0);">（如灰度发布、熔断、安全）或</font>**<font style="color:rgb(0, 0, 0);">复杂微服务架构</font>**<font style="color:rgb(0, 0, 0);">（如电商、金融），选</font>**<font style="color:rgb(0, 0, 0);">APISIX</font>**<font style="color:rgb(0, 0, 0);">。</font>

