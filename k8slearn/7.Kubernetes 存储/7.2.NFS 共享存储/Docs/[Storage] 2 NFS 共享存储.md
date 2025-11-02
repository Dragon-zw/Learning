前面我们学习了 hostPath 与 Local PV 两种本地存储方式，但是平时我们的应用更多的是无状态服务，可能会同时发布在不同的节点上，这个时候本地存储就不适用了，往往就需要使用到共享存储了，比如最简单常用的网络共享存储 NFS，本节课我们就来介绍下如何在 Kubernetes 下面使用 NFS 共享存储。

## 1 安装 NFS 服务
我们这里为了演示方便，先使用相对简单的 NFS 这种存储资源，接下来我们在节点 `<font style="color:#DF2A3F;">192.168.178.35</font>` 上来安装 NFS 服务，数据目录：`<font style="color:#DF2A3F;">/var/lib/k8s/data/</font>`

关闭防火墙

```shell
➜ systemctl stop firewalld.service
➜ systemctl disable firewalld.service
```

安装配置 NFS

```shell
➜ yum -y install nfs-utils rpcbind
```

共享目录设置权限：

```shell
➜ mkdir -p /var/lib/k8s/data
➜ chmod 755 /var/lib/k8s/data/
```

配置 nfs，nfs 的默认配置文件在 `<font style="color:#DF2A3F;">/etc/exports</font>` 文件下，在该文件中添加下面的配置信息：

```shell
➜ vi /etc/exports
/var/lib/k8s/data  *(rw,sync,no_root_squash)
```

配置说明：

+ `<font style="color:#DF2A3F;">/var/lib/k8s/data</font>`：是共享的数据目录
+ `<font style="color:#DF2A3F;">*</font>`：表示任何人都有权限连接，当然也可以是一个网段，一个 IP，也可以是域名
+ `<font style="color:#DF2A3F;">rw</font>`：读写的权限
+ `<font style="color:#DF2A3F;">sync</font>`：表示文件同时写入硬盘和内存
+ `<font style="color:#DF2A3F;">no_root_squash</font>`：当登录 NFS 主机使用共享目录的使用者是 root 时，其权限将被转换成为匿名使用者，通常它的 UID 与 GID，都会变成 nobody 身份

当然 NFS 的配置还有很多，感兴趣的同学可以在网上去查找一下。

启动服务 NFS 需要向 rpc 注册，rpc 一旦重启了，注册的文件都会丢失，向他注册的服务都需要重启 注意启动顺序，先启动 rpcbind

```shell
➜ systemctl start rpcbind.service
➜ systemctl enable rpcbind
# 查看服务的状态
➜ systemctl status rpcbind
● rpcbind.service - RPC Bind
   Loaded: loaded (/usr/lib/systemd/system/rpcbind.service; enabled; vendor preset: enabled)
   Active: active (running) since Tue 2025-08-12 21:54:44 HKT; 2 months 14 days ago
     Docs: man:rpcbind(8)
 Main PID: 1005 (rpcbind)
    Tasks: 1 (limit: 203828)
   Memory: 1.8M
   CGroup: /system.slice/rpcbind.service
           └─1005 /usr/bin/rpcbind -w -f

Aug 12 21:54:42 hkk8smaster001 systemd[1]: Starting RPC Bind...
Aug 12 21:54:44 hkk8smaster001 systemd[1]: Started RPC Bind.
```

看到上面的 Started 证明启动成功了。

然后启动 NFS 服务：

```shell
➜ systemctl start nfs.service
➜ systemctl enable nfs
# 查看服务的状态
➜ systemctl status nfs
● nfs-server.service - NFS server and services
   Loaded: loaded (/usr/lib/systemd/system/nfs-server.service; enabled; vendor preset: disabled)
  Drop-In: /run/systemd/generator/nfs-server.service.d
           └─order-with-mounts.conf
   Active: active (exited) since Tue 2025-08-12 21:35:37 CST; 14s ago
 Main PID: 32067 (code=exited, status=0/SUCCESS)
   CGroup: /system.slice/nfs-server.service

Jul 10 21:35:37 master systemd[1]: Starting NFS server and services...
Jul 10 21:35:37 master systemd[1]: Started NFS server and services.
```

同样看到 Started 则证明 NFS Server 启动成功了。

另外我们还可以通过下面的命令确认下：

```shell
➜ rpcinfo -p | grep nfs
    100003    3   tcp   2049  nfs
    100003    4   tcp   2049  nfs
    100227    3   tcp   2049  nfs_acl
```

