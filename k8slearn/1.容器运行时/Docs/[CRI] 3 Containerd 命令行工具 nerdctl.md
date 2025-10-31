<font style="color:rgb(28, 30, 33);">前面我们介绍了可以使用 </font>`<font style="color:#DF2A3F;">ctr</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">操作管理 containerd 镜像容器，但是大家都习惯了使用 Docker CLI，</font>`<font style="color:#DF2A3F;">ctr</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">使用起来可能还是不太顺手，为了</font><font style="color:#601BDE;">能够让大家更好的转到 containerd 上面来，社区提供了一个新的命令行工具：</font>[<font style="color:#117CEE;">nerdctl</font>](https://github.com/containerd/nerdctl)<font style="color:rgb(28, 30, 33);">。nerdctl 是一个与 Docker CLI 风格兼容的 </font>`<font style="color:rgb(28, 30, 33);">containerd</font>`<font style="color:rgb(28, 30, 33);"> 客户端工具，而且直接兼容 </font>`<font style="color:#DF2A3F;">docker compose</font>`<font style="color:rgb(28, 30, 33);"> 的语法的，这就大大提高了直接将 </font>`<font style="color:rgb(28, 30, 33);">containerd</font>`<font style="color:rgb(28, 30, 33);"> 作为本地开发、测试或者单机容器部署使用的效率。</font>

## <font style="color:rgb(28, 30, 33);">1 安装 nerdctl</font>
<font style="color:rgb(28, 30, 33);">同样直接在 GitHub Release 页面下载对应的压缩包解压到 PATH 路径下即可：</font>

