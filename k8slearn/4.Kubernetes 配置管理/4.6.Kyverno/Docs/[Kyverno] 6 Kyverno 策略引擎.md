> Link Reference：[为什么选择 Kyverno 作为 Kubernetes 的策略引擎，而不是 Gatekeeper？](https://mp.weixin.qq.com/s/_jAsBQeTy-ehcqHWTNfmVg?scene=1)
>
> KRO Link Reference：[资源编排器 (kro): 如何简化与标准化 Kubernetes 部署](https://mp.weixin.qq.com/s/vdMhionN6Xm8rTpIWX4T7Q)
>

OPA 的 `<font style="color:#DF2A3F;">Gatekeeper</font>`<font style="color:#DF2A3F;"> </font>以及 `<font style="color:#DF2A3F;">Kyverno</font>`<font style="color:#DF2A3F;"> </font>是 CNCF 的两个头部策略管理项目，两个产品各有千秋，前面我们已经学习了 `<font style="color:#DF2A3F;">Gatekeeper</font>`，接下来我们就来了解下如何使用 `<font style="color:#DF2A3F;">Kyverno</font>`。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570256004-78fb8721-53f6-4b5f-a130-9ddcfc0765bf.png)

[Kyverno](https://kyverno.io/) 是来自 Nirmata 的开源项目，后来也捐赠给了 CNCF。**<font style="color:#DF2A3F;">和 Gatekeeper 一样，Kyverno 也是一个具有验证和变异能力的 Kubernetes 策略引擎，但是它还有生成资源的功能，最近还加入了 API 对象查询的能力。</font>**与 Gatekeeper 不同，Kyverno 原本就是为 Kubernetes 编写的。和 Gatekeeper 相比，Kyverno 除了对象生成功能之外，还无需专用语言即可编写策略，<u><font style="color:#DF2A3F;">从实现语言的角度上来看，Kyverno 的模型更为简洁。毕竟 Gatekeeper 的 Rego 语言有一定的门槛。</font></u>

同样 <font style="color:#DF2A3F;">Kyverno 在 Kubernetes 集群中也是作为动态准入控制器运行的。</font>Kyverno 从 kube-apiserver 接收验证和修改准入 webhook HTTP 回调，并应用匹配策略返回执行准入策略或拒绝请求的结果。Kyverno 策略可以使用资源 Kind、name 和标签选择器匹配资源，而且名称中支持通配符。

策略执行是通过 Kubernetes events 来捕获的，Kyverno 还报告现有资源的策略违规行为。下图显示了 Kyverno 的整体架构：

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570257312-7e4c8ff1-0ea4-4290-875b-49786f9fdbf7.png)

Kyverno 的高可用安装可以通过运行多个副本来完成，并且 Kyverno 的每个副本将具有多个执行不同功能的控制器。Webhook 处理来自 Kubernetes APIServer 的 `<font style="color:#DF2A3F;">AdmissionReview</font>`<font style="color:#DF2A3F;"> </font>请求，其 Monitor 组件创建和管理所需的配置。`<font style="color:#DF2A3F;">PolicyController</font>`<font style="color:#DF2A3F;"> </font>watch 策略资源并根据配置的扫描间隔启动后台扫描，`<font style="color:#DF2A3F;">GenerateController</font>`<font style="color:#DF2A3F;"> </font>管理生成资源的生命周期。

## 1 Gatekeeper 和 Kyverno 对比
由于 Gatekeeper 与 Kyverno 都是策略管理的项目，所以自然我们要对这两个项目的优劣势做一个对比。

**Gatekeeper 的优势**

+ 能够表达非常复杂的策略；
+ 社区更为成熟；
+ 支持多副本模式，更好的可用性和伸缩性。

**Gatekeeper 的劣势**

+ 需要编程语言支持，该语言的学习曲线较为陡峭，可能会产生大量技术债，并延长交付时间；
+ 没有生成能力，意味着它的主要应用场景就在验证方面；
+ 策略复杂冗长，需要多个对象协同实现。

**Kyverno 的优势**

+ Kubernetes 风格的策略表达方式，非常易于编写；
+ 成熟的变异能力；
+ 独特的生成和同步能力，扩展了应用场景；
+ 快速交付，场景丰富。

**Kyverno 的劣势**

+ 受到语言能力的限制，难以实现复杂策略；
+ 较为年轻，社区接受度不高；
+ API 对象查询能力还很初级；

从上面对比可以看出来<font style="color:#DF2A3F;"> </font>**<u><font style="color:#DF2A3F;">Gatekeeper 最大的弱点是它需要 Rego 这门语言来实现策略逻辑</font></u>**，而这种语言在其他地方都无法使用，这也大大增加了门槛，当然同样这也是一种优势，因为编程语言可以实现非常强大的逻辑。相比 Gatekeeper 来说，<font style="color:#DF2A3F;">Kyverno 的第一印象就是没有那么复杂的技术需求，因为它是专门为 Kubernetes 构建的，并且用声明式的方法来表达策略，所以它的模型与 Kubernetes 对象的描述和协调方式是相同的，这种模式导致策略的编写方式得到了极大的简化，全面的降低了策略引擎的使用难度。</font>此外 Kyverno 的编译和生成能力，使它从一个简单的准入控制器转变为一个真正的自动化工具。通过结合这三种能力，再加上最近增加的 API 查询能力，Kyverno 能够执行 Gatekeeper 所不能执行的任务。这种简单性加上它的自动化能力和对其他工具的整合，为新用户以及有经验的用户和操作者带来了巨大的价值。

当然具体选择哪一个工具，还是应该根据自己的需求和限制条件进行评估，但是有一点是所有生产环境的用户都应该计划使用策略引擎来保护集群的安全并简化 Kubernetes 管理。

:::warning
管理员如果是 DevOps 运维工程师则可以使用 Kyverno 来进行策略引擎的使用，不需要使用 Gatekeeper 来多学习 rego 的语言管理。

:::

## 2 安装 Kyverno
### 2.1 Kyverno 使用原生 Yaml 配置文件部署
> Reference：[https://kyverno.io/docs/installation/](https://kyverno.io/docs/installation/)
>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760597053819-52fe991c-d42e-4137-b83f-4a9f6e340a60.png)

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760597431295-67da3d57-5785-4f7e-90f4-9287edfe54b8.png)

