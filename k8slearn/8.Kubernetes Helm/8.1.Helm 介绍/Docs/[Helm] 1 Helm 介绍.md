> Link Reference：[Helm 在 Kubernetes 应用部署中的最佳实践：从入门到精通的实战指南](https://mp.weixin.qq.com/s/3ptx3iUxpkXf2z3SN5Bq_g)
>

Helm 可以帮助我们管理 Kubernetes 应用程序 - <u><font style="color:#DF2A3F;">Helm Charts 可以定义、安装和升级复杂的 Kubernetes 应用程序，Charts 包很容易创建、版本管理、分享和分布。</font></u>Helm 对于 Kubernetes 来说就相当于 yum 对于 CentOS 来说，如果没有 yum 的话，我们在 CentOS 下面要安装一些应用程序是极度麻烦的，同样的，对于越来越复杂的 Kubernetes 应用程序来说，如果单纯依靠我们去手动维护应用程序的 YAML 资源清单文件来说，成本也是巨大的。接下来我们就来了解了 Helm 的使用方法。

## 1 Helm CLI 安装
首先当然需要一个可用的 Kubernetes 集群，然后在我们使用 Helm 的节点上已经配置好可以通过 kubectl 访问集群，因为 Helm 其实就是读取的 kubeconfig 文件来访问集群的。

由于 Helm V2 版本必须在 Kubernetes 集群中安装一个 Tiller 服务进行通信，这样大大降低了其安全性和可用性，所以在 V3 版本中移除了服务端，采用了通用的 Kubernetes CRD 资源来进行管理，这样就只需要连接上 Kubernetes 即可，而且 V3 版本已经发布了稳定版，所以我们这里来安装最新的 v3.8.0 版本，软件包下载地址为：`[https://github.com/helm/helm/releases](https://github.com/helm/helm/releases)`，我们可以根据自己的节点选择合适的包，比如我这里是 Mac，就下载 [MacOS amd64](https://get.helm.sh/helm-v3.8.0-darwin-amd64.tar.gz) 的版本。

下载到本地解压后，将 helm 二进制包文件移动到任意的 PATH 路径下即可：

```shell
➜ helm version
version.BuildInfo{Version:"v3.8.0", GitCommit:"d14138609b01886f544b2025f5000351c9eb092e", GitTreeState:"clean", GoVersion:"go1.17.5"}

# 使用叫新版
➜ helm version
version.BuildInfo{Version:"v3.13.0", GitCommit:"825e86f6a7a38cef1112bfa606e4127a706749b1", GitTreeState:"clean", GoVersion:"go1.20.8"}
```

看到上面的版本信息证明已经成功了。

一旦 Helm 客户端准备成功后，我们就可以添加一个 chart 仓库，当然最常用的就是官方的 Helm stable charts 仓库，但是由于官方的 Charts 仓库地址需要科学上网，我们可以使用微软的 charts 仓库代替：

```shell
➜ helm repo add stable http://mirror.azure.cn/kubernetes/charts/
➜ helm repo list
NAME                            URL                                                               
grafana                         https://grafana.github.io/helm-charts                             
open-telemetry                  https://open-telemetry.github.io/opentelemetry-helm-charts        
strimzi                         https://strimzi.io/charts/                                        
kafka-ui                        https://provectus.github.io/kafka-ui-charts                       
bitpoke                         https://helm-charts.bitpoke.io                                    
stable                          https://charts.helm.sh/stable                                     
komodorio                       https://helm-charts.komodor.io                                    
bitnami                         https://charts.bitnami.com/bitnami                                
openkruise                      https://openkruise.github.io/charts                               
descheduler                     https://kubernetes-sigs.github.io/descheduler/                    
nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
longhorn                        https://charts.longhorn.io                                        
ingress-nginx                   https://kubernetes.github.io/ingress-nginx                        
kubernetes-dashboard            https://kubernetes.github.io/dashboard/                           
apisix                          https://charts.apiseven.com           
```

安装完成后可以用 search 命令来搜索可以安装的 chart 包：

```shell
➜ helm search repo stable
NAME                                    CHART VERSION   APP VERSION             DESCRIPTION                                       
stable/acs-engine-autoscaler            2.2.2           2.1.1                   DEPRECATED Scales worker nodes within agent pools 
stable/aerospike                        0.3.5           v4.5.0.5                DEPRECATED A Helm chart for Aerospike in Kubern...
stable/airflow                          7.13.3          1.10.12                 DEPRECATED - please use: https://github.com/air...
stable/ambassador                       5.3.2           0.86.1                  DEPRECATED A Helm chart for Datawire Ambassador   
stable/anchore-engine                   1.7.0           0.7.3                   Anchore container analysis and policy evaluatio...
stable/apm-server                       2.1.7           7.0.0                   DEPRECATED The server receives data from the El...
stable/ark                              4.2.2           0.10.2                  DEPRECATED A Helm chart for ark                   
stable/artifactory                      7.3.2           6.1.0                   DEPRECATED Universal Repository Manager support...
stable/artifactory-ha                   0.4.2           6.2.0                   DEPRECATED Universal Repository Manager support...
stable/atlantis                         3.12.4          v0.14.0                 DEPRECATED A Helm chart for Atlantis https://ww...
stable/auditbeat                        1.1.2           6.7.0                   DEPRECATED A lightweight shipper to audit the a...
[......]
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761805129222-6dff8119-6cf4-4255-8dec-3a78249a8130.png)

## 2 Helm 示例
为了安装一个 chart 包，我们可以使用 `<font style="color:#DF2A3F;">helm install</font>` 命令，Helm 有多种方法来找到和安装 chart 包，但是最简单的方法当然是使用官方的 `<font style="color:#DF2A3F;">stable</font>` 这个仓库直接安装：

首先从仓库中将可用的 charts 信息同步到本地，可以确保我们获取到最新的 charts 列表：

```shell
➜ helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "strimzi" chart repository
...Successfully got an update from the "openkruise" chart repository
...Successfully got an update from the "komodorio" chart repository
...Successfully got an update from the "kubernetes-dashboard" chart repository
...Successfully got an update from the "kafka-ui" chart repository
...Successfully got an update from the "nfs-subdir-external-provisioner" chart repository
...Successfully got an update from the "descheduler" chart repository
...Successfully got an update from the "ingress-nginx" chart repository
...Successfully got an update from the "longhorn" chart repository
...Successfully got an update from the "apisix" chart repository
...Successfully got an update from the "bitpoke" chart repository
...Successfully got an update from the "open-telemetry" chart repository
...Successfully got an update from the "stable" chart repository
...Successfully got an update from the "grafana" chart repository
...Successfully got an update from the "bitnami" chart repository
Update Complete. ⎈Happy Helming!⎈
```

比如我们现在安装一个 `<font style="color:#DF2A3F;">mysql</font>` 应用：

```shell
➜ helm install stable/mysql --generate-name
WARNING: This chart is deprecated
NAME: mysql-1761805412
LAST DEPLOYED: Thu Oct 30 14:23:34 2025
NAMESPACE: default
STATUS: deployed
REVISION: 1
NOTES:
MySQL can be accessed via port 3306 on the following DNS name from within your cluster:
mysql-1761805412.default.svc.cluster.local

To get your root password run:

    MYSQL_ROOT_PASSWORD=$(kubectl get secret --namespace default mysql-1761805412 -o jsonpath="{.data.mysql-root-password}" | base64 --decode; echo)

To connect to your database:

1. Run an Ubuntu pod that you can use as a client:

    kubectl run -i --tty ubuntu --image=ubuntu:16.04 --restart=Never -- bash -il

2. Install the mysql client:

    $ apt-get update && apt-get install mysql-client -y

3. Connect using the mysql cli, then provide your password:
    $ mysql -h mysql-1761805412 -p

To connect to your database directly from outside the K8s cluster:
    MYSQL_HOST=127.0.0.1
    MYSQL_PORT=3306

    # Execute the following command to route the connection:
    kubectl port-forward svc/mysql-1761805412 3306

    mysql -h ${MYSQL_HOST} -P${MYSQL_PORT} -u root -p${MYSQL_ROOT_PASSWORD}
```

我们可以看到<font style="color:#DF2A3F;"> </font>`<font style="color:#DF2A3F;">stable/mysql</font>` 这个 chart 已经安装成功了，我们将安装成功的这个应用叫做一个 `<font style="color:#DF2A3F;">release</font>`，由于我们在安装的时候指定了`<font style="color:#DF2A3F;">--generate-name</font>` 参数，所以生成的 release 名称是随机生成的，名为 `<font style="color:#DF2A3F;">mysql-1761805412</font>`。我们可以用下面的命令来查看 release 安装以后对应的 Kubernetes 资源的状态：

```shell
➜ kubectl get all -l release=mysql-1761805412
NAME                                   READY   STATUS     RESTARTS   AGE
pod/mysql-1761805412-d46f54499-cdxvd   0/1     Init:0/1   0          85s

NAME                       TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
service/mysql-1761805412   ClusterIP   192.96.53.55   <none>        3306/TCP   85s

NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/mysql-1761805412   0/1     1            0           85s

NAME                                         DESIRED   CURRENT   READY   AGE
replicaset.apps/mysql-1761805412-d46f54499   1         1         0       85s
```

我们也可以 `<font style="color:#DF2A3F;">helm show chart</font>` 命令来了解 MySQL 这个 chart 包的一些特性：

```shell
➜ helm show chart stable/mysql
apiVersion: v1
appVersion: 5.7.30
deprecated: true
description: DEPRECATED - Fast, reliable, scalable, and easy to use open-source relational
  database system.
home: https://www.mysql.com/
icon: https://www.mysql.com/common/logos/logo-mysql-170x115.png
keywords:
- mysql
- database
- sql
name: mysql
sources:
- https://github.com/kubernetes/charts
- https://github.com/docker-library/mysql
version: 1.6.9
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761805486999-9bd29b89-95a3-4b87-90a6-86cf5b9cb726.png)

如果想要了解更多信息，可以用 `<font style="color:#DF2A3F;">helm show all</font>` 命令：

```shell
➜ helm show all stable/mysql
[......]
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761805578240-8f4e8414-3163-479b-8769-3cfddd9ad913.png)

需要注意的是无论什么时候安装 chart，都会创建一个新的 release，所以一个 chart 包是可以多次安装到同一个集群中的，每个都可以独立管理和升级。

同样我们也可以用 Helm 很容易查看到已经安装的 release：

```shell
# 查看到已经安装的 release
➜ helm ls
NAME                    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART           APP VERSION
mysql-1761805412        default         1               2025-10-30 14:23:34.636668682 +0800 HKT deployed        mysql-1.6.9     5.7.30   
```

如果需要删除这个 release，也很简单，只需要使用 `<font style="color:#DF2A3F;">helm uninstall</font>` 命令即可：

```shell
➜ helm status mysql-1761805412
NAME: mysql-1761805412
LAST DEPLOYED: Thu Oct 30 14:23:34 2025
NAMESPACE: default
STATUS: deployed
REVISION: 1
NOTES:
MySQL can be accessed via port 3306 on the following DNS name from within your cluster:
mysql-1761805412.default.svc.cluster.local

To get your root password run:

    MYSQL_ROOT_PASSWORD=$(kubectl get secret --namespace default mysql-1761805412 -o jsonpath="{.data.mysql-root-password}" | base64 --decode; echo)

To connect to your database:

1. Run an Ubuntu pod that you can use as a client:

    kubectl run -i --tty ubuntu --image=ubuntu:16.04 --restart=Never -- bash -il

2. Install the mysql client:

    $ apt-get update && apt-get install mysql-client -y

3. Connect using the mysql cli, then provide your password:
    $ mysql -h mysql-1761805412 -p

To connect to your database directly from outside the K8s cluster:
    MYSQL_HOST=127.0.0.1
    MYSQL_PORT=3306

    # Execute the following command to route the connection:
    kubectl port-forward svc/mysql-1761805412 3306

    mysql -h ${MYSQL_HOST} -P${MYSQL_PORT} -u root -p${MYSQL_ROOT_PASSWORD}

# 删除已经安装的 release
➜ helm uninstall mysql-1761805412
release "mysql-1761805412" uninstalled

➜ kubectl get all -l release=mysql-1761805412
No resources found.

➜ helm status mysql-1761805412
Error: release: not found
```

`<font style="color:#DF2A3F;">uninstall</font>` 命令会从 Kubernetes 中删除 release，也会删除与 release 相关的所有 Kubernetes 资源以及 release 历史记录。也可以在删除的时候使用 `<font style="color:#DF2A3F;">--keep-history</font>` 参数，则会保留 release 的历史记录，可以获取该 release 的状态就是 `<font style="color:#DF2A3F;">UNINSTALLED</font>`，而不是找不到 release了：

```shell
➜ helm install stable/mysql --generate-name
WARNING: This chart is deprecated
NAME: mysql-1761805841
LAST DEPLOYED: Thu Oct 30 14:30:44 2025
NAMESPACE: default
STATUS: deployed
REVISION: 1
NOTES:
MySQL can be accessed via port 3306 on the following DNS name from within your cluster:
mysql-1761805841.default.svc.cluster.local
[......]

# 保留 release 的历史记录
➜ helm uninstall mysql-1761805841 --keep-history
release "mysql-1761805841" uninstalled

➜ helm status mysql-1761805841
NAME: mysql-1761805841
LAST DEPLOYED: Thu Oct 30 14:30:44 2025
NAMESPACE: default
STATUS: uninstalled
REVISION: 1
NOTES:
MySQL can be accessed via port 3306 on the following DNS name from within your cluster:
mysql-1761805841.default.svc.cluster.local

To get your root password run:

    MYSQL_ROOT_PASSWORD=$(kubectl get secret --namespace default mysql-1761805841 -o jsonpath="{.data.mysql-root-password}" | base64 --decode; echo)

To connect to your database:

1. Run an Ubuntu pod that you can use as a client:

    kubectl run -i --tty ubuntu --image=ubuntu:16.04 --restart=Never -- bash -il

2. Install the mysql client:

    $ apt-get update && apt-get install mysql-client -y

3. Connect using the mysql cli, then provide your password:
    $ mysql -h mysql-1761805841 -p

To connect to your database directly from outside the K8s cluster:
    MYSQL_HOST=127.0.0.1
    MYSQL_PORT=3306

    # Execute the following command to route the connection:
    kubectl port-forward svc/mysql-1761805841 3306

    mysql -h ${MYSQL_HOST} -P${MYSQL_PORT} -u root -p${MYSQL_ROOT_PASSWORD}

➜ helm ls -a
NAME                    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART           APP VERSION
mysql-1761805841        default         1               2025-10-30 14:30:44.211986926 +0800 HKT uninstalled     mysql-1.6.9     5.7.30  
```

因为 Helm 会在删除 `<font style="color:#DF2A3F;">release</font>` 后跟踪你的 `<font style="color:#DF2A3F;">release</font>`，所以你可以审查历史甚至取消删除 `<font style="color:#DF2A3F;">release</font>`（使用 `<font style="color:#DF2A3F;">helm rollback</font>` 命令）。

## 3 定制 Helm 部署
上面我们都是直接使用的 `<font style="color:#DF2A3F;">helm install</font>` 命令安装的 chart 包，这种情况下只会使用 chart 的默认配置选项，但是更多的时候，是各种各样的需求，索引我们希望根据自己的需求来定制 chart 包的配置参数。

我们可以使用 `<font style="color:#DF2A3F;">helm show values</font>` 命令来查看一个 chart 包的所有可配置的参数选项：

```shell
# 所有可配置的参数选项
➜ helm show values stable/mysql
## mysql image version
## ref: https://hub.docker.com/r/library/mysql/tags/
##
image: "mysql"
imageTag: "5.7.30"

strategy:
  type: Recreate

busybox:
  image: "busybox"
  tag: "1.32"

testFramework:
  enabled: true
  image: "bats/bats"
  tag: "1.2.1"
  imagePullPolicy: IfNotPresent
  securityContext: {}

## Specify password for root user
##
## Default: random 10 character string
# mysqlRootPassword: testing

## Create a database user
##
# mysqlUser:
## Default: random 10 character string
# mysqlPassword:

## Allow unauthenticated access, uncomment to enable
##
# mysqlAllowEmptyPassword: true

## Create a database
##
# mysqlDatabase:

## Specify an imagePullPolicy (Required)
## It's recommended to change this to 'Always' if the image tag is 'latest'
## ref: http://kubernetes.io/docs/user-guide/images/#updating-images
##
imagePullPolicy: IfNotPresent
[......]
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761806040985-7d182fed-5475-421a-ab11-e5ac37f501b9.png)

