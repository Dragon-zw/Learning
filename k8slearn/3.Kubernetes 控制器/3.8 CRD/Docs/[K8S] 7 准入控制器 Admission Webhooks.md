Kubernetes 提供了需要扩展其内置功能的方法，最常用的可能是自定义资源类型和自定义控制器了，除此之外，Kubernetes 还有一些其他非常有趣的功能，比如 `<font style="color:#DF2A3F;">admission webhooks</font>` 就可以用于扩展 API，用于修改某些 Kubernetes 资源的基本行为。

准入控制器是在**对象持久化之前**用于对 Kubernetes API Server 的请求进行拦截的代码段，在请求经过**身份验证**和**授权之后**放行通过。准入控制器可能正在 `<font style="color:#DF2A3F;">validating</font>`、`<font style="color:#DF2A3F;">mutating</font>`<font style="color:#DF2A3F;"> </font>或者都在执行，`<font style="color:#DF2A3F;">Mutating</font>`<font style="color:#DF2A3F;"> </font>控制器可以修改他们处理的资源对象，`<font style="color:#DF2A3F;">Validating</font>`<font style="color:#DF2A3F;"> </font>控制器不会，如果任何一个阶段中的任何控制器拒绝了请求，则会立即拒绝整个请求，并将错误返回给最终的用户。

这意味着有一些特殊的控制器可以拦截 Kubernetes API 请求，并根据自定义的逻辑修改或者拒绝它们。Kubernetes 有自己实现的一个控制器列表：[https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#what-does-each-admission-controller-do](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#what-does-each-admission-controller-do)，当然你也可以编写自己的控制器，虽然这些控制器听起来功能比较强大，但是这些控制器需要被编译进 kube-apiserver，并且只能在 apiserver 启动时启动。

也可以直接使用 kube-apiserver 启动参数查看内置支持的控制器：

```go
kube-apiserver --help | grep enable-admission-plugins
```

由于上面的控制器的限制，我们就需要用到**动态**的概念了，而不是和 apiserver 耦合在一起，`<font style="color:#DF2A3F;">Admission webhooks</font>` 就通过一种动态配置方法解决了这个限制问题。

## 1 Admission Webhooks 是什么?
在 Kubernetes apiserver 中包含两个特殊的准入控制器：`<font style="color:#DF2A3F;">MutatingAdmissionWebhook</font>`<font style="color:#DF2A3F;"> </font>和`<font style="color:#DF2A3F;">ValidatingAdmissionWebhook</font>`，这两个控制器将发送准入请求到外部的 HTTP 回调服务并接收一个准入响应。如果启用了这两个准入控制器，Kubernetes 管理员可以在集群中创建和配置一个 admission webhook。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1730551499429-ad3887be-7f36-4dab-8c35-de1a4624e9d7.png)

整体的步骤如下所示：

    1. 检查集群中是否启用了 `<font style="color:#DF2A3F;">admission webhook</font>` 控制器，并根据需要进行配置。
    2. 编写处理准入请求的 HTTP 回调，回调可以是一个部署在集群中的简单 HTTP 服务，甚至也可以是一个 `<font style="color:#DF2A3F;">serverless</font>`<font style="color:#DF2A3F;"> </font>函数。
    3. 通过 `<font style="color:#DF2A3F;">MutatingWebhookConfiguration</font>`<font style="color:#DF2A3F;"> </font>和 `<font style="color:#DF2A3F;">ValidatingWebhookConfiguration</font>`<font style="color:#DF2A3F;"> </font>资源配置 `<font style="color:#DF2A3F;">admission webhook</font>`。

这两种类型的 admission webhook 之间的区别是非常明显的：`<font style="color:#DF2A3F;">validating webhooks</font>` 可以拒绝请求，但是它们却不能修改准入请求中获取的对象，而 `<font style="color:#DF2A3F;">mutating webhooks</font>` 可以在返回准入响应之前通过创建补丁来修改对象，如果 webhook 拒绝了一个请求，则会向最终用户返回错误。

