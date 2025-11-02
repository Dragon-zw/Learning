[Apache APISIX](https://apisix.apache.org/) 是一个基于 `<font style="color:#DF2A3F;">OpenResty</font>` 和 `<font style="color:#DF2A3F;">Etcd</font>` 实现的动态、实时、高性能的 API 网关，目前已经是 Apache 顶级项目。提供了丰富的流量管理功能，如<u>负载均衡、动态路由、动态 upstream、A/B 测试、金丝雀发布、限速、熔断、防御恶意攻击、认证、监控指标、服务可观测性、服务治理等。可以使用 APISIX 来处理传统的南北流量以及服务之间的东西向流量。</u>

APISIX 基于 Nginx 和 etcd，与传统 API 网关相比，<u><font style="color:#DF2A3F;">APISIX 具有动态路由和热加载插件功能，避免了配置之后的 reload 操作，同时 APISIX 支持 HTTP(S)、HTTP2、Dubbo、QUIC、MQTT、TCP/UDP 等更多的协议。</font></u>而且还内置了 Dashboard，提供强大而灵活的界面。同样也提供了丰富的插件支持功能，而且还可以让用户自定义插件。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570619040-61c7d077-e995-4017-b8b7-22870c05946d.png)

上图是 APISIX 的架构图，整体上分成数据面和控制面两个部分，控制面用来管理路由，主要通过 etcd 来实现配置中心，数据面用来处理客户端请求，通过 APISIX 自身来实现，会不断去 watch etcd 中的 route、upstream 等数据。

## 1 APISIX Ingress
同样作为一个 API 网关，APISIX 也支持作为 Kubernetes 的一个 Ingress 控制器进行使用。**<u><font style="color:#DF2A3F;">APISIX Ingress 在架构上分成了两部分，一部分是 APISIX Ingress Controller，作为控制面它将完成配置管理与分发。另一部分 APISIX(代理) 负责承载业务流量。</font></u>**

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570606263-06bef044-de68-4efd-b50b-72117efcc55c.png)

当 Client 发起请求，到达 Apache APISIX 后，会直接把相应的业务流量传输到后端（如 Service Pod），从而完成转发过程。此过程不需要经过 Ingress Controller，这样做可以保证一旦有问题出现，或者是进行变更、扩缩容或者迁移处理等，都不会影响到用户和业务流量。

同时在配置端，用户通过 `<font style="color:#DF2A3F;">kubectl apply</font>` 创建资源，可将自定义 CRD 配置应用到 K8s 集群，Ingress Controller 会持续 watch 这些资源变更，来将相应配置应用到 Apache APISIX（通过 admin api）。

从上图可以看出 APISIX Ingress 采用了数据面与控制面的分离架构，所以用户可以选择将数据面部署在 K8s 集群内部或外部。但 Ingress Nginx 是将控制面和数据面放在了同一个 Pod 中，如果 Pod 或控制面出现一点闪失，整个 Pod 就会挂掉，进而影响到业务流量。这种架构分离，给用户提供了比较方便的部署选择，同时在业务架构调整场景下，也方便进行相关数据的迁移与使用。

APISIX Ingress 控制器目前支持的核心特性包括：

+ 全动态，支持高级路由匹配规则，可与 Apache APISIX 官方 50 多个插件 & 客户自定义插件进行扩展使用
+ 支持 CRD，更容易理解声明式配置
+ 兼容原生 Ingress 资源对象
+ 支持流量切分
+ 服务自动注册发现，无惧扩缩容
+ 更灵活的负载均衡策略，自带健康检查功能
+ 支持 gRPC plaintext 与 TCP 4 层代理

## 2 APISIX 安装
> Reference：[https://artifacthub.io/packages/helm/apisix/apisix](https://artifacthub.io/packages/helm/apisix/apisix)
>

我们这里在 Kubernetes 集群中来使用 APISIX，可以通过 Helm Chart 来进行安装，首先添加官方提供的 Helm Chart 仓库：

```shell
➜ helm repo add apisix https://charts.apiseven.com
➜ helm repo update
```

由于 APISIX 的 Chart 包中包含 dashboard 和 ingress 控制器的依赖，我们只需要在 values 中启用即可安装 ingress 控制器了：

```shell
# 默认下载最新版
➜ helm fetch apisix/apisix 
➜ tar -xvf apisix-2.12.2.tgz

# 需要指定对应的版本
➜ helm fetch apisix/apisix --version 0.7.2 
➜ tar -xvf apisix-0.7.2.tgz

# 创建目录
➜ mkdir -p apisix/ci
```

在 `<font style="color:#DF2A3F;">apisix/ci</font>` 目录中新建一个用于安装的 values 文件，内容如下所示：

```yaml
# ci/prod.yaml
apisix:
  enabled: true

  nodeSelector: # 固定在 hkk8snode002 节点上
    kubernetes.io/hostname: hkk8snode002

gateway:
  type: NodePort
  externalTrafficPolicy: Cluster
  http:
    enabled: true
    servicePort: 80
    containerPort: 9080
  tls:
    enabled: true # 启用 TLS
    servicePort: 443
    containerPort: 9443

etcd:
  enabled: true 	# 会自动创建3个节点的etcd集群
  replicaCount: 1 # 多副本需要修改下模板，这里暂时运行一个etcd pod

dashboard:
  enabled: true

ingress-controller:
  enabled: true
  config:
    apisix:
      serviceName: apisix-admin
      serviceNamespace: apisix # 指定命名空间，如果不是 ingress-apisix 需要重新指定
```

经测试官方的 Helm Chart 包对 etcd 多节点集群支持不是很好，我测试跑 3 个节点会出问题，另外对外部的 etcd TLS 集群兼容度也不好，比如 Dashboard 的 Chart 需要自己修改模板去支持 TLS，所以这里我们测试先改成 1 个副本的 etcd 集群。

<u><font style="color:#DF2A3F;">APISIX 需要依赖 etcd，默认情况下 Helm Chart 会自动安装一个 3 副本的 etcd 集群</font></u>，需要提供一个默认的 StorageClass（存储章节会详细讲解），如果你已经有默认的存储类则可以忽略下面的步骤，这里我们安装一个 nfs 的 provisioner，用下面的命令可以安装一个默认的 StorageClass：

```shell
# 添加 Helm Repo
➜ helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/

# 安装 NFS StorageClass
➜ helm upgrade --install nfs-subdir-external-provisioner \
  nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --set nfs.server=192.168.178.35 \
  --set nfs.path=/var/lib/k8s/data \
  --set image.repository=cnych/nfs-subdir-external-provisioner \
  --set storageClass.defaultClass=true -n kube-system
```

安装完成后会自动创建一个 StorageClass：

```shell
➜ kubectl get storageclass
NAME                   PROVISIONER                                     RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
nfs-client (default)   cluster.local/nfs-subdir-external-provisioner   Delete          Immediate              true                   35s
```

然后直接执行下面的命令进行一键安装：

```shell
➜ helm upgrade --install apisix ./apisix -f ./apisix/ci/prod.yaml -n apisix --create-namespace
Release "apisix" does not exist. Installing it now.
NAME: apisix
LAST DEPLOYED: Thu Dec 30 16:28:38 2021
NAMESPACE: apisix
STATUS: deployed
REVISION: 1
NOTES:
1. Get the application URL by running these commands:
  export NODE_PORT=$(kubectl get --namespace apisix -o jsonpath="{.spec.ports[0].nodePort}" services apisix-gateway)
  export NODE_IP=$(kubectl get nodes --namespace apisix -o jsonpath="{.items[0].status.addresses[0].address}")
  echo http://$NODE_IP:$NODE_PORT
```

正常就可以成功部署 APISIX 了：

```shell
# 需要更换 etcd 镜像
➜ vim apisix/charts/etcd/values.yaml

# 原镜像：bitnami/etcd:3.4.16-debian-10-r14
image: # swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/bitnami/etcd:3.6.4-debian-12-r0
  registry: swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io
  repository: bitnami/etcd
  tag: 3.6.4-debian-12-r0
  
➜ kubectl get pod -o wide -n apisix 
NAME                                        READY   STATUS    RESTARTS   AGE     IP               NODE           NOMINATED NODE   READINESS GATES
apisix-5c9979777f-tq6mm                     1/1     Running   0          6m45s   192.244.51.235   hkk8snode002   <none>           <none>
apisix-dashboard-7f948b7db9-5kxln           1/1     Running   0          4m5s    192.244.51.204   hkk8snode002   <none>           <none>
apisix-etcd-0                               1/1     Running   0          4m5s    192.244.51.203   hkk8snode002   <none>           <none>
apisix-ingress-controller-7fbcd7654-vkxd7   1/1     Running   0          6m45s   192.244.51.215   hkk8snode002   <none>           <none>

➜ kubectl get service -n apisix 
NAME                        TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
apisix-admin                ClusterIP   192.96.29.121    <none>        9180/TCP                     7m20s
apisix-dashboard            ClusterIP   192.96.226.255   <none>        80/TCP                       7m20s
apisix-etcd                 ClusterIP   192.96.248.28    <none>        2379/TCP,2380/TCP            7m20s
apisix-etcd-headless        ClusterIP   None             <none>        2379/TCP,2380/TCP            7m20s
apisix-gateway              NodePort    192.96.19.250    <none>        80:10137/TCP,443:49091/TCP   7m20s
apisix-ingress-controller   ClusterIP   192.96.85.172    <none>        80/TCP                       7m20s
```

## 3 APISIX Dashboard
现在我们可以为 Dashboard 创建一个路由规则，新建一个如下所示的 `<font style="color:#DF2A3F;">ApisixRoute</font>` 资源对象即可：

```yaml
# ApisixRoute-dashboard.yaml
apiVersion: apisix.apache.org/v2beta2
kind: ApisixRoute
metadata:
  name: dashboard
  namespace: apisix
spec:
  http:
    - name: root
      match:
        hosts:
          - apisix.qikqiak.com
        paths:
          - '/*'
      backends:
        - serviceName: apisix-dashboard
          servicePort: 80
```

创建后 `<font style="color:#DF2A3F;">apisix-ingress-controller</font>` 会将上面的资源对象通过 admin api 映射成 APISIX 中的配置：

```shell
➜ kubectl create -f ApisixRoute-dashboard.yaml 
apisixroute.apisix.apache.org/dashboard created

➜ kubectl get apisixroute -n apisix
NAME        HOSTS                    URIS     AGE
dashboard   ["apisix.qikqiak.com"]   ["/*"]   10s
```

所以其实我们的访问入口是 APISIX，而 `<font style="color:#DF2A3F;">apisix-ingress-controller</font>` 只是一个用于监听 CRDS，然后将 CRDS 翻译成 APISIX 的配置的工具而已，现在就可以通过 `<font style="color:#DF2A3F;">apisix-gateway</font>` 的 NodePort 端口去访问我们的 Dashboard 了：

> 默认浏览器访问：[http://apisix.qikqiak.com:10137/](http://apisix.qikqiak.com:10137/) -> （域名+ NodePort 的方式访问）
>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761799354796-b4c0a9a0-4f27-4064-b789-842c55df6117.png)

当然如果不想在访问的时候域名后面带上端口，在云端环境可以直接将 `<font style="color:#DF2A3F;">apisix-gateway</font>` 这个 Service 设置成 LoadBalancer 模式，在本地测试的时候可以使用 `<font style="color:#DF2A3F;">kubectl port-forward</font>` 将服务暴露在节点的 80 端口上：

```shell
# hkk8snode002 节点暴露 apisix-gateway 服务
➜ kubectl port-forward --address 0.0.0.0 svc/apisix-gateway 80:80 443:443 -n apisix

# 浏览器直接访问：http://apisix.qikqiak.com/
```

默认登录<u>用户名和密码都是 </u>`<u><font style="color:#DF2A3F;">admin</font></u>`，登录后在`<font style="color:#DF2A3F;">路由</font>`菜单下正常可以看到上面我们创建的这个 dashboard 的路由信息：

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761799354796-b4c0a9a0-4f27-4064-b789-842c55df6117.png)

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761799633390-752bc6b1-fce1-4571-888a-e0499041cab9.png)

