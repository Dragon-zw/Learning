我们知道很早之前的 Docker Engine 中就有了 containerd，只不过现在是将 containerd 从 Docker Engine 里分离出来，作为一个独立的开源项目，目标是提供一个更加开放、稳定的容器运行基础设施。分离出来的 containerd 将具有更多的功能，涵盖整个容器运行时管理的所有需求，提供更强大的支持。

containerd 是一个工业级标准的容器运行时，它强调**简单性**、**健壮性**和**可移植性**，containerd 可以负责干下面这些事情：

+ 管理容器的生命周期（从创建容器到销毁容器）
+ 拉取/推送容器镜像
+ 存储管理（管理镜像及容器数据的存储）
+ 调用 runc 运行容器（与 runc 等容器运行时交互）
+ 管理容器网络接口及网络

## 1 Containerd 架构
containerd 可用作 Linux 和 Windows 的守护程序，它管理其主机系统完整的容器生命周期，从镜像传输和存储到容器执行和监测，再到底层存储到网络附件等等。

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1729995248644-cb6d262d-6e8a-4b3f-933d-80de13320e9b.png)

上图是 containerd 官方提供的架构图，可以看出 containerd 采用的也是 C/S 架构，服务端通过 unix domain socket 暴露低层的 gRPC API 接口出去，客户端通过这些 API 管理节点上的容器，每个 containerd 只负责一台机器，Pull 镜像，对容器的操作（启动、停止等），网络，存储都是由 containerd 完成。具体运行容器由 runc 负责，实际上只要是符合 OCI 规范的容器都可以支持。

为了解耦，containerd 将系统划分成了不同的组件，每个组件都由一个或多个模块协作完成（Core 部分），每一种类型的模块都以插件的形式集成到 Containerd 中，而且插件之间是相互依赖的，例如，上图中的每一个长虚线的方框都表示一种类型的插件，包括 Service Plugin、Metadata Plugin、GC Plugin、Runtime Plugin 等，其中 Service Plugin 又会依赖 Metadata Plugin、GC Plugin 和 Runtime Plugin。每一个小方框都表示一个细分的插件，例如 Metadata Plugin 依赖 Containers Plugin、Content Plugin 等。比如:

+ `<font style="color:#DF2A3F;">Content Plugin</font>`: 提供对镜像中可寻址内容的访问，所有不可变的内容都被存储在这里。
+ `<font style="color:#DF2A3F;">Snapshot Plugin</font>`: 用来管理容器镜像的文件系统快照，镜像中的每一层都会被解压成文件系统快照，类似于 Docker 中的 graphdriver。

**<u><font style="color:#DF2A3F;">总体来看 containerd 可以分为三个大块：Storage、Metadata 和 Runtime。</font></u>**

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1729995248451-18698761-6868-4269-8dda-c570fe941301.png)

## 2 安装 Containerd
这里我使用的系统是 `<font style="color:#DF2A3F;">CentOS 7.6</font>`，首先需要安装 `<font style="color:#DF2A3F;">seccomp</font>`<font style="color:#DF2A3F;"> </font>依赖：

```shell
➜  ~ rpm -qa |grep libseccomp
libseccomp-2.3.1-4.el7.x86_64
# 如果没有安装 libseccomp 包则执行下面的命令安装依赖
➜  ~ yum install wget -y
➜  ~ wget http://mirror.centos.org/centos/7/os/x86_64/Packages/libseccomp-2.3.1-4.el7.x86_64.rpm
➜  ~ yum install libseccomp-2.3.1-4.el7.x86_64.rpm -y
```

如果是使用 RHEL 8.8 的系统。

```shell
$ rpm -qa |grep libseccomp
libseccomp-2.5.2-1.el8.x86_64
```

