<font style="color:rgb(28, 30, 33);">现在我们已经了解了如何将信息加入到模板中，但是这些信息都是直接原样的放置过去的，有时候，我们希望以一种对我们更有用的方式来转换提供的数据。</font>

<font style="color:rgb(28, 30, 33);">下面让我们从一个最佳实践开始：将 </font>`<font style="color:#DF2A3F;">.Values</font>`<font style="color:rgb(28, 30, 33);"> 对象中的字符串注入模板时，我们应该引用这些字符串，我们可以通过在 template 指令中调用 </font>`<font style="color:#DF2A3F;">quote</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">函数来实现，比如：</font>

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  drink: {{ quote .Values.favorite.drink }}
  food: {{ quote .Values.favorite.food }}
```

<font style="color:rgb(28, 30, 33);">模板函数遵循的语法规则是 </font>`<font style="color:#DF2A3F;">functionName arg1 arg2...</font>`<font style="color:rgb(28, 30, 33);">，在上面的代码片段中，</font>`<font style="color:#DF2A3F;">quote .Values.favorite.drink</font>`<font style="color:rgb(28, 30, 33);"> 会调用 </font>`<font style="color:#DF2A3F;">quote</font>`<font style="color:rgb(28, 30, 33);"> 函数并传递一个单个参数。</font>