你可以选择直接从最新版本的资源清单安装 Kyverno，直接执行下面的命令即可：

```shell
# 链接已经失效
# ➜ kubectl create -f https://raw.githubusercontent.com/kyverno/kyverno/main/config/install.yaml

# 查看 Kubernetes 的版本
➜ kubectl get node 
NAME             STATUS   ROLES           AGE     VERSION
hkk8smaster001   Ready    control-plane   2d22h   v1.27.6
hkk8snode001     Ready    <none>          2d22h   v1.27.6
hkk8snode002     Ready    <none>          2d22h   v1.27.6

# 使用适配对应 Kubernetes 的版本的 Kyverno 的版本
➜ kubectl create -f https://github.com/kyverno/kyverno/releases/download/v1.12.7/install.yaml
➜ kubectl get pod -n kyverno 
NAME                                             READY   STATUS    RESTARTS   AGE
kyverno-admission-controller-5c97895d96-fx6s2    1/1     Running   0          60s
kyverno-background-controller-5475bc76fb-bc4s9   1/1     Running   0          60s
kyverno-cleanup-controller-d65d88ccc-df5kr       1/1     Running   0          60s
kyverno-reports-controller-866c4475ff-qqz9v      1/1     Running   0          60s
```

<details class="lake-collapse"><summary id="u5ab683fa"><span class="ne-text">Bitnami 镜像缺失</span></summary><p id="ud288b5df" class="ne-p"><span class="ne-text">由于 Bitnami 镜像做了重大的改变，DockerHub 的镜像已经绝大部分清除，需要使用镜像源的 Docker 镜像来替换</span></p><div class="ne-quote"><p id="u1d3ef48f" class="ne-p"><span class="ne-text">Reference：</span><a href="https://docker.aityp.com/image/docker.io/bitnami/kubectl:1.28.9" data-href="https://docker.aityp.com/image/docker.io/bitnami/kubectl:1.28.9" target="_blank" class="ne-link"><span class="ne-text">https://docker.aityp.com/image/docker.io/bitnami/kubectl:1.28.9</span></a></p></div><pre data-language="shell" id="buocQ" class="ne-codeblock language-shell"><code>$ docker pull swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/bitnami/kubectl:1.28.9
$ docker tag  swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/bitnami/kubectl:1.28.9  docker.io/bitnami/kubectl:1.28.9</code></pre><p id="u7e3779bd" class="ne-p"><span class="ne-text">修改完成 </span><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">install.yaml</span></code><span class="ne-text"> 由于文件较长，不要使用 apply 的参数，使用 create 的参数执行资源清单文件即可！</span></p></details>
### 2.2 Kyverno 使用 Helm 进行部署
此外同样可以使用 Helm 来进行一键安装（推荐使用）：

