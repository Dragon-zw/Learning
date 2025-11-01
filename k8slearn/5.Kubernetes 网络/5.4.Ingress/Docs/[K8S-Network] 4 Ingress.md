前面我们学习了在 Kubernetes 集群内部使用 kube-dns 实现服务发现的功能，那么我们部署在 Kubernetes 集群中的应用如何暴露给外部的用户使用呢？我们知道可以使用 `<font style="color:#DF2A3F;">NodePort</font>`<font style="color:#DF2A3F;"> </font>和 `<font style="color:#DF2A3F;">LoadBlancer</font>`<font style="color:#DF2A3F;"> </font>类型的 Service 可以把应用暴露给外部用户使用，除此之外，Kubernetes 还为我们提供了一个非常重要的资源对象可以用来暴露服务给外部用户，那就是 `<font style="color:#DF2A3F;">Ingress</font>`。对于小规模的应用我们使用 NodePort 或许能够满足我们的需求，但是当你的应用越来越多的时候，你就会发现对于 NodePort 的管理就非常麻烦了，这个时候使用 Ingress 就非常方便了，可以避免管理大量的端口。

<font style="color:rgb(0, 0, 0);">Ingress 可以提供外网访问 Service 的能力。可以把某个请求地址映射、路由到特定的 service。</font>

<font style="color:rgb(0, 0, 0);">Ingress 需要配合 Ingress controller 一起使用才能发挥作用，Ingress 只是相当于路由规则的集合而已，真正实现路由功能的，是 Ingress Controller，Ingress Controller 和其它 k8s 组件一样，也是在 Pod 中运行。</font>

<font style="color:rgb(0, 0, 0);">Ingress Controller 建议部署在同一个节点当中。</font>

:::color1
<font style="color:rgb(39, 41, 42);">通常暴露 Service 到外部网络使用 Ingress Nginx 七层负载均衡。</font>

⚓<font style="color:rgb(39, 41, 42);">Service 是用于服务内部的网络共享，Ingress 是用于外部服务的发现，外部服务的统一入口。建议 Ingress 部署在同一个节点中。</font>

:::

<font style="color:rgb(0, 0, 0);">Ingress Controller 有多种实现方式，例如 </font><font style="color:rgb(18, 18, 18);">NGINX、HAproxy、Traefik、Envoy、Higress、Istio 等均可以达到 </font><font style="color:rgb(0, 0, 0);">Ingress 的能力。</font>