现在非常火热的 Service Mesh 应用 `<font style="color:#DF2A3F;">istio</font>`<font style="color:#DF2A3F;"> </font>就是通过 mutating webhooks 来自动将 `<font style="color:#DF2A3F;">Envoy</font>`<font style="color:#DF2A3F;"> </font>这个 sidecar 容器注入到 Pod 中去的：[https://istio.io/docs/setup/kubernetes/sidecar-injection/](https://istio.io/docs/setup/kubernetes/sidecar-injection/)。

## 2 创建配置一个 Admission Webhook
上面我们介绍了 Admission Webhook 的理论知识，接下来我们在一个真实的 Kubernetes 集群中来实际测试使用下，我们将创建一个 webhook 的 webserver，将其部署到集群中，然后创建 webhook 配置查看是否生效。

首先确保在 apiserver 中启用了 `<font style="color:#DF2A3F;">MutatingAdmissionWebhook</font>`<font style="color:#DF2A3F;"> </font>和 `<font style="color:#DF2A3F;">ValidatingAdmissionWebhook</font>`<font style="color:#DF2A3F;"> </font>这两个控制器，通过参数 `<font style="color:#DF2A3F;">--enable-admission-plugins</font>` 进行配置，当前 v1.22 版本已经内置默认开启了，如果没有开启则需要添加上这两个参数，然后重启 apiserver。

然后通过运行下面的命令检查集群中是否启用了准入注册 API：

```go
➜  ~ kubectl api-versions | grep admission
admissionregistration.k8s.io/v1
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760424090620-6f700395-b0e2-4942-bbc2-c0056e883230.png)

### 2.1 编写 webhook
满足了前面的先决条件后，接下来我们就来实现一个 webhook 示例，通过监听两个不同的 HTTP 端点（validate 和 mutate）来进行 `<font style="color:#DF2A3F;">validating</font>`<font style="color:#DF2A3F;"> </font>和 `<font style="color:#DF2A3F;">mutating webhook</font>`<font style="color:#DF2A3F;"> </font>验证。

这个 webhook 的完整代码可以在 Github 上获取：[https://github.com/cnych/admission-webhook-example](https://github.com/cnych/admission-webhook-example)，该仓库 Fork 自项目 [https://github.com/banzaicloud/admission-webhook-example](https://github.com/banzaicloud/admission-webhook-example)。这个 webhook 是一个简单的带 TLS 认证的 HTTP 服务，用 Deployment 方式部署在我们的集群中。

代码中主要的逻辑在两个文件中：`<font style="color:#DF2A3F;">main.go</font>` 和 `<font style="color:#DF2A3F;">webhook.go</font>`，main.go 文件包含创建 HTTP 服务的代码，而 webhook.go 包含 validates 和 mutates 两个 webhook 的逻辑，大部分代码都比较简单，首先查看 main.go 文件，查看如何使用标准 golang 包来启动 HTTP 服务，以及如何从命令行标志中读取 TLS 配置的证书：

```go
flag.StringVar(&parameters.certFile, "tlsCertFile", "/etc/webhook/certs/cert.pem", "File containing the x509 Certificate for HTTPS.")
flag.StringVar(&parameters.keyFile, "tlsKeyFile", "/etc/webhook/certs/key.pem", "File containing the x509 private key to --tlsCertFile.")
```

然后一个比较重要的是 serve 函数，用来处理传入的 mutate 和 validating 函数 的 HTTP 请求。该函数从请求中反序列化 `<font style="color:#DF2A3F;">AdmissionReview</font>`<font style="color:#DF2A3F;"> </font>对象，执行一些基本的内容校验，根据 URL 路径调用相应的 mutate 和 validate 函数，然后序列化 AdmissionReview 对象：

```go
func (whsvr *WebhookServer) serve(w http.ResponseWriter, r *http.Request) {
    var body []byte
    if r.Body != nil {
        if data, err := ioutil.ReadAll(r.Body); err == nil {
            body = data
        }
    }
    if len(body) == 0 {
        glog.Error("empty body")
        http.Error(w, "empty body", http.StatusBadRequest)
        return
    }

    // 校验 Content-Type
    contentType := r.Header.Get("Content-Type")
    if contentType != "application/json" {
        glog.Errorf("Content-Type=%s, expect application/json", contentType)
        http.Error(w, "invalid Content-Type, expect `application/json`", http.StatusUnsupportedMediaType)
        return
    }

    var admissionResponse *v1beta1.AdmissionResponse
    ar := v1beta1.AdmissionReview{}
    if _, _, err := deserializer.Decode(body, nil, &ar); err != nil {
        glog.Errorf("Can't decode body: %v", err)
        admissionResponse = &v1beta1.AdmissionResponse{
            Result: &metav1.Status{
                Message: err.Error(),
            },
        }
    } else {
        if r.URL.Path == "/mutate" {
            admissionResponse = whsvr.mutate(&ar)
        } else if r.URL.Path == "/validate" {
            admissionResponse = whsvr.validate(&ar)
        }
    }

    admissionReview := v1beta1.AdmissionReview{}
    if admissionResponse != nil {
        admissionReview.Response = admissionResponse
        if ar.Request != nil {
            admissionReview.Response.UID = ar.Request.UID
        }
    }

    resp, err := json.Marshal(admissionReview)
    if err != nil {
        glog.Errorf("Can't encode response: %v", err)
        http.Error(w, fmt.Sprintf("could not encode response: %v", err), http.StatusInternalServerError)
    }
    glog.Infof("Ready to write reponse ...")
    if _, err := w.Write(resp); err != nil {
        glog.Errorf("Can't write response: %v", err)
        http.Error(w, fmt.Sprintf("could not write response: %v", err), http.StatusInternalServerError)
    }
}
```

主要的准入逻辑是 validate 和 mutate 两个函数。validate 函数检查资源对象是否需要校验：不验证 kube-system 和 kube-public 两个命名空间中的资源，如果想要显示的声明不验证某个资源，可以通过在资源对象中添加一个 `<font style="color:#DF2A3F;">admission-webhook-example.qikqiak.com/validate=false</font>` 的 annotation 进行声明。如果需要验证，则根据资源类型的 kind，和标签与其对应项进行比较，将 service 或者 deployment 资源从请求中反序列化出来。如果缺少某些 label 标签，则响应中的 Allowed 会被设置为 false。如果验证失败，则会在响应中写入失败原因，最终用户在尝试创建资源时会收到失败的信息。validate 函数实现如下所示：

```go
// validate deployments and services
func (whsvr *WebhookServer) validate(ar *v1beta1.AdmissionReview) *v1beta1.AdmissionResponse {
    req := ar.Request
    var (
        availableLabels                 map[string]string
        objectMeta                      *metav1.ObjectMeta
        resourceNamespace, resourceName string
    )

    glog.Infof("AdmissionReview for Kind=%v, Namespace=%v Name=%v (%v) UID=%v patchOperation=%v UserInfo=%v",
               req.Kind, req.Namespace, req.Name, resourceName, req.UID, req.Operation, req.UserInfo)

    switch req.Kind.Kind {
        case "Deployment":
        var deployment appsv1.Deployment
        if err := json.Unmarshal(req.Object.Raw, &deployment); err != nil {
            glog.Errorf("Could not unmarshal raw object: %v", err)
            return &v1beta1.AdmissionResponse{
                Result: &metav1.Status{
                    Message: err.Error(),
                },
            }
        }
        resourceName, resourceNamespace, objectMeta = deployment.Name, deployment.Namespace, &deployment.ObjectMeta
        availableLabels = deployment.Labels
        case "Service":
        var service corev1.Service
        if err := json.Unmarshal(req.Object.Raw, &service); err != nil {
            glog.Errorf("Could not unmarshal raw object: %v", err)
            return &v1beta1.AdmissionResponse{
                Result: &metav1.Status{
                    Message: err.Error(),
                },
            }
        }
        resourceName, resourceNamespace, objectMeta = service.Name, service.Namespace, &service.ObjectMeta
        availableLabels = service.Labels
    }

    if !validationRequired(ignoredNamespaces, objectMeta) {
        glog.Infof("Skipping validation for %s/%s due to policy check", resourceNamespace, resourceName)
        return &v1beta1.AdmissionResponse{
            Allowed: true,
        }
    }

    allowed := true
    var result *metav1.Status
    glog.Info("available labels:", availableLabels)
    glog.Info("required labels", requiredLabels)
    for _, rl := range requiredLabels {
        if _, ok := availableLabels[rl]; !ok {
            allowed = false
            result = &metav1.Status{
                Reason: "required labels are not set",
            }
            break
        }
    }

    return &v1beta1.AdmissionResponse{
        Allowed: allowed,
        Result:  result,
    }
}
```

判断是否需要进行校验的方法如下，可以通过 namespace 进行忽略，也可以通过 annotations 设置进行配置：

```go
func validationRequired(ignoredList []string, metadata *metav1.ObjectMeta) bool {
    required := admissionRequired(ignoredList, admissionWebhookAnnotationValidateKey, metadata)
    glog.Infof("Validation policy for %v/%v: required:%v", metadata.Namespace, metadata.Name, required)
    return required
}

func admissionRequired(ignoredList []string, admissionAnnotationKey string, metadata *metav1.ObjectMeta) bool {
    // skip special kubernetes system namespaces
    for _, namespace := range ignoredList {
        if metadata.Namespace == namespace {
            glog.Infof("Skip validation for %v for it's in special namespace:%v", metadata.Name, metadata.Namespace)
            return false
        }
    }

    annotations := metadata.GetAnnotations()
    if annotations == nil {
        annotations = map[string]string{}
    }

    var required bool
    switch strings.ToLower(annotations[admissionAnnotationKey]) {
        default:
        required = true
        case "n", "no", "false", "off":
        required = false
    }
    return required
}
```

mutate 函数的代码是非常类似的，但不是仅仅比较标签并在响应中设置 Allowed，而是创建一个补丁，将缺失的标签添加到资源中，并将 `<font style="color:#DF2A3F;">not_available</font>` 设置为标签的值。

```go
// main mutation process
func (whsvr *WebhookServer) mutate(ar *v1beta1.AdmissionReview) *v1beta1.AdmissionResponse {
    req := ar.Request
    var (
        availableLabels, availableAnnotations map[string]string
        objectMeta                            *metav1.ObjectMeta
        resourceNamespace, resourceName       string
    )

    glog.Infof("AdmissionReview for Kind=%v, Namespace=%v Name=%v (%v) UID=%v patchOperation=%v UserInfo=%v",
               req.Kind, req.Namespace, req.Name, resourceName, req.UID, req.Operation, req.UserInfo)

    switch req.Kind.Kind {
        case "Deployment":
        var deployment appsv1.Deployment
        if err := json.Unmarshal(req.Object.Raw, &deployment); err != nil {
            glog.Errorf("Could not unmarshal raw object: %v", err)
            return &v1beta1.AdmissionResponse{
                Result: &metav1.Status{
                    Message: err.Error(),
                },
            }
        }
        resourceName, resourceNamespace, objectMeta = deployment.Name, deployment.Namespace, &deployment.ObjectMeta
        availableLabels = deployment.Labels
        case "Service":
        var service corev1.Service
        if err := json.Unmarshal(req.Object.Raw, &service); err != nil {
            glog.Errorf("Could not unmarshal raw object: %v", err)
            return &v1beta1.AdmissionResponse{
                Result: &metav1.Status{
                    Message: err.Error(),
                },
            }
        }
        resourceName, resourceNamespace, objectMeta = service.Name, service.Namespace, &service.ObjectMeta
        availableLabels = service.Labels
    }

    if !mutationRequired(ignoredNamespaces, objectMeta) {
        glog.Infof("Skipping validation for %s/%s due to policy check", resourceNamespace, resourceName)
        return &v1beta1.AdmissionResponse{
            Allowed: true,
        }
    }

    annotations := map[string]string{admissionWebhookAnnotationStatusKey: "mutated"}
    patchBytes, err := createPatch(availableAnnotations, annotations, availableLabels, addLabels)
    if err != nil {
        return &v1beta1.AdmissionResponse{
            Result: &metav1.Status{
                Message: err.Error(),
            },
        }
    }

    glog.Infof("AdmissionResponse: patch=%v\n", string(patchBytes))
    return &v1beta1.AdmissionResponse{
        Allowed: true,
        Patch:   patchBytes,
        PatchType: func() *v1beta1.PatchType {
            pt := v1beta1.PatchTypeJSONPatch
            return &pt
        }(),
    }
}
```

### 2.2 构建镜像
其实我们已经将代码打包成一个 Docker 镜像了，你可以直接使用，镜像仓库地址为：`<font style="color:#DF2A3F;">cnych/admission-webhook-example:v1</font>`。当然如果你希望更改部分代码，那就需要重新构建项目了，由于这个项目采用 go 语言开发，包管理工具更改为了 `<font style="color:#DF2A3F;">go mod</font>`，所以我们需要确保构建环境提前安装好 Go 环境，当然 Docker 也是必不可少的，因为我们需要的是打包成一个 Docker 镜像。

获取项目：

```bash
$ mkdir admission-webhook && cd admission-webhook
$ git clone https://github.com/cnych/admission-webhook-example.git
```

我们可以看到代码根目录下面有一个 build 的脚本，只需要提供我们自己的 Docker 镜像用户名然后直接构建即可：

```bash
$ cd admission-webhook-example/
$ export DOCKER_USER=dragonzw

# 需要提前进行 Docker Login 到镜像仓库中(DockerHub)
$ ./build
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760424344079-df1c3ee0-98ab-4100-b502-c26ac8a6a8f8.png)

