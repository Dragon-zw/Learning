前文我们学习 `<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:#DF2A3F;"> </font>的时候，我们说 `<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:#DF2A3F;"> </font>这个资源对象是 Kubernetes 当中非常重要的一个资源对象，一般情况下 ConfigMap 是用来存储一些非安全的配置信息，如果涉及到一些安全相关的数据的话用 ConfigMap 就非常不妥了，因为 ConfigMap 是明文存储的，这个时候我们就需要用到另外一个资源对象了：`<font style="color:#DF2A3F;">Secret</font>`，`<font style="color:#DF2A3F;">Secret</font>`用来保存敏感信息，例如密码、OAuth 令牌和 ssh key 等等，将这些信息放在 `<font style="color:#DF2A3F;">Secret</font>`<font style="color:#DF2A3F;"> </font>中比放在 Pod 的定义中或者 Docker 镜像中要更加安全和灵活。

`<font style="color:#DF2A3F;">Secret</font>`<font style="color:#DF2A3F;"> </font>主要使用的有以下三种类型：

+ `<font style="color:#DF2A3F;">Opaque</font>`：base64 编码格式的 Secret，用来存储密码、密钥等；但数据也可以通过 `<font style="color:#DF2A3F;">base64 –decode</font>` 解码得到原始数据，所有加密性很弱。
+ `<font style="color:#DF2A3F;">kubernetes.io/dockercfg</font>`: `<font style="color:#DF2A3F;">~/.dockercfg</font>` 文件的序列化形式
+ `<font style="color:#DF2A3F;">kubernetes.io/dockerconfigjson</font>`：用来存储私有`<font style="color:#DF2A3F;">docker registry</font>`的认证信息，`<font style="color:#DF2A3F;">~/.docker/config.json</font>` 文件的序列化形式。与 `<font style="color:#DF2A3F;">kubernetes.io/dockercfg</font>`<font style="color:#DF2A3F;"> </font>功能相同用于拉取镜像
+ `<font style="color:#DF2A3F;">kubernetes.io/service-account-token</font>`：用于 `<font style="color:#DF2A3F;">ServiceAccount</font>`, ServiceAccount 创建时 Kubernetes 会默认创建一个对应的 Secret 对象，Pod 如果使用了 ServiceAccount，对应的 Secret 会自动挂载到 Pod 目录 `<font style="color:#DF2A3F;">/run/secrets/kubernetes.io/serviceaccount</font>` 中
+ `<font style="color:#DF2A3F;">kubernetes.io/ssh-auth</font>`：用于 SSH 身份认证的凭据
+ `<font style="color:#DF2A3F;">kubernetes.io/basic-auth</font>`：用于基本身份认证的凭据
+ `<font style="color:#DF2A3F;">bootstrap.kubernetes.io/token</font>`：用于节点接入集群的校验的 Secret

上面是 Secret 对象内置支持的几种类型，通过为 Secret 对象的 type 字段设置一个非空的字符串值，也可以定义并使用自己 Secret 类型。如果 type 值为空字符串，则被视为 Opaque 类型。Kubernetes 并不对类型的名称作任何限制，不过，如果要使用内置类型之一， 则你必须满足为该类型所定义的所有要求。

## 1 Opaque Secret（重要）
`<font style="color:#DF2A3F;">Secret</font>`<font style="color:#DF2A3F;"> </font>资源包含2个键值对： `<font style="color:#DF2A3F;">data</font>`<font style="color:#DF2A3F;"> </font>和 `<font style="color:#DF2A3F;">stringData</font>`，`<font style="color:#DF2A3F;">data</font>`<font style="color:#DF2A3F;"> </font>字段用来存储 base64 编码的任意数据，提供 `<font style="color:#DF2A3F;">stringData</font>`<font style="color:#DF2A3F;"> </font>字段是为了方便，它允许 Secret 使用未编码的字符串。 `<font style="color:#DF2A3F;">data</font>`<font style="color:#DF2A3F;"> </font>和 `<font style="color:#DF2A3F;">stringData</font>`<font style="color:#DF2A3F;"> </font>的键必须由字母、数字、`<font style="color:#DF2A3F;">-</font>`，`<font style="color:#DF2A3F;">_</font>` 或 `<font style="color:#DF2A3F;">.</font>` 组成。

比如我们来创建一个用户名为 `<font style="color:#DF2A3F;">admin</font>`，密码为 `<font style="color:#DF2A3F;">admin321</font>` 的 `<font style="color:#DF2A3F;">Secret</font>`<font style="color:#DF2A3F;"> </font>对象，首先我们需要先把用户名和密码做 `<font style="color:#DF2A3F;">base64</font>`<font style="color:#DF2A3F;"> </font>编码：

```shell
➜  ~ echo -n "admin" | base64
YWRtaW4=
➜  ~ echo -n "admin321" | base64
YWRtaW4zMjE=
```

然后我们就可以利用上面编码过后的数据来编写一个 YAML 文件：(`<font style="color:#DF2A3F;">secret-demo.yaml</font>`)

```yaml
# secret-demo.yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
data:
  username: YWRtaW4=
  password: YWRtaW4zMjE=
```

