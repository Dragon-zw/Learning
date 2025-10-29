# CGroups 概述

```sh
# 查看 /proc/cgroups 文件来查找当前系统支持的 CGroups 子系统：
cat /proc/cgroups 

CGroups 支持的子系统包含以下几类，即为每种可以控制的资源定义了一个子系统:
● cpuset: 为 cgroup 中的进程分配单独的 CPU 节点，即可以绑定到特定的 CPU
● cpu: 限制 cgroup 中进程的 CPU 使用份额
● cpuacct: 统计 cgroup 中进程的 CPU 使用情况
● memory: 限制 cgroup 中进程的内存使用,并能报告内存使用情况
● devices: 控制 cgroup 中进程能访问哪些文件设备(设备文件的创建、读写)
● freezer: 挂起或恢复 cgroup 中的 task
● net_cls: 可以标记 cgroups 中进程的网络数据包，然后可以使用 tc 模块(traffic contro)对数据包进行控制
● blkio: 限制 cgroup 中进程的块设备 IO
● perf_event: 监控 cgroup 中进程的 perf 时间，可用于性能调优
● hugetlb: hugetlb 的资源控制功能
● pids: 限制 cgroup 中可以创建的进程数
● net_prio: 允许管理员动态的通过各种应用程序设置网络传输的优先级

# mount --type cgroup命令查看当前系统挂载了哪些 cgroup
```

# CGroup 测试

```sh
➜  ~ mkdir -p /sys/fs/cgroup/cpu/ydzs.test
➜  ~ ls /sys/fs/cgroup/cpu/ydzs.test

➜  ~ cat /sys/fs/cgroup/cpu/ydzs.test/cpu.cfs_period_us
100000
➜  ~ cat /sys/fs/cgroup/cpu/ydzs.test/cpu.cfs_quota_us
-1
```

# Namespaces
```sh
lsns 命令查看当前系统已经创建的命名空间

```