上面我们看到的所有参数都是可以用自己的数据来覆盖的，可以在安装的时候通过 YAML 格式的文件来传递这些参数：

```shell
➜ cat config.yaml
mysqlUser:
  user0
mysqlPassword: user0pwd
mysqlDatabase: user0db
persistence:
  enabled: false

# 使用指定的配置文件参数进行定制化 Helm 部署
➜ helm install -f config.yaml mysql stable/mysql
WARNING: This chart is deprecated
NAME: mysql
LAST DEPLOYED: Thu Oct 30 14:35:31 2025
NAMESPACE: default
STATUS: deployed
REVISION: 1
NOTES:
MySQL can be accessed via port 3306 on the following DNS name from within your cluster:
mysql.default.svc.cluster.local

To get your root password run:

    MYSQL_ROOT_PASSWORD=$(kubectl get secret --namespace default mysql -o jsonpath="{.data.mysql-root-password}" | base64 --decode; echo)

To connect to your database:

1. Run an Ubuntu pod that you can use as a client:

    kubectl run -i --tty ubuntu --image=ubuntu:16.04 --restart=Never -- bash -il

2. Install the mysql client:

    $ apt-get update && apt-get install mysql-client -y

3. Connect using the mysql cli, then provide your password:
    $ mysql -h mysql -p

To connect to your database directly from outside the K8s cluster:
    MYSQL_HOST=127.0.0.1
    MYSQL_PORT=3306

    # Execute the following command to route the connection:
    kubectl port-forward svc/mysql 3306

    mysql -h ${MYSQL_HOST} -P${MYSQL_PORT} -u root -p${MYSQL_ROOT_PASSWORD}
```