然后我们就可以使用 kubectl 命令来创建了：

```shell
➜  ~ kubectl apply -f secret-demo.yaml
secret "mysecret" created
```

利用`<font style="color:#DF2A3F;">kubectl get secret</font>`命令查看：

```shell
➜  ~ kubectl get secret
NAME                  TYPE                                  DATA      AGE
default-token-n9w2d   kubernetes.io/service-account-token   3         33d
mysecret              Opaque                                2         40s
```

其中 `<font style="color:#DF2A3F;">default-token-n9w2d</font>` 为创建集群时默认创建的 Secret，被 `<font style="color:#DF2A3F;">serviceacount/default</font>` 引用。我们可以使用 `<font style="color:#DF2A3F;">describe</font>`<font style="color:#DF2A3F;"> </font>命令查看详情：

```shell
➜  ~ kubectl describe secret mysecret
Name:         mysecret
Namespace:    default
Labels:       <none>
Annotations:  <none>

Type:  Opaque

Data
====
password:  8 bytes
username:  5 bytes
```

我们可以看到利用 `<font style="color:#DF2A3F;">describe</font>` 命令查看到的 Data 没有直接显示出来，如果想看到 Data 里面的详细信息，同样我们可以输出成YAML 文件进行查看：

```shell
➜  ~ kubectl get secret mysecret -o yaml
apiVersion: v1
data:
  password: YWRtaW4zMjE=
  username: YWRtaW4=
kind: Secret
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","data":{"password":"YWRtaW4zMjE=","username":"YWRtaW4="},"kind":"Secret","metadata":{"annotations":{},"name":"mysecret","namespace":"default"},"type":"Opaque"}
  creationTimestamp: "2025-10-15T05:54:17Z"
  name: mysecret
  namespace: default
  resourceVersion: "396440"
  uid: 187fc4c4-cc57-4334-b0fb-b60255d9336b
type: Opaque
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760508260593-58353424-a51f-4908-8a3a-2356e83a1ed1.png)

对于某些场景，你可能希望使用 `<font style="color:#DF2A3F;">stringData</font>`<font style="color:#DF2A3F;"> </font>字段，这字段可以将一个非 base64 编码的字符串直接放入 Secret 中， 当创建或更新该 Secret 时，此字段将被编码。

比如当我们部署应用时，使用 Secret 存储配置文件， 你希望在部署过程中，填入部分内容到该配置文件。例如，如果你的应用程序使用以下配置文件:

```yaml
apiUrl: "https://my.api.com/api/v1"
username: "<user>"
password: "<password>"
```

那么我们就可以使用以下定义将其存储在 Secret 中:

```yaml
# Secret-mysecret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
stringData:
  config.yaml: |
    apiUrl: "https://my.api.com/api/v1"
    username: <user>
    password: <password>
```

比如我们直接创建上面的对象后重新获取对象的话 `<font style="color:#DF2A3F;">config.yaml</font>` 的值会被编码：

```shell
➜  ~ kubectl get secret mysecret -o yaml
apiVersion: v1
data:
  config.yaml: YXBpVXJsOiAiaHR0cHM6Ly9teS5hcGkuY29tL2FwaS92MSIKdXNlcm5hbWU6IDx1c2VyPgpwYXNzd29yZDogPHBhc3N3b3JkPgo=
kind: Secret
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"Secret","metadata":{"annotations":{},"name":"mysecret","namespace":"default"},"stringData":{"config.yaml":"apiUrl: \"https://my.api.com/api/v1\"\nusername: \u003cuser\u003e\npassword: \u003cpassword\u003e\n"},"type":"Opaque"}
  creationTimestamp: "2025-10-15T05:54:17Z"
  name: mysecret
  namespace: default
  resourceVersion: "398453"
  uid: 187fc4c4-cc57-4334-b0fb-b60255d9336b
type: Opaque
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760508456460-211bb554-8d10-4491-a56e-b2a913aa7beb.png)

创建好 `<font style="color:#DF2A3F;">Secret</font>`对象后，有两种方式来使用它：

+ 以环境变量的形式
+ 以Volume的形式挂载

### 1.1 环境变量
首先我们来测试下环境变量的方式，同样的，我们来使用一个简单的 busybox 镜像来测试下：(`secret1-pod.yaml`)

```yaml
# secret1-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret1-pod
spec:
  containers:
  - name: secret1
    image: busybox
    command: [ "/bin/sh", "-c", "env" ]
    env:
    - name: USERNAME
      valueFrom:
        secretKeyRef:
          name: mysecret
          key: username
    - name: PASSWORD
      valueFrom:
        secretKeyRef:
          name: mysecret
          key: password
```

