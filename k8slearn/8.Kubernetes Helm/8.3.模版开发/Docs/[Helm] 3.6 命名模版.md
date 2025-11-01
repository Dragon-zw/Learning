<font style="color:rgb(28, 30, 33);">前面我们都是只操作的一个模板，现在我们来尝试使用多个模板文件。在本节中，我们可以了解到如何在一个文件中定义命名模板，然后在其他地方使用它们。</font>**<u><font style="color:#DF2A3F;">命名模板（有时也叫子模板）只是在文件内部定义的有名称的模板。</font></u>**<font style="color:rgb(28, 30, 33);">主要有两种创建方式以及几种不同的使用方式。</font>

:::success
🍨<u><font style="color:#DF2A3F;">当使用命名模板的时候有几个重要细节：模板名称是</font></u>**<u><font style="color:#DF2A3F;">全局</font></u>**<u><font style="color:#DF2A3F;">的，如果声明两个具有相同名称的模板，则会使用最后被加载的模板。由于子 chart 中的模板是与顶级模板一起编译的，所以需要谨慎命名。</font></u>

:::

<font style="color:rgb(28, 30, 33);">一种流行的命名约定是在每个定义的模板前添加 chart 名称：</font>`<font style="color:#DF2A3F;">{{ define "mychart.labels" }}</font>`<font style="color:rgb(28, 30, 33);">，通过使用特定的 chart 名作为前缀，我们可以避免由于两个不同的 chart 实现了相同名称的模板而引起的冲突。</font>

## <font style="color:rgb(28, 30, 33);">1 </font>`<font style="color:#DF2A3F;">partials</font>`<font style="color:rgb(28, 30, 33);"> 和 </font>`<font style="color:#DF2A3F;">_</font>`<font style="color:rgb(28, 30, 33);"> 文件</font>
<font style="color:rgb(28, 30, 33);">到目前为止，我们只使用了一个模板文件，但是 Helm 的模板语言允许我们创建命名的嵌入式模板，可以在其他位置进行访问。在编写这些模板之前，有一些值得一提的命名约定：</font>

+ `<font style="color:#DF2A3F;">templates/</font>`<font style="color:rgb(28, 30, 33);"> 中的大多数文件都被视为 Kubernetes 资源清单文件（</font>`<font style="color:#DF2A3F;">NOTES.txt</font>`<font style="color:rgb(28, 30, 33);"> 除外）</font>
+ <font style="color:rgb(28, 30, 33);">以 </font>`<font style="color:#DF2A3F;">_</font>`<font style="color:rgb(28, 30, 33);"> 开头命名的文件也不会被当做 Kubernetes 资源清单文件</font>
+ <font style="color:rgb(28, 30, 33);">下划线开头的文件不会被当做资源清单之外，还可以被其他 chart 模板调用</font>

:::success
💫`<font style="color:#DF2A3F;">_</font>`<font style="color:rgb(28, 30, 33);"> 开头的这些文件其实就是 Helm 中的 </font>`<font style="color:#DF2A3F;">partials</font>`<font style="color:rgb(28, 30, 33);"> 文件，所以其实我们完全可以将命名模板定义在这些 </font>`<font style="color:#DF2A3F;">partials</font>`<font style="color:rgb(28, 30, 33);"> 文件中，默认就是 </font>`<font style="color:#DF2A3F;">_helpers.tpl</font>`<font style="color:rgb(28, 30, 33);"> 文件，其实在前面我们创建的 </font>`<font style="color:#DF2A3F;">mychart</font>`<font style="color:rgb(28, 30, 33);"> 包中也可以找到这个文件。</font>

:::

## 2 `<font style="color:#DF2A3F;">define</font>`<font style="color:rgb(28, 30, 33);"> 和 </font>`<font style="color:#DF2A3F;">template</font>`
`<font style="color:#DF2A3F;">define</font>`<font style="color:rgb(28, 30, 33);"> 关键字可以让我们在模板文件中创建命名模板，它的语法如下所示：</font>

```yaml
{{ define "MY.NAME" }}
  # 模板内容区域
{{ end }}
```

<font style="color:rgb(28, 30, 33);">比如我们可以定义一个模板来封装下 Kubernetes 的 Labels 标签：</font>

```yaml
{{- define "mychart.labels" }} # 定义 Kubernetes 模板
  labels:
    generator: helm
    date: {{ now | htmlDate }}
{{- end }}
```

<font style="color:rgb(28, 30, 33);">现在我们可以将该模板嵌入到前面的 ConfigMap 模板中，然后将其包含在模板中：</font>

