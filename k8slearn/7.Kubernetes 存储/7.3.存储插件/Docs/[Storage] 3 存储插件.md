前面的章节中我们介绍了在 Kubernetes 中的持久化存储的使用，了解了 PV、PVC 以及 StorageClass 的使用方法，从本地存储到 NFS 共享存储都有学习，到这里我们其实已经可以完成应用各种场景的数据持久化了，但是难免在实际的使用过程中会遇到各种各样的问题，要解决这些问题最好的方式就是来了解下 Kubernetes 中存储的实现原理。

Kubernetes 默认情况下就提供了主流的存储卷接入方案，我们可以执行命令 `<font style="color:#DF2A3F;">kubectl explain pod.spec.volumes</font>` 查看到支持的各种存储卷，另外也提供了插件机制，允许其他类型的存储服务接入到 Kubernetes 系统中来，在 Kubernetes 中就对应 `<font style="color:#DF2A3F;">In-Tree</font>` 和 `<font style="color:#DF2A3F;">Out-Of-Tree</font>` 两种方式，`**<u><font style="color:#DF2A3F;">In-Tree</font></u>**`**<u> 就是在 Kubernetes 源码内部实现的，和 Kubernetes 一起发布、管理的，但是更新迭代慢、灵活性比较差，</u>**`**<u><font style="color:#DF2A3F;">Out-Of-Tree</font></u>**`**<u> 是独立于 Kubernetes 的，目前主要有 </u>**`**<u>CSI</u>**`**<u> 和 </u>**`**<u>FlexVolume</u>**`**<u> 两种机制</u>**，开发者可以根据自己的存储类型实现不同的存储插件接入到 Kubernetes 中去，<u>其中 </u>`<u><font style="color:#DF2A3F;">CSI</font></u>`<u> 是现在也是以后主流的方式</u>，所以当然我们的重点也会是 `<font style="color:#DF2A3F;">CSI</font>` 的使用介绍。

## 1 FlexVolume
FlexVolume 提供了一种扩展 Kubernetes 存储插件的方式，用户可以自定义自己的存储插件。**<u>要使用 FlexVolume 需要在每个节点上安装存储插件二进制文件，该二进制需要实现 FlexVolume 的相关接口，默认存储插件的存放路径为 </u>**`**<u><font style="color:#DF2A3F;">/usr/libexec/kubernetes/kubelet-plugins/volume/exec/<vendor~driver>/<driver></font></u>**`，`<font style="color:#DF2A3F;">VolumePlugins</font>` 组件会不断 watch 这个目录来实现插件的添加、删除等功能。

其中 `<font style="color:#DF2A3F;">vendor~driver</font>` 的名字需要和 Pod 中`<font style="color:#DF2A3F;">flexVolume.driver</font>` 的字段名字匹配，例如：

```shell
/usr/libexec/kubernetes/kubelet-plugins/volume/exec/foo~cifs/cifs
```

对应的 Pod 中的 `<font style="color:#DF2A3F;">flexVolume.driver</font>` 属性为：`<font style="color:#DF2A3F;">foo/cifs</font>`。

在我们实现自定义存储插件的时候，需要实现 FlexVolume 的部分接口，因为要看实际需求，并不一定所有接口都需要实现。比如对于类似于 NFS 这样的存储就没必要实现 `<font style="color:#DF2A3F;">attach/detach</font>` 这些接口了，因为不需要，只需要实现 `<font style="color:#DF2A3F;">init/mount/umount</font>` 3 个接口即可。

+ init: `<font style="color:#DF2A3F;"><driver executable> init</font>` - `<font style="color:#DF2A3F;">kubelet/kube-controller-manager</font>` 初始化存储插件时调用，插件需要返回是否需要要 attach 和 detach 操作
+ attach: `<font style="color:#DF2A3F;"><driver executable> attach <json options> <node name></font>` - 将存储卷挂载到 Node 节点上
+ detach: `<font style="color:#DF2A3F;"><driver executable> detach <mount device> <node name></font>` - 将存储卷从 Node 上卸载
+ waitforattach: `<font style="color:#DF2A3F;"><driver executable> waitforattach <mount device> <json options></font>` - 等待 attach 操作成功（超时时间为 10 分钟）
+ isattached: `<font style="color:#DF2A3F;"><driver executable> isattached <json options> <node name></font>` - 检查存储卷是否已经挂载
+ mountdevice: `<font style="color:#DF2A3F;"><driver executable> mountdevice <mount dir> <mount device> <json options></font>` - 将设备挂载到指定目录中以便后续 bind mount 使用
+ unmountdevice: `<font style="color:#DF2A3F;"><driver executable> unmountdevice <mount device></font>` - 将设备取消挂载
+ mount: `<font style="color:#DF2A3F;"><driver executable> mount <mount dir> <json options></font>` - 将存储卷挂载到指定目录中
+ unmount: `<font style="color:#DF2A3F;"><driver executable> unmount <mount dir></font>` - 将存储卷取消挂载