查看具体目录挂载权限：

```shell
➜ cat <<EOF >> /var/lib/nfs/etab
/var/lib/k8s/data       *(rw,sync,wdelay,hide,nocrossmnt,secure,no_root_squash,no_all_squash,no_subtree_check,secure_locks,acl,no_pnfs,anonuid=65534,anongid=65534,sec=sys,rw,secure,no_root_squash,no_all_squash)
EOF
```

到这里我们就把 NFS server 给安装成功了，然后就是前往节点安装 NFS 的客户端来验证，安装 nfs 当前也需要先关闭防火墙：

```shell
➜ systemctl stop firewalld.service
➜ systemctl disable firewalld.service
```

然后安装 nfs

```shell
➜ yum -y install nfs-utils rpcbind
```

安装完成后，和上面的方法一样，先启动 rpc、然后启动 nfs：

```shell
➜ systemctl start rpcbind.service
➜ systemctl enable rpcbind.service
➜ systemctl start nfs.service
➜ systemctl enable nfs.service
```

挂载数据目录 客户端启动完成后，我们在客户端来挂载下 nfs 测试下，首先检查下 nfs 是否有共享目录：

```shell
➜ showmount -e 192.168.178.35
Export list for 192.168.178.35:
/nfs/data         *
/var/lib/k8s/data *
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761530583486-4c9093dc-22ff-40ad-8702-4a2ffff3424a.png)

然后我们在客户端上新建目录：

```shell
➜ mkdir -p /root/course/kubeadm/data
```

将 nfs 共享目录挂载到上面的目录：

```shell
➜ mount -t nfs 192.168.178.35:/var/lib/k8s/data /root/course/kubeadm/data
```

挂载成功后，在客户端上面的目录中新建一个文件，然后我们观察下 nfs 服务端的共享目录下面是否也会出现该文件：

```shell
➜ touch /root/course/kubeadm/data/test.txt
```

然后在 NFS 服务端查看：

```shell
➜ ls -ls /var/lib/k8s/data/
total 4
4 -rw-r--r--. 1 root root 4 Jul 10 21:50 test.txt
```

如果上面出现了 `<font style="color:#DF2A3F;">test.txt</font>` 的文件，那么证明我们的 NFS 挂载成功了。

## 2 使用 Kubernetes NFS StorageClass
前面我们已经了解到了 PV、PVC、StorgeClass 的使用，那么我们的 NFS 又应该如何在 Kubernetes 中使用呢？

同样创建一个如下所示 nfs 类型的 PV 资源对象：

```yaml
# nfs-volume.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv
spec:
  storageClassName: manual
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  nfs: # 如果是 localPV 则使用 local 字段属性
    path: /var/lib/k8s/data/ # 指定nfs的挂载点
    server: 192.168.178.35 # 指定nfs服务地址
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-pvc
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

我们知道用户真正使用的是 PVC，而要使用 PVC 的前提就是必须要先和某个符合条件的 PV 进行一一绑定，比如存储容器、访问模式，以及 PV 和 PVC 的 storageClassName 字段必须一样，这样才能够进行绑定，当 PVC 和 PV 绑定成功后就可以直接使用这个 PVC 对象了：

```yaml
# nfs-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-volumes
spec:
  volumes:
    - name: nfs
      persistentVolumeClaim:
        claimName: nfs-pvc
  containers:
    - name: web
      image: nginx
      ports:
        - name: web
          containerPort: 80
      volumeMounts:
        - name: nfs
          subPath: test-volumes
          mountPath: '/usr/share/nginx/html'
```

直接创建上面的资源对象即可：

```shell
➜ kubectl apply -f nfs-volume.yaml
persistentvolume/nfs-pv created
persistentvolumeclaim/nfs-pvc created

➜ kubectl apply -f nfs-pod.yaml
pod/test-volumes created

# 查看 PV，PVC 以及 Pod 的状态信息
➜ kubectl get pv nfs-pv
NAME     CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM             STORAGECLASS   REASON   AGE
nfs-pv   1Gi        RWO            Retain           Bound    default/nfs-pvc   manual                  25s

➜ kubectl get pvc nfs-pvc
NAME      STATUS   VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
nfs-pvc   Bound    nfs-pv   1Gi        RWO            manual         45s

➜ kubectl get pods test-volumes -o wide
NAME           READY   STATUS    RESTARTS   AGE   IP               NODE           NOMINATED NODE   READINESS GATES
test-volumes   1/1     Running   0          50s   192.244.211.47   hkk8snode001   <none>           <none>
```