```shell
➜ helm repo add kyverno https://kyverno.github.io/kyverno/
➜ helm repo update
# Install the Kyverno Helm chart into a new namespace called "kyverno"
➜ helm install kyverno kyverno/kyverno -n kyverno --create-namespace
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760596522905-316074f4-5dce-467a-b3b7-d0cd07a08acb.png)

安装完成会创建一个 kyverno 命名空间，同样也包含一些相关的 CRD：

```shell
➜ kubectl get pods -n kyverno
NAME                       READY   STATUS    RESTARTS   AGE
kyverno-69bdfcfc7c-dbtlt   1/1     Running   0          29m

➜ kubectl get validatingwebhookconfiguration
NAME                                            WEBHOOKS   AGE
kyverno-cleanup-validating-webhook-cfg          1          19m
kyverno-exception-validating-webhook-cfg        1          19m
kyverno-global-context-validating-webhook-cfg   1          19m
kyverno-policy-validating-webhook-cfg           1          19m
kyverno-resource-validating-webhook-cfg         0          19m
kyverno-ttl-validating-webhook-cfg              1          19m

➜ kubectl get mutatingwebhookconfigurations
NAME                                        WEBHOOKS   AGE
kyverno-policy-mutating-webhook-cfg         1          19m
kyverno-resource-mutating-webhook-cfg       0          19m
kyverno-verify-mutating-webhook-cfg         1          19m

➜ kubectl get crd | grep kyverno
admissionreports.kyverno.io                           2025-10-16T07:03:00Z
backgroundscanreports.kyverno.io                      2025-10-16T07:03:00Z
cleanuppolicies.kyverno.io                            2025-10-16T07:03:01Z
clusteradmissionreports.kyverno.io                    2025-10-16T07:03:01Z
clusterbackgroundscanreports.kyverno.io               2025-10-16T07:03:01Z
clustercleanuppolicies.kyverno.io                     2025-10-16T07:03:01Z
clusterephemeralreports.reports.kyverno.io            2025-10-16T07:03:02Z
clusterpolicies.kyverno.io                            2025-10-16T07:04:03Z
ephemeralreports.reports.kyverno.io                   2025-10-16T07:03:02Z
globalcontextentries.kyverno.io                       2025-10-16T07:03:01Z
policies.kyverno.io                                   2025-10-16T07:04:04Z
policyexceptions.kyverno.io                           2025-10-16T07:03:02Z
updaterequests.kyverno.io                             2025-10-16T07:03:02Z
```

可以看出安装完成后创建了几个 `<font style="color:#DF2A3F;">validatingwebhookconfiguration</font>`<font style="color:#DF2A3F;"> </font>与 `<font style="color:#DF2A3F;">mutatingwebhookconfigurations</font>`<font style="color:#DF2A3F;"> </font>对象。

## 3 策略与规则
使用 <u>Kyverno 其实就是对策略和规则的应用，Kyverno 策略是规则的集合，每个规则都包含一个 </u>`<u><font style="color:#DF2A3F;">match</font></u>`<u><font style="color:#DF2A3F;"> </font></u><u>声明、一个可选的 </u>`<u><font style="color:#DF2A3F;">exclude</font></u>`<u><font style="color:#DF2A3F;"> </font></u><u>声明以及 </u>`<u><font style="color:#DF2A3F;">validate</font></u>`<u>、</u>`<u><font style="color:#DF2A3F;">mutate</font></u>`<u>、</u>`<u><font style="color:#DF2A3F;">generate</font></u>`<u><font style="color:#DF2A3F;"> </font></u><u>或 </u>`<u><font style="color:#DF2A3F;">verifyImages</font></u>`<u><font style="color:#DF2A3F;"> </font></u><u>声明之一组成，每个规则只能包含一个 </u>`<u><font style="color:#DF2A3F;">validate</font></u>`<u>、</u>`<u><font style="color:#DF2A3F;">mutate</font></u>`<u>、</u>`<u><font style="color:#DF2A3F;">generate</font></u>`<u><font style="color:#DF2A3F;"> </font></u><u>或 </u>`<u><font style="color:#DF2A3F;">verifyImages</font></u>`<u><font style="color:#DF2A3F;"> </font></u><u>子声明。</u>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570257030-aad6b3b7-bea3-47a7-8597-8989c45cdfc6.png)

策略可以定义为集群范围的资源（`<font style="color:#DF2A3F;">ClusterPolicy</font>`）或命名空间级别资源（`<font style="color:#DF2A3F;">Policy</font>`）。

+ `<font style="color:#DF2A3F;">Policy</font>`<font style="color:#DF2A3F;"> </font>将仅适用于定义它们的 namespace 内的资源
+ `<font style="color:#DF2A3F;">ClusterPolicy</font>` 应用于匹配跨所有 namespace 的资源

## 4 策略定义
编写策略其实就是定义 `<font style="color:#DF2A3F;">Policy</font>`<font style="color:#DF2A3F;"> </font>或者 `<font style="color:#DF2A3F;">ClusterPolicy</font>`<font style="color:#DF2A3F;"> </font>对象。

### 4.1 验证资源
验证规则基本上是我们使用最常见和最实用的规则类型，当用户或进程创建新资源时，Kyverno 将根据验证规则检查该资源的属性，如果验证通过，则允许创建资源。如果验证失败，则创建被阻止。比如现在我们添加一个策略，要求所有的 Pod 都包含一个 kyverno 的标签：

```yaml
# kyverno-require-label.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-label
spec:
  validationFailureAction: enforce # 资源在创建时立即被阻止
  rules:
    - name: check-for-labels
      match:
        resources:
          kinds:
            - Pod
      validate: # 配置 Admission Webhook 的配置
        message: "label 'kyverno' is required"
        pattern:
          metadata:
            labels:
              kyverno: '?*'