<font style="color:rgb(28, 30, 33);">Helm 有60多种可用的函数，其中一些是由</font><font style="color:rgb(28, 30, 33);"> </font>[<font style="color:rgb(28, 30, 33);">Go 模板语言</font>](https://godoc.org/text/template)<font style="color:rgb(28, 30, 33);">本身定义的，其他大多数都是</font><font style="color:rgb(28, 30, 33);"> </font>[<font style="color:rgb(28, 30, 33);">Sprig 模板库</font>](https://masterminds.github.io/sprig/)<font style="color:rgb(28, 30, 33);">提供的，接下来我们会通过部分示例来逐步介绍其中的一些功能函数。</font>

Helm 模板

当我们谈论 `<font style="color:#DF2A3F;">Helm 模板语言</font>` 的时候，就好像是特定于 Helm 一样，但实际上它是 Go 模板语言加上一些额外的函数以及各种封装程序的组合，以将某些对象暴露给模板。当我们需要学习模板的时候，Go 模板上有许多资源会对我们有所帮助的。

## <font style="color:rgb(28, 30, 33);">1 管道</font>
<font style="color:rgb(28, 30, 33);">模板语言有一个强大的功能就是</font>**<font style="color:#DF2A3F;">管道（Pipeline）</font>**<font style="color:rgb(28, 30, 33);">概念，管道利用 UNIX 的概念，将一系列模板命令链接在一起，一起对外提供服务，换句话说，管道是按顺序完成多项工作的有效方式，我们来使用管道重写上面的示例模板：</font>

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  drink: {{ .Values.favorite.drink | quote }}
  food: {{ .Values.favorite.food | quote }}
```

<font style="color:rgb(28, 30, 33);">在这里我们没有调用 </font>`<font style="color:#DF2A3F;">quote ARGUMENT</font>`<font style="color:rgb(28, 30, 33);"> 函数，而是颠倒了下顺序，我们使用管道符（</font>`<font style="color:#DF2A3F;">|</font>`<font style="color:rgb(28, 30, 33);">）将参数</font>**<font style="color:rgb(28, 30, 33);">发送</font>**<font style="color:rgb(28, 30, 33);">给函数：</font>`<font style="color:#DF2A3F;">.Values.favorite.drink | quote</font>`<font style="color:rgb(28, 30, 33);">，使用管道，我们可以将多个功能链接在一起：</font>

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  drink: {{ .Values.favorite.drink | quote }}
  food: {{ .Values.favorite.food | upper | quote }}
```

:::success
💡<font style="color:rgb(28, 30, 33);">info "管道顺序"</font>

<font style="color:rgb(28, 30, 33);">反转顺序是模板中常见的做法，我们会看到 </font>`<font style="color:#DF2A3F;">`.val | quote`(使用较多)</font>`<font style="color:rgb(28, 30, 33);"> 比 </font>`<font style="color:#DF2A3F;">`quote .val`</font>`<font style="color:rgb(28, 30, 33);"> 用法更多，虽然两种方法都是可以的。</font>

:::

<font style="color:rgb(28, 30, 33);">最后，模板渲染后，会产生如下所示的结果：</font>

```shell
➜ helm install --generate-name --dry-run --debug ./mychart
install.go:214: [debug] Original chart version: ""
install.go:231: [debug] CHART PATH: /root/georgezhong/CloudNative/Learning/k8slearn/8.Kubernetes Helm/8.3.模版开发/Manifest/mychart

NAME: mychart-1761994110
LAST DEPLOYED: Sat Nov  1 18:48:30 2025
NAMESPACE: default
STATUS: pending-install
REVISION: 1
TEST SUITE: None
USER-SUPPLIED VALUES:
{}

COMPUTED VALUES:
favorite:
  drink: coffee
  food: pizza

HOOKS:
MANIFEST:
---
# Source: mychart/templates/configmap.yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mychart-1761994110-configmap
data:
  myvalue: "Hello World"
  drink: "coffee"
  food: "PIZZA"
```

<font style="color:rgb(28, 30, 33);">我们可以看到 values 中的 </font>`<font style="color:#DF2A3F;">pizza</font>`<font style="color:rgb(28, 30, 33);"> 值已经被转换成了 </font>`<font style="color:#DF2A3F;">"PIZZA"</font>`<font style="color:rgb(28, 30, 33);">。当这样传递参数的时候，第一个求值结果（</font>`<font style="color:#DF2A3F;">.Values.favorite.drink</font>`<font style="color:rgb(28, 30, 33);">）会作为一个参数发送给函数，我们可以修改上面的 </font>`<font style="color:#DF2A3F;">drink</font>`<font style="color:rgb(28, 30, 33);"> 示例，用一个带有两个参数的函数进行说明：</font>`<font style="color:#DF2A3F;">repeat COUNT STRING</font>`<font style="color:rgb(28, 30, 33);">。</font>

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  drink: {{ .Values.favorite.drink | repeat 5 | quote }}
  food: {{ .Values.favorite.food | upper | quote }}
```

`<font style="color:#DF2A3F;">repeat</font>`<font style="color:rgb(28, 30, 33);"> 函数将重复字符串给定的次数，渲染后我们可以得到如下的输出结果：</font>

```yaml
# Source: mychart/templates/configmap.yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mychart-1761994179-configmap
data:
  myvalue: "Hello World"
  drink: "coffeecoffeecoffeecoffeecoffee"
  food: "PIZZA"
```

## 2 `<font style="color:#DF2A3F;">default</font>`<font style="color:rgb(28, 30, 33);"> 函数</font>
<font style="color:rgb(28, 30, 33);">在模板中经常会使用到的一个函数是 </font>`<font style="color:#DF2A3F;">default</font>`<font style="color:rgb(28, 30, 33);"> 函数：</font>`<font style="color:#DF2A3F;">default DEFAULT_VALUE GIVEN_VALUE</font>`<font style="color:rgb(28, 30, 33);">，该函数允许你在模板内部指定默认值，我们来修改上面示例中的模板：</font>

```yaml
food: {{ .Values.favorite.food | default "rice" | upper | quote }}
```

<font style="color:rgb(28, 30, 33);">正常运行，我们还是可以得到 </font>`<font style="color:#DF2A3F;">values.yaml</font>`<font style="color:rgb(28, 30, 33);"> 文件中定义的 </font>`<font style="color:rgb(28, 30, 33);">pizza</font>`<font style="color:rgb(28, 30, 33);">：</font>

```yaml
# Source: mychart/templates/configmap.yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mychart-1761994204-configmap
data:
  myvalue: "Hello World"
  drink: "coffeecoffeecoffeecoffeecoffee"
  food: "PIZZA"
```

<font style="color:rgb(28, 30, 33);">现在我们从 </font>`<font style="color:#DF2A3F;">values.yaml</font>`<font style="color:rgb(28, 30, 33);"> 文件中移除 food 的定义：</font>

```yaml
favorite:
  drink: coffee
  # food: pizza
```

<font style="color:rgb(28, 30, 33);">现在我们重新运行 </font>`<font style="color:#DF2A3F;">helm install --generate-name --dry-run --debug ./mychart</font>`<font style="color:rgb(28, 30, 33);"> 将渲染成如下的 YAML 文件：</font>

```yaml
# Source: mychart/templates/configmap.yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mychart-1761994218-configmap
data:
  myvalue: "Hello World"
  drink: "coffeecoffeecoffeecoffeecoffee"
  food: "RICE"
```

<font style="color:rgb(28, 30, 33);">在</font><u><font style="color:rgb(28, 30, 33);">一个真实的 chart 模板中，所有的静态默认值都应位于 </font></u>`<u><font style="color:#DF2A3F;">values.yaml</font></u>`<u><font style="color:rgb(28, 30, 33);"> 文件中</font></u><font style="color:rgb(28, 30, 33);">，并且不应该重复使用 </font>`<font style="color:#DF2A3F;">default</font>`<font style="color:rgb(28, 30, 33);"> 函数，</font><u><font style="color:rgb(28, 30, 33);">但是，默认命令非常适合计算不能在 </font></u>`<u><font style="color:#DF2A3F;">values.yaml</font></u>`<u><font style="color:rgb(28, 30, 33);"> 文件中声明的 values 值</font></u><font style="color:rgb(28, 30, 33);">，例如：</font>

```yaml
food: {{ .Values.favorite.food | default (printf "%s-rice" (include "fullname" .)) }}
```

<font style="color:rgb(28, 30, 33);">不过在有些地方，</font>`<u><font style="color:#DF2A3F;">if</font></u>`<u><font style="color:rgb(28, 30, 33);"> 条件语句可能比 </font></u>`<u><font style="color:#DF2A3F;">default</font></u>`<u><font style="color:rgb(28, 30, 33);"> 函数更合适</font></u><font style="color:rgb(28, 30, 33);">，我们会在后面了解到。</font>

<font style="color:rgb(28, 30, 33);">模板函数和管道是将数据转换后然后将其插入到 YAML 文件中的一种强大方法，但是有的时候有必要添加一些模板逻辑，这些逻辑比仅仅插入字符串要复杂得多，下面我们将来了解模板语言中提供的控制流程。</font>

## <font style="color:rgb(28, 30, 33);">3 运算符函数</font>
<font style="color:rgb(28, 30, 33);">另外需要注意的是在模板中，运算符（eq、ne、lt、gt、and、or 等等）均实现为函数，在管道中，运算符可以用括号</font>`<font style="color:#DF2A3F;">()</font>`<font style="color:rgb(28, 30, 33);">进行分割。</font>

<font style="color:rgb(28, 30, 33);">接下来我们可以去了解控制流程条件语句、循环和作用域修饰符的使用。</font>