> GitHub Reference：[https://github.com/containerd/nerdctl/releases](https://github.com/containerd/nerdctl/releases)
>

```shell
####################################
# nerdctl Version: v0.12.1
####################################
# 如果没有安装 containerd，则可以下载 nerdctl-full-<VERSION>-linux-amd64.tar.gz 包进行安装
➜  ~ wget https://github.com/containerd/nerdctl/releases/download/v0.12.1/nerdctl-0.12.1-linux-amd64.tar.gz
# 如果有限制，也可以替换成下面的 URL 加速下载
# wget https://download.fastgit.org/containerd/nerdctl/releases/download/v0.12.1/nerdctl-0.12.1-linux-amd64.tar.gz
➜  ~ mkdir -p /usr/local/containerd/bin/ && tar -zxvf nerdctl-0.12.1-linux-amd64.tar.gz nerdctl && mv nerdctl /usr/local/containerd/bin/
➜  ~ ln -s /usr/local/containerd/bin/nerdctl /usr/local/bin/nerdctl
➜  ~ nerdctl version
Client:
 Version:       v0.12.1
 Git commit:    c802f934791f83dacf20a041cd1c865f8fac954e

Server:
 containerd:
  Version:      v1.5.5
  Revision:     72cec4be58a9eb6b2910f5d10f1c01ca47d231c0

####################################
# nerdctl Version: v2.1.6
####################################
➜  ~ wget https://github.com/containerd/nerdctl/releases/download/v2.1.6/nerdctl-2.1.6-linux-amd64.tar.gz
➜  ~ mkdir -p /usr/local/containerd/bin/ && tar -zxvf nerdctl-2.1.6-linux-amd64.tar.gz nerdctl && mv nerdctl /usr/local/containerd/bin/
➜  ~ ln -s /usr/local/containerd/bin/nerdctl /usr/local/bin/nerdctl
# 查看版本信息
➜  ~ nerdctl version
WARN[0000] unable to determine buildctl version          error="exec: \"buildctl\": executable file not found in $PATH"
Client:
 Version:       v2.1.6
 OS/Arch:       linux/amd64
 Git commit:    59253e9931873e79b92fe3400f14e69d6be34025
 buildctl:
  Version:

Server:
 containerd:
  Version:      v1.7.7
  GitCommit:    8c087663b0233f6e6e2f4515cee61d49f14746a8
 runc:
  Version:      1.1.4
  GitCommit:    v1.1.4-0-g5fd4c4d1
```

<font style="color:rgb(28, 30, 33);">安装完成后接下来学习下 </font>`<font style="color:#DF2A3F;">nerdctl</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">命令行工具的使用。</font>

## <font style="color:rgb(28, 30, 33);">2 </font>**<font style="color:rgb(28, 30, 33);">nerdctl </font>**<font style="color:rgb(28, 30, 33);">命令</font>
### <font style="color:rgb(28, 30, 33);">2.1 Run & Exec</font>
**<font style="color:rgb(28, 30, 33);">🐳</font>**`**<font style="color:rgb(28, 30, 33);">nerdctl run</font>**`

<font style="color:rgb(28, 30, 33);">和 </font>`<font style="color:#DF2A3F;">docker run</font>`<font style="color:rgb(28, 30, 33);"> 类似可以使用 </font>`<font style="color:#DF2A3F;">nerdctl run</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">命令运行容器，例如：</font>

```shell
# 运行容器
➜  ~ nerdctl run -d -p 1080:80 --name=nginx --restart=always nginx:alpine
docker.io/library/nginx:alpine:                                                   resolved       |++++++++++++++++++++++++++++++++++++++| 
index-sha256:61e01287e546aac28a3f56839c136b31f590273f3b41187a36f46f6a03bbfe22:    done           |++++++++++++++++++++++++++++++++++++++| 
manifest-sha256:b03ccb7431a2e3172f5cbae96d82bd792935f33ecb88fbf2940559e475745c4e: done           |++++++++++++++++++++++++++++++++++++++| 
config-sha256:5e7abcdd20216bbeedf1369529564ffd60f830ed3540c477938ca580b645dff5:   done           |++++++++++++++++++++++++++++++++++++++| 
elapsed: 4.7 s                                                                    total:  12.5 K (2.7 KiB/s)   

➜  ~ nerdctl run -t -d -p 2080:80 --name=nginx  --restart=always nginx:alpine
```

<font style="color:rgb(28, 30, 33);">可选的参数使用和 </font>`<font style="color:#DF2A3F;">docker run</font>`<font style="color:rgb(28, 30, 33);"> 基本一直，比如 </font>`<font style="color:#DF2A3F;">-i</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:#DF2A3F;">-t</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:#DF2A3F;">--cpus</font>`<font style="color:rgb(28, 30, 33);">、</font>`<font style="color:#DF2A3F;">--memory</font>`<font style="color:rgb(28, 30, 33);"> 等选项，可以使用 </font>`<font style="color:#DF2A3F;">nerdctl run --help</font>`<font style="color:rgb(28, 30, 33);"> 获取可使用的命令选项：</font>

```shell
####################################
# nerdctl Version: v0.12.1
####################################
➜  ~ nerdctl run --help
NAME:
   nerdctl run - Run a command in a new container

USAGE:
   nerdctl run [command options] [arguments...]

OPTIONS:
   --help                        show help (default: false)
   --tty, -t                     (Currently -t needs to correspond to -i) (default: false)
   --interactive, -i             Keep STDIN open even if not attached (default: false)
   --detach, -d                  Run container in background and print container ID (default: false)
   --restart value               Restart policy to apply when a container exits (implemented values: "no"|"always") (default: "no")
   --rm                          Automatically remove the container when it exits (default: false)
   --pull value                  Pull image before running ("always"|"missing"|"never") (default: "missing")
   --network value, --net value  Connect a container to a network ("bridge"|"host"|"none") (default: "bridge")
   --dns value                   Set custom DNS servers (default: "8.8.8.8", "1.1.1.1")
   --publish value, -p value     Publish a container's port(s) to the host
   --hostname value, -h value    Container host name
   --cpus value                  Number of CPUs (default: 0)
   --memory value, -m value      Memory limit
   --pid value                   PID namespace to use
   --pids-limit value            Tune container pids limit (set -1 for unlimited) (default: -1)
   --cgroupns value              Cgroup namespace to use, the default depends on the cgroup version ("host"|"private") (default: "host")
   --cpuset-cpus value           CPUs in which to allow execution (0-3, 0,1)
   --cpu-shares value            CPU shares (relative weight) (default: 0)
   --device value                Add a host device to the container
   --user value, -u value        Username or UID (format: <name|uid>[:<group|gid>])
   --security-opt value          Security options
   --cap-add value               Add Linux capabilities
   --cap-drop value              Drop Linux capabilities
   --privileged                  Give extended privileges to this container (default: false)
   --runtime value               Runtime to use for this container, e.g. "crun", or "io.containerd.runsc.v1" (default: "io.containerd.runc.v2")
   --sysctl value                Sysctl options
   --gpus value                  GPU devices to add to the container ('all' to pass all GPUs)
   --volume value, -v value      Bind mount a volume
   --read-only                   Mount the container's root filesystem as read only (default: false)
   --rootfs                      The first argument is not an image but the rootfs to the exploded container (default: false)
   --entrypoint value            Overwrite the default ENTRYPOINT of the image
   --workdir value, -w value     Working directory inside the container
   --env value, -e value         Set environment variables
   --env-file value              Set environment variables from file
   --name value                  Assign a name to the container
   --label value, -l value       Set meta data on a container
   --label-file value            Read in a line delimited file of labels
   --cidfile value               Write the container ID to the file
   --shm-size value              Size of /dev/shm

####################################
# nerdctl Version: v2.1.6
####################################
➜  ~ nerdctl run --help
Run a command in a new container. Optionally specify "ipfs://" or "ipns://" scheme to pull image from IPFS.

Usage: nerdctl run [flags] IMAGE [COMMAND] [ARG...]

Flags:
      --add-host strings                               Add a custom host-to-IP mapping (host:ip)
      --annotation stringArray                         Add an annotation to the container (passed through to the OCI runtime)
  -a, --attach strings                                 Attach STDIN, STDOUT, or STDERR
      --blkio-weight uint16                            Block IO (relative weight), between 10 and 1000, or 0 to disable (default 0)
      --blkio-weight-device stringArray                Block IO weight (relative device weight) (default [])
      --cap-add strings                                Add Linux capabilities
      --cap-drop strings                               Drop Linux capabilities
      --cgroup-conf strings                            Configure cgroup v2 (key=value)
      --cgroup-parent string                           Optional parent cgroup for the container
      --cgroupns string                                Cgroup namespace to use, the default depends on the cgroup version ("host"|"private") (default "host")
      --cidfile string                                 Write the container ID to the file
      --cosign-certificate-identity string             The identity expected in a valid Fulcio certificate for --verify=cosign. Valid values include email address, DNS names, IP addresses, and URIs. Either --cosign-certificate-identity or --cosign-certificate-identity-regexp must be set for keyless flows
      --cosign-certificate-identity-regexp string      A regular expression alternative to --cosign-certificate-identity for --verify=cosign. Accepts the Go regular expression syntax described at https://golang.org/s/re2syntax. Either --cosign-certificate-identity or --cosign-certificate-identity-regexp must be set for keyless flows
      --cosign-certificate-oidc-issuer string          The OIDC issuer expected in a valid Fulcio certificate for --verify=cosign, e.g. https://token.actions.githubusercontent.com or https://oauth2.sigstore.dev/auth. Either --cosign-certificate-oidc-issuer or --cosign-certificate-oidc-issuer-regexp must be set for keyless flows
      --cosign-certificate-oidc-issuer-regexp string   A regular expression alternative to --certificate-oidc-issuer for --verify=cosign. Accepts the Go regular expression syntax described at https://golang.org/s/re2syntax. Either --cosign-certificate-oidc-issuer or --cosign-certificate-oidc-issuer-regexp must be set for keyless flows
      --cosign-key string                              Path to the public key file, KMS, URI or Kubernetes Secret for --verify=cosign
      --cpu-period uint                                Limit CPU CFS (Completely Fair Scheduler) period
      --cpu-quota int                                  Limit CPU CFS (Completely Fair Scheduler) quota (default -1)
      --cpu-rt-period uint                             Limit CPU real-time period in microseconds
      --cpu-rt-runtime uint                            Limit CPU real-time runtime in microseconds
      --cpu-shares uint                                CPU shares (relative weight)
      --cpus float                                     Number of CPUs
      --cpuset-cpus string                             CPUs in which to allow execution (0-3, 0,1)
      --cpuset-mems string                             MEMs in which to allow execution (0-3, 0,1)
  -d, --detach                                         Run container in background and print container ID
      --detach-keys string                             Override the default detach keys (default "ctrl-p,ctrl-q")
      --device strings                                 Add a host device to the container
      --device-read-bps stringArray                    Limit read rate (bytes per second) from a device (default [])
      --device-read-iops stringArray                   Limit read rate (IO per second) from a device (default [])
      --device-write-bps stringArray                   Limit write rate (bytes per second) to a device (default [])
      --device-write-iops stringArray                  Limit write rate (IO per second) to a device (default [])
      --dns strings                                    Set custom DNS servers
      --dns-opt strings                                Set DNS options
      --dns-option strings                             Set DNS options
      --dns-search strings                             Set custom DNS search domains
      --domainname string                              Container domain name
      --entrypoint stringArray                         Overwrite the default ENTRYPOINT of the image
  -e, --env stringArray                                Set environment variables
      --env-file strings                               Set environment variables from file
      --gpus stringArray                               GPU devices to add to the container ('all' to pass all GPUs)
      --group-add strings                              Add additional groups to join
      --health-cmd string                              Command to run to check health
      --health-interval duration                       Time between running the check (default: 30s)
      --health-retries int                             Consecutive failures needed to report unhealthy (default: 3)
      --health-start-period duration                   Start period for the container to initialize before starting health-retries countdown
      --health-timeout duration                        Maximum time to allow one check to run (default: 30s)
      --help                                           show help
  -h, --hostname string                                Container host name
      --init                                           Run an init process inside the container, Default to use tini
      --init-binary string                             The custom binary to use as the init process (default "tini")
  -i, --interactive                                    Keep STDIN open even if not attached
      --ip string                                      IPv4 address to assign to the container
      --ip6 string                                     IPv6 address to assign to the container
      --ipc string                                     IPC namespace to use ("host"|"private")
      --ipfs-address string                            multiaddr of IPFS API (default uses $IPFS_PATH env variable if defined or local directory ~/.ipfs)
      --isolation string                               Specify isolation technology for container. On Linux the only valid value is default. Windows options are host, process and hyperv with process isolation as the default (default "default")
      --kernel-memory string                           Kernel memory limit (deprecated)
  -l, --label stringArray                              Set metadata on container
      --label-file strings                             Set metadata on container from file
      --log-driver string                              Logging driver for the container. Default is json-file. It also supports logURI (eg: --log-driver binary://<path>) (default "json-file")
      --log-opt stringArray                            Log driver options
      --mac-address string                             MAC address to assign to the container
  -m, --memory string                                  Memory limit
      --memory-reservation string                      Memory soft limit
      --memory-swap string                             Swap limit equal to memory plus swap: '-1' to enable unlimited swap
      --memory-swappiness int                          Tune container memory swappiness (0 to 100) (default -1) (default -1)
      --mount stringArray                              Attach a filesystem mount to the container
      --name string                                    Assign a name to the container
      --net strings                                    Connect a container to a network ("bridge"|"host"|"none"|"container:<container>"|"ns:<path>"|<CNI>) (default [bridge])
      --network strings                                Connect a container to a network ("bridge"|"host"|"none"|"container:<container>"|"ns:<path>"|<CNI>) (default [bridge])
      --no-healthcheck                                 Disable any container-specified HEALTHCHECK
      --oom-kill-disable                               Disable OOM Killer
      --oom-score-adj int                              Tune container’s OOM preferences (-1000 to 1000, rootless: 100 to 1000)
      --pid string                                     PID namespace to use
      --pidfile string                                 file path to write the task's pid
      --pids-limit int                                 Tune container pids limit (set -1 for unlimited) (default -1)
      --platform string                                Set platform (e.g. "amd64", "arm64")
      --privileged                                     Give extended privileges to this container
  -p, --publish strings                                Publish a container's port(s) to the host
      --pull string                                    Pull image before running ("always"|"missing"|"never") (default "missing")
  -q, --quiet                                          Suppress the pull output
      --rdt-class string                               Name of the RDT class (or CLOS) to associate the container with
      --read-only                                      Mount the container's root filesystem as read only
      --restart string                                 Restart policy to apply when a container exits (implemented values: "no"|"always|on-failure:n|unless-stopped") (default "no")
      --rm                                             Automatically remove the container when it exits
      --rootfs                                         The first argument is not an image but the rootfs to the exploded container
      --runtime string                                 Runtime to use for this container, e.g. "crun", or "io.containerd.runsc.v1" (default "io.containerd.runc.v2")
      --security-opt stringArray                       Security options
      --shm-size string                                Size of /dev/shm
      --sig-proxy                                      Proxy received signals to the process (default true) (default true)
      --stop-signal string                             Signal to stop a container (default "SIGTERM")
      --stop-timeout int                               Timeout (in seconds) to stop a container
      --sysctl stringArray                             Sysctl options
      --systemd string                                 Allow running systemd in this container (default: false) (default "false")
      --tmpfs stringArray                              Mount a tmpfs directory
  -t, --tty                                            Allocate a pseudo-TTY
      --ulimit strings                                 Ulimit options
      --umask string                                   Set the umask inside the container. Defaults to 0022
  -u, --user string                                    Username or UID (format: <name|uid>[:<group|gid>])
      --userns string                                  Specify host to disable userns-remap
      --uts string                                     UTS namespace to use
      --verify string                                  Verify the image (none|cosign|notation) (default "none")
  -v, --volume stringArray                             Bind mount a volume
      --volumes-from stringArray                       Mount volumes from the specified container(s)
  -w, --workdir string                                 Working directory inside the container

See also 'nerdctl --help' for the global flags such as '--namespace', '--snapshotter', and '--cgroup-manager'.
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760173531560-75547c16-0393-4e67-af48-8b66ec751b1a.png)

**<font style="color:rgb(28, 30, 33);">🐳</font>**`**<font style="color:rgb(28, 30, 33);">nerdctl exec</font>**`

<font style="color:rgb(28, 30, 33);">同样也可以使用 </font>`<font style="color:#DF2A3F;">exec</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">命令执行容器相关命令，例如：</font>

```shell
# 进入到容器中执行容器相关命令
➜  ~ nerdctl exec -it nginx /bin/sh
/ # date
Mon Oct 13 03:03:20 UTC 2025
/ #
```

### <font style="color:rgb(28, 30, 33);">2.2 容器管理</font>
**<font style="color:rgb(28, 30, 33);">🐳</font>**`**<font style="color:rgb(28, 30, 33);">nerdctl ps</font>**`<font style="color:rgb(28, 30, 33);">：列出容器</font>

<font style="color:rgb(28, 30, 33);">使用 </font>`<font style="color:#DF2A3F;">nerdctl ps</font>`<font style="color:rgb(28, 30, 33);"> 命令可以列出所有容器。</font>

```shell
# 列出容器
➜  ~ nerdctl ps
CONTAINER ID    IMAGE                             COMMAND                   CREATED           STATUS    PORTS                 NAMES
6e489777d2f7    docker.io/library/nginx:alpine    "/docker-entrypoint.…"    10 minutes ago    Up        0.0.0.0:80->80/tcp    nginx
```

<font style="color:rgb(28, 30, 33);">同样可以使用 </font>`<font style="color:#DF2A3F;">-a</font>`<font style="color:rgb(28, 30, 33);"> 选项显示所有的容器列表，默认只显示正在运行的容器，不过需要注意的是 </font>`<font style="color:#DF2A3F;">nerdctl ps</font>`<font style="color:rgb(28, 30, 33);"> 命令并没有实现 </font>`<font style="color:#DF2A3F;">docker ps</font>`<font style="color:rgb(28, 30, 33);"> 下面的 </font>`<font style="color:#DF2A3F;">--filter</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">--format</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">--last</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">--size</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">等选项。</font>

**<font style="color:rgb(28, 30, 33);">🐳</font>**`**<font style="color:rgb(28, 30, 33);">nerdctl inspect</font>**`<font style="color:rgb(28, 30, 33);">：获取容器的详细信息。</font>

```shell
# 获取容器的详细信息
➜  ~ nerdctl inspect nginx
[
    {
        "Id": "be4addd26f056028b1b5144be20da489c0d356bc1517fe70dd388524df684b3e",
        "Created": "2025-10-11T09:10:33.988952786Z",
        "Path": "/docker-entrypoint.sh",
        "Args": [
            "nginx",
            "-g",
            "daemon off;"
        ],
        "State": {
            "Status": "running",
            "Running": true,
            "Paused": false,
            "Restarting": true,
            "Pid": 204491,
            "ExitCode": 0,
            "Error": "",
            "StartedAt": "2025-10-11T09:10:34.638537495Z",
            "FinishedAt": ""
        },
        "Image": "docker.io/library/nginx:alpine",
        "ResolvConfPath": "/var/lib/nerdctl/1935db59/containers/default/be4addd26f056028b1b5144be20da489c0d356bc1517fe70dd388524df684b3e/resolv.conf",
        "HostnamePath": "/var/lib/nerdctl/1935db59/containers/default/be4addd26f056028b1b5144be20da489c0d356bc1517fe70dd388524df684b3e/hostname",
        "HostsPath": "/var/lib/nerdctl/1935db59/etchosts/default/be4addd26f056028b1b5144be20da489c0d356bc1517fe70dd388524df684b3e/hosts",
        "LogPath": "/var/lib/nerdctl/1935db59/containers/default/be4addd26f056028b1b5144be20da489c0d356bc1517fe70dd388524df684b3e/be4addd26f056028b1b5144be20da489c0d356bc1517fe70dd388524df684b3e-json.log",
        "Name": "nginx",
        "RestartCount": 0,
        "Driver": "overlayfs",
        "Platform": "linux",
        "AppArmorProfile": "",
        "HostConfig": {
            "ContainerIDFile": "",
            "LogConfig": {
                "driver": "json-file",
                "address": "/run/containerd/containerd.sock"
            },
            "PortBindings": {
                "80/tcp": [
                    {
                        "HostIp": "0.0.0.0",
                        "HostPort": "1080"
                    }
                ]
            },
            "CgroupnsMode": "",
            "Dns": null,
            "DnsOptions": null,
            "DnsSearch": null,
            "ExtraHosts": [],
            "GroupAdd": [
                "1",
                "2",
                "3",
                "4",
                "6",
                "10",
                "11",
                "20",
                "26",
                "27"
            ],
            "IpcMode": "private",
            "OomScoreAdj": 0,
            "PidMode": "",
            "ReadonlyRootfs": false,
            "UTSMode": "",
            "ShmSize": 0,
            "Sysctls": null,
            "Runtime": "io.containerd.runc.v2",
            "CpusetMems": "",
            "CpusetCpus": "",
            "CpuQuota": 0,
            "CpuShares": 0,
            "CpuPeriod": 0,
            "CpuRealtimePeriod": 0,
            "CpuRealtimeRuntime": 0,
            "Memory": 0,
            "MemorySwap": 0,
            "OomKillDisable": false,
            "Devices": null,
            "BlkioWeight": 0,
            "BlkioWeightDevice": [],
            "BlkioDeviceReadBps": [],
            "BlkioDeviceWriteBps": [],
            "BlkioDeviceReadIOps": [],
            "BlkioDeviceWriteIOps": []
        },
        "Mounts": [
            {
                "Type": "bind",
                "Source": "/var/lib/nerdctl/1935db59/containers/default/be4addd26f056028b1b5144be20da489c0d356bc1517fe70dd388524df684b3e/resolv.conf",
                "Destination": "/etc/resolv.conf",
                "Mode": "bind,rprivate",
                "RW": true,
                "Propagation": "rprivate"
            },
            {
                "Type": "bind",
                "Source": "/var/lib/nerdctl/1935db59/etchosts/default/be4addd26f056028b1b5144be20da489c0d356bc1517fe70dd388524df684b3e/hosts",
                "Destination": "/etc/hosts",
                "Mode": "bind,rprivate",
                "RW": true,
                "Propagation": "rprivate"
            },
            {
                "Type": "bind",
                "Source": "/var/lib/nerdctl/1935db59/containers/default/be4addd26f056028b1b5144be20da489c0d356bc1517fe70dd388524df684b3e/hostname",
                "Destination": "/etc/hostname",
                "Mode": "bind,rprivate",
                "RW": true,
                "Propagation": "rprivate"
            }
        ],
        "Config": {
            "Hostname": "be4addd26f05",
            "AttachStdin": false,
            "Env": [
                "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
                "NGINX_VERSION=1.29.2",
                "PKG_RELEASE=1",
                "DYNPKG_RELEASE=1",
                "NJS_VERSION=0.9.3",
                "NJS_RELEASE=1",
                "HOSTNAME=be4addd26f05"
            ],
            "Image": "docker.io/library/nginx:alpine",
            "Labels": {
                "containerd.io/restart.loguri": "binary:///usr/local/containerd/bin/nerdctl?_NERDCTL_INTERNAL_LOGGING=%2Fvar%2Flib%2Fnerdctl%2F1935db59",
                "containerd.io/restart.policy": "always",
                "containerd.io/restart.status": "running",
                "io.containerd.image.config.stop-signal": "SIGQUIT",
                "maintainer": "NGINX Docker Maintainers <docker-maint@nginx.com>",
                "nerdctl/auto-remove": "false",
                "nerdctl/dns": "{\"DNSServers\":null,\"DNSResolvConfOptions\":null,\"DNSSearchDomains\":null}",
                "nerdctl/extraHosts": "[]",
                "nerdctl/host-config": "{\"BlkioWeight\":0,\"CidFile\":\"\",\"Devices\":null}",
                "nerdctl/hostname": "be4addd26f05",
                "nerdctl/ipc": "{\"mode\":\"private\"}",
                "nerdctl/log-config": "{\"driver\":\"json-file\",\"address\":\"/run/containerd/containerd.sock\"}",
                "nerdctl/log-uri": "binary:///usr/local/containerd/bin/nerdctl?_NERDCTL_INTERNAL_LOGGING=%2Fvar%2Flib%2Fnerdctl%2F1935db59",
                "nerdctl/name": "nginx",
                "nerdctl/namespace": "default",
                "nerdctl/networks": "[\"bridge\"]",
                "nerdctl/platform": "linux/amd64",
                "nerdctl/state-dir": "/var/lib/nerdctl/1935db59/containers/default/be4addd26f056028b1b5144be20da489c0d356bc1517fe70dd388524df684b3e"
            }
        },
        "NetworkSettings": {
            "Ports": {
                "80/tcp": [
                    {
                        "HostIp": "0.0.0.0",
                        "HostPort": "1080"
                    }
                ]
            },
            "GlobalIPv6Address": "",
            "GlobalIPv6PrefixLen": 0,
            "IPAddress": "10.4.0.3",
            "IPPrefixLen": 24,
            "MacAddress": "a6:79:21:90:9a:f4",
            "Networks": {
                "unknown-eth0": {
                    "IPAddress": "10.4.0.3",
                    "IPPrefixLen": 24,
                    "GlobalIPv6Address": "",
                    "GlobalIPv6PrefixLen": 0,
                    "MacAddress": "a6:79:21:90:9a:f4"
                }
            }
        }
    },
    {
        "Id": "nginx",
        "Created": "2025-10-11T08:26:57.288011179Z",
        "Path": "/docker-entrypoint.sh",
        "Args": [
            "nginx",
            "-g",
            "daemon off;"
        ],
        "State": {
            "Status": "",
            "Running": false,
            "Paused": false,
            "Restarting": false,
            "Pid": 0,
            "ExitCode": 0,
            "Error": "cannot determine networking options from nil spec.Annotations",
            "StartedAt": "",
            "FinishedAt": ""
        },
        "Image": "docker.io/library/nginx:alpine",
        "ResolvConfPath": "",
        "HostnamePath": "",
        "HostsPath": "",
        "LogPath": "",
        "Name": "",
        "RestartCount": 0,
        "Driver": "overlayfs",
        "Platform": "linux",
        "AppArmorProfile": "",
        "HostConfig": {
            "ContainerIDFile": "",
            "LogConfig": {
                "driver": "json-file",
                "address": ""
            },
            "PortBindings": null,
            "CgroupnsMode": "",
            "Dns": null,
            "DnsOptions": null,
            "DnsSearch": null,
            "ExtraHosts": null,
            "GroupAdd": [
                "1",
                "2",
                "3",
                "4",
                "6",
                "10",
                "11",
                "20",
                "26",
                "27"
            ],
            "IpcMode": "",
            "OomScoreAdj": 0,
            "PidMode": "",
            "ReadonlyRootfs": false,
            "UTSMode": "",
            "ShmSize": 0,
            "Sysctls": null,
            "Runtime": "io.containerd.runc.v2",
            "CpusetMems": "",
            "CpusetCpus": "",
            "CpuQuota": 0,
            "CpuShares": 0,
            "CpuPeriod": 0,
            "CpuRealtimePeriod": 0,
            "CpuRealtimeRuntime": 0,
            "Memory": 0,
            "MemorySwap": 0,
            "OomKillDisable": false,
            "Devices": null,
            "BlkioWeight": 0,
            "BlkioWeightDevice": [],
            "BlkioDeviceReadBps": [],
            "BlkioDeviceWriteBps": [],
            "BlkioDeviceReadIOps": [],
            "BlkioDeviceWriteIOps": []
        },
        "Mounts": [],
        "Config": {
            "AttachStdin": false,
            "Env": [
                "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
                "NGINX_VERSION=1.29.2",
                "PKG_RELEASE=1",
                "DYNPKG_RELEASE=1",
                "NJS_VERSION=0.9.3",
                "NJS_RELEASE=1"
            ],
            "Image": "docker.io/library/nginx:alpine",
            "Labels": {
                "io.containerd.image.config.stop-signal": "SIGQUIT",
                "maintainer": "NGINX Docker Maintainers <docker-maint@nginx.com>",
                "nerdctl/error": "cannot determine networking options from nil spec.Annotations"
            }
        },
        "NetworkSettings": {
            "Ports": {},
            "GlobalIPv6Address": "",
            "GlobalIPv6PrefixLen": 0,
            "IPAddress": "",
            "IPPrefixLen": 0,
            "MacAddress": "",
            "Networks": {}
        }
    }
]
```

<font style="color:rgb(28, 30, 33);">可以看到显示结果和 </font>`<font style="color:#DF2A3F;">docker inspect</font>`<font style="color:rgb(28, 30, 33);"> 也基本一致的。</font>

**<font style="color:rgb(28, 30, 33);">🐳</font>**`**<font style="color:rgb(28, 30, 33);">nerdctl logs</font>**`<font style="color:rgb(28, 30, 33);">：获取容器日志</font>

<font style="color:rgb(28, 30, 33);">查看容器日志是我们平时经常会使用到的一个功能，同样我们可以使用 </font>`<font style="color:#DF2A3F;">nerdctl logs</font>`<font style="color:rgb(28, 30, 33);"> 来获取日志数据：</font>

```shell
# 获取容器日志
➜  ~ nerdctl logs -f nginx
[......]
2021/08/19 06:35:46 [notice] 1#1: start worker processes
2021/08/19 06:35:46 [notice] 1#1: start worker process 32
2021/08/19 06:35:46 [notice] 1#1: start worker process 33
```

<font style="color:rgb(28, 30, 33);">同样支持 </font>`<font style="color:#DF2A3F;">-f</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">-t</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">-n</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">--since</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">--until</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">这些选项。</font>

**<font style="color:rgb(28, 30, 33);">🐳</font>**`**<font style="color:rgb(28, 30, 33);">nerdctl stop</font>**`<font style="color:rgb(28, 30, 33);">：停止容器</font>

```shell
# 停止容器
➜  ~ nerdctl stop nginx
nginx

# 查看正常运行的容器
➜  ~ nerdctl ps
CONTAINER ID    IMAGE    COMMAND    CREATED    STATUS    PORTS    NAMES

# 查看所有的容器
➜  ~ nerdctl ps -a
CONTAINER ID    IMAGE                             COMMAND                   CREATED           STATUS    PORTS                 NAMES
6e489777d2f7    docker.io/library/nginx:alpine    "/docker-entrypoint.…"    20 minutes ago    Up        0.0.0.0:80->80/tcp    nginx
```

**<font style="color:rgb(28, 30, 33);">🐳</font>**`**<font style="color:rgb(28, 30, 33);">nerdctl rm</font>**`<font style="color:rgb(28, 30, 33);">：删除容器</font>

```shell
# 删除容器
➜  ~ nerdctl rm nginx
You cannot remove a running container f4ac170235595f28bf962bad68aa81b20fc83b741751e7f3355bd77d8016462d. Stop the container before attempting removal or force remove

# 强制删除容器
➜  ~ nerdctl rm -f nginx
nginx
➜  ~ nerdctl ps
CONTAINER ID    IMAGE    COMMAND    CREATED    STATUS    PORTS    NAMES
```

<font style="color:rgb(28, 30, 33);">要强制删除同样可以使用 </font>`<font style="color:#DF2A3F;">-f</font>`<font style="color:rgb(28, 30, 33);"> 或 </font>`<font style="color:#DF2A3F;">--force</font>`<font style="color:rgb(28, 30, 33);"> 选项来操作。</font>

### <font style="color:rgb(28, 30, 33);">2.3 镜像管理</font>
**<font style="color:rgb(28, 30, 33);">🐳</font>**`**<font style="color:rgb(28, 30, 33);">nerdctl images</font>**`<font style="color:rgb(28, 30, 33);">：镜像列表</font>

```shell
# 拉取镜像
➜  ~ nerdctl pull alpine:latest
docker.io/library/alpine:latest:                                                  resolved       |++++++++++++++++++++++++++++++++++++++| 
index-sha256:4b7ce07002c69e8f3d704a9c5d6fd3053be500b7f1c69fc0d80990c2ad8dd412:    done           |++++++++++++++++++++++++++++++++++++++| 
manifest-sha256:85f2b723e106c34644cd5851d7e81ee87da98ac54672b29947c052a45d31dc2f: done           |++++++++++++++++++++++++++++++++++++++| 
config-sha256:706db57fb2063f39f69632c5b5c9c439633fda35110e65587c5d85553fd1cc38:   done           |++++++++++++++++++++++++++++++++++++++| 
elapsed: 1.8 s                                                                    total:   0.0 B (0.0 B/s)                       

# 列出镜像
➜  ~ nerdctl images
REPOSITORY    TAG       IMAGE ID        CREATED          PLATFORM       SIZE       BLOB SIZE
alpine        latest    4b7ce07002c6    2 minutes ago    linux/amd64    8.63MB     3.804MB
nginx         alpine    7c1b9a91514d    2 hours ago      linux/amd64    55.65MB    22.59MB
nginx         alpine    7c1b9a91514d    2 hours ago      linux/386      0B         21.76MB
```

<font style="color:rgb(28, 30, 33);">也需要注意的是没有实现 </font>`<font style="color:#DF2A3F;">docker images</font>`<font style="color:rgb(28, 30, 33);"> 的一些选项，比如</font><font style="color:#DF2A3F;"> </font>`<font style="color:#DF2A3F;">--all</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">--digests</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">--filter</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">--format</font>`<font style="color:rgb(28, 30, 33);">。</font>

**<font style="color:rgb(28, 30, 33);">🐳</font>**`**<font style="color:rgb(28, 30, 33);">nerdctl pull</font>**`<font style="color:rgb(28, 30, 33);">：拉取镜像</font>

```shell
# 拉取镜像
➜  ~ nerdctl pull docker.io/library/busybox:latest
docker.io/library/busybox:latest:                                                 resolved       |++++++++++++++++++++++++++++++++++++++| 
index-sha256:d82f458899c9696cb26a7c02d5568f81c8c8223f8661bb2a7988b269c8b9051e:    done           |++++++++++++++++++++++++++++++++++++++| 
manifest-sha256:182014572d8981d8323fe9944876f63b39694e16ce08ae6296e97686c52b150c: done           |++++++++++++++++++++++++++++++++++++++| 
config-sha256:0ed463b26daee791b094dc3fff25edb3e79f153d37d274e5c2936923c38dac2b:   done           |++++++++++++++++++++++++++++++++++++++| 
layer-sha256:80bfbb8a41a2b27d93763e96f5bdccb8ca289387946e406e6f24053f6a8e8494:    done           |++++++++++++++++++++++++++++++++++++++| 
elapsed: 4.9 s                                                                    total:  2.1 Mi (443.1 KiB/s)  
```

**<font style="color:rgb(28, 30, 33);">🐳</font>**`**<font style="color:rgb(28, 30, 33);">nerdctl push</font>**`<font style="color:rgb(28, 30, 33);">：推送镜像</font>

<font style="color:rgb(28, 30, 33);">当然在推送镜像之前也可以使用 </font>`<font style="color:#DF2A3F;">nerdctl login</font>`<font style="color:rgb(28, 30, 33);"> 命令登录到镜像仓库，然后再执行 </font>`<font style="color:#DF2A3F;">push</font>`<font style="color:rgb(28, 30, 33);"> 操作。</font>

<font style="color:rgb(28, 30, 33);">可以使用 </font>`<font style="color:#DF2A3F;">nerdctl login --username <Username> --password <Password></font>`<font style="color:rgb(28, 30, 33);"> 进行登录，使用 </font>`<font style="color:#DF2A3F;">nerdctl logout</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">可以注销退出登录。</font>

```shell
$ nerdctl login --username <USERNAME> --password <PASSWORD>
WARN[0000] WARNING! Using --password via the CLI is insecure. Use --password-stdin. 
Login Succeeded
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760176715679-5e5ca0c3-af7f-4f37-a3d8-1788aef6bdd3.png)

