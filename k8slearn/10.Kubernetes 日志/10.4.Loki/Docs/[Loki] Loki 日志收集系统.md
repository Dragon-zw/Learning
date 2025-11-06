![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734345196533-b3b94cf5-03d2-47be-84fb-bb53a4ae08fb.png)

`<font style="color:rgb(28, 30, 33);">Grafana Loki</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">是一套可以组合成一个功能齐全的日志堆栈组件，与其他日志记录系统不同，Loki 是基于仅索引有关日志元数据的想法而构建的：</font>**<font style="color:rgb(28, 30, 33);">标签</font>**<font style="color:rgb(28, 30, 33);">（就像 Prometheus 标签一样）。日志数据本身被压缩然后并存储在对象存储（例如 S3 或 GCS）的块中，甚至存储在本地文件系统上，轻量级的索引和高度压缩的块简化了操作，并显著降低了 Loki 的成本，Loki 更适合中小团队。由于 Loki 使用和 Prometheus 类似的标签概念，所以如果你熟悉 Prometheus 那么将很容易上手，也可以直接和 Grafana 集成，只需要添加 Loki 数据源就可以开始查询日志数据了。</font>

<font style="color:rgb(28, 30, 33);">Loki 还提供了一个专门用于日志查询的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">LogQL</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">查询语句，类似于</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">PromQL</font>`<font style="color:rgb(28, 30, 33);">，通过 LogQL 我们可以很容易查询到需要的日志，也可以很轻松获取监控指标。Loki 还能够将 LogQL 查询直接转换为 Prometheus 指标。此外 Loki 允许我们定义有关 LogQL 指标的报警，并可以将它们和 Alertmanager 进行对接。</font>

<font style="color:rgb(28, 30, 33);">Grafana Loki 主要由 3 部分组成:</font>

+ `<font style="color:rgb(28, 30, 33);">loki</font>`<font style="color:rgb(28, 30, 33);">: 日志记录引擎，负责存储日志和处理查询</font>
+ `<font style="color:rgb(28, 30, 33);">promtail</font>`<font style="color:rgb(28, 30, 33);">: 代理，负责收集日志并将其发送给 loki</font>
+ `<font style="color:rgb(28, 30, 33);">grafana</font>`<font style="color:rgb(28, 30, 33);">: UI 界面</font>

## <font style="color:rgb(28, 30, 33);">概述</font>
<font style="color:rgb(28, 30, 33);">Loki 是一组可以组成功能齐全的日志收集堆栈的组件，与其他日志收集系统不同，Loki 的构建思想是仅为日志建立索引标签，而使原始日志消息保持未索引状态。这意味着 Loki 的运营成本更低，并且效率更高。</font>

### <font style="color:rgb(28, 30, 33);">多租户</font>
<font style="color:rgb(28, 30, 33);">Loki 支持多租户，以使租户之间的数据完全分离。当 Loki 在多租户模式下运行时，所有数据（包括内存和长期存储中的数据）都由租户 ID 分区，该租户 ID 是从请求中的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">X-Scope-OrgID</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">HTTP 头中提取的。 当 Loki 不在多租户模式下时，将忽略 Header 头，并将租户 ID 设置为</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">fake</font>`<font style="color:rgb(28, 30, 33);">，这将显示在索引和存储的块中。</font>

### <font style="color:rgb(28, 30, 33);">运行模式</font>
![]()

<font style="color:rgb(28, 30, 33);">Loki 针对本地运行（或小规模运行）和水平扩展进行了优化，Loki 带有单一进程模式，可在一个进程中运行所有必需的微服务。单进程模式非常适合测试 Loki 或以小规模运行。为了实现水平可伸缩性，可以将 Loki 的服务拆分为单独的组件，从而使它们彼此独立地扩展。每个组件都产生一个用于内部请求的 gRPC 服务器和一个用于外部 API 请求的 HTTP 服务，所有组件都带有 HTTP 服务器，但是大多数只暴露就绪接口、运行状况和指标端点。</font>