```

上面策略文件中添加了一个 `<font style="color:#DF2A3F;">validationFailureAction=[Audit, Enforce]</font>` 属性：

+ 当处于 `<font style="color:#DF2A3F;">Audit</font>`<font style="color:#DF2A3F;"> </font>模式下 ，每当创建违反规则集的一个或多个规则的资源时，会允许 Admission Review 请求，并将结果添加到报告中。
+ 当处于 `<font style="color:#DF2A3F;">Enforce</font>`<font style="color:#DF2A3F;"> </font>模式下 ，资源在创建时立即被阻止，报告中不会有。

然后就是下面使用 `<font style="color:#DF2A3F;">rules</font>`<font style="color:#DF2A3F;"> </font>属性定义的规则集合，`<font style="color:#DF2A3F;">match</font>`<font style="color:#DF2A3F;"> </font>用于表示匹配的资源资源，`<font style="color:#DF2A3F;">validate</font>`<font style="color:#DF2A3F;"> </font>表示验证方式，这里我们<u>定义 </u>`<u><font style="color:#DF2A3F;">kyverno: "?*"</font></u>`<u> 这样的标签表示必须有这样的一个标签 key。</u>

直接应用上面的策略对象即可：

```shell
➜ kubectl apply -f kyverno-require-label.yaml
clusterpolicy.kyverno.io/require-label created

➜ kubectl get clusterpolicy
NAME            ADMISSION   BACKGROUND   VALIDATE ACTION   READY   AGE   MESSAGE
require-label   true        true         enforce           True    35s   Ready
```

现在我们添加一个不带标签 kyverno 的 Pod：

```shell
➜ kubectl run busybox --image=busybox:1.28.4  --restart=Never -- sleep 1000000
Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:

resource Pod/default/busybox was blocked due to the following policies

require-label:
  check-for-labels: 'validation error: label ''kyverno'' is required. Rule check-for-labels
    failed at path /metadata/labels/kyverno/'
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760598554417-3f33b7d0-b61f-42a8-bcd1-9ee3a1737b17.png)

可以看到提示，需要一个 kyverno 标签，同样我们也可以通过查看 Events 事件来了解策略应用情况：