点击`<font style="color:#DF2A3F;">更多</font>`下面的`<font style="color:#DF2A3F;">查看</font>`就可以看到在 APISIX 下面真正的路由配置信息：

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761812511910-19358b2b-79dd-479d-adb3-c40dd82a8a6f.png)

所以我们要使用 APISIX，也<u><font style="color:#DF2A3F;">一定要理解其中的路由 Route 这个概念</font></u>，**<u><font style="color:#DF2A3F;">路由（Route）是请求的入口点，它定义了客户端请求与服务之间的匹配规则，路由可以与服务（Service）、上游（Upstream）关联，一个服务可对应一组路由，一个路由可以对应一个上游对象（一组后端服务节点），因此，每个匹配到路由的请求将被网关代理到路由绑定的上游服务中。</font></u>**

理解了路由后自然就知道了我们还需要一个上游 Upstream 进行关联，这个概念和 Nginx 中的 Upstream 基本是一致的，在`<font style="color:#DF2A3F;">上游</font>`菜单下可以看到我们上面创建的 dashboard 对应的上游服务：

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761812546572-ce49e1c6-84ae-45b2-9dbb-caffff941e7f.png)

其实就是将 Kubernetes 中的 Endpoints 映射成 APISIX 中的 Upstream，然后我们可以自己在 APISIX 这边进行负载。

APISIX 提供的 Dashboard 功能还是非常全面的，我们甚至都可以直接在页面上进行所有的配置，包括插件这些，非常方便。

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761812725717-3605b75b-4d7f-4612-b025-2a48b66d9132.png)

当然还有很多其他高级的功能，比如流量切分、请求认证等等，这些高级功能在 crds 中去使用则更加方便了，当然也是支持原生的 Ingress 资源对象的，关于 APISIX 的更多用法，后续再进行说明。

## 4 URL Rewrite
同样我们来介绍下如何使用 APISIX 来实现 URL Rewrite 操作，同样还是以前面测试用过的 Nexus 应用为例进行说明，通过 `<font style="color:#DF2A3F;">ApisixRoute</font>` 对象来配置服务路由，对应的资源清单如下所示：

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
apiVersion: apisix.apache.org/v2beta2
kind: ApisixRoute
metadata:
  name: nexus
  namespace: default
spec:
  http:
    - name: root
      match:
        hosts:
          - ops.qikqiak.com
        paths:
          - '/*'
      backends:
        - serviceName: nexus
          servicePort: 8081
```

直接创建上面的资源对象即可：

```shell
➜ kubectl apply -f nexus.yaml
deployment.apps/nexus configured
service/nexus configured
apisixroute.apisix.apache.org/nexus created

➜ kubectl get apisixroute
NAME    HOSTS                 URIS     AGE
nexus   ["ops.qikqiak.com"]   ["/*"]   25s

➜ kubectl get pods -l app=nexus
NAME                     READY   STATUS    RESTARTS   AGE
nexus-6f78b79d4c-b79r4   1/1     Running   0          45s

➜ kubectl get service -l app=nexus
NAME    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
nexus   ClusterIP   10.102.53.243   <none>        8081/TCP   60s
```

部署完成后，我们根据 `<font style="color:#DF2A3F;">ApisixRoute</font>` 对象中的配置，只需要将域名 `[ops.qikqiak.com](https://ops.qikqiak.com)` 解析到 hkk8snode002 节点（上面通过 port-forward 暴露了 80 端口）即可访问：

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761820816401-17e9d859-d373-4a86-b217-a3247d5bb4e4.png)

可以在 APISIX Dashboard 中查看对应的路由信息

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761813038783-a2f24dcd-26ce-4b67-8ac3-dbc828f958cc.png)

同样如果现在需要通过一个子路径来访问 Nexus 应用的话又应该怎么来实现呢？比如通过 `<font style="color:#DF2A3F;">http://ops.qikqiak.com/nexus</font>` 来访问我们的应用，首先我们肯定需要修改 `<font style="color:#DF2A3F;">ApisixRoute</font>` 对象中匹配的 paths 路径，将其修改为 `<font style="color:#DF2A3F;">/nexus</font>`：

```yaml
# ApisixRoute-nexus.yaml
apiVersion: apisix.apache.org/v2beta2
kind: ApisixRoute
metadata:
  name: nexus
  namespace: default
spec:
  http:
    - name: root
      match:
        hosts:
          - ops.qikqiak.com
        paths:
          - '/nexus*'
      backends:
        - serviceName: nexus
          servicePort: 8081
```

引用资源清单文件