由于 containerd 需要调用 runc，所以我们也需要先安装 runc，不过 containerd 提供了一个包含相关依赖的压缩包 `<font style="color:#DF2A3F;">cri-containerd-cni-${VERSION}.${OS}-${ARCH}.tar.gz</font>`，可以直接使用这个包来进行安装。首先从 [release 页面](https://github.com/containerd/containerd/releases)下载最新版本的压缩包，当前为 `<font style="color:#DF2A3F;">1.5.5</font>` 版本（最新的 `<font style="color:#DF2A3F;">1.5.7</font>` 版本在 CentOS7 下面执行 runc 会报错：[https://github.com/containerd/containerd/issues/6091](https://github.com/containerd/containerd/issues/6091)）：

```shell
➜  ~ wget https://github.com/containerd/containerd/releases/download/v1.5.5/cri-containerd-cni-1.5.5-linux-amd64.tar.gz
# 如果有限制，也可以替换成下面的 URL 加速下载
# wget https://download.fastgit.org/containerd/containerd/releases/download/v1.5.5/cri-containerd-cni-1.5.5-linux-amd64.tar.gz
```

可以通过 tar 的 `-t` 选项直接看到压缩包中包含哪些文件：

```shell
➜  ~ tar -tf cri-containerd-cni-1.5.5-linux-amd64.tar.gz
etc/
etc/cni/
etc/cni/net.d/
etc/cni/net.d/10-containerd-net.conflist
etc/crictl.yaml
etc/systemd/
etc/systemd/system/
etc/systemd/system/containerd.service
usr/
usr/local/
usr/local/bin/
usr/local/bin/containerd-shim-runc-v2
usr/local/bin/ctr
usr/local/bin/containerd-shim
usr/local/bin/containerd-shim-runc-v1
usr/local/bin/crictl
usr/local/bin/critest
usr/local/bin/containerd
usr/local/sbin/
usr/local/sbin/runc
opt/
opt/cni/
opt/cni/bin/
opt/cni/bin/vlan
opt/cni/bin/host-local
opt/cni/bin/flannel
opt/cni/bin/bridge
opt/cni/bin/host-device
opt/cni/bin/tuning
opt/cni/bin/firewall
opt/cni/bin/bandwidth
opt/cni/bin/ipvlan
opt/cni/bin/sbr
opt/cni/bin/dhcp
opt/cni/bin/portmap
opt/cni/bin/ptp
opt/cni/bin/static
opt/cni/bin/macvlan
opt/cni/bin/loopback
opt/containerd/
opt/containerd/cluster/
opt/containerd/cluster/version
opt/containerd/cluster/gce/
opt/containerd/cluster/gce/cni.template
opt/containerd/cluster/gce/configure.sh
opt/containerd/cluster/gce/cloud-init/
opt/containerd/cluster/gce/cloud-init/master.yaml
opt/containerd/cluster/gce/cloud-init/node.yaml
opt/containerd/cluster/gce/env
```

直接将压缩包解压到系统的各个目录中：

```shell
➜  ~ tar -C / -xzf cri-containerd-cni-1.5.5-linux-amd64.tar.gz
```

当然要记得将 `/usr/local/bin` 和 `/usr/local/sbin` 追加到 `~/.bashrc` 文件的 `PATH` 环境变量中：

```shell
export PATH=$PATH:/usr/local/bin:/usr/local/sbin
```

然后执行下面的命令使其立即生效：

```shell
➜  ~ source ~/.bashrc
```

containerd 的默认配置文件为 `<font style="color:#DF2A3F;">/etc/containerd/config.toml</font>`，我们可以通过如下所示的命令生成一个默认的配置：

```shell
➜  ~ mkdir -p /etc/containerd
➜  ~ containerd config default > /etc/containerd/config.toml
```

由于上面我们下载的 containerd 压缩包中包含一个 `<font style="color:#DF2A3F;">etc/systemd/system/containerd.service</font>` 的文件，这样我们就可以通过 systemd 来配置 containerd 作为守护进程运行了，内容如下所示：

```shell
➜  ~ cat /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd

Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=1048576
# Comment TasksMax if your systemd version does not supports it.
# Only systemd 226 and above support this version.
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
```

这里有两个重要的参数：

+ `<font style="color:#DF2A3F;">Delegate</font>`: <u>这个选项</u><u><font style="color:#DF2A3F;">允许 containerd 以及运行时自己管理自己创建容器的 cgroups</font></u><u>。如果</u><u><font style="color:#DF2A3F;">不设置这个选项，systemd 就会将进程移到自己的 cgroups 中，从而导致 containerd 无法正确获取容器的资源使用情况。</font></u>
+ `<font style="color:#DF2A3F;">KillMode</font>`: <u>这个选项</u><u><font style="color:#DF2A3F;">用来处理 containerd 进程被杀死的方式</font></u><u>。</u><u><font style="color:#DF2A3F;">默认情况下，systemd 会在进程的 cgroup 中查找并杀死 containerd 的所有子进程。KillMode 字段可以设置的值如下</font></u><u>。</u>
    - `control-group`（默认值）：当前控制组里面的所有子进程，都会被杀掉
    - `<u><font style="color:#DF2A3F;">process</font></u>`<u><font style="color:#DF2A3F;">：只杀主进程</font></u>
    - `mixed`：主进程将收到 SIGTERM 信号，子进程收到 SIGKILL 信号
    - `none`：没有进程会被杀掉，只是执行服务的 stop 命令

我们<u><font style="color:#DF2A3F;">需要将 KillMode 的值设置为 </font></u>`<u><font style="color:#DF2A3F;">process</font></u>`<u><font style="color:#DF2A3F;">，这样可以确保升级或重启 containerd 时不杀死现有的容器。</font></u>

现在我们就可以启动 containerd 了，直接执行下面的命令即可：

```shell
➜  ~ systemctl enable containerd --now
```

启动完成后就可以使用 containerd 的本地 CLI 工具 `<font style="color:#DF2A3F;">ctr</font>`<font style="color:#DF2A3F;"> </font>了，比如查看版本：

```shell
# 使用了 RHEL 8.8 OS
$ ctr version 
Client:
  Version:  v1.7.7
  Revision: 8c087663b0233f6e6e2f4515cee61d49f14746a8
  Go version: go1.20.8

Server:
  Version:  v1.7.7
  Revision: 8c087663b0233f6e6e2f4515cee61d49f14746a8
  UUID: 39f40971-eb98-41b6-a0a8-f8d67a59cca3
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761929413779-5b2ac705-b013-4fb2-b51e-710c1bec8d9d.png)

## 3 配置
我们首先来查看下上面默认生成的配置文件 `<font style="color:#DF2A3F;">/etc/containerd/config.toml</font>`：

```toml
disabled_plugins = []
imports = []
oom_score = 0
plugin_dir = ""
required_plugins = []
root = "/var/lib/containerd"
state = "/run/containerd"
version = 2

[cgroup]
  path = ""

[debug]
  address = ""
  format = ""
  gid = 0
  level = ""
  uid = 0

[grpc]
  address = "/run/containerd/containerd.sock"
  gid = 0
  max_recv_message_size = 16777216
  max_send_message_size = 16777216
  tcp_address = ""
  tcp_tls_cert = ""
  tcp_tls_key = ""
  uid = 0

[metrics]
  address = ""
  grpc_histogram = false

[plugins]

  [plugins."io.containerd.gc.v1.scheduler"]
    deletion_threshold = 0
    mutation_threshold = 100
    pause_threshold = 0.02
    schedule_delay = "0s"
    startup_delay = "100ms"

  [plugins."io.containerd.grpc.v1.cri"]
    disable_apparmor = false
    disable_cgroup = false
    disable_hugetlb_controller = true
    disable_proc_mount = false
    disable_tcp_service = true
    enable_selinux = false
    enable_tls_streaming = false
    ignore_image_defined_volumes = false
    max_concurrent_downloads = 3
    max_container_log_line_size = 16384
    netns_mounts_under_state_dir = false
    restrict_oom_score_adj = false
    sandbox_image = "k8s.gcr.io/pause:3.5"
    selinux_category_range = 1024
    stats_collect_period = 10
    stream_idle_timeout = "4h0m0s"
    stream_server_address = "127.0.0.1"
    stream_server_port = "0"
    systemd_cgroup = false
    tolerate_missing_hugetlb_controller = true
    unset_seccomp_profile = ""

    [plugins."io.containerd.grpc.v1.cri".cni]
      bin_dir = "/opt/cni/bin"
      conf_dir = "/etc/cni/net.d"
      conf_template = ""
      max_conf_num = 1

    [plugins."io.containerd.grpc.v1.cri".containerd]
      default_runtime_name = "runc"
      disable_snapshot_annotations = true
      discard_unpacked_layers = false
      no_pivot = false
      snapshotter = "overlayfs"

      [plugins."io.containerd.grpc.v1.cri".containerd.default_runtime]
        base_runtime_spec = ""
        container_annotations = []
        pod_annotations = []
        privileged_without_host_devices = false
        runtime_engine = ""
        runtime_root = ""
        runtime_type = ""

        [plugins."io.containerd.grpc.v1.cri".containerd.default_runtime.options]

      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]

        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          base_runtime_spec = ""
          container_annotations = []
          pod_annotations = []
          privileged_without_host_devices = false
          runtime_engine = ""
          runtime_root = ""
          runtime_type = "io.containerd.runc.v2"

          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            BinaryName = ""
            CriuImagePath = ""
            CriuPath = ""
            CriuWorkPath = ""
            IoGid = 0
            IoUid = 0
            NoNewKeyring = false
            NoPivotRoot = false
            Root = ""
            ShimCgroup = ""
            SystemdCgroup = false

      [plugins."io.containerd.grpc.v1.cri".containerd.untrusted_workload_runtime]
        base_runtime_spec = ""
        container_annotations = []
        pod_annotations = []
        privileged_without_host_devices = false
        runtime_engine = ""
        runtime_root = ""
        runtime_type = ""

        [plugins."io.containerd.grpc.v1.cri".containerd.untrusted_workload_runtime.options]

    [plugins."io.containerd.grpc.v1.cri".image_decryption]
      key_model = "node"

    [plugins."io.containerd.grpc.v1.cri".registry]
      config_path = ""

      [plugins."io.containerd.grpc.v1.cri".registry.auths]

      [plugins."io.containerd.grpc.v1.cri".registry.configs]

      [plugins."io.containerd.grpc.v1.cri".registry.headers]

      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]

    [plugins."io.containerd.grpc.v1.cri".x509_key_pair_streaming]
      tls_cert_file = ""
      tls_key_file = ""

  [plugins."io.containerd.internal.v1.opt"]
    path = "/opt/containerd"

  [plugins."io.containerd.internal.v1.restart"]
    interval = "10s"

  [plugins."io.containerd.metadata.v1.bolt"]
    content_sharing_policy = "shared"

  [plugins."io.containerd.monitor.v1.cgroups"]
    no_prometheus = false

  [plugins."io.containerd.runtime.v1.linux"]
    no_shim = false
    runtime = "runc"
    runtime_root = ""
    shim = "containerd-shim"
    shim_debug = false

  [plugins."io.containerd.runtime.v2.task"]
    platforms = ["linux/amd64"]

  [plugins."io.containerd.service.v1.diff-service"]
    default = ["walking"]

  [plugins."io.containerd.snapshotter.v1.aufs"]
    root_path = ""

  [plugins."io.containerd.snapshotter.v1.btrfs"]
    root_path = ""

  [plugins."io.containerd.snapshotter.v1.devmapper"]
    async_remove = false
    base_image_size = ""
    pool_name = ""
    root_path = ""

  [plugins."io.containerd.snapshotter.v1.native"]
    root_path = ""

  [plugins."io.containerd.snapshotter.v1.overlayfs"]
    root_path = ""

  [plugins."io.containerd.snapshotter.v1.zfs"]
    root_path = ""

