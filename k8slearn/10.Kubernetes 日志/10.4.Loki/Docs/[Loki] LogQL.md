<font style="color:rgb(28, 30, 33);">受 PromQL 的启发，Loki 也有自己的查询语言，称为 LogQL，它就像一个分布式的 grep，可以聚合查看日志。和 PromQL 一样，LogQL 也是使用标签和运算符进行过滤的，主要有两种类型的查询功能：</font>

+ <font style="color:rgb(28, 30, 33);">查询返回日志行内容</font>
+ <font style="color:rgb(28, 30, 33);">通过过滤规则在日志流中计算相关的度量指标</font>

## <font style="color:rgb(28, 30, 33);">日志查询</font>
<font style="color:rgb(28, 30, 33);">一个基本的日志查询由两部分组成。</font>

+ `<font style="color:rgb(28, 30, 33);">log stream selector</font>`<font style="color:rgb(28, 30, 33);">（日志流选择器）</font>
+ `<font style="color:rgb(28, 30, 33);">log pipeline</font>`<font style="color:rgb(28, 30, 33);">（日志管道）</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734345617446-4eaa1db1-2e16-4e9d-84cf-0212712ef644.png)

<font style="color:rgb(28, 30, 33);">由于 Loki 的设计，所有 LogQL 查询必须包含一个日志流选择器。一个 Log Stream 代表了具有相同元数据(Label 集)的日志条目。</font>

**<font style="color:rgb(28, 30, 33);">日志流选择器</font>**<font style="color:rgb(28, 30, 33);">决定了有多少日志将被搜索到，一个更细粒度的日志流选择器将搜索到流的数量减少到一个可管理的数量，通过精细的匹配日志流，可以大幅减少查询期间带来资源消耗。</font>

<font style="color:rgb(28, 30, 33);">而日志流选择器后面的</font>**<font style="color:rgb(28, 30, 33);">日志管道</font>**<font style="color:rgb(28, 30, 33);">是可选的，用于进一步处理和过滤日志流信息，它由一组表达式组成，每个表达式都以从左到右的顺序为每个日志行执行相关过滤，每个表达式都可以过滤、解析和改变日志行内容以及各自的标签。</font>