<font style="color:rgb(28, 30, 33);">Loki 运行哪个组件取决于命令行中的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">-target</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">标志或 Loki 的配置文件中的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">target：<string></font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">配置。 当 target 的值为</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">all</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">时，Loki 将在单进程中运行其所有组件。，这称为</font>`<font style="color:rgb(28, 30, 33);">单进程</font>`<font style="color:rgb(28, 30, 33);">或</font>`<font style="color:rgb(28, 30, 33);">单体模式</font>`<font style="color:rgb(28, 30, 33);">。 使用 Helm 安装 Loki 时，单体模式是默认部署方式。</font>

<font style="color:rgb(28, 30, 33);">当 target 未设置为 all（即被设置为</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">querier</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">ingester</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">query-frontend</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">或</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">distributor</font>`<font style="color:rgb(28, 30, 33);">），则可以说 Loki 在</font>`<font style="color:rgb(28, 30, 33);">水平伸缩</font>`<font style="color:rgb(28, 30, 33);">或</font>`<font style="color:rgb(28, 30, 33);">微服务模式</font>`<font style="color:rgb(28, 30, 33);">下运行。</font>

<font style="color:rgb(28, 30, 33);">Loki 的每个组件，例如</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">ingester</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">和</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">distributors</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">都使用 Loki 配置中定义的 gRPC 监听端口通过 gRPC 相互通信。当以单体模式运行组件时，仍然是这样的，尽管每个组件都以相同的进程运行，但它们仍将通过本地网络相互连接进行组件之间的通信。</font>

<font style="color:rgb(28, 30, 33);">单体模式非常适合于本地开发、小规模等场景，单体模式可以通过多个进程进行扩展，但有以下限制：</font>

+ <font style="color:rgb(28, 30, 33);">当运行带有多个副本的单体模式时，当前无法使用本地索引和本地存储，因为每个副本必须能够访问相同的存储后端，并且本地存储对于并发访问并不安全。</font>
+ <font style="color:rgb(28, 30, 33);">各个组件无法独立缩放，因此读取组件的数量不能超过写入组件的数量。</font>

### <font style="color:rgb(28, 30, 33);">组件</font>
![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734345198467-0b2b21de-b2e4-4e7c-919f-ca73605c2d1d.png)

#### <font style="color:rgb(28, 30, 33);">Distributor</font>
`<font style="color:rgb(28, 30, 33);">distributor</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">服务负责处理客户端写入的日志，它本质上是日志数据写入路径中的</font>**<font style="color:rgb(28, 30, 33);">第一站</font>**<font style="color:rgb(28, 30, 33);">，一旦</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">distributor</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">收到日志数据，会将其拆分为多个批次，然后并行发送给多个</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">ingester</font>`<font style="color:rgb(28, 30, 33);">。</font>`<font style="color:rgb(28, 30, 33);">distributor</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">通过 gRPC 与</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">ingester</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">通信，它们都是无状态的，所以可以根据需要扩大或缩小规模。</font>

**<font style="color:rgb(28, 30, 33);">Hashing</font>**

`<font style="color:rgb(28, 30, 33);">distributor</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">将</font>**<font style="color:rgb(28, 30, 33);">一致性 Hash</font>**<font style="color:rgb(28, 30, 33);">和可配置的复制因子结合使用，以确定</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">ingester</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">服务的哪些实例应该接收指定的数据流。</font>

<font style="color:rgb(28, 30, 33);">流是一组与</font>**<font style="color:rgb(28, 30, 33);">租户和唯一标签集</font>**<font style="color:rgb(28, 30, 33);">关联的日志，使用租户 ID 和标签集对流进行 hash 处理，然后使用哈希查询要发送流的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">ingester</font>`<font style="color:rgb(28, 30, 33);">。</font>