实现上面的这些接口需要返回如下所示的 JSON 格式的数据：

```json
{
    "status": "<Success/Failure/Not supported>",
    "message": "<Reason for success/failure>",
    "device": "<Path to the device attached. This field is valid only for attach & waitforattach call-outs>"
    "volumeName": "<Cluster wide unique name of the volume. Valid only for getvolumename call-out>"
    "attached": <True/False (Return true if volume is attached on the node. Valid only for isattached call-out)>
    "capabilities": <Only included as part of the Init response>
    {
        "attach": <True/False (Return true if the driver implements attach and detach)>
    }
}
```

比如我们来实现一个 NFS 的 FlexVolume 插件，最简单的方式就是写一个脚本，然后实现 init、mount、unmount 3 个命令即可，然后按照上面的 JSON 格式返回数据，最后把这个脚本放在节点的 FlexVolume 插件目录下面即可。

下面就是官方给出的一个 NFS 的 FlexVolume 插件示例，可以从 `[https://github.com/kubernetes/examples/blob/master/staging/volumes/flexvolume/nfs](https://github.com/kubernetes/examples/blob/master/staging/volumes/flexvolume/nfs)` 获取脚本：

```shell
#!/bin/bash
# 注意:
#  - 在使用插件之前需要先安装 jq。
usage() {
    err "Invalid usage. Usage: "
    err "\t$0 init"
    err "\t$0 mount <mount dir> <json params>"
    err "\t$0 unmount <mount dir>"
    exit 1
}

err() {
    echo -ne $* 1>&2
}

log() {
    echo -ne $* >&1
}

ismounted() {
    MOUNT=`findmnt -n ${MNTPATH} 2>/dev/null | cut -d' ' -f1`
    if [ "${MOUNT}" == "${MNTPATH}" ]; then
        echo "1"
    else
        echo "0"
    fi
}

domount() {
    MNTPATH=$1

    NFS_SERVER=$(echo $2 | jq -r '.server')
    SHARE=$(echo $2 | jq -r '.share')

    if [ $(ismounted) -eq 1 ] ; then
        log '{"status": "Success"}'
        exit 0
    fi

    mkdir -p ${MNTPATH} &> /dev/null

    mount -t nfs ${NFS_SERVER}:/${SHARE} ${MNTPATH} &> /dev/null
    if [ $? -ne 0 ]; then
        err "{ \"status\": \"Failure\", \"message\": \"Failed to mount ${NFS_SERVER}:${SHARE} at ${MNTPATH}\"}"
        exit 1
    fi
    log '{"status": "Success"}'
    exit 0
}

unmount() {
    MNTPATH=$1
    if [ $(ismounted) -eq 0 ] ; then
        log '{"status": "Success"}'
        exit 0
    fi

    umount ${MNTPATH} &> /dev/null
    if [ $? -ne 0 ]; then
        err "{ \"status\": \"Failed\", \"message\": \"Failed to unmount volume at ${MNTPATH}\"}"
        exit 1
    fi

    log '{"status": "Success"}'
    exit 0
}

op=$1

if ! command -v jq >/dev/null 2>&1; then
    err "{ \"status\": \"Failure\", \"message\": \"'jq' binary not found. Please install jq package before using this driver\"}"
    exit 1
fi

if [ "$op" = "init" ]; then
    log '{"status": "Success", "capabilities": {"attach": false}}'
    exit 0
fi

if [ $# -lt 2 ]; then
    usage
fi

shift

case "$op" in
    mount)
        domount $*
        ;;
    unmount)
        unmount $*
        ;;
    *)
        log '{"status": "Not supported"}'
        exit 0
esac

exit 1
```

将上面脚本命名成 nfs，放置到 hkk8snode001 节点对应的插件下面： `<font style="color:#DF2A3F;">/usr/libexec/kubernetes/kubelet-plugins/volume/exec/ydzs~nfs/nfs</font>`，并设置权限为 700：

```shell
➜ mkdir -pv /usr/libexec/kubernetes/kubelet-plugins/volume/exec/ydzs~nfs/
# 脚本配置可执行权限
➜ chmod 700 /usr/libexec/kubernetes/kubelet-plugins/volume/exec/ydzs~nfs/nfs

# 安装 jq 工具
➜ yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
➜ yum install jq -y
```

