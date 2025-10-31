现在我们使用 kubeadm 从头搭建一个使用 containerd 作为容器运行时的 Kubernetes 集群，这里我们安装最新的 `<font style="color:#DF2A3F;">v1.22.2</font>`<font style="color:#DF2A3F;"> </font>版本。

## 1 环境准备
3 个节点，都是 Centos 7.6 系统，内核版本：`<font style="color:#DF2A3F;">3.10.0-1062.4.1.el7.x86_64</font>`，在每个节点上添加 hosts 信息：

```shell
➜  ~ cat /etc/hosts
192.168.31.31 master1
192.168.31.108 node1
192.168.31.46 node2
# IP_ADDRESS HOSTNAME
```

节点的 hostname 必须使用标准的 DNS 命名，另外千万不用什么默认的`<font style="color:#DF2A3F;">localhost</font>`<font style="color:#DF2A3F;"> </font>的 hostname，会导致各种错误出现的。在 Kubernetes 项目里，机器的名字以及一切存储在 Etcd 中的 API 对象，都必须使用标准的 DNS 命名（RFC 1123）。可以使用命令 `<font style="color:#DF2A3F;">hostnamectl set-hostname node1</font>` 来修改 hostname。

禁用防火墙：

```shell
➜  ~ systemctl stop firewalld
➜  ~ systemctl disable firewalld
```

禁用 SELINUX：

```shell
➜  ~ setenforce 0
➜  ~ cat /etc/selinux/config
SELINUX=disabled
```

由于开启内核 ipv4 转发需要加载 br_netfilter 模块，所以加载下该模块：

```shell
➜  ~ modprobe br_netfilter
```

最好将上面的命令设置成开机启动，因为重启后模块失效，下面是开机自动加载模块的方式。首先新建 `<font style="color:#DF2A3F;">/etc/rc.sysinit</font>` 文件，内容如下所示：

```shell
#!/bin/bash
for file in /etc/sysconfig/modules/*.modules ; do
[ -x $file ] && $file
done
```

然后在 `<font style="color:#DF2A3F;">/etc/sysconfig/modules/</font>` 目录下新建如下文件：

```shell
➜  ~ cat /etc/sysconfig/modules/br_netfilter.modules
modprobe br_netfilter
```

增加权限：

```shell
➜  ~ chmod 755 br_netfilter.modules
```

然后重启后，模块就可以自动加载了：

```shell
➜  ~ lsmod |grep br_netfilter
br_netfilter           22209  0
bridge                136173  1 br_netfilter
```

创建 `/etc/sysctl.d/k8s.conf`文件，添加如下内容：

```shell
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
# 下面的内核参数可以解决ipvs模式下长连接空闲超时的问题
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 10
net.ipv4.tcp_keepalive_time = 600
```

:::color1
🏅信息

`<font style="color:#DF2A3F;">bridge-nf</font>` 使得 netfilter 可以对 Linux 网桥上的 IPv4/ARP/IPv6 包过滤。比如，设置`<font style="color:#DF2A3F;">net.bridge.bridge-nf-call-iptables＝1</font>`后，二层的网桥在转发包时也会被 iptables 的 FORWARD 规则所过滤。常用的选项包括：

+ `**<u>net.bridge.bridge-nf-call-arptables</u>**`**<u>：是否在 arptables 的 FORWARD 中过滤网桥的 ARP 包</u>**
+ `**<u>net.bridge.bridge-nf-call-ip6tables</u>**`**<u>：是否在 ip6tables 链中过滤 IPv6 包</u>**
+ `**<u>net.bridge.bridge-nf-call-iptables</u>**`**<u>：是否在 iptables 链中过滤 IPv4 包</u>**
+ `**<u>net.bridge.bridge-nf-filter-vlan-tagged</u>**`**<u>：是否在 iptables/arptables 中过滤打了 vlan 标签的包。 </u>**

:::

执行如下命令使修改生效：

```shell
➜  ~ sysctl -p /etc/sysctl.d/k8s.conf
```

安装 `<font style="color:#DF2A3F;">IPVS</font>`：

`**<font style="color:#DF2A3F;">/etc/sysconfig/modules/ipvs.modules</font>**`**文件**

```shell
➜  ~ cat > /etc/sysconfig/modules/ipvs.modules <<EOF
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4
EOF
➜  ~ chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules && lsmod | grep -e ip_vs -e nf_conntrack_ipv4
```

上面脚本创建了的 `<font style="color:#DF2A3F;">/etc/sysconfig/modules/ipvs.modules</font>`文件，保证在节点重启后能自动加载所需模块。使用 `<font style="color:#DF2A3F;">lsmod | grep -e ip_vs -e nf_conntrack_ipv4</font>`命令查看是否已经正确加载所需的内核模块。

接下来还需要确保各个节点上已经安装了 ipset 软件包：

```shell
➜  ~ yum install ipset
```

为了便于查看 ipvs 的代理规则，最好安装一下管理工具 ipvsadm：

```shell
➜  ~ yum install ipvsadm
```

同步服务器时间

```shell
# 安装时间同步
➜  ~ yum install chrony -y
➜  ~ systemctl enable chronyd
➜  ~ systemctl start chronyd

➜  ~ chronyc sources
210 Number of sources = 4
MS Name/IP address         Stratum Poll Reach LastRx Last sample
===============================================================================
^+ sv1.ggsrv.de                  2   6    17    32   -823us[-1128us] +/-   98ms
^- montreal.ca.logiplex.net      2   6    17    32    -17ms[  -17ms] +/-  179ms
^- ntp6.flashdance.cx            2   6    17    32    -32ms[  -32ms] +/-  161ms
^* 119.28.183.184                2   6    33    32   +661us[ +357us] +/-   38ms

➜  ~ date
Tue Aug 31 14:36:14 CST 2021
```