并不需要推送到 DockerHub 中。查看镜像信息

```shell
$ docker images 
REPOSITORY                                TAG                    IMAGE ID            CREATED             SIZE
dragonzw/admission-webhook-example        v1                     7447b462e2c7        2 minutes ago       26.3MB
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760424465425-ffd2fa0a-8147-4faa-8db3-1fee2e38cbc5.png)

### 2.3 部署
为了部署 Webhook Server，我们需要在我们的 Kubernetes 集群中创建一个 service 和 deployment 资源对象，部署是非常简单的，只是需要配置服务的 TLS 配置。我们可以在代码根目录下面的 deployment 文件夹下面查看 `<font style="color:#DF2A3F;">deployment.yaml</font>` 文件中关于证书的配置声明，会发现从命令行参数中读取的证书和私钥文件是通过一个 secret 对象挂载进来的：

```yaml
args:
    - -tlsCertFile=/etc/webhook/certs/cert.pem
    - -tlsKeyFile=/etc/webhook/certs/key.pem
[...]
    volumeMounts:
    - name: webhook-certs
        mountPath: /etc/webhook/certs
        readOnly: true
volumes:
- name: webhook-certs
  secret:
    secretName: admission-webhook-example-certs
```

在生产环境中，对于 TLS 证书（特别是私钥）的处理是非常重要的，我们可以使用类似于 `<font style="color:#DF2A3F;">cert-manager</font>` 之类的工具来自动处理 TLS 证书，或者将私钥密钥存储在 Vault 中，而不是直接存在 secret 资源对象中。

我们可以使用任何类型的证书，但是需要注意的是我们这里设置的 CA 证书是需要让 apiserver 能够验证的，我们这里可以重用 Istio 项目中的生成的证书签名请求脚本。通过发送请求到 apiserver，获取认证信息，然后使用获得的结果来创建需要的 secret 对象。

首先，[运行该脚本](https://github.com/cnych/admission-webhook-example/blob/master/deployment/webhook-create-signed-cert.sh)检查 secret 对象中是否有证书和私钥信息：

```bash
➜  ~ ./deployment/webhook-create-signed-cert.sh
creating certs in tmpdir /var/folders/x3/wjy_1z155pdf8jg_jgpmf6kc0000gn/T/tmp.IboFfX97
Generating RSA private key, 2048 bit long modulus (2 primes)
..................+++++
........+++++
e is 65537 (0x010001)
certificatesigningrequest.certificates.k8s.io/admission-webhook-example-svc.default created
NAME                                    AGE   REQUESTOR          CONDITION
admission-webhook-example-svc.default   1s    kubernetes-admin   Pending
certificatesigningrequest.certificates.k8s.io/admission-webhook-example-svc.default approved
secret/admission-webhook-example-certs created