**<font style="color:rgb(28, 30, 33);">🐳</font>**`**<font style="color:rgb(28, 30, 33);">nerdctl tag</font>**`<font style="color:rgb(28, 30, 33);">：镜像标签</font>

<font style="color:rgb(28, 30, 33);">使用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">tag</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">命令可以为一个镜像创建一个别名镜像：</font>

```shell
➜  ~ nerdctl images
REPOSITORY    TAG                  IMAGE ID        CREATED           SIZE
busybox       latest               0f354ec1728d    6 minutes ago     1.3 MiB
nginx         alpine               bead42240255    41 minutes ago    16.0 KiB

# 一个镜像创建一个别名镜像
➜  ~ nerdctl tag nginx:alpine harbor.k8s.local/course/nginx:alpine
➜  ~ nerdctl images
REPOSITORY                       TAG                  IMAGE ID        CREATED           SIZE
busybox                          latest               0f354ec1728d    7 minutes ago     1.3 MiB
nginx                            alpine               bead42240255    41 minutes ago    16.0 KiB
harbor.k8s.local/course/nginx    alpine               bead42240255    2 seconds ago     16.0 KiB
```

**<font style="color:rgb(28, 30, 33);">🐳</font>**`**<font style="color:rgb(28, 30, 33);">nerdctl save</font>**`<font style="color:rgb(28, 30, 33);">：导出镜像</font>