```shell
➜ kubectl get events -A -w
[......]
default                0s          Warning   PolicyViolation     clusterpolicy/require-label                                    Pod kyverno/kyverno-cleanup-admission-reports-29343310-djf9m: [check-for-labels] fail; validation error: label 'kyverno' is required. rule check-for-labels failed at path /metadata/labels/kyverno/
default                0s          Warning   PolicyViolation     clusterpolicy/require-label                                    Pod opa/busybox: [check-for-labels] fail (blocked); validation error: label 'kyverno' is required. rule check-for-labels failed at path /metadata/labels/kyverno/
```

如果创建的 Pod 带有 kyverno 标签则可以正常创建：

```shell
➜ kubectl run busybox --image=busybox:1.28.4 --labels kyverno=demo --restart=Never -- sleep 1000000
pod/busybox created

# 清理环境
➜ kubectl delete pod busybox 
pod "busybox" deleted
```

如果将 `<u><font style="color:#DF2A3F;">validationFailureAction</font></u>`<u><font style="color:#DF2A3F;"> </font></u><u>的值更改为 </u>`<u><font style="color:#DF2A3F;">audit</font></u>`，则即使我们创建的 Pod 不带有 kyverno 标签，也可以创建成功，但是我们可以在 `<font style="color:#DF2A3F;">PolicyReport</font>`<font style="color:#DF2A3F;"> </font>对象中看到对应的违规报告：

```yaml
# kyverno-audit-label.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-label
spec:
  validationFailureAction: audit # 允许 Admission Review 请求，并将结果添加到报告中。
  rules:
    - name: check-for-labels
      match:
        resources:
          kinds:
            - Pod
      validate: # 配置 Admission Webhook 的配置
        message: "label 'kyverno' is required"
        pattern:
          metadata:
            labels:
              kyverno: '?*'
```

```shell
➜ kubectl apply -f kyverno-audit-label.yaml 
Warning: Validation failure actions enforce/audit are deprecated, use Enforce/Audit instead.
clusterpolicy.kyverno.io/require-label configured
# 后续的 Action 属性需要首字母大写

➜ kubectl run busybox --image=busybox:1.28.4 --restart=Never -- sleep 1000000
pod/busybox created

############################################################
# 旧版本的 Policyreports 策略报告
############################################################
➜ kubectl get policyreports
NAME              PASS   FAIL   WARN   ERROR   SKIP   AGE
polr-ns-default   0      2      0      0       0      20m

➜ kubectl describe policyreports | grep "Result: \+fail" -B10
  Owner References:
    API Version:     apps/v1
    Kind:            ReplicaSet
    Name:            opa-84b995d66b
    UID:             098a1b04-aca2-45dd-8313-e0a49d9ae086
  Resource Version:  643653
  UID:               93bb9b05-f769-4f60-a738-65a63bf898f2
Results:
  Message:  validation error: label 'kyverno' is required. rule autogen-check-for-labels failed at path /spec/template/metadata/labels/kyverno/
  Policy:   require-label
  Result:   fail
--
  Owner References:
    API Version:     v1
    Kind:            Pod
    Name:            busybox
    UID:             28421552-3080-4ddc-ac76-c42ac1d482e7
  Resource Version:  645325
  UID:               b3752a18-8bee-40cc-9ecb-e1b37c4e5d03
Results:
  Message:  validation error: label 'kyverno' is required. rule check-for-labels failed at path /metadata/labels/kyverno/
  Policy:   require-label
  
  Result:   fail

############################################################
# 新版本的 Policyreports 策略报告
############################################################
➜ kubectl get policyreports
NAME                                   KIND         NAME                   PASS   FAIL   WARN   ERROR   SKIP   AGE
1914caa0-a718-4b88-a6e0-d397d5a39dae   Pod          opa-84b995d66b-txphp   0      1      0      0       0      9m59s
25f6e021-a7dd-4086-98ca-507bc0d6600d   Pod          busybox                0      1      0      0       0      2m15s
42dd5579-7dce-4232-9990-a20b63857141   ReplicaSet   opa-84b995d66b         0      1      0      0       0      10m
b9b4d436-0111-4db7-997c-548ff5704991   Deployment   opa                    0      1      0      0       0      9m57s
➜ kubectl get policyreports 25f6e021-a7dd-4086-98ca-507bc0d6600d -o yaml 
apiVersion: wgpolicyk8s.io/v1alpha2
kind: PolicyReport
metadata:
  creationTimestamp: "2025-10-28T02:58:52Z"
  generation: 2
  labels:
    app.kubernetes.io/managed-by: kyverno
  name: 25f6e021-a7dd-4086-98ca-507bc0d6600d
  namespace: opa
  ownerReferences:
  - apiVersion: v1
    kind: Pod
    name: busybox
    uid: 25f6e021-a7dd-4086-98ca-507bc0d6600d
  resourceVersion: "2628129"
  uid: f51affa6-5ee6-4ef4-af9d-0e141e7726de
results:
- message: 'validation error: label ''kyverno'' is required. rule check-for-labels
    failed at path /metadata/labels/kyverno/'
  policy: require-label
  result: fail
  rule: check-for-labels
  scored: true
  source: kyverno
  timestamp:
    nanos: 0
    seconds: 1761620342
scope:
  apiVersion: v1
  kind: Pod
  name: busybox
  namespace: opa
  uid: 25f6e021-a7dd-4086-98ca-507bc0d6600d
summary:
  error: 0
  fail: 1
  pass: 0
  skip: 0
  warn: 0
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761620500190-572c6228-0a70-48bc-bcac-342df6e5ff86.png)

从上面的报告资源中可以看到违反策略的资源对象。

### 4.2 变更规则
<u><font style="color:#DF2A3F;">变更规则可以用于修改匹配到规则的资源（比如规则设置了 metadata 字段可以和资源的 metadata 进行合并），就是根据我们设置的规则来修改对应的资源。</font></u>

比如现在我们添加如下所示一个策略，给所有包含 nginx 镜像 的 Pod 都加上一个标签（`<font style="color:#DF2A3F;">kyverno=nginx</font>`）：

```yaml
# kyverno-mutate-label.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: nginx-label
spec:
  rules:
    - name: nginx-label
      match:
        resources:
          kinds:
            - Pod
      mutate:
        patchStrategicMerge:
          metadata:
            labels:
              kyverno: nginx # 添加 Pod 的标签
          spec:
            (containers):
              - (image): '*nginx*' # 容器镜像包含 nginx 即可