[proxy_plugins]

[stream_processors]

  [stream_processors."io.containerd.ocicrypt.decoder.v1.tar"]
    accepts = ["application/vnd.oci.image.layer.v1.tar+encrypted"]
    args = ["--decryption-keys-path", "/etc/containerd/ocicrypt/keys"]
    env = ["OCICRYPT_KEYPROVIDER_CONFIG=/etc/containerd/ocicrypt/ocicrypt_keyprovider.conf"]
    path = "ctd-decoder"
    returns = "application/vnd.oci.image.layer.v1.tar"

  [stream_processors."io.containerd.ocicrypt.decoder.v1.tar.gzip"]
    accepts = ["application/vnd.oci.image.layer.v1.tar+gzip+encrypted"]
    args = ["--decryption-keys-path", "/etc/containerd/ocicrypt/keys"]
    env = ["OCICRYPT_KEYPROVIDER_CONFIG=/etc/containerd/ocicrypt/ocicrypt_keyprovider.conf"]
    path = "ctd-decoder"
    returns = "application/vnd.oci.image.layer.v1.tar+gzip"

[timeouts]
  "io.containerd.timeout.shim.cleanup" = "5s"
  "io.containerd.timeout.shim.load" = "5s"
  "io.containerd.timeout.shim.shutdown" = "3s"
  "io.containerd.timeout.task.state" = "2s"

[ttrpc]
  address = ""
  gid = 0
  uid = 0
