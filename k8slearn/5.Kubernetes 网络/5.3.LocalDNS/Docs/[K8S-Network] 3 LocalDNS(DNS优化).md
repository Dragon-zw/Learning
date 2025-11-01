前面我们讲解了在 Kubernetes 中我们可以使用 CoreDNS 来进行集群的域名解析，但是如果在集群规模较大并发较高的情况下我们仍然需要对 DNS 进行优化，典型的就是大家比较熟悉的 CoreDNS 会出现超时 5s 的情况。

## 1 超时原因
在 iptables 模式下（默认情况下），每个服务的 kube-proxy 在主机网络名称空间的 nat 表中创建一些 iptables 规则。

比如在集群中具有两个 DNS 服务器实例的 kube-dns 服务，其相关规则大致如下所示：

```shell
(1) -A PREROUTING -m comment --comment "kubernetes service portals" -j KUBE-SERVICES
<...>
(2) -A KUBE-SERVICES -d 192.96.0.10/32 -p udp -m comment --comment "kube-system/kube-dns:dns cluster IP" -m udp --dport 53 -j KUBE-SVC-TCOU7JCQXEZGVUNU
<...>
(3) -A KUBE-SVC-TCOU7JCQXEZGVUNU -m comment --comment "kube-system/kube-dns:dns" -m statistic --mode random --probability 0.50000000000 -j KUBE-SEP-LLLB6FGXBLX6PZF7
(4) -A KUBE-SVC-TCOU7JCQXEZGVUNU -m comment --comment "kube-system/kube-dns:dns" -j KUBE-SEP-LRVEW52VMYCOUSMZ
<...>
(5) -A KUBE-SEP-LLLB6FGXBLX6PZF7 -p udp -m comment --comment "kube-system/kube-dns:dns" -m udp -j DNAT --to-destination 10.32.0.6:53
<...>
(6) -A KUBE-SEP-LRVEW52VMYCOUSMZ -p udp -m comment --comment "kube-system/kube-dns:dns" -m udp -j DNAT --to-destination 10.32.0.7:53
```

我们知道每个 Pod 的 `<font style="color:#DF2A3F;">/etc/resolv.conf</font>` 文件中都有填充的 `<font style="color:#DF2A3F;">nameserver 192.96.0.10</font>` 这个条目。所以来自 Pod 的 DNS 查找请求将发送到 `<font style="color:#DF2A3F;">192.96.0.10</font>`，这是 kube-dns 服务的 ClusterIP 地址。

由于 `<font style="color:#DF2A3F;">(1)</font>` 请求进入 `<font style="color:#DF2A3F;">KUBE-SERVICE</font>` 链，然后匹配规则 `<font style="color:#DF2A3F;">(2)</font>`，最后根据 `<font style="color:#DF2A3F;">(3)</font>` 的 random 随机模式，跳转到 (5) 或 (6) 条目，将请求 UDP 数据包的目标 IP 地址修改为 DNS 服务器的`<font style="color:#DF2A3F;">实际</font>` IP 地址，这是通过 `<font style="color:#DF2A3F;">DNAT</font>`<font style="color:#DF2A3F;"> </font>完成的。其中<font style="color:#DF2A3F;"> </font>`<font style="color:#DF2A3F;">10.32.0.6</font>` 和 `<font style="color:#DF2A3F;">10.32.0.7</font>` 是我们集群中 CoreDNS 的两个 Pod 副本的 IP 地址。

### 1.1 内核中的 DNAT
`<u><font style="color:#DF2A3F;">DNAT</font></u>`<u><font style="color:#DF2A3F;"> </font></u><u>的主要职责是同时更改传出数据包的目的地，响应数据包的源，并确保对所有后续数据包进行相同的修改。</u>后者严重依赖于连接跟踪机制，也称为 `<font style="color:#DF2A3F;">conntrack</font>`，它被实现为内核模块。`<font style="color:#DF2A3F;">conntrack</font>`<font style="color:#DF2A3F;"> </font>会跟踪系统中正在进行的网络连接。

`<font style="color:#DF2A3F;">conntrack</font>`<font style="color:#DF2A3F;"> </font>中的每个连接都由两个元组表示，一个元组用于原始请求（`<font style="color:#DF2A3F;">IP_CT_DIR_ORIGINAL</font>`），另一个元组用于答复（`<font style="color:#DF2A3F;">IP_CT_DIR_REPLY</font>`）。对于 UDP，每个元组都由源 IP 地址，源端口以及目标 IP 地址和目标端口组成，答复元组包含存储在 src 字段中的目标的真实地址。

例如，如果 IP 地址为 `<font style="color:#DF2A3F;">10.40.0.17</font>` 的 Pod 向 kube-dns 的 ClusterIP 发送一个请求，该请求被转换为<font style="color:#DF2A3F;"> </font>`<font style="color:#DF2A3F;">10.32.0.6</font>`，则将创建以下元组：

```shell
原始：src = 10.40.0.17 dst = 192.96.0.10 sport = 53378 dport = 53
回复：src = 10.32.0.6 dst = 10.40.0.17 sport = 53 dport = 53378
```