关闭 swap 分区：

```shell
➜  ~ swapoff -a
```

修改 `<font style="color:#DF2A3F;">/etc/fstab</font>`文件，注释掉 SWAP 的自动挂载，使用 `<font style="color:#DF2A3F;">free -m</font>`确认 swap 已经关闭。swappiness 参数调整，修改 `<font style="color:#DF2A3F;">/etc/sysctl.d/k8s.conf</font>`添加下面一行：

```shell
vm.swappiness=0
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 10
vm.max_map_count=262144
```

执行 `<font style="color:#DF2A3F;">sysctl -p /etc/sysctl.d/k8s.conf</font>` 使修改生效。

## 2 安装 Containerd
我们已经了解过容器运行时 containerd 的一些基本使用，接下来在各个节点上安装 Containerd。

如果这安装集群的过程出现了容器运行时的问题，启动不起来，可以尝试使用 `<font style="color:#DF2A3F;">yum install containerd.io</font>` 来安装 Containerd。

首先需要这节点商安装 `<font style="color:#DF2A3F;">seccomp</font>` 依赖：

```shell
➜  ~ rpm -qa |grep libseccomp
libseccomp-2.3.1-4.el7.x86_64
# 如果没有安装 libseccomp 包则执行下面的命令安装依赖
➜  ~ yum install wget -y
➜  ~ wget http://mirror.centos.org/centos/7/os/x86_64/Packages/libseccomp-2.3.1-4.el7.x86_64.rpm
➜  ~ yum install libseccomp-2.3.1-4.el7.x86_64.rpm -y
```

