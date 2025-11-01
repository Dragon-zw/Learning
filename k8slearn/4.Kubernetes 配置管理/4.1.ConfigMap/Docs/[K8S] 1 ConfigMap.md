<font style="color:rgb(28, 30, 33);">前面我们学习了一些常用的资源对象的使用，但是单纯依靠这些资源对象，还不足以满足我们的日常需求，一个重要的需求就是应用的配置管理、敏感信息的存储和使用（如：密码、Token 等）、容器运行资源的配置、安全管控、身份认证等等。</font>

<font style="color:rgb(28, 30, 33);">对于应用的可变配置在 Kubernetes 中是通过一个 </font>`<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">资源对象来实现的，我们知道许多应用经常会有从配置文件、命令行参数或者环境变量中读取一些配置信息的需求，这些配置信息我们肯定不会直接写死到应用程序中去的，比如你一个应用连接一个 redis 服务，下一次想更换一个了的，还得重新去修改代码，重新制作一个镜像，这肯定是不可取的，而 </font>`<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">就给我们提供了向容器中注入配置信息的能力，不仅可以用来保存单个属性，还可以用来保存整个配置文件，比如我们可以用来配置一个 redis 服务的访问地址，也可以用来保存整个 redis 的配置文件。接下来我们就来了解下 </font>`<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">这种资源对象的使用方法。</font>

## <font style="color:rgb(28, 30, 33);">1 创建 ConfigMap</font>
`<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">资源对象使用 </font>`<font style="color:#DF2A3F;">key-value</font>`<font style="color:rgb(28, 30, 33);"> 形式的键值对来配置数据，这些数据可以在 Pod 里面使用，如下所示的资源清单：</font>

```yaml
# cm-demo.yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: cm-demo
  namespace: default
data:
  data.1: hello
  data.2: world
  config: |
    property.1=value-1
    property.2=value-2
    property.3=value-3
```

<font style="color:rgb(28, 30, 33);">其中配置数据在 </font>`<font style="color:#DF2A3F;">data</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">属性下面进行配置，前两个被用来保存单个属性，后面一个被用来保存一个配置文件。</font>

<font style="color:rgb(28, 30, 33);">我们可以看到 </font>`<font style="color:#DF2A3F;">config</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">后面有一个竖线符</font><font style="color:#DF2A3F;"> </font>`<u><font style="color:#DF2A3F;">|</font></u>`<u><font style="color:rgb(28, 30, 33);">，这在 yaml 中表示保留换行，每行的缩进和行尾空白都会被去掉，而额外的缩进会被保留。</font></u>

```yaml
lines: |
  我是第一行
  我是第二行
    我是吴彦祖
      我是第四行
  我是第五行

# JSON
{"lines": "我是第一行\n我是第二行\n  我是吴彦祖\n     我是第四行\n我是第五行"}
```

<font style="color:rgb(28, 30, 33);">除了竖线之外还可以使用 </font>`<u><font style="color:#DF2A3F;">></font></u>`<u><font style="color:rgb(28, 30, 33);"> 右尖括号，用来表示折叠换行，只有空白行才会被识别为换行，原来的换行符都会被转换成空格。</font></u>

```yaml
lines: >
  我是第一行
  我也是第一行
  我仍是第一行
  我依旧是第一行

  我是第二行
  这么巧我也是第二行

# JSON
{"lines": "我是第一行 我也是第一行 我仍是第一行 我依旧是第一行\n我是第二行 这么巧我也是第二行"}
```

<font style="color:rgb(28, 30, 33);">除了这两个指令之外，我们还可以使用竖线和加号或者减号进行配合使用，</font>`<u><font style="color:#DF2A3F;">+</font></u>`<u><font style="color:rgb(28, 30, 33);"> 表示保留文字块末尾的换行，</font></u>`<u><font style="color:#DF2A3F;">-</font></u>`<u><font style="color:rgb(28, 30, 33);"> 表示删除字符串末尾的换行。</font></u>

```yaml
value: |
  hello

# {"value": "hello\n"}

value: |-
  hello

# {"value": "hello"}

value: |+
  hello