通过这些条目内核可以相应地修改任何相关数据包的目的地和源地址，而无需再次遍历 DNAT 规则，此外，它将知道如何修改回复以及应将回复发送给谁。创建 `<font style="color:#DF2A3F;">conntrack</font>`<font style="color:#DF2A3F;"> </font>条目后，将首先对其进行确认，然后如果没有已确认的 `<font style="color:#DF2A3F;">conntrack</font>`<font style="color:#DF2A3F;"> </font>条目具有相同的原始元组或回复元组，则内核将尝试确认该条目。`<font style="color:#DF2A3F;">conntrack</font>`<font style="color:#DF2A3F;"> </font>创建和 DNAT 的简化流程如下所示：

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570443925-2de223ed-3232-40b0-88e1-8b2e05cf4b66.png)

### 1.2 问题
DNS 客户端 (glibc 或 musl libc) 会并发请求 A 和 AAAA 记录，跟 DNS Server 通信自然会先 connect (建立 fd)，后面请求报文使用这个 fd 来发送，由于 UDP 是无状态协议，connect 时并不会创建 `<font style="color:#DF2A3F;">conntrack</font>`<font style="color:#DF2A3F;"> </font>表项，而并发请求的 A 和 AAAA 记录默认使用同一个 fd 发包，这时它们源 Port 相同，当并发发包时，两个包都还没有被插入 conntrack 表项，所以 netfilter 会为它们分别创建 conntrack 表项，而集群内请求 CoreDNS 都是访问的 CLUSTER-IP，报文最终会被 DNAT 成一个具体的 Pod IP，当两个包被 DNAT 成同一个 IP，最终它们的五元组就相同了，在最终插入的时候后面那个包就会被丢掉，<u><font style="color:#DF2A3F;">如果 DNS 的 Pod 副本只有一个实例的情况就很容易发生，现象就是 DNS 请求超时，客户端默认策略是等待 5s 自动重试，如果重试成功，我们看到的现象就是 DNS 请求有 5s 的延时。</font></u>

