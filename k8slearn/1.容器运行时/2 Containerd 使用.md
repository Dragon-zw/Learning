# 镜像操作

```sh
# 拉取镜像
➜  ~ ctr image pull docker.io/library/nginx:alpine

# 拉取本地镜像
➜  ~ ctr image ls

# 只打印镜像的名称
➜  ~ ctr image ls -q

# 检测本地镜像
➜  ~ ctr image check

# 镜像重新打标签
➜  ~ ctr image tag docker.io/library/nginx:alpine harbor.k8s.local/course/nginx:alpine

# 删除镜像
➜  ~ ctr image rm harbor.k8s.local/course/nginx:alpine

# 将镜像挂载到主机目录
➜  ~ ctr image mount docker.io/library/nginx:alpine /mnt

# 将镜像从主机目录上卸载
➜  ~ ctr image unmount /mnt

# 拉取所有平台的镜像
➜  ~ ctr image pull --all-platforms docker.io/library/nginx:alpine

# 将镜像导出为压缩包
➜  ~ ctr image export --all-platforms nginx.tar.gz docker.io/library/nginx:alpine

# 删除镜像
➜  ~ ctr image rm --sync docker.io/library/nginx:alpine
docker.io/library/nginx:alpine

# 导入镜像
➜  ~ ctr image import nginx.tar.gz
```

# 容器操作
```sh
# 创建容器
➜  ~ ctr container create docker.io/library/nginx:alpine nginx

# 列出容器
➜  ~ ctr container ls

# 只列出容器名称
➜  ~ ctr container ls -q

# 查看容器详细配置
➜  ~ ctr container info nginx

# 删除容器
➜  ~ ctr container rm nginx
```

# 任务操作
```sh
# -d 后台运行
➜  ~ ctr task start -d nginx

# 查看正在运行的容器
➜  ~ ctr task ls

# 进入容器进行操作
➜  ~ ctr task exec --exec-id 0 -t nginx /bin/sh

# 暂停容器
➜  ~ ctr task pause nginx

# 恢复容器
➜  ~ ctr task resume nginx

# 杀死容器
➜  ~ ctr task kill nginx

# 用来获取容器的内存、CPU 和 PID 的限额与使用量
➜  ~ ctr task metrics nginx

# 杀死容器
➜  ~ ctr task kill nginx

# 查看容器中所有进程在宿主机中的 PID
➜  ~ ctr task ps nginx
```

# 命名空间
```sh
# 查看命名空间
➜  ~ ctr ns ls

# 创建一个命名空间
➜  ~ ctr ns create test

# 删除 namespace
➜  ~ ctr ns rm test
```