<font style="color:rgb(28, 30, 33);">存储在</font><font style="color:rgb(28, 30, 33);"> </font>**<font style="color:rgb(28, 30, 33);">Consul/Etcd</font>**<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">中的哈希环被用来实现一致性哈希，所有的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">ingester</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">都会使用自己拥有的一组 Token 注册到哈希环中，每个 Token 是一个随机的无符号 32 位数字，与一组 Token 一起，</font>`<font style="color:rgb(28, 30, 33);">ingester</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">将其状态注册到哈希环中，状态</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">JOINING</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">和</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">ACTIVE</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">都可以接收写请求，而</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">ACTIVE</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">和</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">LEAVING</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">ingester</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">可以接收读请求。在进行哈希查询时，</font>`<font style="color:rgb(28, 30, 33);">distributor</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">只使用处于请求的适当状态的 ingester 的 Token。</font>

<font style="color:rgb(28, 30, 33);">为了进行哈希查找，</font>`<font style="color:rgb(28, 30, 33);">distributor</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">找到最小合适的 Token，其值大于日志流的哈希值，当复制因子大于 1 时，属于不同</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">ingester</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">的下一个后续 Token（在环中顺时针方向）也将被包括在结果中。</font>

<font style="color:rgb(28, 30, 33);">这种哈希配置的效果是，一个</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">ingester</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">拥有的每个 Token 都负责一个范围的哈希值，如果有三个值为 0、25 和 50 的 Token，那么 3 的哈希值将被给予拥有 25 这个 Token 的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">ingester</font>`<font style="color:rgb(28, 30, 33);">，拥有 25 这个 Token 的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">ingester</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">负责</font>`<font style="color:rgb(28, 30, 33);">1-25</font>`<font style="color:rgb(28, 30, 33);">的哈希值范围。</font>

#### <font style="color:rgb(28, 30, 33);">Ingester</font>
`<font style="color:rgb(28, 30, 33);">ingester</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">负责接收</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">distributor</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">发送过来的日志数据，存储日志的索引数据以及内容数据。此外</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">ingester</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">会验证摄取的日志行是否按照时间戳递增的顺序接收的（即每条日志的时间戳都比前面的日志晚一些），当</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">ingester</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">收到不符合这个顺序的日志时，该日志行会被拒绝并返回一个错误。</font>

+ <font style="color:rgb(28, 30, 33);">如果传入的行与之前收到的行完全匹配（与之前的时间戳和日志文本都匹配），传入的行将被视为完全重复并被忽略。</font>
+ <font style="color:rgb(28, 30, 33);">如果传入的行与前一行的时间戳相同，但内容不同，则接受该日志行，表示同一时间戳有两个不同的日志行是可能的。</font>

<font style="color:rgb(28, 30, 33);">来自每个唯一标签集的日志在内存中被建立成</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">chunks(块)</font>`<font style="color:rgb(28, 30, 33);">，然后可以根据配置的时间间隔刷新到支持的后端存储。在下列情况下，块被压缩并标记为只读：</font>

+ <font style="color:rgb(28, 30, 33);">当前块容量已满（该值可配置）</font>
+ <font style="color:rgb(28, 30, 33);">过了太长时间没有更新当前块的内容</font>
+ <font style="color:rgb(28, 30, 33);">刷新了</font>

<font style="color:rgb(28, 30, 33);">每当一个数据块被压缩并标记为只读时，一个可写的数据块就会取代它。如果一个</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">ingester</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">进程崩溃或突然退出，所有尚未刷新的数据都会丢失，Loki 通常配置为多个副本来</font>**<font style="color:rgb(28, 30, 33);">降低</font>**<font style="color:rgb(28, 30, 33);">这种风险。</font>

<font style="color:rgb(28, 30, 33);">当向持久存储刷新时，该块将根据其租户、标签和内容进行哈希处理，这意味着具有相同数据副本的多个</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">ingester</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">实例不会将相同的数据两次写入备份存储中，但如果对其中一个副本的写入失败，则会在备份存储中创建多个不同的块对象。</font>

**<font style="color:rgb(28, 30, 33);">WAL</font>**

<font style="color:rgb(28, 30, 33);">上面我们提到了</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">ingester</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">将数据临时存储在内存中，如果发生了崩溃，可能会导致数据丢失，而</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">WAL</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">就可以帮助我们来提高这方面的可靠性。</font>

