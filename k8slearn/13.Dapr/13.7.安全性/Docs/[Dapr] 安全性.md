<font style="color:rgb(28, 30, 33);">安全是 Dapr 的基础，本章节我们将来说明在分布式应用中使用 Dapr 时的安全特性和能力，主要可以分为以下几个方面。</font>

+ <font style="color:rgb(28, 30, 33);">与服务调用和</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">pub/sub</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">APIs 的安全通信。</font>
+ <font style="color:rgb(28, 30, 33);">组件上的安全策略并通过配置进行应用。</font>
+ <font style="color:rgb(28, 30, 33);">运维操作安全实践。</font>
+ <font style="color:rgb(28, 30, 33);">状态安全，专注于静态的数据。</font>

<font style="color:rgb(28, 30, 33);">Dapr 通过服务调用 API 提供端到端的安全性，能够使用 Dapr 对应用程序进行身份验证并设置端点访问策略。</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1730396803406-c57c6b38-db3e-44bd-9e20-c68beb2ff04a.png)

## <font style="color:rgb(28, 30, 33);">1 服务调用范围访问策略</font>
**<font style="color:rgb(28, 30, 33);">跨命名空间的服务调用</font>**

<font style="color:rgb(28, 30, 33);">Dapr 应用程序可以被限定在特定的命名空间，以实现部署和安全，当然我们仍然可以在部署到不同命名空间的服务之间进行调用。默认情况下，服务调用支持通过简单地引用应用 ID (比如</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">nodeapp</font>`<font style="color:rgb(28, 30, 33);">) 来调用同一命名空间内的服务：</font>

```bash
localhost:3500/v1.0/invoke/nodeapp/method/neworder
```

<font style="color:rgb(28, 30, 33);">服务调用还支持跨命名空间的调用，在所有受支持的托管平台上，Dapr 应用程序 ID 符合包含目标命名空间的有效</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">FQDN</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">格式，可以同时指定：</font>

+ <font style="color:rgb(28, 30, 33);">应用 ID (如</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">nodeapp</font>`<font style="color:rgb(28, 30, 33);">)</font>
+ <font style="color:rgb(28, 30, 33);">应用程序运行的命名空间（</font>`<font style="color:rgb(28, 30, 33);">production</font>`<font style="color:rgb(28, 30, 33);">）。</font>

<font style="color:rgb(28, 30, 33);">比如在</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">production</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">命名空间中的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">nodeapp</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">应用上调用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">neworder</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">方法，则可以使用下面的方式：</font>

```bash
localhost:3500/v1.0/invoke/nodeapp.production/method/neworder
```

<font style="color:rgb(28, 30, 33);">当使用服务调用在命名空间中调用应用程序时，我们可以使用命名空间对其进行限定，特别在 Kubernetes 集群中的跨命名空间调用是非常有用的。</font>

**<font style="color:rgb(28, 30, 33);">为服务调用应用访问控制列表配置</font>**

<font style="color:rgb(28, 30, 33);">访问控制可以配置策略，限制调用应用程序可以通过服务调用对被调用的应用程序执行哪些操作（比如允许或拒绝）。要限制特定操作对被调用应用程序的访问以及调用应用程序对 HTTP verbs 的访问，我们可以在配置中定义一个访问控制策略的规范。</font>

<font style="color:rgb(28, 30, 33);">访问控制策略在配置文件中被指定，并被应用于被调用应用程序的 Dapr sidecar，对被调用应用程序的访问是</font>**<font style="color:rgb(28, 30, 33);">基于匹配的策略动作</font>**<font style="color:rgb(28, 30, 33);">，你可以为所有调用应用程序提供一个默认的全局动作，如果没有指定访问控制策略，默认行为是允许所有调用应用程序访问被调用的应用程序。</font>

<font style="color:rgb(28, 30, 33);">在具体学习访问控制策略配置之前，我们需要先了解两个概念：</font>

+ `<font style="color:rgb(28, 30, 33);">TrustDomain</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">- “信任域”是管理信任关系的逻辑组。每个应用程序都分配有一个信任域，可以在访问控制列表策略规范中指定。如果未定义策略规范或指定了空的信任域，则使用默认值</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">public</font>`<font style="color:rgb(28, 30, 33);">，该信任域用于在 TLS 证书中生成应用程序的身份。</font>
+ `<font style="color:rgb(28, 30, 33);">App Identity</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">- Dapr 请求 sentry 服务为所有应用程序生成一个</font><font style="color:rgb(28, 30, 33);"> </font>[<font style="color:rgb(28, 30, 33);">SPIFFE id</font>](https://spiffe.io/)<font style="color:rgb(28, 30, 33);">，这个 id 附加在 TLS 证书中。SPIFFE id 的格式为：</font>`<font style="color:rgb(28, 30, 33);">spiffe://<trustdomain>/ns/<namespace>/<appid></font>`<font style="color:rgb(28, 30, 33);">，对于匹配策略，调用应用的信任域、命名空间和应用 ID 值从调用应用的 TLS 证书中的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">SPIFFE id</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">中提取，这些值与策略规范中指定的信任域、命名空间和应用 ID 值相匹配。如果这三个都匹配，则更具体的策略将进一步匹配。</font>

<font style="color:rgb(28, 30, 33);">访问控制策略会遵循如下所示的一些规则：</font>

+ <font style="color:rgb(28, 30, 33);">如果未指定访问策略，则默认行为是允许所有应用访问被调用应用上的所有方法</font>
+ <font style="color:rgb(28, 30, 33);">如果未指定全局默认操作且未定义应用程序特定策略，则将空访问策略视为未指定访问策略，并且默认行为是允许所有应用程序访问被调用应用程序上的所有方法</font>
+ <font style="color:rgb(28, 30, 33);">如果未指定全局默认操作，但已定义了一些特定于应用程序的策略，则会采用更安全的选项，即假设全局默认操作拒绝访问被调用应用程序上的所有方法</font>
+ <font style="color:rgb(28, 30, 33);">如果定义了访问策略并且无法验证传入的应用程序凭据，则全局默认操作将生效</font>
+ <font style="color:rgb(28, 30, 33);">如果传入应用的信任域或命名空间与应用策略中指定的值不匹配，则应用策略将被忽略并且全局默认操作生效</font>

<font style="color:rgb(28, 30, 33);">下面是一些使用访问控制列表进行服务调用的示例场景。</font>

<font style="color:rgb(28, 30, 33);">场景 1：拒绝所有应用程序的访问，除非</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">trustDomain = public</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">namespace = default</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">appId = app1</font>`<font style="color:rgb(28, 30, 33);">，使用如下所示的配置，允许所有</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">appId = app1</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">的调用方法，并拒绝来自其他应用程序的所有其他调用请求。</font>

```yaml
apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: appconfig
spec:
  accessControl:
    defaultAction: deny
    trustDomain: 'public'
    policies:
      - appId: app1
        defaultAction: allow
        trustDomain: 'public'
        namespace: 'default'
```

<font style="color:rgb(28, 30, 33);">场景 2：拒绝访问除</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">trustDomain = public</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">namespace = default</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">appId = app1</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">operation = op1</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">之外的所有应用程序，使用此配置仅允许来自</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">appId = app1</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">的方法</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">op1</font>`<font style="color:rgb(28, 30, 33);">，并且拒绝来自所有其他应用程序的所有其他方法请求，包括</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">app1</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">上的其他方法。</font>

```yaml
apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: appconfig
spec:
  accessControl:
    defaultAction: deny
    trustDomain: 'public'
    policies:
      - appId: app1
        defaultAction: deny
        trustDomain: 'public'
        namespace: 'default'
        operations:
          - name: /op1
            httpVerb: ['*']
            action: allow
```

<font style="color:rgb(28, 30, 33);">场景 3：拒绝对所有应用程序的访问，除非 HTTP 的特定 verb 和 GRPC 的操作匹配，使用如下所示的配置，仅允许以下场景访问，并且来自所有其他应用程序的所有其他方法请求（包括</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">app1</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">或</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">app2</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">上的其他方法）都会被拒绝。</font>

+ <font style="color:rgb(28, 30, 33);">trustDomain = public、namespace = default、appID = app1、operation = op1、http verb = POST/PUT</font>
+ <font style="color:rgb(28, 30, 33);">trustDomain = “myDomain”、namespace = “ns1”、appID = app2、operation = op2 并且应用程序协议是 GRPC，仅允许来自</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">appId = app1</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">的方法</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">op1</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">上的 POST/PUT 请求以及来自所有其他应用程序的所有其他方法请求，包括</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">app1</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">上的其他方法，被拒绝</font>

```yaml
apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: appconfig
spec:
  accessControl:
    defaultAction: deny
    trustDomain: 'public'
    policies:
      - appId: app1
        defaultAction: deny
        trustDomain: 'public'
        namespace: 'default'
        operations:
          - name: /op1
            httpVerb: ['POST', 'PUT']
            action: allow
      - appId: app2
        defaultAction: deny
        trustDomain: 'myDomain'
        namespace: 'ns1'
        operations:
          - name: /op2
            action: allow
```

<font style="color:rgb(28, 30, 33);">场景 4：允许访问除</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">trustDomain = public</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">namespace = default</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">appId = app1</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">operation = /op1/*</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">所有 http verb 之外的所有方法。</font>

```yaml
apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: appconfig
spec:
  accessControl:
    defaultAction: allow
    trustDomain: 'public'
    policies:
      - appId: app1
        defaultAction: allow
        trustDomain: 'public'
        namespace: 'default'
        operations:
          - name: /op1/*
            httpVerb: ['*']
            action: deny
```

<font style="color:rgb(28, 30, 33);">场景 5：允许访问</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">trustDomain = public</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">namespace = ns1</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">appId = app1</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">的所有方法并拒绝访问</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">trustDomain = public</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">namespace = ns2</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">appId = app1</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">的所有方法，此场景展示了如何指定具有相同应用 ID 但属于不同命名空间的应用。</font>

```yaml
apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: appconfig
spec:
  accessControl:
    defaultAction: allow
    trustDomain: 'public'
    policies:
      - appId: app1
        defaultAction: allow
        trustDomain: 'public'
        namespace: 'ns1'
      - appId: app1
        defaultAction: deny
        trustDomain: 'public'
        namespace: 'ns2'
```

<font style="color:rgb(28, 30, 33);">场景 6：允许访问除</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">trustDomain = public</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">namespace = default</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">appId = app1</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">operation = /op1/**/a</font>`<font style="color:rgb(28, 30, 33);">、所有 http 动词之外的所有方法。</font>

```yaml
apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: appconfig
spec:
  accessControl:
    defaultAction: allow
    trustDomain: 'public'
    policies:
      - appId: app1
        defaultAction: allow
        trustDomain: 'public'
        namespace: 'default'
        operations:
          - name: /op1/**/a
            httpVerb: ['*']
            action: deny
```

<font style="color:rgb(28, 30, 33);">下面我们通过一个具体的示例来展示下访问控制策略的使用，同样还是使用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">quickstarts</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">示例中的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">hello-world</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">进行说明。</font>

```bash
git clone [-b <dapr_version_tag>] https://github.com/dapr/quickstarts.git
cd quickstarts/tutorials/hello-world/node
```

![](https://cdn.nlark.com/yuque/0/2024/jpeg/2555283/1730396801233-4923ba3a-0bf8-423e-8c2a-3d4222e37872.jpeg)

<font style="color:rgb(28, 30, 33);">该示例应用中包含一个 python 应用去调用一个 node.js 应用程序，访问控制列表依靠 Dapr Sentry 服务来生成带有</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">SPIFFE id</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">的 TLS 证书进行认证，这意味着 Sentry 服务必须在本地运行或部署到你的托管环境，比如 Kubernetes 集群。</font>

<font style="color:rgb(28, 30, 33);">下面的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">nodeappconfig</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">例子显示了如何拒绝来自</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">pythonapp</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">neworder</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">方法的访问，其中</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">pythonapp</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">是在</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">myDomain</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">信任域和</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">default</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">命名空间中，</font>`<font style="color:rgb(28, 30, 33);">nodeapp</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">在</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">public</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">公共信任域中。</font>

```yaml
# nodeappconfig.yaml
apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: nodeappconfig
spec:
  tracing:
    samplingRate: '1'
  accessControl:
    defaultAction: allow
    trustDomain: 'public'
    policies:
      - appId: pythonapp
        defaultAction: allow
        trustDomain: 'myDomain'
        namespace: 'default'
        operations:
          - name: /neworder
            httpVerb: ['POST']
            action: deny
```

```yaml
# pythonappconfig.yaml
apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: pythonappconfig
spec:
  tracing:
    samplingRate: '1'
  accessControl:
    defaultAction: allow
    trustDomain: 'myDomain'
```

<font style="color:rgb(28, 30, 33);">接下来我们先在本地自拓管模式下来使用启用访问策略配置，首先需要在启用 mTLS 的情况下在本地运行 Sentry 服务，我们可以直接在</font><font style="color:rgb(28, 30, 33);"> </font>[<font style="color:rgb(28, 30, 33);">https://github.com/dapr/dapr/releases</font>](https://github.com/dapr/dapr/releases)<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">页面下载对应的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">sentry</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">二进制文件，比如我们这里是 Mac M1，则可以使用下面的命令直接下载：</font>

```bash
# wget https://github.91chi.fun/https://github.com/dapr/dapr/releases/download/v1.8.4/sentry_darwin_arm64.tar.gz
$ wget https://github.com/dapr/dapr/releases/download/v1.8.4/sentry_darwin_arm64.tar.gz
$ tar -xvf sentry_darwin_arm64.tar.gz
```

<font style="color:rgb(28, 30, 33);">然后为 Sentry 服务创建一个目录以创建自签名根证书：</font>

```bash
$ mkdir -p $HOME/.dapr/certs
```

<font style="color:rgb(28, 30, 33);">使用以下命令在本地运行 Sentry 服务：</font>

```bash
$ ./sentry --issuer-credentials $HOME/.dapr/certs --trust-domain cluster.local
INFO[0000] starting sentry certificate authority -- version 1.8.4 -- commit 18575823c74318c811d6cd6f57ffac76d5debe93  instance=MBP2022.local scope=dapr.sentry type=log ver=1.8.4
INFO[0000] configuration: [port]: 50001, [ca store]: default, [allowed clock skew]: 15m0s, [workload cert ttl]: 24h0m0s  instance=MBP2022.local scope=dapr.sentry.config type=log ver=1.8.4
WARN[0000] loading default config. couldn't find config name: daprsystem: stat daprsystem: no such file or directory  instance=MBP2022.local scope=dapr.sentry type=log ver=1.8.4
INFO[0000] starting watch on filesystem directory: /Users/cnych/.dapr/certs  instance=MBP2022.local scope=dapr.sentry type=log ver=1.8.4
INFO[0000] certificate authority loaded                  instance=MBP2022.local scope=dapr.sentry type=log ver=1.8.4
INFO[0000] root and issuer certs not found: generating self signed CA  instance=MBP2022.local scope=dapr.sentry.ca type=log ver=1.8.4
# ......
INFO[0000] sentry certificate authority is running, protecting ya'll  instance=MBP2022.local scope=dapr.sentry type=log ver=1.8.4
```

<font style="color:rgb(28, 30, 33);">运行成功后 Sentry 服务将在指定目录中创建根证书，可以通过如下所示的命令来配置环境变量指定相关证书路径：</font>

```bash
export DAPR_TRUST_ANCHORS=`cat $HOME/.dapr/certs/ca.crt`
export DAPR_CERT_CHAIN=`cat $HOME/.dapr/certs/issuer.crt`
export DAPR_CERT_KEY=`cat $HOME/.dapr/certs/issuer.key`
export NAMESPACE=default
```

<font style="color:rgb(28, 30, 33);">然后我们就可以运行</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">daprd</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">为启用了 mTLS 的 node.js 应用启动 Dapr sidecar，并引用本地的 Sentry 服务：</font>

```bash
daprd --app-id nodeapp --dapr-grpc-port 50002 -dapr-http-port 3501 -metrics-port 9091 --log-level debug --app-port 3000 --enable-mtls --sentry-address localhost:50001 --config nodeappconfig.yaml
```

<font style="color:rgb(28, 30, 33);">上面的命令我们通过</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">--enable-mtls</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">启用了 mTLS，通过</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">--config</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">指定了上面的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">nodeappconfig.yaml</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">这个配置文件。</font>

<font style="color:rgb(28, 30, 33);">然后启动 node.js 应用：</font>

```bash
$ cd node && yarn
$ node app.js

Node App listening on port 3000!
```

<font style="color:rgb(28, 30, 33);">同样的方式在另外的终端中设置环境变量：</font>

```bash
export DAPR_TRUST_ANCHORS=`cat $HOME/.dapr/certs/ca.crt`
export DAPR_CERT_CHAIN=`cat $HOME/.dapr/certs/issuer.crt`
export DAPR_CERT_KEY=`cat $HOME/.dapr/certs/issuer.key`
export NAMESPACE=default
```

<font style="color:rgb(28, 30, 33);">然后运行</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">daprd</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">为启用了 mTLS 的 python 应用启动 Dapr sidecar，并引用本地的 Sentry 服务：</font>

```bash
daprd --app-id pythonapp  --dapr-grpc-port 50003 --metrics-port 9092 --log-level debug --enable-mtls --sentry-address localhost:50001 --config pythonappconfig.yaml
```

<font style="color:rgb(28, 30, 33);">在重新开一个终端直接启动 Python 应用即可：</font>

```bash
$ cd python && pip3 install -r requirements.txt
$ python3 app.py

HTTP 403 => {"errorCode":"ERR_DIRECT_INVOKE","message":"fail to invoke, id: nodeapp, err: rpc error: code = PermissionDenied desc = access control policy has denied access to appid: pythonapp operation: neworder verb: POST"}
HTTP 403 => {"errorCode":"ERR_DIRECT_INVOKE","message":"fail to invoke, id: nodeapp, err: rpc error: code = PermissionDenied desc = access control policy has denied access to appid: pythonapp operation: neworder verb: POST"}
# ......
```

<font style="color:rgb(28, 30, 33);">由于</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">nodeappconfig</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">文件中我们配置了对</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">/neworder</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">接口的 POST 拒绝操作，所以应该会在 python 应用程序命令提示符中看到对 node.js 应用程序的调用失败，如果我们将上面的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">nodeappconfig</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">配置中的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">action: deny</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">修改为</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">action: allow</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">并重新运行应用程序，然后我们应该会看到此调用成功。</font>

<font style="color:rgb(28, 30, 33);">对于 Kubernetes 模式则更简单，只需要创建上述配置文件</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">nodeappconfig.yaml</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">和</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">pythonappconfig.yaml</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">并将其应用于 Kubernetes 集群，然后在应用的注解中添加</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">dapr.io/config: "pythonappconfig"</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">来指定配置即可开启服务访问控制。</font>

```yaml
annotations:
  dapr.io/enabled: 'true'
  dapr.io/app-id: 'pythonapp'
  dapr.io/config: 'pythonappconfig'
```

## <font style="color:rgb(28, 30, 33);">2 Pub/sub 主题范围访问策略</font>
<font style="color:rgb(28, 30, 33);">对于</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">Pub/sub</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">组件，你可以限制允许哪些主题类型和应用程序发布和订阅特定主题。</font>

<font style="color:rgb(28, 30, 33);">命名空间或组件范围可用于限制组件对特定应用程序的访问，这些添加到组件的应用程序范围仅限制具有特定 ID 的应用程序能够使用该组件。如下所示显示了如何将两个启用 Dapr 的应用程序（应用程序 ID 为</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">app1</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">和</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">app2</font>`<font style="color:rgb(28, 30, 33);">）授予名为</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">statestore</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">的 Redis 组件，该组件本身位于</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">production</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">命名空间中：</font>

```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: statestore
  namespace: production
spec:
  type: state.redis
  version: v1
  metadata:
    - name: redisHost
      value: redis-master:6379
scopes:
  - app1
  - app2
```

<font style="color:rgb(28, 30, 33);">除了这个通用组件的 scopes 范围之外，发布/订阅组件还可以限制以下内容：</font>

+ <font style="color:rgb(28, 30, 33);">可以使用哪些主题（发布或订阅）</font>
+ <font style="color:rgb(28, 30, 33);">允许哪些应用发布到特定主题</font>
+ <font style="color:rgb(28, 30, 33);">允许哪些应用订阅特定主题</font>

<font style="color:rgb(28, 30, 33);">这被称为</font>**<font style="color:rgb(28, 30, 33);">发布/订阅主题范围</font>**<font style="color:rgb(28, 30, 33);">。我们可以为每个发布/订阅组件定义发布/订阅范围，比如你可能有一个名为</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">pubsub</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">的 pub/sub 组件，它具有一组范围，另一个</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">pubsub2</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">具有另外不同的范围。</font>

<font style="color:rgb(28, 30, 33);">示例 1：主题访问范围。如果你的主题包含敏感信息并且仅允许你的应用程序的子集发布或订阅这些信息，那么限制哪些应用程序可以发布/订阅主题可能会很有用。如下以下是三个应用程序和三个主题的示例：</font>

```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: pubsub
spec:
  type: pubsub.redis
  version: v1
  metadata:
    - name: redisHost
      value: 'localhost:6379'
    - name: redisPassword
      value: ''
    - name: publishingScopes
      value: 'app1=topic1;app2=topic2,topic3;app3='
    - name: subscriptionScopes
      value: 'app2=;app3=topic1'
```

<font style="color:rgb(28, 30, 33);">这里我们设置了</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">publishingScopes</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">和</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">subscriptionScopes</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">两个属性，分别用于配置发布范围和订阅范围。要拒绝应用发布到任何主题，请将主题列表留空，比如我们这里配置的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">app1=topic1;app2=topic2,topic3;app3=</font>`<font style="color:rgb(28, 30, 33);">，其中的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">app3=</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">就表示该应用不允许发布到任何主题上去。</font>

<font style="color:rgb(28, 30, 33);">根据我们的配置下表显示了允许哪些应用程序发布到主题中：</font>

|  | **Topic1** | **Topic2** | **Topic3** |
| --- | --- | --- | --- |
| app1 | X |  |  |
| app2 |  | X | X |
| app3 |  |  |  |


<font style="color:rgb(28, 30, 33);">下表显示了哪些应用程序可以订阅主题：</font>

|  | **Topic1** | **Topic2** | **Topic3** |
| --- | --- | --- | --- |
| app1 | X | X | X |
| app2 |  |  |  |
| app3 | X |  |  |


注意：如果未列出应用程序（例如，`subscriptionScopes` 中的 `app1`），则允许它订阅所有主题。因为不使用 `allowedTopics` 并且 `app1` 没有任何订阅范围，所以它也可以使用上面未列出的其他主题。

<font style="color:rgb(28, 30, 33);">示例 2：限制允许的主题。如果 Dapr 应用程序向其发送消息，则会创建一个主题，在某些情况下，应管理此主题的创建。例如：</font>

+ <font style="color:rgb(28, 30, 33);">Dapr 应用程序中生成主题名称的错误可能导致创建无限数量的主题</font>
+ <font style="color:rgb(28, 30, 33);">精简主题名称和总数，防止主题无限增长</font>

<font style="color:rgb(28, 30, 33);">在这些情况下，可以使用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">allowedTopics</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">属性进行配置，以下就是三个允许主题的示例：</font>

```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: pubsub
spec:
  type: pubsub.redis
  version: v1
  metadata:
    - name: redisHost
      value: 'localhost:6379'
    - name: redisPassword
      value: ''
    - name: allowedTopics
      value: 'topic1,topic2,topic3'
```

<font style="color:rgb(28, 30, 33);">示例 3：组合 allowedTopics 和范围。有时你想结合这两个范围，因此只有一组固定的允许主题并为某些应用程序指定范围。以下是三个应用程序和两个主题的示例：</font>

```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: pubsub
spec:
  type: pubsub.redis
  version: v1
  metadata:
    - name: redisHost
      value: 'localhost:6379'
    - name: redisPassword
      value: ''
    - name: allowedTopics
      value: 'A,B'
    - name: publishingScopes
      value: 'app1=A'
    - name: subscriptionScopes
      value: 'app1=;app2=A'
```

注意这里我们没有列出第三个应用程序，如果没有在范围内指定应用程序，则允许它使用所有主题。

<font style="color:rgb(28, 30, 33);">根据上面的配置下表显示了允许哪个应用程序发布到主题中：</font>

|  | **A** | **B** | **C** |
| --- | :--- | --- | --- |
| app1 | X |  |  |
| app2 | X | X |  |
| app3 | X | X |  |


<font style="color:rgb(28, 30, 33);">下表显示了允许哪个应用程序订阅主题：</font>

|  | **A** | **B** | **C** |
| --- | --- | --- | --- |
| app1 |  |  |  |
| app2 | X |  |  |
| app3 | X | X |  |


## <font style="color:rgb(28, 30, 33);">3 Secret 范围访问策略</font>
<font style="color:rgb(28, 30, 33);">要限制 Dapr 应用程序对 Secret 的访问，我们可以定义 Secret 范围，将 Secret 范围策略添加到具有限制性权限的应用程序配置。</font>

<font style="color:rgb(28, 30, 33);">除了限定哪些应用程序可以访问一个指定的组件，例如一个 secret store 组件，一个命名的 secret store 组件本身可以被限定为一个或多个应用程序的 Secret，通过定义</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">allowedSecrets</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">和或</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">deniedSecrets</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">属性，应用程序可以被限制为只能访问特定的 Secret，如下所示：</font>

```yaml
secrets:
  scopes:
    - storeName: kubernetes
      defaultAccess: allow
      allowedSecrets: ['redis-password']
    - storeName: localstore
      defaultAccess: allow
      deniedSecrets: ['redis-password']
```

<font style="color:rgb(28, 30, 33);">下表列出了 secrets 范围的属性：</font>

| **属性** | **类型** | **描述** |
| :--- | :--- | :--- |
| `storeName` | string | Secret Store 组件的名称，`storeName`<br/> 在列表中必须是唯一的。 |
| `defaultAccess` | string | 访问修饰符，接受值 “allow” (默认) 或者 “deny”。 |
| `allowedSecrets` | list | 可以访问的 Secret 列表。 |
| `deniedSecrets` | list | 不能访问的 Secret 列表。 |


<font style="color:rgb(28, 30, 33);">当</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">allowedSecrets</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">列表存在至少一个元素时，应用程序只能访问列表中定义的那些 Secret。</font>

## <font style="color:rgb(28, 30, 33);">4 保护 Dapr 到 Dapr 的通信</font>
<font style="color:rgb(28, 30, 33);">在 Dapr 中不需要额外的代码或者复杂的配置即可启用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">mTLS</font>`<font style="color:rgb(28, 30, 33);">，Dapr sidecars 默认情况下会阻止除</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">localhost</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">之外的所有 IP 地址调用它，当然可以明确配置。</font>`<font style="color:rgb(28, 30, 33);">mTLS</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">会为 Dapr sidecars 之间的流量提供传输中的加密，为了实现这一点，Dapr 会使用 Sentry 系统服务，该服务充当证书颁发机构 (CA)或身份提供者，并对源自 Dapr sidecar 的工作负载证书请求进行签名。</font>

<font style="color:rgb(28, 30, 33);">默认情况下，工作负载证书的有效期为 24 小时，时钟偏差设置为 15 分钟。除非你提供了现有的根证书，否则 Sentry 服务会自动创建并保留有效期为一年的自签名根证书。 Dapr 会自己管理工作负载证书轮换；如果你使用的是自己的证书，Dapr 会以零停机对应用程序执行此操作。</font>

<font style="color:rgb(28, 30, 33);">当根证书被替换时（在 Kubernetes 模式下是 Secret 对象，在自托管模式下是文件系统），Sentry 服务会获取它们并重建信任链，无需重启，对 Sentry 来说是零停机。</font>

<font style="color:rgb(28, 30, 33);">当一个新的 Dapr sidecar 初始化时，它会检查是否启用了 mTLS，如果是，则会生成 ECDSA 私钥和证书签名请求，并通过 gRPC 接口发送到 Sentry 服务，Dapr sidecar 和 Sentry 之间的通信使用信任链证书进行身份验证，该证书由 Dapr Sidecar Injector 系统服务注入到每个 Dapr 实例中。</font>

**<font style="color:rgb(28, 30, 33);">配置 mTLS</font>**

<font style="color:rgb(28, 30, 33);">我们可以通过配置对象中的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">spec.mtls.enabled</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">字段来配置是否开启</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">mTLS</font>`<font style="color:rgb(28, 30, 33);">，如下所示：</font>

```yaml
apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: daprsystem
  namespace: dapr-system
spec:
  metric:
    enabled: true
  mtls:
    allowedClockSkew: 15m
    enabled: true
    workloadCertTTL: 24h
```

<font style="color:rgb(28, 30, 33);">下图显示了 Sentry 系统服务如何根据运维人员提供的或由 Sentry 服务生成的存储在文件中的根/颁发者证书为应用程序颁发证书。</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1730396801101-2094cef1-92da-4285-8387-bf59ce5c99d6.png)

<font style="color:rgb(28, 30, 33);">在 Kubernetes 集群中，保存根证书的 Secret 是：</font>

+ <font style="color:rgb(28, 30, 33);">作用于部署 Dapr 组件的命名空间</font>
+ <font style="color:rgb(28, 30, 33);">只能由 Dapr 控制平面系统 pod 访问</font>

<font style="color:rgb(28, 30, 33);">Dapr 在 Kubernetes 上部署时还支持强身份，依赖于作为证书签名请求 (CSR) 的一部分发送到 Sentry 的 pod 的服务帐户令牌。下图展示了 Sentry 系统服务如何根据运维人员提供的或由 Sentry 服务生成并存储为 Kubernetes Secret 的根/颁发者证书为应用程序颁发证书。</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1730396801236-2408fc96-6f72-4e9d-a88e-3ff7cfc5ed2f.png)

## <font style="color:rgb(28, 30, 33);">5 保护 Dapr 到应用程序的通信</font>
<font style="color:rgb(28, 30, 33);">Dapr sidecar 通过 localhost 靠近应用运行，并建议在与应用程序相同的网络边界下运行，尽管现在许多云原生系统将 pod 级别（例如在 Kubernetes 上）视为受信任的安全边界，但 Dapr 为应用程序提供了使用 Token 的 API 级别身份验证，该功能保证了，即使在 localhost 上：</font>

+ <font style="color:rgb(28, 30, 33);">只有经过身份验证的应用程序才能调用 Dapr</font>
+ <font style="color:rgb(28, 30, 33);">一个应用程序可以检查 Dapr 是否正在回调它</font>

**<font style="color:rgb(28, 30, 33);">使用 API Token 对从应用程序到 Dapr 的请求进行身份验证</font>**

<font style="color:rgb(28, 30, 33);">默认情况下，Dapr 依赖网络边界来限制对其公共 API 的访问，如果你计划在该边界之外暴露 Dapr API，或者你的部署需要额外的安全级别，请考虑为 Dapr API 启用令牌身份验证，这会导致 Dapr 在允许该请求通过之前，要求其 API 的每个传入 gRPC 和 HTTP 请求都包含身份验证令牌。</font>

<font style="color:rgb(28, 30, 33);">Dapr 使用共享 tokens 令牌进行 API 认证，你可以自由定义要使用的 API Token。尽管 Dapr 没有为 Token 规定任何格式，但一个好主意是生成一个随机的字节序列并进行 Base64 编码，例如下面的命令生成了一个随机的 32 字节的密钥，并将其编码为 Base64。</font>

```bash
openssl rand 16 | base64
```

<font style="color:rgb(28, 30, 33);">Token 生成后需要在 Dapr 中配置该 API token，Kubernetes 或自托管 Dapr 部署的令牌身份验证配置略有不同。</font>

<font style="color:rgb(28, 30, 33);">在自托管模式下，Dapr 会查找</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">DAPR_API_TOKEN</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">环境变量，如果在</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">daprd</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">进程启动时设置了该环境变量，Dapr 会在其公共 API 上强制执行身份验证：</font>

```bash
export DAPR_API_TOKEN=<token>
```

<font style="color:rgb(28, 30, 33);">要轮换配置的令牌，只需要将</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">DAPR_API_TOKEN</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">环境变量更新为新值并重新启动 daprd 进程即可。</font>

<font style="color:rgb(28, 30, 33);">在 Kubernetes 模式下，Dapr 利用 Kubernetes Secret 对象来存储保存共享令牌，要配置 Dapr API 身份验证，首先要创建一个新密钥：</font>

```bash
kubectl create secret generic dapr-api-token --from-literal=token=<token>
```

请注意，需要在要启用 Dapr 令牌身份验证的每个命名空间中创建上述 Secret 对象。

<font style="color:rgb(28, 30, 33);">要让 Dapr 使用该密钥来保护其 API，只需要在部署模板规范中添加如下所示的注解即可：</font>

```yaml
annotations:
  dapr.io/enabled: 'true'
  dapr.io/api-token-secret: 'dapr-api-token' # name of the Kubernetes secret
```

<font style="color:rgb(28, 30, 33);">部署后，Dapr sidecar injector 将自动创建一个 Secret 引用并将实际值注入</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">DAPR_API_TOKEN</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">环境变量。</font>

<font style="color:rgb(28, 30, 33);">同样要在 Kubernetes 中轮换配置的令牌，请使用每个命名空间中的新令牌更新先前创建的密钥，我们可以使用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">kubectl patch</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">命令执行此操作，但在每个命名空间中更新这些内容的更简单方法是使用资源清单文件：</font>

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: dapr-api-token
type: Opaque
data:
  token: <your-new-token>
```

<font style="color:rgb(28, 30, 33);">然后在每个命名空间中应用该对象：</font>

```bash
kubectl apply --file token-secret.yaml --namespace <namespace-name>
```

<font style="color:rgb(28, 30, 33);">要告诉 Dapr 开始使用新令牌，需要对每个 Deployment 的滚动升级：</font>

```bash
kubectl rollout restart deployment/<deployment-name> --namespace <namespace-name>
```

<font style="color:rgb(28, 30, 33);">一旦在 Dapr 中配置了令牌身份验证，所有调用 Dapr API 的客户端都必须将 API 令牌附加到每个请求。</font>

<font style="color:rgb(28, 30, 33);">对于 HTTP，Dapr 需要通过 dapr-api-token 这个 Header 来指定 API 令牌，例如：</font>

```bash
GET http://<daprAddress>/v1.0/metadata
dapr-api-token: <token>
```

**<font style="color:rgb(28, 30, 33);">使用 API Token 对从 Dapr 到应用程序的请求进行身份验证</font>**

<font style="color:rgb(28, 30, 33);">对于某些构建块，例如发布/订阅、服务调用和输入绑定，Dapr 通过 HTTP 或 gRPC 与应用程序通信。要使应用程序能够对来自 Dapr sidecar 的请求进行身份验证，同样我们可以配置 Dapr 以将 API Token 作为 Header（在 HTTP 请求中）或元数据（在 gRPC 请求中）发送。</font>

<font style="color:rgb(28, 30, 33);">和上面同样的方式对于自拓管模式字需要配置</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">APP_API_TOKEN=<token></font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">环境变量即可，对于 Kubernetes 模式的通过设置</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">dapr.io/app-token-secret</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">这个注解即可。</font>

## <font style="color:rgb(28, 30, 33);">6 保护 Dapr 到控制平面通信</font>
<font style="color:rgb(28, 30, 33);">除了 Dapr sidecar 之间的自动 mTLS 之外，Dapr 还在下面场景下提供强制性 mTLS：</font>

+ <font style="color:rgb(28, 30, 33);">Dapr sidecar</font>
+ <font style="color:rgb(28, 30, 33);">Dapr 控制平面系统服务，即：</font>
    - <font style="color:rgb(28, 30, 33);">Sentry 服务（证书颁发机构）</font>
    - <font style="color:rgb(28, 30, 33);">Placement 服务</font>
    - <font style="color:rgb(28, 30, 33);">Kubernetes Operator 服务</font>

<font style="color:rgb(28, 30, 33);">启用 mTLS 后，Sentry 将根证书和颁发者证书写入 Kubernetes Secret，其范围为安装控制平面的命名空间。在自托管模式下，Sentry 将证书写入可配置的文件系统路径。</font>

<font style="color:rgb(28, 30, 33);">在 Kubernetes 中，当 Dapr 系统服务启动时，它们会自动挂载并使用包含根证书和颁发者证书的 Secret 来保护 Dapr sidecar 使用的 gRPC 服务器。在自托管模式下，每个系统服务都可以挂载到文件系统路径以获取凭据。</font>

<font style="color:rgb(28, 30, 33);">当 Dapr sidecar 初始化时，它使用挂载的叶子证书和颁发者私钥对系统 pod 进行身份验证，这些作为环境变量注入在 sidecar 容器上。</font>

<font style="color:rgb(28, 30, 33);">下图显示了 Dapr sidecar 和 Dapr Sentry（证书颁发机构）、Placement 和 Kubernetes Operator 系统服务之间的安全通信。</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1730396801629-be3f4027-30a8-44bf-8ea4-58bf777c86c6.png)

## <font style="color:rgb(28, 30, 33);">7 API 访问策略</font>
<font style="color:rgb(28, 30, 33);">在某些情况下，例如零信任网络或通过前端将 Dapr sidecar 暴露给外部流量时，建议仅启用应用程序当前使用的 Dapr sidecar API，这大大降低了攻击面，并使 Dapr API 的范围仅限于应用程序的实际需求。你可以通过在配置中设置 API 允许的列表来控制应用程序可以访问哪些 API。</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1730396804295-cc28db70-246f-40f0-b844-39e603ce4134.png)

<font style="color:rgb(28, 30, 33);">Dapr 允许开发人员通过使用 Dapr Configuration 设置 API 的允许列表来控制应用程序可以访问哪些 API。</font>

<font style="color:rgb(28, 30, 33);">如果未配置 API 允许列表，则默认行为是允许访问所有 Dapr API 的，一旦设置了允许列表，就只能访问指定的 API。例如，以下配置为 HTTP 和 gRPC 启用所有 API：</font>

```yaml
apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: myappconfig
  namespace: default
spec:
  tracing:
    samplingRate: '1'
```

<font style="color:rgb(28, 30, 33);">如果我们只需要使用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">v1.0</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">的 HTTP API，则可以使用下面的配置：</font>

```yaml
apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: myappconfig
  namespace: default
spec:
  api:
    allowed:
      - name: state
        version: v1.0
        protocol: http
```

<font style="color:rgb(28, 30, 33);">同样以下示例启用 state v1 gRPC API 并阻止所有其他 API：</font>

```yaml
apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: myappconfig
  namespace: default
spec:
  api:
    allowed:
      - name: state
        version: v1
        protocol: grpc
```

<font style="color:rgb(28, 30, 33);">允许列表配置规范中的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">name</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">表示你要启用的 Dapr API 的名称，如下表所示为不同 Dapr API 对应的值列表：</font>

| **Name** | **Dapr API** |
| :--- | :--- |
| state | [State](https://docs.dapr.io/reference/api/state_api/) |
| invoke | [Service Invocation](https://docs.dapr.io/reference/api/service_invocation_api/) |
| secrets | [Secrets](https://docs.dapr.io/reference/api/secrets_api/) |
| bindings | [Output Bindings](https://docs.dapr.io/reference/api/bindings_api/) |
| publish | [Pub/Sub](https://docs.dapr.io/developing-applications/building-blocks/pubsub/) |
| actors | [Actors](https://docs.dapr.io/reference/api/actors_api/) |
| metadata | [Metadata](https://docs.dapr.io/reference/api/metadata_api/) |


## <font style="color:rgb(28, 30, 33);">8 示例</font>
<font style="color:rgb(28, 30, 33);">Dapr 运行时不存储任何静止的数据，这意味着 Dapr 运行时的操作不依赖于任何状态存储，可以被认为是无状态的。</font>

<font style="color:rgb(28, 30, 33);">下图显示了 Kubernetes 上托管的示例应用程序中的一些安全功能。在该示例中，Dapr 控制平面、Redis 状态存储和每个服务都已部署到各自的命名空间中，在 Kubernetes 上部署时，可以使用常规的 Kubernetes RBAC 来控制对应用的访问。</font>

<font style="color:rgb(28, 30, 33);">在应用程序中，请求由 ingress 反向代理接收，该代理旁边运行着一个 Dapr sidecar，通过反向代理，Dapr 使用 service invocation 调用服务 A，然后服务 A 将消息发布到服务 B，服务 B 检索 Secret，以便读取状态并将其保存到 Redis 状态存储。</font>

![](https://cdn.nlark.com/yuque/0/2024/jpeg/2555283/1730396803552-a2388897-4848-49fc-8aaf-a2c0c7d657bb.jpeg)

<font style="color:rgb(28, 30, 33);">让我们回顾一下每种安全功能，并描述它们是如何保护此应用程序的。</font>

1. <font style="color:rgb(28, 30, 33);">API Token 身份验证确保反向代理知道它正在与正确的 Dapr sidecar 实例通信，这样可以防止将消息转发到除此 Dapr sidecar 以外的任何地方。</font>
2. <font style="color:rgb(28, 30, 33);">服务调用 mTLS 用于反向代理和服务 A 之间的身份验证。在服务 A 上配置的服务访问策略将其限制为只接收来自反向代理的特定端点上的调用，而不接收其他服务。</font>
3. <font style="color:rgb(28, 30, 33);">服务 B 使用 pub/sub 主题安全策略来指示它只能接收从服务 A 发布的消息。</font>
4. <font style="color:rgb(28, 30, 33);">Redis 组件定义使用组件范围安全策略表示只允许服务 B 调用它。</font>
5. <font style="color:rgb(28, 30, 33);">服务 B 限制 Dapr sidecar 只能使用 pub/sub、状态管理和 Secret API，所有其他 API 调用(例如，服务调用)都将失败。</font>
6. <font style="color:rgb(28, 30, 33);">配置中设置的 secret 安全策略限制服务 B 可以访问的 secret，在这种情况下，服务 B 只能读取连接到 Redis 状态存储组件所需的 secret，而不能读取其他 secret。</font>
7. <font style="color:rgb(28, 30, 33);">服务 B 被部署到命名空间 B，这进一步将它与其他服务隔离开来。即使在服务调用 API 上启用了服务调用 API，也不能因为与服务 A 处于同一名称空间而偶然调用它。服务 B 必须在其组件 YAML 文件中显式设置 Redis Host 名称空间来调用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">Redis</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">命名空间，否则这个调用也会失败。</font>
8. <font style="color:rgb(28, 30, 33);">Redis 状态存储中的数据是静止加密的，只能使用正确配置的 Dapr Redis 状态存储组件读取。</font>