由于我们这里 PV 中的数据为空，所以挂载后会将 nginx 容器中的 `<font style="color:#DF2A3F;">/usr/share/nginx/html</font>` 目录覆盖，那么访问应用的时候就没有内容了：

```shell
➜ curl http://192.244.211.47
<html>
<head><title>403 Forbidden</title></head>
<body>
<center><h1>403 Forbidden</h1></center>
<hr><center>nginx/1.21.5</center>
</body>
</html>
```

我们可以在 PV 目录中添加一些内容：

```shell
# 在 NFS 服务器上面执行
➜ echo "nfs pv content" > /var/lib/k8s/data/test-volumes/index.html
➜ curl http://192.244.211.47
nfs pv content
```

然后重新访问就有数据了，而且当我们的 Pod 应用挂掉或者被删掉重新启动后数据还是存在的，因为数据已经持久化了。

上面的示例中需要我们手动去创建 PV 来和 PVC 进行绑定，有的场景下面需要自动创建 PV，这个时候就需要使用到 StorageClass 了，并且需要一个对应的 provisioner 来自动创建 PV，比如这里我们使用的 NFS 存储，则可以使用 [nfs-subdir-external-provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner) 这个 Provisioner，它使用现有的和已配置的 NFS 服务器来支持通过 PVC 动态配置 PV，持久卷配置为 `<font style="color:#DF2A3F;">${namespace}-${pvcName}-${pvName}</font>`，首先我们使用 Helm Chart 来安装：

```shell
➜ helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/

# 指定第三方的镜像仓库
# ➜ helm upgrade --install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
#   --set nfs.server=192.168.178.35 \
#   --set nfs.path=/var/lib/k8s/data \
#   --set image.repository=cnych/nfs-subdir-external-provisioner \
#   --set storageClass.defaultClass=true -n kube-system

➜ helm upgrade --install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --set nfs.server=192.168.178.35 \
  --set nfs.path=/var/lib/k8s/data \
  --set storageClass.defaultClass=true -n kube-system
```

上面的命令会在 `<font style="color:#DF2A3F;">kube-system</font>` 命名空间下安装 `<font style="color:#DF2A3F;">nfs-subdir-external-provisioner</font>`，并且会创建一个名为 `<font style="color:#DF2A3F;">nfs-client</font>` 默认的 StorageClass：

```shell
➜ kubectl get sc
NAME                   PROVISIONER                                     RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-storage          kubernetes.io/no-provisioner                    Delete          WaitForFirstConsumer   false                  2d20h
nfs-client (default)   cluster.local/nfs-subdir-external-provisioner   Delete          Immediate              true                   35d

➜ kubectl get sc nfs-client -o yaml
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  annotations:
    meta.helm.sh/release-name: nfs-subdir-external-provisioner
    meta.helm.sh/release-namespace: kube-system
    storageclass.kubernetes.io/is-default-class: "true"
  creationTimestamp: "2025-10-27T02:34:14Z"
  labels:
    app: nfs-subdir-external-provisioner
    app.kubernetes.io/managed-by: Helm
    chart: nfs-subdir-external-provisioner-4.0.18
    heritage: Helm
    release: nfs-subdir-external-provisioner
  name: nfs-client
  resourceVersion: "2160028"
  uid: 35443d15-1657-43df-b4c6-b3394afbb2ae
parameters:
  archiveOnDelete: "true"
provisioner: cluster.local/nfs-subdir-external-provisioner
reclaimPolicy: Delete
volumeBindingMode: Immediate
```

这样当以后我们创建的 PVC 中如果没有指定具体的 `<font style="color:#DF2A3F;">StorageClass</font>` 的时候，则会使用上面的 SC 自动创建一个 PV。比如我们创建一个如下所示的 PVC：

```yaml
# nfs-sc-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-sc-pvc
spec:
  # storageClassName: nfs-client  # 不指定则使用默认的 SC
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

直接创建上面的 PVC 资源对象后就会自动创建一个 PV 与其进行绑定：

```shell
# 引用资源清单文件
➜ kubectl create -f nfs-sc-pvc.yaml 
persistentvolumeclaim/nfs-sc-pvc created