<font style="color:rgb(28, 30, 33);">在计算机领域，WAL（Write-ahead logging，预写式日志）是数据库系统提供原子性和持久化的一系列技术。</font>

<font style="color:rgb(28, 30, 33);">在使用 WAL 的系统中，所有的修改都先被写入到日志中，然后再被应用到系统状态中。通常包含 redo 和 undo 两部分信息。为什么需要使用 WAL，然后包含 redo 和 undo 信息呢？举个例子，如果一个系统直接将变更应用到系统状态中，那么在机器断电重启之后系统需要知道操作是成功了，还是只有部分成功或者是失败了（为了恢复状态）。如果使用了 WAL，那么在重启之后系统可以通过比较日志和系统状态来决定是继续完成操作还是撤销操作。</font>

`<font style="color:rgb(28, 30, 33);">redo log</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">称为重做日志，每当有操作时，在数据变更之前将操作写入</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">redo log</font>`<font style="color:rgb(28, 30, 33);">，这样当发生断电之类的情况时系统可以在重启后继续操作。</font>`<font style="color:rgb(28, 30, 33);">undo log</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">称为撤销日志，当一些变更执行到一半无法完成时，可以根据撤销日志恢复到变更之间的状态。</font>

<font style="color:rgb(28, 30, 33);">Loki 中的 WAL 记录了传入的数据，并将其存储在本地文件系统中，以保证在进程崩溃的情况下持久保存已确认的数据。重新启动后，Loki 将</font>**<font style="color:rgb(28, 30, 33);">重放</font>**<font style="color:rgb(28, 30, 33);">日志中的所有数据，然后将自身注册，准备进行后续写操作。这使得 Loki 能够保持在内存中缓冲数据的性能和成本优势，以及持久性优势（一旦写被确认，它就不会丢失数据）。</font>

#### <font style="color:rgb(28, 30, 33);">Querier</font>
`<font style="color:rgb(28, 30, 33);">Querier</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">接收日志数据查询、聚合统计请求，使用 LogQL 查询语言处理查询，从</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">ingester</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">和长期存储中获取日志。</font>

<font style="color:rgb(28, 30, 33);">查询器查询所有</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">ingester</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">的内存数据，然后再到后端存储运行相同的查询。由于复制因子，查询器有可能会收到重复的数据。为了解决这个问题，查询器在内部对具有相同纳秒时间戳、标签集和日志信息的数据进行重复数据删除。</font>

#### <font style="color:rgb(28, 30, 33);">Query Frontend</font>
`<font style="color:rgb(28, 30, 33);">Query Frontend</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">查询前端是一个可选的服务，可以用来加速读取路径。当查询前端就位时，将传入的查询请求定向到查询前端，而不是</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">querier</font>`<font style="color:rgb(28, 30, 33);">, 为了执行实际的查询，群集中仍需要</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">querier</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">服务。</font>

<font style="color:rgb(28, 30, 33);">查询前端在内部执行一些查询调整，并在内部队列中保存查询。</font>`<font style="color:rgb(28, 30, 33);">querier</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">作为 workers 从队列中提取作业，执行它们，并将它们返回到查询前端进行汇总。</font>`<font style="color:rgb(28, 30, 33);">querier</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">需要配置查询前端地址，以便允许它们连接到查询前端。</font>

<font style="color:rgb(28, 30, 33);">查询前端是无状态的，然而，由于内部队列的工作方式，建议运行几个查询前台的副本，以获得公平调度的好处，在大多数情况下，两个副本应该足够了。</font>

**<font style="color:rgb(28, 30, 33);">队列</font>**

<font style="color:rgb(28, 30, 33);">查询前端的排队机制用于：</font>

+ <font style="color:rgb(28, 30, 33);">确保可能导致</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">querier</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">出现内存不足（OOM）错误的查询在失败时被重试。这样管理员就可以为查询提供稍低的内存，或者并行运行更多的小型查询，这有助于降低总成本。</font>
+ <font style="color:rgb(28, 30, 33);">通过使用先进先出队列（FIFO）将多个大型请求分配到所有</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">querier</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">上，以防止在单个</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">querier</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">中进行多个大型请求。</font>
+ <font style="color:rgb(28, 30, 33);">通过在租户之间公平调度查询。</font>