由于 containerd 需要调用 runc，所以我们也需要先安装 runc，不过 containerd 提供了一个包含相关依赖的压缩包 `<font style="color:#DF2A3F;">cri-containerd-cni-${VERSION}.${OS}-${ARCH}.tar.gz</font>`，可以直接使用这个包来进行安装。首先从 [release 页面](https://github.com/containerd/containerd/releases)下载最新版本的压缩包，当前为 1.5.5 版本（最新的 1.5.7 版本在 CentOS7 下面执行 runc 会报错：[https://github.com/containerd/containerd/issues/6091](https://github.com/containerd/containerd/issues/6091)）：

```shell
➜  ~ wget https://github.com/containerd/containerd/releases/download/v1.5.5/cri-containerd-cni-1.5.5-linux-amd64.tar.gz
# 如果有限制，也可以替换成下面的 URL 加速下载
# wget https://download.fastgit.org/containerd/containerd/releases/download/v1.5.5/cri-containerd-cni-1.5.5-linux-amd64.tar.gz
```

可以通过 tar 的 `<font style="color:#DF2A3F;">-t</font>` 选项直接看到压缩包中包含哪些文件：

由于 containerd 需要调用 runc，所以我们也需要先安装 runc，不过 containerd 提供了一个包含相关依赖的压缩包 `<font style="color:#DF2A3F;">cri-containerd-cni-${VERSION}.${OS}-${ARCH}.tar.gz</font>`，可以直接使用这个包来进行安装。首先从 [release 页面](https://github.com/containerd/containerd/releases)下载最新版本的压缩包，当前为 1.5.5 版本：

```shell
➜  ~ wget https://github.com/containerd/containerd/releases/download/v1.5.5/cri-containerd-cni-1.5.5-linux-amd64.tar.gz
# 如果有限制，也可以替换成下面的 URL 加速下载
# wget https://download.fastgit.org/containerd/containerd/releases/download/v1.5.5/cri-containerd-cni-1.5.5-linux-amd64.tar.gz
```

直接将压缩包解压到系统的各个目录中：

```shell
➜  ~ tar -C / -xzf cri-containerd-cni-1.5.5-linux-amd64.tar.gz
```

然后要将 `<font style="color:#DF2A3F;">/usr/local/bin</font>` 和 `<font style="color:#DF2A3F;">/usr/local/sbin</font>` 追加到 `<font style="color:#DF2A3F;">~/.bashrc</font>` 文件的 `<font style="color:#DF2A3F;">PATH</font>`<font style="color:#DF2A3F;"> </font>环境变量中：

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

对于使用 systemd 作为 init system 的 Linux 的发行版，使用 `<font style="color:#DF2A3F;">systemd</font>`<font style="color:#DF2A3F;"> </font>作为容器的 `<font style="color:#DF2A3F;">cgroup driver</font>` 可以确保节点在资源紧张的情况更加稳定，所以推荐将 containerd 的 cgroup driver 配置为 systemd。

修改前面生成的配置文件 `<font style="color:#DF2A3F;">/etc/containerd/config.toml</font>`，在 `<font style="color:#DF2A3F;">plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options</font>` 配置块下面将 `<font style="color:#DF2A3F;">SystemdCgroup</font>` 设置为 `<font style="color:#DF2A3F;">true</font>`：

```toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  ...
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true
    ....
```

然后再为镜像仓库配置一个加速器，需要在 cri 配置块下面的 `<font style="color:#DF2A3F;">registry</font>`<font style="color:#DF2A3F;"> </font>配置块下面进行配置 `<font style="color:#DF2A3F;">registry.mirrors</font>`：

```toml
[plugins."io.containerd.grpc.v1.cri"]
  ...
  # sandbox_image = "k8s.gcr.io/pause:3.5"
  sandbox_image = "registry.aliyuncs.com/k8sxio/pause:3.5"
  ...
  [plugins."io.containerd.grpc.v1.cri".registry]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
        endpoint = ["https://bqr1dr1n.mirror.aliyuncs.com"]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]
        endpoint = ["https://registry.aliyuncs.com/k8sxio"]
```

如果我们的节点不能正常获取 `<font style="color:#DF2A3F;">k8s.gcr.io</font>` 的镜像，那么我们需要在上面重新配置 `<font style="color:#DF2A3F;">sandbox_image</font>` 镜像，否则后面 kubelet 覆盖该镜像不会生效：`<font style="color:#DF2A3F;">Warning: For remote container runtime, --pod-infra-container-image is ignored in kubelet, which should be set in that remote runtime instead</font>`。

由于上面我们下载的 containerd 压缩包中包含一个 `<font style="color:#DF2A3F;">etc/systemd/system/containerd.service</font>` 的文件，这样我们就可以通过 systemd 来配置 containerd 作为守护进程运行了，现在我们就可以启动 containerd 了，直接执行下面的命令即可：

```shell
➜  ~ systemctl daemon-reload
➜  ~ systemctl enable containerd --now
```

启动完成后就可以使用 containerd 的本地 CLI 工具 `<font style="color:#DF2A3F;">ctr</font>`<font style="color:#DF2A3F;"> </font>和 `<font style="color:#DF2A3F;">crictl</font>`<font style="color:#DF2A3F;"> </font>了，比如查看版本：

```bash
# ctr 查看版本
➜  ~ ctr version
Client:
  Version:  v1.5.5
  Revision: 72cec4be58a9eb6b2910f5d10f1c01ca47d231c0
  Go version: go1.16.6

Server:
  Version:  v1.5.5
  Revision: 72cec4be58a9eb6b2910f5d10f1c01ca47d231c0
  UUID: cd2894ad-fd71-4ef7-a09f-5795c7eb4c3b

# crictl 查看版本
➜  ~ crictl version
Version:  0.1.0
RuntimeName:  containerd
RuntimeVersion:  v1.5.5
RuntimeApiVersion:  v1alpha2
```

## 3 使用 kubeadm 部署 Kubernetes
上面的相关环境配置也完成了，现在我们就可以来安装 Kubeadm 了，我们这里是通过指定 yum 源的方式来进行安装的：

```shell
➜  ~ cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
        https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
```

当然了，上面的 yum 源是需要科学上网的，如果不能科学上网的话，我们可以使用阿里云的源进行安装：

```shell
➜  ~ cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
        http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
```

然后安装 kubeadm、kubelet、kubectl：

```shell
# --disableexcludes 禁掉除了kubernetes之外的别的仓库
➜  ~ yum makecache fast
➜  ~ yum install -y kubelet-1.22.2 kubeadm-1.22.2 kubectl-1.22.2 --disableexcludes=kubernetes
➜  ~ kubeadm version
kubeadm version: &version.Info{Major:"1", Minor:"22", GitVersion:"v1.22.2", GitCommit:"8b5a19147530eaac9476b0ab82980b4088bbc1b2", GitTreeState:"clean", BuildDate:"2021-09-15T21:37:34Z", GoVersion:"go1.16.8", Compiler:"gc", Platform:"linux/amd64"}
```

可以看到我们这里安装的是 `<font style="color:#DF2A3F;">v1.22.2</font>` 版本，然后将 master 节点的 kubelet 设置成开机启动：

```shell
➜  ~ systemctl enable --now kubelet.service
➜  ~ systemctl status --no-pager -l kubelet.service 
● kubelet.service - kubelet: The Kubernetes Node Agent
   Loaded: loaded (/etc/systemd/system/kubelet.service; enabled; vendor preset: disabled)
  Drop-In: /etc/systemd/system/kubelet.service.d
           └─10-kubeadm.conf
   Active: active (running) since Mon 2025-10-13 16:35:58 HKT; 1h 32min ago
     Docs: https://kubernetes.io/docs/home/
 Main PID: 8938 (kubelet)
    Tasks: 20 (limit: 203828)
   Memory: 89.6M
   CGroup: /system.slice/kubelet.service
           └─8938 /usr/local/bin/kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --root-dir=/var/lib/containerd/kubelet --config=/var/lib/kubelet/config.yaml --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock --pod-infra-container-image=registry.k8s.io/pause:3.9 --tls-cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
```

到这里为止上面所有的操作都需要在所有节点执行配置。

### 3.1 初始化集群
当我们执行 `<font style="color:#DF2A3F;">kubelet --help</font>` 命令的时候可以看到原来大部分命令行参数都被 `<font style="color:#DF2A3F;">DEPRECATED</font>`了，这是因为官方推荐我们使用 `<font style="color:#DF2A3F;">--config</font>` 来指定配置文件，在配置文件中指定原来这些参数的配置，可以通过官方文档 [Set Kubelet parameters via a config file](https://kubernetes.io/docs/tasks/administer-cluster/kubelet-config-file/) 了解更多相关信息，这样 Kubernetes 就可以支持动态 Kubelet 配置（Dynamic Kubelet Configuration）了，参考 [Reconfigure a Node’s Kubelet in a Live Cluster](https://kubernetes.io/docs/tasks/administer-cluster/reconfigure-kubelet/)。

然后我们可以通过下面的命令在 master 节点上输出集群初始化默认使用的配置：

```shell
➜  ~ kubeadm config print init-defaults --component-configs KubeletConfiguration > kubeadm.yaml
```

然后根据我们自己的需求修改配置，比如修改 `<font style="color:#DF2A3F;">imageRepository</font>`<font style="color:#DF2A3F;"> </font>指定集群初始化时拉取 Kubernetes 所需镜像的地址，kube-proxy 的模式为 ipvs，另外需要注意的是我们这里是准备安装 flannel 网络插件的，需要将 `<font style="color:#DF2A3F;">networking.podSubnet</font>` 设置为 `<font style="color:#DF2A3F;">10.244.0.0/16</font>`：

:::color1
**kubeadm.yaml**

:::

```yaml
apiVersion: kubeadm.k8s.io/v1beta3
bootstrapTokens:
  - groups:
      - system:bootstrappers:kubeadm:default-node-token
    token: abcdef.0123456789abcdef
    ttl: 24h0m0s
    usages:
      - signing
      - authentication
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 192.168.31.31 # 指定master节点内网IP
  bindPort: 6443
nodeRegistration:
  criSocket: /run/containerd/containerd.sock # 使用 containerd的Unix socket 地址
  imagePullPolicy: IfNotPresent
  name: master
  taints: # 给master添加污点，master节点不能调度应用
    - effect: 'NoSchedule'
      key: 'node-role.kubernetes.io/master'

---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs # kube-proxy 模式

---
apiServer:
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta3
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager: {}
dns: {}
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: registry.aliyuncs.com/k8sxio
kind: ClusterConfiguration
kubernetesVersion: 1.22.2
networking:
  dnsDomain: cluster.local
  serviceSubnet: 10.96.0.0/12
  podSubnet: 10.244.0.0/16 # 指定 pod 子网
scheduler: {}

---
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    cacheTTL: 0s
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: 0s
    cacheUnauthorizedTTL: 0s
clusterDNS:
  - 10.96.0.10
clusterDomain: cluster.local
cpuManagerReconcilePeriod: 0s
evictionPressureTransitionPeriod: 0s
fileCheckFrequency: 0s
healthzBindAddress: 127.0.0.1
healthzPort: 10248
httpCheckFrequency: 0s
imageMinimumGCAge: 0s
kind: KubeletConfiguration
cgroupDriver: systemd # 配置 cgroup driver
logging: {}
memorySwap: {}
nodeStatusReportFrequency: 0s
nodeStatusUpdateFrequency: 0s
rotateCertificates: true
runtimeRequestTimeout: 0s
shutdownGracePeriod: 0s
shutdownGracePeriodCriticalPods: 0s
staticPodPath: /etc/kubernetes/manifests
streamingConnectionIdleTimeout: 0s
syncFrequency: 0s
volumeStatsAggPeriod: 0s
```

对于上面的资源清单的文档比较杂，要想完整了解上面的资源对象对应的属性，可以查看对应的 godoc 文档，地址：`[https://godoc.org/k8s.io/kubernetes/cmd/kubeadm/app/apis/kubeadm/v1beta3](https://godoc.org/k8s.io/kubernetes/cmd/kubeadm/app/apis/kubeadm/v1beta3)`。 

在开始初始化集群之前可以使用 `<font style="color:#DF2A3F;">kubeadm config images pull --config kubeadm.yaml</font>` 预先在各个服务器节点上拉取所 Kubernetes 需要的容器镜像。

配置文件准备好过后，可以使用如下命令先将相关镜像 pull 下面：

```shell
➜  ~ kubeadm config images pull --config kubeadm.yaml
[config/images] Pulled registry.aliyuncs.com/k8sxio/kube-apiserver:v1.22.2
[config/images] Pulled registry.aliyuncs.com/k8sxio/kube-controller-manager:v1.22.2
[config/images] Pulled registry.aliyuncs.com/k8sxio/kube-scheduler:v1.22.2
[config/images] Pulled registry.aliyuncs.com/k8sxio/kube-proxy:v1.22.2
[config/images] Pulled registry.aliyuncs.com/k8sxio/pause:3.5
[config/images] Pulled registry.aliyuncs.com/k8sxio/etcd:3.5.0-0
failed to pull image "registry.aliyuncs.com/k8sxio/coredns:v1.8.4": output: time="2021-10-25T17:34:48+08:00" level=fatal msg="pulling image: rpc error: code = NotFound desc = failed to pull and unpack image \"registry.aliyuncs.com/k8sxio/coredns:v1.8.4\": failed to resolve reference \"registry.aliyuncs.com/k8sxio/coredns:v1.8.4\": registry.aliyuncs.com/k8sxio/coredns:v1.8.4: not found"
, error: exit status 1
To see the stack trace of this error execute with --v=5 or higher
```

上面在拉取 `<font style="color:#DF2A3F;">coredns</font>`<font style="color:#DF2A3F;"> </font>镜像的时候出错了，没有找到这个镜像，我们可以手动 pull 该镜像，然后重新 tag 下镜像地址即可：

```shell
➜  ~ ctr -n k8s.io i pull docker.io/coredns/coredns:1.8.4
docker.io/coredns/coredns:1.8.4:                                                  resolved       |++++++++++++++++++++++++++++++++++++++|
index-sha256:6e5a02c21641597998b4be7cb5eb1e7b02c0d8d23cce4dd09f4682d463798890:    done           |++++++++++++++++++++++++++++++++++++++|
manifest-sha256:10683d82b024a58cc248c468c2632f9d1b260500f7cd9bb8e73f751048d7d6d4: done           |++++++++++++++++++++++++++++++++++++++|
layer-sha256:bc38a22c706b427217bcbd1a7ac7c8873e75efdd0e59d6b9f069b4b243db4b4b:    done           |++++++++++++++++++++++++++++++++++++++|
config-sha256:8d147537fb7d1ac8895da4d55a5e53621949981e2e6460976dae812f83d84a44:   done           |++++++++++++++++++++++++++++++++++++++|
layer-sha256:c6568d217a0023041ef9f729e8836b19f863bcdb612bb3a329ebc165539f5a80:    exists         |++++++++++++++++++++++++++++++++++++++|
elapsed: 12.4s                                                                    total:  12.0 M (991.3 KiB/s)
unpacking linux/amd64 sha256:6e5a02c21641597998b4be7cb5eb1e7b02c0d8d23cce4dd09f4682d463798890...
done: 410.185888ms
➜  ~ ctr -n k8s.io i tag docker.io/coredns/coredns:1.8.4 registry.aliyuncs.com/k8sxio/coredns:v1.8.4
```

然后就可以使用上面的配置文件在 master 节点上进行初始化：

```shell
➜  ~ kubeadm init --config kubeadm.yaml
[init] Using Kubernetes version: v1.22.2
[preflight] Running pre-flight checks
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Generating "ca" certificate and key
[certs] Generating "apiserver" certificate and key
[certs] apiserver serving cert is signed for DNS names [kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local master1] and IPs [10.96.0.1 192.168.31.31]
[certs] Generating "apiserver-kubelet-client" certificate and key
[certs] Generating "front-proxy-ca" certificate and key
[certs] Generating "front-proxy-client" certificate and key
[certs] Generating "etcd/ca" certificate and key
[certs] Generating "etcd/server" certificate and key
[certs] etcd/server serving cert is signed for DNS names [localhost master1] and IPs [192.168.31.31 127.0.0.1 ::1]
[certs] Generating "etcd/peer" certificate and key
[certs] etcd/peer serving cert is signed for DNS names [localhost master1] and IPs [192.168.31.31 127.0.0.1 ::1]
[certs] Generating "etcd/healthcheck-client" certificate and key
[certs] Generating "apiserver-etcd-client" certificate and key
[certs] Generating "sa" key and public key
[kubeconfig] Using kubeconfig folder "/etc/kubernetes"
[kubeconfig] Writing "admin.conf" kubeconfig file
[kubeconfig] Writing "kubelet.conf" kubeconfig file
[kubeconfig] Writing "controller-manager.conf" kubeconfig file
[kubeconfig] Writing "scheduler.conf" kubeconfig file
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Starting the kubelet
[control-plane] Using manifest folder "/etc/kubernetes/manifests"
[control-plane] Creating static Pod manifest for "kube-apiserver"
[control-plane] Creating static Pod manifest for "kube-controller-manager"
[control-plane] Creating static Pod manifest for "kube-scheduler"
[etcd] Creating static Pod manifest for local etcd in "/etc/kubernetes/manifests"
[wait-control-plane] Waiting for the kubelet to boot up the control plane as static Pods from directory "/etc/kubernetes/manifests". This can take up to 4m0s
[apiclient] All control plane components are healthy after 12.004224 seconds
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config-1.22" in namespace kube-system with the configuration for the kubelets in the cluster
[upload-certs] Skipping phase. Please see --upload-certs
[mark-control-plane] Marking the node master1 as control-plane by adding the labels: [node-role.kubernetes.io/master(deprecated) node-role.kubernetes.io/control-plane node.kubernetes.io/exclude-from-external-load-balancers]
[mark-control-plane] Marking the node master1 as control-plane by adding the taints [node-role.kubernetes.io/master:NoSchedule]
[bootstrap-token] Using token: abcdef.0123456789abcdef
[bootstrap-token] Configuring bootstrap tokens, cluster-info ConfigMap, RBAC Roles
[bootstrap-token] configured RBAC rules to allow Node Bootstrap tokens to get nodes
[bootstrap-token] configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[bootstrap-token] Creating the "cluster-info" ConfigMap in the "kube-public" namespace
[kubelet-finalize] Updating "/etc/kubernetes/kubelet.conf" to point to a rotatable kubelet client certificate and key
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.31.31:6443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:ca0c87226c69309d7779096c15b6a41e14b077baf4650bfdb6f9d3178d4da645
```

根据安装提示拷贝 kubeconfig 文件：

```shell
➜  ~ mkdir -p $HOME/.kube
➜  ~ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
➜  ~ sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

然后可以使用 kubectl 命令查看 master 节点已经初始化成功了：

```shell
➜  ~ kubectl get nodes
NAME      STATUS   ROLES                  AGE   VERSION
master1   Ready    control-plane,master   41s   v1.22.2
```

### 3.2 Kubernetes 添加 Worker 节点
记住初始化集群上面的配置和操作要提前做好，将 master 节点上面的 `<font style="color:#DF2A3F;">$HOME/.kube/config</font>` 文件拷贝到 node 节点对应的文件中，安装 kubeadm、kubelet、kubectl（可选），然后执行上面初始化完成后提示的 join 命令即可：

```shell
➜  ~ kubeadm join 192.168.31.31:6443 --token abcdef.0123456789abcdef \
> --discovery-token-ca-cert-hash sha256:ca0c87226c69309d7779096c15b6a41e14b077baf4650bfdb6f9d3178d4da645
[preflight] Running pre-flight checks
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Starting the kubelet
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

:::color1
重新获取 join 命令

:::

如果忘记了上面的 `<font style="color:#DF2A3F;">join</font>`<font style="color:#DF2A3F;"> </font>命令可以使用命令`<font style="color:#DF2A3F;">kubeadm token create --print-join-command</font>` 重新获取。

执行成功后运行 `<font style="color:#DF2A3F;">get nodes</font>` 命令：

```shell
➜  ~ kubectl get nodes
NAME      STATUS   ROLES                  AGE     VERSION
master1   Ready    control-plane,master   2m35s   v1.22.2
node1     Ready    <none>                 45s     v1.22.2
```

这个时候其实集群还不能正常使用，因为还没有安装网络插件，接下来安装网络插件，可以在文档 `[https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)` 中选择我们自己的网络插件，这里我们安装 flannel：

```shell
➜  ~ wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
# 如果有节点是多网卡，则需要在资源清单文件中指定内网网卡
# 搜索到名为 kube-flannel-ds 的 DaemonSet，在kube-flannel容器下面

➜  ~ vi kube-flannel.yml
[......]
containers:
- name: kube-flannel
  image: quay.io/coreos/flannel:v0.15.0
  command:
  - /opt/bin/flanneld
  args:
  - --ip-masq
  - --kube-subnet-mgr
  - --iface=eth0  # 如果是多网卡的话，指定内网网卡的名称
[......]

➜  ~ kubectl apply -f kube-flannel.yml  # 安装 flannel 网络插件
```

隔一会儿查看 Pod 运行状态：

```shell
➜  ~ kubectl get pods -n kube-system
NAME                             READY   STATUS    RESTARTS   AGE
coredns-7568f67dbd-5mg59         1/1     Running   0          8m32s
coredns-7568f67dbd-b685t         1/1     Running   0          8m31s
etcd-master                      1/1     Running   0          66m
kube-apiserver-master            1/1     Running   0          66m
kube-controller-manager-master   1/1     Running   0          66m
kube-flannel-ds-dsbt6            1/1     Running   0          11m
kube-flannel-ds-zwlm6            1/1     Running   0          11m
kube-proxy-jq84n                 1/1     Running   0          66m
kube-proxy-x4hbv                 1/1     Running   0          19m
kube-scheduler-master            1/1     Running   0          66m
```

:::color1
信息

当我们部署完网络插件后执行 ifconfig 命令，正常会看到新增的`<font style="color:#DF2A3F;">cni0</font>`与 `<font style="color:#DF2A3F;">flannel1</font>`这两个虚拟设备，但是如果没有看到 `<font style="color:#DF2A3F;">cni0</font>`这个设备也不用太担心，我们可以观察 `<font style="color:#DF2A3F;">/var/lib/cni</font>`目录是否存在，如果不存在并不是说部署有问题，而是该节点上暂时还没有应用运行，我们只需要在该节点上运行一个 Pod 就可以看到该目录会被创建，并且 `<font style="color:#DF2A3F;">cni0</font>`设备也会被创建出来。

:::

用同样的方法添加另外一个节点即可。

## 4 Kubernetes Dashboard
`<font style="color:#DF2A3F;">v1.22.2</font>`<font style="color:#DF2A3F;"> </font>版本的集群需要安装最新的 2.0+ 版本的 Dashboard：

```yaml
# 推荐使用下面这种方式
➜  ~ wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.3.1/aio/deploy/recommended.yaml
➜  ~ vi recommended.yaml
# 修改Service为NodePort类型
[......]
kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  ports:
    - port: 443
      targetPort: 8443
  selector:
    k8s-app: kubernetes-dashboard
  type: NodePort  # 加上type=NodePort变成NodePort类型的服务
[......]
```

:::color1
💡信息

在 YAML 文件中可以看到新版本 Dashboard 集成了一个 metrics-scraper 的组件，可以通过 Kubernetes 的 Metrics API 收集一些基础资源的监控信息，并在 web 页面上展示，所以要想在页面上展示监控信息就需要提供 Metrics API，比如安装 Metrics Server。

:::

直接创建：

```shell
➜  ~ kubectl apply -f recommended.yaml
```

新版本的 Dashboard 会被默认安装在 kubernetes-dashboard 这个命名空间下面：

```shell
➜  ~ kubectl get pods -n kubernetes-dashboard -o wide
NAME                                         READY   STATUS    RESTARTS   AGE   IP              NODE           NOMINATED NODE   READINESS GATES
dashboard-metrics-scraper-5bc754cb48-w496q   1/1     Running   0          35s   192.244.211.2   hkk8snode001   <none>           <none>
kubernetes-dashboard-c8b7d9fd-hjn8n          1/1     Running   0          35s   192.244.211.1   hkk8snode001   <none>           <none>
```

我们仔细看可以发现上面的 Pod 分配的 IP 段是 `<font style="color:#DF2A3F;">10.88.xx.xx</font>`，包括前面自动安装的 CoreDNS 也是如此，我们前面不是配置的 podSubnet 为 `<font style="color:#DF2A3F;">10.244.0.0/16</font>` 吗？我们先去查看下 CNI 的配置文件：

```shell
➜  ~ ls -la /etc/cni/net.d/
total 8
drwxr-xr-x  2 1001 docker  67 Aug 31 16:45 .
drwxr-xr-x. 3 1001 docker  19 Jul 30 01:13 ..
-rw-r--r--  1 1001 docker 604 Jul 30 01:13 10-containerd-net.conflist
-rw-r--r--  1 root root   292 Aug 31 16:45 10-flannel.conflist
```

可以看到里面包含两个配置，一个是 `<font style="color:#DF2A3F;">10-containerd-net.conflist</font>`，另外一个是我们上面创建的 Flannel 网络插件生成的配置，我们的需求肯定是想使用 Flannel 的这个配置，我们可以查看下 containerd 这个自带的 cni 插件配置：

```shell
➜  ~ cat /etc/cni/net.d/10-containerd-net.conflist
{
  "cniVersion": "0.4.0",
  "name": "containerd-net",
  "plugins": [
    {
      "type": "bridge",
      "bridge": "cni0",
      "isGateway": true,
      "ipMasq": true,
      "promiscMode": true,
      "ipam": {
        "type": "host-local",
        "ranges": [
          [{
            "subnet": "10.88.0.0/16"
          }],
          [{
            "subnet": "2001:4860:4860::/64"
          }]
        ],
        "routes": [
          { "dst": "0.0.0.0/0" },
          { "dst": "::/0" }
        ]
      }
    },
    {
      "type": "portmap",
      "capabilities": {"portMappings": true}
    }
  ]
}
```

可以看到上面的 IP 段恰好就是 `<font style="color:#DF2A3F;">10.88.0.0/16</font>`，但是这个 cni 插件类型是 `<font style="color:#DF2A3F;">bridge</font>`<font style="color:#DF2A3F;"> </font>网络，网桥的名称为 `<font style="color:#DF2A3F;">cni0</font>`：

```shell
➜  ~ ip a
......
6: cni0: <BROADCAST,MULTICAST,PROMISC,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 9a:e7:eb:40:e8:66 brd ff:ff:ff:ff:ff:ff
    inet 10.88.0.1/16 brd 10.88.255.255 scope global cni0
       valid_lft forever preferred_lft forever
    inet6 2001:4860:4860::1/64 scope global
       valid_lft forever preferred_lft forever
    inet6 fe80::98e7:ebff:fe40:e866/64 scope link
       valid_lft forever preferred_lft forever
......
```

但是使用 bridge 网络的容器无法跨多个宿主机进行通信，跨主机通信需要借助其他的 cni 插件，比如上面我们安装的 Flannel，或者 Calico 等等，由于我们这里有两个 CNI 配置，所以我们需要将 `<font style="color:#DF2A3F;">10-containerd-net.conflist</font>` 这个配置删除，因为如果这个目录中有多个 cni 配置文件，kubelet 将会使用按文件名的字典顺序排列的第一个作为配置文件，所以前面默认选择使用的是 `<font style="color:#DF2A3F;">containerd-net</font>` 这个插件。

```shell
➜  ~ mv /etc/cni/net.d/10-containerd-net.conflist /etc/cni/net.d/10-containerd-net.conflist.bak
➜  ~ ifconfig cni0 down && ip link delete cni0
➜  ~ systemctl daemon-reload
➜  ~ systemctl restart containerd kubelet
```

然后记得重建 Coredns 和 Dashboard 的 Pod，重建后 Pod 的 IP 地址就正常了：

```shell
➜  ~ kubectl get pods -n kubernetes-dashboard -o wide
NAME                                         READY   STATUS    RESTARTS   AGE   IP           NODE    NOMINATED NODE   READINESS GATES
dashboard-metrics-scraper-856586f554-tp8m5   1/1     Running   0          42s   10.244.1.6   node2   <none>           <none>
kubernetes-dashboard-76597d7df5-9rmbx        1/1     Running   0          66s   10.244.1.5   node2   <none>           <none>

➜  ~ kubectl get pods -n kube-system -o wide -l k8s-app=kube-dns
NAME                       READY   STATUS    RESTARTS   AGE     IP           NODE    NOMINATED NODE   READINESS GATES
coredns-7568f67dbd-n7bfx   1/1     Running   0          5m40s   10.244.1.2   node2   <none>           <none>
coredns-7568f67dbd-plrv8   1/1     Running   0          3m47s   10.244.1.4   node2   <none>           <none>
```

查看 Dashboard 的 NodePort 端口：

```shell
➜  ~ kubectl get svc -n kubernetes-dashboard
NAME                        TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)         AGE
dashboard-metrics-scraper   ClusterIP   192.96.96.183    <none>        8000/TCP        2m30s
kubernetes-dashboard        NodePort    192.96.219.146   <none>        443:29665/TCP   2m30s
```

然后可以通过上面的 `<font style="color:#DF2A3F;">29665</font>`<font style="color:#DF2A3F;"> </font>端口去访问 Dashboard，要记住使用 https，Chrome 不生效可以使用 `<font style="color:#DF2A3F;">Firefox</font>` 测试，如果没有 Firefox 下面打不开页面，可以点击下页面中的 `<font style="color:#DF2A3F;">信任证书</font>`即可：

+ 使用 Ingress-Nginx 的方式访问：

```yaml
# Ingress-kubernetes-dashboard.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kubernetes-dashboard-ingress
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/auth-keepalive: "75"
    nginx.ingress.kubernetes.io/client-body-buffer-size: 500m
    nginx.ingress.kubernetes.io/client-header-buffer-size: 10m
    nginx.ingress.kubernetes.io/large-client-header-buffers: 4 10240k
    nginx.ingress.kubernetes.io/proxy-body-size: 1024m
    nginx.ingress.kubernetes.io/proxy-buffer: 32 32k
    nginx.ingress.kubernetes.io/proxy-buffer-size: 5m
    nginx.ingress.kubernetes.io/proxy-buffering: "on"
    nginx.ingress.kubernetes.io/proxy-buffers-number: "16"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "1800"
    nginx.ingress.kubernetes.io/proxy-max-temp-file-size: 1024m
    nginx.ingress.kubernetes.io/proxy-read-timeout: "1800"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "1800"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-passthrough: "false"
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
  labels:
    app: kubernetes-dashboard
spec:
  rules:
    - host: kubernetes-dashboard.kubesphere.ai
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: kubernetes-dashboard
                port:
                  number: 8443
```

引用资源清单文件

```shell
$ kubectl apply -f Ingress-kubernetes-dashboard.yaml 
Warning: annotation "kubernetes.io/ingress.class" is deprecated, please use 'spec.ingressClassName' instead
ingress.networking.k8s.io/kubernetes-dashboard-ingress created
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760348830924-9c733163-1f35-4c18-b1d3-bac06dbcff67.png)

信任后就可以访问到 Dashboard 的登录页面了：

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760349205312-a9e165d8-2a8a-4648-8574-cb46d183b4ab.png)

然后创建一个具有全局所有权限的用户来登录 Dashboard：(`<font style="color:#DF2A3F;">dashboard-admin.yaml</font>`)

```yaml
# dashboard-admin.yaml
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: admin
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: ServiceAccount
    name: admin
    namespace: kubernetes-dashboard
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin
  namespace: kubernetes-dashboard
```

直接创建：

:::success
💡<font style="color:#601BDE;">在Kubernetes 1.24版本之前，创建一个ServiceAccount时，系统会</font>**<font style="color:#601BDE;">自动生成一个关联的Secret</font>**<font style="color:#601BDE;">，该Secret包含用于API认证的Token。然而，从Kubernetes 1.24版本开始，默认行为发生了变化，</font>**<font style="color:#601BDE;">不再自动生成Secret</font>**<font style="color:#601BDE;">，需要手动创建并关联。</font>

变更原因

+ 此更改的主要目的是**<font style="color:#601BDE;">增强安全性</font>**，避免不必要的Token暴露。默认情况下，ServiceAccount的Token挂载功能被禁用。如果需要恢复自动生成Secret的功能，可以通过配置启用。

:::

```shell
########################################################################
# 旧的Kubernetes版本(因为旧版本的Kubernetes会默认自动创建Secrets)
########################################################################
➜  ~ kubectl apply -f dashboard-admin.yaml
➜  ~ kubectl get secret -n kubernetes-dashboard | grep admin-token
admin-token-lwmmx                  kubernetes.io/service-account-token   3         1d
➜  ~ kubectl get secret admin-token-lwmmx -o jsonpath={.data.token} -n kubernetes-dashboard |base64 -d
# 会生成一串很长的base64后的字符串

########################################################################
# 新的Kubernetes版本(因为新版本的Kubernetes不会默认自动创建Secrets)
########################################################################
➜  ~ cat <<EOF > dashboard-admin.yaml
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: admin
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: ServiceAccount
    name: admin
    namespace: kubernetes-dashboard
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin
  namespace: kubernetes-dashboard
---
apiVersion: v1
kind: Secret
metadata:
  name: admin-token
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/service-account.name: admin
type: kubernetes.io/service-account-token
EOF
➜  ~ kubectl apply -f dashboard-admin.yaml
clusterrolebinding.rbac.authorization.k8s.io/admin created
serviceaccount/admin created
secret/admin-token created

➜  ~ kubectl get secret admin-token -o jsonpath={.data.token} -n kubernetes-dashboard | base64 -d ; echo
eyJhbGciOiJSUzI1NiIsImtpZCI6IjhHaERRNmFUaEhNS3NtT3l0bUdQMTRUb1JVeXY0Q1Y5UzQ3LTFQdGE0SXcifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlcm5ldGVzLWRhc2hib2FyZCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJhZG1pbi10b2tlbiIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJhZG1pbiIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50LnVpZCI6ImUzNzZiYjI2LTNmNjAtNDk3Yi1iODJjLWVlZWEwNzY3ZjFlMiIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDprdWJlcm5ldGVzLWRhc2hib2FyZDphZG1pbiJ9.STUd4ffBIN_8fsuDYI8L_8YQ-2eL5jlNA9Qpz9333Cd8s0PKmqC4s2sPetvAZJViDMNq8K2kqgin3oNyTl0yUunUEBokBxHY2Ly7TCp8l6vg-EYYFKlRAc6hoMoXZqRS35-lkyTCmiRM42PQ2x-lrUwgwD5WH79_W_kaY0Ca3idhdtJ2cUWsr-aGtbEomqIuFMWZPvvqHazRAqOwS7ZXW0fgup3tAyfudpmsrgeGLDNWZmV0SOBkMstIxIR7Pbomxx87S-sAJiJkzXCLCk9vYPufcWeHS8FvPa2w5vBl1b9mnS2xTxxB3WjdSQqZ-RMEJDolgJOe0N_sR3m5GyN7Kg
```

然后用上面的 `<font style="color:#DF2A3F;">base64</font>`<font style="color:#DF2A3F;"> </font>解码后的字符串作为 `<font style="color:#DF2A3F;">token</font>`<font style="color:#DF2A3F;"> </font>登录 Dashboard 即可，新版本还新增了一个暗黑模式：

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760349999856-0247b66a-c8a2-4a43-825f-bb8ba476a311.png)

最终我们就完成了使用 kubeadm 搭建 `<font style="color:#DF2A3F;">v1.22.1</font>` 版本的 Kubernetes 集群、Coredns、IPVS、Flannel、Containerd。

## 5 清理（重置）
如果你的集群安装过程中遇到了其他问题，我们可以使用下面的命令来进行重置：

```bash
➜  ~ kubeadm reset
➜  ~ ifconfig cni0 down && ip link delete cni0
➜  ~ ifconfig flannel.1 down && ip link delete flannel.1
➜  ~ rm -rf /var/lib/cni/
```