➜ kubectl get pvc nfs-sc-pvc
NAME         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
nfs-sc-pvc   Bound    pvc-eb54cea7-311b-449b-9b98-17becceb0257   1Gi        RWO            nfs-client     15s
```

对应自动创建的 PV 如下所示：

```shell
➜ kubectl get pv pvc-eb54cea7-311b-449b-9b98-17becceb0257 -o yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  annotations:
    pv.kubernetes.io/provisioned-by: cluster.local/nfs-subdir-external-provisioner
  creationTimestamp: "2025-10-27T02:35:36Z"
  finalizers:
  - kubernetes.io/pv-protection
  name: pvc-eb54cea7-311b-449b-9b98-17becceb0257
  resourceVersion: "2160328"
  uid: d29e5152-8ea5-4d35-b225-78f7babf2e01
spec:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 1Gi
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    name: nfs-sc-pvc
    namespace: default
    resourceVersion: "2160322"
    uid: eb54cea7-311b-449b-9b98-17becceb0257
  nfs:
    path: /var/lib/k8s/data/default-nfs-sc-pvc-pvc-eb54cea7-311b-449b-9b98-17becceb0257
    server: 192.168.178.35
  persistentVolumeReclaimPolicy: Delete
  storageClassName: nfs-client
  volumeMode: Filesystem
status:
  phase: Bound
```

挂载的 NFS 目录为 `<font style="color:#DF2A3F;">/var/lib/k8s/data/default-nfs-sc-pvc-pvc-ed8e2fb7-897d-465f-8735-81d52c91d074</font>`<font style="color:#DF2A3F;">，和上面的 </font>`<font style="color:#DF2A3F;">${namespace}-${pvcName}-${pvName}</font>` 规范一致的。

## 3 原理
我们只是在 volumes 中指定了我们上面创建的 PVC 对象，当这个 Pod 被创建之后， kubelet 就会把这个 PVC 对应的这个 NFS 类型的 Volume（PV）挂载到这个 Pod 容器中的目录中去。前面我们也提到了这样的话对于普通用户来说完全就不用关心后面的具体存储在 NFS 还是 Ceph 或者其他了，只需要直接使用 PVC 就可以了，因为真正的存储是需要很多相关的专业知识的，这样就完全职责分离解耦了。

普通用户直接使用 PVC 没有问题，但是也会出现一个问题，那就是当普通用户创建一个 PVC 对象的时候，这个时候系统里面并没有合适的 PV 来和它进行绑定，因为 PV 大多数情况下是管理员给我们创建的，这个时候启动 Pod 肯定就会失败了，如果现在管理员如果去创建一个对应的 PV 的话，PVC 和 PV 当然就可以绑定了，然后 Pod 也会自动的启动成功，这是因为在 Kubernetes 中有一个专门处理持久化存储的控制器 Volume Controller，这个控制器下面有很多个控制循环，其中一个就是用于 PV 和 PVC 绑定的 `<font style="color:#DF2A3F;">PersistentVolumeController</font>`。

`<font style="color:#DF2A3F;">PersistentVolumeController</font>` 会不断地循环去查看每一个 PVC，是不是已经处于 Bound（已绑定）状态。如果不是，那它就会遍历所有的、可用的 PV，并尝试将其与未绑定的 PVC 进行绑定，这样，Kubernetes 就可以保证用户提交的每一个 PVC，只要有合适的 PV 出现，它就能够很快进入绑定状态。而所谓将一个 PV 与 PVC 进行**<font style="color:#DF2A3F;">绑定</font>**，其实就是将这个 PV 对象的名字，填在了 PVC 对象的 `<font style="color:#DF2A3F;">spec.volumeName</font>` 字段上。

PV 和 PVC 绑定上了，那么又是如何将容器里面的数据进行持久化的呢，我们知道 Docker 的 Volume 挂载其实就是**<font style="color:#DF2A3F;">将一个宿主机上的目录和一个容器里的目录绑定挂载在了一起</font>**，具有持久化功能当然就是指的宿主机上面的这个目录了，当容器被删除或者在其他节点上重建出来以后，这个目录里面的内容依然存在，所以一般情况下实现持久化是需要一个远程存储的，比如 NFS、Ceph 或者云厂商提供的磁盘等等。所以接下来需要做的就是持久化宿主机目录这个过程。

当 Pod 被调度到一个节点上后，节点上的 kubelet 组件就会为这个 Pod 创建它的 Volume 目录，默认情况下 kubelet 为 Volume 创建的目录在 kubelet 工作目录下面：

```shell
/var/lib/kubelet/pods/<Pod的ID>/volumes/kubernetes.io~<Volume类型>/<Volume名字>
```

比如上面我们创建的 Pod 对应的 Volume 目录完整路径为：

```shell
/var/lib/kubelet/pods/d4fcdb11-baf7-43d9-8d7d-3ede24118e08/volumes/kubernetes.io~nfs/nfs-pv
```

!!! info "提示" 要获取 Pod 的唯一标识 uid，可通过命令 `<font style="color:#DF2A3F;">kubectl get pod pod名 -o jsonpath={.metadata.uid}</font>` 获取。

然后就需要根据我们的 Volume 类型来决定需要做什么操作了，假如后端存储使用的 Ceph RBD，那么 kubelet 就需要先将 Ceph 提供的 RBD 挂载到 Pod 所在的宿主机上面，这个阶段在 Kubernetes 中被称为 **Attach 阶段**。Attach 阶段完成后，为了能够使用这个块设备，kubelet 还要进行第二个操作，即：**格式化**这个块设备，然后将它**挂载**到宿主机指定的挂载点上。这个挂载点，也就是上面我们提到的 Volume 的宿主机的目录。将块设备格式化并挂载到 Volume 宿主机目录的操作，在 Kubernetes 中被称为 **Mount 阶段**。但是对于我们这里使用的 NFS 就更加简单了， 因为 NFS 存储并没有一个设备需要挂载到宿主机上面，所以这个时候 kubelet 就会直接进入第二个 `Mount` 阶段，相当于直接在宿主机上面执行如下的命令：

```shell
mount -t nfs 192.168.178.35:/var/lib/k8s/data/ /var/lib/kubelet/pods/d4fcdb11-baf7-43d9-8d7d-3ede24118e08/volumes/kubernetes.io~nfs/nfs-pv
```

同样可以在测试的 Pod 所在节点查看 Volume 的挂载信息：

```shell
➜ findmnt /var/lib/kubelet/pods/d4fcdb11-baf7-43d9-8d7d-3ede24118e08/volumes/kubernetes.io~nfs/nfs-pv
TARGET                                                                               SOURCE                 FSTYPE OPTIONS
/var/lib/kubelet/pods/d4fcdb11-baf7-43d9-8d7d-3ede24118e08/volumes/kubernetes.io~nfs/nfs-pv
                                                                                     192.168.178.35:/var/lib/k8s/data/ nfs4   rw,relatime,