**<font style="color:rgb(28, 30, 33);">分割</font>**

<font style="color:rgb(28, 30, 33);">查询前端将较大的查询分割成多个较小的查询，在下游</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">querier</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">上并行执行这些查询，并将结果再次拼接起来。这可以防止大型查询在单个查询器中造成内存不足的问题，并有助于更快地执行这些查询。</font>

**<font style="color:rgb(28, 30, 33);">缓存</font>**

<font style="color:rgb(28, 30, 33);">查询前端支持缓存查询结果，并在后续查询中重复使用。如果缓存的结果不完整，查询前端会计算所需的子查询，并在下游</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">querier</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">上并行执行这些子查询。查询前端可以选择将查询与其</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">step</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">参数对齐，以提高查询结果的可缓存性。</font>

#### <font style="color:rgb(28, 30, 33);">读取路径</font>
<font style="color:rgb(28, 30, 33);">日志读取路径的流程如下所示：</font>

+ <font style="color:rgb(28, 30, 33);">查询器收到一个对数据的 HTTP 请求。</font>
+ <font style="color:rgb(28, 30, 33);">查询器将查询传递给所有</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">ingester</font>`<font style="color:rgb(28, 30, 33);">。</font>
+ `<font style="color:rgb(28, 30, 33);">ingester</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">收到读取请求，并返回与查询相匹配的数据。</font>
+ <font style="color:rgb(28, 30, 33);">如果没有</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">ingester</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">返回数据，查询器会从后端存储加载数据，并对其运行查询。</font>
+ <font style="color:rgb(28, 30, 33);">查询器对所有收到的数据进行迭代和重复计算，通过 HTTP 连接返回最后一组数据。</font>

#### <font style="color:rgb(28, 30, 33);">写入路径</font>
![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734345197290-9d385336-3c1b-42b5-8412-9cd4db6d47e1.png)

<font style="color:rgb(28, 30, 33);">整体的日志写入路径如下所示：</font>

+ `<font style="color:rgb(28, 30, 33);">distributor</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">收到一个 HTTP 请求，以存储流的数据。</font>
+ <font style="color:rgb(28, 30, 33);">每个流都使用哈希环进行哈希操作。</font>
+ `<font style="color:rgb(28, 30, 33);">distributor</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">将每个流发送到合适的</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">ingester</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">和他们的副本（基于配置的复制因子）。</font>
+ <font style="color:rgb(28, 30, 33);">每个</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">ingester</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">将为日志流数据创建一个块或附加到一个现有的块上。每个租户和每个标签集的块是唯一的。</font>

## <font style="color:rgb(28, 30, 33);">安装</font>
<font style="color:rgb(28, 30, 33);">首先添加 Loki 的 Chart 仓库：</font>

```shell
$ helm repo add grafana https://grafana.github.io/helm-charts
$ helm repo update
```

<font style="color:rgb(28, 30, 33);">获取</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">loki-stack</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">的 Chart 包并解压：</font>

```shell
$ helm pull grafana/loki-stack --untar --version 2.6.4
```

`<font style="color:rgb(28, 30, 33);">loki-stack</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">这个 Chart 包里面包含所有的 Loki 相关工具依赖，在安装的时候可以根据需要开启或关闭，比如我们想要安装 Grafana，则可以在安装的时候简单设置</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">--set grafana.enabled=true</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">即可。默认情况下</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">loki</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:rgb(28, 30, 33);">promtail</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">是自动开启的，也可以根据我们的需要选择使用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">filebeat</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">或者</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">logstash</font>`<font style="color:rgb(28, 30, 33);">，同样在 Chart 包根目录下面创建用于安装的 Values 文件：</font>

```yaml
# values-prod.yaml
loki:
  enabled: true
  replicas: 1
  rbac:
    pspEnabled: false
  persistence:
    enabled: true
    storageClassName: local-path

promtail:
  enabled: true
  rbac:
    pspEnabled: false

grafana:
  enabled: true
  service:
    type: NodePort
  rbac:
    pspEnabled: false
  persistence:
    enabled: true
    storageClassName: local-path
    accessModes:
      - ReadWriteOnce
    size: 1Gi
```