```

直接应用上面这个策略对象即可：

```shell
# 引用资源清单文件
➜ kubectl apply -f kyverno-mutate-label.yaml
clusterpolicy.kyverno.io/nginx-label created

➜ kubectl get clusterpolicy nginx-label
NAME          ADMISSION   BACKGROUND   VALIDATE ACTION   READY   AGE   MESSAGE
nginx-label   true        true         Audit             True    10s   Ready
```

现在我们使用 nginx 镜像直接创建一个 Pod：

```shell
➜ kubectl run --image=nginx nginx
pod/nginx created

# 查看 Pod 的标签
➜ kubectl get pod nginx --show-labels
NAME    READY   STATUS    RESTARTS   AGE   LABELS
nginx   1/1     Running   0          5s    kyverno=nginx,run=nginx
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760599216503-279b1fc7-7485-4456-b70a-ceb86d334a48.png)

可以看到 Pod 创建成功后包含了一个 `<font style="color:#DF2A3F;">kyverno=nginx</font>` 标签，由于有 kyverno 标签，所以上面的验证策略也是通过的，可以正常创建。

### 4.3 生成资源
<u><font style="color:#DF2A3F;">生成规则可用于在创建新资源或更新源时创建其他资源</font></u>，例如为命名空间创建新 RoleBindings 或 Secret 等。

比如现在我们一个需求是将某个 Secret 同步到其他命名空间中去（比如 TLS 密钥、镜像仓库认证信息），手动复制这些 Secret 比较麻烦，则我们可以使用 Kyverno 来创建一个策略帮助我们同步这些 Secret。比如在 `<font style="color:#DF2A3F;">default</font>`<font style="color:#DF2A3F;"> </font>命名空间中有一个名为 `<font style="color:#DF2A3F;">regcred</font>`<font style="color:#DF2A3F;"> </font>的 Secret 对象，需要复制到另外的命名空间，如果源 Secret 发生更改，它还将向复制的 Secret 同步更新。