<font style="color:rgb(28, 30, 33);">使用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">save</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">命令可以导出镜像为一个</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">tar</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">压缩包。</font>

```shell
# 导出镜像
➜  ~ nerdctl save -o busybox.tar.gz busybox:latest
➜  ~ ls -lh busybox.tar.gz
-rw-r--r-- 1 root root 2.2M Oct 11 18:48 busybox.tar.gz
```

**<font style="color:rgb(28, 30, 33);">🐳</font>**`**<font style="color:rgb(28, 30, 33);">nerdctl rmi</font>**`<font style="color:rgb(28, 30, 33);">：删除镜像</font>

```shell
# 删除镜像
➜  ~ nerdctl rmi busybox
Untagged: docker.io/library/busybox:latest@sha256:0f354ec1728d9ff32edcd7d1b8bbdfc798277ad36120dc3dc683be44524c8b60
Deleted: sha256:5b8c72934dfc08c7d2bd707e93197550f06c0751023dabb3a045b723c5e7b373
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760324829875-d76df01c-c203-47c2-8c2e-549594630e31.png)

**<font style="color:rgb(28, 30, 33);">🐳</font>**`**<font style="color:rgb(28, 30, 33);">nerdctl load</font>**`<font style="color:rgb(28, 30, 33);">：导入镜像</font>

<font style="color:rgb(28, 30, 33);">使用</font><font style="color:rgb(28, 30, 33);"> </font>`<font style="color:rgb(28, 30, 33);">load</font>`<font style="color:rgb(28, 30, 33);"> </font><font style="color:rgb(28, 30, 33);">命令可以将上面导出的镜像再次导入：</font>

```shell
# 导入镜像
➜  ~ nerdctl load -i busybox.tar.gz 
unpacking docker.io/library/busybox:latest (sha256:d82f458899c9696cb26a7c02d5568f81c8c8223f8661bb2a7988b269c8b9051e)...
Loaded image: busybox:latest
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760324873713-c1c3ae96-f7ec-4308-99db-5f02a65260c0.png)