具体原因可以参考 weave works 总结的文章 [Racy conntrack and DNS lookup timeouts](https://www.weave.works/blog/racy-conntrack-and-dns-lookup-timeouts)。

+ 只有多个线程或进程，并发从同一个 socket 发送相同五元组的 UDP 报文时，才有一定概率会发生
+ glibc、musl（alpine linux 的 libc 库）都使用 `<font style="color:#DF2A3F;">parallel query</font>`, 就是并发发出多个查询请求，因此很容易碰到这样的冲突，造成查询请求被丢弃
+ 由于 IPVS 也使用了 conntrack, 使用 kube-proxy 的 IPVS 模式，并不能避免这个问题

## 2 解决方法
:::success
<u><font style="color:#DF2A3F;">要彻底解决这个问题最好当然是内核上去 FIX 掉这个 BUG，除了这种方法之外我们还可以使用其他方法来进行规避，我们可以避免相同五元组 DNS 请求的并发。</font></u>

:::

在 `<font style="color:#DF2A3F;">resolv.conf</font>` 中就有两个相关的参数可以进行配置：

+ `<font style="color:#DF2A3F;">single-request-reopen</font>`：发送 A 类型请求和 AAAA 类型请求使用不同的源端口，这样两个请求在 conntrack 表中不占用同一个表项，从而避免冲突。
+ `<font style="color:#DF2A3F;">single-request</font>`：避免并发，改为串行发送 A 类型和 AAAA 类型请求。没有了并发，从而也避免了冲突。

要给容器的 `<font style="color:#DF2A3F;">resolv.conf</font>`<font style="color:#DF2A3F;"> </font>加上 options 参数，有几个办法：

    1. 在容器的 `<font style="color:#DF2A3F;">ENTRYPOINT</font>`<font style="color:#DF2A3F;"> </font>或者 `<font style="color:#DF2A3F;">CMD</font>`<font style="color:#DF2A3F;"> </font>脚本中，执行 `<font style="color:#DF2A3F;">/bin/echo 'options single-request-reopen' >> /etc/resolv.conf</font>`
    2. 在 Pod 的 postStart hook 中添加：

```yaml
lifecycle:
  postStart:
    exec:
      command:
        - /bin/sh
        - -c
        - "/bin/echo 'options single-request-reopen' >> /etc/resolv.conf"
```

    1. 使用 `<font style="color:#DF2A3F;">template.spec.dnsConfig</font>` 配置:

```yaml
template:
  spec:
    dnsConfig:
      options:
        - name: single-request-reopen
```

    1. 使用 ConfigMap 覆盖 Pod 里面的 `<font style="color:#DF2A3F;">/etc/resolv.conf</font>`：

```yaml
# configmap
apiVersion: v1
data:
  resolv.conf: |
    nameserver 1.2.3.4
    search default.svc.cluster.local svc.cluster.local cluster.local
    options ndots:5 single-request-reopen timeout:1
kind: ConfigMap
metadata:
  name: resolvconf
---
# Pod Spec
spec:
  volumeMounts:
    - name: resolv-conf
      mountPath: /etc/resolv.conf
      subPath: resolv.conf # 在某个目录下面挂载一个文件（保证不覆盖当前目录）需要使用subPath -> 不支持热更新
---
volumes:
  - name: resolv-conf
    configMap:
      name: resolvconf
      items:
        - key: resolv.conf
          path: resolv.conf
```

<u>上面的方法在一定程度上可以解决 DNS 超时的问题，但更好的方式是</u>**<u><font style="color:#DF2A3F;">使用本地 DNS 缓存</font></u>**<u>，容器的 DNS 请求都发往本地的 DNS 缓存服务，也就不需要走 DNAT，当然也不会发生 </u>`<u><font style="color:#DF2A3F;">conntrack</font></u>`<u><font style="color:#DF2A3F;"> </font></u><u>冲突了，而且还可以有效提升 CoreDNS 的性能瓶颈。</u>

## 3 性能测试
这里我们使用一个简单的 Golang 程序来测试下使用本地 DNS 缓存的前后性能。代码如下所示：

```go
// main.go
package main

import (
    "context"
    "flag"
    "fmt"
    "net"
    "sync/atomic"
    "time"
)

var host string
var connections int
var duration int64
var limit int64
var timeoutCount int64

func main() {
    flag.StringVar(&host, "host", "", "Resolve host")
    flag.IntVar(&connections, "c", 100, "Connections")
    flag.Int64Var(&duration, "d", 0, "Duration(s)")
    flag.Int64Var(&limit, "l", 0, "Limit(ms)")
    flag.Parse()

    var count int64 = 0
    var errCount int64 = 0
    pool := make(chan interface{}, connections)
    exit := make(chan bool)
    var (
        min int64 = 0
        max int64 = 0
        sum int64 = 0
    )

    go func() {
        time.Sleep(time.Second * time.Duration(duration))
        exit <- true
    }()

endD:
    for {
        select {
        case pool <- nil:
            go func() {
                defer func() {
                    <-pool
                }()
                resolver := &net.Resolver{}
                now := time.Now()
                _, err := resolver.LookupIPAddr(context.Background(), host)
                use := time.Since(now).Nanoseconds() / int64(time.Millisecond)
                if min == 0 || use < min {
                    min = use
                }
                if use > max {
                    max = use
                }
                sum += use
                if limit > 0 && use >= limit {
                    timeoutCount++
                }
                atomic.AddInt64(&count, 1)
                if err != nil {
                    fmt.Println(err.Error())
                    atomic.AddInt64(&errCount, 1)
                }
            }()
        case <-exit:
            break endD
        }
    }
    fmt.Printf("request count：%d\nerror count：%d\n", count, errCount)
    fmt.Printf("request time：min(%dms) max(%dms) avg(%dms) timeout(%dn)\n", min, max, sum/count, timeoutCount)
}
```

<details class="lake-collapse"><summary id="u8f645126" style="text-align: left"><span class="ne-text">testdns 二进制命令的参数</span></summary><div data-type="success" class="ne-alert"><ul class="ne-ul"><li id="ubf635a00" data-lake-index-type="0" style="text-align: left"><code class="ne-code"><span class="ne-text">-host nginx-service.default</span></code><span class="ne-text">: 要解析的域名（DNS 查询目标）</span></li><li id="u76d98d68" data-lake-index-type="0" style="text-align: left"><code class="ne-code"><span class="ne-text">-c 200</span></code><span class="ne-text">: 并发连接数，同时发起 200 个 DNS 查询</span></li><li id="u4d774fe8" data-lake-index-type="0" style="text-align: left"><code class="ne-code"><span class="ne-text">-d 30</span></code><span class="ne-text">: 持续时间 30 秒，程序会在 30 秒内不断发起 DNS 查询</span></li><li id="ua7f97b32" data-lake-index-type="0" style="text-align: left"><code class="ne-code"><span class="ne-text">-l 5000</span></code><span class="ne-text">: 超时限制 5000 毫秒（5秒），如果单次 DNS 查询超过 5 秒就计入超时统计</span></li></ul></div></details>
首先配置好 Golang 环境，然后直接构建上面的测试应用：

```shell
$ go mod tidy 
$ go build -o testdns .
```

构建完成后生成一个 testdns 的二进制文件，然后我们将这个二进制文件拷贝到任意一个 Pod 中去进行测试：

```shell
$ kubectl get pod -l app=nginx 
NAME                            READY   STATUS    RESTARTS   AGE
nginx-deploy-57b754799f-hxdn2   1/1     Running   0          5s
nginx-deploy-57b754799f-lhll6   1/1     Running   0          5s

$ kubectl cp testdns nginx-deploy-57b754799f-hxdn2:/root -n default
```

拷贝完成后进入这个测试的 Pod 中去：

```shell
$ kubectl exec -it nginx-deploy-57b754799f-hxdn2 -- /bin/bash
root@nginx-deploy-57b754799f-hxdn2:/# cat /etc/resolv.conf 
search default.svc.cluster.local svc.cluster.local cluster.local
nameserver 192.96.0.10
options ndots:5
root@nginx-deploy-57b754799f-hxdn2:/# cd /root/ && ls -l 
total 3116
-rwxr-xr-x 1 root root 3187585 Oct 16 16:00 testdns
```

然后我们执行 testdns 程序来进行压力测试，比如执行 200 个并发，持续 30 秒：

```shell
# 对 nginx-service.default 这个地址进行解析
root@svc-demo-546b7bcdcf-6xsnr:~# ./testdns -host nginx-service.default -c 200 -d 30 -l 5000
lookup nginx-service.default on 192.96.0.10:53: no such host
lookup nginx-service.default on 192.96.0.10:53: no such host
lookup nginx-service.default on 192.96.0.10:53: no such host
lookup nginx-service.default on 192.96.0.10:53: no such host
lookup nginx-service.default on 192.96.0.10:53: no such host
request count：12533
error count：5
request time：min(5ms) max(16871ms) avg(425ms) timeout(475n)

root@svc-demo-546b7bcdcf-6xsnr:~# ./testdns -host nginx-service.default -c 200 -d 30 -l 5000
lookup nginx-service.default on 192.96.0.10:53: no such host
lookup nginx-service.default on 192.96.0.10:53: no such host
lookup nginx-service.default on 192.96.0.10:53: no such host
request count：10058
error count：3
request time：min(4ms) max(12347ms) avg(540ms) timeout(487n)

root@svc-demo-546b7bcdcf-6xsnr:~# ./testdns -host nginx-service.default -c 200 -d 30 -l 5000
lookup nginx-service.default on 192.96.0.10:53: no such host
lookup nginx-service.default on 192.96.0.10:53: no such host
request count：12242
error count：2
request time：min(3ms) max(12206ms) avg(478ms) timeout(644n)

root@svc-demo-546b7bcdcf-6xsnr:~# ./testdns -host nginx-service.default -c 200 -d 30 -l 5000
request count：11008
error count：0
request time：min(3ms) max(11110ms) avg(496ms) timeout(478n)

root@svc-demo-546b7bcdcf-6xsnr:~# ./testdns -host nginx-service.default -c 200 -d 30 -l 5000
request count：9126
error count：0
request time：min(4ms) max(11554ms) avg(613ms) timeout(197n)
```

我们可以看到大部分平均耗时都是在 `<font style="color:#DF2A3F;">500ms</font>` 左右，这个性能是非常差的，而且还有部分解析失败的条目。接下来我们就来尝试使用 `<font style="color:#DF2A3F;">NodeLocal DNSCache</font>`<font style="color:#DF2A3F;"> </font>来提升 DNS 的性能和可靠性。

## 4 NodeLocal DNSCache
### 4.1 NodeLocal DNSCache 定义
`<font style="color:#DF2A3F;">NodeLocal DNSCache</font>` 通过在集群节点上运行一个 DaemonSet 来提高集群 DNS 性能和可靠性。处于 ClusterFirst 的 DNS 模式下的 Pod 可以连接到 kube-dns 的 serviceIP 进行 DNS 查询，通过 kube-proxy 组件添加的 iptables 规则将其转换为 CoreDNS 端点。通过在每个集群节点上运行 DNS 缓存，`<font style="color:#DF2A3F;">NodeLocal DNSCache</font>`<font style="color:#DF2A3F;"> </font>可以缩短 DNS 查找的延迟时间、使 DNS 查找时间更加一致，以及减少发送到 kube-dns 的 DNS 查询次数。

在集群中运行 `<font style="color:#DF2A3F;">NodeLocal DNSCache</font>` 有如下几个好处：

+ 如果本地没有 CoreDNS 实例，则具有最高 DNS QPS 的 Pod 可能必须到另一个节点进行解析，使用 `<font style="color:#DF2A3F;">NodeLocal DNSCache</font>` 后，拥有本地缓存将有助于改善延迟
+ 跳过 iptables DNAT 和连接跟踪将有助于减少 conntrack 竞争并避免 UDP DNS 条目填满 conntrack 表（上面提到的 5s 超时问题就是这个原因造成的）
+ 从本地缓存代理到 kube-dns 服务的连接可以升级到 TCP，TCP conntrack 条目将在连接关闭时被删除，而 UDP 条目必须超时(默认 `<font style="color:#DF2A3F;">nfconntrackudp_timeout</font>`<font style="color:#DF2A3F;"> </font>是 30 秒)
+ 将 DNS 查询从 UDP 升级到 TCP 将减少归因于丢弃的 UDP 数据包和 DNS 超时的尾部等待时间，通常长达 30 秒（3 次重试+ 10 秒超时）

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1731570451985-9103121f-f247-49fb-a7f9-693fbdb61963.png)