##################################################################
# 新版本的 Kubernetes API Version 进行了修改：
# API 版本：certificates.k8s.io/v1beta1 → certificates.k8s.io/v1
# 添加 signerName：kubernetes.io/kubelet-serving - 用于签署服务证书
# 移除 groups 字段：v1 版本不再需要
##################################################################
➜  ~ kubectl get secret admission-webhook-example-certs
NAME                              TYPE     DATA   AGE
admission-webhook-example-certs   Opaque   2      28s
```

```shell
#!/bin/bash

set -e

usage() {
    cat <<EOF
Generate self-signed certificate for webhook service.

usage: ${0} [OPTIONS]

The following flags are optional.

       --service          Service name of webhook (default: admission-webhook-example-svc)
       --namespace        Namespace where webhook service and secret reside (default: default)
       --secret           Secret name for CA certificate and server certificate/key pair (default: admission-webhook-example-certs)
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case ${1} in
        --service)
            service="$2"
            shift
            ;;
        --secret)
            secret="$2"
            shift
            ;;
        --namespace)
            namespace="$2"
            shift
            ;;
        *)
            usage
            ;;
    esac
    shift
done

[ -z ${service} ] && service=admission-webhook-example-svc
[ -z ${secret} ] && secret=admission-webhook-example-certs
[ -z ${namespace} ] && namespace=default

