<font style="color:rgb(28, 30, 33);">前面我们介绍了 Helm 模板提供的内置对象，其中就有一个内置对象 </font>`<font style="color:#DF2A3F;">Values</font>`<font style="color:rgb(28, 30, 33);">，该对象提供对传递到 chart 中的 values 值的访问，其内容主要有4个来源：</font>

+ <font style="color:rgb(28, 30, 33);">chart 文件中的 </font>`<font style="color:#DF2A3F;">values.yaml</font>`<font style="color:rgb(28, 30, 33);"> 文件</font>
+ <font style="color:rgb(28, 30, 33);">如果这是子 chart，父 chart 的 </font>`<font style="color:#DF2A3F;">values.yaml</font>`<font style="color:rgb(28, 30, 33);"> 文件</font>
+ <font style="color:rgb(28, 30, 33);">用 </font>`<font style="color:#DF2A3F;">-f</font>`<font style="color:rgb(28, 30, 33);"> 参数传递给 </font>`<font style="color:#DF2A3F;">helm install</font>`<font style="color:rgb(28, 30, 33);"> 或 </font>`<font style="color:#DF2A3F;">helm upgrade</font>`<font style="color:rgb(28, 30, 33);"> 的 values 值文件（例如 </font>`<font style="color:#DF2A3F;">helm install -f myvals.yaml ./mychart</font>`<font style="color:rgb(28, 30, 33);">）</font>
+ <font style="color:rgb(28, 30, 33);">用 </font>`<font style="color:#DF2A3F;">--set</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">传递的各个参数（例如 </font>`<font style="color:#DF2A3F;">helm install --set foo=bar ./mychart</font>`<font style="color:rgb(28, 30, 33);">）</font>

`<font style="color:#DF2A3F;">values.yaml</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">文件是默认值，可以被父 chart 的 </font>`<font style="color:#DF2A3F;">values.yaml</font>`<font style="color:rgb(28, 30, 33);"> 文件覆盖，而后者又可以由用户提供的 values 值文件覆盖，而该文件又可以被 </font>`<font style="color:#DF2A3F;">--set</font>`<font style="color:rgb(28, 30, 33);"> 参数覆盖。</font>

## <font style="color:rgb(28, 30, 33);">1 配置 Values</font>
```shell
➜ helm create mychart
```

<font style="color:rgb(28, 30, 33);">values 值文件是纯 YAML 文件，我们可以来编辑 </font>`<font style="color:#DF2A3F;">mychart/values.yaml</font>`<font style="color:rgb(28, 30, 33);"> 文件然后编辑 </font>`<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:rgb(28, 30, 33);"> 模板。删除 </font>`<font style="color:#DF2A3F;">values.yaml</font>`<font style="color:rgb(28, 30, 33);"> 中的默认设置后，我们将只设置一个参数：</font>

```yaml
favoriteDrink: coffee
```

<font style="color:rgb(28, 30, 33);">现在我们可以在模板中直接使用它：</font>

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  drink: {{ .Values.favoriteDrink }}
```

<font style="color:rgb(28, 30, 33);">可以看到在最后一行我们将 </font>`<font style="color:#DF2A3F;">favoriteDrink</font>`<font style="color:rgb(28, 30, 33);"> 作为 </font>`<font style="color:#DF2A3F;">Values</font>`<font style="color:rgb(28, 30, 33);"> 的属性进行访问：</font>`<font style="color:#DF2A3F;">{{ .Values.favoriteDrink }}</font>`<font style="color:rgb(28, 30, 33);">。我们可以来看看是如何渲染的：</font>

```shell
# --dry-run：模拟运行
➜ helm install --generate-name --dry-run --debug ./mychart
install.go:148: [debug] Original chart version: ""
install.go:165: [debug] CHART PATH: /Users/ych/devs/workspace/yidianzhishi/course/k8strain/content/helm/manifests/mychart

NAME: mychart-1575963545
LAST DEPLOYED: Tue Dec 10 15:39:06 2019
NAMESPACE: default
STATUS: pending-install
REVISION: 1
TEST SUITE: None
USER-SUPPLIED VALUES:
{}

COMPUTED VALUES:
favoriteDrink: coffee

HOOKS:
MANIFEST:
---
# Source: mychart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mychart-1575963545-configmap
data:
  myvalue: "Hello World"
  drink: coffee
```

<font style="color:rgb(28, 30, 33);">由于在默认的 </font>`<font style="color:#DF2A3F;">values.yaml</font>`<font style="color:rgb(28, 30, 33);"> 文件中将 favoriteDrink 设置为了 coffee，所以这就是模板中显示的值，我们可以通过在调用 </font>`<font style="color:#DF2A3F;">helm install</font>`<font style="color:rgb(28, 30, 33);"> 的过程中添加 </font>`<font style="color:#DF2A3F;">--set</font>`<font style="color:rgb(28, 30, 33);"> 参数来覆盖它：</font>

