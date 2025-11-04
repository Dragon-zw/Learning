<font style="color:rgb(28, 30, 33);">前面我们学习了本地存储、NFS 共享存储，除了这些存储类型之外，还有一个块存储，同样为 Kubernetes 提供块存储的方案有很多，比如 Ceph RBD，今天我们为大家介绍的是 Rancher 开源的一款 Kubernetes 的云原生分布式块存储方案 - Longhorn。</font>

<font style="color:rgb(28, 30, 33);">使用 Longhorn，可以：</font>

+ <font style="color:rgb(28, 30, 33);">使用 Longhorn 卷作为 Kubernetes 集群中分布式有状态应用程序的持久存储</font>
+ <font style="color:rgb(28, 30, 33);">将你的块存储分区为 Longhorn 卷，以便你可以在有或没有云提供商的情况下使用 Kubernetes 卷</font>
+ <font style="color:rgb(28, 30, 33);">跨多个节点和数据中心复制块存储以提高可用性</font>
+ <font style="color:rgb(28, 30, 33);">将备份数据存储在 NFS 或 AWS S3 等外部存储中</font>
+ <font style="color:rgb(28, 30, 33);">创建跨集群灾难恢复卷，以便可以从第二个 Kubernetes 集群中的备份中快速恢复主 Kubernetes 集群中的数据</font>
+ <font style="color:rgb(28, 30, 33);">调度一个卷的快照，并将备份调度到 NFS 或 S3 兼容的二级存储</font>
+ <font style="color:rgb(28, 30, 33);">从备份还原卷</font>
+ <font style="color:rgb(28, 30, 33);">不中断持久卷的情况下升级 Longhorn</font>

<font style="color:rgb(28, 30, 33);">Longhorn 还带有独立的 UI，可以使用 Helm、kubectl 或 Rancher 应用程序目录进行安装。</font>

## <font style="color:rgb(28, 30, 33);">1 Longhorn 架构</font>
<font style="color:rgb(28, 30, 33);">Longhorn 为每个卷创建一个专用的存储控制器，并在多个节点上存储的多个副本之间同步复制该卷。Longhorn 在整体上分为两层：</font>**<font style="color:rgb(28, 30, 33);">数据平面和控制平面</font>**<font style="color:rgb(28, 30, 33);">，Longhorn Engine 是存储控制器，对应数据平面，Longhorn Manager 对应控制平面。</font>

<font style="color:rgb(28, 30, 33);">Longhorn Manager 会以 DaemonSet 的形式在 Longhorn 集群中的每个节点上运行，它负责在 Kubernetes 集群中创建和管理卷，并处理来自 UI 或 Kubernetes 卷插件的 API 调用，它是遵循 Kubernetes 控制器模式。</font>

<font style="color:rgb(28, 30, 33);">Longhorn Manager 通过与 Kubernetes APIServer 通信来创建新的 Longhorn volume CRD，然后 Longhorn Manager 会一直 Watch APIServer 的响应，当它看到发现创建了一个新的 Longhorn volume CRD 时，Longhorn Manager 就会去创建一个新的对应卷。当 Longhorn Manager 被要求创建一个卷时，它会在卷所连接的节点上创建一个 Longhorn Engine 实例，并在每个将放置副本的节点上创建一个副本，副本应放置在不同的主机上以确保最大可用性。副本的多条数据路径确保了 Longhorn 卷的高可用性，即使某个副本或引擎出现问题，也不会影响所有副本或 Pod 对卷的访问。</font>

<font style="color:rgb(28, 30, 33);">Longhorn Engine 始终与使用 Longhorn 卷的 Pod 在同一节点中运行，它在存储在多个节点上的多个副本之间同步复制卷。</font>

<font style="color:rgb(28, 30, 33);">如下图所示，描述了 Longhorn 卷、Longhorn Engine、副本实例和磁盘之间的读/写数据流:</font>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761620987902-fc0549fd-f417-4b6f-8ddd-b6ef7af556fe.png)

+ <font style="color:rgb(28, 30, 33);">上图中有 3 个 Longhorn 卷实例</font>
+ <font style="color:rgb(28, 30, 33);">每个卷都有一个专用控制器，称为 Longhorn Engine，并作为 Linux 进程运行</font>
+ <font style="color:rgb(28, 30, 33);">每个 Longhorn 卷有两个副本，每个副本也是一个 Linux 进程</font>
+ <font style="color:rgb(28, 30, 33);">图中的箭头表示卷、控制器实例、副本实例和磁盘之间的读/写数据流</font>
+ <font style="color:rgb(28, 30, 33);">通过为每个卷创建单独的 Longhorn Engine，如果一个控制器发生故障，其他卷的功能不会受到影响</font>

<font style="color:rgb(68, 73, 80);">注意: 图中的 Engine 并非是单独的一个 Pod，而是每一个 Volume 会对应一个 golang exec 出来的 Linux 进程</font>

**<u><font style="color:#DF2A3F;">在 Longhorn 中，每个 Engine 只需要服务一个卷，简化了存储控制器的设计，由于控制器软件的故障域与单个卷隔离，因此控制器崩溃只会影响一个卷。</font></u>**<font style="color:rgb(28, 30, 33);">由于 Longhorn Engine 足够简单和轻便，因此我们可以创建多达 100000 个独立的 Engine，Kubernetes 去调度这些独立的 Engine，从一组共享的磁盘中提取资源，并与 Longhorn 合作形成一个弹性的分布式块存储系统。</font>

**<u><font style="color:#DF2A3F;">因为每个卷都有自己的控制器，所以每个卷的控制器和副本实例也可以升级，而不会导致 IO 操作明显中断。Longhorn 可以创建一个长时间运行的 job 任务来协调所有卷的升级，而不会中断系统的运行。</font></u>**

<font style="color:rgb(28, 30, 33);">Longhorn 是通过 CSI 驱动在 Kubernetes 中管理的，CSI 驱动通过调用 Longhorn 来创建卷，为 Kubernetes 工作负载创建持久性数据，CSI 插件可以让我们创建、删除、附加、分离、挂载卷，并对卷进行快照操作，Kubernetes 集群内部使用 CSI 接口与 Longhorn CSI 驱动进行通信，而 Longhorn CSI 驱动是通过使用 Longhorn API 与 Longhorn Manager 进行通信。</font>

<font style="color:rgb(28, 30, 33);">此外 Longhorn 还提供一个 UI 界面程序，</font>**<u><font style="color:#DF2A3F;">通过 Longhorn API 与 Longhorn Manager 进行交互，通过 Longhorn UI 可以管理快照、备份、节点和磁盘等，此外，集群工作节点的空间使用情况还可以通过 Longhorn UI 查看。</font></u>**

## <font style="color:rgb(28, 30, 33);">2 安装 Longhorn</font>
<font style="color:rgb(28, 30, 33);">要在 Kubernetes 集群上安装 Longhorn，需要集群的</font>**<u><font style="color:#DF2A3F;">每个节点</font></u>**<font style="color:rgb(28, 30, 33);">都必须满足以下要求：</font>

+ <font style="color:rgb(28, 30, 33);">与 Kubernetes 兼容的容器运行时（Docker v1.13+、containerd v1.3.7+ 等）</font>
+ <font style="color:rgb(28, 30, 33);">Kubernetes v1.18+</font>
+ <font style="color:rgb(28, 30, 33);">安装 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">open-iscsi</font>`<font style="color:rgb(28, 30, 33);">，并且 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">iscsid</font>`<font style="color:rgb(28, 30, 33);"> 守护程序在所有节点上运行，这是必要的，因为 Longhorn 依赖主机上的 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">iscsiadm</font>`<font style="color:rgb(28, 30, 33);"> 为 Kubernetes 提供持久卷</font>
+ <font style="color:rgb(28, 30, 33);">RWX 支持需要每个节点上都安装 NFSv4 客户端</font>
+ <font style="color:rgb(28, 30, 33);">宿主机文件系统支持 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">file extents</font>`<font style="color:rgb(28, 30, 33);"> 功能来存储数据，目前我们支持：ext4 与 XFS</font>
+ <font style="color:rgb(28, 30, 33);">bash、curl、findmnt、grep、awk、blkid、lsblk 等工具必须安装</font>
+ `<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">Mount propagation</font>`<font style="color:rgb(28, 30, 33);"> 必须启用，它允许将一个容器挂载的卷与同一 pod 中的其他容器共享，甚至可以与同一节点上的其他 pod 共享</font>

<font style="color:rgb(28, 30, 33);">Longhorn workloads 必须能够以 root 身份运行才能正确部署和操作 Longhorn。</font>

### <font style="color:rgb(28, 30, 33);">2.1 依赖</font>
<font style="color:rgb(28, 30, 33);">为了验证这些环境要求，Longhorn 官方提供了一个脚本来帮助我们进行检查，执行该脚本需要在本地安装 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">jq</font>`<font style="color:rgb(28, 30, 33);"> 工具，执行下面的命令即可运行脚本：</font>

```shell
➜ curl -sSfL https://raw.githubusercontent.com/longhorn/longhorn/v1.2.3/scripts/environment_check.sh | bash
daemonset.apps/longhorn-environment-check created
waiting for pods to become ready (0/2)
waiting for pods to become ready (0/2)
all pods ready (2/2)

  MountPropagation is enabled!

cleaning up...
daemonset.apps "longhorn-environment-check" deleted
clean up complete
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761622215559-09271ae0-f3a5-4f4f-ad38-48f167e52278.png)

<font style="color:rgb(28, 30, 33);">如果没有检查通过会给出相关的提示信息。</font>

<font style="color:rgb(28, 30, 33);">要安装 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">open-iscsi</font>`<font style="color:rgb(28, 30, 33);">，可以直接使用下面的命令即可：</font>