这个时候我们部署一个应用到 hkk8snode001 节点上，并用 `<font style="color:#DF2A3F;">flexVolume</font>` 来持久化容器中的数据（当然也可以通过定义 flexvolume 类型的 PV、PVC 来使用），如下所示：

```yaml
# test-flexvolume.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-flexvolume
spec:
  nodeSelector: # 节点选择器
    kubernetes.io/hostname: hkk8snode001
  volumes:
    - name: test
      flexVolume:
        driver: 'ydzs/nfs' # 定义插件类型，根据这个参数在对应的目录下面找到插件的可执行文件
        fsType: 'nfs' # 定义存储卷文件系统类型
        options: # 定义所有与存储相关的一些具体参数
          server: '192.168.178.35'
          share: 'var/lib/k8s/data/'
  containers:
    - name: web
      image: nginx
      ports:
        - containerPort: 80
      volumeMounts:
        - name: test
          subPath: testflexvolume
          mountPath: /usr/share/nginx/html
```

其中 `<font style="color:#DF2A3F;">flexVolume.driver</font>` 就是插件目录 `<font style="color:#DF2A3F;">ydzs~nfs</font>` 对应的 `<font style="color:#DF2A3F;">ydzs/nfs</font>`<font style="color:#DF2A3F;"> </font>名称，`<font style="color:#DF2A3F;">flexVolume.options</font>` 中根据上面的 nfs 脚本可以得知里面配置的是 NFS 的 Server 地址和挂载目录路径，直接创建上面的资源对象：

```shell
➜ kubectl apply -f test-flexvolume.yaml
pod/test-flexvolume created

➜ kubectl get pods test-flexvolume -o wide 
NAME              READY   STATUS    RESTARTS   AGE   IP               NODE           NOMINATED NODE   READINESS GATES
test-flexvolume   1/1     Running   0          35s   192.244.211.31   hkk8snode001   <none>           <none>

# 进入到 Pod 终端执行命令
➜ kubectl exec -it test-flexvolume mount | grep test
kubectl exec [POD] [COMMAND] is DEPRECATED and will be removed in a future version. Use kubectl exec [POD] -- [COMMAND] instead.
192.168.178.35:/var/lib/k8s/data/testflexvolume on /usr/share/nginx/html type nfs4 (rw,relatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=192.168.178.36,local_lock=none,addr=192.168.178.35)

# 查看宿主机挂载情况
➜ mount | grep test # hkk8snode001节点上执行
192.168.178.35:/var/lib/k8s/data/test-volumes on /var/lib/containerd/kubelet/pods/9879ee68-8448-4b87-a122-ea52f18d431e/volume-subpaths/nfs-pv/web/0 type nfs4 (rw,relatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=192.168.178.36,local_lock=none,addr=192.168.178.35)
192.168.178.35:/var/lib/k8s/data on /var/lib/containerd/kubelet/pods/bcbb1fe9-87ab-4c52-9aaa-678d19e9337d/volumes/ydzs~nfs/test type nfs4 (rw,relatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=192.168.178.36,local_lock=none,addr=192.168.178.35)
192.168.178.35:/var/lib/k8s/data/testflexvolume on /var/lib/containerd/kubelet/pods/bcbb1fe9-87ab-4c52-9aaa-678d19e9337d/volume-subpaths/test/web/0 type nfs4 (rw,relatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=192.168.178.36,local_lock=none,addr=192.168.178.35)
```

同样我们可以查看到 Pod 的本地持久化目录是被 mount 到了 NFS 上面，证明上面我们的 FlexVolume 插件是正常的。

:::success
info "调用"

当我们要去真正的 mount NFS 的时候，就是通过 kubelet 调用 ``<font style="color:#DF2A3F;">VolumePlugin</font>``，然后直接执行命令``<font style="color:#DF2A3F;">/usr/libexec/kubernetes/kubelet-plugins/volume/exec/ydzs~nfs/nfs mount <mount dir> <json param></font>`` 来完成的，就相当于平时我们在宿主机上面手动挂载 NFS 的方式一样的，所以**<u><font style="color:#DF2A3F;">存储插件 nfs 是一个可执行的二进制文件或者 shell 脚本都是可以的</font></u>**。

:::