<font style="color:rgb(28, 30, 33);">使用 </font>`<font style="color:#DF2A3F;">-i</font>`<font style="color:rgb(28, 30, 33);"> 或 </font>`<font style="color:#DF2A3F;">--input</font>`<font style="color:rgb(28, 30, 33);"> 选项指定需要导入的压缩包。</font>

### <font style="color:rgb(28, 30, 33);">2.4 镜像构建</font>
<font style="color:rgb(28, 30, 33);">镜像构建是平时我们非常重要的一个需求，我们知道 </font>`<font style="color:#DF2A3F;">ctr</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">并没有构建镜像的命令，而现在我们又不使用 Docker 了，那么如何进行镜像构建了，幸运的是 </font>`<font style="color:#DF2A3F;">nerdctl</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">就提供了 </font>`<font style="color:#DF2A3F;">nerdctl build</font>`<font style="color:rgb(28, 30, 33);"> 这样的镜像构建命令。</font>

**<font style="color:rgb(28, 30, 33);">🐳</font>**`**<font style="color:rgb(28, 30, 33);">nerdctl build</font>**`<font style="color:rgb(28, 30, 33);">：从 Dockerfile 构建镜像</font>

<font style="color:rgb(28, 30, 33);">比如现在我们定制一个 nginx 镜像，新建一个如下所示的 Dockerfile 文件：</font>