# {"value": "hello\n\n"} (有多少个回车就有多少个\n)
```

<font style="color:rgb(28, 30, 33);">当然同样的我们可以使用</font>`<font style="color:#DF2A3F;">kubectl create -f xxx.yaml</font>`<font style="color:rgb(28, 30, 33);">来创建上面的 </font>`<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">对象，但是如果我们不知道怎么创建 </font>`<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">的话，不要忘记 kubectl 是我们最好的帮手，可以使用</font>`<font style="color:#DF2A3F;">kubectl create configmap -h</font>`<font style="color:rgb(28, 30, 33);">来查看关于创建 </font>`<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">的帮助信息：</font>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760459422483-91b42aa3-a7bf-435b-a242-f26a54677097.png)

```shell
Examples:
  # Create a new config map named my-config based on folder bar
  kubectl create configmap my-config --from-file=path/to/bar
  
  # Create a new config map named my-config with specified keys instead of file basenames on disk
  kubectl create configmap my-config --from-file=key1=/path/to/bar/file1.txt
--from-file=key2=/path/to/bar/file2.txt
  
  # Create a new config map named my-config with key1=config1 and key2=config2
  kubectl create configmap my-config --from-literal=key1=config1 --from-literal=key2=config2
  
  # Create a new config map named my-config from the key=value pairs in the file
  kubectl create configmap my-config --from-file=path/to/bar
  
  # Create a new config map named my-config from an env file
  kubectl create configmap my-config --from-env-file=path/to/foo.env --from-env-file=path/to/bar.env
```

<font style="color:rgb(28, 30, 33);">我们可以看到可以从一个给定的目录来创建一个 </font>`<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">对象，比如我们有一个 testcm 的目录，该目录下面包含一些配置文件，</font>`<font style="color:rgb(28, 30, 33);">redis</font>`<font style="color:rgb(28, 30, 33);"> 和 </font>`<font style="color:rgb(28, 30, 33);">mysql</font>`<font style="color:rgb(28, 30, 33);"> 的连接信息，如下：</font>

```shell
➜  ~ mkdir -p testcm
➜  ~ cat <<EOF > testcm/redis.conf
host=127.0.0.1
port=6379
EOF

➜  ~ cat <<EOF > testcm/mysql.conf
host=127.0.0.1
port=3306
EOF

➜  ~ ls -l testcm
total 8
-rw-r--r-- 1 root root 25 Oct 15 00:31 mysql.conf
-rw-r--r-- 1 root root 25 Oct 15 00:31 redis.conf
```

<font style="color:rgb(28, 30, 33);">然后我们就可以使用 </font>`<font style="color:#DF2A3F;">from-file</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">关键字来创建包含这个目录下面所以配置文件的 </font>`<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:rgb(28, 30, 33);">：</font>

```shell
➜  ~ kubectl create configmap cm-demo1 --from-file=testcm
configmap "cm-demo1" created
```

<font style="color:rgb(28, 30, 33);">其中 </font>`<font style="color:#DF2A3F;">from-file</font>`<font style="color:rgb(28, 30, 33);"> 参数指定在该目录下面的所有文件都会被用在 </font>`<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">里面创建一个键值对，键的名字就是文件名，值就是文件的内容。创建完成后，同样我们可以使用如下命令来查看 </font>`<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">列表：</font>

```shell
➜  ~ kubectl get configmap cm-demo1
NAME       DATA   AGE
cm-demo1   2      25s
```

<font style="color:rgb(28, 30, 33);">可以看到已经创建了一个 </font>`<font style="color:rgb(28, 30, 33);">cm-demo1</font>`<font style="color:rgb(28, 30, 33);"> 的 </font>`<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">对象，然后可以使用 </font>`<font style="color:#DF2A3F;">describe</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">命令查看详细信息：</font>

```shell
➜  ~ kubectl describe configmap cm-demo1
Name:         cm-demo1
Namespace:    default
Labels:       <none>
Annotations:  <none>

Data
====
mysql.conf:
----
host=127.0.0.1
port=3306

redis.conf:
----
host=127.0.0.1
port=6379


BinaryData
====

Events:  <none>
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760459580225-38c9878d-e1c8-498f-8412-22eec8fed3c7.png)

<font style="color:rgb(28, 30, 33);">我们可以看到两个 </font>`<font style="color:#DF2A3F;">key</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">是 testcm 目录下面的文件名称，对应的 </font>`<font style="color:#DF2A3F;">value</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">值就是文件内容，这里值得注意的是如果文件里面的配置信息很大的话，</font>`<font style="color:#DF2A3F;">describe</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">的时候可能不会显示对应的值，要查看完整的键值，可以使用如下命令：</font>