主要需要注意的是上面环境变量中定义的 `<font style="color:#DF2A3F;">secretKeyRef</font>`<font style="color:#DF2A3F;"> </font>字段，和我们前文的 `<font style="color:#DF2A3F;">configMapKeyRef</font>`<font style="color:#DF2A3F;"> </font>类似，一个是从 `<font style="color:#DF2A3F;">Secret</font>`<font style="color:#DF2A3F;"> </font>对象中获取，一个是从 `<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:#DF2A3F;"> </font>对象中获取，创建上面的 Pod：

```shell
# 引用资源清单文件
➜  ~ kubectl create -f secret1-pod.yaml
pod "secret1-pod" created
```

然后我们查看 Pod 的日志输出：

```shell
➜  ~ kubectl logs secret1-pod
[......]
USERNAME=admin
PASSWORD=admin321
[......]
```

可以看到有 `<font style="color:#DF2A3F;">USERNAME</font>`<font style="color:#DF2A3F;"> </font>和 `<font style="color:#DF2A3F;">PASSWORD</font>` 两个环境变量输出出来。

### 1.2 Volume 挂载
同样的我们用一个 Pod 来验证下 `<font style="color:#DF2A3F;">Volume</font>`<font style="color:#DF2A3F;"> </font>挂载，创建一个 Pod 文件：(`<font style="color:#DF2A3F;">secret2-pod.yaml</font>`)

```yaml
# secret2-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret2-pod
spec:
  containers:
  - name: secret2
    image: busybox
    command: ["/bin/sh", "-c", "ls /etc/secrets"]
    volumeMounts:
    - name: secrets
      mountPath: /etc/secrets
  volumes:
  - name: secrets
    secret:
      secretName: mysecret
```

创建 Pod，然后查看输出日志：

```shell
# 引用资源清单文件
➜  ~ kubectl create -f secret2-pod.yaml
pod/secret2-pod created

➜  ~ kubectl logs secret2-pod
password
username
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760508855214-d45a5220-9404-4195-8310-d8a6e8b4b0b2.png)

可以看到 Secret 把两个 key 挂载成了两个对应的文件。当然如果想要挂载到指定的文件上面，是不是也可以使用上一节课的方法：在 `<font style="color:#DF2A3F;">secretName</font>`<font style="color:#DF2A3F;"> </font>下面添加 `<font style="color:#DF2A3F;">items</font>`<font style="color:#DF2A3F;"> </font>指定 `<font style="color:#DF2A3F;">key</font>`<font style="color:#DF2A3F;"> </font>和 `<font style="color:#DF2A3F;">path</font>`，这个大家可以参考上节课 `<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:#DF2A3F;"> </font>中的方法去测试下。

## 2 kubernetes.io/dockerconfigjson（重要）
除了上面的 `<font style="color:#DF2A3F;">Opaque</font>`<font style="color:#DF2A3F;"> </font>这种类型外，我们还可以来创建用户 `<font style="color:#DF2A3F;">docker registry</font>` 认证的 `<font style="color:#DF2A3F;">Secret</font>`，直接使用 `<font style="color:#DF2A3F;">kubectl create</font>` 命令创建即可，如下：

```shell
➜  ~ kubectl create secret docker-registry myregistry \
  --docker-server=DOCKER_SERVER \
  --docker-username=DOCKER_USER \
  --docker-password=DOCKER_PASSWORD \
  --docker-email=DOCKER_EMAIL
secret "myregistry" created

# 示例：
➜  ~ kubectl create secret docker-registry myregistry \
  --docker-username=<USERNAME> \
  --docker-password=<PASSWORD> \
  --docker-email=<EMAIL>
```

除了上面这种方法之外，我们也可以通过指定文件的方式来创建镜像仓库认证信息，需要注意对应的 `<font style="color:#DF2A3F;">KEY</font>`<font style="color:#DF2A3F;"> </font>和 `<font style="color:#DF2A3F;">TYPE</font>`：

```shell
➜  ~ kubectl create secret generic myregistry \
  --from-file=.dockerconfigjson=/root/.docker/config.json \
  --type=kubernetes.io/dockerconfigjson
```

然后查看 Secret 列表：

```shell
➜  ~ kubectl get secret myregistry
NAME         TYPE                             DATA   AGE
myregistry   kubernetes.io/dockerconfigjson   1      110s
```

注意看上面的 TYPE 类型，myregistry 对应的是 `<font style="color:#DF2A3F;">kubernetes.io/dockerconfigjson</font>`，同样的可以使用 `<font style="color:#DF2A3F;">describe</font>` 命令来查看详细信息：

```shell
➜  ~ kubectl describe secret myregistry
Name:         myregistry
Namespace:    default
Labels:       <none>
Annotations:  <none>

Type:  kubernetes.io/dockerconfigjson

Data
====
.dockerconfigjson:  162 bytes
```

同样的可以看到 Data 区域没有直接展示出来，如果想查看的话可以使用 `<font style="color:#DF2A3F;">-o yaml</font>` 来输出展示出来：

```shell
➜  ~ kubectl get secret myregistry -o yaml
apiVersion: v1
data:
  .dockerconfigjson: <BASE64-Code>
kind: Secret
metadata:
  creationTimestamp: "2025-10-15T06:32:00Z"
  name: myregistry
  namespace: default
  resourceVersion: "402558"
  uid: 3b02f0ad-d16e-4c4e-a979-bf6f40144bd5