```dockerfile
FROM nginx
RUN echo 'Hello Nerdctl From Containerd' > /usr/share/nginx/html/index.html
```

<font style="color:rgb(28, 30, 33);">然后在文件所在目录执行镜像构建命令：</font>

```shell
➜  ~ nerdctl build -t nginx:nerdctl -f Dockerfile .
ERRO[0000] `buildctl` needs to be installed and `buildkitd` needs to be running, see https://github.com/moby/buildkit  error="failed to ping to host unix:///run/buildkit-default/buildkitd.sock: exec: \"buildctl\": executable file not found in $PATH\nfailed to ping to host unix:///run/buildkit/buildkitd.sock: exec: \"buildctl\": executable file not found in $PATH"
FATA[0000] no buildkit host is available, tried 2 candidates: failed to ping to host unix:///run/buildkit-default/buildkitd.sock: exec: "buildctl": executable file not found in $PATH
failed to ping to host unix:///run/buildkit/buildkitd.sock: exec: "buildctl": executable file not found in $PATH 
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760324907338-49fc6d4d-7158-460e-a564-1f97b88adf96.png)

<font style="color:rgb(28, 30, 33);">可以看到有一个错误提示，需要我们安装 </font>`<font style="color:#DF2A3F;">buildctl</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">并运行 </font>`<font style="color:#DF2A3F;">buildkitd</font>`<font style="color:rgb(28, 30, 33);">，这是因为 </font>`<font style="color:#DF2A3F;">nerdctl build</font>`<font style="color:rgb(28, 30, 33);"> 需要依赖 </font>`<font style="color:#DF2A3F;">buildkit</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">工具。</font>