Release 安装成功后，可以查看对应的 Pod 信息：

```shell
➜ kubectl get pod -l release=mysql
NAME                     READY   STATUS    RESTARTS   AGE
mysql-699f75d785-r9tpx   1/1     Running   0          3m55s

➜ kubectl describe pod  mysql-699f75d785-r9tpx
[......]
Containers:
  mysql:
    Container ID:   containerd://b15bdf227405c5277e1e18f99dd8b01a1654561ab9d90b6ac6af937372e522a9
    Image:          mysql:5.7.30
    [......]
    Environment:
      MYSQL_ROOT_PASSWORD:  <set to the key 'mysql-root-password' in secret 'mysql'>  Optional: false
      MYSQL_PASSWORD:       <set to the key 'mysql-password' in secret 'mysql'>       Optional: false
      MYSQL_USER:           user0
      MYSQL_DATABASE:       user0db
[......]
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761811676724-25dd2b1b-debe-474b-adcc-a855ed9e8365.png)

可以看到环境变量 `<font style="color:#DF2A3F;">MYSQL_USER=user0，MYSQL_DATABASE=user0db</font>`<font style="color:#DF2A3F;"> </font>的值和我们上面配置的值是一致的。在安装过程中，有两种方法可以传递配置数据：

+ `<font style="color:#DF2A3F;">--values（或者 -f）</font>`：指定一个 YAML 文件来覆盖 values 值，可以指定多个值，最后边的文件优先
+ `<font style="color:#DF2A3F;">--set</font>`：在命令行上指定覆盖的配置

如果同时使用这两个参数，`<font style="color:#DF2A3F;">--values(-f)</font>`<font style="color:#DF2A3F;"> </font>将被合并到具有更高优先级的 `<font style="color:#DF2A3F;">--set</font>`，使用 `<font style="color:#DF2A3F;">--set</font>` 指定的值将持久化在 ConfigMap 中，对于给定的 release，可以使用 `<font style="color:#DF2A3F;">helm get values <release-name></font>` 来查看已经设置的值，已设置的值也通过允许 `<font style="color:#DF2A3F;">helm upgrade</font>` 并指定 `<font style="color:#DF2A3F;">--reset</font>` 值来清除。

`<font style="color:#DF2A3F;">--set</font>` 选项接收零个或多个 name/value 对，最简单的用法就是 `<font style="color:#DF2A3F;">--set name=value</font>`，相当于 YAML 文件中的：

```yaml
name: value
```

多个值之间用字符串“,”隔开，用法就是 `<font style="color:#DF2A3F;">--set a=b,c=d</font>`，相当于 YAML 文件中的：

```yaml
a: b
c: d
```

也支持更加复杂的表达式，例如 `<font style="color:#DF2A3F;">--set outer.inner=value</font>`，对应 YAML：

```yaml
outer:
  inner: value