![](https://cdn.nlark.com/yuque/0/2024/jpeg/2555283/1734345615905-6e322e68-829d-46f8-ad7c-56aa1d7d0a78.jpeg)

<font style="color:rgb(28, 30, 33);">下面的例子显示了一个完整的日志查询的操作：</font>

```plain
{container="query-frontend",namespace="loki-dev"} |= "metrics.go" | logfmt | duration > 10s and throughput_mb < 500
```

<font style="color:rgb(28, 30, 33);">该查询语句由以下几个部分组成：</font>

+ <font style="color:rgb(28, 30, 33);">一个日志流选择器</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">{container="query-frontend",namespace="loki-dev"}</font>`<font style="color:rgb(28, 30, 33);">，用于过滤</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">loki-dev</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">命名空间下面的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">query-frontend</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">容器的日志</font>
+ <font style="color:rgb(28, 30, 33);">然后后面跟着一个日志管道</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">|= "metrics.go" | logfmt | duration > 10s and throughput_mb < 500</font>`<font style="color:rgb(28, 30, 33);">，该管道表示将筛选出包含</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">metrics.go</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">这个词的日志，然后解析每一行日志提取更多的表达式并进行过滤</font>

为了避免转义特色字符，你可以在引用字符串的时候使用单引号，而不是双引号，比如 `\w+1` 与 "\w+" 是相同的。

## <font style="color:rgb(28, 30, 33);">Log Stream Selector</font>
<font style="color:rgb(28, 30, 33);">日志流选择器决定了哪些日志流应该被包含在你的查询结果中，选择器由</font>**<font style="color:rgb(28, 30, 33);">一个或多个键值对</font>**<font style="color:rgb(28, 30, 33);">组成，其中每个键是一个</font>**<font style="color:rgb(28, 30, 33);">日志标签</font>**<font style="color:rgb(28, 30, 33);">，每个值是该标签的值。</font>

<font style="color:rgb(28, 30, 33);">日志流选择器是通过将键值对包裹在一对大括号中编写的，比如：</font>

```plain
{app="mysql", name="mysql-backup"}
```

<font style="color:rgb(28, 30, 33);">上面这个示例表示，所有标签为 app 且其值为 mysql 和标签为 name 且其值为 mysql-backup 的日志流将被包括在查询结果中。</font>

<font style="color:rgb(28, 30, 33);">其中标签名后面的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">=</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">运算符是一个标签匹配运算符，LogQL 中一共支持以下几种标签匹配运算符：</font>

+ `<font style="color:rgb(28, 30, 33);">=</font>`<font style="color:rgb(28, 30, 33);">: 完全匹配</font>
+ `<font style="color:rgb(28, 30, 33);">!=</font>`<font style="color:rgb(28, 30, 33);">: 不相等</font>
+ `<font style="color:rgb(28, 30, 33);">=~</font>`<font style="color:rgb(28, 30, 33);">: 正则表达式匹配</font>
+ `<font style="color:rgb(28, 30, 33);">!~</font>`<font style="color:rgb(28, 30, 33);">: 正则表达式不匹配</font>

<font style="color:rgb(28, 30, 33);">例如：</font>

+ `<font style="color:rgb(28, 30, 33);">{name=~"mysql.+"}</font>`
+ `<font style="color:rgb(28, 30, 33);">{name!~"mysql.+"}</font>`
+ `<font style="color:rgb(28, 30, 33);">{name!~"mysql-\\d+"}</font>`

<font style="color:rgb(28, 30, 33);">适用于</font><font style="color:rgb(28, 30, 33);"> </font>[<font style="color:rgb(28, 30, 33);">Prometheus 标签选择器</font>](https://prometheus.io/docs/prometheus/latest/querying/basics/#instant-vector-selectors)<font style="color:rgb(28, 30, 33);">的规则同样适用于 Loki 日志流选择器。</font>

## <font style="color:rgb(28, 30, 33);">Log Pipeline</font>
<font style="color:rgb(28, 30, 33);">日志管道可以附加到日志流选择器上，以进一步处理和过滤日志流。 它通常由一个或多个表达式组成，每个表达式针对每个日志行依次执行。 如果一个表达式过滤掉了日志行，则管道将在此处停止并开始处理下一行。一些表达式可以改变日志内容和各自的标签，然后可用于进一步过滤和处理后续表达式或指标查询。</font>

<font style="color:rgb(28, 30, 33);">一个日志管道可以由以下部分组成。</font>

+ <font style="color:rgb(28, 30, 33);">日志行过滤表达式</font>
+ <font style="color:rgb(28, 30, 33);">解析器表达式</font>
+ <font style="color:rgb(28, 30, 33);">标签过滤表达式</font>
+ <font style="color:rgb(28, 30, 33);">日志行格式化表达式</font>
+ <font style="color:rgb(28, 30, 33);">标签格式化表达式</font>
+ <font style="color:rgb(28, 30, 33);">Unwrap 表达式</font>

<font style="color:rgb(28, 30, 33);">其中 unwrap 表达式是一个特殊的表达式，只能在度量查询中使用。</font>

### <font style="color:rgb(28, 30, 33);">日志行过滤表达式</font>
<font style="color:rgb(28, 30, 33);">日志行过滤表达式用于对匹配日志流中的聚合日志进行分布式 grep。</font>

<font style="color:rgb(28, 30, 33);">编写入日志流选择器后，可以使用一个</font>**<font style="color:rgb(28, 30, 33);">搜索表达式</font>**<font style="color:rgb(28, 30, 33);">进一步过滤得到的日志数据集，搜索表达式可以是文本或正则表达式，比如：</font>

+ `<font style="color:rgb(28, 30, 33);">{job="mysql"} |= "error"</font>`
+ `<font style="color:rgb(28, 30, 33);">{name="kafka"} |~ "tsdb-ops.*io:2003"</font>`
+ `<font style="color:rgb(28, 30, 33);">{name="cassandra"} |~ "error=\\w+"</font>`
+ `<font style="color:rgb(28, 30, 33);">{instance=~"kafka-[23]",name="kafka"} != "kafka.server:type=ReplicaManager"</font>`

<font style="color:rgb(28, 30, 33);">上面示例中的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">|=</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">|~</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">和</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">!=</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">是</font>**<font style="color:rgb(28, 30, 33);">过滤运算符</font>**<font style="color:rgb(28, 30, 33);">，支持下面几种：</font>

+ `<font style="color:rgb(28, 30, 33);">|=</font>`<font style="color:rgb(28, 30, 33);">：日志行包含的字符串</font>
+ `<font style="color:rgb(28, 30, 33);">!=</font>`<font style="color:rgb(28, 30, 33);">：日志行不包含的字符串</font>
+ `<font style="color:rgb(28, 30, 33);">|~</font>`<font style="color:rgb(28, 30, 33);">：日志行匹配正则表达式</font>
+ `<font style="color:rgb(28, 30, 33);">!~</font>`<font style="color:rgb(28, 30, 33);">：日志行与正则表达式不匹配</font>

<font style="color:rgb(28, 30, 33);">过滤运算符可以是链式的，并将按顺序过滤表达式，产生的日志行必须满足每个过滤器。当使用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">|~</font>`<font style="color:rgb(28, 30, 33);">和</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">!~</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">时，可以使用 Golang 的 RE2 语法的正则表达式，默认情况下，匹配是区分大小写的，可以用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">(?i)</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">作为正则表达式的前缀，切换为不区分大小写。</font>

<font style="color:rgb(28, 30, 33);">虽然日志行过滤表达式可以放在管道的任何地方，但最好把它们放在开头，这样可以提高查询的性能，当某一行匹配时才做进一步的后续处理。例如，虽然结果是一样的，但下面的查询</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">{job="mysql"} |= "error" |json | line_format "{{.err}}"</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">会比</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">{job="mysql"} | json | line_format "{{.message}}" |= "error"</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">更快，</font>**<font style="color:rgb(28, 30, 33);">日志行过滤表达式是继日志流选择器之后过滤日志的最快方式</font>**<font style="color:rgb(28, 30, 33);">。</font>

### <font style="color:rgb(28, 30, 33);">解析器表达式</font>
<font style="color:rgb(28, 30, 33);">解析器表达式可以解析和提取日志内容中的标签，这些提取的标签可以用于标签过滤表达式进行过滤，或者用于指标聚合。</font>

<font style="color:rgb(28, 30, 33);">提取的标签键将由解析器进行自动格式化，以遵循 Prometheus 指标名称的约定（它们只能包含 ASCII 字母和数字，以及下划线和冒号，不能以数字开头）。</font>

<font style="color:rgb(28, 30, 33);">例如下面的日志经过管道</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">| json</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">将产生以下 Map 数据：</font>

```json
{ "a.b": { "c": "d" }, "e": "f" }
```

<font style="color:rgb(28, 30, 33);">-></font>

```plain
{a_b_c="d", e="f"}
```

<font style="color:rgb(28, 30, 33);">在出现错误的情况下，例如，如果该行不是预期的格式，该日志行不会被过滤，而是会被添加一个新的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">__error__</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">标签。</font>

<font style="color:rgb(28, 30, 33);">需要注意的是如果一个提取的标签键名已经存在于原始日志流中，那么提取的标签键将以</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">_extracted</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">作为后缀，以区分两个标签，你可以使用一个标签格式化表达式来强行覆盖原始标签，但是如果一个提取的键出现了两次，那么只有最新的标签值会被保留。</font>

<font style="color:rgb(28, 30, 33);">目前支持</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">json</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">logfmt</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">pattern</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">regexp</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">和</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">unpack</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">这几种解析器。</font>

<font style="color:rgb(28, 30, 33);">我们应该尽可能使用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">json</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">和</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">logfmt</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">等预定义的解析器，这会更加容易，而当日志行结构异常时，可以使用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">regexp</font>`<font style="color:rgb(28, 30, 33);">，可以在同一日志管道中使用多个解析器，这在你解析复杂日志时很有用。</font>

#### <font style="color:rgb(28, 30, 33);">JSON</font>
<font style="color:rgb(28, 30, 33);">json 解析器有两种模式运行。</font>

    1. <font style="color:rgb(28, 30, 33);">没有参数。</font>

<font style="color:rgb(28, 30, 33);">如果日志行是一个有效的 json 文档，在你的管道中添加</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">| json</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">将提取所有 json 属性作为标签，嵌套的属性会使用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">_</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">分隔符被平铺到标签键中。</font>

注意：数组会被忽略。

<font style="color:rgb(28, 30, 33);">例如，使用 json 解析器从以下文件内容中提取标签。</font>

```json
{
  "protocol": "HTTP/2.0",
  "servers": ["129.0.1.1", "10.2.1.3"],
  "request": {
    "time": "6.032",
    "method": "GET",
    "host": "foo.grafana.net",
    "size": "55",
    "headers": {
      "Accept": "*/*",
      "User-Agent": "curl/7.68.0"
    }
  },
  "response": {
    "status": 401,
    "size": "228",
    "latency_seconds": "6.031"
  }
}
```

<font style="color:rgb(28, 30, 33);">可以得到如下所示的标签列表：</font>

```plain
"protocol" => "HTTP/2.0"
"request_time" => "6.032"
"request_method" => "GET"
"request_host" => "foo.grafana.net"
"request_size" => "55"
"response_status" => "401"
"response_size" => "228"
"response_latency_seconds" => "6.031"
```

    1. <font style="color:rgb(28, 30, 33);">带参数的</font>

<font style="color:rgb(28, 30, 33);">在你的管道中使用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">|json label="expression", another="expression"</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">将只提取指定的 json 字段为标签，你可以用这种方式指定一个或多个表达式，与</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">label_format</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">相同，所有表达式必须加引号。</font>

<font style="color:rgb(28, 30, 33);">当前仅支持字段访问（</font>`<font style="color:rgb(28, 30, 33);">my.field</font>`<font style="color:rgb(28, 30, 33);">,</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">my["field"]</font>`<font style="color:rgb(28, 30, 33);">）和数组访问（</font>`<font style="color:rgb(28, 30, 33);">list[0]</font>`<font style="color:rgb(28, 30, 33);">），以及任何级别嵌套中的这些组合（</font>`<font style="color:rgb(28, 30, 33);">my.list[0]["field"]</font>`<font style="color:rgb(28, 30, 33);">）。</font>

<font style="color:rgb(28, 30, 33);">例如，</font>`<font style="color:rgb(28, 30, 33);">|json first_server="servers[0]", ua="request.headers[\"User-Agent\"]</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">将从以下日志文件中提取标签：</font>

```json
{
  "protocol": "HTTP/2.0",
  "servers": ["129.0.1.1", "10.2.1.3"],
  "request": {
    "time": "6.032",
    "method": "GET",
    "host": "foo.grafana.net",
    "size": "55",
    "headers": {
      "Accept": "*/*",
      "User-Agent": "curl/7.68.0"
    }
  },
  "response": {
    "status": 401,
    "size": "228",
    "latency_seconds": "6.031"
  }
}
```

<font style="color:rgb(28, 30, 33);">提取的标签列表为：</font>

```plain
"first_server" => "129.0.1.1"
"ua" => "curl/7.68.0"
```

<font style="color:rgb(28, 30, 33);">如果表达式返回一个数组或对象，它将以 json 格式分配给标签。例如，</font>`<font style="color:rgb(28, 30, 33);">|json server_list="services", headers="request.headers</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">将提取到如下标签：</font>

```plain
"server_list" => `["129.0.1.1","10.2.1.3"]`
"headers" => `{"Accept": "*/*", "User-Agent": "curl/7.68.0"}`
```

#### <font style="color:rgb(28, 30, 33);">logfmt</font>
`<font style="color:rgb(28, 30, 33);">logfmt</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">解析器可以通过使用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">| logfmt</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">来添加，它将从 logfmt 格式的日志行中提前所有的键和值。</font>

<font style="color:rgb(28, 30, 33);">例如，下面的日志行数据：</font>

```plain
at=info method=GET path=/ host=grafana.net fwd="124.133.124.161" service=8ms status=200
```

<font style="color:rgb(28, 30, 33);">将提取得到如下所示的标签：</font>

```plain
"at" => "info"
"method" => "GET"
"path" => "/"
"host" => "grafana.net"
"fwd" => "124.133.124.161"
"service" => "8ms"
"status" => "200"
```

#### <font style="color:rgb(28, 30, 33);">regexp</font>
<font style="color:rgb(28, 30, 33);">与</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">logfmt</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">和</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">json</font>`<font style="color:rgb(28, 30, 33);">（它们隐式提取所有值且不需要参数）不同，</font>`<font style="color:rgb(28, 30, 33);">regexp</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">解析器采用单个参数</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">| regexp "<re>"</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">的格式，其参数是使用 Golang RE2 语法的正则表达式。</font>

<font style="color:rgb(28, 30, 33);">正则表达式必须包含至少一个命名的子匹配（例如</font>`<font style="color:rgb(28, 30, 33);">(?P<name>re)</font>`<font style="color:rgb(28, 30, 33);">），每个子匹配项都会提取一个不同的标签。</font>

<font style="color:rgb(28, 30, 33);">例如，解析器</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">| regexp "(?P<method>\\w+) (?P<path>[\\w|/]+) \\((?P<status>\\d+?)\\) (?P<duration>.*)"</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">将从以下行中提取标签：</font>

```plain
POST /api/prom/api/v1/query_range (200) 1.5s
```

<font style="color:rgb(28, 30, 33);">提取的标签为：</font>

```plain
"method" => "POST"
"path" => "/api/prom/api/v1/query_range"
"status" => "200"
"duration" => "1.5s"
```

#### <font style="color:rgb(28, 30, 33);">pattern</font>
<font style="color:rgb(28, 30, 33);">模式解析器允许通过定义模式表达式（</font>`<font style="color:rgb(28, 30, 33);">| pattern "<pattern-expression>"</font>`<font style="color:rgb(28, 30, 33);">）从日志行中显式提取字段，该表达式与日志行的结构相匹配。</font>

<font style="color:rgb(28, 30, 33);">比如我们来考虑下面的 NGINX 日志行数据：</font>

```shell
0.191.12.2 - - [10/Jun/2021:09:14:29 +0000] "GET /api/plugins/versioncheck HTTP/1.1" 200 2 "-" "Go-http-client/2.0" "13.76.247.102, 34.120.177.193" "TLSv1.2" "US" ""
```

<font style="color:rgb(28, 30, 33);">该日志行可以用下面的表达式来解析：</font>

```shell
<ip> - - <_> "<method> <uri> <_>" <status> <size> <_> "<agent>" <_>
```

<font style="color:rgb(28, 30, 33);">解析后可以提取出下面的这些属性：</font>

```plain
"ip" => "0.191.12.2"
"method" => "GET"
"uri" => "/api/plugins/versioncheck"
"status" => "200"
"size" => "2"
"agent" => "Go-http-client/2.0"
```

<font style="color:rgb(28, 30, 33);">模式表达式的捕获是由</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);"><</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">和</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">></font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">字符分隔的字段名称，比如</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);"><example></font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">定义了字段名称为</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">example</font>`<font style="color:rgb(28, 30, 33);">，未命名的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">capture</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">显示为</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);"><_></font>`<font style="color:rgb(28, 30, 33);">，未命名的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">capture</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">会跳过匹配的内容。默认情况下，模式表达式锚定在日志行的开头，可以在表达式的开头使用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);"><_></font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">将表达式锚定在开头。</font>

<font style="color:rgb(28, 30, 33);">比如我们查看下面的日志行数据：</font>

```shell
level=debug ts=2021-06-10T09:24:13.472094048Z caller=logging.go:66 traceID=0568b66ad2d9294c msg="POST /loki/api/v1/push (204) 16.652862ms"
```

<font style="color:rgb(28, 30, 33);">我们如果只希望去匹配</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">msg="</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">的内容，我们可以使用下面的表达式来进行匹配：</font>

```shell
<_> msg="<method> <path> (<status>) <latency>"
```

<font style="color:rgb(28, 30, 33);">前面大部分日志数据我们不需要，只需要使用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);"><_></font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">进行占位即可，明显可以看出这种方式比正则表达式要简单得多。</font>

