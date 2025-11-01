<u><font style="color:#DF2A3F;">Helm 使用一种名为 Charts 的包格式，一个 chart 是描述一组相关的 Kubernetes 资源的文件集合，单个 chart 可能用于部署简单的应用</font></u>，比如 memcached pod，或者复杂的应用，比如一个带有 HTTP 服务、数据库、缓存等等功能的完整 web 应用程序。

<u><font style="color:#DF2A3F;">Charts 是创建在特定目录下面的文件集合，然后可以将它们打包到一个版本化的存档中来部署。</font></u>接下来我们就来看看使用 Helm 构建 charts 的一些基本方法。

## 1 文件结构
chart 被组织为一个目录中的文件集合，目录名称就是 chart 的名称（不包含版本信息），下面是一个 WordPress 的 chart，会被存储在 `<font style="color:#DF2A3F;">wordpress/</font>` 目录下面，基本结构如下所示：

```shell
wordpress/
  Chart.yaml          # 包含当前 chart 信息的 YAML 文件
  LICENSE             # 可选：包含 chart 的 license 的文本文件
  README.md           # 可选：一个可读性高的 README 文件
  values.yaml         # 当前 chart 的默认配置 values
  values.schema.json  # 可选: 一个作用在 values.yaml 文件上的 JSON 模式
  charts/             # 包含该 chart 依赖的所有 chart 的目录
  crds/               # Custom Resource Definitions
  templates/          # 模板目录，与 values 结合使用时，将渲染生成 Kubernetes 资源清单文件
  templates/NOTES.txt # 可选: 包含简短使用使用的文本文件
```

另外 Helm 会保留 `<font style="color:#DF2A3F;">charts/</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">crds/</font>` 以及 `<font style="color:#DF2A3F;">templates/</font>` 目录以及上面列出的文件名的使用。

## 2 Chart.yaml 文件
对于一个 chart 包来说<font style="color:#DF2A3F;"> </font>`<font style="color:#DF2A3F;">Chart.yaml</font>` 文件是必须的，它包含下面的这些字段：

```yaml
apiVersion: chart API 版本 (必须)
name: chart 名 (必须)
version: SemVer 2版本 (必须)
kubeVersion: # 兼容的 Kubernetes 版本 (可选)
description: # 一句话描述 (可选)
type: # chart 类型 (可选)
keywords:
  - # 当前项目关键字集合 (可选)
home: # 当前项目的 URL (可选)
sources:
  - # 当前项目源码 URL (可选)
dependencies: # chart 依赖列表 (可选)
  - name: # chart 名称 (nginx)
    version: # chart 版本 ("1.2.3")
    repository: # 仓库地址 ("https://example.com/charts")
maintainers: # (可选)
  - name: # 维护者名字 (对每个 maintainer 是必须的)
    email: # 维护者的 email (可选)
    url: # 维护者 URL (可选)
icon: # chart 的 SVG 或者 PNG 图标 URL (可选).
appVersion: # 包含的应用程序版本 (可选). 不需要 SemVer 版本
deprecated: # chart 是否已被弃用 (可选, boolean)
```

其他字段默认会被忽略。

### 2.1 版本
每个 chart 都必须有一个版本号，版本必须遵循 `<font style="color:#DF2A3F;">SemVer2</font>` 标准，和 Helm Classic 不同，<u><font style="color:#DF2A3F;">Kubernetes Helm 使用版本号作为 release 的标记</font></u>，仓库中的软件包通过名称加上版本号来标识的。

例如，将一个 nginx 的 chart 包 version 字段设置为：`<font style="color:#DF2A3F;">1.2.3</font>`，则 chart 最终名称为：

```plain
nginx-1.2.3.tgz
```

还支持更复杂的 `<font style="color:#DF2A3F;">SemVer2</font>` 名称，例如版本：`<font style="color:#DF2A3F;">1.2.3-alpha.1+ef365</font>`，但是需要注意的是系统明确禁止使用非 `<font style="color:#DF2A3F;">SemVer</font>` 的名称。

`<font style="color:#DF2A3F;">Chart.yaml</font>` 中的 `<font style="color:#DF2A3F;">version</font>` 字段被很多 Helm 工具使用，包括 CLI 工具，生成包的时候，命令 `<font style="color:#DF2A3F;">helm package</font>` 将使用该字段作为包名称中的标记，系统是默认 Chart 包中的版本号与 `<font style="color:#DF2A3F;">chart.yaml</font>` 中的版本号匹配的，所以如果不匹配的话就导致一系列错误。

### 2.2 `<font style="color:#DF2A3F;">apiVersion</font>` 字段
对于 Helm 3 以上的版本 `<font style="color:#DF2A3F;">apiVersion</font>` 字段应该是 `<font style="color:#DF2A3F;">v2</font>`，之前版本的 Chart 应该设置为`<font style="color:#DF2A3F;">v1</font>`，并且也可以有 Helm 3 进行安装。