```shell
$ kubectl apply -f ApisixRoute-nexus.yaml 
apisixroute.apisix.apache.org/nexus configured
```

更新后我们可以通过 `<font style="color:#DF2A3F;">http://ops.qikqiak.com/nexus</font>` 访问应用：

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761896916046-ae65427c-bea3-4a31-ac67-1ca32e9da9a8.png)

仔细分析发现很多静态资源 404 了，这是因为现在我们只匹配了 `<font style="color:#DF2A3F;">/nexus</font>` 的请求，而我们的静态资源是 `<font style="color:#DF2A3F;">/static</font>` 路径开头的，当然就匹配不到了，所以就出现了 404，所以我们只需要加上这个 `<font style="color:#DF2A3F;">/static</font>` 路径的匹配就可以了，同样更新 ApisixRoute 对象，新增 `<font style="color:#DF2A3F;">/static/*</font>`<font style="color:#DF2A3F;"> </font>路径支持：

```yaml
# ApisixRoute-nexus.yaml
apiVersion: apisix.apache.org/v2beta2
kind: ApisixRoute
metadata:
  name: nexus
  namespace: default
spec:
  http:
    - name: root
      match:
        hosts:
          - ops.qikqiak.com
        paths:
          - '/nexus*'
          - '/static/*'
      backends:
        - serviceName: nexus
          servicePort: 8081
```

引用资源清单文件

```shell
$ kubectl apply -f ApisixRoute-nexus.yaml 
apisixroute.apisix.apache.org/nexus configured
```

更新后发现虽然静态资源可以正常访问了，但是当我们访问 `<font style="color:#DF2A3F;">http://ops.qikqiak.com/nexus</font>` 的时候依然会出现 404 错误。

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761897006278-05f5d6c5-74b4-413e-9a23-fb27daa726c2.png)

这是因为我们这里是将 `<font style="color:#DF2A3F;">/nexus</font>` 路径的请求直接路由到后端服务去了，而后端服务没有对该路径做任何处理，所以也就是 404 的响应了，在之前 ingress-nginx 或者 traefik 中我们是通过 url 重写来实现的，而在 APISIX 中同样可以实现这个处理，相当于在请求在真正到达上游服务之前将请求的 url 重写到根目录就可以了，这里我们需要用到 [proxy-rewrite](https://apisix.apache.org/zh/docs/apisix/plugins/proxy-rewrite) 这个插件（需要确保在安装的时候已经包含了该插件），`**<u><font style="color:#DF2A3F;">proxy-rewrite</font></u>**`**<u> 是上游代理信息重写插件，支持对 scheme、uri、host 等信息的重写</u>**，该插件可配置的属性如下表所示：

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570608802-f3793b5f-462b-4c95-920e-a16391f9a88a.png)

我们现在的需求是希望将所有 `<font style="color:#DF2A3F;">/nexus</font>` 下面的请求都重写到根路径 `<font style="color:#DF2A3F;">/</font>` 下面去，所以我们应该使用 `<font style="color:#DF2A3F;">regex_uri</font>` 属性，转发到上游的新 uri 地址, 使用正则表达式匹配来自客户端的 uri，当匹配成功后使用模板替换转发到上游的 uri, 未匹配成功时将客户端请求的 uri 转发至上游，重新修改后的 `<font style="color:#DF2A3F;">ApisixRoute</font>` 对象如下所示，新增 `<font style="color:#DF2A3F;">plugins</font>` 属性来配置插件：

```yaml
# ApisixRoute-proxy-rewrite-nexus.yaml
apiVersion: apisix.apache.org/v2beta2
kind: ApisixRoute
metadata:
  name: nexus
  namespace: default
spec:
  http:
    - name: root
      match:
        hosts:
          - ops.qikqiak.com
        paths:
          - '/nexus*'
          - '/static/*'
      plugins:
        - name: proxy-rewrite
          enable: true
          config:
            regex_uri: ['^/nexus(/|$)(.*)', '/$2']
      backends:
        - serviceName: nexus
          servicePort: 8081
```

引用资源清单文件

```shell
$ kubectl apply -f ApisixRoute-proxy-rewrite-nexus.yaml 
apisixroute.apisix.apache.org/nexus configured
```

这里我们启用一个 `<font style="color:#DF2A3F;">proxy-rewrite</font>` 插件，并且将所有 `<font style="color:#DF2A3F;">/nexus</font>` 路径的请求都重写到了 `<font style="color:#DF2A3F;">/</font>` 跟路径下，重新更新后再次访问 `<font style="color:#DF2A3F;">http://ops.qikqiak.com/nexus</font>` 应该就可以正常访问了：

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761897087246-a3fce84a-7683-43d3-82d0-0e74c811f0bf.png)

只有最后一个小问题了，从浏览器网络请求中可以看出我们没有去匹配 `<font style="color:#DF2A3F;">/service</font>` 这个路径的请求，只需要配置上该路径即可，如下所示：

```yaml
# ApisixRoute-nexus.yaml
apiVersion: apisix.apache.org/v2beta2
kind: ApisixRoute
metadata:
  name: nexus
  namespace: default
spec:
  http:
    - name: root
      match:
        hosts:
          - ops.qikqiak.com
        paths:
          - '/nexus*'
          - '/static/*'
          - '/service/*'
      plugins:
        - name: proxy-rewrite
          enable: true
          config:
            regex_uri: ['^/nexus(/|$)(.*)', '/$2']
      backends:
        - serviceName: nexus
          servicePort: 8081
```

引用资源清单文件

```shell
$ kubectl apply -f ApisixRoute-nexus.yaml 
apisixroute.apisix.apache.org/nexus configured
```

现在重新访问子路径就完成正常了（资源全部加载 Loading 完成）：

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761897481554-6db3fcb2-6987-40e8-b5e6-e84b97e31d6a.png)

## 5 Redirect
现在当我们访问 `<font style="color:#DF2A3F;">http://ops.qikqiak.com/nexus</font>` 或者 `<font style="color:#DF2A3F;">http://ops.qikqiak.com/nexus/</font>` 的时候都可以得到正常的结果，一般来说我们可能希望能够统一访问路径，比如访问 `**<u><font style="color:#DF2A3F;">/nexus</font></u>**`**<u><font style="color:#DF2A3F;"> </font></u>****<u>子路径的时候可以自动跳转到 </u>**`**<u><font style="color:#DF2A3F;">/nexus/</font></u>**`**<u> 以 Splash 结尾的路径上去。同样要实现该需求我们只需要使用一个名为 </u>**`**<u><font style="color:#DF2A3F;">redirect</font></u>**`**<u> 的插件即可，该插件是 URI 重定向插件</u>**，可配置的属性如下所示：

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570609720-d7811ad4-c7b3-49e2-96f6-42cb4211d055.png)

要实现我们的需求直接使用 `<font style="color:#DF2A3F;">regex_uri</font>` 这个属性即可，只需要去匹配 `<font style="color:#DF2A3F;">/nexus</font>` 的请求，然后进行跳转即可，更新 `<font style="color:#DF2A3F;">ApisixRoute</font>` 对象：

```yaml
# ApisixRoute-nexus-redirect.yaml
apiVersion: apisix.apache.org/v2beta2
kind: ApisixRoute
metadata:
  name: nexus
  namespace: default
spec:
  http:
    - name: root
      match:
        hosts:
          - ops.qikqiak.com
        paths:
          - '/nexus*'
          - '/static/*'
          - '/service/*'
      plugins:
        - name: proxy-rewrite
          enable: true
          config:
            regex_uri: ['^/nexus(/|$)(.*)', '/$2']
        - name: redirect
          enable: true
          config:
            regex_uri: ['^(/nexus)$', '$1/']
      backends:
        - serviceName: nexus
          servicePort: 8081
```

引用资源清单文件

```shell
$ kubectl apply -f ApisixRoute-nexus-redirect.yaml
apisixroute.apisix.apache.org/nexus configured
```

我们新启用了一个 `<font style="color:#DF2A3F;">redirect</font>` 插件，并配置 `<font style="color:#DF2A3F;">regex_uri: ["^(/nexus)$", "$1/"]</font>`，这样当访问 `<font style="color:#DF2A3F;">/nexus</font>` 的时候会自动跳转到 `<font style="color:#DF2A3F;">/nexus/</font>` 路径下面去。浏览器访问 URL 就会自动跳转。

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761898305146-010ae6a1-52b0-4542-a027-2cc8484d2cf4.png)