#### <font style="color:rgb(28, 30, 33);">unpack</font>
`<font style="color:rgb(28, 30, 33);">unpack</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">解析器将解析 json 日志行，并通过打包阶段解开所有嵌入的标签，一个特殊的属性</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">_entry</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">也将被用来替换原来的日志行。</font>

<font style="color:rgb(28, 30, 33);">例如，使用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">| unpack</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">解析器，可以得到如下所示的标签：</font>

```json
{
  "container": "myapp",
  "pod": "pod-3223f",
  "_entry": "original log message"
}
```

<font style="color:rgb(28, 30, 33);">允许提取</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">container</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">和</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">pod</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">标签以及原始日志信息作为新的日志行。</font>

如果原始嵌入的日志行是特定的格式，你可以将 unpack 与 json 解析器（或其他解析器）相结合使用。

### <font style="color:rgb(28, 30, 33);">标签过滤表达式</font>
<font style="color:rgb(28, 30, 33);">标签过滤表达式允许使用其原始和提取的标签来过滤日志行，它可以包含多个谓词。</font>

<font style="color:rgb(28, 30, 33);">一个谓词包含一个标签标识符、操作符和用于比较标签的值。</font>

<font style="color:rgb(28, 30, 33);">例如</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">cluster="namespace"</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">其中的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">cluster</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">是标签标识符，操作符是</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">=</font>`<font style="color:rgb(28, 30, 33);">，值是</font>`<font style="color:rgb(28, 30, 33);">"namespace"</font>`<font style="color:rgb(28, 30, 33);">。</font>