<font style="color:rgb(28, 30, 33);">然后直接使用上面的 Values 文件进行安装即可：</font>

```shell
$ helm upgrade --install loki -n logging -f values-prod.yaml .
Release "loki" does not exist. Installing it now.
NAME: loki
LAST DEPLOYED: Tue Jun 14 14:45:50 2022
NAMESPACE: logging
STATUS: deployed
REVISION: 1
NOTES:
The Loki stack has been deployed to your cluster. Loki can now be added as a datasource in Grafana.

See http://docs.grafana.org/features/datasources/loki/ for more detail.
```

<font style="color:rgb(28, 30, 33);">安装完成后可以查看 Pod 的状态：</font>

```shell
$ kubectl get pods -n logging
NAME                            READY   STATUS    RESTARTS   AGE
loki-0                          1/1     Running   0          5m19s
loki-grafana-5f9df99f6d-8rwbz   2/2     Running   0          5m19s
loki-promtail-ptxxl             1/1     Running   0          5m19s
loki-promtail-xc55z             1/1     Running   0          5m19s
loki-promtail-zg9tv             1/1     Running   0          5m19s
```

<font style="color:rgb(28, 30, 33);">这里我们为 Grafana 设置的 NodePort 类型的 Service：</font>

```shell
$ kubectl get svc -n logging
NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
loki            ClusterIP   10.104.186.9    <none>        3100/TCP       5m34s
loki-grafana    NodePort    10.110.58.196   <none>        80:31634/TCP   5m34s
loki-headless   ClusterIP   None            <none>        3100/TCP       5m34s
```

<font style="color:rgb(28, 30, 33);">可以通过 NodePort 端口</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">31634</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">访问 Grafana，使用下面的命令获取 Grafana 的登录密码：</font>

```shell
$ kubectl get secret --namespace logging loki-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

<font style="color:rgb(28, 30, 33);">使用用户名</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">admin</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">和上面的获取的密码即可登录 Grafana，由于 Helm Chart 已经为 Grafana 配置好了 Loki 的数据源，所以我们可以直接获取到日志数据了。点击左侧</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">Explore</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">菜单，然后就可以筛选 Loki 的日志数据了：</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734345202804-bf598f61-aef6-4e66-8cde-6b72c4c7a9f9.png)

<font style="color:rgb(28, 30, 33);">我们使用 Helm 安装的 Promtail 默认已经帮我们做好了配置，已经针对 Kubernetes 做了优化，我们可以查看其配置：</font>

```yaml
$ kubectl get secret loki-promtail -n logging -o json | jq -r '.data."promtail.yaml"' | base64 --decode
server:
  log_level: info
  http_listen_port: 3101

client:
  url: http://loki:3100/loki/api/v1/push


positions:
  filename: /run/promtail/positions.yaml