[<font style="color:#117CEE;">buildkit</font>](https://github.com/moby/buildkit)<font style="color:#117CEE;"> </font><font style="color:rgb(28, 30, 33);">项目也是 Docker 公司开源的一个构建工具包，支持 OCI 标准的镜像构建。它主要包含以下部分:</font>

+ <font style="color:rgb(28, 30, 33);">服务端 </font>`<font style="color:#DF2A3F;">buildkitd</font>`<font style="color:rgb(28, 30, 33);">：当前支持 runc 和 containerd 作为 worker，默认是 runc，我们这里使用 containerd</font>
+ <font style="color:rgb(28, 30, 33);">客户端 </font>`<font style="color:#DF2A3F;">buildctl</font>`<font style="color:rgb(28, 30, 33);">：负责解析 Dockerfile，并向服务端 buildkitd 发出构建请求</font>

<font style="color:rgb(28, 30, 33);">buildkit 是典型的 C/S 架构，客户端和服务端是可以不在一台服务器上，而 </font>`<font style="color:#DF2A3F;">nerdctl</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">在构建镜像的时候也作为 </font>`<font style="color:#DF2A3F;">buildkitd</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">的客户端，所以需要我们安装并运行 </font>`<font style="color:#DF2A3F;">buildkitd</font>`<font style="color:rgb(28, 30, 33);">。</font>

<font style="color:rgb(28, 30, 33);">所以接下来我们先来安装 </font>`<font style="color:#DF2A3F;">buildkit</font>`<font style="color:rgb(28, 30, 33);">：</font>

```shell
#############################
# buildkit Version: v0.9.1
#############################
➜  ~ wget https://github.com/moby/buildkit/releases/download/v0.9.1/buildkit-v0.9.1.linux-amd64.tar.gz
# 如果有限制，也可以替换成下面的 URL 加速下载
# wget https://download.fastgit.org/moby/buildkit/releases/download/v0.9.1/buildkit-v0.9.1.linux-amd64.tar.gz
➜  ~ tar -zxvf buildkit-v0.9.1.linux-amd64.tar.gz -C /usr/local/containerd/
bin/
bin/buildctl
bin/buildkit-qemu-aarch64
bin/buildkit-qemu-arm
bin/buildkit-qemu-i386
bin/buildkit-qemu-mips64
bin/buildkit-qemu-mips64el
bin/buildkit-qemu-ppc64le
bin/buildkit-qemu-riscv64
bin/buildkit-qemu-s390x
bin/buildkit-runc
bin/buildkitd
➜  ~ ln -s /usr/local/containerd/bin/buildkitd /usr/local/bin/buildkitd
➜  ~ ln -s /usr/local/containerd/bin/buildctl /usr/local/bin/buildctl

#############################
# buildkit Version: v0.25.1 
#############################
➜  ~ wget https://github.com/moby/buildkit/releases/download/v0.25.1/buildkit-v0.25.1.linux-amd64.tar.gz
➜  ~ tar -zxvf buildkit-v0.25.1.linux-amd64.tar.gz -C /usr/local/containerd/
➜  ~ ln -s /usr/local/containerd/bin/buildkitd /usr/local/bin/buildkitd
➜  ~ ln -s /usr/local/containerd/bin/buildctl /usr/local/bin/buildctl
```

<font style="color:rgb(28, 30, 33);">这里我们使用 Systemd 来管理 </font>`<font style="color:#DF2A3F;">buildkitd</font>`<font style="color:rgb(28, 30, 33);">，创建如下所示的 </font>`<font style="color:#DF2A3F;">systemd unit</font>`<font style="color:rgb(28, 30, 33);"> 文件：</font>

```shell
➜  ~ cat <<EOF > /etc/systemd/system/buildkit.service
[Unit]
Description=BuildKit
Documentation=https://github.com/moby/buildkit

[Service]
ExecStart=/usr/local/bin/buildkitd --oci-worker=false --containerd-worker=true

[Install]
WantedBy=multi-user.target
EOF
```

<font style="color:rgb(28, 30, 33);">然后启动 </font>`<font style="color:#DF2A3F;">buildkitd</font>`<font style="color:rgb(28, 30, 33);">：</font>

```shell
➜  ~ systemctl daemon-reload
➜  ~ systemctl enable buildkit --now
Created symlink /etc/systemd/system/multi-user.target.wants/buildkit.service → /etc/systemd/system/buildkit.service.
➜  ~ systemctl status buildkit
● buildkit.service - BuildKit
     Loaded: loaded (/etc/systemd/system/buildkit.service; enabled; vendor preset: enabled)
     Memory: 8.6M
     CGroup: /system.slice/buildkit.service
             └─5779 /usr/local/bin/buildkitd --oci-worker=false --containerd-worker=true

Aug 19 16:03:10 ydzsio systemd[1]: Started BuildKit.
Aug 19 16:03:10 ydzsio buildkitd[5779]: time="2021-08-19T16:03:10+08:00" level=warning msg="using host network as the default"
Aug 19 16:03:10 ydzsio buildkitd[5779]: time="2021-08-19T16:03:10+08:00" level=info msg="found worker \"euznuelxhxb689bc5of7pxmbc\", labels>
Aug 19 16:03:10 ydzsio buildkitd[5779]: time="2021-08-19T16:03:10+08:00" level=info msg="found 1 workers, default=\"euznuelxhxb689bc5of7pxm>
Aug 19 16:03:10 ydzsio buildkitd[5779]: time="2021-08-19T16:03:10+08:00" level=warning msg="currently, only the default worker can be used."
Aug 19 16:03:10 ydzsio buildkitd[5779]: time="2021-08-19T16:03:10+08:00" level=info msg="running server on /run/buildkit/buildkitd.sock"
~
```

<font style="color:rgb(28, 30, 33);">现在我们再来重新构建镜像：</font>

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760324984191-77662d18-7224-47c8-a548-62264e81d75a.png)