```

这个配置文件比较复杂，我们可以将重点放在其中的 `<font style="color:#DF2A3F;">plugins</font>`<font style="color:#DF2A3F;"> </font>配置上面，仔细观察我们可以发现每一个顶级配置块的命名都是 `<font style="color:#DF2A3F;">plugins."io.containerd.xxx.vx.xxx"</font>` 这种形式，每一个顶级配置块都表示一个插件，其中 `<font style="color:#DF2A3F;">io.containerd.xxx.vx</font>` 表示插件的类型，`<font style="color:#DF2A3F;">vx</font>` 后面的 `<font style="color:#DF2A3F;">xxx</font>` 表示插件的 ID，我们可以通过 `<font style="color:#DF2A3F;">ctr</font>` 查看插件列表：

```shell
➜  ~ ctr plugin ls
TYPE                            ID                       PLATFORMS      STATUS
io.containerd.content.v1        content                  -              ok
io.containerd.snapshotter.v1    aufs                     linux/amd64    ok
io.containerd.snapshotter.v1    btrfs                    linux/amd64    skip
io.containerd.snapshotter.v1    devmapper                linux/amd64    error
io.containerd.snapshotter.v1    native                   linux/amd64    ok
io.containerd.snapshotter.v1    overlayfs                linux/amd64    ok
io.containerd.snapshotter.v1    zfs                      linux/amd64    skip
io.containerd.metadata.v1       bolt                     -              ok
io.containerd.differ.v1         walking                  linux/amd64    ok
io.containerd.gc.v1             scheduler                -              ok
io.containerd.service.v1        introspection-service    -              ok
io.containerd.service.v1        containers-service       -              ok
io.containerd.service.v1        content-service          -              ok
io.containerd.service.v1        diff-service             -              ok
io.containerd.service.v1        images-service           -              ok
io.containerd.service.v1        leases-service           -              ok
io.containerd.service.v1        namespaces-service       -              ok
io.containerd.service.v1        snapshots-service        -              ok
io.containerd.runtime.v1        linux                    linux/amd64    ok
io.containerd.runtime.v2        task                     linux/amd64    ok
io.containerd.monitor.v1        cgroups                  linux/amd64    ok
io.containerd.service.v1        tasks-service            -              ok
io.containerd.internal.v1       restart                  -              ok
io.containerd.grpc.v1           containers               -              ok
io.containerd.grpc.v1           content                  -              ok
io.containerd.grpc.v1           diff                     -              ok
io.containerd.grpc.v1           events                   -              ok
io.containerd.grpc.v1           healthcheck              -              ok
io.containerd.grpc.v1           images                   -              ok
io.containerd.grpc.v1           leases                   -              ok
io.containerd.grpc.v1           namespaces               -              ok
io.containerd.internal.v1       opt                      -              ok
io.containerd.grpc.v1           snapshots                -              ok
io.containerd.grpc.v1           tasks                    -              ok
io.containerd.grpc.v1           version                  -              ok
io.containerd.grpc.v1           cri                      linux/amd64    ok
```

顶级配置块下面的子配置块表示该插件的各种配置，比如 cri 插件下面就分为 containerd、cni 和 registry 的配置，而 containerd 下面又可以配置各种 runtime，还可以配置默认的 runtime。比如现在我们要为镜像配置一个加速器，那么就需要在 cri 配置块下面的 `<font style="color:#DF2A3F;">registry</font>`<font style="color:#DF2A3F;"> </font>配置块下面进行配置 `<font style="color:#DF2A3F;">registry.mirrors</font>`：

```toml
[plugins."io.containerd.grpc.v1.cri".registry]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
      endpoint = ["https://bqr1dr1n.mirror.aliyuncs.com"]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]
      endpoint = ["https://registry.aliyuncs.com/k8sxio"]
```

+ `<font style="color:#DF2A3F;">registry.mirrors."xxx"</font>`: 表示需要配置 mirror 的镜像仓库，例如 `<font style="color:#DF2A3F;">registry.mirrors."docker.io"</font>` 表示配置 `<font style="color:#DF2A3F;">docker.io</font>` 的 `<font style="color:#DF2A3F;">mirror</font>`。
+ `<font style="color:#DF2A3F;">endpoint</font>`: 表示提供 mirror 的镜像加速服务，比如我们可以注册一个阿里云的镜像服务来作为 `<font style="color:#DF2A3F;">docker.io</font>` 的 mirror。

另外在默认配置中还有两个关于存储的配置路径：

```toml
root = "/var/lib/containerd"
state = "/run/containerd"
```

其中 `<font style="color:#DF2A3F;">root</font>`<font style="color:#DF2A3F;"> </font>是用来保存持久化数据，包括 Snapshots，Content，Metadata 以及各种插件的数据，每一个插件都有自己单独的目录，Containerd 本身不存储任何数据，它的所有功能都来自于已加载的插件。

而另外的 `<font style="color:#DF2A3F;">state</font>`<font style="color:#DF2A3F;"> </font>是用来保存运行时的临时数据的，包括 sockets、pid、挂载点、运行时状态以及不需要持久化的插件数据。

## 4 ctr CLI 命令使用
我们知道 Docker CLI 工具提供了需要增强用户体验的功能，containerd 同样也提供一个对应的 CLI 工具：`<font style="color:#DF2A3F;">ctr</font>`，不过 ctr 的功能没有 docker 完善，但是关于镜像和容器的基本功能都是有的。接下来我们就先简单介绍下 `<font style="color:#DF2A3F;">ctr</font>`<font style="color:#DF2A3F;"> </font>的使用。

**帮助**

直接输入 `<font style="color:#DF2A3F;">ctr</font>`<font style="color:#DF2A3F;"> </font>命令即可获得所有相关的操作命令使用方式：

```shell
➜  ~ ctr
NAME:
   ctr -
        __
  _____/ /______
 / ___/ __/ ___/
/ /__/ /_/ /
\___/\__/_/

containerd CLI


USAGE:
   ctr [global options] command [command options] [arguments...]

VERSION:
   v1.5.5