![](https://cdn.nlark.com/yuque/0/2023/png/2555283/1684174998308-f1add435-a3ca-42cc-91cb-084c0c267a48.png)

<font style="color:rgb(39, 41, 42);">传统网络架构</font>

![](https://cdn.nlark.com/yuque/0/2023/png/2555283/1690613027668-16239b4d-e3dc-4d0b-87bb-20bf26516cc2.png)

:::color1
🚀<font style="color:rgb(39, 41, 42);">Ingress 大家可以理解为也是一种 </font>`<font style="color:rgb(39, 41, 42);">LB(LoadBalancer)</font>`<font style="color:rgb(39, 41, 42);"> 的抽象，它的实现也是支持 nginx、haproxy 以及流行的 Istio、Traefik 等负载均衡服务的。</font>

:::

Kubernetes 网络架构

![](https://cdn.nlark.com/yuque/0/2023/png/2555283/1690613017140-47115737-567c-4b09-8013-aa6e1a94b7cc.png)

💡**<font style="color:rgb(51, 51, 51);">为什么需要Ingress？</font>**

+ <font style="color:rgb(51, 51, 51);">Service 可以使用 NodePort 暴露集群外访问端口，但是性能低下不安全。并且有NodePort 端口使用范围有限</font><font style="color:#601BDE;">[ 30000 - 32767 ]</font>
+ <font style="color:rgb(51, 51, 51);">缺少</font>**<font style="color:rgb(51, 51, 51);">Layer7( </font>****<font style="color:#601BDE;">应用层：可以拆解出数据协议包，根据请求头，路径等贴近于业务的负载均衡服务</font>****<font style="color:rgb(51, 51, 51);"> )</font>**<font style="color:rgb(51, 51, 51);">的统一访问入口，可以负载均衡、限流等；</font>
+ [Ingress](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.21/#ingress-v1beta1-networking-k8s-io)<font style="color:rgb(51, 51, 51);"> 公开了从集群外部到集群内</font>[服务](https://kubernetes.io/zh/docs/concepts/services-networking/service/)<font style="color:rgb(51, 51, 51);">的 HTTP 和 HTTPS 路由。 流量路由由 Ingress 资源上定义的规则控制。</font>
+ <font style="color:rgb(51, 51, 51);">我们使用 Ingress 作为整个集群统一的入口，配置 Ingress 规则转到对应的 Service</font>

:::success
在 Java 开发人员来说，面向对象的设计中，开发人员要尽可能的依赖抽象，而不是依赖实现

:::

![](https://cdn.nlark.com/yuque/0/2022/png/2555283/1670253745184-928b7744-9684-4bce-883d-460070d31135.png)

## 1 资源对象
`<font style="color:#DF2A3F;">Ingress</font>`<font style="color:#DF2A3F;"> </font>资源对象是 Kubernetes 内置定义的一个对象，是从 Kuberenets 集群外部访问集群的一个入口，将外部的请求转发到集群内不同的 Service 上，其实就相当于 nginx、haproxy 等负载均衡代理服务器，可能你会觉得我们直接使用 nginx 就实现了，但是只使用 nginx 这种方式有很大缺陷，每次有新服务加入的时候怎么改 Nginx 配置？不可能让我们去手动更改或者滚动更新前端的 Nginx Pod 吧？那我们再加上一个服务发现的工具比如 consul 如何？貌似是可以，对吧？Ingress 实际上就是这样实现的，只是服务发现的功能自己实现了，不需要使用第三方的服务了，然后再加上一个域名规则定义，路由信息的刷新依靠 Ingress Controller 来提供。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570504746-7c4503ee-1b2a-463b-8421-f8857461dd0f.png)

Ingress Controller 可以理解为一个监听器，通过不断地监听 kube-apiserver，实时的感知后端 Service、Pod 的变化，当得到这些信息变化后，Ingress Controller 再结合 Ingress 的配置，更新反向代理负载均衡器，达到服务发现的作用。其实这点和服务发现工具 consul、 consul-template 非常类似。

## 2 定义
一个常见的 Ingress 资源清单如下所示：

```yaml
# demo-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
    - http:
        paths:
          - path: /testpath
            pathType: Prefix
            backend:
              service:
                name: test
                port:
                  number: 80
```

上面这个 Ingress 资源的定义，配置了一个路径为 `<font style="color:#DF2A3F;">/testpath</font>` 的路由，所有 `<font style="color:#DF2A3F;">/testpath/**</font>` 的入站请求，会被 Ingress 转发至名为 test 的服务的 80 端口的 `<font style="color:#DF2A3F;">/</font>` 路径下。可以将 Ingress 狭义的理解为 Nginx 中的配置文件 `<font style="color:#DF2A3F;">nginx.conf</font>`。

此外 Ingress 经常使用注解 `<font style="color:#DF2A3F;">annotations</font>` 来配置一些选项，当然这具体取决于 Ingress 控制器的实现方式，不同的 Ingress 控制器支持不同的注解。

另外需要注意的是当前集群版本是 `<font style="color:#DF2A3F;">v1.22</font>`，这里使用的 `<font style="color:#DF2A3F;">apiVersion</font>` 是 `<font style="color:#DF2A3F;">networking.k8s.io/v1</font>`，所以如果是之前版本的 Ingress 资源对象需要进行迁移。 Ingress 资源清单的描述我们可以使用 `<font style="color:#DF2A3F;">kubectl explain</font>` 命令来了解：

```shell
➜ kubectl explain ingress.spec
KIND:     Ingress
VERSION:  networking.k8s.io/v1

RESOURCE: spec <Object>

DESCRIPTION:
     Spec is the desired state of the Ingress. More info:
     https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#spec-and-status

     IngressSpec describes the Ingress the user wishes to exist.

FIELDS:
   defaultBackend       <Object>
     DefaultBackend is the backend that should handle requests that don't match
     any rule. If Rules are not specified, DefaultBackend must be specified. If
     DefaultBackend is not set, the handling of requests that do not match any
     of the rules will be up to the Ingress controller.

   ingressClassName     <string>
     IngressClassName is the name of the IngressClass cluster resource. The
     associated IngressClass defines which controller will implement the
     resource. This replaces the deprecated `kubernetes.io/ingress.class`
     annotation. For backwards compatibility, when that annotation is set, it
     must be given precedence over this field. The controller may emit a warning
     if the field and annotation have different values. Implementations of this
     API should ignore Ingresses without a class specified. An IngressClass
     resource may be marked as default, which can be used to set a default value
     for this field. For more information, refer to the IngressClass
     documentation.

   rules        <[]Object>
     A list of host rules used to configure the Ingress. If unspecified, or no
     rule matches, all traffic is sent to the default backend.

   tls  <[]Object>
     TLS configuration. Currently the Ingress only supports a single TLS port,
     443. If multiple members of this list specify different hosts, they will be
     multiplexed on the same port according to the hostname specified through
     the SNI TLS extension, if the ingress controller fulfilling the ingress
     supports SNI.
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760667172643-fcbaf3bb-6abd-4f8d-bd8c-f93cf282cba6.png)

从上面描述可以看出 Ingress 资源对象中有几个重要的属性：`<font style="color:#DF2A3F;">defaultBackend</font>`、`<font style="color:#DF2A3F;">ingressClassName</font>`、`<font style="color:#DF2A3F;">rules</font>`、`<font style="color:#DF2A3F;">tls</font>`。

### 2.1 rules
其中核心部分是 `<font style="color:#DF2A3F;">rules</font>`<font style="color:#DF2A3F;"> </font>属性的配置，每个路由规则都在下面进行配置：

+ `<font style="color:#DF2A3F;">host</font>`：可选字段，上面我们没有指定 host 属性，所以该规则适用于通过指定 IP 地址的所有入站 HTTP 通信，如果提供了 host 域名，则 `<font style="color:#DF2A3F;">rules</font>`<font style="color:#DF2A3F;"> </font>则会匹配该域名的相关请求，此外 `<font style="color:#DF2A3F;">host</font>`<font style="color:#DF2A3F;"> </font>主机名可以是精确匹配（例如 `<font style="color:#DF2A3F;">foo.bar.com</font>`）或者使用通配符来匹配（例如 `<font style="color:#DF2A3F;">*.foo.com</font>`）。
+ `<font style="color:#DF2A3F;">http.paths</font>`：定义访问的路径列表，比如上面定义的 `<font style="color:#DF2A3F;">/testpath</font>`，每个路径都有一个由 `<font style="color:#DF2A3F;">backend.service.name</font>` 和 `<font style="color:#DF2A3F;">backend.service.port.number</font>` 定义关联的 Service 后端，在控制器将流量路由到引用的服务之前，`<font style="color:#DF2A3F;">host</font>`<font style="color:#DF2A3F;"> </font>和 `<font style="color:#DF2A3F;">path</font>`<font style="color:#DF2A3F;"> </font>都必须匹配传入的请求才行。
+ `<font style="color:#DF2A3F;">backend</font>`：该字段其实就是用来定义后端的 Service 服务的，与路由规则中 `<font style="color:#DF2A3F;">host</font>` 和 `<font style="color:#DF2A3F;">path</font>`<font style="color:#DF2A3F;"> </font>匹配的流量会将发送到对应的 backend 后端去。

此外一般情况下在 Ingress 控制器中会配置一个 `<font style="color:#DF2A3F;">defaultBackend</font>`<font style="color:#DF2A3F;"> </font>默认后端，当请求不匹配任何 Ingress 中的路由规则的时候会使用该后端。`<font style="color:#DF2A3F;">defaultBackend</font>`<font style="color:#DF2A3F;"> </font>通常是 Ingress 控制器的配置选项，而非在 Ingress 资源中指定。

### 2.2 Resource
`<font style="color:#DF2A3F;">backend</font>`<font style="color:#DF2A3F;"> </font>后端除了可以引用一个 Service 服务之外，还可以通过一个 `<font style="color:#DF2A3F;">resource</font>`<font style="color:#DF2A3F;"> </font>资源进行关联，`<u><font style="color:#DF2A3F;">Resource</font></u>`<u><font style="color:#DF2A3F;"> </font></u><u>是当前 Ingress 对象命名空间下引用的另外一个 Kubernetes 资源对象</u>，但是💡<u>需要注意的是 </u>`<u><font style="color:#DF2A3F;">Resource</font></u>`<u><font style="color:#DF2A3F;"> </font></u><u>与 </u>`<u><font style="color:#DF2A3F;">Service</font></u>`<u><font style="color:#DF2A3F;"> </font></u><u>配置是互斥的，只能配置一个</u>，`<font style="color:#DF2A3F;">Resource</font>`<font style="color:#DF2A3F;"> </font>后端的一种常见用法是将所有入站数据导向带有静态资产的对象存储后端，如下所示：

```yaml
# ingress-resource-backend.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-resource-backend
spec:
  rules:
    - http:
        paths:
          - path: /icons
            pathType: ImplementationSpecific
            backend:
              resource:
                apiGroup: k8s.example.com
                kind: StorageBucket
                name: icon-assets
```

该 Ingress 资源对象描述了所有的 `<font style="color:#DF2A3F;">/icons</font>` 请求会被路由到同命名空间下的名为 `<font style="color:#DF2A3F;">icon-assets</font>` 的 `<font style="color:#DF2A3F;">StorageBucket</font>`<font style="color:#DF2A3F;"> </font>资源中去进行处理。

### 2.3 pathType
上面的示例中在定义路径规则的时候都指定了一个 `<font style="color:#DF2A3F;">pathType</font>`<font style="color:#DF2A3F;"> </font>的字段，事实上每个路径都需要有对应的路径类型，当前支持的路径类型有三种：

+ `<font style="color:#DF2A3F;">ImplementationSpecific</font>`：该路径类型的匹配方法取决于 `<font style="color:#DF2A3F;">IngressClass</font>`，具体实现可以将其作为单独的 `<font style="color:#DF2A3F;">pathType</font>` 处理或者与 `<font style="color:#DF2A3F;">Prefix</font>`<font style="color:#DF2A3F;"> </font>或 `<font style="color:#DF2A3F;">Exact</font>`<font style="color:#DF2A3F;"> </font>类型作相同处理。
+ `<font style="color:#DF2A3F;">Exact</font>`：精确匹配 URL 路径，且区分大小写。
+ `<font style="color:#DF2A3F;">Prefix</font>`：基于以 `<font style="color:#DF2A3F;">/</font>` 分隔的 URL 路径前缀匹配，匹配区分大小写，并且对路径中的元素逐个完成，路径元素指的是由 `<font style="color:#DF2A3F;">/</font>` 分隔符分隔的路径中的标签列表。

`<font style="color:#DF2A3F;">Exact</font>`<font style="color:#DF2A3F;"> </font>比较简单，就是需要精确匹配 URL 路径，对于 `<font style="color:#DF2A3F;">Prefix</font>`<font style="color:#DF2A3F;"> </font>前缀匹配，需要注意如果路径的最后一个元素是请求路径中最后一个元素的子字符串，则不会匹配，例如 `<font style="color:#DF2A3F;">/foo/bar</font>` 可以匹配 `<font style="color:#DF2A3F;">/foo/bar/baz</font>`, 但不匹配 `<font style="color:#DF2A3F;">/foo/barbaz</font>`，可以查看下表了解更多的匹配场景（来自官网）：

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570496165-6e54adad-2411-45a9-8f6c-8af52d9a1812.png)

在某些情况下，Ingress 中的多条路径会匹配同一个请求，这种情况下最长的匹配路径优先，如果仍然有两条同等的匹配路径，则精确路径类型优先于前缀路径类型。

### 2.4 IngressClass
Kubernetes 1.18 起，正式提供了一个 `<font style="color:#DF2A3F;">IngressClass</font>`<font style="color:#DF2A3F;"> </font>资源，作用与 `<font style="color:#DF2A3F;">kubernetes.io/ingress.class</font>` 注解`<font style="color:#DF2A3F;">Annotation</font>`类似，因为可能在集群中有多个 Ingress 控制器，可以通过该对象来定义我们的控制器，例如：

```yaml
# IngressClass-external-lb.yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: external-lb
spec:
  controller: nginx-ingress-internal-controller
  parameters:
    apiGroup: k8s.example.com
    kind: IngressParameters
    name: external-lb
```

其中重要的属性是 `<font style="color:#DF2A3F;">metadata.name</font>` 和 `<font style="color:#DF2A3F;">spec.controller</font>`，前者是这个 `<font style="color:#DF2A3F;">IngressClass</font>`<font style="color:#DF2A3F;"> </font>的名称，需要设置在 Ingress 中，后者是 Ingress 控制器的名称。

Ingress 中的 `<font style="color:#DF2A3F;">spec.ingressClassName</font>` 属性就可以用来指定对应的 `<font style="color:#DF2A3F;">IngressClass</font>`<font style="color:#DF2A3F;"> </font>，并进而由 `<font style="color:#DF2A3F;">IngressClass</font>`<font style="color:#DF2A3F;"> </font> 关联到对应的 Ingress 控制器，如：

```yaml
# Ingress-myapp.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
spec:
  ingressClassName: external-lb # 上面定义的 IngressClass 对象名称
  defaultBackend:
    service:
      name: myapp
      port:
        number: 80
```

不过需要注意的是 `<font style="color:#DF2A3F;">spec.ingressClassName</font>` 与老版本的 `<font style="color:#DF2A3F;">kubernetes.io/ingress.class</font>` 注解的作用并不完全相同，因为 `<font style="color:#DF2A3F;">ingressClassName</font>`<font style="color:#DF2A3F;"> </font>字段引用的是 `<font style="color:#DF2A3F;">IngressClass</font>` 资源的名称，`<font style="color:#DF2A3F;">IngressClass</font>`<font style="color:#DF2A3F;"> </font>资源中除了指定了 Ingress 控制器的名称之外，还可能会通过 `<font style="color:#DF2A3F;">spec.parameters</font>` 属性定义一些额外的配置。

比如 `<font style="color:#DF2A3F;">parameters</font>`<font style="color:#DF2A3F;"> </font>字段有一个 `<font style="color:#DF2A3F;">scope</font>`<font style="color:#DF2A3F;"> </font>和 `<font style="color:#DF2A3F;">namespace</font>`<font style="color:#DF2A3F;"> </font>字段，可用来引用特定于命名空间的资源，对 Ingress 类进行配置。 `<font style="color:#DF2A3F;">scope</font>`<font style="color:#DF2A3F;"> </font>字段默认为 `<font style="color:#DF2A3F;">Cluster</font>`，表示默认是集群作用域的资源。将 `<font style="color:#DF2A3F;">scope</font>`<font style="color:#DF2A3F;"> </font>设置为 `<font style="color:#DF2A3F;">Namespace</font>`<font style="color:#DF2A3F;"> </font>并设置 `<font style="color:#DF2A3F;">namespace</font>`<font style="color:#DF2A3F;"> </font>字段就可以引用某特定命名空间中的参数资源，比如：

```yaml
# IngressClass-external-lb.yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: external-lb
spec:
  controller: nginx-ingress-internal-controller
  parameters:
    apiGroup: k8s.example.com
    kind: IngressParameters
    name: external-lb
    namespace: external-configuration
    scope: Namespace
```

由于一个集群中可能有多个 Ingress 控制器，所以我们还可以将一个特定的 `<font style="color:#DF2A3F;">IngressClass</font>`<font style="color:#DF2A3F;"> </font>对象标记为集群默认是 Ingress 类。只需要将一个 IngressClass 资源的 `<font style="color:#DF2A3F;">ingressclass.kubernetes.io/is-default-class</font>` 注解设置为 true 即可，这样未指定 `<font style="color:#DF2A3F;">ingressClassName</font>`<font style="color:#DF2A3F;"> </font>字段的 Ingress 就会使用这个默认的 IngressClass。

如果集群中有多个 `<font style="color:#DF2A3F;">IngressClass</font>`<font style="color:#DF2A3F;"> </font>被标记为默认，准入控制器将阻止创建新的未指定 `<font style="color:#DF2A3F;">ingressClassName</font>`<font style="color:#DF2A3F;"> </font>的 Ingress 对象。最好的方式还是确保集群中最多只能有一个 `<font style="color:#DF2A3F;">IngressClass</font>`<font style="color:#DF2A3F;"> </font>被标记为默认。

### 2.5 TLS
Ingress 资源对象还可以用来配置 HTTPS 的服务，可以通过设定包含 TLS 私钥和证书的 Secret 来保护 Ingress。 Ingress 只支持单个 TLS 端口 443，如果 Ingress 中的 TLS 配置部分指定了不同的主机，那么它们将根据通过 SNI TLS 扩展指定的主机名 （如果 Ingress 控制器支持 SNI）在同一端口上进行复用。需要注意 TLS Secret 必须包含名为 `<font style="color:#DF2A3F;">tls.crt</font>` 和 `<font style="color:#DF2A3F;">tls.key</font>` 的键名，例如：

```yaml
# Secret-testsecret-tls.yaml
apiVersion: v1
kind: Secret
metadata:
  name: testsecret-tls
  namespace: default
data:
  tls.crt: <base64 编码的 cert>
  tls.key: <base64 编码的 key>
type: kubernetes.io/tls
```

在 Ingress 中引用此 Secret 将会告诉 Ingress 控制器使用 TLS 加密从客户端到负载均衡器的通道，我们需要确保创建的 TLS Secret 创建自包含 `<font style="color:#DF2A3F;">https-example.foo.com</font>` 的公用名称的证书，如下所示：

```yaml
# tls-example-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-example-ingress
spec:
  tls:
    - hosts:
        - https-example.foo.com
      secretName: testsecret-tls
  rules:
    - host: https-example.foo.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: service1
                port:
                  number: 80
```

现在我们了解了如何定义 Ingress 资源对象了，但是仅创建 Ingress 资源本身没有任何效果。还需要部署 Ingress 控制器，例如 `<font style="color:#DF2A3F;">ingress-nginx</font>`，现在可以供大家使用的 Ingress 控制器有很多，比如 traefik、nginx-controller、Kubernetes Ingress Controller for Kong、HAProxy Ingress controller，当然你也可以自己实现一个 Ingress Controller，现在普遍用得较多的是 traefik 和 ingress-nginx，traefik 的性能比 ingress-nginx 差，但是配置使用要简单许多，我们这里会重点给大家介绍 `<font style="color:#DF2A3F;">ingress-nginx</font>`、`<font style="color:#DF2A3F;">traefik</font>` 以及 `<font style="color:#DF2A3F;">apisix</font>` 的使用。

实际上社区目前还在开发一组高配置能力的 API，被称为 [Service API](https://gateway-api.sigs.k8s.io/)，新 API 会提供一种 Ingress 的替代方案，它的存在目的不是替代 Ingress，而是提供一种更具配置能力的新方案。