```shell
# apt-get install open-iscsi  # Debian 和 Ubuntu 系统命令
➜ yum install -y iscsi-initiator-utils
```

<font style="color:rgb(28, 30, 33);">Longhorn 官方还为我们还提供了一个 iscsi 安装程序，可以更轻松地自动安装 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">open-iscsi</font>`<font style="color:rgb(28, 30, 33);">：</font>

```shell
➜ kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.2.3/deploy/prerequisite/longhorn-iscsi-installation.yaml
```

<font style="color:rgb(28, 30, 33);">部署完成后，运行以下命令来检查安装程序的 Pod 状态：</font>

```shell
➜ kubectl get pod -l app=longhorn-iscsi-installation
NAME                                READY   STATUS    RESTARTS   AGE
longhorn-iscsi-installation-789rz   1/1     Running   0          90s
longhorn-iscsi-installation-qgnk7   1/1     Running   0          90s
longhorn-iscsi-installation-tqjz5   1/1     Running   0          90s
```

<font style="color:rgb(28, 30, 33);">也可以通过以下命令查看日志，查看安装结果：</font>

```shell
# 安装工具日志
➜ kubectl logs longhorn-iscsi-installation-tqjz5 -c iscsi-installation
[......]
Installed:
  iscsi-initiator-utils.x86_64 0:6.2.0.874-7.amzn2

Dependency Installed:
  iscsi-initiator-utils-iscsiuio.x86_64 0:6.2.0.874-7.amzn2

Complete!
Created symlink from /etc/systemd/system/multi-user.target.wants/iscsid.service to /usr/lib/systemd/system/iscsid.service.
iscsi install successfully

# 升级工具日志
➜ kubectl logs longhorn-iscsi-installation-tqjz5 -c iscsi-installation

Upgraded:
  iscsi-initiator-utils-6.2.1.4-8.git095f59c.el8.x86_64                         
  iscsi-initiator-utils-iscsiuio-6.2.1.4-8.git095f59c.el8.x86_64                

iscsi install successfully
```

<font style="color:rgb(28, 30, 33);">同样要安装 NFSv4 客户端，可以直接使用下面的命令一键安装：</font>

```shell
# apt-get install nfs-common  #  Debian 和 Ubuntu 系统命令
➜ yum install nfs-utils
```

<font style="color:rgb(28, 30, 33);">同样 Longhorn 官方也提供了一个 nfs 客户端安装程序，可以更轻松地自动安装 nfs-client：</font>

```shell
➜ kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.2.3/deploy/prerequisite/longhorn-nfs-installation.yaml
```

<font style="color:rgb(28, 30, 33);">部署完成后，运行以下命令来检查安装程序的 pod 状态：</font>

```shell
➜ kubectl get pod -l app=longhorn-nfs-installation
NAME                              READY   STATUS    RESTARTS   AGE
longhorn-nfs-installation-kdtm6   1/1     Running   0          3m10s
longhorn-nfs-installation-s2dcf   1/1     Running   0          3m10s
longhorn-nfs-installation-zjlcs   1/1     Running   0          3m10s
```

<font style="color:rgb(28, 30, 33);">也可以通过以下命令查看日志，查看安装结果：</font>

```shell
➜ kubectl logs longhorn-nfs-installation-s2dcf -c nfs-installation
[......]
nfs install successfully
```

<font style="color:rgb(28, 30, 33);">相关依赖环境准备好过后就可以开始安装 Longhorn 了。</font>