## 2 CSI
既然已经有了 `<font style="color:#DF2A3F;">FlexVolume</font>` 插件了，为什么还需要<font style="color:#DF2A3F;"> </font>`<font style="color:#DF2A3F;">CSI</font>` 插件呢？上面**<u>我们使用 FlexVolume 插件的时候可以看出 FlexVolume 插件实际上相当于就是一个普通的 shell 命令，类似于平时我们在 Linux 下面执行的 </u>**`**<u><font style="color:#DF2A3F;">ls</font></u>**`**<u> 命令一样，只是返回的信息是 JSON 格式的数据，并不是我们通常认为的一个常驻内存的进程，而 CSI 是一个更加完善、编码更加方便友好的一种存储插件扩展方式。</u>**

[CSI](https://kubernetes-csi.github.io/docs/) 是 `<font style="color:#DF2A3F;">Container Storage Interface</font>` 的简称，旨在能为容器编排引擎和存储系统间建立一套标准的存储调用接口，通过该接口能为容器编排引擎提供存储服务。在 CSI 之前，K8S 里提供存储服务基本上是通过 `<font style="color:#DF2A3F;">in-tree</font>`<font style="color:#DF2A3F;"> </font>的方式来提供，如下图：

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731583768161-cacc1cb6-1951-4520-9947-d47a041dc282.png)

这种方式需要将存储提供者的代码逻辑放到 K8S 的代码库中运行，调用引擎与插件间属于强耦合，这种方式会带来一些问题：

+ 存储插件需要一同随 K8S 发布
+ K8S 社区需要对存储插件的测试、维护负责
+ 存储插件的问题有可能会影响 K8S 部件正常运行
+ 存储插件享有 K8S 部件同等的特权存在安全隐患
+ 存储插件开发者必须遵循 K8S 社区的规则开发代码

基于这些问题和挑战，CO（Container Orchestrator） 厂商提出 Container Storage Interface 用来定义容器存储标准，<u><font style="color:#DF2A3F;">它独立于 Kubernetes Storage SIG，由 Kubernetes、Mesos、Cloud Foundry 三家一起推动。CSI 规范定义了存储提供商实现 CSI 兼容插件的最小操作集合和部署建议，CSI 规范的主要焦点是声明插件必须实现的接口。</font></u>

在 Kubernetes 上整合 CSI 插件的整体架构如下图所示：

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731583769536-32c4a056-294e-408c-9c78-b47a001499a4.png)

Kubernetes CSI 存储体系主要由两部分组成：

+ Kubernetes 外部组件：包含 `<font style="color:#DF2A3F;">Driver registrar</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">External provisioner</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">External attacher</font>` 三部分，这三个组件是从 Kubernetes 原本的 in-tree 存储体系中剥离出来的存储管理功能，实际上是 Kubernetes 中的一种外部 controller，它们 watch kubernetes 的 API 资源对象，根据 watch 到的状态来调用下面提到的第二部分的 CSI 插件来实现存储的管理和操作。这部分是 Kubernetes 团队维护的，插件开发者完全不必关心其实现细节。
    - `<font style="color:#DF2A3F;">Driver registra</font>`：一个 Sidecar 容器，向 Kubernetes 注册 CSI Driver，添加 Drivers 的一些信息
    - `<font style="color:#DF2A3F;">External provisioner</font>`：也是一个 Sidecar 容器，watch Kubernetes 的 PVC 对象，调用对应 CSI 的 Volum e 创建、删除等操作
    - `<font style="color:#DF2A3F;">External attacher</font>`：一个 Sidecar 容器，watch Kubernetes 系统里的 `<font style="color:#DF2A3F;">VolumeAttachment</font>` 对象，调用对应 CSI 的 ControllerPublish 和 ControllerUnpublish 操作来完成对应的 Volume 的 Attach/Detach。而 Volume 的 Mount/Unmount 阶段并不属于外部组件，当真正需要执行 Mount 操作的时候，kubelet 会去直接调用下面的 CSI Node 服务来完成 Volume 的 Mount/UnMount 操作。
+ CSI 存储插件: 这部分正是开发者需要实现的 CSI 插件部分，都是通过 gRPC 实现的服务，一般会用一个二进制文件对外提供服务，主要包含三部分：`<font style="color:#DF2A3F;">CSI Identity</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">CSI Controller</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">CSI Node</font>`。
    - `<font style="color:#DF2A3F;">CSI Identity</font>` — 主要用于负责对外暴露这个插件本身的信息，确保插件的健康状态。