<font style="color:rgb(28, 30, 33);">构建完成后查看镜像是否构建成功：</font>

```shell
➜  ~ nerdctl images
REPOSITORY    TAG        IMAGE ID        CREATED           PLATFORM       SIZE       BLOB SIZE
nginx         nerdctl    810fd264633b    24 seconds ago    linux/amd64    170.4MB    62.7MB
busybox       latest     d82f458899c9    2 minutes ago     linux/amd64    4.493MB    2.214MB
nginx         alpine     61e01287e546    8 minutes ago     linux/amd64    55.65MB    22.59MB
alpine        latest     4b7ce07002c6    41 hours ago      linux/amd64    8.63MB     3.804MB
```

<font style="color:rgb(28, 30, 33);">我们可以看到已经有我们构建的 </font>`<font style="color:#DF2A3F;">nginx:nerdctl</font>`<font style="color:rgb(28, 30, 33);"> 镜像了。接下来使用上面我们构建的镜像来启动一个容器进行测试：</font>

```shell
➜  ~ nerdctl run -d -p 3080:80 --name=nginx --restart=always nginx:nerdctl
2f63ae82ec019af0494b16ae6b6ed6c070030f42ad0b9b57225f11d0ae48e19f

# 查看容器的进程
➜  ~ nerdctl ps
CONTAINER ID    IMAGE                              COMMAND                   CREATED          STATUS    PORTS                   NAMES
2f63ae82ec01    docker.io/library/nginx:nerdctl    "/docker-entrypoint.…"    4 seconds ago    Up        0.0.0.0:3080->80/tcp    nginx

# 访问容器:3080的内容
➜  ~ curl localhost:3080
Hello Nerdctl From Containerd
```

![](https://cdn.nlark.com/yuque/0/2025/png/2555283/1760325036140-cd985db9-1dec-4da6-bce3-f2557250defa.png)

<font style="color:rgb(28, 30, 33);">这样我们就使用 </font>`<font style="color:#DF2A3F;">nerdctl + buildkitd</font>`<font style="color:rgb(28, 30, 33);"> 轻松完成了容器镜像的构建。</font>

<font style="color:rgb(28, 30, 33);">当然如果你还想在单机环境下使用 Docker Compose，在 containerd 模式下，我们也可以使用 </font>`<font style="color:#DF2A3F;">nerdctl</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">来兼容该功能。同样我们可以使用 </font>`<font style="color:#DF2A3F;">nerdctl compose</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">nerdctl compose up</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">nerdctl compose logs</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">nerdctl compose build</font>`<font style="color:#DF2A3F;">、</font>`<font style="color:#DF2A3F;">nerdctl compose down</font>`<font style="color:#DF2A3F;"> </font><font style="color:rgb(28, 30, 33);">等命令来管理 Compose 服务。</font>

<font style="color:rgb(28, 30, 33);">这样使用 containerd、nerdctl 结合 buildkit 等工具就完全可以替代 Docker 在镜像构建、镜像容器方面的管理功能了。</font>

## <font style="color:rgb(28, 30, 33);">3 nerdctl0 网桥</font>
nerdctl0 是 nerdctl/containerd 创建的默认网桥，类似于 Docker 的 docker0。它是在你使用 nerdctl 运行容器时自动创建的。

### 3.1 nerdctl0 的来源
nerdctl0 是由以下情况创建的：

+ 使用 `nerdctl run` 命令运行容器
+ `nerdctl` 使用默认的 bridge 网络模式
+ containerd 的 CNI 插件自动创建的网桥

```shell
$ ip addr show nerdctl0
14: nerdctl0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default qlen 1000
    link/ether fe:db:db:d9:c6:73 brd ff:ff:ff:ff:ff:ff
    inet 10.4.0.1/24 brd 10.4.0.255 scope global nerdctl0
       valid_lft forever preferred_lft forever
    inet6 fe80::fcdb:dbff:fed9:c673/64 scope link 
       valid_lft forever preferred_lft forever
```

### 3.2 清理 nerdctl0 网桥
```shell
#!/bin/bash
echo "=== 停止并删除 nerdctl 容器 ==="
nerdctl stop $(nerdctl ps -aq) 2>/dev/null || true
nerdctl rm $(nerdctl ps -aq) 2>/dev/null || true

echo "=== 删除 nerdctl0 网桥 ==="
ip link set nerdctl0 down 2>/dev/null || true
ip link delete nerdctl0 2>/dev/null || true

echo "=== 备份 nerdctl CNI 配置 ==="
mv /etc/cni/net.d/nerdctl-bridge.conflist /etc/cni/net.d/nerdctl-bridge.conflist.bak 2>/dev/null || true

echo "=== 验证删除 ==="
ip addr show nerdctl0 2>/dev/null && echo "nerdctl0 仍然存在" || echo "nerdctl0 已删除"
```

不然会因为有这个网卡的存在，导致 Kubernetes 集群的 Calico 会连接这个 nerdctl0 网桥进行 BGP 网络。

### 3.3 小总结
重要： 删除 nerdctl0 后：

+ 使用 nerdctl 运行的容器将无法使用默认网络
+ Kubernetes Pod 不受影响（它们使用 Calico CNI）
+ 如果需要再次使用 nerdctl，网桥会自动重新创建

---

:::color2
推荐做法

:::

如果你的 Master 节点主要用于 Kubernetes，建议：

+ 不删除 `nerdctl0`，而是让 Calico 忽略它

使用之前的方法强制 Calico 使用正确的接口：

```shell
kubectl set env daemonset/calico-node -n calico-system IP_AUTODETECTION_METHOD=interface=ens192
kubectl delete pod -n calico-system -l k8s-app=calico-node
```

这样既保留了 nerdctl 的功能，又解决了 Calico 的 IP 选择问题。