type: kubernetes.io/dockerconfigjson
```

可以把上面的 `<font style="color:#DF2A3F;">data.dockerconfigjson</font>` 下面的数据做一个 `<font style="color:#DF2A3F;">base64</font>`<font style="color:#DF2A3F;"> </font>解码，看看里面的数据是怎样的呢？

如果我们需要拉取私有仓库中的 Docker 镜像的话就需要使用到上面的 myregistry 这个 `<font style="color:#DF2A3F;">Secret</font>`：

```yaml
# foo-myregistry.yaml
apiVersion: v1
kind: Pod
metadata:
  name: foo
spec:
  containers:
  - name: foo
    image: <DOCKERHUB_PERSONAL>/ubuntu:22.04
  imagePullSecrets:
  - name: myregistry
```

:::warning
imagePullSecrets

:::

`<u><font style="color:#DF2A3F;">ImagePullSecrets</font></u>`<u><font style="color:#DF2A3F;"> </font></u><u>与 </u>`<u><font style="color:#DF2A3F;">Secrets</font></u><u>不同，因为 </u>`<u><font style="color:#DF2A3F;">Secrets</font></u><u>可以挂载到 Pod 中，但是 </u>`<u><font style="color:#DF2A3F;">ImagePullSecrets</font></u><u>只能由 Kubelet 访问。</u>

我们需要拉取私有仓库镜像 `<font style="color:#DF2A3F;"><DOCKERHUB_PERSONAL>/ubuntu:22.04</font>`，我们就需要针对该私有仓库来创建一个如上的 `<font style="color:#DF2A3F;">Secret</font>`，然后在 Pod 中指定 `<font style="color:#DF2A3F;">imagePullSecrets</font>`。

除了设置 `<font style="color:#DF2A3F;">Pod.spec.imagePullSecrets</font>` 这种方式来获取私有镜像之外，我们还可以通过在 `<font style="color:#DF2A3F;">ServiceAccount</font>`<font style="color:#DF2A3F;"> </font>中设置 `<font style="color:#DF2A3F;">imagePullSecrets</font>`，然后就会自动为使用该 SA 的 Pod 注入 `<font style="color:#DF2A3F;">imagePullSecrets</font>`<font style="color:#DF2A3F;"> </font>信息：

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  creationTimestamp: "2019-11-08T12:00:04Z"
  name: default
  namespace: default
  resourceVersion: "332"
  selfLink: /api/v1/namespaces/default/serviceaccounts/default
  uid: cc37a719-c4fe-4ebf-92da-e92c3e24d5d0
secrets:
- name: default-token-5tsh4
imagePullSecrets:
- name: myregistry
```

## 3 kubernetes.io/basic-auth
该类型用来存放用于基本身份认证所需的凭据信息，使用这种 Secret 类型时，Secret 的 data 字段（不一定）必须包含以下两个键（相当于是约定俗成的一个规定）：

+ `<font style="color:#DF2A3F;">username</font>`: 用于身份认证的用户名
+ `<font style="color:#DF2A3F;">password</font>`: 用于身份认证的密码或令牌

以上两个键的键值都是 `<font style="color:#DF2A3F;">base64</font>`<font style="color:#DF2A3F;"> </font>编码的字符串。 然你也可以在创建 Secret 时使用 `<font style="color:#DF2A3F;">stringData</font>`<font style="color:#DF2A3F;"> </font>字段来提供明文形式的内容。下面的 YAML 是基本身份认证 Secret 的一个示例清单：

```yaml
# secret-basic-auth.yaml
apiVersion: v1
kind: Secret
metadata:
  name: secret-basic-auth
type: kubernetes.io/basic-auth
stringData:
  username: admin
  password: admin321
```

```shell
$ kubectl apply -f secret-basic-auth.yaml 
secret/secret-basic-auth created

$ kubectl get secrets secret-basic-auth 
NAME                TYPE                       DATA   AGE
secret-basic-auth   kubernetes.io/basic-auth   2      10s

$ kubectl get secrets secret-basic-auth -o yaml 
apiVersion: v1
data:
  password: YWRtaW4zMjE=
  username: YWRtaW4=
kind: Secret
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"Secret","metadata":{"annotations":{},"name":"secret-basic-auth","namespace":"default"},"stringData":{"password":"admin321","username":"admin"},"type":"kubernetes.io/basic-auth"}
  creationTimestamp: "2025-10-24T02:35:55Z"
  name: secret-basic-auth
  namespace: default
  resourceVersion: "1283626"
  uid: cd2040e5-1a13-4d23-af1f-6b56712a4d70
type: kubernetes.io/basic-auth
```

提供基本身份认证类型的 Secret 仅仅是出于用户方便性考虑，我们也可以使用 `<u><font style="color:#DF2A3F;">Opaque</font></u>`<u><font style="color:#DF2A3F;"> 类型</font></u>来保存用于基本身份认证的凭据，不过<font style="color:#DF2A3F;">使用内置的 Secret 类型的有助于对凭据格式进行统一处理</font>。

## 4 kubernetes.io/ssh-auth
该类型用来存放 SSH 身份认证中所需要的凭据，使用这种 Secret 类型时，你就不一定必须在其 data（或 stringData）字段中提供一个 `<font style="color:#DF2A3F;">ssh-privatekey</font>` 键值对，作为要使用的 SSH 凭据。

如下所示是一个 SSH 身份认证 Secret 的配置示例：

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: secret-ssh-auth
type: kubernetes.io/ssh-auth
data:
  ssh-privatekey: |
    MIIEpQIBAAKCAQEAulqb/Y ......
```