```

对于列表数组可以用<font style="color:#DF2A3F;"> </font>`<font style="color:#DF2A3F;">{}</font>` 来包裹，比如 `<font style="color:#DF2A3F;">--set name={a, b, c}</font>`，对应 YAML：

```yaml
name:
 - a
 - b
 - c
```

从 Helm 2.5.0 开始，就可以使用数组索引语法来访问列表中某个项，比如 `<font style="color:#DF2A3F;">--set servers[0].port=80</font>`，对应的 YAML 为：

```yaml
servers:
 - port: 80
```

也可以这样设置多个值，比如 `<font style="color:#DF2A3F;">--set servers[0].port=80,servers[0].host=example</font>`，对应的 YAML 为：

```yaml
servers
  - port: 80
    host: example
```

有时候你可能需要在 `<font style="color:#DF2A3F;">--set</font>` 选项中使用特殊的字符，这个时候可以使用反斜杠来转义字符，比如 `<font style="color:#DF2A3F;">--set name=value1\,value2</font>`，对应的 YAML 为：

```yaml
name: "value1,value2"
```

类似的，你还可以转义`<font style="color:#DF2A3F;">.</font>`，当 chart 模板中使用 `<font style="color:#DF2A3F;">toYaml</font>` 函数来解析 annotations、labels 以及 node selectors 之类的时候，这非常有用，比如 `<font style="color:#DF2A3F;">--set nodeSelector."kubernetes\.io/role"=master</font>`，对应的 YAML 文件：

```yaml
nodeSelector:
  kubernetes.io/role: master