同样如果我们想要重定向到 HTTPS，只需要在该插件下面设置 `<font style="color:#DF2A3F;">config.http_to_https=true</font>` 即可：

```yaml
# ...... 其他部分省略
- name: redirect
  enable: true
  config:
    http_to_https: true
```

## 6 TLS
通过使用上面的 `<font style="color:#DF2A3F;">redirect</font>` 插件配置 `<font style="color:#DF2A3F;">http_to_https</font>` 可以将请求重定向到 https 上去，但是我们现在并没有对我们的 `<font style="color:#DF2A3F;">ops.qikqiak.com</font>` 配置 https 证书，这里我们就需要使用 `<font style="color:#DF2A3F;">ApisixTls</font>` 对象来进行证书管理。

我们先使用 `<font style="color:#DF2A3F;">openssl</font>` 创建一个自签名的证书，当然你有正规 CA 机构购买的证书的话直接将证书下载下来使用即可：

```shell
➜ openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=ops.qikqiak.com"
```

然后通过 Secret 对象来引用上面创建的证书文件：

```shell
# 要注意证书文件名称必须是 tls.crt 和 tls.key
➜ kubectl create secret tls ops-tls --cert=tls.crt --key=tls.key
```

然后就可以创建一个 `<font style="color:#DF2A3F;">ApisixTls</font>` 资源对象，引用上面的 Secret 即可：

```yaml
# ApisixTls-ops-tls.yaml
apiVersion: apisix.apache.org/v1
kind: ApisixTls
metadata:
  name: ops-tls
spec:
  hosts:
    - ops.qikqiak.com
  secret:
    name: ops-tls
    namespace: default
```

引用资源清单文件

```shell
$ kubectl create -f ApisixTls-ops-tls.yaml 
apisixtls.apisix.apache.org/ops-tls created
```

同时 APISIX TLS 还可以配置 `<font style="color:#DF2A3F;">spec.client</font>`，用于进行 mTLS 双向认证的配置。上面的资源对象创建完成后，即可访问 HTTPS 服务了（Chrome 浏览器默认会限制不安全的证书，只需要在页面上输入 `<font style="color:#DF2A3F;">thisisunsafe</font>` 即可访问了）：

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570609982-a247f487-11a6-42db-b22a-991d9a5ef695.png)

:::success
而且当访问 HTTP 的时候也会自动跳转到 HTTPS 上面去，此外我们还可以结合 cert-manager 来实现自动化的 https。

:::

## 7 auth
身份认证在日常生活当中是非常常见的一项功能，大家平时基本都会接触到。比如用支付宝消费时的人脸识别确认、公司上班下班时的指纹/面部打卡以及网站上进行账号密码登录操作等，其实都是身份认证的场景体现。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570610906-a6c6cfdf-bd7a-4780-ab1a-c939db95ab15.png)

如上图，Jack 通过账号密码请求服务端应用，服务端应用中需要有一个专门用做身份认证的模块来处理这部分的逻辑。请求处理完毕子后，如果使用 JWT Token 认证方式，服务器会反馈一个 Token 去标识这个用户为 Jack。如果登录过程中账号密码输入错误，就会导致身份认证失败。

但是每个应用服务模块去开发一个单独的身份认证模块，用来支持身份认证的一套流程处理，当服务量多了之后，就会发现这些模块的开发工作量都是非常巨大且重复的。这个时候，我们可以通过把这部分的开发逻辑放置到 Apache APISIX 的网关层来实现统一，减少开发量。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570611471-4768cfdc-6633-4bfa-a9ab-5965e1a1084b.png)

如上图所示，用户或应用方直接去请求 Apache APISIX，然后 Apache APISIX 通过识别并认证通过后，会将鉴别的身份信息传递到上游应用服务，之后上游应用服务就可以从请求头中读到这部分信息，然后进行后续的逻辑处理。

Apache APISIX 作为一个 API 网关，目前已开启与各种插件功能的适配合作，插件库也比较丰富。目前已经可与大量身份认证相关的插件进行搭配处理，如下图所示。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570611557-9952c9b2-f107-4e7e-87a9-3b9eace1776f.png)

基础认证插件比如 `<font style="color:#DF2A3F;">Key-Auth</font>`、`<font style="color:#DF2A3F;">Basic-Auth</font>`，他们是通过账号密码的方式进行认证。复杂一些的认证插件如 `<font style="color:#DF2A3F;">Hmac-Auth</font>`、`<font style="color:#DF2A3F;">JWT-Auth</font>`，如 `<font style="color:#DF2A3F;">Hmac-Auth</font>`<font style="color:#DF2A3F;"> </font>通过对请求信息做一些加密，生成一个签名，当 API 调用方将这个签名携带到 Apache APISIX，Apache APISIX 会以相同的算法计算签名，只有当签名方和应用调用方认证相同时才予以通过。其他则是一些通用认证协议和联合第三方组件进行合作的认证协议，例如 `<font style="color:#DF2A3F;">OpenID-Connect</font>` 身份认证机制，以及 `<font style="color:#DF2A3F;">LDAP</font>` 认证等。

Apache APISIX 还可以针对每一个 Consumer （即调用方应用）去做不同级别的插件配置。如下图所示，我们创建了两个消费者 Consumer A、Consumer B，我们将 Consumer A 应用到应用 1，则后续应用 1 的访问将会开启 Consumer A 的这部分插件，例如 IP 黑白名单，限制并发数量等。将 Consumer B 应用到应用 2 ，由于开启了 http-log 插件，则应用 2 的访问日志将会通过 HTTP 的方式发送到日志系统进行收集。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570612290-1954a37f-8bf3-4d39-ae61-4164ad697d1a.png)

总体说来 APISIX 的认证系统功能非常强大，我们非常有必要掌握。

### 7.1 basic-auth
首先我们来了解下最简单的基本认证在 APISIX 中是如何使用的。`<font style="color:#DF2A3F;">basic-auth</font>` 是一个认证插件，它需要与 Consumer 一起配合才能工作。添加 Basic Auth 到一个 Service 或 Route，然后 Consumer 将其用户名和密码添加到请求头中以验证其请求。

首先我们需要在 APISIX Consumer 消费者中增加 basic auth 认证配置，为其指定用户名和密码，我们这里在 APISIX Ingress 中，可以通过 `<font style="color:#DF2A3F;">ApisixConsumer</font>` 资源对象进行配置，比如这里我们为前面的 nexus 实例应用添加一个基本认证，如下所示：

```yaml
# nexus-basic-auth.yaml
apiVersion: apisix.apache.org/v2alpha1
kind: ApisixConsumer
metadata:
  name: nexusBauth
spec:
  authParameter:
    basicAuth:
      value:
        username: admin
        password: admin321
```

`<font style="color:#DF2A3F;">ApisixConsumer</font>` 资源对象中只需要配置 `<font style="color:#DF2A3F;">authParameter</font>` 认证参数即可，目前只支持 `<font style="color:#DF2A3F;">BasicAuth</font>` 与 `<font style="color:#DF2A3F;">KeyAuth</font>` 两种认证类型，在 basicAuth 下面可以通过 value 可直接去配置相关的 username 和 password，也可以直接使用 Secret 资源对象进行配置，比起明文配置会更安全一些。

然后在 `<font style="color:#DF2A3F;">ApisixRoute</font>` 中添加 authentication，将其开启并指定认证类型即可，就可以实现使用 Consumer 去完成相关配置认证，如下所示：

```yaml
apiVersion: apisix.apache.org/v2beta2
kind: ApisixRoute
metadata:
  name: nexus
  namespace: default
spec:
  http:
    - name: root
      match:
        hosts:
          - ops.qikqiak.com
        paths:
          - '/nexus*'
          - '/static/*'
          - '/service/*'
      plugins:
        - name: proxy-rewrite
          enable: true
          config:
            regex_uri: ['^/nexus(/|$)(.*)', '/$2']
        - name: redirect
          enable: true
          config:
            regex_uri: ['^(/nexus)$', '$1/']
        - name: redirect
          enable: true
          config:
            http_to_https: true
      backends:
        - serviceName: nexus
          servicePort: 8081
      authentication: # 开启 basic auth 认证
        enable: true
        type: basicAuth
```