if [ ! -x "$(command -v openssl)" ]; then
    echo "openssl not found"
    exit 1
fi

tmpdir=$(mktemp -d)
echo "Creating certs in tmpdir ${tmpdir}"

# Generate CA key and certificate
openssl genrsa -out ${tmpdir}/ca-key.pem 2048
openssl req -x509 -new -nodes -key ${tmpdir}/ca-key.pem -days 365 -out ${tmpdir}/ca-cert.pem -subj "/CN=admission-webhook-ca"

# Create server certificate config
cat <<EOF > ${tmpdir}/server.conf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${service}
DNS.2 = ${service}.${namespace}
DNS.3 = ${service}.${namespace}.svc
DNS.4 = ${service}.${namespace}.svc.cluster.local
EOF

# Generate server key and CSR
openssl genrsa -out ${tmpdir}/server-key.pem 2048
openssl req -new -key ${tmpdir}/server-key.pem -out ${tmpdir}/server.csr -subj "/CN=${service}.${namespace}.svc" -config ${tmpdir}/server.conf

# Sign server certificate with CA
openssl x509 -req -in ${tmpdir}/server.csr -CA ${tmpdir}/ca-cert.pem -CAkey ${tmpdir}/ca-key.pem -CAcreateserial -out ${tmpdir}/server-cert.pem -days 365 -extensions v3_req -extfile ${tmpdir}/server.conf