### <font style="color:rgb(28, 30, 33);">2.2 部署 Longhorn</font>
> Reference：[Longhorn安装部署完全指南：从零开始搭建存储系统-CSDN博客](https://blog.csdn.net/gitblog_00283/article/details/150911787)
>

<font style="color:rgb(28, 30, 33);">官方支持使用 Rancher Catalog 应用、kubectl 与 helm 三种方式来进行安装，同样这里我们选择使用 helm 进行安装。</font>

<font style="color:rgb(28, 30, 33);">首先添加 Longhorn 的 chart 仓库：</font>

```shell
➜ helm repo add longhorn https://charts.longhorn.io
➜ helm repo update
```

<font style="color:rgb(28, 30, 33);">然后可以根据自己的实际场景定制 values 文件，可以通过下面的命令获取默认的 values 文件：</font>

```shell
➜ curl -Lo values.yaml https://raw.githubusercontent.com/longhorn/charts/master/charts/longhorn/values.yaml
```

<font style="color:rgb(28, 30, 33);">然后可以修改 values 文件中的配置，</font>**<u><font style="color:rgb(28, 30, 33);">Longhorn 推荐单独挂盘作为存储使用，这里作为测试直接使用默认的 </font></u>**`**<u><font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">/var/lib/containerd/longhorn(mkdir -pv /var/lib/containerd/longhorn)</font></u>**`**<u><font style="color:rgb(28, 30, 33);"> 目录。</font></u>**

<font style="color:rgb(28, 30, 33);">如下所示默认配置的示例片段：</font>

```yaml
defaultSettings:
  backupTarget: s3://backupbucket@us-east-1/backupstore
  backupTargetCredentialSecret: minio-secret
  createDefaultDiskLabeledNodes: true
  defaultDataPath: /var/lib/containerd/longhorn
  replicaSoftAntiAffinity: false
  storageOverProvisioningPercentage: "600"
  storageMinimalAvailablePercentage: "15"
  upgradeChecker: false
  defaultReplicaCount: "2"
  defaultDataLocality: disabled
  guaranteedEngineCPU: # 新版本 Longhorn 已经取消了该配置
  defaultLonghornStaticStorageClass: longhorn-static-example
  backupstorePollInterval: "500"
  taintToleration: key1=value1:NoSchedule; key2:NoExecute
  systemManagedComponentsNodeSelector: 'storage-node:longhorn' # 配置节点标签
  priority-class: high-priority
  autoSalvage: false
  disableSchedulingOnCordonedNode: false
  replicaZoneSoftAntiAffinity: false
  volumeAttachmentRecoveryPolicy: never # 新版本 Longhorn 已经取消了该配置
  nodeDownPodDeletionPolicy: do-nothing
  mkfsExt4Parameters: -O ^64bit,^metadata_csum
  guaranteed-engine-manager-cpu: 15 # 新版本 Longhorn 已经取消了该配置
  guaranteed-replica-manager-cpu: 15 # 新版本 Longhorn 已经取消了该配置

ingress: # 开启ingress
  enabled: true
  ingressClassName: nginx # 配置 ingressclass
  host: longhorn.k8s.local
  annotations: # 添加annotations
    nginx.ingress.kubernetes.io/proxy-body-size: 10000m
    
enablePSP: false
persistence:
  defaultClass: true
  defaultFsType: ext4
  defaultClassReplicaCount: 3 # 配置成节点数
```

<font style="color:rgb(28, 30, 33);">然后执行下面的命令一键安装 Longhorn：</font>

```shell
➜ helm upgrade --install longhorn longhorn/longhorn \
  --namespace longhorn-system --create-namespace \
  -f values.yaml
Release "longhorn" does not exist. Installing it now.
NAME: longhorn
LAST DEPLOYED: Tue Oct 28 11:53:00 2025
NAMESPACE: longhorn-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
Longhorn is now installed on the cluster!

Please wait a few minutes for other Longhorn components such as CSI deployments, Engine Images, and Instance Managers to be initialized.

Visit our documentation at https://longhorn.io/docs/
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761623610780-321b47ce-652a-4caa-8b22-48eaaa413896.png)<font style="color:rgb(28, 30, 33);">部署后可以查看 Pod 的运行状态来确保安装正确：</font>

```shell
➜ kubectl label node hkk8smaster001 storage-node=longhorn
➜ kubectl label node hkk8snode001 storage-node=longhorn && kubectl label node hkk8snode002 storage-node=longhorn

➜ kubectl get pods -n longhorn-system
NAME                                        READY   STATUS    RESTARTS   AGE
csi-attacher-5f46994f7-fqntq                1/1     Running   0          33s
csi-attacher-5f46994f7-ltxg8                1/1     Running   0          36m
csi-attacher-5f46994f7-vw75d                1/1     Running   0          36m
csi-provisioner-6ccbfbf86f-bvc99            1/1     Running   0          33s
csi-provisioner-6ccbfbf86f-k46hn            1/1     Running   0          36m
csi-provisioner-6ccbfbf86f-lxm8h            1/1     Running   0          36m
csi-resizer-6dd8bd4c97-52gmm                1/1     Running   0          35m
csi-resizer-6dd8bd4c97-9btj6                1/1     Running   0          3s
csi-resizer-6dd8bd4c97-fdjmp                1/1     Running   0          35m
csi-snapshotter-86f65d8bc-5mjk2             1/1     Running   0          33s
csi-snapshotter-86f65d8bc-5rrfs             1/1     Running   0          35m
csi-snapshotter-86f65d8bc-bg6nv             1/1     Running   0          35m
engine-image-ei-fa2dfbf0-jrb2d              1/1     Running   0          36m
engine-image-ei-fa2dfbf0-m5799              1/1     Running   0          36m
instance-manager-e-051171e6                 1/1     Running   0          36m
instance-manager-e-db94b4b7                 1/1     Running   0          24m
instance-manager-r-dd84ad5c                 1/1     Running   0          36m
instance-manager-r-f5eefb8a                 1/1     Running   0          24m
longhorn-csi-plugin-mljt2                   2/2     Running   0          35m
longhorn-csi-plugin-rfzcj                   2/2     Running   0          24m
longhorn-driver-deployer-6db849975f-dh4p4   1/1     Running   0          58m
longhorn-manager-bxks6                      1/1     Running   0          24m
longhorn-manager-tj58k                      1/1     Running   0          2m50s
longhorn-ui-6f547c964-k56xr                 1/1     Running   0          58m
```

<font style="color:rgb(28, 30, 33);">上面是部署完成后运行的 Pod，这里可以对这些工作负载做一个简单的说明：</font>

+ `<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">csi-attacher-xxx</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">csi-provisioner-xxx</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">csi-resizer-xxx</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">csi-snapshotter-xxx</font>`<font style="color:rgb(28, 30, 33);"> 是 csi 原生的组件</font>
+ `<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">longhorn-manager-xxx</font>`<font style="color:rgb(28, 30, 33);"> 是运行在每个节点上的 Longhorn Manager，是一个控制器，也为 Longhorn UI 或者 CSI 插件提供 API，主要功能是通过修改 Kubernetes CRD 来触发控制循环，比如 volume attach/detach 操作</font>
+ `<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">longhorn-ui-xxx</font>`<font style="color:rgb(28, 30, 33);"> 提供 Longhorn UI 服务，提供一个可视化的控制页面</font>
+ <font style="color:rgb(28, 30, 33);">Longhorn Engine 数据平面，提供两种工作模式：Engine Mode（</font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">instance-manager-e-xxx</font>`<font style="color:rgb(28, 30, 33);"> 的 Pod）、Replica Mode（</font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">instance-manager-r-xxx</font>`<font style="color:rgb(28, 30, 33);"> 的 Pod），Replica 负责实际数据的写入，每个副本包含数据的完整副本，Engine 连接到副本实现 volume 的数据平面，任何写操作都会同步到所有副本，读操作从任意一个副本读取数据</font>

<font style="color:rgb(28, 30, 33);">由于上面安装的时候我们添加了 Ingress 支持，所以可以通过配置的域名去访问 Longhorn UI：</font>

```shell
➜ kubectl get ingress  -n longhorn-system
NAME               CLASS   HOSTS                ADDRESS         PORTS   AGE
longhorn-ingress   nginx   longhorn.k8s.local   192.168.178.35   80      4m11s
```

<font style="color:rgb(28, 30, 33);">这里我们使用的 ingress-nginx 这个控制器，安装完成后在浏览器中直接访问</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);background-color:rgb(246, 247, 248);">http://longhorn.k8s.local</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">即可，Longhorn UI 界面中展示了当前存储系统的状态。</font>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761620987889-837990e8-8529-47bb-bfce-4b08f68ab715.png)

<font style="color:rgb(28, 30, 33);">关于存储的几种状态：</font>

+ `<font style="color:rgb(28, 30, 33);background-color:rgb(246, 247, 248);">Schedulable</font>`<font style="color:rgb(28, 30, 33);">: 可用于 Longhorn 卷调度的实际空间(actual space)</font>
+ `<font style="color:rgb(28, 30, 33);background-color:rgb(246, 247, 248);">Reserved</font>`<font style="color:rgb(28, 30, 33);">: 为其他应用程序和系统保留的空间(space reserved)</font>
+ `<font style="color:rgb(28, 30, 33);background-color:rgb(246, 247, 248);">Used</font>`<font style="color:rgb(28, 30, 33);">: Longhorn、系统和其他应用程序已使用的实际空间(space reserved)</font>
+ `<font style="color:rgb(28, 30, 33);background-color:rgb(246, 247, 248);">Disabled</font>`<font style="color:rgb(28, 30, 33);">: 不允许调度 Longhorn 卷的磁盘/节点的总空间</font>

<font style="color:rgb(28, 30, 33);">在 Node 页面，Longhorn 会显示每个节点的空间分配、调度和使用信息：</font>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761620987918-14a5c738-0cf4-461d-9e7f-547063ddc8e1.png)

+ <font style="color:rgb(28, 30, 33);">Size 列：Longhorn 卷可以使用的最大实际可用空间，它等于节点的总磁盘空间减去保留空间。</font>
+ <font style="color:rgb(28, 30, 33);">Allocated 列：左边的数字是</font>**<font style="color:rgb(28, 30, 33);">卷调度(volume scheduling)</font>**<font style="color:rgb(28, 30, 33);">已使用的大小，并不代表该空间已被用于 Longhorn 卷数据存储。正确的数字是卷调度的 max 大小，它是 Size 乘以 Storage Over Provisioning Percentage 的结果，因此，这两个数字之间的差异（我们称之为可分配空间 allocable space）决定了卷副本是否可以调度到这个节点。</font>
+ <font style="color:rgb(28, 30, 33);">Used 列：左边部分表示该节点当前使用的空间，整个条形表示节点的总空间。</font>

<font style="color:rgb(28, 30, 33);">此外还会创建一个默认的 StorageClass 对象：</font>

```shell
➜ kubectl get sc longhorn
NAME                 PROVISIONER          RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
longhorn (default)   driver.longhorn.io   Delete          Immediate           true                   91m
➜ kubectl get sc longhorn -o yaml
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  annotations:
    ......
    storageclass.kubernetes.io/is-default-class: "true"
  creationTimestamp: "2022-02-20T09:32:51Z"
  ......
  name: longhorn
  resourceVersion: "4524911"
  uid: 6066e858-e7ab-4dab-95db-7ff829e6e01b
parameters:
  fromBackup: ""
  fsType: ext4
  numberOfReplicas: "3"
  staleReplicaTimeout: "30"
provisioner: driver.longhorn.io
reclaimPolicy: Delete
volumeBindingMode: Immediate
```

## <font style="color:rgb(28, 30, 33);">3 测试 Longhorn</font>
<font style="color:rgb(28, 30, 33);">下面我们来测试使用 longhorn 提供一个存储卷，由于提供了默认的 StorageClass，所以直接创建 PVC 即可，创建一个如下所示的 PVC：</font>

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
spec:
  storageClassName: longhorn
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

<font style="color:rgb(28, 30, 33);">然后部署一个 mysql 应用来使用上面的 PVC 进行数据持久化：</font>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
spec:
  selector:
    matchLabels:
      app: mysql
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
        - image: mysql:5.6
          name: mysql
          env:
            - name: MYSQL_ROOT_PASSWORD
              value: password
          ports:
            - containerPort: 3306
              name: mysql
          volumeMounts:
            - name: data
              mountPath: /var/lib/mysql
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: mysql-pvc
```

<font style="color:rgb(28, 30, 33);">直接创建上面的资源对象：</font>

```shell
➜ kubectl get pvc mysql-pvc
NAME        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
mysql-pvc   Bound    pvc-ec17a7e4-7bb4-4456-9380-353db3ed4307   1Gi        RWO            longhorn       8s
➜ kubectl get pods
NAME                     READY   STATUS    RESTARTS      AGE
mysql-6879698bd4-r8cxz   1/1     Running   0             3m10s
➜ kubectl exec -it mysql-6879698bd4-r8cxz -- mysql -uroot -ppassword
Warning: Using a password on the command line interface can be insecure.
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 1
Server version: 5.6.51 MySQL Community Server (GPL)

Copyright (c) 2000, 2021, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> create database longhorn;
Query OK, 1 row affected (0.01 sec)

mysql>
```

<font style="color:rgb(28, 30, 33);">应用启动成功后我们可以去节点上查看数据来验证是否成功：</font>

```shell
➜ ls /var/lib/longhorn/
engine-binaries  longhorn-disk.cfg  replicas
➜ ls /var/lib/longhorn/replicas/
pvc-ec17a7e4-7bb4-4456-9380-353db3ed4307-c40376c5
➜ ls /var/lib/longhorn/replicas/pvc-ec17a7e4-7bb4-4456-9380-353db3ed4307-c40376c5
revision.counter  volume-head-000.img  volume-head-000.img.meta  volume.meta
```

<font style="color:rgb(28, 30, 33);">需要注意的是 longhorn 是分布式块存储，与分布式文件系统不同，不能超过 pv 设置的存储大小（上例中为 1G）。我们在数据库中创建了一个名为</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);background-color:rgb(246, 247, 248);">longhorn</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">的数据库，然后我们重建 Pod 再次查看数据是否依然存在：</font>

```shell
➜ kubectl get pods
NAME                     READY   STATUS    RESTARTS      AGE
mysql-6879698bd4-s8tfv   1/1     Running   0             6s
➜ kubectl exec -it mysql-6879698bd4-s8tfv -- mysql -uroot -ppassword
Warning: Using a password on the command line interface can be insecure.
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 1
Server version: 5.6.51 MySQL Community Server (GPL)

Copyright (c) 2000, 2021, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> show databases;
+---------------------+
| Database            |
+---------------------+
| information_schema  |
| longhorn            |
| #mysql50#lost+found |
| mysql               |
| performance_schema  |
+---------------------+
5 rows in set (0.00 sec)

mysql>
```

<font style="color:rgb(28, 30, 33);">可以看到前面创建的数据库依然存在，证明我们的数据持久化成功了。在 Longhorn UI 界面中也可以看到数据卷的信息：</font>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761620987861-fb389002-ea6b-4b0c-b354-84b6b45c3bb1.png)

## <font style="color:rgb(28, 30, 33);">4 Longhorn 备份恢复</font>
<font style="color:rgb(28, 30, 33);">Longhorn 提供了备份恢复功能，要使用这个功能我们需要给卷创建一个</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);background-color:rgb(246, 247, 248);">snapshot</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">快照，快照是 Kubernetes Volume 在任何指定时间点的状态。</font>

