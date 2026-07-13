# Ansible + kubeadm 一键安装 Kubernetes 集群（Ubuntu）

项目地址: https://github.com/AYYQ127/k8s_kubeadm_install

---

## 前置条件检查清单

开始前请确认以下条件全部满足：

- [ ] 所有节点已安装 Ubuntu 20.04 / 22.04 / 24.04
- [ ] 每个节点 2 CPU / 2GB RAM 以上
- [ ] 节点间网络互通，可访问 `pkgs.k8s.io` 和 `registry.aliyuncs.com`
- [ ] master1 已安装 Ansible（`apt install ansible -y`）
- [ ] 项目已克隆到 master1（`git clone https://github.com/AYYQ127/k8s_kubeadm_install.git`）
- [ ] 已阅读 [README.md](README.md) 了解项目概述

> **CentOS 用户**: 请参考 [How_to_run_redhat_release.md](How_to_run_redhat_release.md)
>
> **高可用部署**: 请参考 [files/ha/README.md](files/ha/README.md)

---

## 目录

- [1. 集群规划](#1-集群规划)
- [2. 环境准备](#2-环境准备)
- [3. 配置 Ansible](#3-配置-ansible)
- [4. 修改变量文件](#4-修改变量文件)
- [5. 准备组件 YAML 文件](#5-准备组件-yaml-文件)
- [6. 执行安装](#6-执行安装)
- [7. 选装组件](#7-选装组件)
  - [7.1 Metrics Server](#71-metrics-server)
  - [7.2 Prometheus + Grafana](#72-prometheus--grafana)
  - [7.3 Harbor 私有镜像仓库](#73-harbor-私有镜像仓库)
- [8. 持久卷](#8-持久卷)
- [9. 证书续期](#9-证书续期)
- [10. 离线安装](#10-离线安装)
- [11. 快速命令参考](#11-快速命令参考)

---

## 1. 集群规划

以下为示例规划，实际请根据环境调整。要求：**主机名、`/etc/hosts`、`files/ansible/hosts` 三者保持一致**。

| 主机名 | IP | 角色 |
|---|---|---|
| master1 | 10.37.1.200 | 集群主节点 1（操作节点） |
| master2 | 10.37.1.201 | 集群主节点 2 |
| master3 | 10.37.1.202 | 集群主节点 3 |
| node1 | 10.37.1.210 | 工作节点 1 |
| harbor | 10.37.1.220 | 私有镜像仓库（可选） |

---

## 2. 环境准备

### 2.1 检查网络

在所有节点执行，确保可以拉取镜像：

```bash
ping pkgs.k8s.io
ping registry.aliyuncs.com
```

### 2.2 设置主机名

```bash
hostnamectl set-hostname master1   # master1
hostnamectl set-hostname master2   # master2
hostnamectl set-hostname master3   # master3
hostnamectl set-hostname node1     # node1
```

### 2.3 配置 /etc/hosts（master1）

```bash
cat >> /etc/hosts << EOF
10.37.1.200 master1
10.37.1.201 master2
10.37.1.202 master3
10.37.1.210 node1
EOF
```

### 2.4 配置 SSH 免密登录

**在 master1 上操作，使用 root 用户。**

生成密钥：
```bash
sudo su -
ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa
```

在所有节点上开启 root 密码登录：
```bash
# 所有节点都要执行
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
systemctl restart sshd.service
passwd root        # 设置统一密码
```

分发密钥：
```bash
for i in master1 master2 master3 node1; do
    ssh-copy-id root@$i
done
```

验证免密登录：
```bash
ssh root@master1 exit
ssh root@master2 exit
ssh root@master3 exit
ssh root@node1 exit
```

关闭 root 密码登录（可选，安全加固）：
```bash
# 所有节点
sed -i '$d' /etc/ssh/sshd_config
systemctl restart sshd.service
```

### 2.5 更换系统 APT 源（可选）

如果官方源速度慢，可以更换为国内镜像。以 Ubuntu 22.04 为例：

```bash
cat > /etc/apt/sources.list << 'EOF'
deb https://mirrors.cernet.edu.cn/ubuntu/ jammy main restricted universe multiverse
deb https://mirrors.cernet.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse
deb https://mirrors.cernet.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse
EOF
apt update
```

**Ubuntu 24.04** 的源文件格式不同（`.sources`），详见下文 Ansible 分发步骤中的示例。
```bash
cat <<'EOF' > /etc/apt/sources.list.d/ubuntu.sources
Types: deb
URIs: https://mirrors.tuna.tsinghua.edu.cn/ubuntu
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
# Types: deb-src
# URIs: https://mirrors.tuna.tsinghua.edu.cn/ubuntu
# Suites: noble noble-updates noble-backports
# Components: main restricted universe multiverse
# Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

# 以下安全更新软件源为官方源配置
Types: deb
URIs: http://security.ubuntu.com/ubuntu/
Suites: noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

EOF
```

### 2.6 安装 Ansible

```bash
apt install ansible -y
mkdir -p /etc/ansible
ansible-config init --disabled > /etc/ansible/ansible.cfg
# 修改ansible默认的fork配置，默认为5，大于5台节点在第一步重启时会重启失败
```

> 如果遇到 Ansible 与 Jinja2 版本兼容问题：
> ```bash
> apt install python3-pip
> pip3 uninstall jinja2 -y --break-system-packages
> pip3 install jinja2==3.0.3 --break-system-packages
> python3 -c "from jinja2.filters import environmentfilter;print('ok')"
> 预期输出ok
> ```



---

## 3. 配置 Ansible

### 3.1 克隆项目

```bash
git clone https://github.com/AYYQ127/k8s_kubeadm_install.git
cd k8s_kubeadm_install
```

### 3.2 修改 Inventory

编辑 `files/ansible/hosts`，将主机名替换为实际节点名（**不要修改分组名称**）：

```ini
[manage_node]
master1

[other_masters]
master2
master3

[nodes]
node1

[harbor_server]
harbor

# 以下分组不要修改
[except_manage_node:children]
other_masters
nodes

[masters:children]
manage_node
other_masters

[k8s:children]
manage_node
other_masters
nodes
```

> 如需自定义 SSH 端口：`master1 ansible_ssh_port=2222`

### 3.3 部署 Ansible 配置

```bash
# 按需修改主机清单
vim files/ansible/hosts
cp -r files/ansible /etc/
```

### 3.4 分发 hosts 和 apt 源到所有节点

```bash
# 分发 /etc/hosts
ansible k8s -m copy -a "src=/etc/hosts dest=/etc/hosts"

# 分发 apt 源（Ubuntu 20.04/22.04）
ansible k8s -m copy -a "src=/etc/apt/sources.list dest=/etc/apt/sources.list"

# 分发 apt 源（Ubuntu 24.04）
ansible k8s -m copy -a "src=/etc/apt/sources.list.d/ubuntu.sources dest=/etc/apt/sources.list.d/ubuntu.sources"

# 更新缓存
ansible k8s -m apt -a "update_cache=yes"

# 关闭系统更新
ansible k8s -m copy -a "src=files/system-init/disable-auto-update.sh dest=/tmp/disable-auto-update.sh"
ansible k8s -m shell -a "bash /tmp/disable-auto-update.sh"
```

---

## 4. 修改变量文件

编辑 `files/vars.yaml`，根据实际环境修改以下变量。所有变量按功能分组，带 `[必改]` 标记的必须在安装前修改。

> **版本号查询**: `apt-cache madison kubeadm` 可查看 APT 源中所有可用版本及其精确后缀。组件版本兼容性参考 [README.md](README.md) 版本兼容性一节。

### 4.1 集群基础配置

| 变量 | 示例值 | 说明 |
|---|---|---|
| `kubernetes_version` | `v1.36.0` | **[必改]** K8s 大版本号，用于 `kubeadm init`，不带后缀 |
| `kube_3tools_version` | `1.36.0-1.1` | **[必改]** APT 精确版本号（kubelet/kubeadm/kubectl）。通过 `apt-cache madison kubeadm` 查询 |
| `kube_3tools_version_yum` | `1.28.4-150500.1.1` | **[CentOS 必改]** YUM 精确版本号。通过 `yum --showduplicates list kubeadm` 查询 |
| `control_plane_endpoint` | `master1` | **[必改]** 控制平面地址。单 master 填主机名（如 `master1`），HA 填负载均衡地址（如 `ha-apiserveraddr:16443`） |
| `apiserver_advertise_address` | `10.37.1.141` | **[必改]** master1 的 IP 地址，`kubeadm init` 使用 |
| `NTP` | `10.37.1.141` | 时间服务器地址，所有节点同步时间 |

### 4.2 网络配置

| 变量 | 示例值 | 说明 |
|---|---|---|
| `pod_network_cidr` | `10.244.0.0/16` | Pod 网络 CIDR，`kubeadm init` 使用 |
| `pod_network` | `10.244.0.0/16` | Calico `custom-resources.yaml` 中的网络段，需与 `pod_network_cidr` 一致 |
| `sandbox_image` | `pause:3.10.1` | Pause 容器镜像版本，使用阿里云源（`registry.aliyuncs.com/google_containers/`），官方源国内无法拉取 |

### 4.3 高可用配置

> 仅高可用部署时需要配置，单 master 可忽略。

| 变量 | 示例值 | 说明 |
|---|---|---|
| `all_masters` | `[10.37.1.141, 10.37.1.142, 10.37.1.143]` | 所有 master 节点 IP 列表 |
| `certSANs` | 见 vars.yaml | 证书 SAN 白名单，包含所有 master IP、主机名、127.0.0.1 和负载均衡地址 |

### 4.4 组件版本

| 变量 | 示例值 | 说明 |
|---|---|---|
| `calico_version` | `v3.32.1` | Calico 网络插件版本，需与 `files/calico/` 中的文件名版本匹配 |
| `ingress_version` | `v1.15.1` | Ingress-Nginx Controller 版本 |
| `metrics_server_version` | `v0.8.1` | Metrics Server 版本 |
| `kube_prometheus_version` | `0.18.0` | kube-prometheus 监控栈版本 |
| `grafana_host` | `grafana.example.local` | Grafana Ingress 访问域名 |

### 4.5 Harbor 私有仓库

> 仅安装 Harbor 时需要配置。

| 变量 | 示例值 | 说明 |
|---|---|---|
| `harbor_domain` | `harbor.example.local` | Harbor 私有仓库域名 |
| `harbor_ip` | `10.37.1.150` | Harbor 节点 IP |
| `harbor_port` | `16443` | Harbor 服务端口 |
| `passord_or_secert` | `password` | 认证方式：`password`（containerd 配置中写死密码）或 `secert`（通过 `imagePullSecrets` 引用） |

> 选择 `secert` 方式时，需在 Pod 中通过 `imagePullSecrets` 引用已创建的 Secret。containerd v2.x默认不再支持password.若想使用password需要降级到v1.7版本，并参考files/harbor/with_password_config.tpml.j2中格式

### 4.6 云环境注意事项

- **微软云 / 火山云环境**：Calico 默认 `encapsulation: VXLANCrossSubnet` 在云环境中可能导致 Pod 跨节点不通。安装完成后检查并修复：
  ```bash
  kubectl get ippools -o yaml          # 查看 vxlanMode 是否为 CrossSubnet
  kubectl edit installation default    # 将 encapsulation 改为 VXLAN（两处）
  kubectl -n calico-system rollout restart ds calico-node
  ```
- **VMware ESXi**：保持默认配置，无需修改。

---

## 5. 准备组件 YAML 文件

运行 playbook 前，需确保 `files/` 目录下已准备好对应版本的组件 YAML 文件。各组件下载方式如下：

### Calico（随集群自动安装）

```bash
# 查看版本对应关系
# https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements

# 下载 tigera-operator.yaml
wget https://raw.githubusercontent.com/projectcalico/calico/${calico_version}/manifests/tigera-operator.yaml \
  -O files/calico/tigera-operator_${calico_version}.yaml

# 下载 custom-resources.yaml
wget https://raw.githubusercontent.com/projectcalico/calico/${calico_version}/manifests/custom-resources.yaml \
  -O files/calico/custom-resources_${calico_version}.yaml
```

> 文件命名格式为 `文件名_版本号.yaml`，与 `vars.yaml` 中的 `calico_version` 保持一致。

### Ingress-Nginx（随集群自动安装）

```bash
# 查看版本兼容性
# https://github.com/kubernetes/ingress-nginx#readme

version=v1.15.1
wget https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${version}/deploy/static/provider/baremetal/deploy.yaml \
  -O files/ingress/deploy_${version}.yaml
```

下载后需手动修改 `deploy.yaml`：

1. **替换镜像**（三处，改为阿里云镜像）：
   ```yaml
   image: registry.cn-hangzhou.aliyuncs.com/google_containers/nginx-ingress-controller:v1.15.1
   image: registry.cn-hangzhou.aliyuncs.com/google_containers/kube-webhook-certgen:v20231011-8b53cabe0
   image: registry.cn-hangzhou.aliyuncs.com/google_containers/kube-webhook-certgen:v20231011-8b53cabe0
   ```

2. **Deployment 改为 DaemonSet**（每台 node 都运行一个副本）

3. **开启 hostNetwork**（使用节点 80/443 端口）：
   ```yaml
   hostNetwork: true
   ```

4. **添加参数**（可选，兼容无 ingressClass 的旧资源）：
   ```yaml
   - --watch-ingress-without-class=true
   ```

### Metrics Server

```bash
# 查看 K8s 版本兼容性
# https://github.com/kubernetes-sigs/metrics-server#compatibility-matrix

version=v0.8.1
wget https://github.com/kubernetes-sigs/metrics-server/releases/download/${version}/components.yaml \
  -O files/metrics/components_${version}.yaml
```

> 0.6.x 和 0.7.x 均支持 K8s 1.19+。

### kube-prometheus（Prometheus + Grafana）

```bash
# 查看版本兼容性（见 README.md 组件资源章节的兼容表）
# https://github.com/prometheus-operator/kube-prometheus/releases

version=v0.18.0
wget https://github.com/prometheus-operator/kube-prometheus/archive/refs/tags/${version}.zip
unzip ${version}.zip
# 解压后只保留 manifests/ 目录，放入 files/prometheus/kube-prometheus-0.18.0/
```

解压后需替换部分镜像（原始镜像国内无法拉取）：

| 版本 | 文件 | 替换后的镜像 |
|---|---|---|
| 0.13.0 | `prometheusAdapter-deployment.yaml` | `docker.io/developerxu/prometheus-adapter:v0.10.0` |
| | `kubeStateMetrics-deployment.yaml` | `docker.io/bitnami/kube-state-metrics:2.7.0` |
| 0.15.0 | `prometheusAdapter-deployment.yaml` | `docker.io/v5cn/prometheus-adapter:v0.12.0` |
| | `kubeStateMetrics-deployment.yaml` | `docker.io/bitnami/kube-state-metrics:2.15.0` |
| 0.18.0 | `prometheusAdapter-deployment.yaml` | `docker.io/v5cn/prometheus-adapter:v0.12.0` |
| | `kubeStateMetrics-deployment.yaml` | `registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.19.0` |

> **NetworkPolicies 注意事项**: 0.11 版本后默认启用 NetworkPolicies，NodePort 方式需删除 `grafana-networkPolicy.yaml`。

> **Grafana 调优**: 安装后需修改 Grafana 的 limits（太小会 OOM），并将 `grafana-storage` 从 emptyDir 改为持久卷。

### Harbor

> Harbor 文件较大，未上传 GitHub。安装前需自行下载：
> - [docker-compose](https://github.com/docker/compose/releases) → `files/harbor/docker-compose-linux-x86_64`
> - [harbor-offline-installer](https://github.com/goharbor/harbor/releases) → 解压后重命名为 `files/harbor/harbor-offline-installer.tgz`

---

## 6. 执行安装

### 6.1 注意事项

- **执行前确认 `vars.yaml` 已修改完成**
- 如果是云环境，需修改 `files/calico/custom-resources_{version}.yaml` 中的 `encapsulation: VXLANCrossSubnet` 为 `VXLAN`，否则 Pod 跨节点无法通信
- VMware ESXi 平台保持默认配置即可

### 6.2 执行

```bash
cd ~/k8s_kubeadm_install
ansible-playbook playbooks/main-ubuntu2404-ha.yaml
#单节点文件已不再维护
```

**安装分两轮执行**：第一轮初始化系统后会重启所有节点，重启完成后**再次进入 master1 执行同一命令**，第二轮完成集群初始化和节点加入。

> 执行方式为 `sudo su -` 切换到 root 后再执行（Ansible 使用 root 远程连接）。

### 6.3 验证集群

```bash
# 等待 4-5 分钟后检查
kubectl get nodes
# NAME      STATUS   ROLES           AGE   VERSION
# master1   Ready    control-plane   6m    v1.36.0
# master2   Ready    control-plane   5m    v1.36.0
# master3   Ready    control-plane   6m    v1.36.0
# node1     Ready    node            6m    v1.36.0
```

### 6.4 master 节点参与调度（可选）

```bash
# 查看污点
kubectl describe node master2 | grep Taints

# 删除master污点
kubectl taint nodes master2 node-role.kubernetes.io/control-plane:NoSchedule-

# 改 node 角色
kubectl label nodes node1 node-role.kubernetes.io/node=
```

---

## 7. 选装组件

基础集群安装完成后，可通过 `-t` 标签按需安装以下组件：

```bash
ansible-playbook playbooks/main-ubuntu2404-ha.yaml -t <tag>
```

| 标签 | 组件 |
|---|---|
| `metrics` | Metrics Server（`kubectl top`） |
| `prometheus` | Prometheus + Grafana 监控 |
| `harbor` | Harbor 私有镜像仓库 |

### 7.1 Metrics Server

```bash
ansible-playbook playbooks/main-ubuntu2404-ha.yaml -t metrics
```

验证：
```bash
kubectl get pod -A | grep metrics
kubectl top node
```

### 7.2 Prometheus + Grafana

```bash
ansible-playbook playbooks/main-ubuntu2404-ha.yaml -t prometheus
```

访问 Grafana：
```bash
kubectl get ingress -n monitoring
# 将 grafana.example.local 添加到本地 hosts 文件
# 默认账号密码: admin / admin（首次登录强制修改）
```

> **注意**: 安装后需要修改 Grafana 的 limits（太小会 OOM）和数据持久化配置（将 emptyDir 改为自己的持久卷）。

### 7.3 Harbor 私有镜像仓库

Harbor 部署在独立节点，安装前需要额外准备。

#### 准备工作

1. **在 harbor 节点上设置主机名和密码**：
   ```bash
   hostnamectl set-hostname harbor
   echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
   systemctl restart sshd.service
   passwd root
   ```

2. **在 master1 上添加 harbor 的 hosts 解析并配置免密**：
   ```bash
   echo "10.37.1.220 harbor" >> /etc/hosts
   ssh-copy-id root@harbor
   ```

3. **重新部署 Ansible 配置**：
   ```bash
   cp -r files/ansible /etc/
   ansible harbor -m ping
   ```

4. **分发 hosts 和 apt 源到 harbor**：
   ```bash
   ansible all -m copy -a "src=/etc/hosts dest=/etc/hosts"
   ansible harbor -m copy -a "src=/etc/apt/sources.list dest=/etc/apt/sources.list"
   ansible harbor -m apt -a "update_cache=yes"
   ```

5. **下载必要文件**：YAML 文件准备见[第 5 章](#5-准备组件-yaml-文件)。

> Harbor 文件较大（docker-compose + harbor-offline-installer），需从 GitHub Releases 自行下载放入 `files/harbor/`。

#### 修改变量

在 `vars.yaml` 中修改 Harbor 相关变量：

```yaml
harbor_domain: myharbor.com
harbor_ip: 10.37.1.220
passord_or_secert: secert    # password 或 secert 两种认证方式
```

#### 执行安装

```bash
ansible-playbook playbooks/main-ubuntu2404-ha.yaml -t harbor
```

#### 验证

```bash
# Docker 方式测试
docker login myharbor.com -u admin
docker pull nginx
docker tag nginx:latest myharbor.com/test/nginx:latest
docker push myharbor.com/test/nginx:latest

# Kubernetes 方式测试
kubectl apply -f files/harbor/test-harbor_with_password.yaml
kubectl get ingress
curl http://foo.bar.com --resolve foo.bar.com:80:10.37.1.210
```

> Harbor 支持两种认证方式：
> - **password**: 在 containerd 配置中直接写入账号密码
> - **secert**: 通过 `kubectl create secret docker-registry` 创建 Secret，在 Pod 中通过 `imagePullSecrets` 引用
>
> 详情参考 [README.md](README.md) Harbor 章节。

---

## 8. 持久卷

### 8.1 NFS Server 安装（以 harbor 节点为例）

```bash
apt install nfs-kernel-server nfs-common -y

cat > /etc/exports << EOF
/nfs/pv 10.37.1.0/24(rw,sync,no_root_squash,no_all_squash)
/nfs/sc 10.37.1.0/24(rw,sync,no_root_squash,no_all_squash)
EOF

mkdir -p /nfs/{pv,sc}
systemctl restart nfs-server
```

所有 K8s 节点安装 NFS 客户端：
```bash
ansible k8s -m shell -a "apt update"
ansible k8s -m shell -a "apt install nfs-common -y"
```

### 8.2 静态 Provisioning（PV/PVC）

```bash
kubectl apply -f files/nfs_volume/pv_pvc/pv-example.yaml
kubectl apply -f files/nfs_volume/pv_pvc/pvc-example.yaml
kubectl apply -f files/nfs_volume/pv_pvc/test-pv-pvc.yaml
```

### 8.3 动态 Provisioning（StorageClass）

```bash
kubectl apply -f files/nfs_volume/storageclass/sc-rbac.yaml
kubectl apply -f files/nfs_volume/storageclass/
```

验证：
```bash
kubectl get sc
kubectl get pv
kubectl get pvc
```

### 8.4 Helm 安装 JumpServer

```bash
# 安装 Helm
tar -zxvf helm-<version>-linux-amd64.tar.gz
mv linux-amd64/helm /usr/local/bin/helm
chmod +x /usr/local/bin/helm

# 创建数据库
kubectl apply -f files/helm/jms/mysql.yaml -f files/helm/jms/redis.yaml
kubectl exec -it $(kubectl get pod -l app=mysql -o jsonpath='{.items[0].metadata.name}') -- bash
# mysql -uroot -pjumpserver
# CREATE DATABASE jumpserver DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;
# CREATE USER 'jumpserver'@'%' IDENTIFIED BY 'jumpserver';
# GRANT ALL PRIVILEGES ON jumpserver.* TO 'jumpserver'@'%';
# FLUSH PRIVILEGES;

# 安装 JumpServer
helm install jms-k8s files/helm/jms/jms.tgz
```

---

## 9. 证书续期

kubeadm 生成的证书默认有效期 1 年，使用内置脚本可延长至 100 年。

```bash
# 查询证书有效期
kubeadm certs check-expiration

# 执行续期（每个 master 节点都要执行，自动安装已经执行到100年，不再单独执行）
bash files/kube-cert/update-kubeadm-cert.sh all --cri containerd

# 再次检查
kubeadm certs check-expiration
```

---

## 10. 离线安装

适用于无外网环境。将离线镜像包放入 `files/docker-images/v<version>/` 目录，执行安装命令不变。

当前支持的离线镜像版本：

```
files/docker-images/
├── v1.28.4/    # K8s v1.28.4 + Calico v3.26.3
├── v1.29.6/    # K8s v1.29.6 + Calico v3.28.0
├── v1.30.2/    # K8s v1.30.2 + Calico v3.28.0
├── v1.32.6/    # K8s v1.32.6
└── v1.36.0/    # K8s v1.36.0
```

镜像包获取方式请参考 [files/docker-images/README.md](files/docker-images/README.md)。

---

## 11. 快速命令参考

```bash
# 基础安装（执行两次）
ansible-playbook playbooks/main-ubuntu2404-ha.yaml

# 选装组件
ansible-playbook playbooks/main-ubuntu2404-ha.yaml -t metrics
ansible-playbook playbooks/main-ubuntu2404-ha.yaml -t prometheus
ansible-playbook playbooks/main-ubuntu2404-ha.yaml -t harbor

# 集群状态
kubectl get nodes -o wide
kubectl get pod -A
kubectl top node

# Ansible 管理
ansible k8s -m ping                          # 测试所有节点连通性
ansible k8s -m shell -a "uptime"             # 在所有节点执行命令
ansible k8s -m copy -a "src=/etc/hosts dest=/etc/hosts"  # 分发文件

# 证书管理
kubeadm certs check-expiration               # 查看证书有效期
bash files/kube-cert/update-kubeadm-cert.sh all --cri containerd  # 续期
openssl x509 -noout -text -in /etc/kubernetes/pki/apiserver.crt | awk '/Validity/,/Subject:/ { if ($1 == "Not" && ($2 == "Before:" || $2 == "After" )) print $0 }' # 查有效期
```