```yaml
# configmap.yaml
{{- define "mychart.labels" }}
  labels:
    generator: helm
    date: {{ now | htmlDate }}
{{- end }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
  {{- template "mychart.labels" }}
data:
  myvalue: "Hello World"
  {{- range $key, $val := .Values.favorite }}
  {{ $key }}: {{ $val | quote }}
  {{- end }}
```

<font style="color:rgb(28, 30, 33);">当模板引擎读取这个文件的时候，它会存储 </font>`<font style="color:#DF2A3F;">mychart.labels</font>`<font style="color:rgb(28, 30, 33);"> 的引用，直到该模板被调用，然后会内联渲染该模板。我们渲染这个模板可以都到如下所示的结果（记得先删掉默认生成的 </font>`<font style="color:#DF2A3F;">_helpers.tpl</font>`<font style="color:rgb(28, 30, 33);"> 文件）：</font>

```yaml
$ helm install --generate-name --dry-run --debug ./mychart
[......]
# Source: mychart/templates/configmap.yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mychart-1762007485-configmap
  labels:
    generator: helm
    date: 2025-11-01
data:
  myvalue: "Hello World"
  drink: "coffee"
  food: "pizza"
```

<font style="color:rgb(28, 30, 33);">一般来说，</font><u>💡</u>_<u><font style="color:rgb(28, 30, 33);">Helm 中约定将这些模板统一放到一个 </font></u>_`_<u><font style="color:#DF2A3F;">partials</font></u>_`_<u><font style="color:rgb(28, 30, 33);"> 文件中，通常就是 </font></u>_`_<u><font style="color:#DF2A3F;">_helpers.tpl</font></u>_`_<u><font style="color:rgb(28, 30, 33);"> 文件中</font></u>_<font style="color:rgb(28, 30, 33);">，我们将上面的命名模板移动到该文件（</font>`<font style="color:#DF2A3F;">templates/_helpers.tpl</font>`<font style="color:rgb(28, 30, 33);">）中去：</font>

```yaml
{{/* 生成基本的 Label 标签 */}}
{{- define "mychart.labels" }}
  labels:
    generator: helm
    date: {{ now | htmlDate }}
{{- end }}
```

<font style="color:rgb(28, 30, 33);">一般来说，我们也会用一个简单的块（</font>`<font style="color:#DF2A3F;">{{/*...*/}}</font>`<font style="color:rgb(28, 30, 33);">）来注释这个命名模板的作用。</font>

<font style="color:rgb(28, 30, 33);">现在虽然我们把命名模板放到了 </font>`<font style="color:#DF2A3F;">_helpers.tpl</font>`<font style="color:rgb(28, 30, 33);"> 文件中，但是我们在 </font>`<font style="color:#DF2A3F;">configmap.yaml</font>`<font style="color:rgb(28, 30, 33);"> 模板中还是可以访问，因为命名模板是全局的：</font>

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
  {{- template "mychart.labels" }}
data:
  myvalue: "Hello World"
  {{- range $key, $val := .Values.favorite }}
  {{ $key }}: {{ $val | quote }}
  {{- end }}
```

<font style="color:rgb(28, 30, 33);">因为上面我们提到过命名模板是全局的，我们可以再渲染下上面的模板可以得到正确的结果。</font>

```yaml
$ helm install --generate-name --dry-run --debug ./mychart
[......]
# Source: mychart/templates/configmap.yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mychart-1762007602-configmap
  labels:
    generator: helm
    date: 2025-11-01
data:
  myvalue: "Hello World"
  drink: "coffee"
  food: "pizza"
```

## <font style="color:rgb(28, 30, 33);">3 设置模板范围</font>
<font style="color:rgb(28, 30, 33);">上面我们定义的模板中，还没有使用到任何对象，只使用了函数，现在我们来修改下定义的命名模板，包含 chart 的名称和版本：</font>

```yaml
{{/* 生成基本的 Label 标签 */}}
{{- define "mychart.labels" }}
  labels:
    generator: helm
    date: {{ now | htmlDate }}
    chart: {{ .Chart.Name }}
    version: {{ .Chart.Version }}
{{- end }}
```

<font style="color:rgb(28, 30, 33);">现在我们来渲染下模板，会出现下面的错误：</font>

```shell
# 旧版本的 helm CLI 执行效果
➜ helm install --generate-name --dry-run --debug ./mychart
install.go:148: [debug] Original chart version: ""
install.go:165: [debug] CHART PATH: /Users/ych/devs/workspace/yidianzhishi/course/k8strain/content/helm/manifests/mychart

