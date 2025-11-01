<font style="color:rgb(28, 30, 33);">在上一节中我们介绍了几种创建和访问命名模板的方法，这使得从另一个模板中导入一个模板变得很容易，但是有时候需要导入一个不是模板的文件并注入其内容，而不通过模板渲染器获得内容。</font>

<font style="color:rgb(28, 30, 33);">Helm 提供了一个 </font>`<font style="color:#DF2A3F;">.Files</font>`<font style="color:rgb(28, 30, 33);"> 对象对文件的访问，但是在模板中使用这个对象之前，还有几个需要注意的事项值得一提：</font>

+ <font style="color:rgb(28, 30, 33);">可以在 Helm chart 中添加额外的文件，这些文件也会被打包，不过需要注意，由于 Kubernetes 对象的存储限制，Charts 必须小于 1M</font>
+ <font style="color:rgb(28, 30, 33);">由于一些安全原因，通过 </font>`<font style="color:#DF2A3F;">.Files</font>`<font style="color:rgb(28, 30, 33);"> 对象无法访问某些文件</font>
    - <font style="color:rgb(28, 30, 33);">无法访问 </font>`<font style="color:#DF2A3F;">templates/</font>`<font style="color:rgb(28, 30, 33);"> 下面的文件</font>
    - <font style="color:rgb(28, 30, 33);">无法访问使用 </font>`<font style="color:#DF2A3F;">.helmignore</font>`<font style="color:rgb(28, 30, 33);"> 排除的文件</font>
+ <font style="color:rgb(28, 30, 33);">Chart 不会保留 UNIX 模式的信息，所以，当使用 </font>`<font style="color:#DF2A3F;">.Files</font>`<font style="color:rgb(28, 30, 33);"> 对象时，文件级别的权限不会对文件的可用性产生影响。</font>

## <font style="color:rgb(28, 30, 33);">1 基本示例</font>
<font style="color:rgb(28, 30, 33);">现在我们来编写一个模板，将3个文件读入到 </font>`<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:rgb(28, 30, 33);"> 模板中，首先我们在 chart 中添加3个文件，将3个文件都直接放置在 </font>`<font style="color:#DF2A3F;">mychart/</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">目录中。</font>

`<font style="color:#DF2A3F;">config1.toml</font>`<font style="color:rgb(28, 30, 33);">:</font>

```plain
message = Hello from config 1
```

`<font style="color:#DF2A3F;">config2.toml</font>`<font style="color:rgb(28, 30, 33);">:</font>

```plain
message = This is config 2
```

`<font style="color:#DF2A3F;">config3.toml</font>`<font style="color:rgb(28, 30, 33);">:</font>

```plain
message = Goodbye from config 3
```

<font style="color:rgb(28, 30, 33);">3 个文件都是简单的 TOML 文件，我们知道这些文件的名称，所以我们可以使用 </font>`<font style="color:#DF2A3F;">range</font>`<font style="color:rgb(28, 30, 33);"> 函数来遍历它们，并将其内容注入到 </font>`<font style="color:#DF2A3F;">ConfigMap</font>`<font style="color:rgb(28, 30, 33);"> 中去。</font>

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  {{- $files := .Files }}
  {{- range tuple "config1.toml" "config2.toml" "config3.toml" }}
  {{ . }}: |-
    {{ $files.Get . }}
  {{- end }}
```

<font style="color:rgb(28, 30, 33);">这里我们</font><u><font style="color:rgb(28, 30, 33);">声明了一个 </font></u>`<u><font style="color:#DF2A3F;">$files</font></u>`<u><font style="color:rgb(28, 30, 33);"> 的变量来保存 </font></u>`<u><font style="color:#DF2A3F;">.Files</font></u>`<u><font style="color:rgb(28, 30, 33);"> 对象的引用，还使用了 </font></u>`<u><font style="color:#DF2A3F;">tuple</font></u>`<u><font style="color:rgb(28, 30, 33);"> 函数来循环文件列表</font></u><font style="color:rgb(28, 30, 33);">，然后我们打印每个文件夹 </font>`<font style="color:#DF2A3F;">{{ . }}: |-</font>`<font style="color:rgb(28, 30, 33);">，后面使用 </font>`<font style="color:#DF2A3F;">{{ $files.Get . }}</font>`<font style="color:rgb(28, 30, 33);"> 获取文件内容。</font>

<font style="color:rgb(28, 30, 33);">现在我们渲染这个模板会产生包含3个文件内容的单个 ConfigMap：</font>

```yaml
$ helm install --generate-name --dry-run --debug ./mychart
[......]
# Source: mychart/templates/configmap.yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mychart-1762011571-configmap
data:
  config1.toml: |-
    message = Hello from config 1
  config2.toml: |-
    message = This is config 2
  config3.toml: |-
    message = Goodbye from config 3
```

<font style="color:rgb(28, 30, 33);">另外在处理文件的时候，对文件路径本身执行一些标准操作可能非常有用，为了解决这个问题，Helm 从 Go 的路径包中导入了许多功能供你使用，它们都可以使用与 Go 包中相同的相同名称来访问，但是首字母需要小写，比如 Base 需要变成 base，导入的函数有：</font>`<font style="color:#DF2A3F;">- Base - Dir - Ext - IsAbs - Clean</font>`<font style="color:rgb(28, 30, 33);">。</font>

## <font style="color:rgb(28, 30, 33);">2 Glob 模式</font>
<font style="color:rgb(28, 30, 33);">随着 chart 的增长，你可能需要更多地组织文件，因此 Helm 提供了 </font>`<font style="color:#DF2A3F;">Files.Glob</font>`<font style="color:rgb(28, 30, 33);"> 的方法来帮助我们获取具有 </font>`<font style="color:#DF2A3F;">glob</font>`<font style="color:rgb(28, 30, 33);"> 模式的文件。</font>

`<font style="color:#DF2A3F;">.Glob</font>`<font style="color:rgb(28, 30, 33);"> 返回 </font>`<font style="color:#DF2A3F;">Files</font>`<font style="color:rgb(28, 30, 33);"> 类型，所以你可以在返回的对象上调用任何 </font>`<font style="color:#DF2A3F;">Files</font>`<font style="color:rgb(28, 30, 33);"> 方法。比如，我们的文件目录结构如下所示：</font>

```yaml
foo/:
  foo.txt foo.yaml