直接更新上面的资源即可开启 basic auth 认证了，在 Dashboard 上也可以看到创建了一个 Consumer：

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570614409-199da584-37e0-4a91-9b6d-f70ea028b49c.png)

然后我们可以进行如下的测试来进行验证：

```shell
# 缺少 Authorization header
➜ curl -i http://ops.qikqiak.com/nexus/
HTTP/1.1 401 Unauthorized
Date: Tue, 11 Jan 2022 07:44:49 GMT
Content-Type: text/plain; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive
WWW-Authenticate: Basic realm='.'
Server: APISIX/2.10.0

{"message":"Missing authorization in request"}
# 用户名不存在
➜ curl -i -ubar:bar http://ops.qikqiak.com/nexus/
HTTP/1.1 401 Unauthorized
Date: Tue, 11 Jan 2022 07:45:07 GMT
Content-Type: text/plain; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive
Server: APISIX/2.10.0

{"message":"Invalid user key in authorization"}
# 成功请求
➜ curl -uadmin:admin321 http://ops.qikqiak.com/nexus/
<html>
<head><title>301 Moved Permanently</title></head>
<body>
<center><h1>301 Moved Permanently</h1></center>
<hr><center>openresty</center>
</body>
</html>
```

### 7.2 consumer-restriction
不过这里大家可能会有一个疑问，在 Route 上面我们并没有去指定具体的一个 Consumer，然后就可以进行 Basic Auth 认证了，那如果我们有多个 Consumer 都定义了 Basic Auth 岂不是都会生效的？确实是这样的，这就是 APISIX 的实现方式，所有的 Consumer 对启用对应插件的 Route 都会生效的，如果我们只想 Consumer A 应用在 Route A、Consumer B 应用在 Route B 上面的话呢？要实现这个功能就需要用到另外一个插件：[consumer-restriction](https://apisix.apache.org/zh/docs/apisix/plugins/consumer-restriction/)。

`<font style="color:#DF2A3F;">consumer-restriction</font>` 插件可以根据选择的不同对象做相应的访问限制，该插件可配置的属性如下表所示：

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570614303-c2ce8bd3-4808-4a12-8c29-23a1983a273e.png)

其中的 type 字段是个枚举类型，它可以是 `<font style="color:#DF2A3F;">consumer_name</font>` 或 `<font style="color:#DF2A3F;">service_id</font>`，分别代表以下含义：

+ `<font style="color:#DF2A3F;">consumer_name</font>`：把 consumer 的 username 列入白名单或黑名单（支持单个或多个 consumer）来限制对服务或路由的访问。
+ `<font style="color:#DF2A3F;">service_id</font>`：把 service 的 id 列入白名单或黑名单（支持一个或多个 service）来限制 service 的访问，需要结合授权插件一起使用。

比如现在我们有两个 Consumer：jack1 和 jack2，这两个 Consumer 都配置了 Basic Auth 认证，配置如下所示：

Conumer `<font style="color:#DF2A3F;">jack1</font>` 的认证配置：

```shell
➜ curl http://192.168.31.46/apisix/admin/consumers -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' -X PUT -i -d '
{
    "username": "jack1",
    "plugins": {
        "basic-auth": {
            "username":"jack2019",
            "password": "123456"
        }
    }
}'
```

Conumer `<font style="color:#DF2A3F;">jack2</font>` 的认证配置：

```shell
➜ curl http://192.168.31.46/apisix/admin/consumers -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' -X PUT -i -d '
{
    "username": "jack2",
    "plugins": {
        "basic-auth": {
            "username":"jack2020",
            "password": "123456"
        }
    }
}'
```

现在我们只想给一个 Route 路由对象启用 jack1 这个 Consumer 的认证配置，则除了启用 `<font style="color:#DF2A3F;">basic-auth</font>` 插件之外，还需要在 `<font style="color:#DF2A3F;">consumer-restriction</font>` 插件中配置一个 `<font style="color:#DF2A3F;">whitelist</font>` 白名单（当然配置黑名单也是可以的），如下所示：

```shell
➜ curl http://192.168.31.46/apisix/admin/routes/1 -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' -X PUT -d '
{
    "uri": "/index.html",
    "upstream": {
        "type": "roundrobin",
        "nodes": {
            "127.0.0.1:1980": 1
        }
    },
    "plugins": {
        "basic-auth": {},
        "consumer-restriction": {
            "whitelist": [
                "jack1"
            ]
        }
    }
}'
```

然后我们使用 jack1 去访问我们的路由进行验证：

```shell
➜ curl -u jack2019:123456 http://127.0.0.1:9080/index.html -i
HTTP/1.1 200 OK
...
```

正常使用 jack2 访问就会认证失败了：

```shell
➜ curl -u jack2020:123456 http://127.0.0.1:9080/index.html -i
HTTP/1.1 403 Forbidden
...
{"message":"The consumer_name is forbidden."}
```

所以当你只想让一个 Route 对象关联指定的 Consumer 的时候，记得使用 `<font style="color:#DF2A3F;">consumer-restriction</font>` 插件。

### 7.3 jwt-auth
在平时的应用中可能使用 jwt 认证的场景是最多的，同样在 APISIX 中也有提供 `<font style="color:#DF2A3F;">jwt-auth</font>` 的插件，它同样需要与 Consumer 一起配合才能工作，我们只需要添加 JWT Auth 到一个 Service 或 Route，然后 Consumer 将其密钥添加到查询字符串参数、请求头或 cookie 中以验证其请求即可。

由于目前 `<font style="color:#DF2A3F;">ApisixConsumer</font>` 还不支持 `<font style="color:#DF2A3F;">jwt-auth</font>` 配置，所以需要我们去 APISIX 手动创建一个 Consumer，可以通过 APISIX 的 API 进行创建，当然也可以直接通过 Dashboard 页面操作。在 Dashboard 消费者页面点击创建消费者：

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570615379-569e897e-e501-4d26-bc3a-b0c38d79f847.png)

点击**下一步**进入插件配置页面，这里我们需要启用 `<font style="color:#DF2A3F;">jwt-auth</font>` 这个插件：

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570615373-121b8b1a-f225-4540-9b59-4405e722f091.png)

在插件配置页面配置 `<font style="color:#DF2A3F;">jwt-auth</font>` 相关属性，可参考插件文档 [https://apisix.apache.org/zh/docs/apisix/plugins/jwt-auth/](https://apisix.apache.org/zh/docs/apisix/plugins/jwt-auth/):

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570615727-0a3a5d52-8448-4a68-8569-2afbbc462faa.png)

可配置的属性如下表所示：

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570616090-63188111-6d04-4252-9537-10d22ed5875f.png)

然后提交即可创建完成 Consumer，然后我们只需要在需要的 Service 或者 Route 上开启 `<font style="color:#DF2A3F;">jwt-auth</font>` 即可，比如同样还是针对上面的 nexus 应用，我们只需要在 `<font style="color:#DF2A3F;">ApisixRoute</font>` 对象中启用一个 `<font style="color:#DF2A3F;">jwt-auth</font>` 插件即可：

```yaml
apiVersion: apisix.apache.org/v2beta2
kind: ApisixRoute
metadata:
  name: nexus
  namespace: default
spec:
  http:
    - name: root
      match:
        hosts:
          - ops.qikqiak.com
        paths:
          - '/nexus*'
          - '/static/*'
          - '/service/*'
      plugins:
        - name: jwt-auth
          enable: true
        - name: redirect
          enable: true
          config:
            http_to_https: true
        - name: redirect
          enable: true
          config:
            regex_uri: ['^(/nexus)$', '$1/']
        - name: proxy-rewrite
          enable: true
          config:
            regex_uri: ['^/nexus(/|$)(.*)', '/$2']
      backends:
        - serviceName: nexus
          servicePort: 8081
```

需要注意的是 `<font style="color:#DF2A3F;">authentication</font>` 属性也不支持 `<font style="color:#DF2A3F;">jwt-auth</font>`，所以这里我们通过 `<font style="color:#DF2A3F;">plugins</font>` 进行启用，重新更新上面的对象后我们同样来测试验证下：

```shell
➜ curl -i http://ops.qikqiak.com/nexus/
HTTP/1.1 401 Unauthorized
Date: Tue, 11 Jan 2022 08:54:30 GMT
Content-Type: text/plain; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive
Server: APISIX/2.10.0

{"message":"Missing JWT token in request"}
```