```

我们可以看到这个 Volume 被挂载到了 NFS（`<font style="color:#DF2A3F;">192.168.178.35:/var/lib/k8s/data/</font>`）下面，以后我们在这个目录里写入的所有文件，都会被保存在远程 NFS 服务器上。

这样在经过了上面的阶段过后，我们就得到了一个持久化的宿主机上面的 Volume 目录了，接下来 kubelet 只需要把这个 Volume 目录挂载到容器中对应的目录即可，这样就可以为 Pod 里的容器挂载这个持久化的 Volume 了，这一步其实也就相当于执行了如下所示的命令：

```shell
# docker 或者 nerdctl
$ docker run \
  -v /var/lib/kubelet/pods/<Pod的ID>/volumes/kubernetes.io~<Volume类型>/<Volume名字>:/<容器内的目标目录> \
  我的镜像 ...
```

整个存储的架构可以用下图来说明： ![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731583732357-f4ac971f-650d-4603-af54-80bbf1361d1c.png)

+ PV Controller：负责 PV/PVC 的绑定，并根据需求进行数据卷的 Provision/Delete 操作
+ AD Controller：负责存储设备的 Attach/Detach 操作，将设备挂载到目标节点
+ Volume Manager：管理卷的 Mount/Unmount 操作、卷设备的格式化等操作
+ Volume Plugin：扩展各种存储类型的卷管理能力，实现第三方存储的各种操作能力和 Kubernetes 存储系统结合

:::success
我们上面使用的 NFS 就属于 `<font style="color:#DF2A3F;">In-Tree</font>` 这种方式，`<font style="color:#DF2A3F;">In-Tree</font>` 就是在 Kubernetes 源码内部实现的，和 Kubernetes 一起发布、管理的，但是更新迭代慢、灵活性比较差，另外一种方式 `<font style="color:#DF2A3F;">Out-Of-Tree</font>` 是独立于 Kubernetes 的，目前主要有 `<font style="color:#DF2A3F;">CSI</font>` 和 `<font style="color:#DF2A3F;">FlexVolume</font>` 两种机制，开发者可以根据自己的存储类型实现不同的存储插件接入到 Kubernetes 中去，其中 `<font style="color:#DF2A3F;">CSI</font>` 是现在也是以后主流的方式，接下来我们会主要介绍 `<font style="color:#DF2A3F;">CSI</font>` 这种存储插件的使用。

:::