```shell
➜ helm install --generate-name --dry-run --debug --set favoriteDrink=slurm ./mychart
install.go:148: [debug] Original chart version: ""
install.go:165: [debug] CHART PATH: /Users/ych/devs/workspace/yidianzhishi/course/k8strain/content/helm/manifests/mychart

NAME: mychart-1575963760
LAST DEPLOYED: Tue Dec 10 15:42:43 2019
NAMESPACE: default
STATUS: pending-install
REVISION: 1
TEST SUITE: None
USER-SUPPLIED VALUES:
favoriteDrink: slurm

COMPUTED VALUES:
favoriteDrink: slurm

HOOKS:
MANIFEST:
---
# Source: mychart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mychart-1575963760-configmap
data:
  myvalue: "Hello World"
  drink: slurm
```

<font style="color:rgb(28, 30, 33);">因为 </font>`<font style="color:#DF2A3F;">--set</font>`<font style="color:rgb(28, 30, 33);"> 的优先级高于默认的 </font>`<font style="color:#DF2A3F;">values.yaml</font>`<font style="color:rgb(28, 30, 33);"> 文件，所以我们的模板会生成 </font>`<font style="color:#DF2A3F;">drink: slurm</font>`<font style="color:rgb(28, 30, 33);">。Values 值文件也可以包含更多结构化的内容，例如我们可以在 </font>`<font style="color:#DF2A3F;">values.yaml</font>`<font style="color:rgb(28, 30, 33);"> 文件中创建一个 favorite 的部分，然后在其中添加几个 keys：</font>

```yaml
favorite:
  drink: coffee
  food: pizza
```

<font style="color:rgb(28, 30, 33);">现在我们再去修改下我们的模板：</font>

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  drink: {{ .Values.favorite.drink }}
  food: {{ .Values.favorite.food }}
```

<font style="color:rgb(28, 30, 33);">虽然我们可以通过这种方式来构造数据，但是还是建议你将 values 树保持更浅，这样在使用的时候更加简单。当我们考虑为子 chart 分配 values 值的时候，我们就可以看到如何使用树形结构来命名 values 值了。</font>

## <font style="color:rgb(28, 30, 33);">2 删除默认 KEY</font>
<font style="color:rgb(28, 30, 33);">如果你需要从默认值中删除 key，则可以将该 key 的值覆盖为 null，在这种情况下，Helm 将从覆盖的 values 中删除该 key。例如，在 Drupal chart 中配置一个 liveness 探针:</font>

```yaml
livenessProbe:
  httpGet:
    path: /user/login
    port: http
  initialDelaySeconds: 120
```

<font style="color:rgb(28, 30, 33);">如果你想使用 </font>`<font style="color:#DF2A3F;">--set livenessProbe.exec.command=[cat, docroot/CHANGELOG.txt]</font>`<font style="color:rgb(28, 30, 33);"> 将 livenessProbe 的处理程序覆盖为 </font>`<font style="color:#DF2A3F;">exec</font>`<font style="color:rgb(28, 30, 33);"> 而不是 </font>`<font style="color:#DF2A3F;">httpGet</font>`<font style="color:rgb(28, 30, 33);">，则 Helm 会将默认键和覆盖键合并在一起，如下所示：</font>

```yaml
livenessProbe:
  httpGet:
    path: /user/login
    port: http
  exec:
    command:
    - cat
    - docroot/CHANGELOG.txt
  initialDelaySeconds: 120
```

<font style="color:rgb(28, 30, 33);">但是，这样却有一个问题，因为你不能声明多个 livenessProbe 处理程序，为了解决这个问题，你可以让 Helm 通过将 </font>`<font style="color:#DF2A3F;">livenessProbe.httpGet</font>`<font style="color:rgb(28, 30, 33);"> 设置为 </font>`<font style="color:#DF2A3F;">null</font>`<font style="color:rgb(28, 30, 33);"> 来删除它：</font>

```shell
➜ helm install stable/drupal \
  --set image=my-registry/drupal:0.1.0 \
  --set livenessProbe.exec.command=[cat, docroot/CHANGELOG.txt] \
  --set livenessProbe.httpGet=null
```

<font style="color:rgb(28, 30, 33);">到这里我们已经了解到了几个内置对象，并利用它们将信息注入到了模板中，现在我们来看看模板引擎的另外方面：函数和管道。</font>

