> Reference：
>
> [打造强大的集群权限控制：OPA部署与策略制定全流程](https://mp.weixin.qq.com/s/IV7riIFhqRTBH6xqt8_wFQ)
>
> [https://kubernetes.io/zh-cn/blog/2019/08/06/opa-gatekeeper-policy-and-governance-for-kubernetes/](https://kubernetes.io/zh-cn/blog/2019/08/06/opa-gatekeeper-policy-and-governance-for-kubernetes/)
>

官网地址：[https://www.openpolicyagent.org/](https://www.openpolicyagent.org/)

官方文档地址：[https://www.openpolicyagent.org/docs/latest/](https://www.openpolicyagent.org/docs/latest/)

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760581665719-133696cd-b76f-4e8a-a1a9-7c5fe0e02050.png)

[<u>Open Policy Agent</u>](https://www.openpolicyagent.org/)<u> 简称 OPA，是一种开源的通用策略代理引擎，是 CNCF 毕业的项目。</u><u><font style="color:#DF2A3F;">OPA 提供了一种高级声明式语言 Rego，简化了策略规则的定义，以减轻程序中策略的决策负担。</font></u><u>在微服务、Kubernetes、CI/CD、API 网关等场景中均可以使用 OPA 来定义策略。OPA 最初是由 Styra 创建的，它很自豪能成为云原生计算基金会（CNCF）景观中的一个毕业项目。</u>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570187401-3a8fde90-f676-48da-b4ee-0fdc3fbfce1c.png)

我们这里主要讲解在 Kubernetes 中如何集成 OPA，<font style="color:#DF2A3F;">在 Kubernetes 中 OPA 是通过 Admission Controllers 来实现安全策略的</font>。事实上使用 Pod 安全策略功能（要废弃了，已经在新版本移除）来执行我们的安全策略并没有什么问题，然而，根据定义，PSP 只能应用于 Pods。它们不能处理其他 Kubernetes 资源，如 Ingresses、Deployments、Services 等，OPA 的强大之处在于它可以应用于任何 Kubernetes 资源。<u><font style="color:#DF2A3F;">OPA 作为一个准入控制器部署到 Kubernetes，它拦截发送到 APIServer 的 API 调用，并验证和/或修改它们。</font></u>你可以有一个统一的 OPA 策略，适用于系统的不同组件，而不仅仅是 Pods，例如，有一种策略，强制用户在其服务中使用公司的域，并确保用户只从公司的镜像仓库中拉取镜像。

<details class="lake-collapse"><summary id="u737d85bb"><span class="ne-text" style="color: rgb(58, 58, 58)">K8S OPA 的简单介绍（通俗易懂）</span></summary><p id="ue1410cf8" class="ne-p" style="text-align: left"><span class="ne-text" style="color: rgb(58, 58, 58)">简单来说就是针对云原生环境的基于策略的控制，为整个堆栈的管理员提供灵活、细粒度的控制。OPA 为跨云原生堆栈的策略提供统一的工具集和框架。</span></p><p id="u85242d30" class="ne-p" style="text-align: left"><span class="ne-text" style="color: rgb(58, 58, 58)">这里再聊一聊 K8S 如何集成OPA，在 Kubernetes 里，OPA 好比一个全能的保安，它通过一种叫做“准入控制器”的特殊通道来确保安全规则被遵守。你可以想象，Kubernetes 集群像一座大楼，而每当有新的服务（比如 Pods）或者其他东西想要进入这座大楼时，它们都需要通过这个保安的检查。</span></p><p id="u60f6d985" class="ne-p" style="text-align: left"><span class="ne-text" style="color: rgb(58, 58, 58)">以前，我们有一种被称为“Pod 安全策略”的保镖，但他已经退休了（PSP）。虽然这位保镖干得还不错，但他只关注服务本身，也就是 Pod，对于其他进入大楼的东西（比如 Ingresses、Deployments、Services 等）就无能为力了。</span></p><p id="u1a16615e" class="ne-p" style="text-align: left"><span class="ne-text" style="color: rgb(58, 58, 58)">这就是 OPA 登场的时候。这位全能的保安 OPA 不仅仅会检查服务，还会检查进入大楼的任何东西。它的工作方式是站在大楼的入口处，也就是 Kubernetes 的 API 服务器前，检查所有想要进入的请求，确保它们都符合规定。</span></p><p id="u4e41b9e6" class="ne-p" style="text-align: left"><span class="ne-text" style="color: rgb(58, 58, 58)">例如，OPA 可以执行一个规则，要求所有的服务都要使用公司的域名，还可以确保所有使用的软件镜像都必须来自公司内部的镜像仓库。这样，无论是服务本身还是服务使用的其他资源，都必须遵循同一套规则。OPA 就像是一个可以在多个地方同时看门的超级保安，守护着整个 Kubernetes 大楼的安全。</span></p><p id="u7f22cadc" class="ne-p" style="text-align: left"><span class="ne-text" style="color: rgb(58, 58, 58)">如图所示：</span></p><p id="u3e25f0f3" class="ne-p" style="text-align: left"><img src="https://cdn.nlark.com/yuque/0/2025/webp/2555283/1760589108713-95040a4b-7258-4a3e-a3a3-2556c5108860.webp" width="1080" id="u60b847e7" class="ne-image" style="color: rgb(0, 0, 0)"></p><p id="u6dd673df" class="ne-p" style="text-align: left"><img src="https://cdn.nlark.com/yuque/0/2025/webp/2555283/1760589108763-763a1f52-f038-4414-80ef-2967a0b6ab63.webp" width="789" id="u6d5d5214" class="ne-image" style="color: rgb(0, 0, 0)"></p></details>
## 1 OPA 概述
OPA 将策略决策与策略执行分离，当应用需要做出策略决策时，它会查询 OPA 并提供结构化数据（例如 JSON）作为输入，OPA 接受任意结构化数据作为输入。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570186992-9c98db28-64f5-40ec-9f41-c06a7cd74876.png)

<u>OPA 通过评估查询输入策略和数据来生成策略决策，你可以在你的策略中描述几乎任何的不变因素，例如：</u>

+ <u>哪些用户可以访问哪些资源</u>
+ <u>哪些子网的出口流量被允许</u>
+ <u>工作负载必须部署到哪些集群</u>
+ <u>二进制文件可以从哪里下载</u>
+ <u>容器可以用哪些操作系统的能力来执行</u>
+ <u>系统在一天中的哪些时间可以被访问</u>

策略决定不限于简单的**<font style="color:#DF2A3F;">是/否或允许/拒绝</font>**，与查询输入一样，你的策略可以生成任意结构化数据作为输出。 让我们看一个例子。<u><font style="color:#DF2A3F;">OPA 的策略是用一种叫做 Rego 的高级声明性语言来声明的，Rego 是专门为表达复杂的分层数据结构的策略而设计的。</font></u>

在 Kubernetes 中，准入控制器在创建、更新和删除操作期间对对象实施策略。准入控制是 Kubernetes 中策略执行的基础。通过将 OPA 部署为准入控制器，可以：

+ 要求在所有资源上使用特定标签
+ 要求容器镜像来自企业镜像仓库
+ 要求所有 Pod 指定资源请求和限制
+ 防止创建冲突的 Ingress 对象
+ ......

Kubernetes APIServer 配置为在创建、更新或删除对象时查询 OPA 以获取准入控制策略。APIServer 将 webhook 请求中的整个对象发送给 OPA，OPA 使用准入审查作为输入来评估它已加载的策略。这个其实和我们自己去实现一个准入控制器是类似的，只是不需要我们去编写代码，只需要编写策略规则，OPA 就可以根据我们的规则去对输入的对象进行验证。

## 2 部署 OPA
### 2.1 使用 kube-mgmt 原生方式部署
> Reference：[https://www.openpolicyagent.org/docs/kubernetes](https://www.openpolicyagent.org/docs/kubernetes)
>

kube-mgmt 是一个 sidecar 容器，负责将 Kubernetes 中的 ConfigMap 策略与资源同步到 OPA 实例中，便于动态策略加载与资源感知。

接下来我们介绍下如何在 Kubernetes 集群中集成 OPA，由于 Kubernetes 中是通过准入控制器来集成 OPA 的，所以我们必须在集群中启用 `<font style="color:#DF2A3F;">ValidatingAdmissionWebhook</font>`<font style="color:#DF2A3F;"> </font>这个准入控制器。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570187856-8ba70d94-2cd1-4cd5-8207-c1c847762c50.png)

首先创建一个名为 `<font style="color:#DF2A3F;">opa</font>`<font style="color:#DF2A3F;"> </font>的命名空间，可以让 OPA 从该命名空间中的 ConfigMap 去加载策略：

```shell
➜ kubectl create namespace opa
```

并将上下文更改为 opa 命名空间：

```shell
➜ kubectl config current-context
kubernetes-admin@kubernetes

# 切换到默认的命名空间
➜ kubectl config set-context kubernetes-admin@kubernetes --namespace=opa
Context "kubernetes-admin@kubernetes" modified.

➜ kubectl get pods
No resources found in opa namespace.
```

为了保护 APIServer 和 OPA 之间的通信，我们需要配置 TLS 证书。

1. 创建证书颁发机构和密钥：

```shell
➜ openssl genrsa -out ca.key 2048
➜ openssl req -x509 -new -nodes -key ca.key -days 100000 -out ca.crt -subj "/CN=admission_ca"
➜ ls -l 
total 8
-rw-r--r-- 1 root root 1123 Oct 16 10:45 ca.crt
-rw------- 1 root root 1679 Oct 16 10:45 ca.key
```

2. 为 OPA 生成密钥和证书：

```shell
➜ cat >server.conf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, serverAuth
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = opa.opa.svc
EOF
➜ openssl genrsa -out server.key 2048
➜ openssl req -new -key server.key -out server.csr -subj "/CN=opa.opa.svc" -config server.conf
➜ openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 100000 -extensions v3_req -extfile server.conf
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760582803803-6ceadee4-4d15-4f77-af7e-2875d019e6e3.png)

3. 创建一个 Kubernetes TLS Secret 来存储我们的 OPA 凭证：

```shell
➜ kubectl create secret tls opa-server --cert=server.crt --key=server.key
➜ kubectl get secrets 
NAME         TYPE                DATA   AGE
opa-server   kubernetes.io/tls   2      10s

➜ kubectl describe secrets opa-server  
Name:         opa-server
Namespace:    opa
Labels:       <none>
Annotations:  <none>

Type:  kubernetes.io/tls

Data
====
tls.crt:  1119 bytes
tls.key:  1679 bytes
```

证书准备好后就可以部署准入控制器了，对应的资源清单文件如下所示：

```yaml
# opa-admission-controller.yaml
# Grant OPA/kube-mgmt read-only access to resources. This lets kube-mgmt
# replicate resources into OPA so they can be used in policies.
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: opa-viewer
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: Group
    name: system:serviceaccounts:opa
    apiGroup: rbac.authorization.k8s.io
---
# Define role for OPA/kube-mgmt to update configmaps with policy status.
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: opa
  name: configmap-modifier
rules:
  - apiGroups: ['']
    resources: ['configmaps']
    verbs: ['update', 'patch']
---
# Grant OPA/kube-mgmt role defined above.
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: opa
  name: opa-configmap-modifier
roleRef:
  kind: Role
  name: configmap-modifier
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: Group
    name: system:serviceaccounts:opa
    apiGroup: rbac.authorization.k8s.io
---
kind: Service
apiVersion: v1
metadata:
  name: opa
  namespace: opa
spec:
  selector:
    app: opa
  ports:
    - name: https
      protocol: TCP
      port: 443
      targetPort: 443
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: opa
  namespace: opa
spec:
  selector:
    matchLabels:
      app: opa
  template:
    metadata:
      labels:
        app: opa
    spec:
      containers:
        - name: opa
          image: openpolicyagent/opa:latest
          securityContext:
            capabilities:
              add:
                - NET_BIND_SERVICE
          args:
            - 'run'
            - '--server'
            - '--tls-cert-file=/certs/tls.crt'
            - '--tls-private-key-file=/certs/tls.key'
            - '--addr=0.0.0.0:443'
            - '--addr=http://127.0.0.1:8181'
            - '--log-level=debug'
            - '--log-format=json-pretty'
          volumeMounts:
            - readOnly: true
              mountPath: /certs
              name: opa-server
          readinessProbe:
            httpGet:
              path: /health
              scheme: HTTPS
              port: 443
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /health
              scheme: HTTPS
              port: 443
            initialDelaySeconds: 10
            periodSeconds: 15
        - name: kube-mgmt
          image: openpolicyagent/kube-mgmt:4.0.0
          args:
            - --replicate-cluster=v1/namespaces
            - --replicate=networking.k8s.io/v1/ingresses
            - --opa-url=http://127.0.0.1:8181/v1
            - --enable-data=true
            - --enable-policies=true
            - --policies=opa
            - --require-policy-label=true
      volumes:
        - name: opa-server
          secret:
            secretName: opa-server
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: opa-default-system-main
  namespace: opa
  labels:
    openpolicyagent.org/policy: rego
data:
  main: |
    package system

    import data.kubernetes.admission

    main = {
      "apiVersion": "admission.k8s.io/v1",
      "kind": "AdmissionReview",
      "response": response,
    }

    default uid = ""
    uid = input.request.uid
    response = {
        "allowed": false,
        "uid": uid,
        "status": {
            "message": reason,
        },
    } {
        reason = concat(", ", admission.deny)
        reason != ""
    }
    else = {"allowed": true, "uid": uid}
```

上面的资源清单中我们添加了一个 `<font style="color:#DF2A3F;">kube-mgmt</font>` 的 Sidecar 容器，<u>该容器可以将 ConfigMap 对象中的策略动态加载到 OPA 中，</u>`<u><font style="color:#DF2A3F;">kube-mgmt</font></u>`<u> 容器还可以将任何其他 Kubernetes 对象作为 JSON 数据加载到 OPA 中。</u>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570186874-a6dcf4e9-141e-41d1-8534-57a93606f272.png)

另外需要注意的是 Service 的名称（opa）必须与我们证书配置的 CN 匹配，否则 TLS 通信会失败。在 `<font style="color:#DF2A3F;">kube-mgmt</font>` 容器中还指定了以下命令行参数：

+ `<u><font style="color:#DF2A3F;">--replicate-cluster=v1/namespaces</font></u>`
+ `<u><font style="color:#DF2A3F;">--replicate=networking.k8s.io/v1/ingresses</font></u>`
+ `<u><font style="color:#DF2A3F;">--enable-policies=true</font></u>`
+ `<u><font style="color:#DF2A3F;">--policies=opa</font></u>`
+ `<u><font style="color:#DF2A3F;">--require-policy-label=true</font></u>`

前两个参数允许 Sidecar 容器复制命名空间、Ingress 对象，并将它们加载到 OPA 引擎中，`<font style="color:#DF2A3F;">enable-policies=true</font>` 表示会通过 Configmap 加载 OPA 策略，下面的 `<font style="color:#DF2A3F;">--policies=opa</font>` 表示从 `<font style="color:#DF2A3F;">opa</font>`<font style="color:#DF2A3F;"> </font>命名空间中的 Configmap 来加载策略，如果还配置了 `<font style="color:#DF2A3F;">--require-policy-label=true</font>` 参数，则需要 Configmap 中带有 `<font style="color:#DF2A3F;">openpolicyagent.org/policy=rego</font>` 这个标签才会被自动加载。

现在直接应用上面的资源清单即可：

```shell
➜ kubectl create -f opa-admission-controller.yaml 
clusterrolebinding.rbac.authorization.k8s.io/opa-viewer created
role.rbac.authorization.k8s.io/configmap-modifier created
rolebinding.rbac.authorization.k8s.io/opa-configmap-modifier created
service/opa created
deployment.apps/opa created
configmap/opa-default-system-main created

➜ kubectl get pods
NAME                  READY   STATUS    RESTARTS   AGE
opa-6cd68f74f-s9zcv   2/2     Running   0          5m28s
```

<details class="lake-collapse"><summary id="u9bd61d43"><span class="ne-text">原生部署 OPA（kube-mgmt）FAQ</span></summary><pre data-language="shell" id="ZflSv" class="ne-codeblock language-shell"><code>$ kubectl logs $(kubectl get pod -oname|awk -F'/' '{print $2}')
Defaulted container &quot;opa&quot; out of: opa, kube-mgmt
{
  &quot;addrs&quot;: [
    &quot;0.0.0.0:443&quot;,
    &quot;http://127.0.0.1:8181&quot;
  ],
  &quot;diagnostic-addrs&quot;: [],
  &quot;level&quot;: &quot;info&quot;,
  &quot;msg&quot;: &quot;Initializing server.&quot;,
  &quot;time&quot;: &quot;2025-10-16T04:51:19Z&quot;
}
{
  &quot;level&quot;: &quot;debug&quot;,
  &quot;msg&quot;: &quot;Failed to determine uid/gid of process owner&quot;,
  &quot;time&quot;: &quot;2025-10-16T04:51:19Z&quot;
}
{
  &quot;level&quot;: &quot;debug&quot;,
  &quot;msg&quot;: &quot;maxprocs: Leaving GOMAXPROCS=16: CPU quota undefined&quot;,
  &quot;time&quot;: &quot;2025-10-16T04:51:19Z&quot;
}
{
  &quot;headers&quot;: {
    &quot;User-Agent&quot;: [
      &quot;Open Policy Agent/1.9.0 (linux, amd64)&quot;
    ]
  },
  &quot;level&quot;: &quot;debug&quot;,
  &quot;method&quot;: &quot;GET&quot;,
  &quot;msg&quot;: &quot;Sending request.&quot;,
  &quot;time&quot;: &quot;2025-10-16T04:51:19Z&quot;,
  &quot;url&quot;: &quot;https://api.github.com/repos/open-policy-agent/opa/releases/latest&quot;
}
{
  &quot;level&quot;: &quot;debug&quot;,
  &quot;msg&quot;: &quot;Server initialized.&quot;,
  &quot;time&quot;: &quot;2025-10-16T04:51:19Z&quot;
}
{
  &quot;err&quot;: &quot;listen tcp 0.0.0.0:443: bind: permission denied&quot;,
  &quot;level&quot;: &quot;error&quot;,
  &quot;msg&quot;: &quot;Listener failed.&quot;,
  &quot;time&quot;: &quot;2025-10-16T04:51:19Z&quot;
}</code></pre><p id="u657cc1e3" class="ne-p"><span class="ne-text">如果出现无法正常启动 OPA 服务，那么就有可能是端口 Bind 的问题。可以将 OPA Yaml 中涉及到 443 端口改为 8443 端口来进行部署即可。</span></p><pre data-language="shell" id="lNTL8" class="ne-codeblock language-shell"><code>$ kubectl get all -o wide 
NAME                       READY   STATUS    RESTARTS   AGE   IP               NODE           NOMINATED NODE   READINESS GATES
pod/opa-84b995d66b-j9rb9   2/2     Running   0          39m   192.244.51.253   hkk8snode002   &lt;none&gt;           &lt;none&gt;

NAME          TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE   SELECTOR
service/opa   ClusterIP   192.96.161.3   &lt;none&gt;        8443/TCP   49m   app=opa

NAME                  READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS      IMAGES                                                       SELECTOR
deployment.apps/opa   1/1     1            1           49m   opa,kube-mgmt   openpolicyagent/opa:latest,openpolicyagent/kube-mgmt:4.0.0   app=opa</code></pre></details>
### 2.2 kube-mgmt 使用 Helm 方式部署
```shell
# 准备环境
# 确保已安装 Helm v3+ 和 kubectl，并连接到目标集群。

# 添加 Helm 仓库并更新
$ helm repo add open-policy-agent https://open-policy-agent.github.io/kube-mgmt/charts

# 安装 OPA 与 kube-mgmt
$ helm install opa open-policy-agent/opa --create-namespace
NAME: opa
LAST DEPLOYED: Thu Oct 16 11:29:41 2025
NAMESPACE: opa
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
Please wait while the OPA is deployed on your cluster.

For example policies that you can enforce with OPA see https://www.openpolicyagent.org.

If you installed this chart with the default values, you can exercise the sample policy.

# 1. Create a namespace called "opa-example"

kubectl create namespace opa-example

# 2. Create an Ingress in the "opa-example" namespace that complies with the policy.

cat > ingress-ok.yaml <<EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ingress-ok
spec:
  rules:
  - host: signin.dev.acmecorp.com
    http:
      paths:
      - backend:
          serviceName: nginx
          servicePort: 80
EOF

kubectl -n opa-example create -f ingress-ok.yaml

# 3. Try to create an Ingress in the "opa-example" namespace that violates the policy.

cat > ingress-bad.yaml <<EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ingress-bad
spec:
  rules:
  - host: signin.acmecorp.com
    http:
      paths:
      - backend:
          serviceName: nginx
          servicePort: 80
EOF

kubectl -n opa-example create -f ingress-bad.yaml

If you want to turn off authz for debugging purposes, you can do so by upgrading the chart like so:
helm upgrade opa stable/opa --reuse-values --set authz.enabled=false

You can query OPA to see the policies it has loaded (you will need to turn off authz as described above):

export OPA_POD_NAME=$(kubectl get pods --namespace opa -l "app=opa" -o jsonpath="{.items[0].metadata.name}")

kubectl port-forward $OPA_POD_NAME 8080:443 --namespace opa

curl -k -s https://localhost:8080/v1/policies | jq -r '.result[].raw'

# 卸载 OPA 与 kube-mgmt
$ helm uninstall -n opa opa 
release "opa" uninstalled
```

### 2.3 准入 Admission Webhook 配置
为了让准入控制器工作，我们还需要一个准入 Admission Webhook 来接收准入 HTTP 回调并执行它们，创建如下所示的 webhook 配置文件：

+ 使用原生方式部署 OPA(`<font style="color:#DF2A3F;">kube-mgmt</font>`)

```yaml
➜ cat > webhook-configuration.yaml <<EOF
kind: ValidatingWebhookConfiguration
apiVersion: admissionregistration.k8s.io/v1
metadata:
  name: opa-validating-webhook
webhooks:
  - name: validating-webhook.openpolicyagent.org
    admissionReviewVersions: ["v1", "v1beta1"]
    namespaceSelector:
      matchExpressions:
      - key: openpolicyagent.org/webhook
        operator: NotIn
        values:
        - ignore
    failurePolicy: Ignore
    rules:
      - apiGroups:
        - '*'
        apiVersions:
        - '*'
        operations:
        - '*'
        resources:
        - '*'
    sideEffects: None
    clientConfig:
      caBundle: $(cat ca.crt | base64 | tr -d '\n')
      service:
        namespace: opa
        name: opa
EOF
```

+ 使用 Helm 方式部署 OPA(`<font style="color:#DF2A3F;">kube-mgmt</font>`)

```yaml
➜ cat > webhook-configuration.yaml <<EOF
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: opa-validating-webhook
webhooks:
  - name: opa.kube-system.svc
    rules:
      - apiGroups:
          - "*"
        apiVersions:
          - "*"
        operations:
          - CREATE
          - UPDATE
        resources:
          - "*"
    clientConfig:
      service:
        namespace: kube-system
        name: opa
    failurePolicy: Fail # 或者可以设置为 Ignore
EOF
```

上面的 webhook 中配置了以下属性：

+ 不会监听来自带有 `<font style="color:#DF2A3F;">openpolicyagent.org/webhook=ignore</font>` 标签的命名空间的操作
+ 会监听所有资源上的 CREATE 和 UPDATE 操作
+ 它使用我们之前创建的 CA 证书，以便能够与 OPA 通信

现在，在使用配置之前，我们标记 `<font style="color:#DF2A3F;">kube-system</font>` 和 `<font style="color:#DF2A3F;">opa</font>`<font style="color:#DF2A3F;"> </font>命名空间，使它们不在 webhook 范围内：

```shell
➜ kubectl label namespace kube-system openpolicyagent.org/webhook=ignore
➜ kubectl label namespace opa openpolicyagent.org/webhook=ignore
```

然后应用上面的配置对象将 OPA 注册为准入控制器：

```shell
➜ kubectl apply -f webhook-configuration.yaml
validatingwebhookconfiguration.admissionregistration.k8s.io/opa-validating-webhook created

➜ kubectl get pods
NAME                   READY   STATUS    RESTARTS   AGE
opa-7bb5cc9d97-r5bjr   1/1     Running   0          60m

➜ kubectl get validatingwebhookconfiguration opa-validating-webhook
NAME                     WEBHOOKS   AGE
opa-validating-webhook   1          15s
```

## 3 策略示例
OPA 使用 Rego 语言来描述策略，这里我们使用官方文档中提到的示例来进行说明，创建一个限制 Ingress 可以使用的主机名策略，只允许匹配指定正则表达式的主机名。

创建如下所示名为 `<font style="color:#DF2A3F;">ingress-allowlist.rego</font>` 的策略文件：

+ Version 1：

```go
// <!-- 在这里，我们声明规则属于什么包，这与其他语言的包装类似，是将类似规则归入同一命名空间的一种方式。 -->
package kubernetes.admission

import data.kubernetes.namespaces

operations = {"CREATE", "UPDATE"} // 两项操作的数据集

deny[msg] {
    input.request.kind.kind == "Ingress"
    operations[input.request.operation]
    host := input.request.object.spec.rules[_].host
    not fqdn_matches_any(host, valid_ingress_hosts)
    msg := sprintf("invalid ingress host %q", [host])
}

valid_ingress_hosts = {host |
    allowlist := namespaces[input.request.namespace].metadata.annotations["ingress-allowlist"]
    hosts := split(allowlist, ",")
    host := hosts[_]
}

fqdn_matches_any(str, patterns) {
    fqdn_matches(str, patterns[_])
}

fqdn_matches(str, pattern) {
    pattern_parts := split(pattern, ".")
    pattern_parts[0] == "*"
    str_parts := split(str, ".")
    n_pattern_parts := count(pattern_parts)
    n_str_parts := count(str_parts)
    suffix := trim(pattern, "*.")
    endswith(str, suffix)
}

fqdn_matches(str, pattern) {
    not contains(pattern, "*")
    str == pattern
}
```

+ Version 2（推荐版本）：

```go
package kubernetes.admission

import data.kubernetes.namespaces

operations = {"CREATE", "UPDATE"}

deny contains msg if {
    input.request.kind.kind == "Ingress"
    operations[input.request.operation]
    host := input.request.object.spec.rules[_].host
    not fqdn_matches_any(host, valid_ingress_hosts)
    msg := sprintf("invalid ingress host %q", [host])
}

valid_ingress_hosts = {host |
    allowlist := namespaces[input.request.namespace].metadata.annotations["ingress-allowlist"]
    hosts := split(allowlist, ",")
    host := hosts[_]
}

fqdn_matches_any(str, patterns) if {
    fqdn_matches(str, patterns[_])
}

fqdn_matches(str, pattern) if {
    pattern_parts := split(pattern, ".")
    pattern_parts[0] == "*"
    str_parts := split(str, ".")
    n_pattern_parts := count(pattern_parts)
    n_str_parts := count(str_parts)
    suffix := trim(pattern, "*.")
    endswith(str, suffix)
}

fqdn_matches(str, pattern) if {
    not contains(pattern, "*")
    str == pattern
}
```

如果你是 Rego 新手，上面的代码看上去可能有点陌生，但 Rego 让定义策略变得非常容易，我们来分析下这个策略是如何使用白名单中的 Ingress 命名空间强制执行的：

+ 第 1 行：`<font style="color:#DF2A3F;">package</font>`<font style="color:#DF2A3F;"> </font>的使用方式与在其他语言中的使用方式是一样的
+ 第 5 行：我们定义一个包含两项操作的数据集：`<font style="color:#DF2A3F;">CREATE</font>` 和 `<font style="color:#DF2A3F;">UPDATE</font>`
+ 第 7 行：这是策略的核心部分，以 `<font style="color:#DF2A3F;">deny</font>`<font style="color:#DF2A3F;"> </font>开头，然后是策略正文。如果正文中的语句组合评估为真，则违反策略，便会阻止操作，并将消息返回给用户，说明操作被阻止的原因
+ 第 8 行：指定输入对象，发送到 OPA 的任何 JSON 消息都是从输入对象的根部开始的，我们遍历 JSON 对象，直到找到有问题的资源，并且它必须是 `<font style="color:#DF2A3F;">Ingress</font>`<font style="color:#DF2A3F;"> </font>才能应用该策略
+ 第 9 行：我们需要应用策略来创建或更新资源，在 Rego 中，我们可以通过使用 `<font style="color:#DF2A3F;">operations[input.requset.operations]</font>` 来实现，方括号内的代码会提取请求中指定的操作，如果它与第 5 行的操作集中定义的元素相匹配，则该语句为真
+ 第 10 行：为了提取 Ingress 对象的 host 信息，我们需要迭代 JSON 对象的 rules 数组，同样 Rego 提供了 `<font style="color:#DF2A3F;">_</font>` 字符来循环浏览数组，并将所有元素返回到 `<font style="color:#DF2A3F;">host</font>`<font style="color:#DF2A3F;"> </font>变量中
+ 第 11 行：现在我们有了 host 变量，我们需要确保它不是列入白名单的主机，要记住，只有在评估为 true 时才会违反该策略，为了检查主机是否有效，我们使用第 21 行中定义的 `<font style="color:#DF2A3F;">fqdn_matches_any</font>`<font style="color:#DF2A3F;"> </font>函数
+ 第 12 行：定义应返回给用户的消息，说明无法创建 Ingress 对象的原因
+ 第 15-19 行：这部分从 Ingress 命名空间的 `<font style="color:#DF2A3F;">annotations</font>`<font style="color:#DF2A3F;"> </font>中提取列入白名单的主机名，主机名添加在逗号分隔的列表中，使用 `<font style="color:#DF2A3F;">split</font>`<font style="color:#DF2A3F;"> </font>内置函数用于将其转换为列表。最后，`<font style="color:#DF2A3F;">_</font>` 用于遍历所有提取的主机列表，将结果通过 `<font style="color:#DF2A3F;">|</font>` 管道传送给 `<font style="color:#DF2A3F;">host</font>`<font style="color:#DF2A3F;"> </font>变量（这与 Python 中的列表推导非常类似）
+ 第 21 行：该函数只接受一个字符串，并在一个 patterns 列表中搜索它，这是第二个参数。实际上是调用的下方的 `<font style="color:#DF2A3F;">fqdn_matches</font>`<font style="color:#DF2A3F;"> </font>函数来实现的。在 Rego 中，**可以定义具有多个相同名称的函数**，只要它们都产生相同的输出，当调用多次定义的函数时，将调用该函数的所有实例
+ 第 25-33 行：第一个 `<font style="color:#DF2A3F;">fqdn_matches</font>`<font style="color:#DF2A3F;"> </font>函数的定义。
    - 首先它通过点 `<font style="color:#DF2A3F;">.</font>` 将 pattern 进行拆分，比如 `<font style="color:#DF2A3F;">*.example.com</font>`<font style="color:#DF2A3F;"> </font>会分割成 `<font style="color:#DF2A3F;">*</font>`、`<font style="color:#DF2A3F;">example</font>` 和 `<font style="color:#DF2A3F;">com</font>`
    - 接下来确保 pattern 的第一个标记是星号，同样对输入的字符串按照 `<font style="color:#DF2A3F;">.</font>` 进行拆分
    - 删除 pattern 中的 `<font style="color:#DF2A3F;">*.</font>`
    - 最后评估输入字符串是否以后缀结尾，比如如果允许的模式字符串是 `<font style="color:#DF2A3F;">*.mydomain.com</font>`，被评估的字符串是 `<font style="color:#DF2A3F;">www.example.com</font>`，则违反了该策略，因为该字符串不是 `<font style="color:#DF2A3F;">mydomain.com</font>` 的一部分
+ 第 35-38 行：第二个验证函数，该函数用于验证不使用通配符的模式，例如，当模式写为 `<font style="color:#DF2A3F;">mycompany.mydomain.com</font>` 的时候
    - 首先，需要确保提供的模式不包含通配符，否则，该语句将评估为 false 并且函数将不会继续
    - 如果模式指的是特定的域名，那么我们只需要确保 fqdn 与该模式匹配。换句话说，如果模式是 `<font style="color:#DF2A3F;">mycompany.mydomain.com</font>`，那么主机的 fqdn 也必须是 `<font style="color:#DF2A3F;">mycompany.mydomain.com</font>`

:::success
**<u><font style="color:#DF2A3F;">我们之所以有两个具有相同名称的函数，是因为 Rego 语言的一个限制，它会阻止函数产生一个以上的输出结果，所以，要想在同一时间用不同的逻辑进行多个验证，必须使用多个同名的函数。</font></u>**

:::

在生产环境中，在将 Rego 代码应用到集群之前一定要进行全方位测试，比如可以添加单元测试，同时也可以使用 [Rego Playground](https://play.openpolicyagent.org/) 来对代码进行验证。

要将该策略应用于集群，我们需要将上面的 Rego 文件以 Configmap 的形式应用到 opa 命名空间中：

```shell
# 引用 rego 文件需要将注释信息全部删除
➜ kubectl create configmap ingress-allowlist --from-file=ingress-allowlist.rego
# 配置 ConfigMap 的 Label 标签
➜ kubectl label  configmap ingress-allowlist openpolicyagent.org/policy=rego
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760593346080-62c8e15a-df95-45b8-aa90-c907c033cab8.png)

由于我们开启了 `<font style="color:#DF2A3F;">--require-policy-label</font>` 参数，所以还需要带上对应的标签。创建完成后最好检查下我们的策略是否被 OPA 获取了，并且没有语法错误，可以通过检查 ConfigMap 的状态来判断：

```shell
➜ kubectl get cm ingress-allowlist  -o json | jq '.metadata.annotations'
{
  "openpolicyagent.org/policy-status": "{\"status\":\"ok\"}"
}
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761585715495-26d5bbb0-ebe9-4bdc-8656-46834ef70154.png)

接下来，让我们创建两个命名空间，一个用于 QA 环境，另一个用于生产环境。要注意它们都包含 `<font style="color:#DF2A3F;">ingress-allowlist</font>` 注解，其中包含 Ingress 主机名应该匹配的模式。

```yaml
# qa-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    ingress-allowlist: '*.qa.qikqiak.com,*.internal.qikqiak.com'
  name: qa
---
# production-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    ingress-allowlist: '*.qikqiak.com'
  name: production
```

直接应用上面的两个资源清单文件即可：

```shell
➜ kubectl apply -f qa-namespace.yaml -f production-namespace.yaml
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761585768065-f49a870d-3e73-4e37-9b63-5722f3c6d04b.png)

接下来让我们创建一个被策略允许的 Ingress 对象：

```shell
➜ kubectl apply -f - <<EOT
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-ok
  namespace: production
spec:
  ingressClassName: nginx
  rules:
  - host: prod.qikqiak.com
    http:
      paths:
      - backend:
          service:
            name: nginx
            port:
              number: 80
        path: /
        pathType: Prefix
EOT
```

正常上面的资源对象可以创建：

```shell
➜ kubectl get ing -n production
NAME         CLASS   HOSTS              ADDRESS   PORTS   AGE
ingress-ok   nginx   prod.qikqiak.com             80      10s
```

接着我们创建一个不符合策略的 Ingress 对象：

```shell
➜ kubectl apply -f - <<EOT
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-bad
  namespace: qa
spec:
  ingressClassName: nginx
  rules:
  - host: opa.k8s.local
    http:
      paths:
      - backend:
          service:
            name: nginx
            port:
              number: 80
        path: /
        pathType: Prefix
EOT
Error from server: error when creating "test.yaml": admission webhook "validating-webhook.openpolicyagent.org" denied the request: invalid ingress host "opa.k8s.local"
```

从输出中可以看出，APIServer 拒绝创建 Ingress 对象，因为上面的对象违反了我们的 OPA 策略规则。

到这里我们就完成了理由 OPA 在 Kubernetes 集群中实施准入控制策略，而无需修改或重新编译任何 Kubernetes 组件。此外，还可以通过 OPA 的 Bundle 功能策略，可以定期从远程服务器下载以满足不断变化的操作要求。

## 4 Gatekeeper OPA 部署
上面我们介绍了使用 `<font style="color:#DF2A3F;">kube-mgmt</font>` 这个 sidecar 容器来完成 OPA 策略的自动同步，此外还有另外一个更加高级的工具 [Gatekeeper](https://open-policy-agent.github.io/gatekeeper/website/docs/)，相比于之前的模式，`<font style="color:#DF2A3F;">Gatekeeper(v3.0)</font>` 准入控制器集成了 `<font style="color:#DF2A3F;">OPA Constraint Framework</font>`，以执行基于 CRD 的策略，并允许声明式配置的策略可靠地共享，使用 kubebuilder 构建，它提供了验证和修改准入控制和审计功能。这允许为 Rego 策略创建策略模板，将策略创建为 CRD，并在策略 CRD 上存储审计结果，这个项目是谷歌、微软、红帽和 Styra 一起合作实现的。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570187201-0140febf-bdf9-41bd-9db9-9bc4cb7f5739.png)

直接使用下面的命令即可安装 `<font style="color:#DF2A3F;">Gatekeeper</font>`：

```shell
# 安装 Gatekeeper
➜ kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.7/deploy/gatekeeper.yaml
```

默认会将 `<font style="color:#DF2A3F;">Gatekeeper</font>`<font style="color:#DF2A3F;"> </font>安装到 `<font style="color:#DF2A3F;">gatekeeper-system</font>` 命名空间下面，同样会安装几个相关的 CRD：

```shell
➜ kubectl get pods -n gatekeeper-system
NAME                                             READY   STATUS    RESTARTS   AGE
gatekeeper-audit-5b65dfddfd-pr98g                1/1     Running   0          70s
gatekeeper-controller-manager-59c4c455bb-4tgbw   1/1     Running   0          70s
gatekeeper-controller-manager-59c4c455bb-cktpp   1/1     Running   0          70s
gatekeeper-controller-manager-59c4c455bb-hkdt9   1/1     Running   0          70s

➜ kubectl get crd |grep gatekeeper.sh
assign.mutations.gatekeeper.sh                        2025-10-16T05:48:47Z
assignmetadata.mutations.gatekeeper.sh                2025-10-16T05:48:47Z
configs.config.gatekeeper.sh                          2025-10-16T05:48:47Z
constraintpodstatuses.status.gatekeeper.sh            2025-10-16T05:48:47Z
constrainttemplatepodstatuses.status.gatekeeper.sh    2025-10-16T05:48:47Z
constrainttemplates.templates.gatekeeper.sh           2025-10-16T05:48:47Z
modifyset.mutations.gatekeeper.sh                     2025-10-16T05:48:47Z
mutatorpodstatuses.status.gatekeeper.sh               2025-10-16T05:48:47Z
providers.externaldata.gatekeeper.sh                  2025-10-16T05:48:47Z
```

`<font style="color:#DF2A3F;">Gatekeeper</font>`<font style="color:#DF2A3F;"> </font>使用 OPA 约束框架来描述和执行策略，在定义约束之前必须首先定义一个 `<font style="color:#DF2A3F;">ConstraintTemplate</font>`<font style="color:#DF2A3F;"> </font>对象，<font style="color:#DF2A3F;">它描述了强制执行约束的 Rego 和约束的模式。约束的模式允许管理员对约束的行为进行微调，就像函数的参数一样。</font>

如下所示是一个约束模板，<u><font style="color:#DF2A3F;">描述了验证的对象必须要有标签存在</font></u>：

```yaml
# k8srequiredlabels_template.yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema: # Schema for the `parameters` field
          type: object
          description: Describe K8sRequiredLabels crd parameters
          properties:
            labels:
              type: array
              items:
                type: string
                description: A label string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels

        violation[{"msg": msg, "details": {"missing_labels": missing}}] {
          provided := {label | input.review.object.metadata.labels[label]}
          required := {label | label := input.parameters.labels[_]}
          missing := required - provided
          count(missing) > 0
          msg := sprintf("you must provide labels: %v", [missing])
        }
```

直接应用上面的 `<font style="color:#DF2A3F;">ConstraintTemplate</font>`<font style="color:#DF2A3F;"> </font>资源清单：

```shell
➜ kubectl apply -f k8srequiredlabels_template.yaml
constrainttemplate.templates.gatekeeper.sh/k8srequiredlabels created

➜ kubectl get ConstraintTemplate
NAME                AGE
k8srequiredlabels   10s
```

上面我们的定义的 `<font style="color:#DF2A3F;">ConstraintTemplate</font>`<font style="color:#DF2A3F;"> </font>对象就是一个模板，其中的 `<font style="color:#DF2A3F;">crd</font>`<font style="color:#DF2A3F;"> </font>部分描述了我们定义的 CRD 模板，比如类型叫 `<font style="color:#DF2A3F;">K8sRequiredLabels</font>`，需要和模板的名称保持一致，然后通过下面的 `<font style="color:#DF2A3F;">validation</font>`<font style="color:#DF2A3F;"> </font>定义了我们的 CRD 的属性 Schema，比如有一个 `<font style="color:#DF2A3F;">labels</font>`<font style="color:#DF2A3F;"> </font>的属性参数，类似是字符串数据类型：

```yaml
crd:
  spec:
    names:
      kind: K8sRequiredLabels
    validation:
      openAPIV3Schema: # Schema for the `parameters` field
        type: object
        description: Describe K8sRequiredLabels crd parameters
        properties:
          labels:
            type: array
            items:
              type: string
              description: A label string
```

然后下面的 `<font style="color:#DF2A3F;">targets</font>`<font style="color:#DF2A3F;"> </font>部分就是定义的约束目标，使用 Rego 进行编写。

+ 首先通过 `<font style="color:#DF2A3F;">provided := {label | input.review.object.metadata.labels[label]}</font>` 获取到创建对象的所有 `<font style="color:#DF2A3F;">label</font>` 标签
+ 然后通过 `<font style="color:#DF2A3F;">required := {label | label := input.parameters.labels[_]}</font>` 获取到需要提供的 label 标签
+ 将上面两个标签集合相减（rego 语言支持该操作），得到未满足的 label
+ 断言未满足的 label 数量 > 0，如果大于 0，说明条件满足，violation 为 true，说明违反了约束，返回错误

上面的约束模板创建完成后，实际上相当于创建了一个名为的 `<font style="color:#DF2A3F;">K8sRequiredLabels</font>`<font style="color:#DF2A3F;"> </font>对象，我们定义的属性位于 `<font style="color:#DF2A3F;">spec.parameters</font>`<font style="color:#DF2A3F;"> </font>属性下面：

```shell
➜ kubectl get K8sRequiredLabels
No resources found

➜ kubectl explain K8sRequiredLabels.spec.parameters.labels
KIND:     K8sRequiredLabels
VERSION:  constraints.gatekeeper.sh/v1beta1

FIELD:    labels <[]string>

DESCRIPTION:

     A label string
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760593907915-397e2ccb-020e-4cb0-8050-54f1a064d3f4.png)

现在我们就可以使用上面的 `<font style="color:#DF2A3F;">K8sRequiredLabels</font>`<font style="color:#DF2A3F;"> </font>这个约束模板来定义策略了，比如我们要求在所有命名空间上都定义一个 `<font style="color:#DF2A3F;">gatekeeper</font>`<font style="color:#DF2A3F;"> </font>的标签，则可以创建如下所示的对象：

```yaml
# all_ns_must_have_gatekeeper.yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: ns-must-have-gk
spec:
  match:
    kinds:
      - apiGroups: ['']
        kinds: ['Namespace'] # 表示这个约束会在创建命名空间的时候被应用，可以使用 namespaceSelector、namespaces等进行过滤
  parameters:
    labels: ['gatekeeper'] # 根据schema规范定义
```

注意 match 字段，它定义了将应用给定约束的对象的范围，其中 `<font style="color:#DF2A3F;">kinds: ["Namespace"]</font>` 表示这个约束会在创建命名空间的时候被应用，此外它还支持其他匹配器：

+ `<font style="color:#DF2A3F;">kind</font>`<font style="color:#DF2A3F;"> </font>接受带有 apiGroups 和 kind 字段的对象列表，这些字段列出了约束将应用到的对象的组/种类。如果指定了多个组/种类对象，则资源在范围内只需要一个匹配项。
+ `<font style="color:#DF2A3F;">scope</font>`<font style="color:#DF2A3F;"> </font>接受 _、_Cluster 或 Namespaced 决定是否选择集群范围和/或命名空间范围的资源。（默认为）
+ `<font style="color:#DF2A3F;">namespaces</font>`<font style="color:#DF2A3F;"> </font>是命名空间名称的列表。如果已定义，则约束仅适用于列出的命名空间中的资源。命名空间还支持基于前缀的 glob。例如，`<font style="color:#DF2A3F;">namespaces: [kube-*]</font>` 匹配 kube-system 和 kube-public。
+ `<font style="color:#DF2A3F;">excludeNamespaces</font>`<font style="color:#DF2A3F;"> </font>是命名空间名称的列表。如果已定义，则约束仅适用于不在列出的命名空间中的资源。ExcludedNamespaces 还支持基于前缀的 glob，例如，`<font style="color:#DF2A3F;">excludedNamespaces: [kube-*]</font>` 匹配 kube-system 和 kube-public。
+ `<font style="color:#DF2A3F;">labelSelector</font>`<font style="color:#DF2A3F;"> </font>是标准的 Kubernetes 标签选择器。
+ `<font style="color:#DF2A3F;">namespaceSelector</font>`<font style="color:#DF2A3F;"> </font>是针对对象的包含名称空间或对象本身的标签选择器，如果对象是名称空间。name 是对象的名称。如果已定义，则匹配具有指定名称的对象。Name 还支持基于前缀的 glob。例如，名称：pod-* 匹配 pod-a 和 pod-b。

下面的<font style="color:#DF2A3F;"> </font>`<font style="color:#DF2A3F;">parameters.labels</font>` 就是根据上面的 CRD 规范定义的属性，该值是传递给 opa 的参数，此处表示一个 key 为 labels，value 为一个列表的字典，与 `<font style="color:#DF2A3F;">ConstraintTemplate</font>`<font style="color:#DF2A3F;"> </font>里的 `<font style="color:#DF2A3F;">properties</font>`<font style="color:#DF2A3F;"> </font>要匹配上，此处表示要创建的对象需要含有 `<font style="color:#DF2A3F;">gatekeeper</font>`<font style="color:#DF2A3F;"> </font>的 label。

直接应用上面的这个资源对象即可：

```shell
➜ kubectl apply -f all_ns_must_have_gatekeeper.yaml
k8srequiredlabels.constraints.gatekeeper.sh/ns-must-have-gk created
```

创建完成后可以查看到这个 `<font style="color:#DF2A3F;">constraints</font>`<font style="color:#DF2A3F;"> </font>对象：

```shell
➜ kubectl get k8srequiredlabels
NAME              AGE
ns-must-have-gk   35s

➜ kubectl get constraints  # 和上面对象一样
NAME              AGE
ns-must-have-gk   35s
```

由于 `<font style="color:#DF2A3F;">Gatekeeper</font>`<font style="color:#DF2A3F;"> </font>具有审计功能，可以根据集群中执行的约束条件对资源进行定期评估，以检测预先存在的错误配置，`<font style="color:#DF2A3F;">Gatekeeper</font>`<font style="color:#DF2A3F;"> </font>将审计结果存储为相关约束条件的 `<font style="color:#DF2A3F;">status</font>`<font style="color:#DF2A3F;"> </font>字段中列出违规行为。我们可以查看 `<font style="color:#DF2A3F;">K8sRequiredLabels</font>`<font style="color:#DF2A3F;"> </font>对象的 `<font style="color:#DF2A3F;">status</font>`<font style="color:#DF2A3F;"> </font>字段来查看不符合约束的行为：

```shell
➜ kubectl get constraints ns-must-have-gk -o yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
[......]
status:
  auditTimestamp: "2025-11-27T07:42:38Z"
  ......
  totalViolations: 11
  violations:
  - enforcementAction: deny
    kind: Namespace
    message: 'you must provide labels: {"gatekeeper"}'
    name: apisix
  - enforcementAction: deny
    kind: Namespace
    message: 'you must provide labels: {"gatekeeper"}'
    name: default
[......]
```

比如现在我们创建一个如下所示的 Namespace：

```yaml
# test-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ns-test
  labels:
    a: b
    # gatekeeper: abc
```

此时不给命名空间 Label 标签添加 key 为 `<font style="color:#DF2A3F;">gatekeeper</font>`<font style="color:#DF2A3F;"> </font>的 label，创建的时候就会报错：

```shell
$ kubectl apply -f test-namespace.yaml 
Error from server ([ns-must-have-gk] you must provide labels: {"gatekeeper"}): error when creating "test-namespace.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [ns-must-have-gk] you must provide labels: {"gatekeeper"}
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760594913366-ae961121-150a-4192-acd6-ed60ca4bb97d.png)

然后把 `<font style="color:#DF2A3F;">gatekeeper: abc</font>` 这行的注释打开，则能成功创建了，这就是 `<font style="color:#DF2A3F;">Gatekeeper</font>`<font style="color:#DF2A3F;"> </font>的基本用法。

```yaml
# test-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ns-test
  labels:
    a: b
    gatekeeper: abc
```

```shell
$ kubectl apply -f test-namespace.yaml 
namespace/ns-test created

$ kubectl get namespaces ns-test --show-labels 
NAME      STATUS   AGE   LABELS
ns-test   Active   15m   a=b,gatekeeper=abc,kubernetes.io/metadata.name=ns-test
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760594929112-6abb436d-fa39-40b9-9e01-a36c040f2cdc.png)

从上面我们可以知道定义约束模板的策略会经常从 `<font style="color:#DF2A3F;">input</font>`<font style="color:#DF2A3F;"> </font>对象中获取数据，但是如果需要创建自己的约束，但是不知道传入的参数即 `<font style="color:#DF2A3F;">input</font>`<font style="color:#DF2A3F;"> </font>是什么，有一种简单方法是使用拒绝所有请求并将请求对象作为其拒绝消息输出的约束/模板。我们可以在创建模板时在 `<font style="color:#DF2A3F;">violation</font>`<font style="color:#DF2A3F;"> </font>中只保留一行 `<font style="color:#DF2A3F;">msg := sprintf("input: %v", [input])</font>`，此时创建对象时必定会失败，然后获取到输出的错误信息，里面即包含所有 `<font style="color:#DF2A3F;">input</font>`<font style="color:#DF2A3F;"> </font>信息，之后再通过 Rego 语法去获取需要的数据即可。

```yaml
# k8sdenyall_template.yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sdenyall
spec:
  crd:
    spec:
      names:
        kind: K8sDenyAll
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sdenyall

        violation[{"msg": msg}] {
          msg := sprintf("input:  %v", [input])
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sDenyAll
metadata:
  name: deny-all-namespaces
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Namespace"]
```

由于约束模板或者说策略库具有一定的通用性，所以 `<font style="color:#DF2A3F;">OPA Gatekeeper</font>` 社区提供了一个通用的策略库：[https://github.com/open-policy-agent/gatekeeper-library](https://github.com/open-policy-agent/gatekeeper-library)，该仓库中包含了大量通用的约束模板。

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760596006662-5a988f74-02ff-41cb-aadf-894a94905265.png)

每个模板库下面都包含一个 `<font style="color:#DF2A3F;">template.yaml</font>` 文件用来描述约束模板，`<font style="color:#DF2A3F;">samples</font>`<font style="color:#DF2A3F;"> </font>目录下面就包含具体的约束对象和示例资源清单，这些策略也是我们去学习 Rego 语言的很好的案例。

## 5 Rego 语言
上面的示例为我们详细介绍了如何使用 OPA 来配置我们的策略规则，其中最核心的就是使用 Rego 编写的策略规则，Rego 是专门为表达复杂的分层数据结构的策略而设计的，所以要掌握 OPA 的使用对 Rego 的了解是必不可少的。

### <font style="color:rgb(0, 0, 0);">5.1 Rego 语言概述</font>
<font style="color:rgb(0, 0, 0);">Rego 是</font>**<font style="color:rgb(0, 0, 0);">Open Policy Agent（OPA，云原生计算基金会 CNCF 毕业项目）</font>**<font style="color:rgb(0, 0, 0);">的核心策略语言，专为</font>**<font style="color:rgb(0, 0, 0);">声明式策略定义</font>**<font style="color:rgb(0, 0, 0);">设计，旨在将策略逻辑从业务代码中解耦，实现“策略即代码”（Policy as Code）。它受到 Datalog 启发，扩展了对 JSON 等结构化数据的支持，语法简洁、可读性强，适合表达</font>**<font style="color:rgb(0, 0, 0);">集合逻辑</font>**<font style="color:rgb(0, 0, 0);">与</font>**<font style="color:rgb(0, 0, 0);">条件判断</font>**<font style="color:rgb(0, 0, 0);">，广泛应用于访问控制、合规检查、资源管理等场景。</font>

### <font style="color:rgb(0, 0, 0);">5.2 Rego 语言的核心特性</font>
1. **<font style="color:rgb(0, 0, 0);">声明式语法</font>**<font style="color:rgb(0, 0, 0);">：专注于“要实现的结果”而非“实现方式”，规则以</font><font style="color:rgb(0, 0, 0);"> </font>`<font style="color:rgb(0, 0, 0);">if-then</font>`<font style="color:rgb(0, 0, 0);">逻辑形式定义（如</font><font style="color:rgb(0, 0, 0);"> </font>`<font style="color:rgb(0, 0, 0);">allow { input.user.role == "admin" }</font>`<font style="color:rgb(0, 0, 0);">），便于团队协作与审计。</font>
2. **<font style="color:rgb(0, 0, 0);">JSON 兼容</font>**<font style="color:rgb(0, 0, 0);">：输入（</font>`<font style="color:rgb(0, 0, 0);">input</font>`<font style="color:rgb(0, 0, 0);">）与输出（</font>`<font style="color:rgb(0, 0, 0);">decision</font>`<font style="color:rgb(0, 0, 0);">）均为标准 JSON 格式，与配置文件（如 Kubernetes YAML、Terraform HCL）天然契合。</font>
3. **<font style="color:rgb(0, 0, 0);">规则类型丰富</font>**<font style="color:rgb(0, 0, 0);">：</font>
    - **<font style="color:rgb(0, 0, 0);">完全规则（Complete Rules）</font>**<font style="color:rgb(0, 0, 0);">：产生单一确定值（如</font><font style="color:rgb(0, 0, 0);"> </font>`<font style="color:rgb(0, 0, 0);">default allow = false</font>`<font style="color:rgb(0, 0, 0);">）；</font>
    - **<font style="color:rgb(0, 0, 0);">增量规则（Incremental Rules）</font>**<font style="color:rgb(0, 0, 0);">：产生满足条件的集合（如</font><font style="color:rgb(0, 0, 0);"> </font>`<font style="color:rgb(0, 0, 0);">public_networks[net.id] { net.public }</font>`<font style="color:rgb(0, 0, 0);">）。</font>
4. **<font style="color:rgb(0, 0, 0);">内置函数与测试支持</font>**<font style="color:rgb(0, 0, 0);">：提供字符串处理、数学计算、集合操作等内置函数，支持通过单元测试验证规则正确性。</font>

### <font style="color:rgb(0, 0, 0);">5.3 Rego 语言的应用场景</font>
<font style="color:rgb(0, 0, 0);">Rego 语言通过 OPA 引擎，可实现</font>**<font style="color:rgb(0, 0, 0);">跨场景的策略统一管理</font>**<font style="color:rgb(0, 0, 0);">，典型应用包括：</font>

+ **<font style="color:rgb(0, 0, 0);">Kubernetes 准入控制</font>**<font style="color:rgb(0, 0, 0);">：通过 Gatekeeper 项目，验证 Deployment、Pod 等资源的合规性（如禁止容器以 root 身份运行、要求资源限制）；</font>
+ **<font style="color:rgb(0, 0, 0);">API 授权管理</font>**<font style="color:rgb(0, 0, 0);">：作为 API Gateway（如 Envoy）的外部授权服务，统一管理微服务的访问控制（如仅管理员可访问敏感接口）；</font>
+ **<font style="color:rgb(0, 0, 0);">云原生配置校验</font>**<font style="color:rgb(0, 0, 0);">：结合 Conftest 工具，验证 Terraform、Kubernetes 配置文件是否符合安全标准（如禁止暴露敏感端口）；</font>
+ **<font style="color:rgb(0, 0, 0);">基础设施合规检查</font>**<font style="color:rgb(0, 0, 0);">：在 CI/CD 流水线中集成 OPA，评估资源配置是否符合企业规范（如要求所有资源添加标签）。</font>

### <font style="color:rgb(0, 0, 0);">5.4 Rego 语言的学习网站与资源</font>
<font style="color:rgb(0, 0, 0);">以下是</font>**<font style="color:rgb(0, 0, 0);">权威、全面</font>**<font style="color:rgb(0, 0, 0);">的 Rego 学习资源，覆盖从基础入门到高级实践的全流程：</font>

#### <font style="color:rgb(0, 0, 0);">5.4.1. </font>**<font style="color:rgb(0, 0, 0);">官方文档（首选）</font>**
OPA 官方网站提供**最权威的 Rego 教程**，包括语法详解、规则编写指南、实战案例等。推荐路径：

+ **入门**：[Rego 语言概述](https://www.openpolicyagent.org/docs/latest/policy-language/#what-is-rego)（了解核心概念与语法）；
+ **实战**：[Rego 规则编写教程](https://www.openpolicyagent.org/docs/latest/how-do-i-write-policies/)（通过示例学习规则定义）；
+ **高级**：[Rego 测试与调试](https://www.openpolicyagent.org/docs/latest/testing/)（掌握单元测试与错误排查）。

#### <font style="color:rgb(0, 0, 0);">5.4.2. </font>**<font style="color:rgb(0, 0, 0);">Styra Academy（免费课程）</font>**
<font style="color:rgb(0, 0, 0);">Styra 是 OPA 的主要维护者，其 Academy 平台提供</font>**<font style="color:rgb(0, 0, 0);">免费的 Rego 与 OPA 在线课程</font>**<font style="color:rgb(0, 0, 0);">，包括视频教程、实验环境与认证考试。适合初学者快速上手，内容涵盖：</font>

+ <font style="color:rgb(0, 0, 0);">Rego 基础语法；</font>
+ <font style="color:rgb(0, 0, 0);">OPA 集成（Kubernetes、API Gateway 等）；</font>
+ <font style="color:rgb(0, 0, 0);">策略管理与审计。</font>

#### <font style="color:rgb(0, 0, 0);">5.4.3. </font>**<font style="color:rgb(0, 0, 0);">Rego Playground（在线沙盒）</font>**
<font style="color:rgb(0, 0, 0);">OPA 官方提供的</font>**<font style="color:rgb(0, 0, 0);">在线执行平台</font>**<font style="color:rgb(0, 0, 0);">，无需安装即可编写、测试 Rego 规则。界面分为四部分：</font>

+ **<font style="color:rgb(0, 0, 0);">Policy</font>**<font style="color:rgb(0, 0, 0);">：编写 Rego 代码；</font>
+ **<font style="color:rgb(0, 0, 0);">Input</font>**<font style="color:rgb(0, 0, 0);">：输入 JSON 数据；</font>
+ **<font style="color:rgb(0, 0, 0);">Data</font>**<font style="color:rgb(0, 0, 0);">：加载基础数据；</font>
+ **<font style="color:rgb(0, 0, 0);">Output</font>**<font style="color:rgb(0, 0, 0);">：查看决策结果。</font>

<font style="color:rgb(0, 0, 0);">适合快速验证规则逻辑（如</font><font style="color:rgb(0, 0, 0);"> </font>`<font style="color:rgb(0, 0, 0);">allow</font>`<font style="color:rgb(0, 0, 0);">规则的触发条件）。</font>

#### <font style="color:rgb(0, 0, 0);">5.4.4. </font>**<font style="color:rgb(0, 0, 0);">Awesome OPA（资源集合）</font>**
<font style="color:rgb(0, 0, 0);">GitHub 上的</font>**<font style="color:rgb(0, 0, 0);">OPA 生态资源库</font>**<font style="color:rgb(0, 0, 0);">（由 Styra 维护），包含：</font>

+ <font style="color:rgb(0, 0, 0);">官方文档链接；</font>
+ <font style="color:rgb(0, 0, 0);">社区工具（如 Conftest、Gatekeeper）；</font>
+ <font style="color:rgb(0, 0, 0);">示例策略（Kubernetes、Terraform 等场景）；</font>
+ <font style="color:rgb(0, 0, 0);">集成教程（微服务、API 网关等）。</font>

<font style="color:rgb(0, 0, 0);">是查找实战案例与工具的首选。</font>

### <font style="color:rgb(0, 0, 0);">5.5 总结</font>
<font style="color:rgb(0, 0, 0);">Rego 语言是云原生场景下的</font>**<font style="color:rgb(0, 0, 0);">策略管理神器</font>**<font style="color:rgb(0, 0, 0);">，通过声明式语法与 OPA 引擎，实现策略的统一管理与解耦。学习 Rego 的关键是</font>**<font style="color:rgb(0, 0, 0);">掌握声明式思维</font>**<font style="color:rgb(0, 0, 0);">与</font>**<font style="color:rgb(0, 0, 0);">实战案例</font>**<font style="color:rgb(0, 0, 0);">，推荐从官方文档与 Playground 入手，结合 Awesome OPA 的资源深化理解。无论是 Kubernetes 准入控制还是 API 授权，Rego 都能提供灵活、可扩展的策略解决方案。</font>

## 6 Pod 的安全策略（已经废弃）
:::warning
Pod 的安全策略（已经废弃）

:::

[🕸️[K8S] 19 Pod 的安全策略](https://www.yuque.com/seekerzw/xi8l23/mfzyytwtz8hggygu)

## 7 清理环境
```shell
# 删除 OPA 的策略配置即可
$ kubectl delete -f k8srequiredlabels_template.yaml
```