同样提供 SSH 身份认证类型的 Secret 也仅仅是出于用户方便性考虑，我们也可以使用 Opaque 类型来保存用于 SSH 身份认证的凭据，只是<font style="color:#DF2A3F;">使用内置的 Secret 类型的有助于对凭据格式进行统一处理</font>。

## 5 kubernetes.io/tls（重要）
```shell
$ kubectl create secret tls --help
Create a TLS secret from the given public/private key pair.

 The public/private key pair must exist before hand. The public key certificate must be .PEM encoded and match the given
private key.

Examples:
  # Create a new TLS secret named tls-secret with the given key pair:
  kubectl create secret tls tls-secret --cert=path/to/tls.cert --key=path/to/tls.key

Options:
      --allow-missing-template-keys=true: If true, ignore any errors in templates when a field or map key is missing in
the template. Only applies to golang and jsonpath output formats.
      --append-hash=false: Append a hash of the secret to its name.
      --cert='': Path to PEM encoded public key certificate.
      --dry-run='none': Must be "none", "server", or "client". If client strategy, only print the object that would be
sent, without sending it. If server strategy, submit server-side request without persisting the resource.
      --field-manager='kubectl-create': Name of the manager used to track field ownership.
      --key='': Path to private key associated with given certificate.
  -o, --output='': Output format. One of:
json|yaml|name|go-template|go-template-file|template|templatefile|jsonpath|jsonpath-as-json|jsonpath-file.
      --save-config=false: If true, the configuration of current object will be saved in its annotation. Otherwise, the
annotation will be unchanged. This flag is useful when you want to perform kubectl apply on this object in the future.
      --show-managed-fields=false: If true, keep the managedFields when printing objects in JSON or YAML format.
      --template='': Template string or path to template file to use when -o=go-template, -o=go-template-file. The
template format is golang templates [http://golang.org/pkg/text/template/#pkg-overview].
      --validate=true: If true, use a schema to validate the input before sending it

Usage:
  kubectl create secret tls NAME --cert=path/to/cert/file --key=path/to/key/file [--dry-run=server|client|none]
[options]

Use "kubectl options" for a list of global command-line options (applies to all commands).
```

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1728933469672-f32f6332-a14a-4856-94e1-f91c75d21834.png?x-oss-process=image%2Fformat%2Cwebp)

该类型用来存放证书及其相关密钥（通常用在 TLS 场合）。此类数据主要提供给 Ingress 资源，用以校验 TLS 链接，当使用此类型的 Secret 时，Secret 配置中的 data （或 stringData）字段必须包含 `<font style="color:#DF2A3F;">tls.key</font>` 和 `<font style="color:#DF2A3F;">tls.crt</font>`主键。下面的 YAML 包含一个 TLS Secret 的配置示例：

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: secret-tls
type: kubernetes.io/tls
data:
  tls.crt: |
    MIIC2DCCAcCgAwIBAgIBATANBgkqh ......
  tls.key: |
    MIIEpgIBAAKCAQEA7yn3bRHQ5FHMQ ......
```

提供 TLS 类型的 Secret 仅仅是出于用户方便性考虑，我们也可以使用 Opaque 类型来保存用于 TLS 服务器与/或客户端的凭据。不过，使用内置的 Secret 类型的有助于对凭据格式进行统一化处理。当使用 kubectl 来创建 TLS Secret 时，我们可以像下面的例子一样使用 tls 子命令：

```shell
➜  ~ kubectl create secret tls my-tls-secret \
  --cert=path/to/cert/file \
  --key=path/to/key/file
```

需要注意的是用于 `<font style="color:#DF2A3F;">--cert</font>` 的公钥证书必须是 `<font style="color:#DF2A3F;">.PEM</font>` 编码的 （Base64 编码的 DER 格式），且与 `<font style="color:#DF2A3F;">--key</font>` 所给定的私钥匹配，私钥必须是通常所说的 PEM 私钥格式，且未加密。对这两个文件而言，PEM 格式数据的第一行和最后一行（例如，证书所对应的 `<font style="color:#DF2A3F;">--------BEGIN CERTIFICATE--------</font>` 和 `<font style="color:#DF2A3F;">--------END CERTIFICATE--------</font>`）都不会包含在其中。

## 6 kubernetes.io/service-account-token（重要）
另外一种 `<font style="color:#DF2A3F;">Secret</font>`<font style="color:#DF2A3F;"> </font>类型就是 `<font style="color:#DF2A3F;">kubernetes.io/service-account-token</font>`，用于被 `<font style="color:#DF2A3F;">ServiceAccount</font>`<font style="color:#DF2A3F;"> </font>引用。`<font style="color:#DF2A3F;">ServiceAccout</font>`<font style="color:#DF2A3F;"> </font>创建时 Kubernetes 会默认创建对应的 `<font style="color:#DF2A3F;">Secret</font>`，如下所示我们随意创建一个 Pod：

```shell
➜  ~ kubectl run secret3-pod --image nginx:1.7.9
deployment.apps "secret3-pod" created