```shell
➜  ~ kubectl get configmap cm-demo1 -o yaml
apiVersion: v1
data:
  mysql.conf: |
    host=127.0.0.1
    port=3306
  redis.conf: |
    host=127.0.0.1
    port=6379
kind: ConfigMap
metadata:
  creationTimestamp: "2025-10-14T16:32:12Z"
  name: cm-demo1
  namespace: default
  resourceVersion: "267204"
  uid: 3a097e86-5089-483f-aec8-010737454279
```

<font style="color:rgb(28, 30, 33);">除了通过文件目录进行创建，我们也可以使用指定的文件进行创建 </font>`<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:rgb(28, 30, 33);">，同样的，以上面的配置文件为例，我们创建一个 redis 的配置的一个单独 </font>`<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">对象：</font>

```shell
➜  ~ kubectl create configmap cm-demo2 --from-file=testcm/redis.conf
configmap "cm-demo2" created

# 查看 ConfigMap 的 Yaml 输出 
➜  ~ kubectl get configmap cm-demo2 -o yaml
apiVersion: v1
data:
  redis.conf: |
    host=127.0.0.1
    port=6379
kind: ConfigMap
metadata:
  creationTimestamp: "2025-10-14T16:33:13Z"
  name: cm-demo2
  namespace: default
  resourceVersion: "267361"
  uid: 2083ad2a-fdf4-41e4-826a-e49ea8477a63
```

<font style="color:rgb(28, 30, 33);">我们可以看到一个关联 </font>`<font style="color:#DF2A3F;">redis.conf</font>`<font style="color:rgb(28, 30, 33);"> 文件配置信息的 </font>`<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">对象创建成功了，另外值得注意的是 </font>`<font style="color:#DF2A3F;">--from-file</font>`<font style="color:rgb(28, 30, 33);"> 这个参数可以使用多次，比如我们这里使用两次分别指定 </font>`<font style="color:#DF2A3F;">redis.conf</font>`<font style="color:rgb(28, 30, 33);"> 和 </font>`<font style="color:#DF2A3F;">mysql.conf</font>`<font style="color:rgb(28, 30, 33);"> 文件，就和直接指定整个目录是一样的效果了。</font>

<font style="color:rgb(28, 30, 33);">另外，通过帮助文档我们可以看到我们还可以直接使用字符串进行创建，通过 </font>`<font style="color:#DF2A3F;">--from-literal</font>`<font style="color:rgb(28, 30, 33);"> 参数传递配置信息，同样的，这个参数可以使用多次，格式如下：</font>

```shell
➜  ~ kubectl create configmap cm-demo3 \
  --from-literal=db.host=localhost \
  --from-literal=db.port=3306
configmap "cm-demo3" created

# 查看 ConfigMap 的 Yaml 输出 
➜  ~ kubectl get configmap cm-demo3 -o yaml
apiVersion: v1
data:
  db.host: localhost
  db.port: "3306"
kind: ConfigMap
metadata:
  creationTimestamp: "2025-10-14T16:34:03Z"
  name: cm-demo3
  namespace: default
  resourceVersion: "267493"
  uid: e70bf167-d9e4-474c-bb60-a09b6ce1f92b
```

## <font style="color:rgb(28, 30, 33);">2 使用 ConfigMap</font>
`<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">创建成功了，那么我们应该怎么在 Pod 中来使用呢？我们说 </font>`<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">这些配置数据可以通过很多种方式在 Pod 里使用，主要有以下几种方式：</font>

+ <font style="color:rgb(28, 30, 33);">设置环境变量的值</font>
+ <font style="color:rgb(28, 30, 33);">在容器里设置命令行参数</font>
+ <font style="color:rgb(28, 30, 33);">在数据卷里面挂载配置文件</font>

### <font style="color:rgb(28, 30, 33);">2.1 设置环境变量的值</font>
<font style="color:rgb(28, 30, 33);">首先，我们使用 </font>`<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">来填充我们的环境变量，如下所示的 Pod 资源对象：</font>

```yaml
# testcm1-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: testcm1-pod
spec:
  containers:
    - name: testcm1
      image: busybox
      command: [ "/bin/sh", "-c", "env" ]
      env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: cm-demo3
              key: db.host
        - name: DB_PORT
          valueFrom:
            configMapKeyRef:
              name: cm-demo3
              key: db.port
      envFrom:
        - configMapRef:
            name: cm-demo1