DESCRIPTION:

ctr is an unsupported debug and administrative client for interacting
with the containerd daemon. Because it is unsupported, the commands,
options, and operations are not guaranteed to be backward compatible or
stable from release to release of the containerd project.

COMMANDS:
   plugins, plugin            provides information about containerd plugins
   version                    print the client and server versions
   containers, c, container   manage containers
   content                    manage content
   events, event              display containerd events
   images, image, i           manage images
   leases                     manage leases
   namespaces, namespace, ns  manage namespaces
   pprof                      provide golang pprof outputs for containerd
   run                        run a container
   snapshots, snapshot        manage snapshots
   tasks, t, task             manage tasks
   install                    install a new package
   oci                        OCI tools
   shim                       interact with a shim directly
   help, h                    Shows a list of commands or help for one command

GLOBAL OPTIONS:
   --debug                      enable debug output in logs
   --address value, -a value    address for containerd's GRPC server (default: "/run/containerd/containerd.sock") [$CONTAINERD_ADDRESS]
   --timeout value              total timeout for ctr commands (default: 0s)
   --connect-timeout value      timeout for connecting to containerd (default: 0s)
   --namespace value, -n value  namespace to use with commands (default: "default") [$CONTAINERD_NAMESPACE]
   --help, -h                   show help
   --version, -v                print the version
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760078458651-4d7b9e7e-2da3-4d18-a079-dccd2b572520.png)

### 4.1 镜像操作
#### 4.1.1 拉取镜像
拉取镜像可以使用 `<font style="color:#DF2A3F;">ctr image pull</font>` 来完成，比如拉取 Docker Hub 官方镜像 `<font style="color:#DF2A3F;">nginx:alpine</font>`，需要<font style="color:#DF2A3F;">注意的是镜像地址需要加上 </font>`<font style="color:#DF2A3F;">docker.io</font>`<font style="color:#DF2A3F;"> Host 地址</font>：

```shell
# 拉取镜像
➜  ~ ctr image pull docker.io/library/nginx:alpine
docker.io/library/nginx:alpine:                                                   resolved       |++++++++++++++++++++++++++++++++++++++| 
index-sha256:7c1b9a91514d1eb5288d7cd6e91d9f451707911bfaea9307a3acbc811d4aa82e:    done           |++++++++++++++++++++++++++++++++++++++| 
manifest-sha256:b03ccb7431a2e3172f5cbae96d82bd792935f33ecb88fbf2940559e475745c4e: done           |++++++++++++++++++++++++++++++++++++++| 
layer-sha256:76c9bcaa4163e6fb844375a66c86911591b942e01511e28eec442e187f667f4e:    done           |++++++++++++++++++++++++++++++++++++++| 
config-sha256:5e7abcdd20216bbeedf1369529564ffd60f830ed3540c477938ca580b645dff5:   done           |++++++++++++++++++++++++++++++++++++++| 
layer-sha256:2d35ebdb57d9971fea0cac1582aa78935adf8058b2cc32db163c98822e5dfa1b:    done           |++++++++++++++++++++++++++++++++++++++| 
layer-sha256:f80aba050eadb732c9571d549167ce0f71adce202ac619ae8786fe6c9eec3374:    done           |++++++++++++++++++++++++++++++++++++++| 
layer-sha256:621a51978ed7f4a65a4324aaf124c21292fd986ed107e731f860572233073798:    done           |++++++++++++++++++++++++++++++++++++++| 
layer-sha256:03e63548f2091b6073fb9744492242182874f6b2d2554c9f3a94455203a033f0:    done           |++++++++++++++++++++++++++++++++++++++| 
layer-sha256:83ce83cd996042dd16a6124be94e6046da71a9c6b59a6cc48704f6cffca76d7d:    done           |++++++++++++++++++++++++++++++++++++++| 
layer-sha256:e2d0ea5d3690e523d1c4fc7f288e0b98b6c405d5880fa11d1637483fd5afc74c:    done           |++++++++++++++++++++++++++++++++++++++| 
layer-sha256:7fb80c2f28bc872ae84429312ddfbc823aca17b7ce107a0f24074294cd3beac5:    done           |++++++++++++++++++++++++++++++++++++++| 
elapsed: 7.2 s                                                                    total:  17.9 M (2.5 MiB/s)                                       
unpacking linux/amd64 sha256:7c1b9a91514d1eb5288d7cd6e91d9f451707911bfaea9307a3acbc811d4aa82e...
done: 39.881972155s
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760078767452-e9fdc436-1b73-441b-b649-c95fa5a48176.png)

也可以使用 `<font style="color:#DF2A3F;">--platform</font>` 选项指定对应平台的镜像。当然对应的也有推送镜像的命令 `ctr image push`，如果是私有镜像则在推送的时候可以通过 `<font style="color:#DF2A3F;">--user</font>` 来自定义仓库的用户名和密码。

#### 4.1.2 列出本地镜像
```shell
# 拉取本地镜像
➜  ~ ctr image ls
REF                            TYPE                                                      DIGEST                                                                  SIZE    PLATFORMS                                                                                LABELS
docker.io/library/nginx:alpine application/vnd.docker.distribution.manifest.list.v2+json sha256:bead42240255ae1485653a956ef41c9e458eb077fcb6dc664cbc3aa9701a05ce 9.5 MiB linux/386,linux/amd64,linux/arm/v6,linux/arm/v7,linux/arm64/v8,linux/ppc64le,linux/s390x -

# 只打印镜像的名称
➜  ~ ctr image ls -q
docker.io/library/nginx:alpine
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760078806575-2d9132d2-b7f0-448d-9c9c-baf884af7923.png)

使用 `<font style="color:#DF2A3F;">-q（--quiet）</font>` 选项可以只打印镜像名称。