<font style="color:rgb(28, 30, 33);">在 Longhorn UI 的 Volume 页面中点击要创建快照的卷，进入卷的详细信息页面，点击下方的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);background-color:rgb(246, 247, 248);">Take Snapshot</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">按钮即可创建快照了，创建快照后，将在卷头(Volume Head)之前的快照列表中可以看到它，比如这里我们会前面测试使用的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);background-color:rgb(246, 247, 248);">mysql</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">卷创建一个快照：</font>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761620987665-d4ff8582-fcb8-4796-ba3b-0251591cf77e.png)

<font style="color:rgb(28, 30, 33);">同样在节点的数据目录下面也可以看到创建的快照数据：</font>

```shell
➜ tree /var/lib/longhorn/replicas/pvc-ec17a7e4-7bb4-4456-9380-353db3ed4307-fbf72396/
/var/lib/longhorn/replicas/pvc-ec17a7e4-7bb4-4456-9380-353db3ed4307-fbf72396/
├── revision.counter
├── volume-head-002.img
├── volume-head-002.img.meta
├── volume.meta
├── volume-snap-3b1f877b-24ba-44ec-808e-ab8d4b15f8dd.img
├── volume-snap-3b1f877b-24ba-44ec-808e-ab8d4b15f8dd.img.meta
├── volume-snap-5d403e8e-65e8-46d1-aa54-70aa3280dac4.img
└── volume-snap-5d403e8e-65e8-46d1-aa54-70aa3280dac4.img.meta

0 directories, 8 files
```

<font style="color:rgb(28, 30, 33);">其中的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);background-color:rgb(246, 247, 248);">volume-snap-xxx</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">后面的数据和页面上的快照名称是一致的，比如页面中我们刚刚创建的快照名称为</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);background-color:rgb(246, 247, 248);">3b1f877b-24ba-44ec-808e-ab8d4b15f8dd</font>`<font style="color:rgb(28, 30, 33);">，其中的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);background-color:rgb(246, 247, 248);">img</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">文件是镜像文件，而</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);background-color:rgb(246, 247, 248);">img.meta</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">是保存当前快照的元信息：</font>

```shell
➜ cat volume-snap-3b1f877b-24ba-44ec-808e-ab8d4b15f8dd.img.meta
{"Name":"volume-head-001.img","Parent":"volume-snap-5d403e8e-65e8-46d1-aa54-70aa3280dac4.img","Removed":false,"UserCreated":true,"Created":"2022-02-22T07:36:48Z","Labels":null}
```

<font style="color:rgb(28, 30, 33);">元信息里面包含父级的文件镜像，这其实表明快照是增量的快照。</font>

<font style="color:rgb(28, 30, 33);">此外除了手动创建快照之外，从 Longhorn UI 上还可以进行周期性快照和备份，同样在卷的详细页面可以进行配置，在</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);background-color:rgb(246, 247, 248);">Recurring Jobs Schedule</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">区域点击</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);background-color:rgb(246, 247, 248);">Add</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">按钮即可创建一个定时的快照。</font>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761620988825-02d75481-aea4-42d5-b914-573d8f3dad8e.png)

<font style="color:rgb(28, 30, 33);">创建任务的时候可以选择任务类型是备份(backup)或快照(snapshot)，任务的时间以 CRON 表达式的形式进行配置，还可以配置要保留的备份或快照数量以及标签。</font>

<font style="color:rgb(28, 30, 33);">为了避免当卷长时间没有新数据时，</font>`<font style="color:rgb(28, 30, 33);background-color:rgb(246, 247, 248);">recurring jobs</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">可能会用相同的备份和空快照覆盖旧的备份/快照的问题，Longhorn 执行以下操作：</font>

+ `<font style="color:rgb(28, 30, 33);background-color:rgb(246, 247, 248);">Recurring backup job</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">仅在自上次备份以来卷有新数据时才进行新备份</font>
+ `<font style="color:rgb(28, 30, 33);background-color:rgb(246, 247, 248);">Recurring snapshot job</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">仅在卷头(volume head)中有新数据时才拍摄新快照</font>

<font style="color:rgb(28, 30, 33);">此外我们还可以通过使用 Kubernetes 的 StorageClass 来配置定时快照，可以通过 StorageClass 的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);background-color:rgb(246, 247, 248);">recurringJobs</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">参数配置定时备份和快照，</font>`<font style="color:rgb(28, 30, 33);background-color:rgb(246, 247, 248);">recurringJobs</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">字段应遵循以下 JSON 格式：</font>

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn
provisioner: driver.longhorn.io
parameters:
  numberOfReplicas: "3"
  staleReplicaTimeout: "30"
  fromBackup: ""
  recurringJobs: '[
    {
      "name":"snap",
      "task":"snapshot",
      "cron":"*/1 * * * *",
      "retain":1
    },
    {
      "name":"backup",
      "task":"backup",
      "cron":"*/2 * * * *",
      "retain":1
    }
  ]'
```

<font style="color:rgb(28, 30, 33);">应为每个 recurring job 指定以下参数：</font>

+ <font style="color:rgb(28, 30, 33);">name：认为的名称，不要在一个 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">recurringJobs</font>`<font style="color:rgb(28, 30, 33);"> 中使用重复的名称，并且 name 的长度不能超过 8 个字符</font>
+ <font style="color:rgb(28, 30, 33);">task：任务的类型，它仅支持 snapshot 或 backup</font>
+ <font style="color:rgb(28, 30, 33);">cron：Cron 表达式，指定任务的执行时间</font>
+ <font style="color:rgb(28, 30, 33);">retain：Longhorn 将为一项任务保留多少快照/备份，不少于 1</font>

<font style="color:rgb(28, 30, 33);">使用这个 StorageClass 创建的任何卷都将自动配置上这些</font><font style="color:#DF2A3F;"> </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">recurring jobs</font>`<font style="color:rgb(28, 30, 33);">。</font>

<font style="color:rgb(28, 30, 33);">要备份卷就需要在 Longhorn 中配置一个备份目标，可以是一个 NFS 服务或者 S3 兼容的对象存储服务，用于存储 Longhorn 卷的备份数据，备份目标可以在 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">Settings/General/BackupTarget</font>`<font style="color:rgb(28, 30, 33);"> 中配置，我们这里使用 Helm Chart 安装的，最好的方式是去定制 values 文件中的 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">defaultSettings.backupTarget</font>`<font style="color:rgb(28, 30, 33);">，当然也可以直接去通过 Longhorn UI 进行配置，比如这里我们先配置备份目标为 nfs 服务，</font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">Backup Target</font>`<font style="color:rgb(28, 30, 33);"> 值设置为 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">nfs://192.168.178.35:/var/lib/k8s/data</font>`<font style="color:rgb(28, 30, 33);">（要确保目录存在），</font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">Backup Target Credential Secret</font>`<font style="color:rgb(28, 30, 33);"> 留空即可，然后拉到最下面点击 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">Save</font>`<font style="color:rgb(28, 30, 33);">：</font>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761620989102-b78179cc-646a-4883-bbf9-320b3bc82114.png)

<font style="color:rgb(28, 30, 33);">备份目标配置后，就可以开始备份了，同样导航到 Longhorn UI 的 Volume 页面，选择要备份的卷，点击 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">Create Backup</font>`<font style="color:rgb(28, 30, 33);">，然后添加合适的标签点击 OK 即可。</font>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761620988941-fe2e3805-25b2-41d3-865f-73c1f4745236.png)

<font style="color:rgb(28, 30, 33);">备份完成后导航到 Backup 页面就可以看到对应的备份数据了：</font>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761620988983-efe1d967-3bfa-48fe-960f-2a2bf345682f.png)

<font style="color:rgb(28, 30, 33);">这些备份的数据也会对应一个 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">backupvolumes</font>`<font style="color:rgb(28, 30, 33);"> crd 对象：</font>

```shell
➜ kubectl get backupvolumes -n longhorn-system
NAME                                       CREATEDAT              LASTBACKUPNAME            LASTBACKUPAT           LASTSYNCEDAT
pvc-ec17a7e4-7bb4-4456-9380-353db3ed4307   2022-02-22T09:23:24Z   backup-8ae4af9c49534859   2022-02-22T09:23:24Z   2022-02-22T09:41:09Z
```

<font style="color:rgb(28, 30, 33);">然后我们去到 NFS 服务器上查看会在挂载目录下面创建一个 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">backupstore</font>`<font style="color:rgb(28, 30, 33);"> 目录，下面会保留我们备份的数据：</font>

```shell
➜ tree /var/lib/k8s/data/backupstore
/var/lib/k8s/data/backupstore
└── volumes
    └── 5e
        └── b6
            └── pvc-ec17a7e4-7bb4-4456-9380-353db3ed4307
                ├── backups
                │   └── backup_backup-8ae4af9c49534859.cfg
                ├── blocks
                │   ├── 02
                │   │   └── 2e
                │   │       └── 022eefc6526cd3d8fc3a9f9a4ba253a910c61a1c430a807403f60a2f233fa210.blk
                ......
                │   └── f7
                │       └── e3
                │           └── f7e3ae1f83e10da4ece5142abac1fafc0d0917370f7418874c151a66a18bfa15.blk
                └── volume.cfg

51 directories, 25 files
```

<font style="color:rgb(28, 30, 33);">同样这个时候我们也可以去快照列表选择要备份的快照：</font>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761620989091-003f8cd0-6a94-4432-9377-1c28bde895f5.png)

<font style="color:rgb(28, 30, 33);">有了备份数据后要想要恢复数据，只需要选择对应的备份数据，点击 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">Restore Latest Backup</font>`<font style="color:rgb(28, 30, 33);"> 恢复数据即可：</font>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761620989884-9f8e9837-1eaa-401e-8c3a-9f879da17712.png)