```

<font style="color:rgb(28, 30, 33);">这个 Pod 运行后会输出如下所示的信息：</font>

```shell
➜  ~ kubectl logs testcm1-pod
......
DB_HOST=localhost # cm-demo3 ConfigMap 的内容
DB_PORT=3306 # cm-demo3 ConfigMap 的内容
mysql.conf=host=127.0.0.1 # cm-demo1 ConfigMap 的内容
port=3306 # cm-demo1 ConfigMap 的内容
redis.conf=host=127.0.0.1 # cm-demo1 ConfigMap 的内容
port=6379 # cm-demo1 ConfigMap 的内容
......
```

<font style="color:rgb(28, 30, 33);">我们可以看到 </font>`<font style="color:#DF2A3F;">DB_HOST</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">和 </font>`<font style="color:#DF2A3F;">DB_PORT</font>`<font style="color:rgb(28, 30, 33);"> 都已经正常输出了，</font><font style="color:#DF2A3F;">另外的环境变量是因为我们这里直接把 </font>`<font style="color:#DF2A3F;">cm-demo1</font>`<font style="color:#DF2A3F;"> 给注入进来了，所以把他们的整个键值给输出出来了</font><font style="color:rgb(28, 30, 33);">，这也是符合预期的。</font>

### <font style="color:rgb(28, 30, 33);">2.2 在容器里设置命令行参数</font>
<font style="color:rgb(28, 30, 33);">另外我们也可以使用 </font>`<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:rgb(28, 30, 33);">来设置命令行参数，</font>`<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">也可以被用来设置容器中的命令或者参数值，如下 Pod:</font>

```yaml
# testcm2-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: testcm2-pod
spec:
  containers:
    - name: testcm2
      image: busybox
      command: [ "/bin/sh", "-c", "echo $(DB_HOST) $(DB_PORT)" ]
      env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: cm-demo3
              key: db.host
        - name: DB_PORT
          valueFrom:
            configMapKeyRef:
              name: cm-demo3
              key: db.port
```

<font style="color:rgb(28, 30, 33);">运行这个 Pod 后会输出如下信息：</font>

```shell
➜  ~ kubectl apply -f testcm2-pod.yaml 
pod/testcm2-pod created

➜  ~ kubectl logs testcm2-pod
localhost 3306
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760460130651-35d6b12d-49ec-494d-8e61-6ba81dfe1ba2.png)

### <font style="color:rgb(28, 30, 33);">2.3 在数据卷里面挂载配置文件</font>
#### 2.3.1 将 ConfigMap 通过数据卷的方式挂载
<font style="color:rgb(28, 30, 33);">另外一种是非常常见的使用 </font>`<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">的方式：通过</font>**<font style="color:#DF2A3F;">数据卷</font>**<font style="color:rgb(28, 30, 33);">使用，在数据卷里面使用 ConfigMap，就是将文件填入数据卷，在这个文件中，键就是文件名，键值就是文件内容，如下资源对象所示：</font>

```yaml
# testcm3-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: testcm3-pod
spec:
  volumes:
    - name: config-volume
      configMap:
        name: cm-demo2
  containers:
    - name: testcm3
      image: busybox
      command: [ "/bin/sh", "-c", "cat /etc/config/redis.conf" ]
      volumeMounts:
      - name: config-volume
        mountPath: /etc/config
```

<font style="color:rgb(28, 30, 33);">运行这个 Pod 的，查看日志：</font>

