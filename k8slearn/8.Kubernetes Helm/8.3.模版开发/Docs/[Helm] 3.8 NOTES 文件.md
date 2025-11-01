<font style="color:rgb(28, 30, 33);">在本节中我们将来了解为 Chart 用户</font>**<u><font style="color:rgb(28, 30, 33);">提供说明的一个 </font></u>**`**<u><font style="color:#DF2A3F;">NOTES.txt</font></u>**`**<u><font style="color:rgb(28, 30, 33);"> 文件，在 Chart 安装或者升级结束时，Helm 可以为用户打印出一些有用的信息，使用模板也可以自定义这些信息。</font></u>**

## <font style="color:rgb(28, 30, 33);">1 创建 NOTES.txt 文件</font>
<font style="color:rgb(28, 30, 33);">要将安装说明添加到 chart 中，只需要创建一个 </font>`<font style="color:#DF2A3F;">templates/NOTES.txt</font>`<font style="color:rgb(28, 30, 33);"> 文件，该文件纯文本的，但是可以像模板一样进行处理，并具有所有常规模板的功能和可用对象。</font>

<font style="color:rgb(28, 30, 33);">现在让我们来创建一个简单的 </font>`<font style="color:#DF2A3F;">NOTES.txt</font>`<font style="color:rgb(28, 30, 33);"> 文件：</font>

```yaml
Thank you for installing {{ .Chart.Name }}.

Your release is named {{ .Release.Name }}.

To learn more about the release, try:

  $ helm status {{ .Release.Name }}
  $ helm get {{ .Release.Name }}
```

<font style="color:rgb(28, 30, 33);">现在我们运行 </font>`<font style="color:#DF2A3F;">helm install ./mychart</font>`<font style="color:rgb(28, 30, 33);">，我们就可以在底部看到这样的消息：</font>

```shell
# $ helm install --generate-name --dry-run --debug ./mychart # 模拟运行 Chart
# $ helm install rude-cardinal --debug ./mychart # 显示 Debug 调式信息
$ helm install rude-cardinal ./mychart
NAME: rude-cardinal
LAST DEPLOYED: Sat Nov  1 23:49:21 2025
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
Thank you for installing mychart.

Your release is named rude-cardinal.

To learn more about the release, try:

  $ helm status rude-cardinal
  $ helm get rude-cardinal
```

<font style="color:rgb(28, 30, 33);">用这种方式可以向用户提供一个有关如何使用其新安装的 chart 的详细信息，强烈建议创建 </font>`<font style="color:#DF2A3F;">NOTES.txt</font>`<font style="color:rgb(28, 30, 33);"> 文件，虽然这不是必须的。</font>