要正常访问我们的服务就需要先进行登录获取 `<font style="color:#DF2A3F;">jwt-auth</font>` 的 token，通过 APISIX 的 `<font style="color:#DF2A3F;">apisix/plugin/jwt/sign</font>` 可以获取：

```shell
➜ curl -i http://192.168.31.46/apisix/plugin/jwt/sign\?key\=user-key
HTTP/1.1 200 OK
Date: Tue, 11 Jan 2022 09:01:29 GMT
Content-Type: text/plain; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive
Server: APISIX/2.10.0

eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJrZXkiOiJ1c2VyLWtleSIsImV4cCI6MTY0MTk3ODA4OX0.rdzMxM4QAKI444c3SC3u3ZqfW9rKnsqrdorLHCGqrQg
```

要注意上面我们在获取 token 的时候需要传递创建消费者的标识 key，因为可能有多个不同的 Consumer 消费者，然后我们将上面获得的 token 放入到 Header 头中进行访问：

```shell
➜ curl -i http://ops.qikqiak.com/nexus/ -H 'Authorization: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJrZXkiOiJ1c2VyLWtleSIsImV4cCI6MTY0MTk3ODA4OX0.rdzMxM4QAKI444c3SC3u3ZqfW9rKnsqrdorLHCGqrQg'
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8
Content-Length: 8802
Connection: keep-alive
......
Expires: 0
Server: APISIX/2.10.0


<!DOCTYPE html>
<html lang="en">
......
```

可以看到可以正常访问。同样也可以放到请求参数中验证：

```shell
➜ curl -i http://ops.qikqiak.com/nexus/?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJrZXkiOiJ1c2VyLWtleSIsImV4cCI6MTY0MTk3ODA4OX0.rdzMxM4QAKI444c3SC3u3ZqfW9rKnsqrdorLHCGqrQg
HTTP/1.1 200 OK
......
```

此外还可以放到 cookie 中进行验证：

```shell
➜ curl -i http://ops.qikqiak.com/nexus/ --cookie jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJrZXkiOiJ1c2VyLWtleSIsImV4cCI6MTY0MTk3ODA4OX0.rdzMxM4QAKI444c3SC3u3ZqfW9rKnsqrdorLHCGqrQg
HTTP/1.1 200 OK
......
```

## 8 自定义插件
除了 APISIX 官方内置的插件之外，我们也可以根据自己的需求去自定义插件，要自定义插件需要使用到 APISIX 提供的 Runner，目前已经支持 Java、Go 和 Python 语言的 Runner，这个 Runner 相当于是 APISIX 和自定义插件之间的桥梁，比如 `<font style="color:#DF2A3F;">apache-apisix-python-runner</font>` 这个项目通过 Python Runner 可以把 Python 直接应用到 APISIX 的插件开发中，整体架构如下所示：

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570616203-e899776b-fb39-4888-b690-644e1619ebd0.png)

左边是 APISIX 的工作流程，右边的 `<font style="color:#DF2A3F;">Plugin Runner</font>` 是各语言的插件运行器，当在 APISIX 中配置一个 Plugin Runner 时，APISIX 会启动一个子进程运行 Plugin Runner，该子进程与 APISIX 进程属于同一个用户，当我们重启或重新加载 APISIX 时，Plugin Runner 也将被重启。

如果你为一个给定的路由配置了 `<font style="color:#DF2A3F;">ext-plugin-*</font>` 插件，请求命中该路由时将触发 APISIX 通过 `<font style="color:#DF2A3F;">Unix Socket</font>`<font style="color:#DF2A3F;"> </font>向 Plugin Runner 发起 RPC 调用。调用分为两个阶段：

+ `<font style="color:#DF2A3F;">ext-plugin-pre-req</font>`：在执行 APISIX 内置插件之前
+ `<font style="color:#DF2A3F;">ext-plugin-post-req</font>`：在执行 APISIX 内置插件之后

接下来我们就以 Python 为例来说明如何自定义插件，首先获取 `<font style="color:#DF2A3F;">apache-apisix-python-runner</font>` 项目：

```shell
➜ git clone https://github.com/apache/apisix-python-plugin-runner.git
➜ cd apisix-python-plugin-runner
➜ git checkout 0.1.0  # 切换刀0.1.0版本
```

如果是开发模式，则我们可以直接使用下面的命令启动 Python Runner：

```shell
➜ APISIX_LISTEN_ADDRESS=unix:/tmp/runner.sock python3 apisix/main.py start
```

启动后需要在 APISIX 配置文件中新增外部插件配置，如下所示：

```shell
➜ vim /path/to/apisix/conf/config.yaml
apisix:
  admin_key:
    - name: "admin"
      key: edd1c9f034335f136f87ad84b625c8f1
      role: admin

ext-plugin:
  path_for_test: /tmp/runner.sock
```

通过 `<font style="color:#DF2A3F;">ext-plugin.path_for_test</font>`<font style="color:#DF2A3F;"> </font>指定 Python Runner 的 unix socket 文件路径即可，如果是生产环境则可以通过 `ext-plugin.cmd` 来指定 Runner 的启动命令即可：

```shell
ext-plugin:
  cmd: [ "python3", "/path/to/apisix-python-plugin-runner/apisix/main.py", "start" ]
```

我们这里的 APISIX 是运行 Kubernetes 集群中的，所以要在 APISIX 的 Pod 中去执行 Python Runner 的代码，我们自然需要将我们的 Python 代码放到 APISIX 的容器中去，然后安装自定义插件的相关依赖，直接在 APISIX 配置文件中添加上面的配置即可，所以我们这里基于 APISIX 的镜像来重新定制包含插件的镜像，在 `<font style="color:#DF2A3F;">apisix-python-plugin-runner</font>` 项目根目录下新增如下所示的 Dockerfile 文件：

```dockerfile
FROM apache/apisix:2.10.0-alpine

ADD . /apisix-python-plugin-runner

RUN apk add --update python3 py3-pip && \
    cd /apisix-python-plugin-runner && \
    python3 -m pip install --upgrade pip && \
    python3 -m pip install -r requirements.txt --ignore-installed && \
    python3 setup.py install --force
```

基于上面 Dockerfile 构建一个新的镜像，推送到 Docker Hub：

```shell
➜ docker build -t cnych/apisix:py3-plugin-2.10.0-alpine .
# 推送到DockerHub
➜ docker push cnych/apisix:py3-plugin-2.10.0-alpine
```

接下来我们需要使用上面构建的镜像来安装 APISIX，我们这里使用的是 Helm Chart 进行安装的，所以需要通过 Values 文件进行覆盖，如下所示：

```yaml
# ci/prod.yaml
apisix:
  enabled: true

  image:
    repository: cnych/apisix
    tag: py3-plugin-2.10.0-alpine
......
```

由于官方的 Helm Chart 没有提供对 `<font style="color:#DF2A3F;">ext-plugin</font>`<font style="color:#DF2A3F;"> </font>配置的支持，所以需要我们手动修改模板文件 `<font style="color:#DF2A3F;">templates/configmap.yaml</font>`，在 `<font style="color:#DF2A3F;">apisix</font>` 属性同级目录下面新增 `<font style="color:#DF2A3F;">ext-plugin</font>` 相关配置，如下所示：

```yaml
{{- if .Values.extPlugins.enabled }}
ext-plugin:
  {{- if .Values.extPlugins.pathForTest }}
  path_for_test: {{ .Values.extPlugins.pathForTest }}
  {{- end }}
  {{- if .Values.extPlugins.cmds }}
  cmd:
  {{- range $cmd := .Values.extPlugins.cmds }}
  - {{ $cmd }}
  {{- end }}
  {{- end }}
{{- end }}

nginx_config:
  user: root  # fix 执行 python runner没权限的问题
```

然后在定制的 Values 文件中添加如下所示的配置：

```yaml
# ci/prod.yaml
extPlugins:
  enabled: true
  cmds: ['python3', '/apisix-python-plugin-runner/apisix/main.py', 'start']
```

接着就可以重新部署 APISIX 了：

```shell
➜ helm upgrade --install apisix ./apisix -f ./apisix/ci/prod.yaml -n apisix
```

部署完成后在 APISIX 的 Pod 中可以看到会启动一个 Python Runner 的子进程：

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570617043-6e5c2ee7-d73f-4df2-8455-c55213848505.png)