```go
service Identity {
    // 返回插件的名称和版本
    rpc GetPluginInfo(GetPluginInfoRequest)
        returns (GetPluginInfoResponse) {}
    // 返回这个插件的包含的功能，比如非块存储类型的 CSI 插件不需要实现 Attach 功能，GetPluginCapabilities 就可以在返回中标注这个 CSI 插件不包含 Attach 功能
    rpc GetPluginCapabilities(GetPluginCapabilitiesRequest)
        returns (GetPluginCapabilitiesResponse) {}
    // 插件插件是否正在运行
    rpc Probe (ProbeRequest)
        returns (ProbeResponse) {}
}
```

    - `<font style="color:#DF2A3F;">CSI Controller</font>`<font style="color:#DF2A3F;"> </font>- 主要实现 Volume 管理流程当中的 Provision 和 Attach 阶段，Provision 阶段是指创建和删除 Volume 的流程，而 Attach 阶段是指把存储卷附着在某个节点或脱离某个节点的流程，另外只有块存储类型的 CSI 插件才需要 Attach 功能。

```go
service Controller {
    // 创建存储卷，包括云端存储介质以及PV对象
    rpc CreateVolume (CreateVolumeRequest)
        returns (CreateVolumeResponse) {}

    //  删除存储卷
    rpc DeleteVolume (DeleteVolumeRequest)
        returns (DeleteVolumeResponse) {}

    // 挂载存储卷，将存储介质挂载到目标节点
    rpc ControllerPublishVolume (ControllerPublishVolumeRequest)
        returns (ControllerPublishVolumeResponse) {}

    // 卸载存储卷
    rpc ControllerUnpublishVolume (ControllerUnpublishVolumeRequest)
        returns (ControllerUnpublishVolumeResponse) {}

    // 例如：是否可以同时用于多个节点的读/写
    rpc ValidateVolumeCapabilities (ValidateVolumeCapabilitiesRequest)
        returns (ValidateVolumeCapabilitiesResponse) {}

    // 返回所有可用的 volumes
    rpc ListVolumes (ListVolumesRequest)
        returns (ListVolumesResponse) {}

    // 可用存储池的总容量
    rpc GetCapacity (GetCapacityRequest)
        returns (GetCapacityResponse) {}

    // 例如. 插件可能未实现 GetCapacity、Snapshotting
    rpc ControllerGetCapabilities (ControllerGetCapabilitiesRequest)
        returns (ControllerGetCapabilitiesResponse) {}

    // 创建快照
    rpc CreateSnapshot (CreateSnapshotRequest)
        returns (CreateSnapshotResponse) {}

    // 删除指定的快照
    rpc DeleteSnapshot (DeleteSnapshotRequest)
        returns (DeleteSnapshotResponse) {}

    // 获取所有的快照
    rpc ListSnapshots (ListSnapshotsRequest)
        returns (ListSnapshotsResponse) {}
}
```

    - `<font style="color:#DF2A3F;">CSI Node</font>` — 负责控制 Kubernetes 节点上的 Volume 的相关功能。其中 Volume 的挂载被分成了 NodeStageVolume 和 NodePublishVolume 两个阶段。NodeStageVolume 接口主要是针对块存储类型的 CSI 插件而提供的，块设备在 "Attach" 阶段被附着在 Node 上后，需要挂载至 Pod 对应目录上，但因为块设备在 linux 上只能 mount 一次，而在 kubernetes volume 的使用场景中，一个 volume 可能被挂载进同一个 Node 上的多个 Pod 实例中，所以这里提供了 NodeStageVolume 这个接口，使用这个接口把块设备格式化后先挂载至 Node 上的一个临时全局目录，然后再调用 NodePublishVolume 使用 linux 中的 `<font style="color:#DF2A3F;">bind mount</font>` 技术把这个全局目录挂载进 Pod 中对应的目录上。

```go
service Node {
    // 在节点上初始化存储卷（格式化），并执行挂载到Global目录
    rpc NodeStageVolume (NodeStageVolumeRequest)
        returns (NodeStageVolumeResponse) {}

    // umount 存储卷在节点上的 Global 目录
    rpc NodeUnstageVolume (NodeUnstageVolumeRequest)
        returns (NodeUnstageVolumeResponse) {}

    // 在节点上将存储卷的 Global 目录挂载到 Pod 的实际挂载目录
    rpc NodePublishVolume (NodePublishVolumeRequest)
        returns (NodePublishVolumeResponse) {}

    // unmount 存储卷在节点上的 Pod 挂载目录
    rpc NodeUnpublishVolume (NodeUnpublishVolumeRequest)
        returns (NodeUnpublishVolumeResponse) {}

    // 获取节点上Volume挂载文件系统统计信息（总空间、可用空间等）
    rpc NodeGetVolumeStats (NodeGetVolumeStatsRequest)
        returns (NodeGetVolumeStatsResponse) {}

    // 获取节点的唯一 ID
    rpc NodeGetId (NodeGetIdRequest)
        returns (NodeGetIdResponse) {
        option deprecated = true;
    }

    // 返回节点插件的能力
    rpc NodeGetCapabilities (NodeGetCapabilitiesRequest)
        returns (NodeGetCapabilitiesResponse) {}

    // 获取节点的一些信息
    rpc NodeGetInfo (NodeGetInfoRequest)
        returns (NodeGetInfoResponse) {}
}
```