<font style="color:rgb(28, 30, 33);">LogQL 支持从查询输入中自动推断出的多种值类型：</font>

+ `<font style="color:rgb(28, 30, 33);">String（字符串）</font>`<font style="color:rgb(28, 30, 33);">用双引号或反引号引起来，例如</font>`<font style="color:rgb(28, 30, 33);">"200"</font>`<font style="color:rgb(28, 30, 33);">或`us-central1`。</font>
+ `<font style="color:rgb(28, 30, 33);">Duration（时间）</font>`<font style="color:rgb(28, 30, 33);">是一串十进制数字，每个数字都有可选的数和单位后缀，如</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">"300ms"</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">"1.5h"</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">或</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">"2h45m"</font>`<font style="color:rgb(28, 30, 33);">，有效的时间单位是</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">"ns"</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">"us"</font>`<font style="color:rgb(28, 30, 33);">（或</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">"µs"</font>`<font style="color:rgb(28, 30, 33);">）、</font>`<font style="color:rgb(28, 30, 33);">"ms"</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">"s"</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">"m"</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">"h"</font>`<font style="color:rgb(28, 30, 33);">。</font>
+ `<font style="color:rgb(28, 30, 33);">Number（数字）</font>`<font style="color:rgb(28, 30, 33);">是浮点数（64 位），如 250、89.923。</font>
+ `<font style="color:rgb(28, 30, 33);">Bytes（字节）</font>`<font style="color:rgb(28, 30, 33);">是一串十进制数字，每个数字都有可选的数和单位后缀，如</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">"42MB"</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">"1.5Kib"</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">或</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">"20b"</font>`<font style="color:rgb(28, 30, 33);">，有效的字节单位是</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">"b"</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">"kib"</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">"kb"</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">"mib"</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">"mb"</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">"gib"</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">"gb"</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">"tib"</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">"tb"</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">"pib"</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">"bb"</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">"eb"</font>`<font style="color:rgb(28, 30, 33);">。</font>

<font style="color:rgb(28, 30, 33);">字符串类型的工作方式与 Prometheus 标签匹配器在日志流选择器中使用的方式完全一样，这意味着你可以使用同样的操作符（</font>`<font style="color:rgb(28, 30, 33);">=</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">!=</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">=~</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">!~</font>`<font style="color:rgb(28, 30, 33);">）。</font>