```

深度嵌套的数据结构可能很难使用 `<font style="color:#DF2A3F;">--set</font>` 来表示，所以一般推荐还是使用 YAML 文件来进行覆盖，当然在设计 chart 模板的时候也可以结合考虑到 `<font style="color:#DF2A3F;">--set</font>` 这种用法，尽可能的提供更好的支持。

## 4 更多安装方式
`<font style="color:#DF2A3F;">helm install</font>` 命令可以从多个源进行安装：

+ chart 仓库（类似于上面我们提到的）
+ 本地 chart 压缩包（`<font style="color:#DF2A3F;">helm install foo-0.1.1.tgz</font>`）
+ 本地解压缩的 chart 目录（`<font style="color:#DF2A3F;">helm install foo path/to/foo</font>`）
+ 在线的 URL（`<font style="color:#DF2A3F;">helm install --generate-name fool</font> [https://example.com/charts/foo-1.2.3.tgz](https://example.com/charts/foo-1.2.3.tgz)`）

## 5 升级和回滚
当新版本的 chart 包发布的时候，或者当你要更改 release 的配置的时候，你可以使用 `<font style="color:#DF2A3F;">helm upgrade</font>` 命令来操作。升级需要一个现有的 release，并根据提供的信息对其进行升级。因为 Kubernetes charts 可能很大而且很复杂，Helm 会尝试以最小的侵入性进行升级，它只会更新自上一版本以来发生的变化：

```yaml
# 进行 Helm Release 升级
➜ helm upgrade -f config.yaml mysql stable/mysql
WARNING: This chart is deprecated
false
Release "mysql" has been upgraded. Happy Helming!
NAME: mysql
LAST DEPLOYED: Thu Oct 30 16:09:29 2025
NAMESPACE: default
STATUS: deployed
REVISION: 2
NOTES:
MySQL can be accessed via port 3306 on the following DNS name from within your cluster:
mysql.default.svc.cluster.local
[......]
```

我们这里 `<font style="color:#DF2A3F;">mysql</font>` 这个 release 用相同的 chart 包进行升级，但是新增了一个配置项：

```yaml
mysqlRootPassword: passw0rd
```

我们可以使用 `<font style="color:#DF2A3F;">helm get values</font>` 来查看新设置是否生效：

```shell
➜ helm get values mysql
USER-SUPPLIED VALUES:
mysqlDatabase: user0db
mysqlPassword: user0pwd
mysqlRootPassword: passw0rd
mysqlUser: user0
persistence:
  enabled: false
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761812054065-0206a4ea-2666-4817-b133-db06a3bc1ade.png)

`<font style="color:#DF2A3F;">helm get</font>` 命令是查看集群中 release 的非常有用的命令，正如我们在上面看到的，它显示了 `<font style="color:#DF2A3F;">panda.yaml</font>` 中的新配置值被部署到了集群中，现在如果某个版本在发布期间没有按计划进行，那么可以使用 `<font style="color:#DF2A3F;">helm rollback [RELEASE] [REVISION]</font>` 命令很容易回滚到之前的版本：

```shell
➜ helm ls 
NAME    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART           APP VERSION
mysql   default         2               2025-10-30 16:09:29.575462608 +0800 HKT deployed        mysql-1.6.9     5.7.30     

# 查看 Release 的历史版本
➜ helm history mysql
REVISION        UPDATED                         STATUS          CHART           APP VERSION     DESCRIPTION     
1               Thu Oct 30 14:35:31 2025        superseded      mysql-1.6.9     5.7.30          Install complete
2               Thu Oct 30 16:09:29 2025        deployed        mysql-1.6.9     5.7.30          Upgrade complete

# Helm 回滚到之前的版本
➜ helm rollback mysql 1
Rollback was a success! Happy Helming!

➜ kubectl get pods -l release=mysql
NAME                     READY   STATUS    RESTARTS   AGE
mysql-699f75d785-r9tpx   1/1     Running   0          95m

➜ helm get values mysql
USER-SUPPLIED VALUES:
mysqlDatabase: user0db
mysqlPassword: user0pwd
mysqlUser: user0
persistence:
  enabled: false
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761811954257-fa47db59-617b-4d99-9d6e-d06f6fd235cc.png)

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761812073982-761fd69a-16d4-47e8-94a1-03aa663d85bc.png)