#### 4.1.3 检测本地镜像
```shell
# 检测本地镜像
# 只要是 complete 状态表示镜像是完整可用的状态
➜  ~ ctr image check
REF                            TYPE                                                      DIGEST                                                                  STATUS         SIZE            UNPACKED
docker.io/library/nginx:alpine application/vnd.docker.distribution.manifest.list.v2+json sha256:bead42240255ae1485653a956ef41c9e458eb077fcb6dc664cbc3aa9701a05ce complete (7/7) 9.5 MiB/9.5 MiB true
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760078825108-d8617f19-b902-4bb2-86da-41e25e034997.png)

主要查看其中的 `<font style="color:#DF2A3F;">STATUS</font>`，`<font style="color:#DF2A3F;">complete</font>`<font style="color:#DF2A3F;"> </font>表示镜像是完整可用的状态。

#### 4.1.4 重新打标签
同样的我们也可以重新给指定的镜像打一个 Tag：

```shell
# 镜像重新打标签
➜  ~ ctr image tag docker.io/library/nginx:alpine harbor.k8s.local/course/nginx:alpine
harbor.k8s.local/course/nginx:alpine

# 只显示镜像名称
➜  ~ ctr image ls -q
docker.io/library/nginx:alpine
harbor.k8s.local/course/nginx:alpine
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760085960001-7b3efeac-e8ce-4e8c-8e33-472a3b752f52.png)

#### 4.1.5 删除镜像
不需要使用的镜像也可以使用 `<font style="color:#DF2A3F;">ctr image rm</font>` 进行删除：

```shell
# 删除镜像
➜  ~ ctr image rm harbor.k8s.local/course/nginx:alpine
harbor.k8s.local/course/nginx:alpine
➜  ~ ctr image ls -q
docker.io/library/nginx:alpine
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760085991914-04b97762-fc5e-459c-9a6b-7f723a742bfd.png)

加上 `<font style="color:#DF2A3F;">--sync</font>` 选项可以同步删除镜像和所有相关的资源。

#### 4.1.6 将镜像挂载到主机目录
```shell
# 将镜像挂载到主机目录
➜  ~ ctr image mount docker.io/library/nginx:alpine /mnt
sha256:c3554b2d61e3c1cffcaba4b4fa7651c644a3354efaafa2f22cb53542f6c600dc
/mnt

# 只显示一层的目录级别
➜  ~ tree -L 1 /mnt
/mnt
├── bin
├── dev
├── docker-entrypoint.d
├── docker-entrypoint.sh
├── etc
├── home
├── lib
├── media
├── mnt
├── opt
├── proc
├── root
├── run
├── sbin
├── srv
├── sys
├── tmp
├── usr
└── var

18 directories, 1 file

# 查看挂载情况
➜  ~ mount | grep /mnt 
overlay on /mnt type overlay (ro,relatime,lowerdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/97333/fs:/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/97332/fs:/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/97331/fs:/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/97330/fs:/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/97329/fs:/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/97328/fs:/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/97327/fs:/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/97326/fs)
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760086025483-66236f7e-e497-4ace-8a7c-aabaefccec78.png)

#### 4.1.7 将镜像从主机目录上卸载
```shell
# 将镜像从主机目录上卸载
➜  ~ ctr image unmount /mnt
/mnt
```

#### 4.1.8 将镜像导出为压缩包
```shell
# 拉取所有平台的镜像
➜  ~ ctr image pull --all-platforms docker.io/library/nginx:alpine
# 将镜像导出为压缩包
➜  ~ ctr image export --all-platforms nginx.tar.gz docker.io/library/nginx:alpine
➜  ~ ls -lh nginx.tar.gz
-rw-r--r-- 1 root root 173M Oct 11 16:21 nginx.tar.gz
```

#### 4.1.9 从压缩包导入镜像
```shell
# 删除镜像
➜  ~ ctr image rm --sync docker.io/library/nginx:alpine
docker.io/library/nginx:alpine

# 导入镜像
➜  ~ ctr image import nginx.tar.gz

# 查看镜像
➜  ~ ctr image ls
REF                            TYPE                                    DIGEST                                                                  SIZE     PLATFORMS                                                                                                              LABELS 
docker.io/library/nginx:alpine application/vnd.oci.image.index.v1+json sha256:7c1b9a91514d1eb5288d7cd6e91d9f451707911bfaea9307a3acbc811d4aa82e 21.5 MiB linux/386,linux/amd64,linux/arm/v6,linux/arm/v7,linux/arm64/v8,linux/ppc64le,linux/riscv64,linux/s390x,unknown/unknown -   

# 检测导入的镜像是否可用
➜  ~ ctr image check
REF                            TYPE                                    DIGEST                                                                  STATUS         SIZE              UNPACKED 
docker.io/library/nginx:alpine application/vnd.oci.image.index.v1+json sha256:61e01287e546aac28a3f56839c136b31f590273f3b41187a36f46f6a03bbfe22 complete (9/9) 21.5 MiB/21.5 MiB true
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760171058423-7cf01097-cb68-497b-95bb-986b81d43c49.png)

直接导入可能会出现类似于 `<font style="color:#DF2A3F;">ctr: content digest <sha256:xxxxxx> not found</font>` 的错误，要解决这个办法需要 Pull 所有平台镜像：

```shell
➜  ~ ctr image pull --all-platforms docker.io/library/nginx:alpine
➜  ~ ctr image export --all-platforms nginx.tar.gz docker.io/library/nginx:alpine
➜  ~ ctr image rm docker.io/library/nginx:alpine
➜  ~ ctr image import nginx.tar.gz
```

### 4.2 容器操作
容器相关操作可以通过 `<font style="color:#DF2A3F;">ctr container</font>`<font style="color:#DF2A3F;"> </font>获取。

#### 4.2.1 创建容器
```shell
# 创建容器
➜  ~ ctr container create docker.io/library/nginx:alpine nginx
```

#### 4.2.2 列出容器
```shell
# 列出容器
➜  ~ ctr container ls
CONTAINER    IMAGE                             RUNTIME
nginx        docker.io/library/nginx:alpine    io.containerd.runc.v2
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760171230661-3c521f04-d1b3-45ea-b053-3eccd57d2339.png)