```shell
➜  ~ kubectl apply -f testcm3-pod.yaml 
pod/testcm3-pod created

➜  ~ kubectl logs testcm3-pod
host=127.0.0.1
port=6379
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760460118028-0e9e4898-4421-47f8-b345-97387d5c923f.png)

<details class="lake-collapse"><summary id="u2fbbb8c0"><strong><span class="ne-text">testcm3-pod.yaml：挂载整个 ConfigMap</span></strong></summary><p id="ub55569c4" class="ne-p"><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">testcm3-pod.yaml</span></code><span class="ne-text"> 的配置方式是将名为 </span><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">cm-demo2</span></code><span class="ne-text"> 的 </span><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">ConfigMap</span></code><span class="ne-text"> 中的所有键值对作为文件挂载到 </span><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">/etc/config</span></code><span class="ne-text"> 目录中。</span><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">ConfigMap</span></code><span class="ne-text"> 中的每个键将成为目录中的文件名，对应的值将是文件内容。 </span></p><p id="uc732e21d" class="ne-p"><strong><span class="ne-text">优点：</span></strong></p><ul class="ne-ul"><li id="u7aa0d90f" data-lake-index-type="0"><strong><span class="ne-text">简单方便：</span></strong><span class="ne-text"> 这种方法配置简单，只需指定 </span><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">ConfigMap</span></code><span class="ne-text"> 名称，适用于需要挂载所有配置文件的场景。</span></li><li id="ub1f6ea2b" data-lake-index-type="0"><strong><span class="ne-text">自动同步：</span></strong><span class="ne-text"> 如果 </span><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">ConfigMap</span></code><span class="ne-text"> 内容发生更新，文件内容会自动同步到 Pod 中（需要应用自身支持热加载），无需重启 Pod。 </span></li></ul><p id="ued8b97d2" class="ne-p"><strong><span class="ne-text">缺点：</span></strong></p><ul class="ne-ul"><li id="u8237b2ec" data-lake-index-type="0"><strong><span class="ne-text">不必要的挂载：</span></strong><span class="ne-text"> 如果 </span><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">ConfigMap</span></code><span class="ne-text"> 包含许多配置项，但容器只需要其中一部分，这会导致不必要的挂载，增加了文件系统的负担。</span></li><li id="u1ec24006" data-lake-index-type="0"><strong><span class="ne-text">命名冲突：</span></strong><span class="ne-text"> 如果 </span><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">ConfigMap</span></code><span class="ne-text"> 中的键名与挂载目录中已有的文件发生冲突，可能会引发问题。</span></li><li id="ua3726fec" data-lake-index-type="0"><strong><span class="ne-text">不灵活：</span></strong><span class="ne-text"> 无法为单个文件指定不同的子路径或文件模式，所有文件都使用 </span><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">ConfigMap</span></code><span class="ne-text"> 中的键名。 </span></li></ul></details>
#### <font style="color:rgb(28, 30, 33);">2.3.2 将 ConfigMap 通过数据卷的方式挂载（控制指定的路径）</font>
<font style="color:rgb(28, 30, 33);">当然我们也可以在 </font>`<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">值被映射的数据卷里去控制路径，如下 Pod 定义：</font>

```yaml
# testcm4-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: testcm4-pod
spec:
  volumes:
    - name: config-volume
      configMap:
        name: cm-demo1
        items:
        - key: mysql.conf
          path: path/to/msyql.conf # 拼接 VolumeMounts 中的 mountPath 的路径
  containers:
    - name: testcm4
      image: busybox
      command: [ "/bin/sh","-c","cat /etc/config/path/to/msyql.conf" ]
      volumeMounts:
      - name: config-volume
        mountPath: /etc/config
```

<font style="color:rgb(28, 30, 33);">运行这个Pod的，查看日志：</font>

```shell
➜  ~ kubectl apply -f testcm4-pod.yaml 
pod/testcm4-pod created

➜  ~ kubectl logs testcm4-pod
host=127.0.0.1
port=3306
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760460105001-5ac6eb73-0148-44de-99fb-9143a3a36500.png)

:::success
<font style="color:rgb(28, 30, 33);">另外需要注意的是，当 </font>`<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">以数据卷的形式挂载进 </font>`<font style="color:#DF2A3F;">Pod</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">的时，这时更新 </font>`<font style="color:#DF2A3F;">ConfigMap（或删掉重建ConfigMap）</font>`<font style="color:rgb(28, 30, 33);">，Pod 内挂载的配置信息会热更新。这时可以增加一些监测配置文件变更的脚本，然后重加载对应服务就可以实现应用的热更新。</font>

+ <font style="color:rgb(28, 30, 33);">当 Pod 应用不支持热更新的机制的话，就只能重建 Pod 的方式。</font>
+ <font style="color:rgb(28, 30, 33);">当 Pod 应用是对接配置中心，当配置中心发生变化就会下发配置到应用就实现动态热更新</font>

:::

:::success
使用注意

只有通过 Kubernetes API 创建的 Pod 才能使用 `<font style="color:#DF2A3F;">ConfigMap</font>`，其他方式创建的（比如静态 Pod）不能使用；ConfigMap 文件大小限制为 `<font style="color:#DF2A3F;">1MB</font>`（ETCD 的要求）。

:::