在插件目录 `<font style="color:#DF2A3F;">/apisix-python-plugin-runner/apisix/plugins</font>` 中的 `<font style="color:#DF2A3F;">.py</font>` 文件都会被自动加载，上面示例中有两个插件 `<font style="color:#DF2A3F;">stop.py</font>` 和 `<font style="color:#DF2A3F;">rewrite.py</font>`，我们以 `<font style="color:#DF2A3F;">stop.py</font>` 为例进行说明，该插件代码如下所示：

```python
from apisix.runner.plugin.base import Base
from apisix.runner.http.request import Request
from apisix.runner.http.response import Response


class Stop(Base):
    def __init__(self):
        super(Stop, self).__init__(self.__class__.__name__)

    def filter(self, request: Request, response: Response):
        # 可以通过 `self.config` 获取配置信息，如果插件配置为JSON将自动转换为字典结构
        # print(self.config)

        # 设置响应 Header 头
        response.headers["X-Resp-A6-Runner"] = "Python"
        # 设置响应body
        response.body = "Hello, Python Runner of APISIX"
        # 设置响应状态码
        response.status_code = 201

        # 通过调用 `self.stop()` 中断请求流程，此时将立即响应请求给客户端
        # 如果未显示调用 `self.stop()` 或 显示调用 `self.rewrite()`将继续将请求
        # 默认为 `self.rewrite()`
        self.stop()
```

实现插件首先必须要继承 `<font style="color:#DF2A3F;">Base</font>` 类，必须实现 `<font style="color:#DF2A3F;">filter</font>` 函数，插件执行核心业务逻辑就是在 `<font style="color:#DF2A3F;">filter</font>` 函数中，该函数只包含 `<font style="color:#DF2A3F;">Request</font>` 和 `<font style="color:#DF2A3F;">Response</font>` 类对象作为参数，`<font style="color:#DF2A3F;">Request</font>` 对象参数可以获取请求信息，`<font style="color:#DF2A3F;">Response</font>` 对象参数可以设置响应信息 ，`<font style="color:#DF2A3F;">self.config</font>` 可以获取插件配置信息，在 `<font style="color:#DF2A3F;">filter</font>` 函数中调用 `<font style="color:#DF2A3F;">self.stop()</font>` 时将马上中断请求，响应数据，调用 `<font style="color:#DF2A3F;">self.rewrite()</font>` 时，将会继续请求。

然后我们在前面的 Nexus 应用中新增一个路由来测试我们上面的 `<font style="color:#DF2A3F;">stop</font>` 插件，在 `<font style="color:#DF2A3F;">ApisixRoute</font>` 对象中新增一个路由规则，如下所示：

```yaml
apiVersion: apisix.apache.org/v2beta2
kind: ApisixRoute
metadata:
  name: nexus
  namespace: default
spec:
  http:
    - name: ext
      match:
        hosts:
          - ops.qikqiak.com
        paths:
          - '/extPlugin'
      plugins:
        - name: ext-plugin-pre-req # 启用ext-plugin-pre-req插件
          enable: true
          config:
            conf:
              - name: 'stop' # 使用 stop 这个自定义插件
                value: '{"body":"hello"}'
      backends:
        - serviceName: nexus
          servicePort: 8081
```

直接创建上面的路由即可，核心配置是启用 `<font style="color:#DF2A3F;">ext-plugin-pre-req</font>` 插件（前提是在配置文件中已经启用该插件，在 Helm Chart 的 Values 中添加上），然后在 `<font style="color:#DF2A3F;">config</font>` 下面使用 `<font style="color:#DF2A3F;">conf</font>` 属性进行配置，`<font style="color:#DF2A3F;">conf</font>` 为数组格式可以同时设置多个插件，插件配置对象中 `<font style="color:#DF2A3F;">name</font>` 为插件名称，该名称需要与插件代码文件和对象名称一致，`<font style="color:#DF2A3F;">value</font>` 为插件配置，可以为 JSON 字符串。

创建后同样在 Dashboard 中也可以看到 APISIX 中的路由配置格式：

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570617473-c4d44a99-89b8-4e6a-a932-8a914e74ab45.png)

接着我们可以来访问 `<font style="color:#DF2A3F;">http://ops.qikqiak.com/extPlugin</font>`<font style="color:#DF2A3F;"> </font>这个路径来验证我们的自定义插件：

```shell
➜ curl -i http://ops.qikqiak.com/extPlugin
HTTP/1.1 201 Created
Date: Thu, 13 Jan 2022 07:04:50 GMT
Content-Type: text/plain; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive
accept: */*
user-agent: curl/7.64.1
host: ops.qikqiak.com
X-Resp-A6-Runner: Python
Server: APISIX/2.10.0

Hello, Python Runner of APISIX
```

访问请求结果中有一个 `<font style="color:#DF2A3F;">X-Resp-A6-Runner: Python</font>` 头信息，返回的 body 数据为 `<font style="color:#DF2A3F;">Hello, Python Runner of APISIX</font>`，和我们在插件中的定义是符合的。到这里就完成了使用 Python 进行 APISIX 自定义插件，我们有任何的业务逻辑需要处理直接去定义一个对应的插件即可。

## 9 APISIX、Traefik 和 Ingress-Nginx <font style="color:rgb(0, 0, 0);">全面对比分析</font>
### <font style="color:rgb(0, 0, 0);">9.1 一、核心定位与设计理念</font>
<font style="color:rgb(0, 0, 0);">三者均为</font>**<font style="color:rgb(0, 0, 0);">Kubernetes（K8s）生态中的Ingress控制器</font>**<font style="color:rgb(0, 0, 0);">，负责管理集群外部流量到内部服务的路由，但设计理念差异显著：</font>

+ **<font style="color:rgb(0, 0, 0);">Ingress-Nginx</font>**<font style="color:rgb(0, 0, 0);">：K8s官方维护的</font>**<font style="color:rgb(0, 0, 0);">基础Ingress控制器</font>**<font style="color:rgb(0, 0, 0);">，基于Nginx构建，强调</font>**<font style="color:rgb(0, 0, 0);">稳定性、兼容性</font>**<font style="color:rgb(0, 0, 0);">，适合作为“入门级”流量入口。其核心是通过Ingress资源定义路由规则，支持基本的HTTP/HTTPS路由、SSL终止、负载均衡等功能。</font>
+ **<font style="color:rgb(0, 0, 0);">Traefik</font>**<font style="color:rgb(0, 0, 0);">：</font>**<font style="color:rgb(0, 0, 0);">云原生动态Ingress控制器</font>**<font style="color:rgb(0, 0, 0);">，专为微服务和容器化环境设计，核心优势是</font>**<font style="color:rgb(0, 0, 0);">自动服务发现、动态配置</font>**<font style="color:rgb(0, 0, 0);">。无需手动修改配置文件，即可感知K8s中Service、Pod的变化，实时更新路由规则。</font>
+ **<font style="color:rgb(0, 0, 0);">APISIX</font>**<font style="color:rgb(0, 0, 0);">：</font>**<font style="color:rgb(0, 0, 0);">高性能云原生API网关</font>**<font style="color:rgb(0, 0, 0);">，超越了传统Ingress的功能边界，提供</font>**<font style="color:rgb(0, 0, 0);">全生命周期API管理</font>**<font style="color:rgb(0, 0, 0);">（如认证、限流、灰度发布、可观测性）。其设计目标是满足复杂微服务架构下的</font>**<font style="color:rgb(0, 0, 0);">动态流量治理</font>**<font style="color:rgb(0, 0, 0);">需求，支持多协议（HTTP/HTTPS、gRPC、WebSocket、Dubbo等）。</font>