可以看到 values 配置已经回滚到之前的版本了。上面的命令回滚到了 release 的第一个版本，每次进行安装、升级或回滚时，修订号都会加 1，第一个修订号始终为1，我们可以使用 `<font style="color:#DF2A3F;">helm history [RELEASE]</font>` 来查看某个版本的修订号。

除此之外我们还可以指定一些有用的选项来定制 `<font style="color:#DF2A3F;">install/upgrade/rollback</font>` 的一些行为，要查看完整的参数标志，我们可以运行 `<font style="color:#DF2A3F;">helm <command> --help</font>` 来查看，这里我们介绍几个有用的参数：

+ `<font style="color:#DF2A3F;">--timeout</font>`: 等待 Kubernetes 命令完成的时间，默认是 300（5分钟），可以使用在日常的部署以及 CICD 的流程中。
+ `<font style="color:#DF2A3F;">--wait</font>`: 等待直到所有 Pods 都处于就绪状态、PVCs 已经绑定、Deployments 具有处于就绪状态的最小 Pods 数量（期望值减去 maxUnavailable）以及 Service 有一个 IP 地址，然后才标记 release 为成功状态。它将等待与 `<font style="color:#DF2A3F;">--timeout</font>`<font style="color:#DF2A3F;"> </font>值一样长的时间，如果达到超时，则 release 将标记为失败。注意：在 Deployment 将副本设置为 1 并且作为滚动更新策略的一部分，maxUnavailable 未设置为0的情况下，`<font style="color:#DF2A3F;">--wait</font>` 将返回就绪状态，因为它已满足就绪状态下的最小 Pod 数量
+ `<font style="color:#DF2A3F;">--no-hooks</font>`: 将会跳过命令的运行 hooks
+ `<font style="color:#DF2A3F;">--recreate-pods</font>`: 仅适用于 upgrade 和 rollback，这个标志将导致重新创建所有的 Pods。（Helm3 中启用了）