同样可以加上 `<font style="color:#DF2A3F;">-q</font>` 选项精简列表内容：

```shell
# 只列出容器名称
➜  ~ ctr container ls -q
nginx
```

#### 4.2.3 查看容器详细配置
类似于 `<font style="color:#DF2A3F;">docker inspect</font>` 功能。使用命令：`<font style="color:#DF2A3F;">ctr container info <Container_ID | Container_NAME></font>`

```shell
# 查看容器详细配置
➜  ~ ctr container info nginx
{
    "ID": "nginx",
    "Labels": {
        "io.containerd.image.config.stop-signal": "SIGQUIT"
    },
    "Image": "docker.io/library/nginx:alpine",
    "Runtime": {
        "Name": "io.containerd.runc.v2",
        "Options": {
            "type_url": "containerd.runc.v1.Options"
        }
    },
    "SnapshotKey": "nginx",
    "Snapshotter": "overlayfs",
    "CreatedAt": "2021-08-12T08:23:13.792871558Z",
    "UpdatedAt": "2021-08-12T08:23:13.792871558Z",
    "Extensions": null,
    "Spec": {}
    ......
}
```

#### 4.2.4 删除容器
```shell
# 查看 Container 的参数
➜  ~ ctr container 
NAME:
   ctr containers - Manage containers

USAGE:
   ctr containers command [command options] [arguments...]

COMMANDS:
   create                   Create container
   delete, del, remove, rm  Delete one or more existing containers
   info                     Get info about a container
   list, ls                 List containers
   label                    Set and clear labels for a container
   checkpoint               Checkpoint a container
   restore                  Restore a container from checkpoint

OPTIONS:
   --help, -h  show help

# 删除容器
➜  ~ ctr container rm nginx
➜  ~ ctr container ls
CONTAINER    IMAGE    RUNTIME
```

除了使用 `<font style="color:#DF2A3F;">rm</font>`<font style="color:#DF2A3F;"> </font>子命令之外也可以使用 `<font style="color:#DF2A3F;">delete</font>`<font style="color:#DF2A3F;"> </font>或者 `<font style="color:#DF2A3F;">del</font>`<font style="color:#DF2A3F;"> </font>`<font style="color:#DF2A3F;">remove</font>`删除容器。

### 4.3 任务
上面我们通过 `_<u><font style="color:#DF2A3F;">container create</font></u>_`_<u> 命令创建的容器，并没有处于运行状态，只是一个静态的容器。</u>_一个 container 对象只是包含了运行一个容器所需的资源及相关配置数据，表示 namespaces、rootfs 和容器的配置都已经初始化成功了，只是用户进程还没有启动。

一个容器真正运行起来是由 Task 任务实现的，Task 可以为容器设置网卡，还可以配置工具来对容器进行监控等。

Task 相关操作可以通过 `<font style="color:#DF2A3F;">ctr task</font>`<font style="color:#DF2A3F;"> </font>获取，如下我们通过 Task 来启动容器：

```shell
# 查看任务的帮助信息
➜  ~ ctr task 
NAME:
   ctr tasks - Manage tasks

USAGE:
   ctr tasks command [command options] [arguments...]

COMMANDS:
   attach                   Attach to the IO of a running container
   checkpoint               Checkpoint a container
   delete, del, remove, rm  Delete one or more tasks
   exec                     Execute additional processes in an existing container
   list, ls                 List tasks
   kill                     Signal a container (default: SIGTERM)
   metrics, metric          Get a single data point of metrics for a task with the built-in Linux runtime
   pause                    Pause an existing container
   ps                       List processes for container
   resume                   Resume a paused container
   start                    Start a container that has been created

OPTIONS:
   --help, -h  show help
   
# -d 后台运行
➜  ~ ctr task start -d nginx
/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
```

启动容器后可以通过 `<font style="color:#DF2A3F;">task ls</font>` 查看正在运行的容器：

```shell
# 查看正在运行的容器
➜  ~ ctr task ls
TASK     PID       STATUS    
nginx    187007    RUNNING
```

同样也可以使用 `<font style="color:#DF2A3F;">exec</font>`<font style="color:#DF2A3F;"> </font>命令进入容器进行操作：

```shell
# 进入容器进行操作
➜  ~ ctr task exec --exec-id 0 -t nginx /bin/sh
/ # cat /etc/os-release 
NAME="Alpine Linux"
ID=alpine
VERSION_ID=3.22.2
PRETTY_NAME="Alpine Linux v3.22"
HOME_URL="https://alpinelinux.org/"
BUG_REPORT_URL="https://gitlab.alpinelinux.org/alpine/aports/-/issues"
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761135197915-48f5febb-5c44-4455-b4ef-b69a40e7e58f.png)

不过这里需要注意必须要指定 `<font style="color:#DF2A3F;">--exec-id</font>` 参数，这个 `<font style="color:#DF2A3F;">id</font>` 可以随便写，只要唯一就行。

暂停容器，和 `<font style="color:#DF2A3F;">docker pause</font>` 类似的功能：

```shell
# 暂停容器
➜  ~ ctr task pause nginx
```

暂停后容器状态变成了 `<font style="color:#DF2A3F;">PAUSED</font>`：

```shell
➜  ~ ctr task ls
TASK     PID       STATUS    
nginx    187007    PAUSED
```

同样也可以使用 `<font style="color:#DF2A3F;">resume</font>`<font style="color:#DF2A3F;"> </font>命令来恢复容器：

```shell
# 恢复容器
➜  ~ ctr task resume nginx
➜  ~ ctr task ls
TASK     PID       STATUS
nginx    187007    RUNNING
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760171736654-3a34b4cc-70e0-49c1-8313-11ca87bd0d7d.png)