➜  ~ kubectl get pods secret3-pod
NAME          READY   STATUS    RESTARTS   AGE
secret-pod3   1/1     Running   0          15s
```

我们可以直接查看这个 Pod 的详细信息：

```yaml
➜  ~ kubectl get pods secret3-pod -o yaml 
[......]
spec:
  containers:
  - image: nginx:1.7.9
    imagePullPolicy: IfNotPresent
    name: secret3-pod
    resources: {}
    volumeMounts:
    - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      name: kube-api-access-pskws
      readOnly: true
  restartPolicy: Always
  schedulerName: default-scheduler
  securityContext: {}
  serviceAccount: default
  serviceAccountName: default
  volumes:
  - name: kube-api-access-pskws
    projected:
      defaultMode: 420
      sources:
      - serviceAccountToken:
          expirationSeconds: 3607
          path: token
      - configMap:
          items:
          - key: ca.crt
            path: ca.crt
          name: kube-root-ca.crt
      - downwardAPI:
          items:
          - fieldRef:
              apiVersion: v1
              fieldPath: metadata.namespace
            path: namespace
```

当创建 Pod 的时候，如果没有指定 ServiceAccount，Pod 则会使用命名空间中名为 `<font style="color:#DF2A3F;">default</font>` 的 ServiceAccount，上面我们可以看到 `<font style="color:#DF2A3F;">spec.serviceAccountName</font>` 字段已经被自动设置了。

可以看到这里通过一个 `<font style="color:#DF2A3F;">projected</font>`<font style="color:#DF2A3F;"> </font>类型的 Volume 挂载到了容器的 `<font style="color:#DF2A3F;">/var/run/secrets/kubernetes.io/serviceaccount</font>` 的目录中，`<font style="color:#DF2A3F;">projected</font>`<font style="color:#DF2A3F;"> </font>类型的 Volume 可以同时挂载多个来源的数据，这里我们挂载了一个 downwardAPI 来获取 namespace，通过 ConfigMap 来获取 `<font style="color:#DF2A3F;">ca.crt</font>` 证书，然后还有一个 `<font style="color:#DF2A3F;">serviceAccountToken</font>`<font style="color:#DF2A3F;"> </font>类型的数据源。

在之前的版本（v1.20）中，是直接将 `<font style="color:#DF2A3F;">default</font>`（自动创建的）的 `<font style="color:#DF2A3F;">ServiceAccount</font>`<font style="color:#DF2A3F;"> </font>对应的 Secret 对象通过 Volume 挂载到了容器的 `<font style="color:#DF2A3F;">/var/run/secrets/kubernetes.io/serviceaccount</font>` 的目录中的，现在的版本提供了更多的配置选项，比如上面我们配置了 `<font style="color:#DF2A3F;">expirationSeconds</font>`<font style="color:#DF2A3F;"> </font>和 `<font style="color:#DF2A3F;">path</font>`<font style="color:#DF2A3F;"> </font>两个属性。

前面我们也提到了默认情况下当前 namespace 下面的 Pod 会默认使用 `<font style="color:#DF2A3F;">default</font>`<font style="color:#DF2A3F;"> </font>这个 ServiceAccount，对应的 `<font style="color:#DF2A3F;">Secret</font>`<font style="color:#DF2A3F;"> </font>会自动挂载到 Pod 的 `<font style="color:#DF2A3F;">/var/run/secrets/kubernetes.io/serviceaccount/</font>` 目录中，这样我们就可以在 Pod 里面获取到用于身份认证的信息了。

```shell
$ kubectl exec -it secret3-pod -- /bin/bash
root@secret-pod3:/# ls -l /var/run/secrets/kubernetes.io/serviceaccount/
total 0
lrwxrwxrwx 1 root root 13 Oct 15 07:53 ca.crt -> ..data/ca.crt
lrwxrwxrwx 1 root root 16 Oct 15 07:53 namespace -> ..data/namespace
lrwxrwxrwx 1 root root 12 Oct 15 07:53 token -> ..data/token
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760515068820-e96c20f1-1937-448e-a124-03baf9e1f8fd.png)

我们可以使用自动挂载给 Pod 的 ServiceAccount 凭据访问 API，我们也可以通过在 ServiceAccount 上设置 `<font style="color:#DF2A3F;">automountServiceAccountToken: false</font>` 来实现不给 ServiceAccount 自动挂载 API 凭据：

```yaml
# SA-build-robot.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: build-robot
  namespace: default
automountServiceAccountToken: false
[......]
```

此外也可以选择不给特定 Pod 自动挂载 API 凭据：

```yaml
# secret4-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret4-pod
spec:
  serviceAccountName: build-robot
  automountServiceAccountToken: false
  containers:
  - name: secret4
    image: busybox
    command: ["/bin/sh", "-c", "sleep 365d"]
    volumeMounts:
    - name: secrets
      mountPath: /etc/secrets
  volumes:
  - name: secrets
    secret:
     secretName: mysecret
```