### 4.2 NodeLocal DNSCache 部署
要安装 `<font style="color:#DF2A3F;">NodeLocal</font> <font style="color:#DF2A3F;">DNSCache</font>`<font style="color:#DF2A3F;"> </font>也非常简单，直接获取官方的资源清单即可：

```shell
wget https://github.com/kubernetes/kubernetes/raw/master/cluster/addons/dns/nodelocaldns/nodelocaldns.yaml
```

<details class="lake-collapse"><summary id="u350535a5" style="text-align: left"><span class="ne-text">nodelocaldns.yaml 配置文件内容</span></summary><pre data-language="yaml" id="ysN3P" class="ne-codeblock language-yaml"><code># Copyright 2018 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the &quot;License&quot;);
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an &quot;AS IS&quot; BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

apiVersion: v1
kind: ServiceAccount
metadata:
  name: node-local-dns
  namespace: kube-system
  labels:
    kubernetes.io/cluster-service: &quot;true&quot;
    addonmanager.kubernetes.io/mode: Reconcile
---
apiVersion: v1
kind: Service
metadata:
  name: kube-dns-upstream
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: &quot;true&quot;
    addonmanager.kubernetes.io/mode: Reconcile
    kubernetes.io/name: &quot;KubeDNSUpstream&quot;
spec:
  ports:
  - name: dns
    port: 53
    protocol: UDP
    targetPort: 53
  - name: dns-tcp
    port: 53
    protocol: TCP
    targetPort: 53
  selector:
    k8s-app: kube-dns
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: node-local-dns
  namespace: kube-system
  labels:
    addonmanager.kubernetes.io/mode: Reconcile