不过需要注意 `<font style="color:#DF2A3F;">ctr</font>`<font style="color:#DF2A3F;"> </font>没有 `<font style="color:#DF2A3F;">stop</font>` 容器的功能，只能暂停或者杀死容器。杀死容器可以使用 `<font style="color:#DF2A3F;">task kill</font>` 命令:

```shell
# 杀死容器
➜  ~ ctr task kill nginx
➜  ~ ctr task ls
TASK     PID       STATUS
nginx    187007    STOPPED
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760171810120-497b6cf7-4c2f-4816-9dc4-1df94e43844b.png)

杀掉容器后可以看到容器的状态变成了 `<font style="color:#DF2A3F;">STOPPED</font>`。同样也可以通过 `<font style="color:#DF2A3F;">task rm</font>` 命令删除 Task：

```shell
# 删除 Task
➜  ~ ctr task rm nginx
➜  ~ ctr task ls
TASK    PID    STATUS
```

除此之外我们还可以获取容器的 cgroup 相关信息，可以使用 `<font style="color:#DF2A3F;">task metrics</font>` 命令用来获取容器的内存、CPU 和 PID 的限额与使用量。

```shell
# 用来获取容器的内存、CPU 和 PID 的限额与使用量
➜  ~ ctr task metrics nginx
ID       TIMESTAMP                              
nginx    seconds:1760171846  nanos:240400806    

METRIC                   VALUE                                                            
memory.usage_in_bytes    7565312                                                          
memory.limit_in_bytes    9223372036854771712                                              
memory.stat.cache        40960                                                            
cpuacct.usage            62543664                                                         
cpuacct.usage_percpu     [20656060 3104102 0 3494506 18662612 9238391 1622124 5765869]    
pids.current             9                                                                
pids.limit               0     
```

还可以使用 `<font style="color:#DF2A3F;">task ps</font>` 命令查看容器中所有进程在宿主机中的 PID：

```shell
# 查看容器中所有进程在宿主机中的 PID
➜  ~ ctr task ps nginx
PID     INFO
3984    -
4029    -
4030    -
4031    -
4032    -
4033    -
4034    -
4035    -
4036    -

➜  ~ ctr task ls
TASK     PID     STATUS
nginx    3984    RUNNING
```

其中第一个 PID `<font style="color:#DF2A3F;">3984</font>`<font style="color:#DF2A3F;"> </font>就是我们容器中的 1 号进程。

### 4.4 命名空间
另外 Containerd 中也支持命名空间的概念，比如查看命名空间：

```shell
# 查看命名空间
➜  ~ ctr ns ls
NAME    LABELS
default
```

如果不指定，`<font style="color:#DF2A3F;">ctr</font>` 默认使用的是 `<font style="color:#DF2A3F;">default</font>` 空间。同样也可以使用 `<font style="color:#DF2A3F;">ns create</font>` 命令创建一个命名空间：

```shell
# 创建一个命名空间
➜  ~ ctr ns create test
➜  ~ ctr ns ls
NAME    LABELS
default
test
```

使用 `<font style="color:#DF2A3F;">remove</font>`<font style="color:#DF2A3F;"> </font>或者 `<font style="color:#DF2A3F;">rm</font>`<font style="color:#DF2A3F;"> </font>可以删除 namespace：

```shell
# 删除 namespace
➜  ~ ctr ns rm test
test
➜  ~ ctr ns ls
NAME    LABELS
default
```

有了命名空间后就可以在操作资源的时候指定 namespace，比如查看 test 命名空间的镜像，可以在操作命令后面加上 `<font style="color:#DF2A3F;">-n test</font>` 选项：

```shell
➜  ~ ctr -n test image ls
REF TYPE DIGEST SIZE PLATFORMS LABELS
```

我们知道 Docker 其实也是默认调用的 <font style="color:#DF2A3F;">containerd</font>，事实上 Docker 使用的 <font style="color:#DF2A3F;">containerd</font> 下面的命名空间默认是 `<font style="color:#DF2A3F;">moby</font>`，而不是 `<font style="color:#DF2A3F;">default</font>`，所以假如我们有用 `<font style="color:#DF2A3F;">Docker</font>` 启动容器，那么我们也可以通过 `<font style="color:#DF2A3F;">ctr -n moby</font>` 来定位下面的容器：

```shell
➜  ~ ctr -n moby container ls
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760172646722-7cd2469f-0777-494e-baf0-1e5d60728077.png)

同样 Kubernetes 下使用的 `<font style="color:#DF2A3F;">containerd</font>` 默认命名空间是 `<font style="color:#DF2A3F;">k8s.io</font>`，所以我们可以使用 `<font style="color:#DF2A3F;">ctr -n k8s.io</font>` 来查看 Kubernetes 下面创建的容器。

<details class="lake-collapse"><summary id="u0a00efd1"><span class="ne-text">小总结</span></summary><pre data-language="shell" id="RauhR" class="ne-codeblock language-shell"><code>➜  ~ ctr ns ls 
NAME    LABELS 
default        
k8s.io         
moby           </code></pre><p id="u1c5c88f7" class="ne-p"><span class="ne-text">Containerd 的命名空间：</span></p><ul class="ne-ul"><li id="u3fe5d9f5" data-lake-index-type="0"><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">moby</span></code><span class="ne-text"> 命名空间是 Docker 所默认占用的命名空间</span></li><li id="ua4cd97aa" data-lake-index-type="0"><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">k8s.io</span></code><span class="ne-text"> 命名空间是 Kubernetes 所默认占用的命名空间</span></li></ul></details>