### <font style="color:rgb(0, 0, 0);">9.2 二、关键功能对比</font>
| **<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">功能维度</font>** | **<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">Ingress-Nginx</font>** | **<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">Traefik</font>** | **<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">APISIX</font>** |
| --- | --- | --- | --- |
| **<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">动态配置</font>** | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">依赖Ingress资源，修改后需</font>`<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">kubectl apply</font>`<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">刷新，无热加载。</font> | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">自动感知K8s Service/Pod变化，实时更新配置，支持热重载。</font> | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">基于etcd动态存储配置，支持</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">热更新</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">（无需重启），配置变更即时生效。</font> |
| **<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">服务发现</font>** | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">仅支持K8s原生Service发现，需手动配置Endpoint。</font> | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">原生支持K8s、Docker、Consul等多种服务发现，自动同步服务列表。</font> | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">支持K8s、Consul、Etcd等</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">多源服务发现</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">，并提供</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">服务治理</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">（如权重调整、熔断、降级）。</font> |
| **<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">路由能力</font>** | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">基础HTTP/HTTPS路由，支持基于路径、域名的匹配。</font> | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">支持</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">动态路由</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">（如基于Header、Cookie的匹配）、</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">流量镜像</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">（Shadowing）。</font> | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">提供</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">精细化路由</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">（如正则表达式、权重路由、灰度发布（金丝雀/蓝绿））、</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">多协议路由</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">（gRPC、WebSocket）。</font> |
| **<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">安全功能</font>** | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">支持基础SSL终止、Let's Encrypt自动证书（需插件）。</font> | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">原生支持</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">Let's Encrypt自动证书</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">、</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">TLS终止</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">、</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">IP白名单</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">。</font> | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">提供</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">多层安全防护</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">：JWT/OAuth2认证、限流（Rate Limiting）、IP黑白名单、WAF（Web应用防火墙）、SQL注入防护。</font> |
| **<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">可观测性</font>** | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">支持基础监控（如请求计数、延迟），需集成Prometheus/Grafana。</font> | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">提供</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">实时Dashboard</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">（显示请求速率、延迟、错误率）、集成Prometheus/Grafana。</font> | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">内置</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">全链路可观测性</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">：分布式追踪（OpenTelemetry）、日志收集（ELK）、监控（Prometheus），支持</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">流量可视化</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">（如请求路径、响应时间分布）。</font> |
| **<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">扩展能力</font>** | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">依赖Lua脚本或第三方插件，扩展复杂度高。</font> | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">支持</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">插件机制</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">（如自定义中间件），但社区插件生态较小。</font> | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">提供</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">插件编排</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">（多个插件逻辑组合）、</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">多语言插件支持</font>**<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">（Java、Python、Go等），社区插件生态丰富（如API密钥认证、流量整形）。</font> |


### <font style="color:rgb(0, 0, 0);">9.3 三、性能与 scalability</font>
+ **<font style="color:rgb(0, 0, 0);">Ingress-Nginx</font>**<font style="color:rgb(0, 0, 0);">：基于Nginx，性能稳定，但</font>**<font style="color:rgb(0, 0, 0);">动态配置需重启</font>**<font style="color:rgb(0, 0, 0);">，高并发下可能出现性能瓶颈。</font>
+ **<font style="color:rgb(0, 0, 0);">Traefik</font>**<font style="color:rgb(0, 0, 0);">：采用Go语言编写，轻量级，</font>**<font style="color:rgb(0, 0, 0);">自动服务发现</font>**<font style="color:rgb(0, 0, 0);">减少了人工干预，适合中等规模集群（如100-500个Pod）。</font>
+ **<font style="color:rgb(0, 0, 0);">APISIX</font>**<font style="color:rgb(0, 0, 0);">：基于Nginx+etcd，</font>**<font style="color:rgb(0, 0, 0);">动态配置</font>**<font style="color:rgb(0, 0, 0);">（etcd）和</font>**<font style="color:rgb(0, 0, 0);">插件编排</font>**<font style="color:rgb(0, 0, 0);">使其在高并发场景下（如1000+ Pod）仍能保持低延迟（<10ms），支持</font>**<font style="color:rgb(0, 0, 0);">水平扩展</font>**<font style="color:rgb(0, 0, 0);">（通过增加节点提升吞吐量）。</font>

### <font style="color:rgb(0, 0, 0);">9.4 四、适用场景</font>
+ **<font style="color:rgb(0, 0, 0);">Ingress-Nginx</font>**<font style="color:rgb(0, 0, 0);">：</font>
    - <font style="color:rgb(0, 0, 0);">适合</font>**<font style="color:rgb(0, 0, 0);">简单静态路由</font>**<font style="color:rgb(0, 0, 0);">需求（如暴露单个Service、静态网站）；</font>
    - <font style="color:rgb(0, 0, 0);">已有K8s基础设施，且无需复杂流量治理的场景；</font>
    - <font style="color:rgb(0, 0, 0);">对成本敏感，追求“开箱即用”的小型团队。</font>
+ **<font style="color:rgb(0, 0, 0);">Traefik</font>**<font style="color:rgb(0, 0, 0);">：</font>
    - <font style="color:rgb(0, 0, 0);">适合</font>**<font style="color:rgb(0, 0, 0);">微服务架构</font>**<font style="color:rgb(0, 0, 0);">（如K8s集群中的多个Service）；</font>
    - <font style="color:rgb(0, 0, 0);">需要</font>**<font style="color:rgb(0, 0, 0);">自动服务发现</font>**<font style="color:rgb(0, 0, 0);">（如频繁部署/销毁Pod）的场景；</font>
    - <font style="color:rgb(0, 0, 0);">追求</font>**<font style="color:rgb(0, 0, 0);">简单部署</font>**<font style="color:rgb(0, 0, 0);">（如Docker Compose、K8s DaemonSet）的中小型团队。</font>
+ **<font style="color:rgb(0, 0, 0);">APISIX</font>**<font style="color:rgb(0, 0, 0);">：</font>
    - <font style="color:rgb(0, 0, 0);">适合</font>**<font style="color:rgb(0, 0, 0);">复杂微服务架构</font>**<font style="color:rgb(0, 0, 0);">（如电商、金融系统的多服务协同）；</font>
    - <font style="color:rgb(0, 0, 0);">需要</font>**<font style="color:rgb(0, 0, 0);">高级API管理</font>**<font style="color:rgb(0, 0, 0);">（如灰度发布、限流、认证）的场景；</font>
    - <font style="color:rgb(0, 0, 0);">多协议支持需求（如gRPC、WebSocket、Dubbo）；</font>
    - <font style="color:rgb(0, 0, 0);">追求</font>**<font style="color:rgb(0, 0, 0);">高可用、高性能</font>**<font style="color:rgb(0, 0, 0);">（如大型电商平台的大促活动）的企业级团队。</font>

### <font style="color:rgb(0, 0, 0);">9.5 五、总结与选择建议</font>
| **<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">维度</font>** | **<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">Ingress-Nginx</font>** | **<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">Traefik</font>** | **<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">APISIX</font>** |
| --- | --- | --- | --- |
| **<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">核心优势</font>** | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">稳定、兼容K8s原生生态</font> | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">自动服务发现、简单部署</font> | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">高性能、全生命周期API管理</font> |
| **<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">核心劣势</font>** | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">动态配置复杂、功能有限</font> | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">功能扩展性弱、社区生态小</font> | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">学习曲线较陡（如插件开发）</font> |
| **<font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">推荐场景</font>** | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">简单静态路由、小型集群</font> | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">微服务架构、自动服务发现</font> | <font style="color:rgb(0, 0, 0);background-color:rgba(0, 0, 0, 0);">复杂微服务、高级API管理、企业级场景</font> |


**<font style="color:rgb(0, 0, 0);">最终选择建议</font>**<font style="color:rgb(0, 0, 0);">：</font>

+ <font style="color:rgb(0, 0, 0);">若需</font>**<font style="color:rgb(0, 0, 0);">基础流量入口</font>**<font style="color:rgb(0, 0, 0);">（如暴露静态网站、单个Service），选</font>**<font style="color:rgb(0, 0, 0);">Ingress-Nginx</font>**<font style="color:rgb(0, 0, 0);">；</font>
+ <font style="color:rgb(0, 0, 0);">若需</font>**<font style="color:rgb(0, 0, 0);">微服务的自动服务发现</font>**<font style="color:rgb(0, 0, 0);">（如K8s集群中的多个Service），选</font>**<font style="color:rgb(0, 0, 0);">Traefik</font>**<font style="color:rgb(0, 0, 0);">；</font>
+ <font style="color:rgb(0, 0, 0);">若需</font>**<font style="color:rgb(0, 0, 0);">高级API管理</font>**<font style="color:rgb(0, 0, 0);">（如灰度发布、限流、认证）或</font>**<font style="color:rgb(0, 0, 0);">多协议支持</font>**<font style="color:rgb(0, 0, 0);">（如gRPC、Dubbo），选</font>**<font style="color:rgb(0, 0, 0);">APISIX</font>**<font style="color:rgb(0, 0, 0);">。</font>