data:
  Corefile: |
    __PILLAR__DNS__DOMAIN__:53 {
        errors
        cache {
                success 9984 30
                denial 9984 5
        }
        reload
        loop
        bind __PILLAR__LOCAL__DNS__ __PILLAR__DNS__SERVER__
        forward . __PILLAR__CLUSTER__DNS__ {
                force_tcp
        }
        prometheus :9253
        health __PILLAR__LOCAL__DNS__:8080
        }
    in-addr.arpa:53 {
        errors
        cache 30
        reload
        loop
        bind __PILLAR__LOCAL__DNS__ __PILLAR__DNS__SERVER__
        forward . __PILLAR__CLUSTER__DNS__ {
                force_tcp
        }
        prometheus :9253
        }
    ip6.arpa:53 {
        errors
        cache 30
        reload
        loop
        bind __PILLAR__LOCAL__DNS__ __PILLAR__DNS__SERVER__
        forward . __PILLAR__CLUSTER__DNS__ {
                force_tcp
        }
        prometheus :9253
        }
    .:53 {
        errors
        cache 30
        reload
        loop
        bind __PILLAR__LOCAL__DNS__ __PILLAR__DNS__SERVER__
        forward . __PILLAR__UPSTREAM__SERVERS__
        prometheus :9253
        }
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-local-dns
  namespace: kube-system
  labels:
    k8s-app: node-local-dns
    kubernetes.io/cluster-service: &quot;true&quot;
    addonmanager.kubernetes.io/mode: Reconcile
spec:
  updateStrategy:
    rollingUpdate:
      maxUnavailable: 10%
  selector:
    matchLabels:
      k8s-app: node-local-dns
  template:
    metadata:
      labels:
        k8s-app: node-local-dns
      annotations:
        prometheus.io/port: &quot;9253&quot;
        prometheus.io/scrape: &quot;true&quot;
    spec:
      priorityClassName: system-node-critical
      serviceAccountName: node-local-dns
      hostNetwork: true
      dnsPolicy: Default  # Don't use cluster DNS.
      tolerations:
      - key: &quot;CriticalAddonsOnly&quot;
        operator: &quot;Exists&quot;
      - effect: &quot;NoExecute&quot;
        operator: &quot;Exists&quot;
      - effect: &quot;NoSchedule&quot;
        operator: &quot;Exists&quot;
      containers:
      - name: node-cache
        image: registry.k8s.io/dns/k8s-dns-node-cache:1.26.4
        resources:
          requests:
            cpu: 25m
            memory: 5Mi
        args: [ &quot;-localip&quot;, &quot;__PILLAR__LOCAL__DNS__,__PILLAR__DNS__SERVER__&quot;, &quot;-conf&quot;, &quot;/etc/Corefile&quot;, &quot;-upstreamsvc&quot;, &quot;kube-dns-upstream&quot; ]
        securityContext:
          capabilities:
            add:
            - NET_ADMIN
        ports:
        - containerPort: 53
          name: dns
          protocol: UDP
        - containerPort: 53
          name: dns-tcp
          protocol: TCP
        - containerPort: 9253
          name: metrics
          protocol: TCP
        livenessProbe:
          httpGet:
            host: __PILLAR__LOCAL__DNS__
            path: /health
            port: 8080
          initialDelaySeconds: 60
          timeoutSeconds: 5
        volumeMounts:
        - mountPath: /run/xtables.lock
          name: xtables-lock
          readOnly: false
        - name: config-volume
          mountPath: /etc/coredns
        - name: kube-dns-config
          mountPath: /etc/kube-dns
      volumes:
      - name: xtables-lock
        hostPath:
          path: /run/xtables.lock
          type: FileOrCreate
      - name: kube-dns-config
        configMap:
          name: kube-dns
          optional: true
      - name: config-volume
        configMap:
          name: node-local-dns
          items:
            - key: Corefile
              path: Corefile.base
---
# A headless service is a service with a service IP but instead of load-balancing it will return the IPs of our associated Pods.
# We use this to expose metrics to Prometheus.
apiVersion: v1
kind: Service
metadata:
  annotations:
    prometheus.io/port: &quot;9253&quot;
    prometheus.io/scrape: &quot;true&quot;
  labels:
    k8s-app: node-local-dns
  name: node-local-dns
  namespace: kube-system
spec:
  clusterIP: None
  ports:
    - name: metrics
      port: 9253
      targetPort: 9253
  selector:
    k8s-app: node-local-dns
</code></pre></details>
该资源清单文件中包含几个变量值得注意，其中：

+ `<font style="color:#DF2A3F;">__PILLAR__DNS__SERVER__</font>`<font style="color:#DF2A3F;"> </font>：表示 kube-dns 这个 Service 的 ClusterIP，可以通过命令 `<font style="color:#DF2A3F;">kubectl get svc -n kube-system | grep kube-dns | awk '{ print $3 }'</font>`<font style="color:#DF2A3F;"> </font>获取（我们这里就是 `<font style="color:#DF2A3F;">192.96.0.10</font>`）
+ `<font style="color:#DF2A3F;">__PILLAR__LOCAL__DNS__</font>`：表示 DNSCache 本地的 IP，默认为 `<font style="color:#DF2A3F;">169.254.20.10</font>`
+ `<font style="color:#DF2A3F;">__PILLAR__DNS__DOMAIN__</font>`：表示集群域，默认就是 `<font style="color:#DF2A3F;">cluster.local</font>`