echo "Certificates created successfully"

# Delete existing secret if it exists
kubectl delete secret ${secret} -n ${namespace} 2>/dev/null || true

# Create the secret with CA cert and server cert/key
kubectl create secret generic ${secret} \
    --from-file=key.pem=${tmpdir}/server-key.pem \
    --from-file=cert.pem=${tmpdir}/server-cert.pem \
    -n ${namespace}

echo "Secret ${secret} created in namespace ${namespace}"

# Output the CA bundle for webhook configuration
echo ""
echo "CA Bundle (base64 encoded) for webhook configuration:"
cat ${tmpdir}/ca-cert.pem | base64 | tr -d '\n'
echo ""

# Clean up
rm -rf ${tmpdir}

```

一旦 secret 对象创建成功，我们就可以直接创建 deployment 和 service 对象。

```go
➜  ~ kubectl apply -f deployment/rbac.yaml
➜  ~ kubectl apply -f deployment/deployment.yaml
deployment.apps "admission-webhook-example-deployment" created

➜  ~ kubectl apply -f deployment/service.yaml
service "admission-webhook-example-svc" created
```

### 2.4 配置 webhook
现在我们的 webhook 服务运行起来了，它可以接收来自 apiserver 的请求。但是我们还需要在 kubernetes 上创建一些配置资源。首先来配置 validating 这个 webhook，查看 webhook 配置，我们会注意到它里面包含一个 `<font style="color:#DF2A3F;">CA_BUNDLE</font>`<font style="color:#DF2A3F;"> </font>的占位符：

```yaml
clientConfig:
  service:
    name: admission-webhook-example-svc
    namespace: default
    path: "/validate"
  caBundle: ${CA_BUNDLE}
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760424654480-63198ba6-6cc1-4371-8e40-b424d27d1b73.png)

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760424693642-04021db4-82e2-42f1-a729-f21abc7da622.png)

CA 证书应提供给 Admission Webhook 配置，这样 ApiServer 才可以信任 webhook server 提供的 TLS 证书。因为我们上面已经使用 Kubernetes API 签署了证书，所以我们可以使用我们的 kubeconfig 中的 CA 证书来简化操作。代码仓库中也提供了一个小脚本用来替换 CA_BUNDLE 这个占位符，创建 `<font style="color:#DF2A3F;">validating webhook</font>` 之前运行该命令即可：