<font style="color:rgb(28, 30, 33);">使用 Duration、Number 和 Bytes 将在比较前转换标签值，并支持以下比较器。</font>

+ `<font style="color:rgb(28, 30, 33);">==</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">或</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">=</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">相等比较</font>
+ `<font style="color:rgb(28, 30, 33);">!=</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">不等于比较</font>
+ `<font style="color:rgb(28, 30, 33);">></font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">和</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">>=</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">用于大于或大于等于比较</font>
+ `<font style="color:rgb(28, 30, 33);"><</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">和</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);"><=</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">用于小于或小于等于比较</font>

<font style="color:rgb(28, 30, 33);">例如</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">logfmt | duration > 1m and bytes_consumed > 20MB</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">过滤表达式。</font>

<font style="color:rgb(28, 30, 33);">如果标签值的转换失败，日志行就不会被过滤，而会添加一个</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">__error__</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">标签。你可以使用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">and</font>`<font style="color:rgb(28, 30, 33);">和</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">or</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">来连接多个谓词，它们分别表示</font>**<font style="color:rgb(28, 30, 33);">且</font>**<font style="color:rgb(28, 30, 33);">和</font>**<font style="color:rgb(28, 30, 33);">或</font>**<font style="color:rgb(28, 30, 33);">的二进制操作，</font>`<font style="color:rgb(28, 30, 33);">and</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">可以用逗号、空格或其他管道来表示，标签过滤器可以放在日志管道的任何地方。</font>

<font style="color:rgb(28, 30, 33);">以下所有的表达式都是等价的:</font>

```plain
| duration >= 20ms or size == 20kb and method!~"2.."
| duration >= 20ms or size == 20kb | method!~"2.."
| duration >= 20ms or size == 20kb,method!~"2.."
| duration >= 20ms or size == 20kb method!~"2.."
```

<font style="color:rgb(28, 30, 33);">默认情况下，多个谓词的优先级是从右到左，你可以用圆括号包装谓词，强制使用从左到右的不同优先级。</font>

<font style="color:rgb(28, 30, 33);">例如，以下内容是等价的：</font>

```plain
| duration >= 20ms or method="GET" and size <= 20KB
| ((duration >= 20ms or method="GET") and size <= 20KB)
```

<font style="color:rgb(28, 30, 33);">它将首先评估</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">duration>=20ms or method="GET"</font>`<font style="color:rgb(28, 30, 33);">，要首先评估</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">method="GET" and size<=20KB</font>`<font style="color:rgb(28, 30, 33);">，请确保使用适当的括号，如下所示。</font>

```plain
| duration >= 20ms or (method="GET" and size <= 20KB)
```

### <font style="color:rgb(28, 30, 33);">日志行格式表达式</font>
<font style="color:rgb(28, 30, 33);">日志行格式化表达式可以通过使用 Golang 的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">text/template</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">模板格式重写日志行的内容，它需要一个字符串参数</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">| line_format "{{.label_name}}"</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">作为模板格式，所有的标签都是注入模板的变量，可以用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">{{.label_name}}</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">的符号来使用。</font>

<font style="color:rgb(28, 30, 33);">例如，下面的表达式：</font>

```plain
{container="frontend"} | logfmt | line_format "{{.query}} {{.duration}}"
```

<font style="color:rgb(28, 30, 33);">将提取并重写日志行，只包含</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">query</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">和请求的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">duration</font>`<font style="color:rgb(28, 30, 33);">。你可以为模板使用双引号字符串或反引号</font><font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">`{{.label_name}}`</font><font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">来避免转义特殊字符。</font>

<font style="color:rgb(28, 30, 33);">此外</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">line_format</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">也支持数学函数，例如：</font>

<font style="color:rgb(28, 30, 33);">如果我们有以下标签</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">ip=1.1.1.1</font>`<font style="color:rgb(28, 30, 33);">,</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">status=200</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">和</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">duration=3000(ms)</font>`<font style="color:rgb(28, 30, 33);">, 我们可以用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">duration</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">除以 1000 得到以秒为单位的值：</font>

```plain
{container="frontend"} | logfmt | line_format "{{.ip}} {{.status}} {{div .duration 1000}}"
```

<font style="color:rgb(28, 30, 33);">上面的查询将得到的日志行内容为</font>`<font style="color:rgb(28, 30, 33);">1.1.1.1 200 3</font>`<font style="color:rgb(28, 30, 33);">。</font>

### <font style="color:rgb(28, 30, 33);">标签格式表达式</font>
`<font style="color:rgb(28, 30, 33);">| label_format</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">表达式可以重命名、修改或添加标签，它以逗号分隔的操作列表作为参数，可以同时进行多个操作。</font>

