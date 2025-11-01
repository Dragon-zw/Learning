<font style="color:rgb(28, 30, 33);">有了函数、管道、对象以及控制结构，我们可以想象下大多数编程语言中更基本的思想之一：</font>`<font style="color:#DF2A3F;">变量</font>`<font style="color:rgb(28, 30, 33);">。在模板中，变量的使用频率较低，但是，我们还是可以使用他们来简化代码，以及更好地使用 </font>`<font style="color:#DF2A3F;">with</font>`<font style="color:rgb(28, 30, 33);"> 和 </font>`<font style="color:#DF2A3F;">range</font>`<font style="color:rgb(28, 30, 33);">。</font>

<font style="color:rgb(28, 30, 33);">在前面的示例中，我们知道下面的模板渲染会出错：</font>

```yaml
{{- with .Values.favorite }}
drink: {{ .drink | default "tea" | quote }}
food: {{ .food | upper | quote }}
release: {{ .Release.Name }}
{{- end }}
```

<u><font style="color:rgb(28, 30, 33);">因为 </font></u>`<u><font style="color:#DF2A3F;">Release.Name</font></u>`<u><font style="color:rgb(28, 30, 33);"> 不在 </font></u>`<u><font style="color:#DF2A3F;">with</font></u>`<u><font style="color:rgb(28, 30, 33);"> 语句块限制的范围之内，解决作用域问题的一种方法是将对象分配给在不考虑当前作用域情况下访问的变量。</font></u>

## 1 变量定义
<font style="color:rgb(28, 30, 33);">在 Helm 模板中，变量是对另外一个对象的命名引用。它遵循 </font>`<font style="color:#DF2A3F;">$name</font>`<font style="color:rgb(28, 30, 33);"> 格式，变量使用特殊的赋值运算符进行赋值 </font>`<font style="color:#DF2A3F;">:=</font>`<font style="color:rgb(28, 30, 33);">，我们可以修改上面的模板，为 </font>`<font style="color:#DF2A3F;">Release.Name</font>`<font style="color:rgb(28, 30, 33);"> 声明一个变量：</font>

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  {{- $relname := .Release.Name -}}
  {{- with .Values.favorite }}
  drink: {{ .drink | default "tea" | quote }}
  food: {{ .food | upper | quote }}
  release: {{ $relname }}
  {{- end }}
```

<font style="color:rgb(28, 30, 33);">注意在 </font>`<font style="color:#DF2A3F;">with</font>`<font style="color:rgb(28, 30, 33);"> 语句之前，我们先分配了 </font>`<font style="color:#DF2A3F;">$relname := .Release.Name</font>`<font style="color:rgb(28, 30, 33);">，然后在 </font>`<font style="color:#DF2A3F;">with</font>`<font style="color:rgb(28, 30, 33);"> 语句块中，</font>`<font style="color:#DF2A3F;">$relname</font>`<font style="color:rgb(28, 30, 33);"> 变量仍然表示 release 的名称，我们渲染该模板，可以得到如下的正确结果：</font>

```yaml
$ helm install --generate-name --dry-run --debug ./mychart
[......]
# Source: mychart/templates/configmap.yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mychart-1762006696-configmap
data:
  myvalue: "Hello World"
  drink: "coffee"
  food: "PIZZA"
  release: mychart-1762006696
```

<font style="color:rgb(28, 30, 33);">变量在 </font>`<font style="color:#DF2A3F;">range</font>`<font style="color:rgb(28, 30, 33);"> 循环里面非常有用，它们可以用于类似于列表的对象来捕获索引和 value 值：</font>

```yaml
toppings: |-
  {{- range $index, $topping := .Values.pizzaToppings }}
    {{ $index }}: {{ $topping }}
  {{- end }}
```

<font style="color:rgb(28, 30, 33);">注意 </font>`<font style="color:#DF2A3F;">range</font>`<font style="color:rgb(28, 30, 33);"> 在前面，然后是变量，然后是赋值运算符，然后才是列表，这会将整数索引（从0开始）分配给 </font>`<font style="color:#DF2A3F;">$index</font>`<font style="color:rgb(28, 30, 33);">，并将 value 值分配给 </font>`<font style="color:#DF2A3F;">$topping</font>`<font style="color:rgb(28, 30, 33);">，上面的内容会被渲染成如下内容：</font>

```yaml
toppings: |-
  0: mushrooms
  1: cheese
  2: peppers
  3: onions