另外还有两个参数 `<font style="color:#DF2A3F;">__PILLAR__CLUSTER__DNS__</font>`<font style="color:#DF2A3F;"> </font>和 `<font style="color:#DF2A3F;">__PILLAR__UPSTREAM__SERVERS__</font>`，这两个参数会通过镜像 `<font style="color:#DF2A3F;">1.15.16</font>` 版本去进行自动配置，对应的值来源于 kube-dns 的 ConfigMap 和定制的 `<font style="color:#DF2A3F;">Upstream Server</font>` 配置。直接执行如下所示的命令即可安装：

```shell
$ kubectl get svc -n kube-system | grep kube-dns | awk '{ print $3 }'
192.96.0.10

$ sed 's/k8s.gcr.io\/dns/cnych/g
s/__PILLAR__DNS__SERVER__/192.96.0.10/g
s/__PILLAR__LOCAL__DNS__/169.254.20.10/g
s/__PILLAR__DNS__DOMAIN__/cluster.local/g' nodelocaldns.yaml |
kubectl apply -f -
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760626279188-d24a8724-d74c-4be1-a407-1f57e8bd8c96.png)

可以通过如下命令来查看对应的 Pod 是否已经启动成功：

```shell
$ kubectl get pods -n kube-system -l k8s-app=node-local-dns -o wide 
NAME                   READY   STATUS    RESTARTS   AGE   IP               NODE             NOMINATED NODE   READINESS GATES
node-local-dns-gmq9m   1/1     Running   0          45s   192.168.178.36   hkk8snode001     <none>           <none>
node-local-dns-sqqc5   1/1     Running   0          45s   192.168.178.35   hkk8smaster001   <none>           <none>
node-local-dns-vpgz8   1/1     Running   0          45s   192.168.178.37   hkk8snode002     <none>           <none>
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760626309628-12f10861-c479-4e32-b5e5-2bd1f2c1c5fe.png)

<u>💡</u><u>需要注意的是这里使用 DaemonSet 部署 </u>`<u><font style="color:#DF2A3F;">node-local-dns</font></u>`<u> 使用了 </u>`<u><font style="color:#DF2A3F;">hostNetwork=true</font></u>`<u>，会占用宿主机的 8080 端口，所以需要保证该端口未被占用。</u>

但是到这里还没有完，如果 kube-proxy 组件使用的是 IPVS 模式的话我们还需要修改 kubelet 的 `<font style="color:#DF2A3F;">--cluster-dns</font>` 参数，将其指向 `<font style="color:#DF2A3F;">169.254.20.10</font>`，Daemonset 会在每个节点创建一个网卡来绑这个 IP，Pod 向本节点这个 IP 发 DNS 请求，缓存没有命中的时候才会再代理到上游集群 DNS 进行查询。iptables 模式下 Pod 还是向原来的集群 DNS 请求，节点上有这个 IP 监听，会被本机拦截，再请求集群上游 DNS，所以不需要更改 `<font style="color:#DF2A3F;">--cluster-dns</font>` 参数。

如果担心线上环境修改 `<font style="color:#DF2A3F;">--cluster-dns</font>` 参数会产生影响，我们也可以直接在新部署的 Pod 中通过 dnsConfig 配置使用新的 LocalDNS 的地址来进行解析。

由于我这里使用的是 kubeadm 安装的 `<font style="color:#DF2A3F;">1.19</font>` 版本的集群，所以我们只需要替换节点上 `<font style="color:#DF2A3F;">/var/lib/kubelet/config.yaml</font>` 文件中的 clusterDNS 这个参数值，然后重启即可：

:::success
LocalDNS 的配置有时候会影响 Calico Node 的网络组件的正常使用！

:::