## <font style="color:rgb(28, 30, 33);">5 ReadWriteMany</font>
<font style="color:rgb(28, 30, 33);">Longhorn 可以通过 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">NFSv4</font>`<font style="color:rgb(28, 30, 33);"> 服务器暴露 Longhorn 卷，原生支持 RWX 工作负载，使用的 RWX 卷 会在 longhorn-system 命名空间下面创建一个 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">share-manager-<volume-name></font>`<font style="color:rgb(28, 30, 33);"> 的 Pod，该 Pod 负责通过在 Pod 内运行的 NFSv4 服务器暴露 Longhorn 卷。</font>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761620989873-41737910-50fa-42fe-9256-638eb04317f8.png)

<font style="color:rgb(28, 30, 33);">要能够使用 RWX 卷，每个客户端节点都需要安装 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">NFSv4</font>`<font style="color:rgb(28, 30, 33);"> 客户端，对于 Ubuntu，可以通过以下方式安装 NFSv4 客户端：</font>

```shell
➜ apt install nfs-common
```

<font style="color:rgb(28, 30, 33);">对于基于 RPM 的发行版，可以通过以下方式安装 NFSv4 客户端：</font>

```shell
➜ yum install nfs-utils
```

<font style="color:rgb(28, 30, 33);">现在我们来创建一个如下所示的 PVC 对象，访问模式配置为 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">ReadWriteMany</font>`<font style="color:rgb(28, 30, 33);">：</font>

```yaml
# html-vol.yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: html
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: longhorn
  resources:
    requests:
      storage: 1Gi
```

<font style="color:rgb(28, 30, 33);">直接创建上面的资源对象就会动态创建一个 PV 与之绑定：</font>

```shell
➜ kubectl get pvc html
NAME   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
html   Bound    pvc-a03c5f7d-d4ca-43e9-aa4a-fb3b5eb5cf15   1Gi        RWX            longhorn       15s
➜ kubectl get pv pvc-a03c5f7d-d4ca-43e9-aa4a-fb3b5eb5cf15
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM          STORAGECLASS   REASON   AGE
pvc-a03c5f7d-d4ca-43e9-aa4a-fb3b5eb5cf15   1Gi        RWX            Delete           Bound    default/html   longhorn                63s
```

<font style="color:rgb(28, 30, 33);">然后创建一个如下所示的名为 writer 的 Deployment 资源对象，使用上面创建的 PVC 来持久化数据：</font>

```yaml
# html-writer.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: writer
spec:
  selector:
    matchLabels:
      app: writer
  template:
    metadata:
      labels:
        app: writer
    spec:
      containers:
        - name: content
          image: alpine:latest
          volumeMounts:
            - name: html
              mountPath: /html
          command: ['/bin/sh', '-c']
          args:
            - while true; do
              date >> /html/index.html;
              sleep 5;
              done
      volumes:
        - name: html
          persistentVolumeClaim:
            claimName: html
```

<font style="color:rgb(28, 30, 33);">部署后上面创建的 Longhorn 的卷就变成 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">Attached</font>`<font style="color:rgb(28, 30, 33);"> 状态了：</font>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761620989697-c4202f76-ef24-44c3-a953-a8dced59a346.png)

<font style="color:rgb(28, 30, 33);">并且这个时候会自动启动一个 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">share-manager</font>`<font style="color:rgb(28, 30, 33);"> 的 Pod，通过该 Pod 内运行的 NFSv4 服务器来暴露 Longhorn 卷：</font>

```shell
➜ kubectl get pods -n longhorn-system -l longhorn.io/component=share-manager
NAME                                                     READY   STATUS    RESTARTS   AGE
share-manager-pvc-a03c5f7d-d4ca-43e9-aa4a-fb3b5eb5cf15   1/1     Running   0          2m16s
➜ kubectl logs -f share-manager-pvc-a03c5f7d-d4ca-43e9-aa4a-fb3b5eb5cf15 -n longhorn-system
time="2022-02-22T10:07:42Z" level=info msg="starting RLIMIT_NOFILE rlimit.Cur 1048576, rlimit.Max 1048576"
time="2022-02-22T10:07:42Z" level=info msg="ending RLIMIT_NOFILE rlimit.Cur 1048576, rlimit.Max 1048576"
time="2022-02-22T10:07:42Z" level=debug msg="volume pvc-a03c5f7d-d4ca-43e9-aa4a-fb3b5eb5cf15 device /dev/longhorn/pvc-a03c5f7d-d4ca-43e9-aa4a-fb3b5eb5cf15 contains filesystem of format " encrypted=false volume=pvc-a03c5f7d-d4ca-43e9-aa4a-fb3b5eb5cf15
I0222 10:07:42.432630       1 mount_linux.go:425] Disk "/dev/longhorn/pvc-a03c5f7d-d4ca-43e9-aa4a-fb3b5eb5cf15" appears to be unformatted, attempting to format as type: "ext4" with options: [-F -m0 /dev/longhorn/pvc-a03c5f7d-d4ca-43e9-aa4a-fb3b5eb5cf15]
I0222 10:07:42.981928       1 mount_linux.go:435] Disk successfully formatted (mkfs): ext4 - /dev/longhorn/pvc-a03c5f7d-d4ca-43e9-aa4a-fb3b5eb5cf15 /export/pvc-a03c5f7d-d4ca-43e9-aa4a-fb3b5eb5cf15
time="2022-02-22T10:07:43Z" level=info msg="starting nfs server, volume is ready for export" encrypted=false volume=pvc-a03c5f7d-d4ca-43e9-aa4a-fb3b5eb5cf15
time="2022-02-22T10:07:43Z" level=info msg="Running NFS server!"
time="2022-02-22T10:07:43Z" level=info msg="starting health check for volume" encrypted=false volume=pvc-a03c5f7d-d4ca-43e9-aa4a-fb3b5eb5cf15
```

<font style="color:rgb(28, 30, 33);">然后我们再创建一个如下所示的 Deployment：</font>

```yaml
# html-reader.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reader
spec:
  replicas: 3
  selector:
    matchLabels:
      app: reader
  template:
    metadata:
      labels:
        app: reader
    spec:
      containers:
        - name: nginx
          image: nginx:stable-alpine
          ports:
            - containerPort: 80
          volumeMounts:
            - name: html
              mountPath: /usr/share/nginx/html
      volumes:
        - name: html
          persistentVolumeClaim:
            claimName: html
---
apiVersion: v1
kind: Service
metadata:
  name: reader
spec:
  selector:
    app: reader
  type: NodePort
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

<font style="color:rgb(28, 30, 33);">上面的 reader Pods 可以引用 writer Pod 相同的 PVC，是因为上面我们创建的 PV 和 PVC 是 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">ReadWriteMany</font>`<font style="color:rgb(28, 30, 33);"> 访问模式，直接创建上面的资源对象，我们可以通过 NodePort 来访问应用：</font>

```shell
➜ kubectl get pods -l app=reader
NAME                     READY   STATUS    RESTARTS   AGE
reader-b54c4749d-4bjxf   1/1     Running   0          11s
reader-b54c4749d-5thwz   1/1     Running   0          4m11s
reader-b54c4749d-drcfk   1/1     Running   0          5m35s
➜ kubectl get svc reader
NAME     TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
reader   NodePort   10.101.54.19   <none>        80:31800/TCP   84s
➜ curl http://192.168.178.35:31800
......
Tue Feb 22 10:18:39 UTC 2022
Tue Feb 22 10:18:44 UTC 2022
Tue Feb 22 10:18:49 UTC 2022
Tue Feb 22 10:18:54 UTC 2022
Tue Feb 22 10:18:59 UTC 2022
......
```

<font style="color:rgb(28, 30, 33);">现在我们尝试从一个 reader Pod 中去产生一些数据，然后再去访问应用验证数据是否正确：</font>

```shell
➜ kubectl exec reader-b54c4749d-4bjxf-- /bin/sh -c "echo longhorn rwx access mode >> /usr/share/nginx/html/index.html"
➜ curl http://192.168.178.35:31800
......
Tue Feb 22 10:23:49 UTC 2022
longhorn rwx access mode
```

<font style="color:rgb(28, 30, 33);">这里我们就验证了在 Longhorn 中使用 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">ReadWriteMany</font>`<font style="color:rgb(28, 30, 33);"> 访问模式的 Volume 卷。</font>

## <font style="color:rgb(28, 30, 33);">6 CSI 卷管理</font>
<font style="color:rgb(28, 30, 33);">上面我们提到了通过 Longhorn UI 可以对卷进行快照、备份恢复等功能，此外我们还可以通过 Kubernetes 来实现对卷的管理，比如可以在集群上启用 CSI 快照和克隆支持。</font>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761620989981-76666a24-b440-4e14-b53d-4af208138219.png)

### <font style="color:rgb(28, 30, 33);">6.1 CSI 卷快照</font>
<font style="color:rgb(28, 30, 33);">Kubernetes 从 1.12 版本开始引入了存储卷快照功能，在 1.17 版本进入 Beta 版本，和 PV、PVC 两个资源对象类似，Kubernetes 提供了 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotContent</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshot</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotClass</font>`<font style="color:rgb(28, 30, 33);"> 三个资源对象用于卷快照管理。</font>

#### <font style="color:rgb(28, 30, 33);">6.1.1 概念</font>
`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotContent</font>`<font style="color:rgb(28, 30, 33);"> 是基于某个 PV 创建的快照，类似于 PV 的资源概念；</font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshot</font>`<font style="color:rgb(28, 30, 33);"> 是用户对卷快照的请求，类似于持久化声明 PVC 的概念；</font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotClass</font>`<font style="color:rgb(28, 30, 33);"> 对象可以来设置快照的特性，屏蔽 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotContent</font>`<font style="color:rgb(28, 30, 33);"> 的细节，为 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshot</font>`<font style="color:rgb(28, 30, 33);"> 绑定提供动态管理，就像 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">StorageClass</font>`<font style="color:rgb(28, 30, 33);"> 的“类”概念。</font>

