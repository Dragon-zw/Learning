Helm 也提供了一种 Hook 机制，可以允许 chart 开发人员在 release 生命周期的某些时间点进行干预。比如，可以使用 hook 来进行下面的操作：

+ 在加载任何 charts 之前，在安装的时候加载 ConfigMap 或者 Secret
+ 在安装新的 chart 之前，执行一个 Job 来备份数据库，然后在升级后执行第二个 Job 还原数据
+ 在删除 release 之前运行一个 JOb，以在删除 release 之前适当地取消相关服务

Hooks 的工作方式类似于普通的模板，但是他们具有特殊的注解，这些注解使 Helm 可以用不同的方式来使用他们。

## 1 Hooks
在 Helm 中定义了如下一些可供我们使用的 Hooks：

+ 预安装`<font style="color:#DF2A3F;">pre-install</font>`：在模板渲染后，kubernetes 创建任何资源之前执行
+ 安装后`<font style="color:#DF2A3F;">post-install</font>`：在所有 kubernetes 资源安装到集群后执行
+ 预删除`<font style="color:#DF2A3F;">pre-delete</font>`：在从 kubernetes 删除任何资源之前执行删除请求
+ 删除后`<font style="color:#DF2A3F;">post-delete</font>`：删除所有 release 的资源后执行
+ 升级前`<font style="color:#DF2A3F;">pre-upgrade</font>`：在模板渲染后，但在任何资源升级之前执行
+ 升级后`<font style="color:#DF2A3F;">post-upgrade</font>`：在所有资源升级后执行
+ 预回滚`<font style="color:#DF2A3F;">pre-rollback</font>`：在模板渲染后，在任何资源回滚之前执行
+ 回滚后`<font style="color:#DF2A3F;">post-rollback</font>`：在修改所有资源后执行回滚请求
+ 测试`<font style="color:#DF2A3F;">test</font>`：在调用 Helm `<font style="color:#DF2A3F;">test</font>` 子命令的时候执行（可以查看[测试文档](https://helm.sh/docs/chart_tests/)）

<details class="lake-collapse"><summary id="u5e472e87"><span class="ne-text" style="color: rgb(27, 83, 194)">注意</span></summary><ul class="ne-ul"><li id="ua13c0a2f" data-lake-index-type="0"><span class="ne-text" style="color: rgb(51, 51, 51)">你可以在单个yaml文件中定义尽可能多的测试或者分布在</span><code class="ne-code"><span class="ne-text" style="color: #DF2A3F; background-color: rgb(250, 250, 250)">templates/</span></code><span class="ne-text" style="color: rgb(51, 51, 51)">目录中的多个yaml文件中。</span></li><li id="u7627ad41" data-lake-index-type="0"><span class="ne-text" style="color: rgb(51, 51, 51)">为了更好地隔离，欢迎你将测试套件嵌套放在</span><code class="ne-code"><span class="ne-text" style="color: #DF2A3F; background-color: rgb(250, 250, 250)">tests/</span></code><span class="ne-text" style="color: rgb(51, 51, 51)">目录中，类似</span><code class="ne-code"><span class="ne-text" style="color: #DF2A3F; background-color: rgb(250, 250, 250)">&lt;chart-name&gt;/templates/tests</span><span class="ne-text" style="color: black; background-color: rgb(250, 250, 250)">/</span></code><span class="ne-text" style="color: rgb(51, 51, 51)">。</span></li><li id="uc0130f81" data-lake-index-type="0"><span class="ne-text" style="color: rgb(51, 51, 51)">一个test就是一个 </span><a href="https://helm.sh/zh/docs/topics/charts_hooks" data-href="https://helm.sh/zh/docs/topics/charts_hooks" target="_blank" class="ne-link"><span class="ne-text" style="color: rgb(51, 51, 51)">Helm 钩子</span></a><span class="ne-text" style="color: rgb(51, 51, 51)">，所以类似于 </span><code class="ne-code"><span class="ne-text" style="color: #DF2A3F; background-color: rgb(250, 250, 250)">helm.sh/hook-weight</span></code><span class="ne-text" style="color: rgb(51, 51, 51)">和</span><code class="ne-code"><span class="ne-text" style="color: #DF2A3F; background-color: rgb(250, 250, 250)">helm.sh/hook-delete-policy</span></code><span class="ne-text" style="color: rgb(51, 51, 51)">的注释可以用于测试资源。</span></li></ul><p id="u5f8b684f" class="ne-p"><img src="https://cdn.nlark.com/yuque/0/2024/png/2555283/1732704359123-abc0fff5-a1a0-4f31-8b02-ddfe5e946cbe.png" width="916" id="mMRoF" class="ne-image"></p></details>
## 2 生命周期
Hooks 允许开发人员在 release 的生命周期中的一些关键节点执行一些钩子函数，我们正常安装一个 chart 包的时候的生命周期如下所示：

1. 用户运行 `<font style="color:#DF2A3F;">helm install foo</font>`
2. Helm 库文件调用安装 API
3. 经过一些验证，Helm 库渲染 `<font style="color:#DF2A3F;">foo</font>` 模板
4. Helm 库将产生的资源加载到 kubernetes 中去
5. Helm 库将 release 对象和其他数据返回给客户端
6. Helm 客户端退出

如果开发人员在 `<font style="color:#DF2A3F;">install</font>` 的生命周期中定义了两个 hook：`<font style="color:#DF2A3F;">pre-install</font>`和`<font style="color:#DF2A3F;">post-install</font>`，那么我们安装一个 chart 包的生命周期就会多一些步骤了：

1. 用户运行`<font style="color:#DF2A3F;">helm install foo</font>`
2. Helm 库文件调用安装 API
3. 在 `<font style="color:#DF2A3F;">crds/</font>`<font style="color:#DF2A3F;"> </font>目录下面的 CRDs 被安装
4. 经过一些验证，Helm 库渲染 `<font style="color:#DF2A3F;">foo</font>` 模板
5. Helm 库将 hook 资源加载到 kubernetes 中，准备执行`<font style="color:#DF2A3F;">pre-install</font>` hooks
6. Helm 库会根据权重对 hooks 进行排序（默认分配权重0，权重相同的 hook 按升序排序）
7. Helm 库然后加载最低权重的 hook
8. Helm 库会等待，直到 hook 准备就绪
9. Helm 库将产生的资源加载到 kubernetes 中，注意如果添加了 `<font style="color:#DF2A3F;">--wait</font>` 参数，Helm 库会等待所有资源都准备好，在这之前不会运行 `<font style="color:#DF2A3F;">post-install</font>` hook
10. Helm 库执行 `<font style="color:#DF2A3F;">post-install</font>` hook（加载 hook 资源）
11. Helm 库等待，直到 hook 准备就绪
12. Helm 库将 release 对象和其他数据返回给客户端
13. Helm 客户端退出

等待 hook 准备就绪，这是一个阻塞的操作，如果 hook 中声明的是一个 Job 资源，Helm 将等待 Job 成功完成，如果失败，则发布失败，在这个期间，Helm 客户端是处于暂停状态的。

对于所有其他类型，只要 kubernetes 将资源标记为加载（添加或更新），资源就被视为就绪状态，当一个 hook 声明了很多资源是，这些资源是被串行执行的。

另外需要注意的是 hook 创建的资源不会作为 release 的一部分进行跟踪和管理，一旦 Helm 验证了 hook 已经达到了就绪状态，它就不会去管它了。

所以，如果我们在 hook 中创建了资源，那么不能依赖 `<font style="color:#DF2A3F;">helm uninstall</font>` 去删除资源，因为 hook 创建的资源已经不受控制了，要销毁这些资源，你需要将 `<font style="color:#DF2A3F;">helm.sh/hook-delete-policy</font>` 这个 annotation 添加到 hook 模板文件中，或者设置 [Job 资源的生存（TTL）字段](https://kubernetes.io/docs/concepts/workloads/controllers/ttlafterfinished/)。

## 3 编写 Hook
**<u>Hooks 就是 Kubernetes 资源清单文件，在元数据部分带有一些特殊的注解，因为他们是模板文件，所以你可以使用普通模板所有的功能，包括读取 </u>**`**<u><font style="color:#DF2A3F;">.Values</font></u>**`**<u><font style="color:#DF2A3F;">、</font></u>**`**<u><font style="color:#DF2A3F;">.Release</font></u>**`**<u><font style="color:#DF2A3F;"> 和 </font></u>**`**<u><font style="color:#DF2A3F;">.Template</font></u>**`**<u>。</u>**

例如，在 `<font style="color:#DF2A3F;">templates/post-install-job.yaml</font>` 文件中声明一个 post-install 的 hook：

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: "{{ .Release.Name }}"
  labels:
    app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
    app.kubernetes.io/instance: {{ .Release.Name | quote }}
    app.kubernetes.io/version: {{ .Chart.AppVersion }}
    helm.sh/chart: "{{ .Chart.Name }}-{{ .Chart.Version }}"
  annotations:
    # 因为添加了这个 hook，所以我们这个资源被定义为了 hook
    # 如果没有这行，则当前这个 Job 会被当成 release 的一部分内容。
    "helm.sh/hook": post-install
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    metadata:
      name: "{{ .Release.Name }}"
      labels:
        app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
        app.kubernetes.io/instance: {{ .Release.Name | quote }}
        helm.sh/chart: "{{ .Chart.Name }}-{{ .Chart.Version }}"
    spec:
      restartPolicy: Never
      containers:
      - name: post-install-job
        image: "alpine:3.3"
        command: ["/bin/sleep","{{ default "10" .Values.sleepyTime }}"]
```

当前这个模板成为 hook 的原因就是添加这个注解：

```yaml
annotations:
  "helm.sh/hook": post-install
```

一种资源也可以实现多个 hooks：

```yaml
annotations:
  "helm.sh/hook": post-install,post-upgrade
```

类似的，实现给定 hook 的资源数量也没有限制，比如可以将 secret 和一个 configmap 都声明为 `<font style="color:#DF2A3F;">pre-install</font>` hook。

当子 chart 声明 hooks 的时候，也会对其进行调用，顶层的 chart 无法禁用子 chart 所声明的 hooks。可以为 hooks 定义权重，这将有助于确定 hooks 的执行顺序：

```yaml
annotations:
  "helm.sh/hook-weight": "5"
```

hook 权重可以是正数也可以是负数，但是必须用字符串表示，当 Helm 开始执行特定种类的 hooks 的时候，它将以升序的方式对这些 hooks 进行排序。

## 4 Hook 删除策略
我们还可以定义确定何时删除相应 hook 资源的策略，hook 删除策略可以使用下面的注解进行定义：

```yaml
annotations:
  "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
```

我们也可以选择一个或多个已定义的注解：

+ `<font style="color:#DF2A3F;">before-hook-creation</font>`：运行一个新的 hook 之前删除前面的资源（默认）
+ `<font style="color:#DF2A3F;">hook-succeeded</font>`：hook 成功执行后删除资源
+ `<font style="color:#DF2A3F;">hook-failed</font>`：hook 如果执行失败则删除资源

如果未指定任何 hook 删除策略注解，则默认情况下会使用 `<font style="color:#DF2A3F;">before-hook-creation</font>` 策略。