```shell
# sed -i 's/169.254.20.10/192.96.0.10/g' /var/lib/kubelet/config.yaml
$ sed -i 's/192.96.0.10/169.254.20.10/g' /var/lib/kubelet/config.yaml
$ systemctl daemon-reload && systemctl restart kubelet

# 查看 Kubelet 的状态
$ systemctl status --no-pager -l kubelet
● kubelet.service - kubelet: The Kubernetes Node Agent
   Loaded: loaded (/etc/systemd/system/kubelet.service; enabled; vendor preset: disabled)
  Drop-In: /etc/systemd/system/kubelet.service.d
           └─10-kubeadm.conf
   Active: active (running) since Thu 2025-10-16 22:53:39 HKT; 22s ago
     Docs: https://kubernetes.io/docs/home/
 Main PID: 51871 (kubelet)
    Tasks: 16 (limit: 203828)
   Memory: 51.6M
   CGroup: /system.slice/kubelet.service
           └─51871 /usr/local/bin/kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --root-dir=/var/lib/containerd/kubelet --config=/var/lib/kubelet/config.yaml --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock --pod-infra-container-image=registry.k8s.io/pause:3.9 --tls-cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384

Oct 16 22:53:40 hkk8smaster001 kubelet[51871]: I1016 22:53:40.698345   51871 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"kube-api-access-2mnzx\" (UniqueName: \"kubernetes.io/projected/7f26492b-4743-458a-8303-80d295bd74e8-kube-api-access-2mnzx\") pod \"kruise-daemon-d4plt\" (UID: \"7f26492b-4743-458a-8303-80d295bd74e8\") " pod="kruise-system/kruise-daemon-d4plt"
Oct 16 22:53:40 hkk8smaster001 kubelet[51871]: I1016 22:53:40.698404   51871 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"xtables-lock\" (UniqueName: \"kubernetes.io/host-path/a3eb2639-b770-46ba-905b-ff796fb79d8e-xtables-lock\") pod \"node-local-dns-sqqc5\" (UID: \"a3eb2639-b770-46ba-905b-ff796fb79d8e\") " pod="kube-system/node-local-dns-sqqc5"
Oct 16 22:53:40 hkk8smaster001 kubelet[51871]: I1016 22:53:40.698490   51871 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"config-volume\" (UniqueName: \"kubernetes.io/configmap/a3eb2639-b770-46ba-905b-ff796fb79d8e-config-volume\") pod \"node-local-dns-sqqc5\" (UID: \"a3eb2639-b770-46ba-905b-ff796fb79d8e\") " pod="kube-system/node-local-dns-sqqc5"
Oct 16 22:53:40 hkk8smaster001 kubelet[51871]: I1016 22:53:40.698535   51871 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"typha-certs\" (UniqueName: \"kubernetes.io/secret/bd55ef31-f4e3-4597-b230-8b50fde6db91-typha-certs\") pod \"calico-typha-669d478b47-8m27b\" (UID: \"bd55ef31-f4e3-4597-b230-8b50fde6db91\") " pod="calico-system/calico-typha-669d478b47-8m27b"
Oct 16 22:53:40 hkk8smaster001 kubelet[51871]: I1016 22:53:40.698612   51871 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"var-run-calico\" (UniqueName: \"kubernetes.io/host-path/4a07b51d-e640-4a77-b24f-f506de414947-var-run-calico\") pod \"calico-node-swhp4\" (UID: \"4a07b51d-e640-4a77-b24f-f506de414947\") " pod="calico-system/calico-node-swhp4"
Oct 16 22:53:40 hkk8smaster001 kubelet[51871]: I1016 22:53:40.698641   51871 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"kube-proxy\" (UniqueName: \"kubernetes.io/configmap/57f5f976-5d94-423c-9d2f-cd0353a04154-kube-proxy\") pod \"kube-proxy-zgb2p\" (UID: \"57f5f976-5d94-423c-9d2f-cd0353a04154\") " pod="kube-system/kube-proxy-zgb2p"
Oct 16 22:53:40 hkk8smaster001 kubelet[51871]: I1016 22:53:40.698669   51871 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"webhook-cert\" (UniqueName: \"kubernetes.io/secret/1e940270-77a1-47e5-bb74-dce379c0875b-webhook-cert\") pod \"ingress-nginx-controller-6479768888-j6hsr\" (UID: \"1e940270-77a1-47e5-bb74-dce379c0875b\") " pod="ingress-nginx/ingress-nginx-controller-6479768888-j6hsr"
Oct 16 22:53:40 hkk8smaster001 kubelet[51871]: I1016 22:53:40.698696   51871 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"config-volume\" (UniqueName: \"kubernetes.io/configmap/6ca278ac-55a2-4b16-bcb8-faeccfffe08f-config-volume\") pod \"coredns-5d78c9869d-qtqxj\" (UID: \"6ca278ac-55a2-4b16-bcb8-faeccfffe08f\") " pod="kube-system/coredns-5d78c9869d-qtqxj"
Oct 16 22:53:40 hkk8smaster001 kubelet[51871]: I1016 22:53:40.698721   51871 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"config-volume\" (UniqueName: \"kubernetes.io/configmap/a6f46359-82cc-4842-b226-01278e54236c-config-volume\") pod \"coredns-5d78c9869d-nlm86\" (UID: \"a6f46359-82cc-4842-b226-01278e54236c\") " pod="kube-system/coredns-5d78c9869d-nlm86"
Oct 16 22:53:40 hkk8smaster001 kubelet[51871]: I1016 22:53:40.698740   51871 reconciler.go:41] "Reconciler: start to sync state"
```

待 `<font style="color:#DF2A3F;">node-local-dns</font>` 安装配置完成后，我们可以部署一个新的 Pod 来验证下：

```yaml
# test-node-local-dns.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-node-local-dns
spec:
  containers:
    - name: local-dns
      image: busybox
      command: ['/bin/sh', '-c', 'sleep 60m']
```

直接部署：

```shell
# 引用资源清单文件
$ kubectl create -f test-node-local-dns.yaml
pod/test-node-local-dns created

$ kubectl exec -it test-node-local-dns -- /bin/sh
/ # cat /etc/resolv.conf 
search default.svc.cluster.local svc.cluster.local cluster.local
nameserver 169.254.20.10
options ndots:5
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760626523531-405a5e40-3c98-4af1-9f07-17f805813eea.png)

我们可以看到 nameserver 已经变成 `<font style="color:#DF2A3F;">169.254.20.10</font>` 了，当然对于之前的历史 Pod 要想使用 node-local-dns 则需要重建。

接下来我们重建前面压力测试 DNS 的 Pod，重新将 testdns 二进制文件拷贝到 Pod 中去：

```shell
# 拷贝到重建的 Pod 中
# $ kubectl get pod -l app=nginx
# NAME                            READY   STATUS    RESTARTS   AGE
# nginx-deploy-57b754799f-9qbz7   1/1     Running   0          30s
# nginx-deploy-57b754799f-swvwn   1/1     Running   0          30s