```shell
$ kubectl create -f secret4-pod.yaml 
pod/secret4-pod created

$ kubectl exec -it secret4-pod -- /bin/sh 
/ # ls -l /var/run/secrets/kubernetes.io/serviceaccount/
ls: /var/run/secrets/kubernetes.io/serviceaccount/: No such file or directory
```

如果 Pod 和 ServiceAccount 都指定了 `<font style="color:#DF2A3F;">automountServiceAccountToken</font>`<font style="color:#DF2A3F;"> </font>值，则 `<font style="color:#DF2A3F;">Pod</font>`<font style="color:#DF2A3F;"> </font>的 `<font style="color:#DF2A3F;">spec</font>`<font style="color:#DF2A3F;"> </font>优先于 ServiceAccount。[ 即 Pod 资源清单文件定义了`<font style="color:#DF2A3F;">automountServiceAccountToken</font>`，那么优先级高于 ServiceAccount 定义 ]。不过一般不会使用这个参数。

### 6.1 ServiceAccount Token 投影
`<font style="color:#DF2A3F;">ServiceAccount</font>`<font style="color:#DF2A3F;"> </font>是 Pod 和集群 ApiServer 通讯的访问凭证，传统方式下，在 Pod 中使用 `<font style="color:#DF2A3F;">ServiceAccount</font>`<font style="color:#DF2A3F;"></font> 可能会遇到如下的安全挑战：

+ `<font style="color:#DF2A3F;">ServiceAccount</font>`<font style="color:#DF2A3F;"> </font>中的<font style="color:#DF2A3F;"> </font>`<font style="color:#DF2A3F;">JSON Web Token (JWT)</font>` 没有绑定 Audience 身份，因此所有 `<font style="color:#DF2A3F;">ServiceAccount</font>` 的使用者都可以彼此扮演，存在伪装攻击的可能
+ 传统方式下每一个 `<font style="color:#DF2A3F;">ServiceAccount</font>`<font style="color:#DF2A3F;"> </font>都需要存储在一个对应的 Secret 中，并且会以文件形式存储在对应的应用节点上，而集群的系统组件在运行过程中也会使用到一些权限很高的 `<font style="color:#DF2A3F;">ServiceAccount</font>`<font style="color:#DF2A3F;"></font>，其增大了集群管控平面的攻击面，攻击者可以通过获取这些管控组件使用的 `<font style="color:#DF2A3F;">ServiceAccount</font>`<font style="color:#DF2A3F;"> </font>非法提权
+ `<font style="color:#DF2A3F;">ServiceAccount</font>`<font style="color:#DF2A3F;"> </font>中的 JWT token 没有设置过期时间，当上述 `<font style="color:#DF2A3F;">ServiceAccount</font>`<font style="color:#DF2A3F;"> </font>泄露情况发生时，只能通过轮转 `<font style="color:#DF2A3F;">ServiceAccount</font>` 的签发私钥来进行防范
+ 每一个 ServiceAccount 都需要创建一个与之对应的 Secret，在大规模的应用部署下存在弹性和容量风险

为解决这个问题 <u>Kubernetes 提供了 ServiceAccount Token 投影特性用于增强 ServiceAccount 的安全性</u>，ServiceAccount 令牌卷投影可使 Pod 支持以卷投影的形式将 ServiceAccount 挂载到容器中从而避免了对 Secret 的依赖。

<font style="color:#DF2A3F;">通过 ServiceAccount 令牌卷投影可用于工作负载的 ServiceAccount 令牌是受时间限制，受 Audience 约束的，并且不与 Secret 对象关联。</font>如果删除了 Pod 或删除了 ServiceAccount，则这些令牌将无效，从而可以防止任何误用，Kubelet 还会在令牌即将到期时自动旋转令牌，另外，还可以配置希望此令牌可用的路径。

为了启用令牌请求投射（此功能在 Kubernetes 1.12 中引入，Kubernetes v1.20 已经稳定版本），你必须为 `<font style="color:#DF2A3F;">kube-apiserver</font>` 设置以下命令行参数，通过 kubeadm 安装的集群已经默认配置了：

```bash
--service-account-issuer  # serviceaccount token 中的签发身份，即token payload中的iss字段。
--service-account-key-file # token 私钥文件路径
--service-account-signing-key-file  # token 签名私钥文件路径
--api-audiences (可选参数)  # 合法的请求token身份，用于apiserver服务端认证请求token是否合法。
```

配置完成后就可以指定令牌的所需属性，例如身份和有效时间，这些属性在默认 ServiceAccount 令牌上无法配置。当删除 Pod 或 ServiceAccount 时，ServiceAccount 令牌也将对 API 无效。

我们可以使用名为 `<font style="color:#DF2A3F;">ServiceAccountToken</font>`<font style="color:#DF2A3F;"> </font>的 `<font style="color:#DF2A3F;">ProjectedVolume</font>`<font style="color:#DF2A3F;"> </font>类型在 PodSpec 上配置此功能，比如要向 Pod 提供具有 "`<font style="color:#DF2A3F;">vault</font>`" 用户以及两个小时有效期的令牌，可以在 PodSpec 中配置以下内容：