bar/:
  bar.go bar.conf baz.yaml
```

<font style="color:rgb(28, 30, 33);">我们可以用 </font>`<font style="color:#DF2A3F;">Glob</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">进行多种选择：</font>

```yaml
{{ range $path := .Files.Glob "**.yaml" }}
{{ $path }}: |
{{ .Files.Get $path }}
{{ end }}
```

<font style="color:rgb(28, 30, 33);">或者</font>

```yaml
{{ range $path, $bytes := .Files.Glob "foo/*" }}
{{ $path }}: '{{ b64enc $bytes }}'
{{ end }}
```

## <font style="color:rgb(28, 30, 33);">3 ConfigMap 和 Secrets</font>
<font style="color:rgb(28, 30, 33);">想要将文件内容同时放入 ConfigMap 和 Secrets 中，以便在运行时安装到 Pod 中，这种需求很常见，为了解决这个问题，Helm 在 </font>`<font style="color:#DF2A3F;">Files</font>`<font style="color:rgb(28, 30, 33);"> 类型上添加了一个实用的方法。</font>

<font style="color:rgb(28, 30, 33);">根据上面的目录结构，我们可以按照如下的方式进行处理：</font>

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: conf
data:
{{ (.Files.Glob "foo/*").AsConfig | indent 2 }}
# 文件解释
# (.Files.Glob "foo/*") - 匹配 Chart 目录下 foo/ 文件夹中的所有文件
# .AsConfig - 将匹配到的文件转换为 ConfigMap 的 data 格式（文件名作为 key，文件内容作为 value）
# indent 2 - 缩进 2 个空格，保持 YAML 格式正确
# 实际效果： 假设 foo/ 目录下有 app.conf 和 db.conf 两个文件，渲染后会变成：
# data:
#   app.conf: |
#     # app.conf 的内容
#   db.conf: |
#     # db.conf 的内容

---
apiVersion: v1
kind: Secret
metadata:
  name: very-secret
type: Opaque
data:
{{ (.Files.Glob "bar/*").AsSecrets | indent 2 }}

# 文件解释
# (.Files.Glob "bar/*") - 匹配 Chart 目录下 bar/ 文件夹中的所有文件
# .AsSecrets - 将文件内容进行 Base64 编码（Secret 要求）
# 文件名作为 key，Base64 编码后的内容作为 value
# 实际效果： 假设 bar/ 目录下有 password.txt 和 token.txt，渲染后会变成：
# data:
#   password.txt: cGFzc3dvcmQxMjM=  # Base64 编码后的内容
#   token.txt: dG9rZW4xMjM0NTY=     # Base64 
```

## <font style="color:rgb(28, 30, 33);">4 编码</font>
<font style="color:rgb(28, 30, 33);">我们也可以导入一个文件并用 </font>`<font style="color:#DF2A3F;">base64</font>`<font style="color:rgb(28, 30, 33);"> 编码进行编码：</font>

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: {{ .Release.Name }}-secret
type: Opaque
data:
  token: |-
    {{ .Files.Get "config1.toml" | b64enc }}
```

<font style="color:rgb(28, 30, 33);">上面将采用我们上面的 </font>`<font style="color:#DF2A3F;">config1.toml</font>`<font style="color:rgb(28, 30, 33);"> 文件并对其内容进行 </font>`<font style="color:#DF2A3F;">base64</font>`<font style="color:rgb(28, 30, 33);"> 编码，渲染会得到如下所示的结果：</font>

```yaml
$ helm install --generate-name --dry-run --debug ./mychart
[......]
# Source: mychart/templates/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: mychart-1762011949-secret
type: Opaque
data:
  token: |-
    bWVzc2FnZSA9IEhlbGxvIGZyb20gY29uZmlnIDE=
```

## <font style="color:rgb(28, 30, 33);">5 Lines</font>
<font style="color:rgb(28, 30, 33);">有时，需要访问模板中文件的每一行内容，Helm 也提供了方法的 </font>`<font style="color:#DF2A3F;">Lines</font>`<font style="color:rgb(28, 30, 33);"> 方法，我们可以使用 </font>`<font style="color:#DF2A3F;">range</font>`<font style="color:rgb(28, 30, 33);"> 函数遍历每行内容：</font>

```yaml
data:
  some-file.txt: {{ range .Files.Lines "foo/bar.txt" }}
    {{ . }}{{ end }}
```

<font style="color:rgb(28, 30, 33);">在 Helm 安装的时候无法将文件传递到 chart 外部，所以，如果你要求用户提供数据的话，则必须使用 </font>`<font style="color:#DF2A3F;">helm install -f</font>`<font style="color:rgb(28, 30, 33);"> 或者 </font>`<font style="color:#DF2A3F;">helm install --set</font>`<font style="color:rgb(28, 30, 33);"> 来获取。</font>