只需要实现上面的接口就可以实现一个 CSI 插件了。虽然 Kubernetes 并未规定 CSI 插件的打包安装，但是提供了以下建议来简化我们在 Kubernetes 上容器化 CSI Volume 驱动程序的部署方案，具体的方案介绍可以查看 CSI 规范介绍文档 [https://github.com/container-storage-interface/spec/blob/master/spec.md](https://github.com/container-storage-interface/spec/blob/master/spec.md)

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731583769957-27a04ee4-afcd-4a52-b4c7-1fd4fa29fbe5.png)

按照上图的推荐方案，`<font style="color:#DF2A3F;">CSI Controller</font>` 负责 Volumes 的创建删除等操作，整个集群只需要部署一个，以 StatefulSet 或者 Deployment 方式部署均可，`<font style="color:#DF2A3F;">CSI Node</font>`<font style="color:#DF2A3F;"> </font>部分负责 Volumes 的 attach、detach 等操作，需要在每个节点部署一个，所以用 DaemonSet 方式部署，因为这两部分实现在同一个 CSI 插件程序中，因此只需要把这个 CSI 插件与 `<font style="color:#DF2A3F;">External Components</font>` 以容器方式部署在同一个 Pod 中，把这个 CSI 插件与 `<font style="color:#DF2A3F;">Driver registrar</font>` 以容器方式部署在 DaemonSet 的 Pod 中，即可完成 CSI 的部署。

比如在训练营第一期中我们使用的 Rook 部署的 Ceph 集群就实现了 CSI 插件的:

```shell
➜ kubectl get pods -n rook-ceph | grep plugin
csi-cephfsplugin-2s9d5                                 3/3     Running     0          21d
csi-cephfsplugin-fgp4v                                 3/3     Running     0          17d
csi-cephfsplugin-fv5nx                                 3/3     Running     0          21d
csi-cephfsplugin-mn8q4                                 3/3     Running     0          17d
csi-cephfsplugin-nf6h8                                 3/3     Running     0          21d
csi-cephfsplugin-provisioner-56c8b7ddf4-68h6d          4/4     Running     0          21d
csi-cephfsplugin-provisioner-56c8b7ddf4-rq4t6          4/4     Running     0          21d
csi-cephfsplugin-xwnl4                                 3/3     Running     0          21d
csi-rbdplugin-7r88w                                    3/3     Running     0          21d
csi-rbdplugin-95g5j                                    3/3     Running     0          21d
csi-rbdplugin-bnzpr                                    3/3     Running     0          21d
csi-rbdplugin-dvftb                                    3/3     Running     0          21d
csi-rbdplugin-jzmj2                                    3/3     Running     0          17d
csi-rbdplugin-provisioner-6ff4dd4b94-bvtss             5/5     Running     0          21d
csi-rbdplugin-provisioner-6ff4dd4b94-lfn68             5/5     Running     0          21d
csi-rbdplugin-trxb4                                    3/3     Running     0          17d
```

这里其实是实现了 RBD 和 CephFS 两种 CSI，用 DaemonSet 在每个节点上运行了一个包含 `<font style="color:#DF2A3F;">Driver registra</font>` 容器的 Pod，当然和节点相关的操作比如 Mount/Unmount 也是在这个 Pod 里面执行的，其他的比如 Provision、Attach 都是在另外的 `<font style="color:#DF2A3F;">csi-rbdplugin-provisioner-xxx</font>` Pod 中执行的。