例如当 Pod 中需要使用 audience 为 vault 并且有效期为2个小时的 ServiceAccount 时，我们可以使用以下模板配置 PodSpec 来使用 ServiceAccount 令牌卷投影。

```yaml
# serviceAccountToken-Demo.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: build-robot

---
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
  - image: nginx
    name: nginx
    volumeMounts:
    - mountPath: /var/run/secrets/tokens
      name: vault-token
  serviceAccountName: build-robot
  volumes:
  - name: vault-token
    projected:
      sources:
      - serviceAccountToken:
          path: vault-token
          expirationSeconds: 7200
          audience: vault
```

kubelet 组件会替 Pod 请求令牌并将其保存起来，通过将令牌存储到一个可配置的路径使之在 Pod 内可用，并在令牌快要到期的时候刷新它。 kubelet 会在令牌存在期达到其 TTL 的 80% 的时候或者令牌生命期超过 24 小时的时候主动轮换它。应用程序负责在令牌被轮换时重新加载其内容。对于大多数使用场景而言，周期性地（例如，每隔 5 分钟）重新加载就足够了。

可以使用 `<font style="color:#DF2A3F;">Vault</font>` 来进行数据加密处理！

## 7 其他特性
如果某个容器已经在通过环境变量使用某 Secret，对该 Secret 的更新不会被容器马上看见，除非容器被重启，当然我们可以使用一些第三方的解决方案在 Secret 发生变化时触发容器重启。

在 Kubernetes v1.21 版本提供了不可变的 Secret 和 ConfigMap 的可选配置[stable]，我们可以设置 Secret 和 ConfigMap 为不可变的，对于大量使用 Secret 或者 ConfigMap 的集群（比如有成千上万各不相同的 Secret 供 Pod 挂载）时，禁止变更它们的数据有很多好处：

+ 可以防止意外更新导致应用程序中断
+ 通过将 Secret 标记为不可变来关闭 `<font style="color:#DF2A3F;">kube-apiserver</font>` 对其的 watch 操作，从而显著降低 `<font style="color:#DF2A3F;">kube-apiserver</font>` 的负载，提升集群性能

这个特性通过可以通过 `<font style="color:#DF2A3F;">ImmutableEmphemeralVolumes</font>`<font style="color:#DF2A3F;"> </font>特性门来进行开启，从 v1.19 开始默认启用，我们可以通过将 Secret 的 `<font style="color:#DF2A3F;">immutable</font>`<font style="color:#DF2A3F;"> </font>字段设置为 true 创建不可更改的 Secret。 例如：

```yaml
apiVersion: v1
kind: Secret
metadata:
  ...
data:
  ...
immutable: true  # 标记为不可变
```

一旦一个 Secret 或 ConfigMap 被标记为不可更改，撤销此操作或者更改 data 字段的内容都是不允许的，只能删除并重新创建这个 Secret。现有的 Pod 将维持对已删除 Secret 的挂载点，所以我们也是建议重新创建这些 Pod。

## 8 Secret vs ConfigMap
最后我们来对比下 `<font style="color:#DF2A3F;">Secret</font>`<font style="color:#DF2A3F;"> </font>和 `<font style="color:#DF2A3F;">ConfigMap</font>`这两种资源对象的异同点：

### 8.1 相同点
+ Key/Value的形式
+ 属于某个特定的命名空间
+ 可以导出到环境变量
+ 可以通过目录/文件形式挂载
+ 通过 volume 挂载的配置信息均可热更新

### 8.2 不同点
+ Secret 可以被 ServerAccount 关联
+ Secret 可以存储 `<font style="color:#DF2A3F;">docker register</font>` 的鉴权信息，用在 `<font style="color:#DF2A3F;">ImagePullSecret</font>`<font style="color:#DF2A3F;"> </font>参数中，用于拉取私有仓库的镜像
+ Secret 支持 `<font style="color:#DF2A3F;">Base64</font>`<font style="color:#DF2A3F;"> </font>加密
+ Secret 分为 `<font style="color:#DF2A3F;">kubernetes.io/service-account-token</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">kubernetes.io/dockerconfigjson</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">Opaque</font>` 三种类型，而 `<font style="color:#DF2A3F;">Configmap</font>`<font style="color:#DF2A3F;"> </font>不区分类型

💡使用注意

同样 Secret 文件大小限制为 `<font style="color:#DF2A3F;">1MB</font>`（ETCD 的要求）；Secret 虽然采用 `<font style="color:#DF2A3F;">Base64</font>`<font style="color:#DF2A3F;"> </font>编码，但是我们还是可以很方便解码获取到原始信息，所以对于非常重要的数据还是需要慎重考虑，可以考虑使用 [Vault](https://www.vaultproject.io/) 来进行加密管理。

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760507529968-3208e77f-0f3f-4683-b2ba-192a5fa6ad07.png)

## 9 参考资料
[🕸️[K8S] 15 ConfigMap 与 Secret 的使用](https://www.yuque.com/seekerzw/xi8l23/xiq830v2zc4at3w7)