### 2.3 `<font style="color:#DF2A3F;">appVersion</font>` 字段
<u>要注意 </u>`<u><font style="color:#DF2A3F;">appVersion</font></u>`<u> 字段与 version 字段无关，这是一种指定应用程序版本的方法</u>，比如 drupal 的 Chart 包可能有一个 `<font style="color:#DF2A3F;">appVersion: 8.2.1</font>` 的字段，表示 Chart 中包含的 drupal 版本是 8.2.1，该字段仅供参考，对 Chart 版本的计算不会产生影响。

### 2.4 弃用 Charts
当在 Chart 仓库中管理 charts 的时候，有时候需要弃用一个 chart，`<font style="color:#DF2A3F;">Chart.yaml</font>` 中的可选字段 `<font style="color:#DF2A3F;">deprecated</font>` 可以用来标记一个 chart 为弃用状态。如果将仓库中最新版本的 chart 标记为弃用，则整个 chart 都会被当做弃用状态了。以后可以通过发布一个未被标记为弃用状态的新版本来重新使用该 chart。弃用 charts 的工作流程如下所示：

+ 更新 chart 的 `<font style="color:#DF2A3F;">Chart.yaml</font>` 来标记 chart 为弃用状态
+ 发布该新版本到 Chart 仓库
+ 从源码仓库（比如 git）中删除 chart

### 2.5 Chart 类型
`<font style="color:#DF2A3F;">type</font>` 字段定义 chart 的类型，可以定义两种类型：应用程序（application）和库（library）。应用程序是默认的类型，它是一个可以完整操作的标准 chart，库或者辅助类 chart 为 chart 提供了一些实用的功能，`<font style="color:#DF2A3F;">library</font>` 不同于应用程序 chart，因为它没有资源对象，所以无法安装。

:::success
⚠️warning "注意"

一个应用 chart 也可以当作库进行使用。通过将类型设置为 `<font style="color:#DF2A3F;">library</font>`，然后该 chart 就会渲染成一个库，可以在其中使用所有的实用性功能，chart 的所有资源对象都不会被渲染。

:::

### 2.6 LICENSE, README 和 NOTES
**<font style="color:#DF2A3F;">Chart 还可以包含用于描述 chart 的安装、配置、用法和许可证书的文件。</font>**

**<font style="color:#DF2A3F;">LICENSE 是一个纯文本文件，其中包含 chart 的许可证书。chart 可以包含一个许可证书，因为它可能在模板中具有编程逻辑，所以不只是配置，如果需要，chart 还可以为应用程序提供单独的 license(s)。</font>**

Chart 的 README 文件应该采用 Markdown（`<font style="color:#DF2A3F;">README.md</font>`）格式，并且通常应该包含如下的一些信息：

+ chart 提供的应用程序的描述信息
+ 运行 chart 的任何先决条件或者要求
+ `<font style="color:#DF2A3F;">values.yaml</font>` 和默认值中的一些选项说明
+ 与 chart 的安装或配置有关的任何其他信息

chart 还可以包含简短的纯文本模板或者 `**<u><font style="color:#DF2A3F;">NOTES.txt</font></u>**`**<u><font style="color:#DF2A3F;"> 文件，该文件将在安装后以及查看 release 状态的时候打印出来。该文件会被当成模板文件，并且可以用于显示使用说明，后续步骤或与 release 有关的任何其他信息。</font></u>**例如，可以提供用于连接到数据或访问 Web UI 的指令。由于在运行 `<font style="color:#DF2A3F;">helm install</font>`<font style="color:#DF2A3F;"> </font>或者 `<font style="color:#DF2A3F;">helm status</font>` 的时候该文件会打印到 `<font style="color:#DF2A3F;">STDOUT</font>` 中，所以建议该文件内容保持内容简短然后可以指向 README 文件来获取更多详细信息。

### 2.7 `<font style="color:#DF2A3F;">dependencies</font>`依赖
在 Helm 中，一个 chart 包可能会依赖许多其他的 chart。这些依赖关系可以使用 `<font style="color:#DF2A3F;">Chart.yaml</font>` 中的依赖关系字段动态链接，也可以引入到 `<font style="color:#DF2A3F;">charts/</font>` 目录手动进行管理。

#### 2.7.1 使用 `<font style="color:#DF2A3F;">dependencies</font>` 字段管理依赖
当前 chart 所需的依赖 chart 需要在 `<font style="color:#DF2A3F;">dependencies</font>` 字段中进行定义，如下所示：

```yaml
dependencies:
  - name: apache
    version: 1.2.3
    repository: https://example.com/charts
  - name: mysql
    version: 3.2.1
    repository: https://another.example.com/charts
```