## 3 测试 Test
现在我们来测试通过 CSI 的形式使用 NFS 存储，当然首先我们需要在 Kubernetes 集群中安装 NFS CSI 的驱动，[https://github.com/kubernetes-csi/csi-driver-nfs](https://github.com/kubernetes-csi/csi-driver-nfs) 就是一个 NFS 的 CSI 驱动实现的项目。

如果能访问 Github 则可以直接使用下面的命令一键安装 NFS CSI 驱动程序：

```shell
➜ curl -skSL https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/deploy/install-driver.sh | bash -s master --
```

也可以本地安装：

```shell
➜ git clone https://github.com/kubernetes-csi/csi-driver-nfs.git
➜ cd csi-driver-nfs

# 如果 kubelet 目录发生了变动则需要修改 
# /var/lib/containerd/kubelet/pods | /var/lib/containerd/kubelet/plugins/csi-nfsplugin | /var/lib/containerd/kubelet/plugins_registry
# csi-driver-nfs/deploy/csi-nfs-controller.yaml
# csi-driver-nfs/deploy/csi-nfs-node.yaml
# 修改 Kubelet Pods 的目录路径即可
➜ ./deploy/install-driver.sh master local
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761535490217-a136fdf7-e76e-4b30-9522-2329f4142816.png)

和上面介绍的部署方式基本上也是一致的，首先会用 DaemonSet 的形式在每个节点上运行了一个包含 `<font style="color:#DF2A3F;">Driver registra</font>` 容器的 Pod，当然和节点相关的操作比如 Mount/Unmount 也是在这个 Pod 里面执行的，其他的比如 Provision、Attach 都是在另外的 `<font style="color:#DF2A3F;">csi-nfs-controller-xxx</font>` Pod 中执行的。

```shell
➜ kubectl -n kube-system get pod -o wide -l app=csi-nfs-controller
NAME                                  READY   STATUS    RESTARTS        AGE     IP               NODE           NOMINATED NODE   READINESS GATES
csi-nfs-controller-7745b75676-r57l6   5/5     Running   5 (3m18s ago)   8m15s   192.168.178.36   hkk8snode001   <none>           <none>

➜ kubectl -n kube-system get pod -o wide -l app=csi-nfs-node
NAME                 READY   STATUS    RESTARTS   AGE   IP               NODE             NOMINATED NODE   READINESS GATES
csi-nfs-node-gqqmj   3/3     Running   0          45s   192.168.178.37   hkk8snode002     <none>           <none>
csi-nfs-node-x54xw   3/3     Running   0          45s   192.168.178.35   hkk8smaster001   <none>           <none>
csi-nfs-node-z68cz   3/3     Running   0          45s   192.168.178.36   hkk8snode001     <none>           <none>
```

当 csi 的驱动安装完成后我们就可以通过 CSI 的方式来使用我们的 NFS 存储了。

比如我们创建

```yaml
# pv-nfs-csi.yaml
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-nfs
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  mountOptions:
    - hard
    - nfsvers=4.1
  csi:
    driver: nfs.csi.k8s.io
    readOnly: false
    volumeHandle: unique-volumeid # make sure it's a unique id in the cluster
    volumeAttributes:
      server: 192.168.178.35
      share: /var/lib/k8s/data
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: pvc-nfs-static
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
  volumeName: pv-nfs
  storageClassName: ''
```

直接创建上面的资源对象后我们的 PV 和 PVC 就绑定在一起了：

```shell
# 引用资源清单文件
➜ kubectl create -f pv-nfs-csi.yaml 
persistentvolume/pv-nfs created
persistentvolumeclaim/pvc-nfs-static created

➜ kubectl get pv pv-nfs
NAME     CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                    STORAGECLASS   REASON   AGE
pv-nfs   10Gi       RWX            Retain           Bound    default/pvc-nfs-static                           15s

➜ kubectl get pvc pvc-nfs-static
NAME             STATUS   VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
pvc-nfs-static   Bound    pv-nfs   10Gi       RWX                           30s
```

这里的核心配置是 PV 中的 `<font style="color:#DF2A3F;">csi</font>` 属性的配置，需要通过 `<font style="color:#DF2A3F;">csi.driver</font>` 来指定我们要使用的驱动名称，比如我们这里使用 nfs 的名称为 `<font style="color:#DF2A3F;">nfs.csi.k8s.io</font>`，然后就是根据具体的驱动配置相关的参数。

同样还可以创建一个用于动态创建 PV 的 StorageClass 对象：

```yaml
# StorageClass-nfs-csi.yaml
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-csi
provisioner: nfs.csi.k8s.io
parameters:
  server: 192.168.178.35
  share: /var/lib/k8s/data
  # csi.storage.k8s.io/provisioner-secret is only needed for providing mountOptions in DeleteVolume
  # csi.storage.k8s.io/provisioner-secret-name: "mount-options"
  # csi.storage.k8s.io/provisioner-secret-namespace: "default"
reclaimPolicy: Delete # PV 回收策略
volumeBindingMode: Immediate
mountOptions:
  - hard
  - nfsvers=4.1
```

```shell
$ kubectl create -f StorageClass-nfs-csi.yaml 
storageclass.storage.k8s.io/nfs-csi created

$ kubectl get sc 
NAME                   PROVISIONER                                     RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-storage          kubernetes.io/no-provisioner                    Delete          WaitForFirstConsumer   false                  10h
nfs-client (default)   cluster.local/nfs-subdir-external-provisioner   Delete          Immediate              true                   60m
nfs-csi                nfs.csi.k8s.io                                  Delete          Immediate              false                  10s
```

对于我们普通用户来说使用起来都是一样的，只需要管理员提供何时的 PV 或 StorageClass 即可，这里我们就使用的 CSI 的形式来提供 NFS 的存储。

## 4 NFS CSI 与 NFS Provisioner 方式区别
### 4.1 NFS Provisioner（旧方式）
:::success
架构：

:::

+ 基于 Kubernetes 的 External Provisioner 机制
+ 通常使用 `<font style="color:#DF2A3F;">nfs-client-provisioner</font>` 或 `<font style="color:#DF2A3F;">nfs-subdir-external-provisioner</font>`
+ 是一个独立的 Pod，监听 PVC 创建事件

:::success
工作原理：

:::

PVC 创建 → Provisioner Pod 监听到 → 在 NFS 服务器上创建子目录 → 创建 PV 指向该子目录

:::success
特点：

:::

+ ✅ 简单易用，配置少
+ ✅ 自动在 NFS 共享目录下创建子目录
+ ❌ 使用旧的 In-Tree 或 External Provisioner 接口
+ ❌ 不符合 CSI 标准
+ ❌ 功能有限（只支持基本的创建/删除）
+ ❌ 未来可能被废弃

:::success
典型配置：

:::

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-client
provisioner: k8s-sigs.io/nfs-subdir-external-provisioner
parameters:
  archiveOnDelete: "false"
```

### 4.2 NFS CSI Driver（新方式，推荐）
:::success
架构：

:::

+ 基于 CSI（Container Storage Interface）标准
+ 包含多个组件：Controller、Node Plugin
+ 符合 Kubernetes 存储标准接口

:::success
工作原理：

:::

PVC 创建 → CSI Controller 处理 → CSI Node Plugin 在节点上挂载 NFS → 支持更多高级功能（快照、克隆等）

:::success
特点：

:::

+ ✅ 符合 CSI 标准，是未来方向
+ ✅ 功能更强大（支持快照、克隆、扩容等）
+ ✅ 更好的错误处理和监控
+ ✅ 社区活跃，持续维护
+ ✅ 可以与其他 CSI 驱动统一管理
+ ❌ 配置相对复杂
+ ❌ 需要部署更多组件

:::success
典型配置：

:::

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-csi
provisioner: nfs.csi.k8s.io
parameters:
  server: nfs-server.example.com
  share: /exported/path
  mountPermissions: "0755"
volumeBindingMode: Immediate
```

### 4.3  对比表格
| 特性 | NFS Provisioner | NFS CSI Driver |
| --- | --- | --- |
| **标准兼容性** | 基于旧版 External Provisioner | 完全符合 CSI 标准 |
| **架构复杂度** | 单 Pod | Controller + Node Plugin |
| **功能完整性** | 基础存储供应 | 支持快照/克隆/扩容/健康检查 |
| **社区支持** | 维护模式 | 活跃开发（Kubernetes 官方） |
| **错误处理能力** | 基础日志 | 完善的错误恢复机制 |
| **未来兼容性** | 可能废弃 | 长期支持 |


### 4.4  实际使用建议
选择 NFS Provisioner 如果：

+ 你只需要基本的动态供应功能
+ 想要快速搭建测试环境
+ 集群版本较老（< 1.20）

选择 NFS CSI Driver 如果：

+ 生产环境使用 ✅
+ 需要快照、克隆等高级功能
+ 希望使用标准化的存储接口
+ 计划长期维护

### 4.5 部署示例对比
NFS Provisioner 部署：

```shell
# 使用 Helm
$ helm repo add nfs-subdir-external-provisioner \
  https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
  
$ helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --set nfs.server=192.168.1.100 \
  --set nfs.path=/exported/path
```

NFS CSI Driver 部署：

```shell
# 使用 Helm
$ helm repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts

$ helm install csi-driver-nfs csi-driver-nfs/csi-driver-nfs \
  --namespace kube-system \
  --set kubeletDir=/var/lib/kubelet
```

### 4.6 总结
:::success
NFS Provisioner 是过渡方案，简单但功能有限；NFS CSI Driver 是未来标准，功能强大且符合 Kubernetes 存储发展方向。

<u><font style="color:#DF2A3F;">对于新项目，强烈推荐使用 NFS CSI Driver。</font></u>

:::