$ kubectl exec -it nginx-deploy-57b754799f-9qbz7 -- cat /etc/resolv.conf 
search default.svc.cluster.local svc.cluster.local cluster.local
nameserver 169.254.20.10
options ndots:5

$ kubectl cp testdns nginx-deploy-57b754799f-9qbz7:/root
$ kubectl exec -it nginx-deploy-57b754799f-9qbz7 -- /bin/bash
root@nginx-deploy-57b754799f-9qbz7:/# cat /etc/resolv.conf
search default.svc.cluster.local svc.cluster.local cluster.local
nameserver 169.254.20.10 # 可以看到 nameserver 已经更改
options ndots:5
root@nginx-deploy-57b754799f-9qbz7:/# cd /root/ && ls -l 
total 3116
-rwxr-xr-x 1 root root 3187585 Oct 16 15:48 testdns

# 重新执行压力测试
root@nginx-deploy-57b754799f-9qbz7:~# ./testdns -host nginx-service.default -c 200 -d 30 -l 5000
request count：227062
error count：0
request time：min(1ms) max(10015ms) avg(25ms) timeout(295n)
root@nginx-deploy-57b754799f-9qbz7:~# ./testdns -host nginx-service.default -c 200 -d 30 -l 5000
request count：223509
error count：0
request time：min(1ms) max(5064ms) avg(26ms) timeout(328n)
root@nginx-deploy-57b754799f-9qbz7:~# ./testdns -host nginx-service.default -c 200 -d 30 -l 5000
request count：227610
error count：0
request time：min(1ms) max(10021ms) avg(25ms) timeout(287n)
root@nginx-deploy-57b754799f-9qbz7:~# ./testdns -host nginx-service.default -c 200 -d 30 -l 5000
request count：224507
error count：0
request time：min(5ms) max(5057ms) avg(25ms) timeout(240n)
```

### 4.2 小总结
从上面的结果可以看到无论是最大解析时间还是平均解析时间都比之前默认的 CoreDNS 提示了不少的效率，所以我们还是<u>非常推荐在线上环境部署 </u>`<u><font style="color:#DF2A3F;">NodeLocal DNSCache</font></u>`<u> 来提升 DNS 的性能和可靠性的，唯一的缺点就是由于 LocalDNS 使用的是 DaemonSet 模式部署，所以如果需要更新镜像则可能会中断服务</u>（不过可以使用一些第三方的增强组件来实现原地升级解决这个问题，比如 [OpenKruise](https://openkruise.io/)）。

:::success
<font style="color:rgb(0, 0, 0);">Kubernetes LocalDNS 的核心作用是通过稳定的 DNS 名称实现服务发现，并通过缓存、架构优化与协议升级提升解析性能、增强稳定性。其本质是为集群内组件提供“IP无关的服务通信方式”，是 Kubernetes 微服务架构的关键基础设施之一。</font>

⚠️<font style="color:rgb(0, 0, 0);">注：部分集群会部署 NodeLocal DNSCache 作为 CoreDNS 的补充，用于进一步优化性能与稳定性，但其核心功能仍基于 CoreDNS 实现。是 CoreDNS 的功能的补充。</font>

:::

---

NodeLocal DNS通过在集群节点上以DaemonSet的方式运行DNS缓存代理来提高集群DNS性能。

在现在的体系结构中，处于ClusterFirst DNS模式的Pod可连接到CoreDNS的ServiceIP进行DNS查询。通过kube-proxy添加的iptables规则将其转换为CoreDNS端点。

借助这种架构，Pod可以访问在同一节点上运行的DNS缓存代理，从而避免了iptables DNAT规则和连接跟踪。本地缓存代理将查询CoreDNS服务以获取集群主机名的缓存缺失（默认为cluster.local后缀）。

![](https://cdn.nlark.com/yuque/0/2025/jpeg/2555283/1761654739001-a6b9a723-24e8-4c6b-bae9-a7ad51e27a43.jpeg)

**Node-local-dns优点：**

+ 使用当前的DNS体系结构，如果没有本地CoreDNS实例，则具有最高DNS QPS的Pod可能必须延伸到另一个节点。在这种情况下，使用本地缓存将有助于改善延迟。
+ 跳过iptables DNAT和连接跟踪将有助于减少conntrack竞争并避免UDP DNS条目填满conntrack表。
+ 从本地缓存代理到CoreDNS服务的连接可以升级到TCP。TCP conntrack条目将在连接关闭时被删除，相反UDP条目必须超时（默认`<font style="color:#DF2A3F;background-color:rgb(243, 244, 244);">nf_conntrack_udp_timeout</font>`是30秒）。
+ 将DNS查询从UDP升级到TCP将减少归因于丢弃的UDP数据包和DNS超时的尾部等待时间，通常长达30秒（3次重试+10秒超时）。
+ 在节点级别对dns请求的度量和可见性。
+ 可以重新启用负缓存，从而减少对CoreDNS服务的查询数量。

## 5 OpenKruise 介绍部署
[[OpenKruise] 9 OpenKruise(Kubernetes 扩展套件)](https://www.yuque.com/seekerzw/xi8l23/grd74tyxz4ulqcsk)

