# 1 Helm CLI 调试信息
调试模板可能比较麻烦，因为渲染的模板会发送到 Kubernetes API server，而 API server 可能会因为格式以外的一些原因而拒绝 YAML 文件。

下面这些命令可以帮助你调试一些问题：

+ `<font style="color:#DF2A3F;">helm lint</font>` 是验证 chart 是否遵循最佳实践的首选工具
+ `<font style="color:#DF2A3F;">helm install --generate-name --dry-run --debug</font>` 或者 `<font style="color:#DF2A3F;">helm template --debug</font>`：前面我们已经使用了这个技巧，这个是让服务器渲染模板，然后返回生成的资源清单文件的好方法，而且不会真正的去安装这些资源
+ `<font style="color:#DF2A3F;">helm get manifest</font>`：这是查看服务器上安装了哪些模板的好方法

当你的 YAML 文件无法解析的时候，但你想要查看生成的内容的时候，检索 YAML 的一种简单方法是注释掉模板中的问题部分，然后重新运行 `<font style="color:#DF2A3F;">helm install --generate-name --dry-run --debug</font>`：

```yaml
apiVersion: v2
# some: problem section
# {{ .Values.foo | quote }}
```

上面的内容将呈现并返回完整的注释：

```yaml
apiVersion: v2
# some: problem section
#  "bar"
```

这提供了一种查看生成的内容的快速方法。

# 2 Helm CLI 模板调试 Demo
<details class="lake-collapse"><summary id="uf2947394"><span class="ne-text" style="color: #DF2A3F">helm lint 的使用</span></summary><pre data-language="shell" id="oAmLe" class="ne-codeblock language-shell"><code>$ helm lint mychart/
==&gt; Linting mychart/
[INFO] Chart.yaml: icon is recommended
[ERROR] /root/georgezhong/CloudNative/Learning/k8slearn/8.Kubernetes Helm/8.3.模版开发/Manifest/mychart: chart metadata is missing these dependencies: mysubchart

Error: 1 chart(s) linted, 1 chart(s) failed</code></pre><p id="u7de7a303" class="ne-p"><img src="https://cdn.nlark.com/yuque/0/2025/png/2555283/1762012933057-7ca33d43-7aa3-4ab0-a170-2ed1f70cbae9.png" width="954" id="ud9c59419" class="ne-image"></p></details>
<details class="lake-collapse"><summary id="ucd5793da"><span class="ne-text" style="color: #DF2A3F">helm install --generate-name --dry-run --debug 的使用</span></summary><pre data-language="shell" id="jQlur" class="ne-codeblock language-shell"><code>$ helm install --generate-name --dry-run --debug mychart</code></pre><p id="uf65eb247" class="ne-p"><img src="https://cdn.nlark.com/yuque/0/2025/png/2555283/1762012842686-f1055a7a-22f6-4ebf-92b9-7067fcf383b2.png" width="941" id="u1656933c" class="ne-image"></p></details>
<details class="lake-collapse"><summary id="u00d2f1ac"><span class="ne-text" style="color: #DF2A3F">helm template --debug 的使用</span></summary><pre data-language="shell" id="XPAjF" class="ne-codeblock language-shell"><code># 可以查看到模板文件渲染的内容
$ helm template --debug mychart/</code></pre><p id="uc053f043" class="ne-p"><img src="https://cdn.nlark.com/yuque/0/2025/png/2555283/1762012773751-e2984b3f-582d-4d8f-9cb6-2f232a8d7227.png" width="936" id="u75d518d7" class="ne-image"></p></details>
