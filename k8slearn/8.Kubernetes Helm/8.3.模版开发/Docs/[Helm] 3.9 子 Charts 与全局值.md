到现在为止，我们从单一模板，到多个模板文件，但是都仅仅是处理的一个 chart 包，但是 charts 可能具有一些依赖项，我们称为 `<font style="color:#DF2A3F;">subcharts（子 chart）</font>`，接下来我们将创建一个子 chart。

同样在深入了解之前，我们需要了解下子 chart 相关的一些信息。

+ 子 chart 是**<font style="color:#DF2A3F;">独立</font>**的，这意味着子 chart 不能显示依赖其父 chart
+ 所以子 chart 无法访问其父级的值
+ 父 chart 可以覆盖子 chart 的值
+ Helm 中有可以被所有 charts 访问的全局值的概念

## 1 创建子chart
同样还是在之前操作的 `<font style="color:#DF2A3F;">mychart/</font>` 这个 chart 包中，我们来尝试添加一些新的子 chart：

```shell
➜ cd mychart/charts
➜ helm create mysubchart
Creating mysubchart
➜ rm -rf mysubchart/templates/*.* && rm -rf mysubchart/templates/test
```

和前面一样，我们删除了所有的基本模板，这样我们可以从头开始。

## 2 添加 values 和 模板
接下来我们为 mysubchart 这个子 chart 创建一个简单的模板和 values 值文件，`<font style="color:#DF2A3F;">mychart/charts/mysubchart</font>` 中已经有一个 `<font style="color:#DF2A3F;">values.yaml</font>` 文件了，在文件中添加下面的 values：

```yaml
dessert: cake
```

下面我们再创建一个新的 ConfigMap 模板 `<font style="color:#DF2A3F;">mychart/charts/mysubchart/templates/configmap.yaml</font>`：

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-cfgmap2
data:
  dessert: {{ .Values.dessert }}
```

因为每个子 chart 都是独立的 chart，所以我们可以单独测试 `<font style="color:#DF2A3F;">mysubchart</font>`：

```shell
# 模拟运行
➜ helm install --generate-name --dry-run --debug mychart/charts/mysubchart
install.go:214: [debug] Original chart version: ""
install.go:231: [debug] CHART PATH: /root/georgezhong/CloudNative/Learning/k8slearn/8.Kubernetes Helm/8.3.模版开发/Manifest/mychart/charts/mysubchart

NAME: mysubchart-1762012454
LAST DEPLOYED: Sat Nov  1 23:54:14 2025
NAMESPACE: default
STATUS: pending-install
REVISION: 1
TEST SUITE: None
USER-SUPPLIED VALUES:
{}

COMPUTED VALUES:
dessert: cake

HOOKS:
MANIFEST:
---
# Source: mysubchart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysubchart-1762012454-cfgmap2
data:
  dessert: cake
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1762012468683-22794b44-4e9c-4c6e-a9fc-dd0f8b65c052.png)

## 3 从父 chart 覆盖 values
我们原来的 chart - mychart 现在是 mysubchart 的父级 chart 了。由于 mychart 是父级，所以我们可以在 mychart 中指定配置，并将该配置发送到 mysubchart 中去，比如，我们可以这样修改 `<font style="color:#DF2A3F;">mychart/values.yaml</font>`：

```yaml
favorite:
  drink: coffee
  food: pizza
  
pizzaToppings:
  - mushrooms
  - cheese
  - peppers
  - onions

mysubchart:
  dessert: ice cream
```

最后两行，`<font style="color:#DF2A3F;">mysubchart</font>` 部分中的所有指令都回被发送到 `<font style="color:#DF2A3F;">mysubchart</font>` 子 chart 中，所以，如果我们现在渲染模板，我们可以看到 `<font style="color:#DF2A3F;">mysubchart</font>` 的 ConfigMap 会被渲染成如下的内容：

```yaml
$ helm install --generate-name --dry-run --debug mychart
[......]
# Source: mychart/charts/mysubchart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mychart-1762012547-cfgmap2
data:
  dessert: ice cream
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1762012588100-9265d048-f124-41a0-9c12-8284079887bb.png)

我们可以看到顶层的 values 值覆盖了子 chart 中的值。这里有一个细节需要注意，我们没有将 `<font style="color:#DF2A3F;">mychart/charts/mysubchart/templates/configmap.yaml</font>` 模板更改为指向 `<font style="color:#DF2A3F;">.Values.mysubchart.dessert</font>`，因为从该模板的绝度来看，该值仍然位于 `<font style="color:#DF2A3F;">.Values.dessert</font>`，当模板引擎传递 values 值的时候，它会设置这个作用域，所以，对于 `<font style="color:#DF2A3F;">mysubchart</font>` 模板，`<font style="color:#DF2A3F;">.Values</font>` 中仅仅提供用于该子 chart 的值。

但是有时候如果我们确实希望某些值可以用于所有模板，这个时候就可以使用全局 chart values 值来完成了。

## 4 全局值
全局值是可以从任何 chart 或子 chart 中都可以访问的值，全局值需要显示的声明，不能将现有的非全局对象当作全局对象使用。

Values 数据类型具有一个名为 `<font style="color:#DF2A3F;">Values.global</font>` 的保留部分，可以在其中设置全局值，我们在 `<font style="color:#DF2A3F;">mychart/values.yaml</font>` 文件中添加一个全局值：

```yaml
favorite:
  drink: coffee
  food: pizza
  
pizzaToppings:
  - mushrooms
  - cheese
  - peppers
  - onions

mysubchart:
  dessert: ice cream

global:
  salad: caesar
```

由于全局值的原因，在 `<font style="color:#DF2A3F;">mychart/templates/configmap.yaml</font>` 和 `<font style="color:#DF2A3F;">mysubchart/templates/configmap.yaml</font>` 下面都应该可以以 `<font style="color:#DF2A3F;">{{ .Values.global.salad }}</font>` 的形式来访问这个值。

+ `<font style="color:#DF2A3F;">mychart/templates/configmap.yaml</font>`：

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  salad: {{ .Values.global.salad }}
```

+ `<font style="color:#DF2A3F;">mysubchart/templates/configmap.yaml</font>`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-cfgmap2
data:
  dessert: {{ .Values.dessert }}
  salad: {{ .Values.global.salad }}
```

然后我们渲染这个模板，可以得到如下所示的内容：

```yaml
$ helm install --generate-name --dry-run --debug mychart
---
# Source: mychart/charts/mysubchart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mychart-1762012678-cfgmap2
data:
  dessert: ice cream
  salad: caesar
---
# Source: mychart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mychart-1762012678-configmap
data:
  salad: caesar
```

全局值对于传递这样的数据比较有用。

## 5 共享模板
父级 Chart 和子 Chart 可以共享模板，任何 Chart 中已定义的块都可以用于其他 Chart。比如，我们可以定义一个简单的模板，如下所示：

```yaml
{{- define "labels" }}from: mychart{{ end }}
```

前面我们提到过可以使用在模板中使用 `<font style="color:#DF2A3F;">include</font>` 和 `<font style="color:#DF2A3F;">template</font>`，但是使用 `<font style="color:#DF2A3F;">include</font>` 的一个优点是可以动态引入模板的内容：

```yaml
{{ include $mytemplate }}
```