<font style="color:rgb(28, 30, 33);">当两边都是标签标识符时，例如</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">dst=src</font>`<font style="color:rgb(28, 30, 33);">，该操作将把</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">src</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">标签重命名为</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">dst</font>`<font style="color:rgb(28, 30, 33);">。</font>

<font style="color:rgb(28, 30, 33);">左边也可以是一个模板字符串，例如</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">dst="{{.status}} {{.query}}"</font>`<font style="color:rgb(28, 30, 33);">，在这种情况下，</font>`<font style="color:rgb(28, 30, 33);">dst</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">标签值会被 Golang 模板执行结果所取代，这与</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">| line_format</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">表达式是同一个模板引擎，这意味着标签可以作为变量使用，也可以使用同样的函数列表。</font>

<font style="color:rgb(28, 30, 33);">在上面两种情况下，如果目标标签不存在，那么就会创建一个新的标签。</font>

<font style="color:rgb(28, 30, 33);">重命名形式</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">dst=src</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">会在将</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">src</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">标签重新映射到</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">dst</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">标签后将其删除，然而，模板形式将保留引用的标签，例如</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">dst="{{.src}}"</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">的结果是</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">dst</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">和</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">src</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">都有相同的值。</font>

一个标签名称在每个表达式中只能出现一次，这意味着 `| label_format foo=bar,foo="new"` 是不允许的，但你可以使用两个表达式来达到预期效果，比如 `| label_format foo=bar | label_format foo="new"`。

## <font style="color:rgb(28, 30, 33);">日志度量</font>
<font style="color:rgb(28, 30, 33);">LogQL 同样支持通过函数方式将日志流进行度量，通常我们可以用它来计算消息的错误率或者排序一段时间内的应用日志输出 Top N。</font>

### <font style="color:rgb(28, 30, 33);">区间向量</font>
<font style="color:rgb(28, 30, 33);">LogQL 同样也支持有限的区间向量度量语句，使用方式和 PromQL 类似，常用函数主要是如下 4 个：</font>

+ `<font style="color:rgb(28, 30, 33);">rate</font>`<font style="color:rgb(28, 30, 33);">: 计算每秒的日志条目</font>
+ `<font style="color:rgb(28, 30, 33);">count_over_time</font>`<font style="color:rgb(28, 30, 33);">: 对指定范围内的每个日志流的条目进行计数</font>
+ `<font style="color:rgb(28, 30, 33);">bytes_rate</font>`<font style="color:rgb(28, 30, 33);">: 计算日志流每秒的字节数</font>
+ `<font style="color:rgb(28, 30, 33);">bytes_over_time</font>`<font style="color:rgb(28, 30, 33);">: 对指定范围内的每个日志流的使用的字节数</font>

<font style="color:rgb(28, 30, 33);">比如计算 nginx 的 qps：</font>

```plain
rate({filename="/var/log/nginx/access.log"}[5m]))
```

<font style="color:rgb(28, 30, 33);">计算 kernel 过去 5 分钟发生 oom 的次数：</font>

```plain
count_over_time({filename="/var/log/message"} |~ "oom_kill_process" [5m]))
```

### <font style="color:rgb(28, 30, 33);">聚合函数</font>
<font style="color:rgb(28, 30, 33);">LogQL 也支持聚合运算，我们可用它来聚合单个向量内的元素，从而产生一个具有较少元素的新向量，当前支持的聚合函数如下：</font>

+ `<font style="color:rgb(28, 30, 33);">sum</font>`<font style="color:rgb(28, 30, 33);">：求和</font>
+ `<font style="color:rgb(28, 30, 33);">min</font>`<font style="color:rgb(28, 30, 33);">：最小值</font>
+ `<font style="color:rgb(28, 30, 33);">max</font>`<font style="color:rgb(28, 30, 33);">：最大值</font>
+ `<font style="color:rgb(28, 30, 33);">avg</font>`<font style="color:rgb(28, 30, 33);">：平均值</font>
+ `<font style="color:rgb(28, 30, 33);">stddev</font>`<font style="color:rgb(28, 30, 33);">：标准差</font>
+ `<font style="color:rgb(28, 30, 33);">stdvar</font>`<font style="color:rgb(28, 30, 33);">：标准方差</font>
+ `<font style="color:rgb(28, 30, 33);">count</font>`<font style="color:rgb(28, 30, 33);">：计数</font>
+ `<font style="color:rgb(28, 30, 33);">bottomk</font>`<font style="color:rgb(28, 30, 33);">：最小的 k 个元素</font>
+ `<font style="color:rgb(28, 30, 33);">topk</font>`<font style="color:rgb(28, 30, 33);">：最大的 k 个元素</font>

<font style="color:rgb(28, 30, 33);">聚合函数我们可以用如下表达式描述：</font>

```plain
<aggr-op>([parameter,] <vector expression>) [without|by (<label list>)]
```

<font style="color:rgb(28, 30, 33);">对于需要对标签进行分组时，我们可以用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">without</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">或者</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">by</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">来区分。比如计算 nginx 的 qps，并按照 pod 来分组：</font>

```plain
sum(rate({filename="/var/log/nginx/access.log"}[5m])) by (pod)
```

<font style="color:rgb(28, 30, 33);">只有在使用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">bottomk</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">和</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">topk</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">函数时，我们可以对函数输入相关的参数。比如计算 nginx 的 qps 最大的前 5 个，并按照 pod 来分组：</font>

```plain
topk(5,sum(rate({filename="/var/log/nginx/access.log"}[5m])) by (pod)))
```

### <font style="color:rgb(28, 30, 33);">二元运算</font>
#### <font style="color:rgb(28, 30, 33);">数学计算</font>
<font style="color:rgb(28, 30, 33);">Loki 存的是日志，都是文本，怎么计算呢？显然 LogQL 中的数学运算是面向区间向量操作的，LogQL 中的支持的二进制运算符如下：</font>

+ `<font style="color:rgb(28, 30, 33);">+</font>`<font style="color:rgb(28, 30, 33);">：加法</font>
+ `<font style="color:rgb(28, 30, 33);">-</font>`<font style="color:rgb(28, 30, 33);">：减法</font>
+ `<font style="color:rgb(28, 30, 33);">*</font>`<font style="color:rgb(28, 30, 33);">：乘法</font>
+ `<font style="color:rgb(28, 30, 33);">/</font>`<font style="color:rgb(28, 30, 33);">：除法</font>
+ `<font style="color:rgb(28, 30, 33);">%</font>`<font style="color:rgb(28, 30, 33);">：求模</font>
+ `<font style="color:rgb(28, 30, 33);">^</font>`<font style="color:rgb(28, 30, 33);">：求幂</font>

<font style="color:rgb(28, 30, 33);">比如我们要找到某个业务日志里面的错误率，就可以按照如下方式计算：</font>

```plain
sum(rate({app="foo", level="error"}[1m])) / sum(rate({app="foo"}[1m]))
```

#### <font style="color:rgb(28, 30, 33);">逻辑运算</font>
<font style="color:rgb(28, 30, 33);">集合运算仅在区间向量范围内有效，当前支持</font>

+ `<font style="color:rgb(28, 30, 33);">and</font>`<font style="color:rgb(28, 30, 33);">：并且</font>
+ `<font style="color:rgb(28, 30, 33);">or</font>`<font style="color:rgb(28, 30, 33);">：或者</font>
+ `<font style="color:rgb(28, 30, 33);">unless</font>`<font style="color:rgb(28, 30, 33);">：排除</font>

<font style="color:rgb(28, 30, 33);">比如：</font>

```plain
rate({app=~"foo|bar"}[1m]) and rate({app="bar"}[1m])
```

#### <font style="color:rgb(28, 30, 33);">比较运算</font>
<font style="color:rgb(28, 30, 33);">LogQL 支持的比较运算符和 PromQL 一样，包括：</font>

+ `<font style="color:rgb(28, 30, 33);">==</font>`<font style="color:rgb(28, 30, 33);">：等于</font>
+ `<font style="color:rgb(28, 30, 33);">!=</font>`<font style="color:rgb(28, 30, 33);">：不等于</font>
+ `<font style="color:rgb(28, 30, 33);">></font>`<font style="color:rgb(28, 30, 33);">：大于</font>
+ `<font style="color:rgb(28, 30, 33);">>=</font>`<font style="color:rgb(28, 30, 33);">: 大于或等于</font>
+ `<font style="color:rgb(28, 30, 33);"><</font>`<font style="color:rgb(28, 30, 33);">：小于</font>
+ `<font style="color:rgb(28, 30, 33);"><=</font>`<font style="color:rgb(28, 30, 33);">: 小于或等于</font>

<font style="color:rgb(28, 30, 33);">通常我们使用区间向量计算后会做一个阈值的比较，这对应告警是非常有用的，比如统计 5 分钟内 error 级别日志条目大于 10 的情况：</font>

```plain
count_over_time({app="foo", level="error"}[5m]) > 10
```

<font style="color:rgb(28, 30, 33);">我们也可以通过布尔计算来表达，比如统计 5 分钟内 error 级别日志条目大于 10 为真，反正则为假：</font>

```plain
count_over_time({app="foo", level="error"}[5m]) > bool 10
```

### <font style="color:rgb(28, 30, 33);">注释</font>
<font style="color:rgb(28, 30, 33);">LogQL 查询可以使用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">#</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">字符进行注释，例如：</font>

```plain
{app="foo"} # anything that comes after will not be interpreted in your query
```

<font style="color:rgb(28, 30, 33);">对于多行 LogQL 查询，可以使用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">#</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">排除整个或部分行：</font>

```plain
{app="foo"}
    | json
    # this line will be ignored
    | bar="baz" # this checks if bar = "baz"