<details class="lake-collapse"><summary id="u411c925f"><strong><span class="ne-text">testcm4-pod.yaml：选择性挂载 ConfigMap 中的数据项</span></strong></summary><p id="ua1de646f" class="ne-p"><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">testcm4-pod.yaml</span></code><span class="ne-text"> 使用 </span><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">items</span></code><span class="ne-text"> 字段，显式指定要从 </span><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">cm-demo1</span></code><span class="ne-text"> 这个 </span><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">ConfigMap</span></code><span class="ne-text"> 中挂载哪个键。这里它只挂载了 </span><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">mysql.conf</span></code><span class="ne-text"> 这个键，并将其映射为 </span><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">/etc/config/path/to/msyql.conf</span></code><span class="ne-text">。 </span></p><div data-type="color1" class="ne-alert"><p id="u2415feac" class="ne-p"><strong><span class="ne-text">优点：</span></strong></p></div><ul class="ne-ul"><li id="u9082cb52" data-lake-index-type="0"><strong><span class="ne-text">精确控制：</span></strong><span class="ne-text"> </span><span class="ne-text">你可以精确地控制哪些配置项被挂载到 Pod 中，避免不必要的配置项被暴露。</span></li><li id="ue6ed9334" data-lake-index-type="0"><strong><span class="ne-text">路径可定制：</span></strong><span class="ne-text"> 可以通过 </span><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">path</span></code><span class="ne-text"> 字段为每个挂载的文件指定不同的文件路径和名称，而无需受 </span><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">ConfigMap</span></code><span class="ne-text"> 中键名的限制。</span></li><li id="udd96c5f4" data-lake-index-type="0"><strong><span class="ne-text">避免冲突：</span></strong><span class="ne-text"> 精确控制挂载文件可以避免与容器中已有的文件发生命名冲突。 </span></li></ul><div data-type="color2" class="ne-alert"><p id="u59c7127f" class="ne-p"><strong><span class="ne-text">缺点：</span></strong></p></div><ul class="ne-ul"><li id="ua43c7efd" data-lake-index-type="0"><strong><span class="ne-text">更新不同步：</span></strong><span class="ne-text"> </span><strong><span class="ne-text">此方法有一个重要限制：通过 </span></strong><code class="ne-code"><strong><span class="ne-text" style="color: #DF2A3F">items</span></strong></code><strong><span class="ne-text"> 字段选择性挂载的文件，如果其来源 </span></strong><code class="ne-code"><strong><span class="ne-text" style="color: #DF2A3F">ConfigMap</span></strong></code><strong><span class="ne-text"> 内容更新，Pod 中的文件不会自动同步。</span></strong><span class="ne-text"> 这意味着你需要重新部署 Pod 才能获取更新的配置。</span></li><li id="ud8f9eb5f" data-lake-index-type="0"><strong><span class="ne-text">配置冗余：</span></strong><span class="ne-text"> 对于需要挂载大量文件的场景，</span><code class="ne-code"><span class="ne-text" style="color: #DF2A3F">items</span></code><span class="ne-text"> 字段的配置会变得冗余和繁琐。 </span></li></ul></details>
#### 2.3.3 小总结
| **特性**** ** | **testcm3 (挂载整个 ConfigMap)** | **testcm4 (选择性挂载)** |
| --- | --- | --- |
| **挂载范围** | **挂载 **`**<font style="color:#DF2A3F;">ConfigMap</font>**`**<font style="color:#DF2A3F;"> </font>****中的所有键值对。** | **仅挂载 **`**<font style="color:#DF2A3F;">items</font>**`**<font style="color:#DF2A3F;"> </font>****字段中指定的键。** |
| **文件命名** | **文件名等同于 **`**<font style="color:#DF2A3F;">ConfigMap</font>**`**<font style="color:#DF2A3F;"> </font>****中的键名。** | **文件名可由 **`**<font style="color:#DF2A3F;">path</font>**`**<font style="color:#DF2A3F;"> </font>****字段自定义。** |
| **热更新** | **支持 **`**<font style="color:#DF2A3F;">ConfigMap</font>**`**<font style="color:#DF2A3F;"> </font>****更新后自动同步到文件。** | **不支持****自动更新，需要重启 Pod。** |
| **灵活性** | **较低，所有文件都在同一目录下，命名固定。** | **较高，可自定义文件路径和名称。** |
| **推荐场景** | **需要所有配置项，且支持热加载的通用配置。** | **只需挂载少数特定文件，或需自定义文件路径和名称。** |


如何选择：

1. 如果需要动态更新配置且应用支持热加载，应使用 testcm3 的方式（挂载整个 ConfigMap），因为它支持自动同步更新。
2. 如果只需要挂载 ConfigMap 中的一两个特定文件，并且不关心动态更新，或需要指定自定义的文件路径，那么使用 testcm4 的方式（选择性挂载） 更合适。
3. 如果需要在现有目录下挂载一个文件而不覆盖整个目录，则必须使用 subPath 字段，这通常与选择性挂载结合使用。 

