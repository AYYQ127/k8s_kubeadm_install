1. 安装docker
2. 配置如下文件
```json
{
  "data-root": "/data2/docker",
  "exec-opts": [
    "native.cgroupdriver=systemd"
  ],
  "registry-mirrors": [
    "https://docker.m.daocloud.io"
  ],
  "max-concurrent-downloads": 10,
  "live-restore": true,
  "log-driver": "json-file",
  "log-level": "warn",
  "log-opts": {
    "max-size": "50m",
    "max-file": "1"
  },
  "storage-driver": "overlay2"
}

```
3. 逐个拉取所需镜像，除个别仓无法拉取外，此种方式可拉取安装集群所需所有镜像
4. docker save xxx:xxx -o xxx.tar