```

## <font style="color:rgb(28, 30, 33);">查询示例</font>
<font style="color:rgb(28, 30, 33);">这里我们部署一个示例应用，该应用程序是一个伪造的记录器，它的日志具有 debug、info 和 warning 输出到 stdout。 error 级别的日志将被写入 stderr，实际的日志消息以 JSON 格式生成，每 500 毫秒将创建一条新的日志消息。日志消息格式如下所示：</font>

```json
{
  "app": "The fanciest app of mankind",
  "executable": "fake-logger",
  "is_even": true,
  "level": "debug",
  "msg": "This is a debug message. Hope you'll catch the bug",
  "time": "2022-04-04T13:41:50+02:00",
  "version": "1.0.0"
}
```

<font style="color:rgb(28, 30, 33);">使用下面的命令来创建示例应用：</font>

```shell
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
 labels:
  app: fake-logger
  environment: development
 name: fake-logger
spec:
 selector:
  matchLabels:
   app: fake-logger
   environment: development
 template:
  metadata:
   labels:
    app: fake-logger
    environment: development
  spec:
   containers:
   - image: thorstenhans/fake-logger:0.0.2
     name: fake-logger
     resources:
      requests:
       cpu: 10m
       memory: 32Mi
      limits:
       cpu: 10m
       memory: 32Mi
EOF
```

<font style="color:rgb(28, 30, 33);">我们可以使用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">{app="fake-logger"}</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">在 Grafana 中查询到该应用的日志流数据。</font>

![](https://cdn.nlark.com/yuque/0/2024/jpeg/2555283/1734345619090-dcd4b703-72ec-4539-9b09-885fd9d78291.jpeg)

<font style="color:rgb(28, 30, 33);">由于我们该示例应用的日志是 JSON 形式的，我们可以采用 JSON 解析器来解析日志，表达式为</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">{app="fake-logger"} | json</font>`<font style="color:rgb(28, 30, 33);">，如下所示。</font>