scrape_configs:
  # See also https://github.com/grafana/loki/blob/master/production/ksonnet/promtail/scrape_config.libsonnet for reference
  - job_name: kubernetes-pods
    pipeline_stages:
      - cri: {}
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels:
          - __meta_kubernetes_pod_controller_name
        regex: ([0-9a-z-.]+?)(-[0-9a-f]{8,10})?
        action: replace
        target_label: __tmp_controller_name
      - source_labels:
          - __meta_kubernetes_pod_label_app_kubernetes_io_name
          - __meta_kubernetes_pod_label_app
          - __tmp_controller_name
          - __meta_kubernetes_pod_name
        regex: ^;*([^;]+)(;.*)?$
        action: replace
        target_label: app
      - source_labels:
          - __meta_kubernetes_pod_label_app_kubernetes_io_component
          - __meta_kubernetes_pod_label_component
        regex: ^;*([^;]+)(;.*)?$
        action: replace
        target_label: component
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_node_name
        target_label: node_name
      - action: replace
        source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - action: replace
        replacement: $1
        separator: /
        source_labels:
        - namespace
        - app
        target_label: job
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_name
        target_label: pod
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_container_name
        target_label: container
      - action: replace
        replacement: /var/log/pods/*$1/*.log
        separator: /
        source_labels:
        - __meta_kubernetes_pod_uid
        - __meta_kubernetes_pod_container_name
        target_label: __path__
      - action: replace
        regex: true/(.*)
        replacement: /var/log/pods/*$1/*.log
        separator: /
        source_labels:
        - __meta_kubernetes_pod_annotationpresent_kubernetes_io_config_hash
        - __meta_kubernetes_pod_annotation_kubernetes_io_config_hash
        - __meta_kubernetes_pod_container_name
        target_label: __path__
```

## <font style="color:rgb(28, 30, 33);">收集 Traefik 日志</font>
<font style="color:rgb(28, 30, 33);">这里我们以收集 Traefik 为例，为 Traefik 定制一个可视化的 Dashboard，默认情况下访问日志没有输出到 stdout，我们可以通过在命令行参数中设置</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">--accesslog=true</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">来开启，此外我们还可以设置访问日志格式为 json，这样更方便在 Loki 中查询使用：</font>

```yaml
containers:
- args:
  - --accesslog=true
  - --accesslog.format=json
  ......
```

<font style="color:rgb(28, 30, 33);">默认 traefik 的日志输出为 stdout，如果你的采集端是通过读取文件的话，则需要用 filePath 参数将 traefik 的日志重定向到文件目录。</font>

<font style="color:rgb(28, 30, 33);">修改完成后正常在 Grafana 中就可以看到 Traefik 的访问日志了：</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734345203039-4c1f1c53-87b8-49c7-9558-8de070a5e79b.png)

<font style="color:rgb(28, 30, 33);">然后我们还可以导入 Dashboard 来展示 Traefik 的信息：</font>[<font style="color:rgb(28, 30, 33);">https://grafana.com/grafana/dashboards/13713</font>](https://grafana.com/grafana/dashboards/13713)<font style="color:rgb(28, 30, 33);">，在 Grafana 中导入 13713 号 Dashboard：</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734345198760-7159f0b7-d9ca-4bcd-81a0-185fabf086f7.png)

<font style="color:rgb(28, 30, 33);">不过要注意我们需要更改 Dashboard 里面图表的查询语句，将 job 的值更改为你实际的标签，比如我这里采集 Traefik 日志的最终标签为</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">job="kube-system/traefik"</font>`<font style="color:rgb(28, 30, 33);">：</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734345200234-ba3ebd29-7163-4c23-9359-9e948691ccd7.png)

<font style="color:rgb(28, 30, 33);">此外该 Dashboard 上还出现了</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">Panel plugin not found: grafana-piechart-panel</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">这样的提示，这是因为该面板依赖</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">grafana-piechart-panel</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">这个插件，我们进入 Grafana 容器内安装重建 Pod 即可：</font>

```shell
$ kubectl exec -it loki-grafana-864fc6999c-z9587 -n logging -- /bin/bash
bash-5.0$ grafana-cli plugins install grafana-piechart-panel
installing grafana-piechart-panel @ 1.6.1
from: https://grafana.com/api/plugins/grafana-piechart-panel/versions/1.6.1/download
into: /var/lib/grafana/plugins

✔ Installed grafana-piechart-panel successfully

Restart grafana after installing plugins . <service grafana-server restart>
```

<font style="color:rgb(28, 30, 33);">由于上面我们安装的时候为 Grafana 持久化了数据，所以删掉 Pod 重建即可：</font>

```shell
kubectl delete pod loki-grafana-864fc6999c-z9587 -n logging
pod "loki-grafana-864fc6999c-z9587" deleted
```

<font style="color:rgb(28, 30, 33);">最后调整过后的 Traefik Dashboard 大盘效果如下所示：</font>

![](https://cdn.nlark.com/yuque/0/2024/png/2555283/1734345200684-482e8d80-57ea-4b61-91b7-4cd76414e8e5.png)

