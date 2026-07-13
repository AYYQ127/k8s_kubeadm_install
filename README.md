# k8s_kubeadm_install

> 使用 Ansible + kubeadm 一键部署 Kubernetes 集群，支持 Ubuntu / CentOS，集成 Calico、Ingress、Prometheus、Harbor 等常用组件。

[![Platform](https://img.shields.io/badge/platform-Ubuntu%2020.04%20%7C%2022.04%20%7C%2024.04%20%7C%20CentOS%207.9-orange)](#)
[![K8s](https://img.shields.io/badge/k8s-v1.25--v1.36-blue)](#)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

- [演示视频 (B站)](https://www.bilibili.com/video/BV1Sk4y1D7b6/)

---

## 目录

- [特性](#特性)
- [快速开始](#快速开始)
- [项目结构](#项目结构)
- [支持的组件](#支持的组件)
- [版本兼容性](#版本兼容性)
- [文档索引](#文档索引)

---

## 特性

- **一键部署**: 执行一条 `ansible-playbook` 命令完成集群初始化（系统优化 → 安装组件 → 初始化集群 → 加入节点）
- **多平台**: Ubuntu 20.04 / 22.04 / 24.04 (APT) 和 CentOS 7.9 (YUM)
- **多版本**: 支持 Kubernetes v1.25 ~ v1.36
- **高可用**: 内置多 master + OpenResty 负载均衡方案
- **离线安装**: 支持离线镜像导入，适合无外网环境
- **幂等性**: 通过 lock 文件机制，中断后可安全重跑
- **可选组件**: 可按需安装 Metrics Server、Prometheus/Grafana、Harbor 私有仓库
- **证书续期**: 内置证书续期脚本，可将 1 年有效期延长至 10 年

---

## 快速开始

### 1. 准备节点

至少 1 台 master（推荐 3 台做 HA），若干台 worker。所有节点需满足：
- Ubuntu 20.04/22.04/24.04 或 CentOS 7.9
- 2 CPU / 2GB RAM 以上
- 网络互通，能访问 `pkgs.k8s.io` 和 `registry.aliyuncs.com`

```bash
# 设置主机名（所有节点）
hostnamectl set-hostname master1   # 按实际命名
```

### 2. 在 master1 上安装 Ansible 并克隆项目

```bash
apt install ansible -y             # CentOS: yum install ansible -y
git clone https://github.com/AYYQ127/k8s_kubeadm_install.git
cd k8s_kubeadm_install
```

### 3. 配置

修改三个文件：

| 文件 | 修改内容 |
|---|---|
| `files/ansible/hosts` | 将 `master1/node1` 等主机名替换为实际节点名 |
| `files/vars.yaml` | 修改 `kubernetes_version`、IP 地址等关键变量 |
| `/etc/hosts` | 添加所有节点的 IP-主机名映射 |

```bash
cp -r files/ansible /etc/
```

### 4. 配置 SSH 免密

从 master1 的 root 用户免密访问所有节点（含自身）。

### 5. 执行安装

```bash
ansible-playbook playbooks/main.yaml
# 第一次包含重启，重启完成后再次执行同一命令
```

等待几分钟，集群就绪：

```bash
kubectl get nodes
```

**CentOS 用户**: 使用 `playbooks/main_redhat_release.yaml`，详见 [How_to_run_redhat_release.md](How_to_run_redhat_release.md)

---

## 项目结构

```
k8s_kubeadm_install/
├── README.md                         # 项目说明（本文件）
├── How_to_run.md                     # Ubuntu 详细安装指南
├── How_to_run_redhat_release.md      # CentOS 详细安装指南
│
├── playbooks/                        # Ansible Playbook
│   ├── main.yaml                     # 【核心】Ubuntu 默认安装入口
│   ├── main_redhat_release.yaml      # 【核心】CentOS 安装入口
│   ├── main-ubuntu2204-ha.yaml       # Ubuntu 22.04 高可用方案
│   ├── main-ubuntu2404-ha.yaml       # Ubuntu 24.04 高可用方案
│   ├── metrics_server_install.yaml   # 选装：metrics-server
│   ├── prometheus_install.yaml       # 选装：Prometheus + Grafana
│   └── harbor_install.yaml           # 选装：Harbor 私有仓库
│
├── files/                            # 资源文件
│   ├── vars.yaml                     # 【核心】全局变量配置
│   ├── ansible/                      # Ansible 配置
│   │   ├── ansible.cfg               #   remote_user=root 等配置
│   │   └── hosts                     #   Inventory 主机清单
│   ├── calico/                       #   Calico 网络插件
│   ├── ingress/                      #   Ingress-Nginx Controller
│   ├── metrics/                      #   Metrics Server
│   ├── prometheus/                   #   Prometheus 监控栈
│   ├── harbor/                       #   Harbor 私有仓库
│   ├── ha/                           #   高可用（OpenResty 负载均衡）
│   ├── k8s_pkgs/                     #   K8s APT/YUM 源和 GPG 密钥
│   ├── docker-images/                #   离线镜像包
│   ├── nfs_volume/                   #   NFS 持久卷示例
│   ├── kube-cert/                    #   证书续期脚本
│   └── helm/                         #   Helm 二进制和 JumpServer Chart
```

**设计说明**: 本项目不使用 Ansible roles，所有任务直接写在 playbook 中，通过 `vars_files` 引入变量，通过 lock 文件实现幂等，结构扁平、易于理解和修改。

---

## 支持的组件

| 组件 | 内置版本范围 | 选装方式 | 说明 |
|---|---|---|---|
| **Calico** | v3.26.3 ~ v3.32.1 | 随集群自动安装 | 网络插件，通过 Tigera Operator 部署 |
| **Ingress-Nginx** | v1.9.4 ~ v1.15.1 | 随集群自动安装 | DaemonSet + hostNetwork 模式 |
| **Metrics Server** | v0.6.4 ~ v0.8.1 | `-t metrics` | 资源监控，`kubectl top` 命令依赖 |
| **Prometheus + Grafana** | 0.13.0 / 0.15.0 / 0.18.0 | `-t prometheus` | 监控报警，Grafana Ingress 暴露 |
| **Harbor** | 离线安装包 | `-t harbor` | 私有镜像仓库，支持 password/secret 认证 |

### 添加新版本

以 Calico 为例，将 `tigera-operator.yaml` 和 `custom-resources.yaml` 下载后按 `文件名_版本号.yaml` 格式放入 `files/calico/`，再在 `vars.yaml` 中修改 `calico_version` 即可。

其它组件同理，详见 `How_to_run.md` 中各组件下载说明。

---

## 版本兼容性

### K8s 与系统兼容矩阵

| K8s 版本 | Ubuntu 20.04 | Ubuntu 22.04 | Ubuntu 24.04 | CentOS 7.9 |
|---|---|---|---|---|
| v1.25 ~ v1.27 | :white_check_mark: | :white_check_mark: | - | :white_check_mark: |
| v1.28 ~ v1.30 | :white_check_mark: | :white_check_mark: | - | :white_check_mark: |
| v1.31 ~ v1.33 | :white_check_mark: | :white_check_mark: | :white_check_mark: | - |
| v1.34 ~ v1.36 | :white_check_mark: | :white_check_mark: | :white_check_mark: | - |

### 关键组件版本对应

| K8s | Calico | Ingress | Metrics Server | Prometheus Stack |
|---|---|---|---|---|
| v1.28 | v3.26.3+ | v1.9.4+ | v0.6.4+ | 0.13.0 |
| v1.29 | v3.28.0+ | v1.10.1+ | v0.7.0+ | 0.15.0 |
| v1.30+ | v3.28.0+ | v1.11.1+ | v0.7.0+ | 0.15.0+ |
| v1.32+ | v3.29.0+ | v1.12.1+ | v0.8.0+ | 0.18.0 |

> 组件版本间有依赖关系，具体请参考各组件官方兼容性文档。更换版本前建议先在测试环境验证。

---

## 组件资源

更新组件版本时，参考以下官方文档和下载地址：

| 组件 | 官方文档 / 版本兼容 | YAML 下载 |
|---|---|---|
| **Calico** | [版本要求](https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements) · [快速部署](https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart) | `tigera-operator` / `custom-resources` [raw](https://raw.githubusercontent.com/projectcalico/calico) |
| **Ingress-Nginx** | [版本支持](https://github.com/kubernetes/ingress-nginx#readme) · [快速部署](https://kubernetes.github.io/ingress-nginx/deploy/) · [Releases](https://github.com/kubernetes/ingress-nginx/releases) | `deploy.yaml` [raw](https://raw.githubusercontent.com/kubernetes/ingress-nginx) |
| **Metrics Server** | [兼容矩阵](https://github.com/kubernetes-sigs/metrics-server#compatibility-matrix) · [Releases](https://github.com/kubernetes-sigs/metrics-server/releases) | `components.yaml` |
| **kube-prometheus** | [仓库](https://github.com/prometheus-operator/kube-prometheus) · [Releases](https://github.com/prometheus-operator/kube-prometheus/releases) | 解压 release 包，保留 `manifests/` 目录 |
| **Harbor** | [Releases](https://github.com/goharbor/harbor/releases) | 离线安装包 `harbor-offline-installer-*.tgz` |
| **Docker Compose** | [Releases](https://github.com/docker/compose/releases) | `docker-compose-linux-x86_64`（Harbor 依赖） |

### kube-prometheus 版本兼容表

| Stack 版本 | K8s 1.22 | 1.23 | 1.24 | 1.25 | 1.26 | 1.27 | 1.28 |
|---|---|---|---|---|---|---|---|
| [release-0.10](https://github.com/prometheus-operator/kube-prometheus/tree/release-0.10) | ✔ | ✔ | ✗ | ✗ | ✗ | ✗ | ✗ |
| [release-0.11](https://github.com/prometheus-operator/kube-prometheus/tree/release-0.11) | ✗ | ✔ | ✔ | ✗ | ✗ | ✗ | ✗ |
| [release-0.12](https://github.com/prometheus-operator/kube-prometheus/tree/release-0.12) | ✗ | ✗ | ✔ | ✔ | ✗ | ✗ | ✗ |
| [release-0.13](https://github.com/prometheus-operator/kube-prometheus/tree/release-0.13) | ✗ | ✗ | ✗ | ✗ | ✔ | ✔ | ✔ |
| [release-0.14](https://github.com/prometheus-operator/kube-prometheus/tree/release-0.14) | ✗ | ✗ | ✔ | ✔ | ✔ | ✗ | ✗ |
| [release-0.15](https://github.com/prometheus-operator/kube-prometheus/tree/release-0.15) | ✗ | ✗ | ✗ | ✗ | ✔ | ✔ | ✔ |
| [release-0.18](https://github.com/prometheus-operator/kube-prometheus/tree/release-0.18) | ✗ | ✗ | ✗ | ✗ | ✗ | ✔ | ✔ |

> **注意**: 0.11 版本后加入了 NetworkPolicies，使用 NodePort 访问需删除 `grafana-networkPolicy.yaml`。本项目默认使用 Ingress 方式暴露，无需额外处理。
>
> Prometheus 镜像替换参考：不同版本需修改 `manifests/prometheusAdapter-deployment.yaml` 和 `manifests/kubeStateMetrics-deployment.yaml` 中的镜像地址。详见各版本 `files/prometheus/kube-prometheus-*/manifests/` 中的实际配置。

---

## 文档索引

| 文档 | 内容 |
|---|---|
| [How_to_run.md](How_to_run.md) | Ubuntu 系统完整安装指南（推荐从这里开始） |
| [How_to_run_redhat_release.md](How_to_run_redhat_release.md) | CentOS / RHEL 系统安装指南 |
| [files/ha/README.md](files/ha/README.md) | 高可用集群部署说明（多 master + OpenResty） |
| [files/docker-images/README.md](files/docker-images/README.md) | 离线镜像包获取方式 |

> 本文档与项目一同持续更新。当前默认配置基于 **K8s v1.36.0 + Calico v3.32.1**。