## 6 Helm Repo 可以添加的 URL
Helm Repo 可以添加的信息：

```shell
$ helm repo list 
NAME                    URL                                                       
jenkinsci               https://charts.jenkins.io/                                
jumpserver              https://jumpserver.github.io/helm-charts                  
bitnami                 https://charts.bitnami.com/bitnami                        
aliyunstable            https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts    
azure                   http://mirror.azure.cn/kubernetes/charts                  
stable                  https://charts.helm.sh/stable                             
gitlab                  https://charts.gitlab.io                                  
kiwigrid                https://kiwigrid.github.io                                
saleor                  https://k.github.io/saleor-helm                           
elastic                 https://helm.elastic.co                                   
harbor                  https://helm.goharbor.io                                  
reactiveops-stable      https://charts.reactiveops.com/stable                     
buttahtoast             https://buttahtoast.github.io/helm-charts/                
bedag                   https://bedag.github.io/helm-charts/                      
grafana                 https://grafana.github.io/helm-charts                     
prometheus              https://prometheus-community.github.io/helm-charts        
meshery                 https://meshery.io/charts/                                
neuvector               https://neuvector.github.io/neuvector-helm/               
higress.io              https://higress.io/helm-charts                            
istio                   https://istio-release.storage.googleapis.com/charts       
kyverno                 https://kyverno.github.io/kyverno/                        
open-telemetry          https://open-telemetry.github.io/opentelemetry-helm-charts
koderover-chart         https://koderover.tencentcloudcr.com/chartrepo/chart      
openobserve             https://charts.openobserve.ai                             
glasskube               https://charts.glasskube.eu/                              
kuma                    https://kumahq.github.io/charts                           
kubeclarity             https://openclarity.github.io/kubeclarity                 
kubevela                https://charts.kubevela.net/core
```