Error: unable to build kubernetes objects from release manifest: error validating "": error validating data: [unknown object type "nil" in ConfigMap.metadata.labels.chart, unknown object type "nil" in ConfigMap.metadata.labels.version]
helm.go:76: [debug] error validating "": error validating data: [unknown object type "nil" in ConfigMap.metadata.labels.chart, unknown object type "nil" in ConfigMap.metadata.labels.version]
[......]

# 新版本的 helm CLI 执行效果
➜ helm install --generate-name --dry-run --debug ./mychart
[......]
# Source: mychart/templates/configmap.yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mychart-1762007741-configmap
  labels:
    generator: helm
    date: 2025-11-01
    chart: 
    version: 
data:
  myvalue: "Hello World"
  drink: "coffee"
  food: "pizza"
```

<font style="color:rgb(28, 30, 33);">我们可以看到提示 </font>`<font style="color:#DF2A3F;">labels.chart</font>`<font style="color:rgb(28, 30, 33);"> 为 </font>`<font style="color:#DF2A3F;">nil</font>`<font style="color:rgb(28, 30, 33);">，这是因为我们使用的 </font>`<font style="color:#DF2A3F;">.Chart.Name</font>`<font style="color:rgb(28, 30, 33);"> 不在定义的这个模板的作用域范围内，当渲染命名模板（使用 </font>`<font style="color:#DF2A3F;">define</font>`<font style="color:rgb(28, 30, 33);"> 定义）的时候，它将接收模板调用传递的作用域。在我们这个示例中，我们是这样引用这个模板的：</font>

```yaml
{{- template "mychart.labels" }}
```

<u><font style="color:rgb(28, 30, 33);">没有传入任何作用域，所以在模板内我们无法访问 </font></u>`<u><font style="color:#DF2A3F;">.</font></u>`<u><font style="color:rgb(28, 30, 33);"> 中的任何内容，当然要解决很简单，我们只需要把作用域范围传递给模板即可</font></u><font style="color:rgb(28, 30, 33);">：</font>

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
  {{- template "mychart.labels" . }} # 把作用域范围传递给模板文件
......
```

<font style="color:rgb(28, 30, 33);">我们这里在使用 </font>`<font style="color:#DF2A3F;">template</font>`<font style="color:rgb(28, 30, 33);"> 调用模板的时候传递了 </font>`<font style="color:#DF2A3F;">.</font>`<font style="color:rgb(28, 30, 33);">，我们可以很容易传递 </font>`<font style="color:#DF2A3F;">.Values</font>`<font style="color:rgb(28, 30, 33);"> 或者 </font>`<font style="color:#DF2A3F;">.Values.favorite</font>`<font style="color:rgb(28, 30, 33);"> 或者我们想要的任何范围，但是这里我们想要的是顶级作用域，所以我们传递的是 </font>`<font style="color:#DF2A3F;">.</font>`<font style="color:rgb(28, 30, 33);">。</font>

<font style="color:rgb(28, 30, 33);">现在我们再来重新渲染我们的模板，可以得到如下所示的结果：</font>

```yaml
$ helm install --generate-name --dry-run --debug ./mychart
[......]
# Source: mychart/templates/configmap.yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mychart-1762007952-configmap
  labels:
    generator: helm
    date: 2025-11-01
    chart: mychart
    version: 0.1.0
data:
  myvalue: "Hello World"
  drink: "coffee"
  food: "pizza"
```

<font style="color:rgb(28, 30, 33);">现在 </font>`<font style="color:#DF2A3F;">{{ .Chart.Name }}</font>`<font style="color:rgb(28, 30, 33);"> 解析为了 mychart，而 </font>`<font style="color:#DF2A3F;">{{ .Chart.Version }}</font>`<font style="color:rgb(28, 30, 33);"> 解析为了 </font>`<font style="color:#DF2A3F;">0.1.0</font>`<font style="color:rgb(28, 30, 33);">。</font>

## <font style="color:rgb(28, 30, 33);">4 include 函数</font>
<font style="color:rgb(28, 30, 33);">假设我们定义了一个如下所示的简单模板：</font>

```yaml
{{- define "mychart.app" -}}
app_name: {{ .Chart.Name }}
app_version: "{{ .Chart.Version }}"
{{- end -}}
```

<font style="color:rgb(28, 30, 33);">现在我们想把上面的内容插入到模板的 </font>`<font style="color:#DF2A3F;">labels</font>`<font style="color:rgb(28, 30, 33);"> 部分，在 </font>`<font style="color:#DF2A3F;">data</font>`<font style="color:rgb(28, 30, 33);"> 部分也想要这个内容：</font>

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
  labels:
    {{ template "mychart.app" . }}