```bash
$ cat ./deployment/validatingwebhook.yaml | ./deployment/webhook-patch-ca-bundle.sh > ./deployment/validatingwebhook-ca-bundle.yaml
```

执行完成后可以查看 `<font style="color:#DF2A3F;">validatingwebhook-ca-bundle.yaml</font>` 文件中的<font style="color:#DF2A3F;"> </font>`<font style="color:#DF2A3F;">CA_BUNDLE</font>`<font style="color:#DF2A3F;"> </font>占位符的值是否已经被替换掉了。需要注意的是 `<font style="color:#DF2A3F;">clientConfig</font>`<font style="color:#DF2A3F;"> </font>里面的 path 路径是 `<font style="color:#DF2A3F;">/validate</font>`，因为我们代码在是将 validate 和 mutate 集成在一个服务中的。

然后就是需要配置一些 RBAC 规则，我们想在 deployment 或 service 创建时拦截 API 请求，所以 apiGroups 和 apiVersions 对应的值分别为 `<font style="color:#DF2A3F;">apps/v1</font>`<font style="color:#DF2A3F;"> </font>对应 deployment，v1 对应 service。

webhook 的最后一部分是配置一个 `<font style="color:#DF2A3F;">namespaceSelector</font>`，我们可以为 webhook 工作的命名空间定义一个 selector，这个配置不是必须的，比如我们这里添加了下面的配置：

```yaml
namespaceSelector:
  matchLabels:
      admission-webhook-example: enabled
```

则我们的 webhook 会只适用于设置了 `<font style="color:#DF2A3F;">admission-webhook-example=enabled</font>` 标签的 namespaces。

所以，首先需要在 default 这个 namespace 中添加该标签：

```go
➜  ~ kubectl label namespace default admission-webhook-example=enabled
namespace "default" labeled
```

最后，创建这个 validating webhook 配置对象，这会动态地将 webhook 添加到 webhook 链上，所以一旦创建资源，就会拦截请求然后调用我们的 webhook 服务：

```go
➜  ~ kubectl apply -f deployment/validatingwebhook-ca-bundle.yaml
validatingwebhookconfiguration.admissionregistration.k8s.io "validation-webhook-example-cfg" created
```

### 2.5 测试
现在让我们创建一个 deployment 资源来验证下是否有效，代码仓库下有一个 `<font style="color:#DF2A3F;">sleep.yaml</font>` 的资源清单文件，直接创建即可：

```go
➜  ~ kubectl apply -f deployment/sleep.yaml
Error from server (required labels are not set): error when creating "deployment/sleep.yaml": admission webhook "required-labels.qikqiak.com" denied the request: required labels are not set
```

正常情况下创建的时候会出现上面的错误信息，然后部署另外一个 `<font style="color:#DF2A3F;">sleep-with-labels.yaml</font>` 的资源清单：

```go
➜  ~ kubectl apply -f deployment/sleep-with-labels.yaml
deployment.apps "sleep" created
```

可以看到可以正常部署，然后我们将上面的 deployment 删除，然后部署另外一个 `<font style="color:#DF2A3F;">sleep-no-validation.yaml</font>` 资源清单，该清单中不存在所需的标签，但是配置了 `<font style="color:#DF2A3F;">admission-webhook-example.qikqiak.com/validate=false</font>` 这样的 annotation，所以正常也是可以正常创建的：

```go
➜  ~ kubectl delete deployment sleep
➜  ~ kubectl apply -f deployment/sleep-no-validation.yaml
deployment.apps "sleep" created
```

### 2.6 部署 mutating webhook
首先，我们将上面的 `<font style="color:#DF2A3F;">validating webhook</font>` 删除，防止对 mutating 产生干扰，然后部署新的配置。 `<font style="color:#DF2A3F;">mutating</font> <font style="color:#DF2A3F;">webhook</font>`<font style="color:#DF2A3F;"> </font>与 `<font style="color:#DF2A3F;">validating webhook</font>` 配置基本相同，但是 webook server 的路径是 `<font style="color:#DF2A3F;">/mutate</font>`，同样的我们也需要先填充上 `<font style="color:#DF2A3F;">CA_BUNDLE</font>`<font style="color:#DF2A3F;"> </font>这个占位符。

