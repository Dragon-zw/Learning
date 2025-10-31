## 1 Windows 系统最佳实践
有部分同学是使用的 Windows 系统，我们的直播课程也是在 Windows 系统下面进行的，然后通过 SSH 方式连接到 服务器上面操作 Kubernetes，由于对 vim 不是很熟悉，所以又通过 SFTP 的方式在本地编写资源清单文件同步到服务器上面执行的，这个过程比较繁琐，效率不高。

下面就来介绍下在 Windows 系统下面配置 kubectl 的实践方式，当然如果你是 Mac 或者 Linux，思路基本都是一致的。

### 1.2 kubectl 配置
> Link Reference：
>
> [https://kubernetes.ltd/zh-cn/docs/reference/kubectl/](https://kubernetes.ltd/zh-cn/docs/reference/kubectl/)
>
> [https://kubernetes.ltd/zh-cn/docs/tasks/tools/install-kubectl-windows/#install-kubectl-binary-on-windows-via-direct-download-or-curl](https://kubernetes.ltd/zh-cn/docs/tasks/tools/install-kubectl-windows/#install-kubectl-binary-on-windows-via-direct-download-or-curl)
>

首先，下载 Windows 版本的 kubectl 二进制文件，地址：[https://dl.k8s.io/v1.16.2/kubernetes-client-windows-amd64.tar.gz](https://dl.k8s.io/v1.16.2/kubernetes-client-windows-amd64.tar.gz)。

```powershell
# PowerShell 执行
$ cd D:\4.DevTools
$ curl.exe -LO "https://dl.k8s.io/release/v1.34.1/bin/windows/amd64/kubectl.exe"
```

下载链接

由于上面下载链接需要科学上网，所以我这里离线放到到了百度网盘上，可以直接下载：

> 链接：[https://pan.baidu.com/s/1w_2s3mzf1OWSlvgVZFssCA](https://pan.baidu.com/s/1w_2s3mzf1OWSlvgVZFssCA)
>
> 提取码：`<font style="color:#DF2A3F;">fxbc</font>`
>
> 复制这段内容后打开百度网盘手机App，操作更方便哦
>

将 `<font style="color:#DF2A3F;">kubectl</font>`<font style="color:#DF2A3F;"> </font>二进制文件下载到本地，解压到目录：`<font style="color:#DF2A3F;">D:\4.DevTools</font>` 下面，然后设置该目录到 PATH 路径下面，操作步骤如下所示：

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761927492550-85f09f93-0936-456d-8117-8a8b5419e475.png)

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761927443844-f1492fce-ef2d-444a-aa3d-e1aa3371602c.png)

这样设置完成后就可以在终端中直接直接 kubectl 命令了。现在只需要配置 kubeconfig 文件就可以访问我们的 Kubernetes 集群了。

首先创建 `<font style="color:#DF2A3F;">.kube</font>` 目录：

```shell
$ mkdir ~/.kube  # 对应目录: C:\Users\Administrator\.kube
```

然后将服务器上面的 `<font style="color:#DF2A3F;">kubeconfig（~/.kube/config）</font>`文件复制到 Windows 下面的 `<font style="color:#DF2A3F;">~/.kube</font>` 目录下面，但是需要注意的是服务器上面的`<font style="color:#DF2A3F;">kubeconfig</font>`配置文件里面的 APIServer 地址是**<font style="color:#DF2A3F;">内网地址</font>**，所以我们把这里的地址改成外网 IP，保存，然后测试 `<font style="color:#DF2A3F;">kubectl</font>` 命令：

```shell
$ kubectl.exe version
Client Version: v1.34.1
Kustomize Version: v5.7.1
Unable to connect to the server: dial tcp [::1]:8080: connectex: No connection could be made because the target machine actively refused it.

# 将服务器上的 Kubeconfig 文件拷贝到主机中
$ cat <<EOF> ~/.kube/config
<KUBECONFIG_CONTENT>
EOF
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761927979367-1942071b-da5a-4a28-8458-b1fc64b1bd02.png)

我们可以看到会提示证书错误，大概意思就是服务端的证书没有包含我们的外网 IP，所以我们通过外网 IP 去访问就证书校验失败了，这个时候怎么办呢？要解决这个问题主要有两个方法：

第一个就是在我们最开始初始化集群的时候通过 kubeadm 的配置文件指定参数 `<font style="color:#DF2A3F;">apiServer CertSANs</font>` 的时候，将外网 IP 也包含着里面，但是我们集群已经安装好了，这个方法肯定不适用了。

第二个方法我们去服务器上面看看我们的 apiserver 证书的详细信息：

```shell
$ openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text
[......]
```

我们仔细看上面 DNS 区域就是包含的校验的域名，后面还有 IP，是不是其中就有我们的 master 节点的 `<font style="color:#DF2A3F;">hostname（hkkckubesphere-george）</font>`，到这里大家想到方法了吗？

我们是不是可以直接在本地的 `<font style="color:#DF2A3F;">/etc/hosts</font>` 里面做一个 APIServer 的`<font style="color:#DF2A3F;">外网 IP -> ydzs-master</font>` 的映射，然后在本地的 kubeconfig 文件中把 apiserver 地址替换成 `<font style="color:#DF2A3F;">https://hkkckubesphere-george:6443</font>` 是不是就 OK 了啊。

所以接下来直接在本地修改 hosts 映射即可，要注意用管理员身份打开文件 `<font style="color:#DF2A3F;">C:\Windows\System32\drivers\etc\hosts</font>`，然后在文件里面添加一行映射：

```bash
# localhost name resolution is handled within DNS itself.
#    127.0.0.1       localhost
#    ::1             localhost
192.168.178.201 hkkckubernetes-master
```

然后保存即可。这个时候我们再到 powershell 中去执行下 kubectl 命令呢：

```shell
$ kubectl version
Client Version: v1.34.1
Kustomize Version: v5.7.1
Server Version: v1.27.6
Warning: version difference between client (1.34) and server (1.27) exceeds the supported minor version skew of +/-1
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761928051417-b3050b94-6b0f-47e7-b663-1081e4d73f5e.png)

是不是全都 OK 了呀~

### 1.2 IDE 配置
当然 kubectl 工具配置好以后，我们就可以直接操作集群了，随便用什么工具编写 YAML 清单文件操作都可以，当然为了更好的实践方式，可以选择一些比较顺手的工具，比如 vscode 之类的编辑器，我这里使用的是 `<font style="color:#DF2A3F;">Goland</font>`<font style="color:#DF2A3F;"> </font>这个 IDE。对于 IDEA（Goland | Pycharm） 的 IDE 都可以一样的操作。

+ 为了页面美观，可以安装一个 `<font style="color:#DF2A3F;">Material Theme UI</font>` 的主题插件
+ 为了编写 YAML 文件方便，还需要安装一个名为 `<font style="color:#DF2A3F;">kubernetes</font>`<font style="color:#DF2A3F;"> </font>的插件，这样我们在编写资源清单的时候就可以自动提示了

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761926766646-fbb61bea-0a84-4876-b55c-758aa45db44d.png)

+ 更改默认的 IDE 的 Terminal 为 Powershell：`<font style="color:#DF2A3F;">open File=>Setting=>Tools=>Terminal</font>`, 将`<font style="color:#DF2A3F;">cmd.exe</font>`修改为`<font style="color:#DF2A3F;">powershell.exe</font>`保存，重启 IDE 即可。

最终的配置效果如下图所示：

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761928343470-d64e2338-200c-46c4-b0fb-a3dec073ae27.png)

