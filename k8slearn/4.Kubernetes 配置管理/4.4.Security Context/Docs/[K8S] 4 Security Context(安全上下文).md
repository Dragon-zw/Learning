![](https://cdn.nlark.com/yuque/0/2024/jpeg/2555283/1731570147988-c3320d9a-01c3-4c9b-bce7-7088c69f0e9f.jpeg)

<font style="color:rgb(28, 30, 33);">我们有时候在运行一个容器的时候，可能需要使用 </font>`<font style="color:#DF2A3F;">sysctl</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">命令来修改内核参数，比如 </font>`<font style="color:#DF2A3F;">net</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">vm</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">kernel</font>`<font style="color:rgb(28, 30, 33);"> 等参数，但是 </font>`<font style="color:#DF2A3F;">systcl</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">需要容器拥有超级权限，才可以使用，在 Docker 容器启动的时候我们可以加上 </font>`<font style="color:#DF2A3F;">--privileged</font>`<font style="color:rgb(28, 30, 33);"> 参数来使用特权模式。那么在 Kubernetes 中应该如何来使用呢？</font>

<font style="color:rgb(28, 30, 33);">这个时候我们就需要使用到 Kubernetes 中的 </font>`<font style="color:#DF2A3F;">Security Context</font>`<font style="color:rgb(28, 30, 33);">，</font>`<u><font style="color:#DF2A3F;">Security Context</font></u>`<u><font style="color:rgb(28, 30, 33);">也就是常说的安全上下文，主要是来</font></u><u><font style="color:#DF2A3F;">限制容器非法操作宿主节点的系统级别的内容，使得节点的系统或者节点上其他容器组受到影响。</font></u><font style="color:rgb(28, 30, 33);">Kubernetes 提供了三种配置安全上下文级别的方法：</font>

+ `<font style="color:#DF2A3F;">Container-level Security Context</font>`<font style="color:rgb(28, 30, 33);">：仅应用到指定的容器</font>
+ `<font style="color:#DF2A3F;">Pod-level Security Context</font>`<font style="color:rgb(28, 30, 33);">：应用到 Pod 内所有容器以及 Volume</font>
+ `<font style="color:#DF2A3F;">Pod Security Policies（PSP，废弃）</font>`<font style="color:rgb(28, 30, 33);">：应用到集群内部所有 Pod 以及 Volume</font>

<font style="color:rgb(28, 30, 33);">我们可以用如下几种方式来设置 </font>`<font style="color:#DF2A3F;">Security Context</font>`<font style="color:rgb(28, 30, 33);">：</font>

+ <font style="color:rgb(28, 30, 33);">访问权限控制：根据用户 ID（UID）和组 ID（GID）来限制对资源（比如：文件）的访问权限</font>
+ <font style="color:rgb(28, 30, 33);">Security Enhanced Linux (SELinux)：为对象分配 </font>`<font style="color:#DF2A3F;">SELinux</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">标签</font>
+ <font style="color:rgb(28, 30, 33);">以 Privileged（特权）模式运行</font>
+ <font style="color:rgb(28, 30, 33);">Linux Capabilities：给某个特定的进程超级权限，而不用给 root 用户所有的 Privileged 权限</font>
+ <font style="color:rgb(28, 30, 33);">AppArmor：使用程序文件来限制单个程序的权限</font>
+ <font style="color:rgb(28, 30, 33);">Seccomp：过滤容器中进程的系统调用（</font>`<font style="color:#DF2A3F;">system call</font>`<font style="color:rgb(28, 30, 33);">）</font>
+ <font style="color:rgb(28, 30, 33);">AllowPrivilegeEscalation（允许特权扩大）：此项配置是一个布尔值，定义了一个进程是否可以比其父进程获得更多的特权，直接效果是，容器的进程上是否被设置 </font>`<font style="color:#DF2A3F;">no_new_privs</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">标记。当出现如下情况时，AllowPrivilegeEscalation 的值始终为 true：</font>
    - <font style="color:rgb(28, 30, 33);">容器以 </font>`<font style="color:#DF2A3F;">privileged</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">模式运行</font>
    - <font style="color:rgb(28, 30, 33);">容器拥有 </font>`<font style="color:#DF2A3F;">CAP_SYS_ADMIN</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">的 Linux Capability</font>

## <font style="color:rgb(28, 30, 33);">1 为 Pod 设置 Security Context</font>
<font style="color:rgb(28, 30, 33);">我们只需要在 Pod 定义的资源清单文件中添加 </font>`<font style="color:#DF2A3F;">securityContext</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">字段，就可以为 Pod 指定安全上下文相关的设定，通过该字段指定的内容将会对当前 Pod 中的所有容器生效。</font>

```yaml
# security-context-pod-demo.yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-context-pod-demo
spec:
  volumes:
    - name: sec-ctx-vol
      emptyDir: {}
  securityContext:
    runAsUser: 1000 # 所有容器内的进程都以UID 1000运行
    runAsGroup: 3000 # 所有容器内的进程都以GID 3000运行
    fsGroup: 2000 # 挂载到卷的文件和目录都属于GID 2000
  containers:
    - name: sec-ctx-demo
      image: busybox
      command: ['sh', '-c', 'sleep 60m']
      volumeMounts:
        - name: sec-ctx-vol
          mountPath: /pod/demo
      securityContext:
        allowPrivilegeEscalation: false
```

<font style="color:rgb(28, 30, 33);">在当前资源清单文件中我们在 Pod 下面添加了 </font>`<font style="color:#DF2A3F;">securityContext</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">字段，其中：</font>

+ `<font style="color:#DF2A3F;">runAsUser</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">字段指定了该 Pod 中所有容器的进程都以 UID 1000 的身份运行</font>
+ `<font style="color:#DF2A3F;">runAsGroup</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">字段指定了该 Pod 中所有容器的进程都以 GID 3000 的身份运行</font>
    - <font style="color:rgb(28, 30, 33);">如果省略该字段，容器进程的 GID 为 </font>`<font style="color:#DF2A3F;">root(0)</font>`
    - <font style="color:rgb(28, 30, 33);">容器中创建的文件，其所有者为 </font>`<font style="color:#DF2A3F;">userID 1000，groupID 3000</font>`
+ `<font style="color:#DF2A3F;">fsGroup</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">字段指定了该 Pod 的 fsGroup 为 2000</font>
    - <font style="color:rgb(28, 30, 33);">数据卷 （对应挂载点 </font>`<font style="color:#DF2A3F;">/pod/demo</font>`<font style="color:rgb(28, 30, 33);"> 的数据卷为 </font>`<font style="color:#DF2A3F;">sec-ctx-demo</font>`<font style="color:rgb(28, 30, 33);">） 的所有者以及在该数据卷下创建的任何文件，其 GID 都为 2000</font>

<font style="color:rgb(28, 30, 33);">下表是我们常用的一些 </font>`<font style="color:#DF2A3F;">securityContext</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">字段设置内容介绍：</font>

![](https://cdn.nlark.com/yuque/0/2024/jpeg/2555283/1731570148373-937c15d5-e0b0-4a1c-9a01-992109486476.jpeg)

<font style="color:rgb(28, 30, 33);">直接创建上面的 Pod 对象：</font>

```shell
# 引用资源清单文件
➜  ~ kubectl apply -f security-context-pod-demo.yaml
pod/security-context-pod-demo created

➜  ~ kubectl get pods security-context-pod-demo
NAME                        READY   STATUS    RESTARTS   AGE
security-context-pod-demo   1/1     Running   0          25s
```

<font style="color:rgb(28, 30, 33);">运行完成后，我们可以验证下容器中的进程运行的 ownership：</font>

```shell
➜  ~ kubectl exec security-context-pod-demo -- /bin/sh -c "top -d 1 -n 1"
Mem: 42357356K used, 23061212K free, 3344324K shrd, 2728K buff, 37680144K cache
CPU:  0.0% usr  0.0% sys  0.0% nic  100% idle  0.0% io  0.0% irq  0.0% sirq
Load average: 0.06 0.08 0.08 1/926 43
  PID  PPID USER     STAT   VSZ %VSZ CPU %CPU COMMAND
   25     0 1000     S     4568  0.0   6  0.0 sh
   38     0 1000     R     4568  0.0   9  0.0 top -d 1 -n 1
    1     0 1000     S     4436  0.0  10  0.0 sleep 60m
```

<font style="color:rgb(28, 30, 33);">我们直接运行一个 </font>`<font style="color:#DF2A3F;">top</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">进程，查看容器中的所有正在执行的进程，我们可以看到 USER ID 都为 1000（</font>`<font style="color:#DF2A3F;">runAsUser</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">指定的），然后查看下挂载的数据卷的 ownership：</font>

```shell
➜  ~ kubectl exec security-context-pod-demo -- ls -la /pod
total 0
drwxr-xr-x    3 root     root            18 Oct 16 01:39 .
drwxr-xr-x    1 root     root            62 Oct 16 01:39 ..
drwxrwsrwx    2 root     2000             6 Oct 16 01:39 demo
```

<font style="color:rgb(28, 30, 33);">因为上面我们指定了 </font>`<font style="color:#DF2A3F;">fsGroup=2000</font>`<font style="color:rgb(28, 30, 33);">，所以声明挂载的数据卷 </font>`<font style="color:#DF2A3F;">/pod/demo</font>`<font style="color:rgb(28, 30, 33);"> 的 GID 也变成了 2000。直接调用容器中的 id 命令：</font>

```shell
➜  ~ kubectl exec security-context-pod-demo -- id
uid=1000 gid=3000 groups=2000,3000
```

<font style="color:rgb(28, 30, 33);">我们可以看到 Gid 为 3000，与 </font>`<font style="color:#DF2A3F;">runAsGroup</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">字段所指定的一致，如果 </font>`<font style="color:#DF2A3F;">runAsGroup</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">字段被省略，则 Gid 取值为 0（即 root），此时容器中的进程将可以操作 root Group 的文件。</font>

<font style="color:rgb(28, 30, 33);">比如我们现在想要去删除容器中的 </font>`<font style="color:#DF2A3F;">/tmp</font>`<font style="color:rgb(28, 30, 33);"> 目录就没有权限了，因为该目录的用户和组都是 root，而我们当前要去删除使用的进程的 ID 号就变成了 </font>`<font style="color:#DF2A3F;">1000:3000</font>`<font style="color:rgb(28, 30, 33);">，所以没有权限操作：</font>

```shell
➜  ~ kubectl exec security-context-pod-demo -- ls -la /tmp
total 8
drwxrwxrwt    2 root     root          4096 Oct 29 02:40 .
drwxr-xr-x    1 root     root          4096 Nov 26 15:44 ..

➜  ~ kubectl exec security-context-pod-demo -- rm -rf /tmp
rm: can't remove '/tmp': Permission denied
command terminated with exit code 1
```

## <font style="color:rgb(28, 30, 33);">2 为容器设置 Security Context</font>
<font style="color:rgb(28, 30, 33);">除了在 Pod 中可以设置安全上下文之外，我们还可以单独为某个容器设置安全上下文，同样也是通过 </font>`<font style="color:#DF2A3F;">securityContext</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">字段设置，当该字段的配置与 Pod 级别的 securityContext 配置相冲突时，容器级别的配置将覆盖 Pod 级别的配置。容器级别的 </font>`<font style="color:#DF2A3F;">securityContext</font>`<font style="color:rgb(28, 30, 33);"> 不影响 Pod 中的数据卷。如下资源清单所示：</font>

```yaml
# security-context-container-demo.yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-context-container-demo
spec:
  securityContext:
    runAsUser: 1000
  containers:
    - name: sec-ctx-demo
      image: busybox
      command: ['sh', '-c', 'sleep 60m']
      securityContext:
        runAsUser: 2000
        allowPrivilegeEscalation: false
```

<font style="color:rgb(28, 30, 33);">直接创建上面的 Pod 对象：</font>

```shell
# URL 已经失效
# ➜  ~ kubectl apply -f https:/www.qikqiak.com/k8strain/security/manifests/security-context-pod-demo-2.yaml
# 引用资源清单文件
➜  ~ kubectl apply -f security-context-container-demo.yaml
pod/security-context-container-demo created

➜  ~ kubectl get pods security-context-container-demo
NAME                              READY   STATUS    RESTARTS   AGE
security-context-container-demo   1/1     Running   0          15s
```

<font style="color:rgb(28, 30, 33);">同样我们直接执行容器中的 </font>`<font style="color:#DF2A3F;">top</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">命令：</font>

```shell
➜  ~ kubectl exec security-context-container-demo -- /bin/sh -c "top -d 1 -n 1"
Mem: 36633004K used, 28785588K free, 3278916K shrd, 3808K buff, 32033700K cache
CPU:  0.6% usr  0.6% sys  0.0% nic 85.8% idle 12.3% io  0.6% irq  0.0% sirq
Load average: 9.14 9.27 9.29 1/1009 12
  PID  PPID USER     STAT   VSZ %VSZ CPU %CPU COMMAND
    7     0 2000     R     4568  0.0   9  0.0 top -d 1 -n 1
    1     0 2000     S     4436  0.0  15  0.0 sleep 60m
```

<font style="color:rgb(28, 30, 33);">容器的进程以 UID 2000 的身份运行，该取值由 </font>`<font style="color:#DF2A3F;">spec.containers[*].securityContext.runAsUser</font>`<font style="color:rgb(28, 30, 33);"> 容器组中的字段定义。Pod 中定义的 </font>`<font style="color:#DF2A3F;">spec.securityContext.runAsUser</font>`<font style="color:rgb(28, 30, 33);"> 取值 1000 被覆盖。</font>

## <font style="color:rgb(28, 30, 33);">3 设置 Linux Capabilities</font>
<font style="color:rgb(28, 30, 33);">我们使用 </font>`<font style="color:#DF2A3F;">docker/nerdctl run</font>`<font style="color:rgb(28, 30, 33);"> 的时候可以通过 </font>`<font style="color:#DF2A3F;">--cap-add</font>`<font style="color:rgb(28, 30, 33);"> 和 </font>`<font style="color:#DF2A3F;">--cap-drop</font>`<font style="color:rgb(28, 30, 33);"> 命令来给容器添加 </font>`<font style="color:#DF2A3F;">Linux Capabilities</font>`<font style="color:rgb(28, 30, 33);">。那么在 Kubernetes 下面如何来设置呢？要了解如何设置，首先我们还是需要了解下 </font>`<font style="color:#DF2A3F;">Linux Capabilities</font>`<font style="color:rgb(28, 30, 33);"> 是什么？</font>

### <font style="color:rgb(28, 30, 33);">3.1 Linux Capabilities</font>
<font style="color:rgb(28, 30, 33);">要了解 </font>`<font style="color:#DF2A3F;">Linux Capabilities</font>`<font style="color:rgb(28, 30, 33);">，这就得从 Linux 的权限控制发展来说明。在 Linux 2.2 版本之前，当内核对进程进行权限验证的时候，Linux 将进程划分为两类：特权进程（UID=0，也就是超级用户）和非特权进程（UID!=0），特权进程拥有所有的内核权限，而非特权进程则根据进程凭证（effective UID, effective GID，supplementary group 等）进行权限检查。</font>

<font style="color:rgb(28, 30, 33);">比如我们以常用的 </font>`<font style="color:#DF2A3F;">passwd</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">命令为例，修改用户密码需要具有 root 权限，而普通用户是没有这个权限的。但是实际上普通用户又可以修改自己的密码，这是怎么回事呢？在 Linux 的权限控制机制中，有一类比较特殊的权限设置，比如 SUID(Set User ID on execution)，允许用户以可执行文件的 owner 的权限来运行可执行文件。因为程序文件 </font>`<font style="color:#DF2A3F;">/bin/passwd</font>`<font style="color:rgb(28, 30, 33);"> 被设置了 </font>`<font style="color:#DF2A3F;">SUID</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">标识，所以普通用户在执行 passwd 命令时，进程是以 passwd 的所有者，也就是 root 用户的身份运行，从而就可以修改密码了。</font>

<font style="color:rgb(28, 30, 33);">但是使用 </font>`<font style="color:#DF2A3F;">SUID</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">却带来了新的安全隐患，当我们运行设置了 </font>`<font style="color:#DF2A3F;">SUID</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">的命令时，通常只是需要很小一部分的特权，但是 </font>`<font style="color:#DF2A3F;">SUID</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">却给了它 root 具有的全部权限，一旦 被设置了 </font>`<font style="color:#DF2A3F;">SUID</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">的命令出现漏洞，是不是就很容易被利用了。</font>

<font style="color:rgb(28, 30, 33);">为此 Linux 引入了 </font>`<font style="color:#DF2A3F;">Capabilities</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">机制来对 root 权限进行了更加细粒度的控制，实现按需进行授权，这样就大大减小了系统的安全隐患。</font>

#### <font style="color:rgb(28, 30, 33);">3.1.1 什么是 Capabilities</font>
<font style="color:rgb(28, 30, 33);">从内核 2.2 开始，Linux 将传统上与超级用户 root 关联的特权划分为不同的单元，称为 </font>`<font style="color:#DF2A3F;">capabilites</font>`<font style="color:rgb(28, 30, 33);">。</font>`<font style="color:#DF2A3F;">Capabilites</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">每个单元都可以独立启用和禁用。这样当系统在作权限检查的时候就变成了：</font>**<font style="color:rgb(28, 30, 33);">在执行特权操作时，如果进程的有效身份不是 root，就去检查是否具有该特权操作所对应的 capabilites，并以此决定是否可以进行该特权操作</font>**<font style="color:rgb(28, 30, 33);">。比如如果我们要设置系统时间，就得具有 </font>`<font style="color:#DF2A3F;">CAP_SYS_TIME</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">这个 capabilites。下面是从 </font>[<font style="color:rgb(28, 30, 33);">capabilities man page</font>](http://man7.org/linux/man-pages/man7/capabilities.7.html)<font style="color:rgb(28, 30, 33);"> 中摘取的 capabilites 列表：</font>

![](https://cdn.nlark.com/yuque/0/2024/jpeg/2555283/1731570157073-855400f4-7cff-4077-b5da-ddd9a5a83b09.jpeg)

#### <font style="color:rgb(28, 30, 33);">3.1.2 如何使用 Capabilities</font>
<font style="color:rgb(28, 30, 33);">我们可以通过 </font>`<font style="color:#DF2A3F;">getcap</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">和 </font>`<font style="color:#DF2A3F;">setcap</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">两条命令来分别查看和设置程序文件的 </font>`<font style="color:#DF2A3F;">capabilities</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">属性。比如当前我们是</font>`<font style="color:#DF2A3F;">test</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">这个用户，使用 </font>`<font style="color:#DF2A3F;">getcap</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">命令查看 </font>`<font style="color:#DF2A3F;">ping</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">命令目前具有的 </font>`<font style="color:#DF2A3F;">capabilities</font>`<font style="color:rgb(28, 30, 33);">：</font>

```shell
➜  ~ ls -l /bin/ping
-rwxr-xr-x. 1 root root 67664 Mar 22  2022 /bin/ping

# Mac: brew install coreutils
# RHEL 8 OS以及高版本的OS似乎已经没有这样的 Capabilities
➜  ~ getcap /bin/ping
/bin/ping = cap_net_admin,cap_net_raw+p
```

<font style="color:rgb(28, 30, 33);">我们可以看到具有 </font>`<font style="color:#DF2A3F;">cap_net_admin</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">这个属性，所以我们现在可以执行 </font>`<font style="color:#DF2A3F;">ping</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">命令：</font>

```shell
➜  ~ ping -c 4 -w 1 www.qikqiak.com
PING www.qikqiak.com.w.kunlungr.com (163.181.81.221) 56(84) bytes of data.
64 bytes from 163.181.81.221 (163.181.81.221): icmp_seq=1 ttl=57 time=34.4 ms

--- www.qikqiak.com.w.kunlungr.com ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 34.395/34.395/34.395/0.000 ms
```

<font style="color:rgb(28, 30, 33);">但是如果我们把命令的 </font>`<font style="color:#DF2A3F;">capabilities</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">属性移除掉：</font>

```shell
➜  ~ sudo setcap cap_net_admin,cap_net_raw-p /bin/ping
➜  ~ getcap /bin/ping
/bin/ping =
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760580311609-63d2a3b6-7de5-43c5-9452-198e6e19e5e3.png)

<font style="color:rgb(28, 30, 33);">这个时候我们执行 </font>`<font style="color:#DF2A3F;">ping</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">命令可以发现已经没有权限了：</font>

```shell
➜  ~ ping -c 4 -w 1 www.qikqiak.com
ping: socket: Operation not permitted
```

<font style="color:rgb(28, 30, 33);">因为 ping 命令在执行时需要访问网络，所需的 </font>`<font style="color:#DF2A3F;">capabilities</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">为 </font>`<font style="color:#DF2A3F;">cap_net_admin</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">和 </font>`<font style="color:#DF2A3F;">cap_net_raw</font>`<font style="color:rgb(28, 30, 33);">，所以我们可以通过 </font>`<font style="color:#DF2A3F;">setcap</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">命令可来添加它们：</font>

```shell
➜  ~ sudo setcap cap_net_admin,cap_net_raw+p /bin/ping
➜  ~ getcap /bin/ping
/bin/ping = cap_net_admin,cap_net_raw+p

➜  ~ ping -c 4 -w 1 www.qikqiak.com
PING www.qikqiak.com.w.kunlungr.com (163.181.199.202) 56(84) bytes of data.
64 bytes from 163.181.199.202 (163.181.199.202): icmp_seq=1 ttl=57 time=34.4 ms

--- www.qikqiak.com.w.kunlungr.com ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 34.422/34.422/34.422/0.000 ms
```

<font style="color:rgb(28, 30, 33);">命令中的 </font>`<font style="color:#DF2A3F;">p</font>`<font style="color:rgb(28, 30, 33);"> 表示 </font>`<font style="color:#DF2A3F;">Permitted</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">集合(接下来会介绍)，</font>`<font style="color:#DF2A3F;">+</font>`<font style="color:rgb(28, 30, 33);"> 号表示把指定的</font>`<font style="color:#DF2A3F;">capabilities</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">添加到这些集合中，</font>`<font style="color:#DF2A3F;">-</font>`<font style="color:rgb(28, 30, 33);"> 号表示从集合中移除。</font>

<font style="color:rgb(28, 30, 33);">对于可执行文件的属性中有三个集合来保存三类 </font>`<font style="color:#DF2A3F;">capabilities</font>`<font style="color:rgb(28, 30, 33);">，它们分别是：</font>

+ `<font style="color:#DF2A3F;">Permitted</font>`<font style="color:rgb(28, 30, 33);">：在进程执行时，Permitted 集合中的 capabilites 自动被加入到进程的 Permitted 集合中。</font>
+ `<font style="color:#DF2A3F;">Inheritable</font>`<font style="color:rgb(28, 30, 33);">：Inheritable 集合中的 capabilites 会与进程的 Inheritable 集合执行与操作，以确定进程在执行 execve 函数后哪些 capabilites 被继承。</font>
+ `<font style="color:#DF2A3F;">Effective</font>`<font style="color:rgb(28, 30, 33);">：Effective 只是一个 bit。如果设置为开启，那么在执行 execve 函数后，Permitted 集合中新增的 capabilities 会自动出现在进程的 Effective 集合中。</font>

<font style="color:rgb(28, 30, 33);">对于进程中有五种 </font>`<font style="color:#DF2A3F;">capabilities</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">集合类型，相比文件的 </font>`<font style="color:#DF2A3F;">capabilites</font>`<font style="color:rgb(28, 30, 33);">，进程的 </font>`<font style="color:#DF2A3F;">capabilities</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">多了两个集合，分别是 </font>`<font style="color:#DF2A3F;">Bounding</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">和 </font>`<font style="color:#DF2A3F;">Ambient</font>`<font style="color:rgb(28, 30, 33);">。</font>

<font style="color:rgb(28, 30, 33);">我们可以通过下面的命名来查看当前进程的 </font>`<font style="color:#DF2A3F;">capabilities</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">信息：</font>

```shell
➜  ~ cat /proc/7029/status | grep 'Cap'  # 7029为PID
CapInh: 0000000000000000
CapPrm: 0000000000000000
CapEff: 0000000000000000
CapBnd: 0000001fffffffff
CapAmb: 0000000000000000
```

<font style="color:rgb(28, 30, 33);">然后我们可以使用 </font>`<font style="color:#DF2A3F;">capsh</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">命令把它们转义为可读的格式，这样基本可以看出进程具有的 </font>`<font style="color:#DF2A3F;">capabilities</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">了：</font>

```shell
# capsh是权限管理的精细化工具，适用于安全加固、容器配置等场景。通过合理设置能力，可在保证功能的同时最小化安全风险。建议结合 getcap/setcap管理文件能力，并定期审计进程权限
➜  ~ capsh --decode=0000001fffffffff
0x0000001fffffffff=cap_chown,cap_dac_override,cap_dac_read_search,cap_fowner,cap_fsetid,cap_kill,cap_setgid,cap_setuid,cap_setpcap,cap_linux_immutable,cap_net_bind_service,cap_net_broadcast,cap_net_admin,cap_net_raw,cap_ipc_lock,cap_ipc_owner,cap_sys_module,cap_sys_rawio,cap_sys_chroot,cap_sys_ptrace,cap_sys_pacct,cap_sys_admin,cap_sys_boot,cap_sys_nice,cap_sys_resource,cap_sys_time,cap_sys_tty_config,cap_mknod,cap_lease,cap_audit_write,cap_audit_control,cap_setfcap,cap_mac_override,cap_mac_admin,cap_syslog,35,36
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760580452278-81505564-83bd-4080-94b0-bcf2fe34e9a5.png)

### <font style="color:rgb(28, 30, 33);">3.2 Container Runtime Capabilities</font>
<font style="color:rgb(28, 30, 33);">我们说容器本质上就是一个进程，所以理论上容器就会和进程一样会有一些默认的开放权限，默认情况下 Docker/Containerd 会删除必须的 </font>`<font style="color:#DF2A3F;">capabilities</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">之外的所有 </font>`<font style="color:#DF2A3F;">capabilities</font>`<font style="color:rgb(28, 30, 33);">，因为在容器中我们经常会以 root 用户来运行，使用 </font>`<font style="color:#DF2A3F;">capabilities</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">现在后，容器中的使用的 root 用户权限就比我们平时在宿主机上使用的 root 用户权限要少很多了，这样即使出现了安全漏洞，也很难破坏或者获取宿主机的 root 权限，所以 Docker/Containerd 支持 </font>`<font style="color:#DF2A3F;">Capabilities</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">对于容器的安全性来说是非常有必要的。</font>

<font style="color:rgb(28, 30, 33);">不过我们在运行容器的时候可以通过指定 </font>`<font style="color:#DF2A3F;">--privileded</font>`<font style="color:rgb(28, 30, 33);"> 参数来开启容器的超级权限，这个参数一定要慎用，因为他会获取系统 root 用户所有能力赋值给容器，并且会扫描宿主机的所有设备文件挂载到容器内部，所以是非常危险的操作。</font>

<font style="color:rgb(28, 30, 33);">但是如果你确实需要一些特殊的权限，我们可以通过 </font>`<font style="color:#DF2A3F;">--cap-add</font>`<font style="color:rgb(28, 30, 33);"> 和 </font>`<font style="color:#DF2A3F;">--cap-drop</font>`<font style="color:rgb(28, 30, 33);"> 这两个参数来动态调整，可以最大限度地保证容器的使用安全。下面表格中列出的 </font>`<font style="color:#DF2A3F;">Capabilities</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">是 Docker 默认给容器添加的，我们可以通过 </font>`<font style="color:#DF2A3F;">--cap-drop</font>`<font style="color:rgb(28, 30, 33);"> 去除其中一个或者多个：</font>

![](https://cdn.nlark.com/yuque/0/2024/jpeg/2555283/1731570149133-ced37767-8e97-45c1-b113-c069b4e9673f.jpeg)

<font style="color:rgb(28, 30, 33);">下面表格中列出的 </font>`<font style="color:#DF2A3F;">Capabilities</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">是 Docker 默认删除的，我们可以通过</font>`<font style="color:#DF2A3F;">--cap-add</font>`<font style="color:rgb(28, 30, 33);">添加其中一个或者多个：</font>

![](https://cdn.nlark.com/yuque/0/2024/jpeg/2555283/1731570149084-997b2152-4a03-4ebc-b105-fd661917dbfe.jpeg)

`<font style="color:#DF2A3F;">--cap-add</font>`和`<font style="color:#DF2A3F;">--cap-drop</font>` 这两参数都支持`<font style="color:#DF2A3F;">ALL</font>`值，比如如果你想让某个容器拥有除了`<font style="color:#DF2A3F;">MKNOD</font>`之外的所有内核权限，那么可以执行下面的命令： `<font style="color:#DF2A3F;">➜ ~ sudo docker run --cap-add=ALL --cap-drop=MKNOD ...</font>`

<font style="color:rgb(28, 30, 33);">比如现在我们需要修改网络接口数据，默认情况下是没有权限的，因为需要的 </font>`<font style="color:#DF2A3F;">NET_ADMIN</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">这个 </font>`<font style="color:#DF2A3F;">Capabilities</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">默认被移除了：</font>

```shell
# nerdctl 的方式
➜  ~ nerdctl run -it --rm busybox /bin/sh
/ # ip link add dummy0 type dummy
ip: RTNETLINK answers: Operation not permitted
/ #

# docker 的方式
➜  ~ docker run -it --rm busybox /bin/sh
/ # ip link add dummy0 type dummy
ip: RTNETLINK answers: Operation not permitted
/ #
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760580579464-d99f2690-0f98-4307-996a-7e4c2d61a32c.png)

<font style="color:rgb(28, 30, 33);">所以在不使用 </font>`<font style="color:#DF2A3F;">--privileged</font>`<font style="color:rgb(28, 30, 33);"> 的情况下（不建议）我们可以使用 </font>`<font style="color:#DF2A3F;">--cap-add=NET_ADMIN</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">将这个 </font>`<font style="color:#DF2A3F;">Capabilities</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">添加回来：</font>

```shell
# nerdctl 的方式
➜  ~ nerdctl run -it --rm --cap-add=NET_ADMIN busybox /bin/sh
/ # ip link add dummy0 type dummy
/ # ip link show 
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: eth0@if41: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue 
    link/ether a6:87:68:0f:3d:06 brd ff:ff:ff:ff:ff:ff
3: dummy0: <BROADCAST,NOARP> mtu 1500 qdisc noop qlen 1000
    link/ether 52:bb:89:ea:cb:95 brd ff:ff:ff:ff:ff:ff

# docker 的方式
➜  ~ docker run -it --rm --cap-add=NET_ADMIN busybox /bin/sh
/ # ip link add dummy0 type dummy
/ # ip link show 
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: tunl0@NONE: <NOARP> mtu 1480 qdisc noop qlen 1000
    link/ipip 0.0.0.0 brd 0.0.0.0
3: dummy0: <BROADCAST,NOARP> mtu 1500 qdisc noop qlen 1000
    link/ether f2:15:6f:6e:5e:40 brd ff:ff:ff:ff:ff:ff
112: eth0@if113: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue 
    link/ether 02:42:ac:11:00:02 brd ff:ff:ff:ff:ff:ff
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760580624647-5a6fb562-173c-49b3-ac27-3de98e095398.png)

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761366167166-f8d35c57-032f-435e-96e8-1e4fd9992f73.png)

<font style="color:rgb(28, 30, 33);">可以看到已经 OK 了。</font>

### <font style="color:rgb(28, 30, 33);">3.3 Kubernetes 配置 Capabilities</font>
<font style="color:rgb(28, 30, 33);">上面我介绍了在 Docker 容器下如何来配置 </font>`<font style="color:#DF2A3F;">Capabilities</font>`<font style="color:rgb(28, 30, 33);">，在 Kubernetes 中也可以很方便的来定义，我们只需要添加到 Pod 定义的 </font>`<font style="color:#DF2A3F;">spec.containers.securityContext.capabilities</font>`<font style="color:rgb(28, 30, 33);">中即可，也可以进行 </font>`<font style="color:#DF2A3F;">add</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">和 </font>`<font style="color:#DF2A3F;">drop</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">配置，同样上面的示例，我们要给 busybox 容器添加 </font>`<font style="color:#DF2A3F;">NET_ADMIN</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">这个 </font>`<font style="color:#DF2A3F;">Capabilities</font>`<font style="color:rgb(28, 30, 33);">，对应的 YAML 文件可以这样定义：</font>

```yaml
# cpb-demo.yaml
apiVersion: v1
kind: Pod
metadata:
  name: cpb-demo
spec:
  containers:
    - name: cpb
      image: busybox
      args:
        - sleep
        - '3600'
      securityContext:
        capabilities:
          add: # 添加
            - NET_ADMIN
          drop: # 删除
            - KILL
```

<font style="color:rgb(28, 30, 33);">我们在 </font>`<font style="color:#DF2A3F;">securityContext</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">下面添加了 </font>`<font style="color:#DF2A3F;">capabilities</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">字段，其中添加了 </font>`<font style="color:#DF2A3F;">NET_ADMIN</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">并且删除了 </font>`<font style="color:#DF2A3F;">KILL</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">这个默认的容器 </font>`<font style="color:#DF2A3F;">Capabilities</font>`<font style="color:rgb(28, 30, 33);">，这样我们就可以在 Pod 中修改网络接口数据了：</font>

```shell
# 引用资源清单文件
➜  ~ kubectl apply -f cpb-demo.yaml
pod/cpb-demo created

➜  ~ kubectl get pods cpb-demo
NAME       READY   STATUS    RESTARTS   AGE
cpb-demo   1/1     Running   0          10s

➜  ~ kubectl exec -it cpb-demo -- /bin/sh
/ # ip link add dummy0 type dummy
/ # ip link show 
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
3: eth0@if185: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1450 qdisc noqueue 
    link/ether 26:37:8e:3c:83:e6 brd ff:ff:ff:ff:ff:ff
4: dummy0: <BROADCAST,NOARP> mtu 1500 qdisc noop qlen 1000
    link/ether f6:34:a0:ea:43:da brd ff:ff:ff:ff:ff:ff
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760580762726-dc39c19e-6ff3-4ba9-9be9-aea744afe404.png)

<font style="color:rgb(28, 30, 33);">在 Kubernetes 中通过 </font>`<font style="color:#DF2A3F;">containers.securityContext.capabilities</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">进行配置容器的 </font>`<font style="color:#DF2A3F;">Capabilities</font>`<font style="color:rgb(28, 30, 33);">，当然最终还是通过容器运行时的 </font>`<font style="color:#DF2A3F;">libcontainer</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">去借助 </font>`<font style="color:#DF2A3F;">Linux kernel capabilities</font>`<font style="color:rgb(28, 30, 33);"> 实现的权限管理。</font>

## <font style="color:rgb(28, 30, 33);">4 参考资料</font>
[🕸️[K8S] 18 Security Context [安全上下文]的使用](https://www.yuque.com/seekerzw/xi8l23/ahurl2agtg8qq013)