data:
  myvalue: "Hello World"
  {{- range $key, $val := .Values.favorite }}
  {{ $key }}: {{ $val | quote }}
  {{- end }}
{{ template "mychart.app" . }}
```

<font style="color:rgb(28, 30, 33);">但是我们直接渲染上面的模板还是会有错误：</font>

```shell
# 旧版本的 helm CLI 执行效果
➜ helm install --generate-name --dry-run --debug ./my
chart
install.go:148: [debug] Original chart version: ""
install.go:165: [debug] CHART PATH: /Users/ych/devs/workspace/yidianzhishi/course/k8strain/content/helm/manifests/mychart

Error: unable to build kubernetes objects from release manifest: error validating "": error validating data: [ValidationError(ConfigMap): unknown field "app_name" in io.k8s.api.core.v1.ConfigMap, ValidationError(ConfigMap): unknown field "app_version" in io.k8s.api.core.v1.ConfigMap]
helm.go:76: [debug] error validating "": error validating data: [ValidationError(ConfigMap): unknown field "app_name" in io.k8s.api.core.v1.ConfigMap, ValidationError(ConfigMap): unknown field "app_version" in io.k8s.api.core.v1.ConfigMap]
[......]

# 新版本的 helm CLI 执行效果
➜ helm install --generate-name --dry-run --debug ./mychart
[......]
# Source: mychart/templates/configmap.yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mychart-1762008052-configmap
  labels:
    app_name: mychart
app_version: "0.1.0"
data:
  myvalue: "Hello World"
  drink: "coffee"
  food: "pizza"
app_name: mychart
app_version: "0.1.0"
```

<font style="color:rgb(28, 30, 33);">因为 </font>`<font style="color:#DF2A3F;">template</font>`<font style="color:rgb(28, 30, 33);"> 只是一个动作，而不是一个函数，所以无法将模板调用的输出传递给其他函数，只是内联插入，相当于渲染的结果是这样的：</font>

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: measly-whippet-configmap
  labels:
    app_name: mychart
app_version: "0.1.0+1478129847"
data:
  myvalue: "Hello World"
  drink: "coffee"
  food: "pizza"
  app_name: mychart
app_version: "0.1.0+1478129847"
```

<font style="color:rgb(28, 30, 33);">很明显上面的 YAML 文件是不符合 ConfigMap 资源对象的格式要求的，所以报错了。为解决这个问题，</font><u><font style="color:rgb(28, 30, 33);">Helm 提供了代替 </font></u>`<u><font style="color:#DF2A3F;">template</font></u>`<u><font style="color:rgb(28, 30, 33);"> 的函数 </font></u>`<u><font style="color:#DF2A3F;">include</font></u>`<u><font style="color:rgb(28, 30, 33);">，可以将模板的内容导入到当前的管道中，这样就可以在管道中传递给其他函数进行处理了</font></u><font style="color:rgb(28, 30, 33);">，如下所示：</font>

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
  labels:
{{ include "mychart.app" . | indent 4 }}
data:
  myvalue: "Hello World"
  {{- range $key, $val := .Values.favorite }}
  {{ $key }}: {{ $val | quote }}
  {{- end }}
{{ include "mychart.app" . | indent 2 }}
```

<font style="color:rgb(28, 30, 33);">现在我们重新渲染就可以得到正确的结果了，这是因为我们用 </font>`<font style="color:#DF2A3F;">include</font>`<font style="color:rgb(28, 30, 33);"> 函数得到模板内容后通过管道传给了后面的 </font>`<font style="color:#DF2A3F;">indent</font>`<font style="color:rgb(28, 30, 33);"> 函数来保证了缩进：</font>

```yaml
Source: mychart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mychart-1576036671-configmap
  labels:
    app_name: mychart
    app_version: "0.1.0"
data:
  myvalue: "Hello World"
  drink: "coffee"
  food: "pizza"
  app_name: mychart
  app_version: "0.1.0"
```

:::success
建议

在 Helm 模板中最好使用 `<font style="color:#DF2A3F;">include</font>` 而不是 `<font style="color:#DF2A3F;">template</font>`，这样可以更好地处理 YAML 文档的输出格式。

<font style="color:rgb(28, 30, 33);">有时候如果我们只想导入内容而不是模板，这个时候我们可以通过下面描述的 </font>`<font style="color:#DF2A3F;">.Files</font>`<font style="color:rgb(28, 30, 33);"> 对象来访问文件实现。</font>

:::