+ `<font style="color:#DF2A3F;">name</font>` 字段是所依赖的 chart 的名称
+ `<font style="color:#DF2A3F;">version</font>` 字段是依赖的 chart 版本
+ `<font style="color:#DF2A3F;">repository</font>` 字段是 chart 仓库的完整 URL，不过需要注意，必须使用 `<font style="color:#DF2A3F;">helm repo add</font>`<font style="color:#DF2A3F;"> </font>在本地添加该 repo

定义了依赖项后，可以运行 `<u><font style="color:#DF2A3F;">helm dependency update</font></u>` 来更新依赖项，它将根据你的依赖项文件把你所有指定的 chart 包下载到 `<font style="color:#DF2A3F;">charts/</font>` 目录中：

```shell
➜ helm dependency update foochart
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "local" chart repository
...Successfully got an update from the "stable" chart repository
...Successfully got an update from the "example" chart repository
...Successfully got an update from the "another" chart repository
Update Complete. Happy Helming!
Saving 2 charts
Downloading apache from repo https://example.com/charts
Downloading mysql from repo https://another.example.com/charts
```

当执行 `<font style="color:#DF2A3F;">helm dependency update</font>` 命令的时候会解析 chart 的依赖项，会将他们作为 chart 包文件下载存放到 `<font style="color:#DF2A3F;">charts/</font>` 目录中，所以，对于上面的示例，我们可以在 charts 目录中看到如下的文件：

```shell
charts/
  apache-1.2.3.tgz
  mysql-3.2.1.tgz
```

#### 2.7.2 alias 字段
除了上面的几个字段之外，每个依赖项还可以包含一个可选的 `<font style="color:#DF2A3F;">alias</font>` 别名字段。为依赖 <u><font style="color:#DF2A3F;">chart 添加别名将使用别名作为依赖的名称。</font></u>在需要访问其他名称的 chart 情况下，就可以使用别名，如下所示：

```yaml
# parentchart/Chart.yaml

dependencies:
  - name: subchart
    repository: http://localhost:10191
    version: 0.1.0
    alias: new-subchart-1
  - name: subchart
    repository: http://localhost:10191
    version: 0.1.0
    alias: new-subchart-2
  - name: subchart
    repository: http://localhost:10191
    version: 0.1.0
```

在上面示例中，我们将获得3个依赖项：

```shell
subchart
new-subchart-1
new-subchart-2
```

当然其实我们也可以手动来实现，将同一个 chart 以不同的名称多次复制/粘贴到 `<font style="color:#DF2A3F;">charts/</font>` 目录中也是可以的。