```go
➜  ~ kubectl delete validatingwebhookconfiguration validation-webhook-example-cfg
validatingwebhookconfiguration.admissionregistration.k8s.io "validation-webhook-example-cfg" deleted

➜  ~ cat ./deployment/mutatingwebhook.yaml | ./deployment/webhook-patch-ca-bundle.sh > ./deployment/mutatingwebhook-ca-bundle.yaml

➜  ~ kubectl apply -f deployment/mutatingwebhook-ca-bundle.yaml
mutatingwebhookconfiguration.admissionregistration.k8s.io "mutating-webhook-example-cfg" created
```

现在我们可以再次部署上面的 sleep 应用程序，然后查看是否正确添加 label 标签：

```yaml
➜  ~ kubectl apply -f deployment/sleep.yaml
deployment.apps "sleep" created

➜  ~ kubectl get deploy sleep -o yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    admission-webhook-example.qikqiak.com/status: mutated
    deployment.kubernetes.io/revision: "1"
  creationTimestamp: "2020-06-01T08:10:04Z"
  generation: 1
  labels:
    app.kubernetes.io/component: not_available
    app.kubernetes.io/instance: not_available
    app.kubernetes.io/managed-by: not_available
    app.kubernetes.io/name: not_available
    app.kubernetes.io/part-of: not_available
    app.kubernetes.io/version: not_available
  name: sleep
  namespace: default
...
```

最后，我们重新创建 `<font style="color:#DF2A3F;">validating webhook</font>`，来一起测试。现在，尝试再次创建 sleep 应用。正常是可以创建成功的，我们可以查看下 [admission-controllers 的文档](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#what-are-they)。

准入控制分两个阶段进行，第一阶段，运行 `<font style="color:#DF2A3F;">mutating admission</font>` 控制器，第二阶段运行 `<font style="color:#DF2A3F;">validating admission</font>` 控制器。

所以 `<font style="color:#DF2A3F;">mutating webhook</font>` 在第一阶段添加上缺失的 labels 标签，然后 `<font style="color:#DF2A3F;">validating webhook</font>` 在第二阶段就不会拒绝这个 deployment 了，因为标签已经存在了，用 `<font style="color:#DF2A3F;">not_available</font>`<font style="color:#DF2A3F;"> </font>设置他们的值。

```go
➜  ~ kubectl apply -f deployment/validatingwebhook-ca-bundle.yaml
validatingwebhookconfiguration.admissionregistration.k8s.io "validation-webhook-example-cfg" created

➜  ~ kubectl apply -f deployment/sleep.yaml
deployment.apps "sleep" created
```

但是如果我们有这样的相关需求就单独去开发一个准入控制器的 webhook 是不是就显得非常麻烦，不够灵活了，为了解决这个问题我们可以使用 Kubernetes 提供的一些策略管理引擎，在不需要编写代码的情况也可以来实现我们的这些需求，比如 `<font style="color:#DF2A3F;">Kyverno</font>`、`<font style="color:#DF2A3F;">Gatekeeper</font>`<font style="color:#DF2A3F;"> </font>等等，后续我们再进行详细讲解。

## 3 小总结
:::warning
Admission Webhook 原理需要知道。

+ <u><font style="color:#601BDE;">Mutating Admission Webhook 是用于改变资源对象的值属性</font></u>（<u><font style="color:#DF2A3F;">在引用资源清单进行验证授权之后，保存 etcd 数据库之前，进行对资源对象赋能</font></u>）；
+ <u><font style="color:#601BDE;">Validating Admission Webhook 则是用于校验资源对象是否符合 Kubernetes 的资源规范</font></u>（<font style="color:#DF2A3F;">开发者编写的资源对象，需要进行创建的话，就需要校验之后符合开发者或者 Kubernetes 的规范</font>）。

![Kubernetes API 请求的生命周期](https://cdn.nlark.com/yuque/0/2024/png/2555283/1729322446417-3d3e961d-4557-4b8c-ab91-2d0b9cbab829.png)

:::

## 4 参考资料
[🕸️[K8S] 20 RBAC 准入控制器[Admission Controller]](https://www.yuque.com/seekerzw/xi8l23/fbv9n54grkva7lqs)

[[Kyverno] Kyverno](https://www.yuque.com/seekerzw/xi8l23/rg1mt7zevn4eulkh)

[[OPA] OPA 策略引擎](https://www.yuque.com/seekerzw/xi8l23/ym70hdxw5cveyscm)

