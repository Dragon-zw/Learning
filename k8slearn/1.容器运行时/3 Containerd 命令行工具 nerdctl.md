# 安装 nerdctl

```sh
➜  ~ wget https://github.com/containerd/nerdctl/releases/download/v2.1.6/nerdctl-2.1.6-linux-amd64.tar.gz
➜  ~ mkdir -p /usr/local/containerd/bin/ && tar -zxvf nerdctl-2.1.6-linux-amd64.tar.gz nerdctl && mv nerdctl /usr/local/containerd/bin/
➜  ~ ln -s /usr/local/containerd/bin/nerdctl /usr/local/bin/nerdctl
# 查看版本信息
➜  ~ nerdctl version
```

# nerdctl 命令

## Run & Exec

```sh
# 运行容器
➜  ~ nerdctl run -d -p 1080:80 --name=nginx --restart=always nginx:alpine

# 查看容器信息
➜  ~ nerdctl ps 

# 进入到容器中执行容器相关命令
➜  ~ nerdctl exec -it nginx /bin/sh
```

## 容器管理

```sh
# 列出容器
➜  ~ nerdctl ps

# 获取容器的详细信息
➜  ~ nerdctl inspect nginx

# 获取容器日志
➜  ~ nerdctl logs -f nginx

# 停止容器
➜  ~ nerdctl stop nginx

# 查看所有的容器
➜  ~ nerdctl ps -a

# 删除容器
➜  ~ nerdctl rm nginx

# 强制删除容器
➜  ~ nerdctl rm -f nginx
```

## 镜像管理

```sh
# 拉取镜像
➜  ~ nerdctl pull alpine:latest
➜  ~ nerdctl pull docker.io/library/busybox:latest

# 列出镜像
➜  ~ nerdctl images

# 一个镜像创建一个别名镜像
➜  ~ nerdctl tag nginx:alpine harbor.k8s.local/course/nginx:alpine

# 导出镜像
➜  ~ nerdctl save -o busybox.tar.gz busybox:latest

# 删除镜像
➜  ~ nerdctl rmi busybox

# 导入镜像
➜  ~ nerdctl load -i busybox.tar.gz 
```

## 镜像构建
```sh
➜  ~ wget https://github.com/moby/buildkit/releases/download/v0.25.1/buildkit-v0.25.1.linux-amd64.tar.gz
➜  ~ tar -zxvf buildkit-v0.25.1.linux-amd64.tar.gz -C /usr/local/containerd/
➜  ~ ln -s /usr/local/containerd/bin/buildkitd /usr/local/bin/buildkitd
➜  ~ ln -s /usr/local/containerd/bin/buildctl /usr/local/bin/buildctl
➜  ~ cat <<EOF > /etc/systemd/system/buildkit.service
[Unit]
Description=BuildKit
Documentation=https://github.com/moby/buildkit

[Service]
ExecStart=/usr/local/bin/buildkitd --oci-worker=false --containerd-worker=true

[Install]
WantedBy=multi-user.target
EOF
➜  ~ systemctl daemon-reload
➜  ~ systemctl status -l --no-page buildkit.service

# 构建镜像
➜  ~ nerdctl build -t nginx:nerdctl -f Dockerfile .
```