<font style="color:rgb(28, 30, 33);">卷快照能力为 Kubernetes 用户提供了一种标准的方式来在指定时间点复制卷的内容，并且不需要创建全新的卷，比如数据库管理员可以在执行编辑或删除之类的修改之前对数据库执行备份。</font>

<font style="color:rgb(28, 30, 33);">但是在使用该功能时，需要注意以下几点：</font>

+ `<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshot</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotContent</font>`<font style="color:rgb(28, 30, 33);"> 和 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotClass</font>`<font style="color:rgb(28, 30, 33);"> 资源对象是 CRDs， 不属于核心 API。</font>
+ `<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshot</font>`<font style="color:rgb(28, 30, 33);"> 支持仅可用于 CSI 驱动。</font>
+ <font style="color:rgb(28, 30, 33);">作为 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshot</font>`<font style="color:rgb(28, 30, 33);"> 部署过程的一部分，Kubernetes 团队提供了一个部署于控制平面的快照控制器，并且提供了一个叫做 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">csi-snapshotter</font>`<font style="color:rgb(28, 30, 33);"> 的 Sidecar 容器，和 CSI 驱动程序一起部署，快照控制器会去监听 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshot</font>`<font style="color:rgb(28, 30, 33);"> 和 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotContent</font>`<font style="color:rgb(28, 30, 33);"> 对象，并且负责创建和删除 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotContent</font>`<font style="color:rgb(28, 30, 33);"> 对象。 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">csi-snapshotter</font>`<font style="color:rgb(28, 30, 33);"> 监听 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotContent</font>`<font style="color:rgb(28, 30, 33);"> 对象，并且触发针对 CSI 端点的 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">CreateSnapshot</font>`<font style="color:rgb(28, 30, 33);"> 和 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">DeleteSnapshot</font>`<font style="color:rgb(28, 30, 33);"> 的操作，完成快照的创建或删除。</font>
+ <font style="color:rgb(28, 30, 33);">CSI 驱动可能实现，也可能没有实现卷快照功能，CSI 驱动可能会使用 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">csi-snapshotter</font>`<font style="color:rgb(28, 30, 33);"> 来提供对卷快照的支持，详见 </font>[<font style="color:rgb(33, 96, 253);">CSI 驱动程序文档</font>](https://kubernetes-csi.github.io/docs/external-snapshotter.html)<font style="color:rgb(28, 30, 33);">。</font>

`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotContents</font>`<font style="color:rgb(28, 30, 33);"> 和 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshots</font>`<font style="color:rgb(28, 30, 33);"> 的生命周期包括资源供应、资源绑定、对使用 PVC 的保护机制和资源删除等各个阶段，这两个对象会遵循这些生命周期。</font>

**<font style="color:rgb(28, 30, 33);">资源供应</font>**<font style="color:rgb(28, 30, 33);">：与 PV 的资源供应类似，</font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotContent</font>`<font style="color:rgb(28, 30, 33);"> 也可以以静态或动态两种方式供应资源。</font>

+ <font style="color:rgb(28, 30, 33);">静态供应：集群管理员会预先创建好一组 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotContent</font>`<font style="color:rgb(28, 30, 33);"> 资源，类似于手动创建 PV</font>
+ <font style="color:rgb(28, 30, 33);">动态供应：基于 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotClass</font>`<font style="color:rgb(28, 30, 33);"> 资源，当用户创建 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshot</font>`<font style="color:rgb(28, 30, 33);"> 申请时自动创建 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotContent</font>`<font style="color:rgb(28, 30, 33);">，类似于 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">StorageClass</font>`<font style="color:rgb(28, 30, 33);"> 动态创建 PV</font>

**<font style="color:rgb(28, 30, 33);">资源绑定</font>**<font style="color:rgb(28, 30, 33);">：快照控制器负责将 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshot</font>`<font style="color:rgb(28, 30, 33);"> 与一个合适的 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotContent</font>`<font style="color:rgb(28, 30, 33);"> 进行绑定，包括静态和动态供应两种情况，</font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshot</font>`<font style="color:rgb(28, 30, 33);"> 和 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotContent</font>`<font style="color:rgb(28, 30, 33);"> 之间也是一对一进行绑定的，不会存在一对多的情况。</font>

**<font style="color:rgb(28, 30, 33);">对使用中的 PVC 的保护机制</font>**<font style="color:rgb(28, 30, 33);">：当存储快照 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshot</font>`<font style="color:rgb(28, 30, 33);"> 正在被创建且还未完成时，相关的 PVC 将会被标记为</font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">正被使用中</font>`<font style="color:rgb(28, 30, 33);">，如果用户对 PVC 进行删除操作，系统不会立即删除 PVC，以避免快照还未做完造成数据丢失，删除操作会延迟到 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshot</font>`<font style="color:rgb(28, 30, 33);"> 创建完成（</font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">readyToUse</font>`<font style="color:rgb(28, 30, 33);"> 状态）或被终止（</font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">aborted</font>`<font style="color:rgb(28, 30, 33);"> 状态）的情况下完成。</font>

**<font style="color:rgb(28, 30, 33);">资源删除</font>**<font style="color:rgb(28, 30, 33);">：对 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshot</font>`<font style="color:rgb(28, 30, 33);"> 发起删除操作时，对与其绑定的后端 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotContent</font>`<font style="color:rgb(28, 30, 33);"> 的删除操作将基于删除策略 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">DeletionPolicy</font>`<font style="color:rgb(28, 30, 33);"> 的设置来决定，可以配置的删除策略有：</font>

+ `<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">Delete</font>`<font style="color:rgb(28, 30, 33);">：自动删除 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotContent</font>`<font style="color:rgb(28, 30, 33);"> 资源对象和快照的内容。</font>
+ `<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">Retain</font>`<font style="color:rgb(28, 30, 33);">：</font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotContent</font>`<font style="color:rgb(28, 30, 33);"> 资源对象和快照的内容都将保留，需要手动清理。</font>

<font style="color:rgb(28, 30, 33);">我们这里的 Longhorn 系统在部署完成后创建了 3 个 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">csi-snapshotter</font>`<font style="color:rgb(28, 30, 33);"> 的 Pod：</font>

```shell
➜ kubectl get pods -n longhorn-system
NAME                                                     READY   STATUS      RESTARTS       AGE
csi-snapshotter-86f65d8bc-9t7dd                          1/1     Running     5 (126m ago)   2d17h
csi-snapshotter-86f65d8bc-d6xbj                          1/1     Running     5 (126m ago)   2d17h
csi-snapshotter-86f65d8bc-dncwv                          1/1     Running     5 (126m ago)   2d17h
......
```

<font style="color:rgb(28, 30, 33);">这其实是启动的 3 个副本，同一时间只有一个 Pod 提供服务，通过 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">leader-election</font>`<font style="color:rgb(28, 30, 33);"> 来实现的选主高可用，比如当前这里提供服务的是 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">csi-snapshotter-86f65d8bc-dncwv</font>`<font style="color:rgb(28, 30, 33);">，我们可以查看对应的日志信息：</font>

```shell
➜ kubectl logs -f csi-snapshotter-86f65d8bc-dncwv -n longhorn-system
......
E0223 04:36:33.570567       1 reflector.go:127] github.com/kubernetes-csi/external-snapshotter/client/v3/informers/externalversions/factory.go:117: Failed to watch *v1beta1.VolumeSnapshotClass: failed to list *v1beta1.VolumeSnapshotClass: the server could not find the requested resource (get volumesnapshotclasses.snapshot.storage.k8s.io)
E0223 04:37:03.773447       1 reflector.go:127] github.com/kubernetes-csi/external-snapshotter/client/v3/informers/externalversions/factory.go:117: Failed to watch *v1beta1.VolumeSnapshotContent: failed to list *v1beta1.VolumeSnapshotContent: the server could not find the requested resource (get volumesnapshotcontents.snapshot.storage.k8s.io)
```

<font style="color:rgb(28, 30, 33);">可以看到提示没有 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotClass</font>`<font style="color:rgb(28, 30, 33);"> 和 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotContent</font>`<font style="color:rgb(28, 30, 33);"> 资源，这是因为这两个资源都是 CRDs，并不是 Kubernetes 内置的资源对象，而我们在安装 Longhorn 的时候也没有安装这两个 CRDs，所以找不到，要通过 CSI 来实现卷快照功能自然就需要先安装 CRDs，我们可以从 </font>[<font style="color:rgb(33, 96, 253);">external-snapshotter</font>](https://github.com/kubernetes-csi/external-snapshotter)<font style="color:rgb(28, 30, 33);"> 项目中来获取：</font>

```shell
➜ git clone https://github.com/kubernetes-csi/external-snapshotter
➜ cd external-snapshotter && git checkout v5.0.1
➜ kubectl kustomize client/config/crd | kubectl create -f -
```

<font style="color:rgb(28, 30, 33);">上面的命令会安装上面提到的 3 个 Snapshot CRDs:</font>

```shell
➜ kubectl get crd |grep snapshot
volumesnapshotclasses.snapshot.storage.k8s.io    2022-02-23T05:31:34Z
volumesnapshotcontents.snapshot.storage.k8s.io   2022-02-23T05:31:34Z
volumesnapshots.snapshot.storage.k8s.io          2022-02-23T05:31:34Z
```

<font style="color:rgb(28, 30, 33);">安装完成后再去查看上面的 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">csi-snapshotter</font>`<font style="color:rgb(28, 30, 33);"> 相关的 Pod 日志就正常了。CRDs 安装完成后还不够，我们还需要一个快照控制器来监听 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshot</font>`<font style="color:rgb(28, 30, 33);"> 和 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotContent</font>`<font style="color:rgb(28, 30, 33);"> 对象，同样 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">external-snapshotter</font>`<font style="color:rgb(28, 30, 33);"> 项目中也提供了一个 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">Common Snapshot Controller</font>`<font style="color:rgb(28, 30, 33);">，执行下面的命令一键安装：</font>

```shell
# 修改 deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml 镜像地址为 cnych/csi-snapshot-controller:v5.0.0，默认为 gcr 镜像
➜ kubectl -n kube-system kustomize deploy/kubernetes/snapshot-controller | kubectl create -f -
```

<font style="color:rgb(28, 30, 33);">这里我们将快照控制器安装到了 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">kube-system</font>`<font style="color:rgb(28, 30, 33);"> 命名空间下，启动两个副本，同样同一时间只有一个 Pod 提供服务：</font>