### 2.8 TEMPLATES 和 VALUES
Helm Chart 模板是用 [Go template 语言](https://golang.org/pkg/text/template/) 进行编写的，另外还额外增加了([Sprig]([https://github.com/Masterminds/sprig](https://github.com/Masterminds/sprig))

库中的 50 个左右的附加模板函数和一些其他[专用函数]([https://helm.sh/docs/howto/charts_tips_and_tricks/](https://helm.sh/docs/howto/charts_tips_and_tricks/))。

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761820964784-61ebb84c-6273-40a1-b99f-2ae9faf9efaa.png)

所有模板文件都存储在 chart 的 `<font style="color:#DF2A3F;">templates/</font>` 目录下面，当 Helm 渲染 charts 的时候，它将通过模板引擎传递该目录中的每个文件。模板的 `<font style="color:#DF2A3F;">Values</font>` 可以通过两种方式提供：

+ Chart 开发人员可以在 chart 内部提供一个名为 `<font style="color:#DF2A3F;">values.yaml</font>` 的文件，该文件可以包含默认的 values 值内容。
+ Chart 用户可以提供包含 values 值的 YAML 文件，可以在命令行中通过 `<font style="color:#DF2A3F;">helm install</font>` 来指定该文件。

当用户提供自定义 values 值的时候，这些值将覆盖 chart 中 `<font style="color:#DF2A3F;">values.yaml</font>` 文件中的相应的值。

#### 2.8.1 `<font style="color:#DF2A3F;">templates/</font>`模板文件
模板文件遵循编写 Go 模板的标准约定（可以查看 [text/template 包文档](https://golang.org/pkg/text/template/)查看详细信息），下面是一个模板文件示例：

```yaml
# deis-database.yaml
apiVersion: v1
kind: ReplicationController
metadata:
  name: deis-database
  namespace: deis
  labels:
    app.kubernetes.io/managed-by: deis
spec:
  replicas: 1
  selector:
    app.kubernetes.io/name: deis-database
  template:
    metadata:
      labels:
        app.kubernetes.io/name: deis-database
    spec:
      serviceAccount: deis-database
      containers:
        - name: deis-database
          image: {{ .Values.imageRegistry }}/postgres:{{ .Values.dockerTag }}
          imagePullPolicy: {{ .Values.pullPolicy }}
          ports:
            - containerPort: 5432
          env:
            - name: DATABASE_STORAGE
              value: {{ default "minio" .Values.storage }}
```

上面这个示例是 Kubernetes replication 控制器的一个模板，它可以使用以下4个模板值（通常在 `<font style="color:#DF2A3F;">values.yaml</font>` 文件中定义的）：

+ `<font style="color:#DF2A3F;">imageRegistry</font>`：Docker 镜像仓库
+ `<font style="color:#DF2A3F;">dockerTag</font>`：Docker 镜像 tag
+ `<font style="color:#DF2A3F;">pullPolicy</font>`：镜像拉取策略
+ `<font style="color:#DF2A3F;">storage</font>`：存储后端，默认设置为 `<font style="color:#DF2A3F;">"minio"</font>`

这些所有的 values 值都是有模板作者来定义的，Helm 不会也不需要规定这些参数。可以可以查看 [Kubernetes Charts 项目](https://github.com/helm/charts)去了解更多的 charts 项目的详细内容。

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761816671351-974bd9fa-3a98-4567-8ffd-45606ede3f3e.png)

#### 2.8.2 预定义 Values
在<u>模板中用 </u>`<u><font style="color:#DF2A3F;">.Values</font></u>`<u> 可以获取到 </u>`<u><font style="color:#DF2A3F;">values.yaml</font></u>`<u> 文件</u>（或者 `<font style="color:#DF2A3F;">--set</font>` 参数）提供的 values 值，此外，还可以在模板中访问其他预定义的数据。下面是一些预定义的、可用于每个模板、并且不能被覆盖的 values 值，与所有 values 值一样，名称都是区分大小写的：

+ `<font style="color:#DF2A3F;">Release.Name</font>`：release 的名称（不是 chart）
+ `<font style="color:#DF2A3F;">Release.Namespace</font>`：release 被安装到的命名空间
+ `<font style="color:#DF2A3F;">Release.Service</font>`：渲染当前模板的服务，在 Helm 上，实际上该值始终为 Helm
+ `<font style="color:#DF2A3F;">Release.IsUpgrade</font>`：如果当前操作是升级或回滚，则该值为 true
+ `<font style="color:#DF2A3F;">Release.IsInstall</font>`：如果当前操作是安装，则该值为 true
+ `<font style="color:#DF2A3F;">Chart</font>`：`<font style="color:#DF2A3F;">Chart.yaml</font>` 文件的内容，可以通过 `<font style="color:#DF2A3F;">Chart.Version</font>` 来获得 Chart 的版本，通过 `<font style="color:#DF2A3F;">Chart.Maintainers</font>` 可以获取维护者信息
+ `<font style="color:#DF2A3F;">Files</font>`： 一个包含 chart 中所有非特殊文件的 map 对象，这不会给你访问模板的权限，但是会给你访问存在的其他文件的权限（除非使用 `<font style="color:#DF2A3F;">.helmignore</font>` 排除它们），可以使用 `<font style="color:#DF2A3F;">{{ index .Files "file.name" }}</font>` 或者 `<font style="color:#DF2A3F;">{{ .Files.Get name }}</font>` 或者 `<font style="color:#DF2A3F;">{{ .Files.GetString name }}</font>` 函数来访问文件，你还可以使用 `<font style="color:#DF2A3F;">{{ .Files.GetBytes }}</font>` 以 `<font style="color:#DF2A3F;">[]byte</font>` 的形式获取访问文件的内容
+ `<font style="color:#DF2A3F;">Capabilities</font>`：也是一个类 map 的对象，其中包含有关 Kubernetes 版本（`<font style="color:#DF2A3F;">{{ .Capabilities.KubeVersion }}</font>`）和支持的 Kubernetes API 版本（`<font style="color:#DF2A3F;">{{ .Capabilities.APIVersions.Has "batch/v1" }}</font>`）信息。

:::success
⚠️warning "注意"

任何未知的 `<font style="color:#DF2A3F;">Chart.yaml</font>` 字段都会被删除，在 Chart 对象内部无法访问他们，所以，`<font style="color:#DF2A3F;">Chart.yaml</font>` 不能用于将任意结构化的数据传递到模板中，但是可以使用 values 文件来传递。

:::

#### 2.8.3 Values 文件
为模板提供一些必须的 values 值的 `<font style="color:#DF2A3F;">values.yaml</font>` 文件如下所示：

```yaml
imageRegistry: "quay.io/deis"
dockerTag: "latest"
pullPolicy: "Always"
storage: "s3"
```

values 文件的格式是 YAML，一个 chart 包可能包含一个默认的 `<font style="color:#DF2A3F;">values.yaml</font>` 文件，`<font style="color:#DF2A3F;">helm install</font>` 命令允许用户通过提供其他的 YAML 值文件来覆盖默认的值：

```shell
helm install --values=myvals.yaml wordpress
```

用这种方式来传递 values 值的时候，它们将合并到默认值文件中，比如有一个 `<font style="color:#DF2A3F;">myvals.yaml</font>` 文件如下所示：

```yaml
storage: "gcs"
```

将其与 chart 的 `<font style="color:#DF2A3F;">values.yaml</font>` 文件合并后，得到的结果为：

```yaml
imageRegistry: "quay.io/deis"
dockerTag: "latest"
pullPolicy: "Always"
storage: "gcs"
```

我们可以看到只有最后一个字段被覆盖了。

:::success
⚠️warning "注意"

chart 内包含的默认 values 文件必须命名为 `<font style="color:#DF2A3F;">values.yaml</font>`，但是在命令行上指定的文件可以任意命名。

如果在 `<font style="color:#DF2A3F;">helm install</font>` 或者 `<font style="color:#DF2A3F;">helm upgrade</font>` 的时候使用 `<font style="color:#DF2A3F;">--set</font>` 参数，则这些值将在客户端转换为 YAML 格式。

如果 values 文件存在任何必须的条目，则可以使用 `<font style="color:#DF2A3F;">required</font>` 函数在 chart 模板中将它们声明为必须选项。

:::

然后我们就可以使用 `<font style="color:#DF2A3F;">.Values</font>` 对象在模板中访问任意一个 values 值，类似于下面的模板文件：

```yaml
apiVersion: v1
kind: ReplicationController
metadata:
  name: deis-database
  namespace: deis
  labels:
    app.kubernetes.io/managed-by: deis
spec:
  replicas: 1
  selector:
    app.kubernetes.io/name: deis-database
  template:
    metadata:
      labels:
        app.kubernetes.io/name: deis-database
    spec:
      serviceAccount: deis-database
      containers:
        - name: deis-database
          image: {{ .Values.imageRegistry }}/postgres:{{ .Values.dockerTag }}
          imagePullPolicy: {{ .Values.pullPolicy }}
          ports:
            - containerPort: 5432
          env:
            - name: DATABASE_STORAGE
              value: {{ default "minio" .Values.storage }}
```

#### 2.8.4 作用范围、依赖和 Values
**<u>values.yaml 文件可以声明顶级的 chart 以及该 chart 的 </u>**`**<u><font style="color:#DF2A3F;">charts/</font></u>**`**<u> 目录中包含的任何 chart 的值。</u>**或者，换句话说，values 文件可以为 chart 以及他的任何依赖项提供 values 值。例如，上面提到了 WordPress 这个 chart 同时依赖 mysql 和 apache 这两个依赖项，values 文件可以为所有这些组件提供 values 值：

```yaml
title: "My WordPress Site" # 传递到 WordPress 模板

mysql:
  max_connections: 100 # 传递到 MySQL
  password: "secret"

apache:
  port: 8080 # 传递到 Apache
```

较高级别的 Charts 可以访问下面定义的所有变量，所以，WordPress 这个 chart 可以通过 `<font style="color:#DF2A3F;">.Values.mysql.password</font>` 来访问 MySQL 的密码，但是较低级别的 chart 是无法访问父 chart 中的内容的，所有 MySQL 无法获取到 title 属性，当然同样也不能访问 `<font style="color:#DF2A3F;">apache.port</font>`。

Values 是有命名空间的，但是会对其进行调整，比如对于 WordPress 这个 chart 来说，它可以通过 `<font style="color:#DF2A3F;">.Values.mysql.password</font>` 来进行访问，但是对于 MySQL 这个 chart 本身来说，values 的范围缩小了，命名空间前缀会被删除，所以它只需要通过 `<font style="color:#DF2A3F;">.Values.password</font>` 就可以访问到。

#### 2.8.5 全局 Values
从 `<font style="color:#DF2A3F;">2.0.0-Alpha.2</font>` 版本开始，Helm 开始支持特殊的 `<font style="color:#DF2A3F;">global</font>` 全局值，比如将上面的示例修改如下：

```yaml
title: "My WordPress Site" # 传递到 WordPress 模板

global:
  app: MyWordPress

mysql:
  max_connections: 100 # 传递到 MySQL
  password: "secret"

apache:
  port: 8080 # 传递到 Apache
```

上面我们添加了一个全局范围的 value 值：`<font style="color:#DF2A3F;">app: MyWordPress</font>`，该值可以通过 `<font style="color:#DF2A3F;">.Values.global.app</font>` 提供给所有 chart 使用。

例如，mysql 模板可以以 `<font style="color:#DF2A3F;">{{ .Values.global.app }}</font>` 来访问 app，apache chart 也可以，实际上，上面的 values 文件会这样重新生成：

```yaml
title: "My WordPress Site" # 传递到 WordPress 模板

global:
  app: MyWordPress

mysql:
  global:
    app: MyWordPress
  max_connections: 100 # 传递到 MySQL
  password: "secret"

apache:
  global:
    app: MyWordPress
  port: 8080 # 传递到 Apache
```

这种方式提供了一种与所有子 chart 共享一个顶级变量的方式，这对于设置 meta 数据这种属性是非常有用的。如果子 chart 声明了全局变量，则该全局变量将向下（传递到子 chart 的子 chart 中）传递，而不会向上传递到父 chart，<font style="color:#DF2A3F;">子 chart 无法影响 父 chart 的值</font>。同样，<u><font style="color:#DF2A3F;">父 chart 的全局遍历优先与子 chart 中的全局变量</font></u>。

#### 2.8.6 Schema 文件
有时候，chart 开发者可能希望在其 values 值上面定义一个结构，这种情况下可以通过在 `<font style="color:#DF2A3F;">values.schema.json</font>` 文件中定义一个 schema 来完成，这里的 schema 就是一个 [JSON Schema](https://json-schema.org/) 文件结构规范，如下所示：

```json
{
  "➜schema": "https://json-schema.org/draft-07/schema#",
  "properties": {
    "image": {
      "description": "Container Image",
      "properties": {
        "repo": {
          "type": "string"
        },
        "tag": {
          "type": "string"
        }
      },
      "type": "object"
    },
    "name": {
      "description": "Service name",
      "type": "string"
    },
    "port": {
      "description": "Port",
      "minimum": 0,
      "type": "integer"
    },
    "protocol": {
      "type": "string"
    }
  },
  "required": [
    "protocol",
    "port"
  ],
  "title": "Values",
  "type": "object"
}
```

该 schema 会对 values 值进行校验，调用以下任何命令时，都会进行验证：

+ `<font style="color:#DF2A3F;">helm install</font>`<font style="color:#DF2A3F;"> -> 安装 Helm Release</font>
+ `<font style="color:#DF2A3F;">helm upgrade</font>`<font style="color:#DF2A3F;"> -> 升级或者安装 Helm Release</font>
+ `<font style="color:#DF2A3F;">helm lint</font>`<font style="color:#DF2A3F;"> -> 校验 Helm Charts 包</font>
+ `<font style="color:#DF2A3F;">helm template</font>`<font style="color:#DF2A3F;"> -> 查看 Helm Charts 模板文件</font>

比如下面的示例文件就可以满足上面的 schema 要求：

```yaml
name: frontend
protocol: https
port: 443
```

需要注意的是该 schema 将应用于最终的 `<font style="color:#DF2A3F;">.Values</font>` 对象，而不仅仅是应用于 `<font style="color:#DF2A3F;">values.yaml</font>` 文件，所以下面的文件也是可以满足 schema 要求的：

```yaml
name: frontend
protocol: https
```

因为在安装的时候我们通过 `<font style="color:#DF2A3F;">--set</font>` 选项传递了必须的 `<font style="color:#DF2A3F;">port</font>` 属性：

```shell
helm install --set port=443
```

此外，还会根据所有的子 chart schemas 来检查最终的 `<font style="color:#DF2A3F;">.Values</font>` 对象，这意味着父 chart 无法规避对子 chart 的限制。同样的，如果子 chart 要求未满足子 chart 的<font style="color:#DF2A3F;"> </font>`<font style="color:#DF2A3F;">values.yaml</font>` 文件，则父 chart 必须满足这些限制才能生效。

#### 2.8.7 参考文档
在编写模板、values、和 schema 文件的时候，下面这些文档可以提供一些帮助：

+ [Go Template](https://godoc.org/text/template)
+ [额外的模板函数](https://godoc.org/github.com/Masterminds/sprig)
+ [YAML 文件](https://yaml.org/spec/)
+ [JSON Schema](https://json-schema.org/)

### 2.9 CRDS
<u>Kubernetes 提供了一种声明新类型的 Kubernetes 对象的机制，使用 </u>`<u><font style="color:#DF2A3F;">CustomResourceDefinitions（CRDS）</font></u>`<u>可以让 Kubernetes 开发人员声明自定义资源类型。</u>

在 Helm 3 中，CRD 被视为一种特殊的对象，它们在 chart 部分之前被安装，并且会受到一些限制。**<u>CRD YAML 文件应该放置 chart 内的 </u>**`**<u><font style="color:#DF2A3F;">crds/</font></u>**`**<u><font style="color:#DF2A3F;"> </font></u>****<u>目录下面。</u>**多个 CRDs 可以放在同一个文件中，Helm 将尝试将 CRD 目录中的所有文件加载到 Kubernetes 中。

:::success
⚠️**<u>需要注意的是 CRD 文件不能模板化</u>**<u>，它们必须是纯的 YAML 文件。</u>

:::

当 **<u><font style="color:#601BDE;">Helm 安装一个新的 chart 的时候，它将会安装 CRDs，然后会暂停直到 API Server 提供 CRD 为止，然后才开始启动模板引擎，渲染其余的 chart 模板，并将其安装到 Kubernetes 中</font></u>**。由于这个安装顺序，CRD 信息在 Helm 模板的 `<font style="color:#DF2A3F;">.Capabilities</font>`<font style="color:#DF2A3F;"> </font>对象中是可以获取到的，并且 Helm 模板可能会创建在 CRD 中声明的对象的新实例。

比如，如果你的 Chart 在 `<font style="color:#DF2A3F;">crds</font>` 目录下面有一个 CronTab 的 CRD，则可以在 `<font style="color:#DF2A3F;">templates/</font>` 目录下面创建 CronTab 类型的实例：

```shell
crontabs/
  Chart.yaml
  crds/
    crontab.yaml
  templates/
    mycrontab.yaml
```

`<font style="color:#DF2A3F;">crontab.yaml</font>` 文件必须包含不带模板指定的 CRD，Helm 会自动直接部署 CRD 文件，然后再来部署 templates 模板目录下的文件：

```yaml
kind: CustomResourceDefinition
metadata:
  name: crontabs.stable.example.com
spec:
  group: stable.example.com
  versions:
    - name: v1
      served: true
      storage: true
  scope: Namespaced
  names:
    plural: crontabs
    singular: crontab
    kind: CronTab
```

然后模板 `<font style="color:#DF2A3F;">mycrontab.yaml</font>` 可以创建一个新的 CronTab（和平时使用模板一样）：

```yaml
apiVersion: stable.example.com
kind: CronTab
metadata:
  name: {{ .Values.name }}
spec:
   # ......
```

在继续安装 `<font style="color:#DF2A3F;">templates/</font>` 之前，Helm 会确保已经安装上了 CronTab 类型，并且可以从 Kubernetes API server 上获得该类型。

#### 2.9.1 CRDs 的限制
于 Kubernetes 中的大多数对象不同，<u><font style="color:#DF2A3F;">CRDs 是全局安装的，所以 Helm 在管理 CRD 的时候比较谨慎</font></u>，会有一些限制：

+ <u><font style="color:#601BDE;">CRDs 不会重新安装，如果 Helm 确定 </font></u>`<u><font style="color:#DF2A3F;">crds/</font></u>`<u><font style="color:#601BDE;"> 目录中的 CRD 已经存在（无论版本如何），Helm 都不会重新安装或升级。</font></u>
+ <u><font style="color:#601BDE;">CRDs 不会在升级或回滚的时候安装，只会在安装操作的时候创建 CRDs。</font></u>
+ <u><font style="color:#601BDE;">CRDs 不会被删除，删除 CRD 会自动删除集群中所有 namespace 中的 CRDs 内容，所以 Helm 不会删除 CRD。</font></u>

Helm 希望想要升级或删除 CRDs 的操作人员可以手动来仔细地操作。

### 2.10 使用 Helm 管理 Charts
helm 工具有几个用于操作 charts 的命令，如下所示。

创建一个新的 chart 包：

```shell
➜ helm create mychart
Created mychart/

➜ cat mychart/Chart.yaml
apiVersion: v2
name: mychart
description: A Helm chart for Kubernetes

# A chart can be either an 'application' or a 'library' chart.
#
# Application charts are a collection of templates that can be packaged into versioned archives
# to be deployed.
#
# Library charts provide useful utilities or functions for the chart developer. They're included as
# a dependency of application charts to inject those utilities and functions into the rendering
# pipeline. Library charts do not define any templates and therefore cannot be deployed.
type: application

# This is the chart version. This version number should be incremented each time you make changes
# to the chart and its templates, including the app version.
# Versions are expected to follow Semantic Versioning (https://semver.org/)
version: 0.1.0

# This is the version number of the application being deployed. This version number should be
# incremented each time you make changes to the application. Versions are not expected to
# follow Semantic Versioning. They should reflect the version the application is using.
# It is recommended to use it with quotes.
appVersion: "1.16.0"
```

一旦你已经编辑了一个 chart 包，Helm 可以将其打包到一个独立文件中：

```shell
# 新版本的 Helm CLI 执行效果
➜ helm package mychart
Successfully packaged chart and saved it to: /root/georgezhong/CloudNative/Learning/k8slearn/8.Kubernetes Helm/8.2.Charts/Manifest/mychart-0.1.0.tgz

# 旧版本的 Helm CLI 执行效果
➜ helm package mychart
Archived mychart-0.1.0.tgz
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761991273383-ec818f36-22df-445f-863f-7419d2149b4d.png)

你还可以使用 helm 帮助你查找 chart 包的格式要求方面或其他问题：

```shell
# 新版本的 Helm CLI 执行效果
➜ helm lint mychart
==> Linting mychart
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed

# 旧版本的 Helm CLI 执行效果
➜ helm lint mychart
No issues found
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1761991261531-eb6ef9c3-3390-4bf5-9fd2-c8cfca8aacdc.png)

### 2.11 Chart 仓库
<u><font style="color:#DF2A3F;">Chart 仓库实际上就是一个 HTTP 服务器，其中包含一个或多个打包的 chart 包，虽然</font></u>**<u><font style="color:#DF2A3F;">可以使用 helm 来管理本地 chart 目录，但是在共享 Charts 的时候，最好的还是使用 Chart 仓库。</font></u>**

可以提供 `<font style="color:#DF2A3F;">YAML</font>` 文件和 `<font style="color:#DF2A3F;">tar</font>`文件并可以相应 GET 请求的任何 HTTP 服务器都可以作为 chart 仓库服务器。仓库的主要特征是存在一个名为 `<font style="color:#DF2A3F;">index.yaml</font>` 的特殊文件，该文件具有仓库中提供的所有软件包的列表以及允许检索和验证这些软件包的元数据。

在客户端，可以使用 `<font style="color:#DF2A3F;">helm repo</font>` 命令来管理仓库，但是 Helm 不提供用于将 chart 上传到远程 chart 仓库的工具。

## 3 Helm Repo 可以添加的 URL
Helm Repo 可以添加的信息：

```shell
$ helm repo list 
NAME                    URL                                                       
jenkinsci               https://charts.jenkins.io/                                
jumpserver              https://jumpserver.github.io/helm-charts                  
bitnami                 https://charts.bitnami.com/bitnami                        
aliyunstable            https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts    
azure                   http://mirror.azure.cn/kubernetes/charts                  
stable                  https://charts.helm.sh/stable                             
gitlab                  https://charts.gitlab.io                                  
kiwigrid                https://kiwigrid.github.io                                
saleor                  https://k.github.io/saleor-helm                           
elastic                 https://helm.elastic.co                                   
harbor                  https://helm.goharbor.io                                  
reactiveops-stable      https://charts.reactiveops.com/stable                     
buttahtoast             https://buttahtoast.github.io/helm-charts/                
bedag                   https://bedag.github.io/helm-charts/                      
grafana                 https://grafana.github.io/helm-charts                     
prometheus              https://prometheus-community.github.io/helm-charts        
meshery                 https://meshery.io/charts/                                
neuvector               https://neuvector.github.io/neuvector-helm/               
higress.io              https://higress.io/helm-charts                            
istio                   https://istio-release.storage.googleapis.com/charts       
kyverno                 https://kyverno.github.io/kyverno/                        
open-telemetry          https://open-telemetry.github.io/opentelemetry-helm-charts
koderover-chart         https://koderover.tencentcloudcr.com/chartrepo/chart      
openobserve             https://charts.openobserve.ai                             
glasskube               https://charts.glasskube.eu/                              
kuma                    https://kumahq.github.io/charts                           
kubeclarity             https://openclarity.github.io/kubeclarity                 
kubevela                https://charts.kubevela.net/core
```

添加的命令如下：

```shell
$ helm repo add jenkinsci               https://charts.jenkins.io/                                
$ helm repo add jumpserver              https://jumpserver.github.io/helm-charts                  
$ helm repo add bitnami                 https://charts.bitnami.com/bitnami                        
$ helm repo add aliyunstable            https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts    
$ helm repo add azure                   http://mirror.azure.cn/kubernetes/charts                  
$ helm repo add stable                  https://charts.helm.sh/stable                             
$ helm repo add gitlab                  https://charts.gitlab.io                                  
$ helm repo add kiwigrid                https://kiwigrid.github.io                                
$ helm repo add saleor                  https://k.github.io/saleor-helm                           
$ helm repo add elastic                 https://helm.elastic.co                                   
$ helm repo add harbor                  https://helm.goharbor.io                                  
$ helm repo add reactiveops-stable      https://charts.reactiveops.com/stable                     
$ helm repo add buttahtoast             https://buttahtoast.github.io/helm-charts/                
$ helm repo add bedag                   https://bedag.github.io/helm-charts/                      
$ helm repo add grafana                 https://grafana.github.io/helm-charts                     
$ helm repo add prometheus              https://prometheus-community.github.io/helm-charts        
$ helm repo add meshery                 https://meshery.io/charts/                                
$ helm repo add neuvector               https://neuvector.github.io/neuvector-helm/               
$ helm repo add higress.io              https://higress.io/helm-charts                            
$ helm repo add istio                   https://istio-release.storage.googleapis.com/charts       
$ helm repo add kyverno                 https://kyverno.github.io/kyverno/                        
$ helm repo add open-telemetry          https://open-telemetry.github.io/opentelemetry-helm-charts
$ helm repo add koderover-chart         https://koderover.tencentcloudcr.com/chartrepo/chart      
$ helm repo add openobserve             https://charts.openobserve.ai                             
$ helm repo add glasskube               https://charts.glasskube.eu/                              
$ helm repo add kuma                    https://kumahq.github.io/charts                           
$ helm repo add kubeclarity             https://openclarity.github.io/kubeclarity                 
$ helm repo add kubevela                https://charts.kubevela.net/core
```