![](https://cdn.nlark.com/yuque/0/2024/jpeg/2555283/1734345619458-2781e6e8-7bee-4737-99f3-f363d3de41c3.jpeg)

<font style="color:rgb(28, 30, 33);">使用 JSON 解析器解析日志后可以看到 Grafana 提供的面板会根据</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">level</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">的值使用不同的颜色进行区分，而且现在我们日志的属性也被添加到了 Log 的标签中去了。</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734345616808-6cbe435d-88a6-4446-98e2-f723dcdf6b87.png)

<font style="color:rgb(28, 30, 33);">现在 JSON 中的数据变成了日志标签我们自然就可以使用这些标签来过滤日志数据了，比如我们要过滤</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">level=error</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">的日志，只使用表达式</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">{app="fake-logger"} | json | level="error"</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">即可实现。</font>

![](https://cdn.nlark.com/yuque/0/2024/jpeg/2555283/1734345620406-d8ec5a51-7b27-43b5-a10d-dffb42c630f6.jpeg)

<font style="color:rgb(28, 30, 33);">此外我们还可以根据我们的需求去格式化输出日志，使用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">line_format</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">即可实现，比如我们这里使用查询语句</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">{app="fake-logger"} | json |is_even="true" | line_format "在 {{.time}} 于 {{.level}}@{{.pod}} Pod中产生了日志 {{.msg}}"</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">来格式化日志输出</font>

![](https://cdn.nlark.com/yuque/0/2024/jpeg/2555283/1734345620863-880db100-e5ff-449f-b589-b722295500b5.jpeg)

## <font style="color:rgb(28, 30, 33);">监控大盘</font>
<font style="color:rgb(28, 30, 33);">这里我们以监控 Kubernetes 的事件为例进行说明。首先需要安装</font><font style="color:rgb(28, 30, 33);"> </font>[<font style="color:rgb(28, 30, 33);">kubernetes-event-exporter</font>](https://github.com/opsgenie/kubernetes-event-exporter/tree/master/deploy)<font style="color:rgb(28, 30, 33);">，</font>`<font style="color:rgb(28, 30, 33);">kubernetes-event-exporter</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">日志会打印到 stdout，然后我们的 promtail 会将日志上传到 Loki。</font>

![](https://cdn.nlark.com/yuque/0/2024/jpeg/2555283/1734345619904-f3cca97d-b8fc-42d3-97a7-c5102ea52276.jpeg)

<font style="color:rgb(28, 30, 33);">然后导入</font><font style="color:rgb(28, 30, 33);"> </font>[<font style="color:rgb(28, 30, 33);">https://grafana.com/grafana/dashboards/14003</font>](https://grafana.com/grafana/dashboards/14003)<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">这个 Dashboard 即可，不过需要注意修改每个图表中的过滤标签为</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">job="monitoring/event-exporter"</font>`<font style="color:rgb(28, 30, 33);">。</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734345620285-5efca1f4-b184-4cb5-8e10-a29390aa7bee.png)

<font style="color:rgb(28, 30, 33);">修改后正常就可以在 Dashboard 中看到集群中的相关事件信息了。</font>

![](https://cdn.nlark.com/yuque/0/2024/jpeg/2555283/1734345620851-b03262d9-cc52-416d-93b6-0b4ad12b86f2.jpeg)

## <font style="color:rgb(28, 30, 33);">建议</font>
1. <font style="color:rgb(28, 30, 33);">尽量使用静态标签，开销更小，通常日志在发送到 Loki 之前注入 label，推荐的静态标签包含：</font>
+ <font style="color:rgb(28, 30, 33);">宿主机：kubernetes/hosts</font>
+ <font style="color:rgb(28, 30, 33);">应用名：kubernetes/labels/app_kubernetes_io/name</font>
+ <font style="color:rgb(28, 30, 33);">组件名：kubernetes/labels/name</font>
+ <font style="color:rgb(28, 30, 33);">命名空间：kubernetes/namespace</font>
+ <font style="color:rgb(28, 30, 33);">其他静态标签，如环境、版本等</font>
1. <font style="color:rgb(28, 30, 33);">谨慎使用动态标签。 过多的标签组合会造成大量的流，它会让 Loki 存储大量的索引和小块的对象文件。这些都会显著消耗 Loki 的查询性能。为避免这些问题，</font>**<font style="color:rgb(28, 30, 33);">在你知道需要之前不要添加标签</font>**<font style="color:rgb(28, 30, 33);">。Loki 的优势在于并行查询，使用过滤器表达式（label="text", |~ "regex", ...）来查询日志会更有效，并且速度也很快。</font>
2. <font style="color:rgb(28, 30, 33);">有界的标签值范围，作为 Loki 的用户或操作员，我们的目标应该是使用尽可能少的标签来存储你的日志。这意味着，</font>**<font style="color:rgb(28, 30, 33);">更少的标签带来更小的索引，从而导致更好的性能</font>**<font style="color:rgb(28, 30, 33);">，所以我们在添加标签之前一定要三思而行。</font>
3. <font style="color:rgb(28, 30, 33);">配置缓存，Loki 可以为多个组件配置缓存, 可以选择 redis 或者 memcached，这可以显著提高性能。</font>
4. <font style="color:rgb(28, 30, 33);">合理使用 LogQL 语法，可大幅提高查询效率。Label matchers(标签匹配器)是你的第一道防线，是大幅减少你搜索的日志数量(例如，从 100TB 到 1TB)的最好方法。当然，这意味着你需要在日志采集端上有良好的标签定义规范。</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734345620917-5dffc258-f6c9-4284-a755-2b4ef9b299a1.png)