添加的命令如下：

```shell
$ helm repo add jenkinsci               https://charts.jenkins.io/                                
$ helm repo add jumpserver              https://jumpserver.github.io/helm-charts                  
$ helm repo add bitnami                 https://charts.bitnami.com/bitnami                        
$ helm repo add aliyunstable            https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts    
$ helm repo add azure                   http://mirror.azure.cn/kubernetes/charts                  
$ helm repo add stable                  https://charts.helm.sh/stable                             
$ helm repo add gitlab                  https://charts.gitlab.io                                  
$ helm repo add kiwigrid                https://kiwigrid.github.io                                
$ helm repo add saleor                  https://k.github.io/saleor-helm                           
$ helm repo add elastic                 https://helm.elastic.co                                   
$ helm repo add harbor                  https://helm.goharbor.io                                  
$ helm repo add reactiveops-stable      https://charts.reactiveops.com/stable                     
$ helm repo add buttahtoast             https://buttahtoast.github.io/helm-charts/                
$ helm repo add bedag                   https://bedag.github.io/helm-charts/                      
$ helm repo add grafana                 https://grafana.github.io/helm-charts                     
$ helm repo add prometheus              https://prometheus-community.github.io/helm-charts        
$ helm repo add meshery                 https://meshery.io/charts/                                
$ helm repo add neuvector               https://neuvector.github.io/neuvector-helm/               
$ helm repo add higress.io              https://higress.io/helm-charts                            
$ helm repo add istio                   https://istio-release.storage.googleapis.com/charts       
$ helm repo add kyverno                 https://kyverno.github.io/kyverno/                        
$ helm repo add open-telemetry          https://open-telemetry.github.io/opentelemetry-helm-charts
$ helm repo add koderover-chart         https://koderover.tencentcloudcr.com/chartrepo/chart      
$ helm repo add openobserve             https://charts.openobserve.ai                             
$ helm repo add glasskube               https://charts.glasskube.eu/                              
$ helm repo add kuma                    https://kumahq.github.io/charts                           
$ helm repo add kubeclarity             https://openclarity.github.io/kubeclarity                 
$ helm repo add kubevela                https://charts.kubevela.net/core
```