```shell
➜ kubectl get pods -n kube-system -l app=snapshot-controller
NAME                                   READY   STATUS    RESTARTS   AGE
snapshot-controller-677b65dc6c-288w9   1/1     Running   0          3m22s
snapshot-controller-677b65dc6c-zgdcm   1/1     Running   0          39s
```

<font style="color:rgb(28, 30, 33);">到这里就将使用 CSI 来配置快照的环境准备好了。</font>

#### <font style="color:rgb(28, 30, 33);">6.1.2 测试</font>
<font style="color:rgb(28, 30, 33);">下面我们仍然以前面的 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">mysql-pvc</font>`<font style="color:rgb(28, 30, 33);"> 这个卷为例来说明下如何使用卷快照功能：</font>

```shell
➜ kubectl get pvc mysql-pvc
NAME        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
mysql-pvc   Bound    pvc-ec17a7e4-7bb4-4456-9380-353db3ed4307   1Gi        RWO            longhorn       2d18h
```

<font style="color:rgb(28, 30, 33);">要创建 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">mysql-pvc</font>`<font style="color:rgb(28, 30, 33);"> 的快照申请，首先需要创建一个 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshot</font>`<font style="color:rgb(28, 30, 33);"> 对象：</font>

```yaml
# snapshot-mysql.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: mysql-snapshot-demo
spec:
  volumeSnapshotClassName: longhorn
  source:
    persistentVolumeClaimName: mysql-pvc
    # volumeSnapshotContentName: test-content
```

<font style="color:rgb(28, 30, 33);">其中就两个主要配置参数：</font>

+ `<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">volumeSnapshotClassName</font>`<font style="color:rgb(28, 30, 33);">：指定 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotClass</font>`<font style="color:rgb(28, 30, 33);"> 的名称，这样就可以动态创建一个对应的 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotContent</font>`<font style="color:rgb(28, 30, 33);"> 与之绑定，如果没有指定该参数，则属于静态方式，需要手动创建 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotContent</font>`<font style="color:rgb(28, 30, 33);">。</font>
+ `<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">persistentVolumeClaimName</font>`<font style="color:rgb(28, 30, 33);">：指定数据来源的 PVC 名称。</font>
+ `<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">volumeSnapshotContentName</font>`<font style="color:rgb(28, 30, 33);">：如果是申请静态存储快照，则需要通过该参数来指定一个 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotContent</font>`<font style="color:rgb(28, 30, 33);">。</font>

<font style="color:rgb(28, 30, 33);">上面我们指定了一个存储快照类 longhorn，当然需要创建这个对象：</font>

```yaml
# snapshotclass.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: longhorn
  # annotations:  # 如果要指定成默认的快照类
  #   snapshot.storage.kubernetes.io/is-default-class: "true"
driver: driver.longhorn.io
deletionPolicy: Delete
```

<font style="color:rgb(28, 30, 33);">每个 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotClass</font>`<font style="color:rgb(28, 30, 33);"> 都包含 driver、deletionPolicy 和 parameters 字段，在需要动态配置属于该类的 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshot</font>`<font style="color:rgb(28, 30, 33);"> 时使用。</font>

+ `<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">driver</font>`<font style="color:rgb(28, 30, 33);">：表示 CSI 存储插件驱动的名称，这里我们使用的是 Longhorn 插件，名为 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">driver.longhorn.io</font>`
+ `<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">deletionPolicy</font>`<font style="color:rgb(28, 30, 33);">：删除策略，可以设置为 Delete 或 Retain，如果删除策略是 Delete，那么底层的存储快照会和 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotContent</font>`<font style="color:rgb(28, 30, 33);"> 对象一起删除，如果删除策略是 Retain，那么底层快照和 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotContent</font>`<font style="color:rgb(28, 30, 33);"> 对象都会被保留。</font>
+ `<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">parameters</font>`<font style="color:rgb(28, 30, 33);">：存储插件需要配置的参数，有 CSI 驱动提供具体的配置参数。</font>

<font style="color:rgb(28, 30, 33);">如果想将当前快照类设置成默认的则需要添加 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">snapshot.storage.kubernetes.io/is-default-class: "true"</font>`<font style="color:rgb(28, 30, 33);"> 这样的 </font>`<font style="color:#DF2A3F;">annotations</font>`<font style="color:rgb(28, 30, 33);">。</font>

<font style="color:rgb(28, 30, 33);">现在我们直接创建上面的两个资源对象：</font>

```shell
# 引用资源清单文件
➜ kubectl apply -f snapshotclass.yaml
volumesnapshotclass.snapshot.storage.k8s.io/longhorn created
➜ kubectl apply -f snapshot-mysql.yaml
volumesnapshot.snapshot.storage.k8s.io/mysql-snapshot-demo created

# 查看资源状态信息
➜ kubectl get volumesnapshotclass
NAME       DRIVER               DELETIONPOLICY   AGE
longhorn   driver.longhorn.io   Delete           43s
➜ kubectl get volumesnapshot
NAME                  READYTOUSE   SOURCEPVC   SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS   SNAPSHOTCONTENT                                    CREATIONTIME   AGE
mysql-snapshot-demo   true         mysql-pvc                           1Gi           longhorn        snapcontent-1119649a-d4f2-447f-a21a-e527f202e43e   43s            43s
```

<font style="color:rgb(28, 30, 33);">这个时候会动态为我们创建一个 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotContent</font>`<font style="color:rgb(28, 30, 33);"> 对象：</font>

```shell
➜ kubectl get volumesnapshotcontent
NAME                                               READYTOUSE   RESTORESIZE   DELETIONPOLICY   DRIVER               VOLUMESNAPSHOTCLASS   VOLUMESNAPSHOT        VOLUMESNAPSHOTNAMESPACE   AGE
snapcontent-1119649a-d4f2-447f-a21a-e527f202e43e   true         1073741824    Delete           driver.longhorn.io   longhorn              mysql-snapshot-demo   default                   97s
```

<font style="color:rgb(28, 30, 33);">自动创建的 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotContent</font>`<font style="color:rgb(28, 30, 33);"> 对象内容如下所示：</font>

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotContent
metadata:
  name: snapcontent-1119649a-d4f2-447f-a21a-e527f202e43e
spec:
  deletionPolicy: Delete
  driver: driver.longhorn.io
  source:
    volumeHandle: pvc-ec17a7e4-7bb4-4456-9380-353db3ed4307
  volumeSnapshotClassName: longhorn
  volumeSnapshotRef:
    apiVersion: snapshot.storage.k8s.io/v1
    kind: VolumeSnapshot
    name: mysql-snapshot-demo
    namespace: default
    resourceVersion: '4967456'
    uid: 1119649a-d4f2-447f-a21a-e527f202e43e
status:
  creationTime: 1645597546000000000
  readyToUse: true
  restoreSize: 1073741824
  snapshotHandle: bs://pvc-ec17a7e4-7bb4-4456-9380-353db3ed4307/backup-f5f28fd624a148ed
```

<font style="color:rgb(28, 30, 33);">其中的 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">source.volumeHandle</font>`<font style="color:rgb(28, 30, 33);"> 字段的值是在后端存储上创建并由 CSI 驱动在创建存储卷期间返回的 Volume 的唯一标识符，在动态供应模式下需要该字段，指定的是快照的来源 Volume 信息，</font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">volumeSnapshotRef</font>`<font style="color:rgb(28, 30, 33);"> 下面就是和关联的 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshot</font>`<font style="color:rgb(28, 30, 33);"> 对象的相关信息。当然这个时候我们在 Longhorn UI 界面上也可以看到上面我们创建的这个快照了，快照名称为 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">snapshot-1119649a-d4f2-447f-a21a-e527f202e43e</font>`<font style="color:rgb(28, 30, 33);">，后面的 ID 与上面的 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">VolumeSnapshotContent</font>`<font style="color:rgb(28, 30, 33);"> 名称保持一致：</font>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761620990110-25eaa928-3935-45e6-b9bd-98de55702974.png)

<font style="color:rgb(28, 30, 33);">并且也会进行一次对应的 Backup 操作，备份的信息通过 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">snapshotHandle</font>`<font style="color:rgb(28, 30, 33);"> 进行指定的，格式为 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">bs://backup-<volume>/backup-<name></font>`<font style="color:rgb(28, 30, 33);">：</font>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761620991004-d1bd812b-faa1-446d-b39e-ffeecd7b0e5b.png)

<font style="color:rgb(28, 30, 33);">这样我们就完成了通过 CSI 实现卷的快照管理功能。</font>