```yaml
# kyverno-generate-secret.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: sync-secrets
spec:
  rules:
    - name: sync-image-pull-secret
      match:
        resources:
          kinds:
            - Namespace
      generate: # 生成的资源对象
        apiVersion: v1
        kind: Secret
        name: regcred
        namespace: '{{request.object.metadata.name}}' # 获取目标命名空间
        synchronize: true
        clone:
          namespace: default
          name: regcred
```

先在 `<font style="color:#DF2A3F;">default</font>` 命名空间中准备我们的 Secret 对象：

```shell
➜ kubectl create secret docker-registry regcred \
  --docker-server=DOCKER_REGISTRY_SERVER \
  --docker-username=DOCKER_USER \
  --docker-password=DOCKER_PASSWORD \
  --docker-email=DOCKER_EMAIL --namespace default
secret/regcred created

➜ kubectl create secret docker-registry regcred \
  --docker-username=<DOCKER_USER> \
  --docker-password=<DOCKER_PASSWORD> \
  --docker-email=<DOCKER_EMAIL> --namespace default
secret/regcred created
```

然后应用上面的同步 Secret 策略：

```shell
➜ kubectl apply -f kyverno-generate-secret.yaml
clusterpolicy.kyverno.io/sync-secrets created

➜ kubectl get clusterpolicy sync-secrets 
NAME           ADMISSION   BACKGROUND   VALIDATE ACTION   READY   AGE   MESSAGE
sync-secrets   true        true         Audit             True    10s   Ready
```

现在我们创建一个新的命名空间：

```shell
➜ kubectl create ns test
namespace/test created

➜ kubectl get secret --namespace test
NAME      TYPE                             DATA   AGE
regcred   kubernetes.io/dockerconfigjson   1      10s

➜ kubectl get secrets -n test regcred -o yaml 
apiVersion: v1
data:
  .dockerconfigjson: eyJhdXRocyI6eyJodHRwczovL2luZGV4LmRvY2tlci5pby92MS8iOnsidXNlcm5hbWUiOiJkcmFnb256dyIsInBhc3N3b3JkIjoiU1p6aG9uZ2Fpc2xmIiwiZW1haWwiOiJkcmFnb256d0BrdWJlc3BoZXJlLmFpIiwiYXV0aCI6IlpISmhaMjl1ZW5jNlUxcDZhRzl1WjJGcGMyeG0ifX19
kind: Secret
metadata:
  creationTimestamp: "2025-10-28T03:08:13Z"
  labels:
    app.kubernetes.io/managed-by: kyverno
    generate.kyverno.io/clone-source: ""
    generate.kyverno.io/policy-name: sync-secrets
    generate.kyverno.io/policy-namespace: ""
    generate.kyverno.io/rule-name: sync-image-pull-secret
    generate.kyverno.io/source-group: ""
    generate.kyverno.io/source-kind: Secret
    generate.kyverno.io/source-namespace: default
    generate.kyverno.io/source-uid: 7e9a782d-3e25-419d-866e-73535a6e562a
    generate.kyverno.io/source-version: v1
    generate.kyverno.io/trigger-group: ""
    generate.kyverno.io/trigger-kind: Namespace
    generate.kyverno.io/trigger-namespace: ""
    generate.kyverno.io/trigger-uid: 7700b18c-f2d8-4efd-af8c-1add8fbb9c53
    generate.kyverno.io/trigger-version: v1
  name: regcred
  namespace: test
  resourceVersion: "2634372"
  uid: cb1d7593-deb5-43ff-b88b-24790abc881f
type: kubernetes.io/dockerconfigjson
```

可以看到在新建的命名空间中多了一个 `<font style="color:#DF2A3F;">regcred</font>`<font style="color:#DF2A3F;"> </font>的 Secret 对象。

更多的 Kyverno 策略可以直接查看官方网站：[https://kyverno.io/policies](https://kyverno.io/policies)，可以在该网站上面根据策略类型、分类、主题等进行筛选。Kyverno 在灵活、强大和易用之间取得了一个很好的平衡，不需要太多学习时间，就能够提供相当方便的功能，官网提供了大量的针对各种场景的样例，非常值得使用。

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760599788397-caa305b8-6e17-438a-98fe-ebede1cf471c.png)