```

<font style="color:rgb(28, 30, 33);">对于同时具有 key 和 value 的数据结构，我们也可以使用 </font>`<font style="color:#DF2A3F;">range</font>`<font style="color:rgb(28, 30, 33);"> 来获得 key、value 的值（跟 Golang 的语法是一样的！），比如，我们可以像这样循环遍历 </font>`<font style="color:#DF2A3F;">.Values.favorite</font>`<font style="color:rgb(28, 30, 33);">：</font>

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  {{- range $key, $val := .Values.favorite }}
  {{ $key }}: {{ $val | quote }}
  {{- end }}
```

<font style="color:rgb(28, 30, 33);">在第一次迭代中，</font>`<font style="color:#DF2A3F;">$key</font>`<font style="color:rgb(28, 30, 33);"> 是 </font>`<font style="color:#DF2A3F;">drink</font>`<font style="color:rgb(28, 30, 33);">，</font>`<font style="color:#DF2A3F;">$val</font>`<font style="color:rgb(28, 30, 33);"> 是 </font>`<font style="color:#DF2A3F;">coffee</font>`<font style="color:rgb(28, 30, 33);">，在第二次迭代中，</font>`<font style="color:#DF2A3F;">$key</font>`<font style="color:rgb(28, 30, 33);"> 是 </font>`<font style="color:#DF2A3F;">food</font>`<font style="color:rgb(28, 30, 33);">，</font>`<font style="color:#DF2A3F;">$val</font>`<font style="color:rgb(28, 30, 33);"> 是 </font>`<font style="color:#DF2A3F;">pizza</font>`<font style="color:rgb(28, 30, 33);">。运行上面的命令将生成下面的内容：</font>

```yaml
$ helm install --generate-name --dry-run --debug ./mychart
[......]
# Source: mychart/templates/configmap.yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mychart-1762006771-configmap
data:
  myvalue: "Hello World"
  drink: "coffee"
  food: "pizza"
```

<font style="color:rgb(28, 30, 33);">一般来说变量不是全局的，它们的作用域是声明它们的块区域，之前，我们在模板的顶层分配了 </font>`<font style="color:#DF2A3F;">$relname</font>`<font style="color:rgb(28, 30, 33);">，该变量将在整个模板的范围内，但是在我们上面的示例中，</font>`<font style="color:#DF2A3F;">$key</font>`<font style="color:rgb(28, 30, 33);"> 和 </font>`<font style="color:#DF2A3F;">$val</font>`<font style="color:rgb(28, 30, 33);"> 作用域只在 </font>`<font style="color:#DF2A3F;">{{ range... }}{{ end }}</font>`<font style="color:rgb(28, 30, 33);"> 区域内。</font>

## 2 全局变量
<font style="color:rgb(28, 30, 33);">但是，有一个始终是全局变量的 </font>`<font style="color:#DF2A3F;">$</font>`<font style="color:rgb(28, 30, 33);"> 始终指向顶层根上下文，当我们在 </font>`<font style="color:#DF2A3F;">range</font>`<font style="color:rgb(28, 30, 33);"> 循环内需要知道 chart 包的 release 名称的时候，该功能就非常有用了，比如下面的模板文件：</font>

```yaml
{{- range .Values.tlsSecrets }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ .name }}
  labels:
    # helm 模板经常使用 `.`，但是这里是无效的，用 `$` 是可以生效的。
    app.kubernetes.io/name: {{ template "fullname" $ }}
    # 这里不能引用 `.Chart.Name`，但是可用使用 `$.Chart.Name`
    helm.sh/chart: "{{ $.Chart.Name }}-{{ $.Chart.Version }}"
    app.kubernetes.io/instance: "{{ $.Release.Name }}"
    # 值来自于 Chart.yaml 文件中的 appVersion
    app.kubernetes.io/version: "{{ $.Chart.AppVersion }}"
    app.kubernetes.io/managed-by: "{{ $.Release.Service }}"
type: kubernetes.io/tls
data:
  tls.crt: {{ .certificate }}
  tls.key: {{ .key }}
---
{{- end }}
```

<font style="color:rgb(28, 30, 33);">到现在为止，我们只研究了在一个文件中声明的一个模板，但是，Helm 模板语言的强大功能之一是它能够声明多个模板并将其一起使用。我们将在下面的章节中来讨论这一点。</font>