### <font style="color:rgb(28, 30, 33);">6.2 基于快照创建新的 PVC（恢复）</font>
<font style="color:rgb(28, 30, 33);">Kubernetes 对基于快照创建存储卷在 1.17 版本更新到了 Beta 版本，要启用该特性，就需要在 kube-apiserver、kube-controller-manager 和 kubelet 的 Feature Gate 中启用 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">--feature-gates=...,VolumeSnapshotDataSource</font>`<font style="color:rgb(28, 30, 33);">（我们这里是 1.22 版本默认已经启用了），然后就可以基于某个快照创建一个新的 PVC 存储卷了，比如现在我们来基于上面创建的 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">mysql-snapshot-demo</font>`<font style="color:rgb(28, 30, 33);"> 这个对象来创建一个新的 PVC：</font>

```yaml
# restore-mysql.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-restore-pvc
spec:
  storageClassName: longhorn
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  dataSource:
    apiGroup: snapshot.storage.k8s.io
    kind: VolumeSnapshot
    name: mysql-snapshot-demo
```

<font style="color:rgb(28, 30, 33);">上面的 PVC 对象和我们平时声明的方式基本一致，唯一不同的是通过一个 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">dataSource</font>`<font style="color:rgb(28, 30, 33);"> 字段配置了基于名为 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">mysql-snapshot-demo</font>`<font style="color:rgb(28, 30, 33);"> 的存储快照进行创建，创建上面的资源对象后同样会自动创建一个 PV 与之绑定：</font>

```shell
➜ kubectl get pvc mysql-restore-pvc
NAME                STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
mysql-restore-pvc   Bound    pvc-e4ddd985-31a8-4570-b393-dcedec3b0d95   1Gi        RWO            longhorn       17s
```

<font style="color:rgb(28, 30, 33);">在 Longhorn UI 中去查看该卷，可以看到该卷的实际大小并不为 0，这是因为我们是从快照中创建过来的，相当于从上面的快照中恢复的数据：</font>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761620990597-da68dafd-b47c-4805-b7b4-7628487e3214.png)

### <font style="color:rgb(28, 30, 33);">6.3 卷克隆</font>
<font style="color:rgb(28, 30, 33);">除了基于快照创建新的 PVC 对象之外，CSI 类型的存储还支持存储的克隆功能，可以基于已经存在的 PVC 克隆一个新的 PVC，实现方式也是通过在 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">dataSource</font>`<font style="color:rgb(28, 30, 33);"> 字段中来设置源 PVC 来实现。</font>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761620990693-812ce289-d38e-49e5-90d4-086455ba5b16.png)

<font style="color:rgb(28, 30, 33);">克隆一个 PVC 其实就是对已存在的存储卷创建一个副本，唯一的区别是，系统在为克隆 PVC 提供后端存储资源时，不是新建一个空的 PV，而是复制一个与原 PVC 绑定 PV 完全一样的 PV。</font>

<font style="color:rgb(28, 30, 33);">从 Kubernetes API 的角度看，克隆的实现只是在创建新的 PVC 时， 增加了指定一个现有 PVC 作为数据源的能力，源 PVC 必须是 bound 状态且可用的。</font>

<font style="color:rgb(28, 30, 33);">用户在使用该功能时，需要注意以下事项：</font>

+ <font style="color:rgb(28, 30, 33);">克隆仅适用于 CSI 驱动</font>
+ <font style="color:rgb(28, 30, 33);">克隆仅适用于动态供应</font>
+ <font style="color:rgb(28, 30, 33);">克隆功能取决于具体的 CSI 驱动是否实现该功能</font>
+ <font style="color:rgb(28, 30, 33);">要求目标 PVC 和源 PVC 必须处于同一个命名空间</font>
+ <font style="color:rgb(28, 30, 33);">只支持在相同的 StorageClass 中（可以使用默认的）</font>
+ <font style="color:rgb(28, 30, 33);">两个存储卷的存储模式（VolumeMode）要一致</font>

<font style="color:rgb(28, 30, 33);">同样我们来对前面的 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">mysql-pvc</font>`<font style="color:rgb(28, 30, 33);"> 这个存储卷进行克隆操作，对应的 PVC 声明如下所示：</font>

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-clone-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 1Gi # 必须大于或等于源的值
  dataSource:
    kind: PersistentVolumeClaim
    name: mysql-pvc
```

<font style="color:rgb(28, 30, 33);">该 PVC 和源 PVC 声明一样的配置，唯一不同的是通过 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">dataSource</font>`<font style="color:rgb(28, 30, 33);"> 指定了源 PVC 的名称，直接创建这个资源对象，结果是 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">mysql-clone-pvc</font>`<font style="color:rgb(28, 30, 33);"> 这个新的 PVC 与源 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">mysql-pvc</font>`<font style="color:rgb(28, 30, 33);"> 拥有相同的数据。</font>

```shell
➜ kubectl get pvc mysql-clone-pvc
NAME              STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
mysql-clone-pvc   Bound    pvc-58eab5f0-a386-435c-91f4-0c26f7935695   1Gi        RWO            longhorn       31s
```

<font style="color:rgb(28, 30, 33);">在 Longhorn UI 页面中也可以看到对应的卷：</font>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761620990950-d642f4c7-dced-45d1-bb86-7b7c68e5131e.png)

<font style="color:rgb(28, 30, 33);">一旦新的 PVC 可用，被克隆的 PVC 就可以像其他 PVC 一样被使用了，也可以对其进行克隆、快照、删除等操作。</font>

### <font style="color:rgb(28, 30, 33);">6.4 卷动态扩容</font>
<font style="color:rgb(28, 30, 33);">我们知道对于存储来说扩容是一个非常终于的需求，对于 Kubernetes 中的卷动态扩容同样也是需要的基本功能，PV 要做扩容操作是需要底层存储支持该操作才能实现，Longhorn 底层是支持卷扩容操作的，但是要求扩展的卷必须处于 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">detached</font>`<font style="color:rgb(28, 30, 33);"> 状态才能操作，有两种方法可以扩容 Longhorn 卷：修改 PVC 和使用 Longhorn UI。</font>

<font style="color:rgb(28, 30, 33);">通过 Longhorn UI 操作比较简单，直接在页面中选择要扩容的卷，在操作中选择 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">Expand Volume</font>`<font style="color:rgb(28, 30, 33);"> 进行操作即可：</font>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761620990864-efc2b1e7-0568-4f52-9ef3-95455b80a4ee.png)

<font style="color:rgb(28, 30, 33);">要通过 PVC 来进行扩容首先需要 PVC 由 Longhorn StorageClass 进行动态供应，并且在 StorageClass 中 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">allowVolumeExpansion</font>`<font style="color:rgb(28, 30, 33);"> 属性设置为 </font>`<font style="color:#DF2A3F;">true</font>`<font style="color:rgb(28, 30, 33);">，建议使用这种方法，因为 PVC 和 PV 会自动更新，并且在扩容后都会保持一致。比如上面使用的 mysql-clone-pvc 这个卷（处于 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">detached</font>`<font style="color:rgb(28, 30, 33);"> 状态）使用的 longhorn 这个 StorageClass 中就已经配置了 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">allowVolumeExpansion: true</font>`<font style="color:rgb(28, 30, 33);">，然后直接修改 mysql-pvc 这个卷下面的 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">spec.resources.requests.storage</font>`<font style="color:rgb(28, 30, 33);"> 值即可：</font>

```shell
➜ kubectl get pvc mysql-clone-pvc
NAME              STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
mysql-clone-pvc   Bound    pvc-58eab5f0-a386-435c-91f4-0c26f7935695   1Gi        RWO            longhorn       40m
➜ kubectl patch pvc mysql-clone-pvc -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}}'
```

<font style="color:rgb(28, 30, 33);">修改后可以查看该 PVC 的 events 信息：</font>

```shell
➜ kubectl describe pvc mysql-clone-pvc
......
Events:
  Type     Reason                  Age                From                                                                                      Message
  ----     ------                  ----               ----                                                                                      -------
  ......
  Normal   Resizing                14s                external-resizer driver.longhorn.io                                                       External resizer is resizing volume pvc-58eab5f0-a386-435c-91f4-0c26f7935695
  Warning  ExternalExpanding       14s                volume_expand                                                                             Ignoring the PVC: didn't find a plugin capable of expanding the volume; waiting for an external controller to process this PVC.
  Normal   VolumeResizeSuccessful  2s                 external-resizer driver.longhorn.io                                                       Resize volume succeeded
```

<font style="color:rgb(28, 30, 33);">可以看到通过 </font>`<font style="color:#DF2A3F;background-color:rgb(246, 247, 248);">external-resizer</font>`<font style="color:rgb(28, 30, 33);"> 组件实现了 Resize 操作，查看 PVC 和 PV 的大小验证：</font>

```shell
➜ kubectl get pvc mysql-clone-pvc
NAME              STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
mysql-clone-pvc   Bound    pvc-58eab5f0-a386-435c-91f4-0c26f7935695   2Gi        RWO            longhorn       43m
➜ kubectl get pv pvc-58eab5f0-a386-435c-91f4-0c26f7935695
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                     STORAGECLASS   REASON   AGE
pvc-58eab5f0-a386-435c-91f4-0c26f7935695   2Gi        RWO            Delete           Bound    default/mysql-clone-pvc   longhorn                43m
```

<font style="color:rgb(28, 30, 33);">可以看到 PVC 和 PV 中的容量都变成了 2Gi，证明扩容成功了，通过 Longhorn UI 也可以查看到卷扩容成功了：</font>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761620991491-e5b95c4b-7712-43f9-96c9-cee0dfbedc63.png)

