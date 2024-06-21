### 演示视频
https://www.bilibili.com/video/BV1Sk4y1D7b6/

### 系统环境
1. ubuntu20.04
2. ubuntu22.04
3. centos7.9

### 区别一下
ubuntu系统请参考How_to_run.md  
centos系统请参考How_to_run_redhat_release.md


### 说明
1. files/calico/custom-resources.yaml && files/calico/tigera-operator.yaml(calico)
```bash
# calico官网地址，查看对应版本
https://docs.tigera.io/calico/latest/about
https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements#kubernetes-requirements

# 快速部署
https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart

# 需要提前下载对应版本tigera-operator.yaml到files目录，其他操作不用做
https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml

# 需要提前下载对应版本custom-resources.yaml到files目录，其他操作不用做
https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml

# 将下载的文件放至files/calico,并按"文件名_version"格式命名
```

2. files/ingress/deploy.yaml(Ingress)
```bash
# 查看支持版本
https://github.com/kubernetes/ingress-nginx/blob/main/README.md#readme

version=v1.10.1

# 快速部署
https://kubernetes.github.io/ingress-nginx/deploy/#quick-start

# 单独下载deploy.yaml文件
wget https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${version}/deploy/static/provider/baremetal/deploy.yaml


# deploy.yaml源码文件包下载

https://github.com/kubernetes/ingress-nginx/releases
wget https://github.com/kubernetes/ingress-nginx/archive/refs/tags/controller-${version}.tar.gz
tar -xf controller-${version}.tar.gz

vim ingress-nginx-controller-v1.9.4/deploy/static/provider/baremetal/deploy.yaml

# 需要提前下载对应版本deploy.yaml到files目录，手动修改镜像名称，有三处(v1.9.4,其余版本在这附近)
445        image: registry.cn-hangzhou.aliyuncs.com/google_containers/nginx-ingress-controller:v1.9.4
542        image: registry.cn-hangzhou.aliyuncs.com/google_containers/kube-webhook-certgen:v20231011-8b53cabe0
591        image: registry.cn-hangzhou.aliyuncs.com/google_containers/kube-webhook-certgen:v20231011-8b53cabe0 

把 kind: Deployment 改为 kind: DaemonSet 模式，这样每台node上都有 
ingress-nginx-controller pod 副本。 
使用hostNetwork: true，默认 ingress-nginx 随机提供 nodeport 端口，
开启 hostNetwork 启用80、443端口。
如果不关心 ingressClass 或者很多没有 ingressClass 配置的 ingress 对象， 
添加参数 --watch-ingress-without-class=true

# 位置为v1.9.4，其余版本行号在这附近
391 kind: DaemonSet
409  #strategy:
410    #rollingUpdate:
411      #maxUnavailable: 1
412    #type: RollingUpdate
422       hostNetwork: true
433         - --watch-ingress-without-class=true

# 将下载的文件放至files/ingress,并按"文件名_version"格式命名
```

3. files/metrics/components.yaml(metrics-server)
```bash
# 查看支持版本
https://github.com/kubernetes-sigs/metrics-server?tab=readme-ov-file#compatibility-matrix


wget https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.6.4/components.yaml
wget https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.7.0/components.yaml

# 目前不管你是用v0.6.4还是v0.7.0都是可以的
# 0.7.x	metrics.k8s.io/v1beta1	1.19+
# 0.6.x	metrics.k8s.io/v1beta1	1.19+
```

4. files/dashboard/kubernetes-dashboard.yaml(dashboard)
```bash
# 参考
https://blog.frognew.com/2023/12/kubeadm-install-kubernetes-1.29.html

# 查看版本对应关系
https://github.com/kubernetes/dashboard/releases

# 目前官方没有发布支持最新的v1.28和v1.29版本的支持，只更新到v1.27,我测试v1.28版本也是没有问题的，参考文档使用的v1.29也是可以的。
# 如果版本安装版本为v3.0.0-alpha0，
wget https://raw.githubusercontent.com/kubernetes/dashboard/v3.0.0-alpha0/charts/kubernetes-dashboard.yaml
258    - host: k8s.dashboard.example    # 此处定义部署完成后，访问的域名，通过vars.yaml修改

# 从 Kubernetes Dashboard v3 版本开始，底层架构已经发生了变化，需要进行全新的安装。请先删除之前的安装。
#Kubernetes Dashboard 现在默认使用 cert-manager 和 nginx-ingress-controller 来正常工作。如果您想使用基于清单的安装路径，请确保在集群中已安装它们。如果需要，基于 Helm 的方法可以自动安装所有所需的依赖项。

# ingress在集群初始化时已经安装
# cert-manager查看后面说明


# 如果安装版本为v2.7.0，则不需要cert-manager 和 nginx-ingress-controller，但是需要修改yaml文件的Service.kubernetes-dashboard.spec.ports
wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

---
kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  ports:
    - port: 443
      targetPort: 8443
      nodePoart: 30443    # 定义nodePort访问端口
  selector:
    k8s-app: kubernetes-dashboard
  type: NodePort          # 设置端口类型，默认为ClusterIP
---


# 登录可以使用两种方式登录，一种是创建的token，使用本脚本创建后的token在master1的/root/k8s_install/dashboard_token文件中
# 另一种时kubeconfig file，配置参考链接https://kubernetes.io/zh-cn/docs/tasks/access-application-cluster/configure-access-multiple-clusters/
```

5. files/cert-manager/cert-manager.yaml(cert-manager)
```bash
# 查看版本支持
https://cert-manager.io/docs/releases/
https://github.com/cert-manager/cert-manager/releases


wget https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# will be released on January 31 2024.
wget https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml


```
6. files/prometheus/ (prometheus)
https://github.com/prometheus-operator/kube-prometheus

| kube-prometheus stack                                                                      | Kubernetes 1.22 | Kubernetes 1.23 | Kubernetes 1.24 | Kubernetes 1.25 | Kubernetes 1.26 | Kubernetes 1.27 | Kubernetes 1.28 |
|--------------------------------------------------------------------------------------------|-----------------|-----------------|-----------------|-----------------|-----------------|-----------------|-----------------|
| [`release-0.10`](https://github.com/prometheus-operator/kube-prometheus/tree/release-0.10) | ✔               | ✔               | ✗               | ✗               | x               | x               | x               |
| [`release-0.11`](https://github.com/prometheus-operator/kube-prometheus/tree/release-0.11) | ✗               | ✔               | ✔               | ✗               | x               | x               | x               |
| [`release-0.12`](https://github.com/prometheus-operator/kube-prometheus/tree/release-0.12) | ✗               | ✗               | ✔               | ✔               | x               | x               | x               |
| [`release-0.13`](https://github.com/prometheus-operator/kube-prometheus/tree/release-0.13) | ✗               | ✗               | ✗               | x               | ✔               | ✔               | ✔               |
| [`main`](https://github.com/prometheus-operator/kube-prometheus/tree/main)                 | ✗               | ✗               | ✗               | x               | x               | ✔               | ✔               |

```bash
# 下载对应版本yaml文件
https://github.com/prometheus-operator/kube-prometheus/releases

# 注意事项！！！在0.11版本后添加了NetworkPolicies用于网络控制
release-0.11 / 2022-06-15
[ENHANCEMENT] Adds NetworkPolicies to all components of Kube-prometheus #1650
# 所以使用常规的NodePort方式是无法访问的，害得我找了两天问题究竟出在哪里
# 可能需要修改 grafana-networkPolicy.yaml 中的Ingress策略，我不知道怎么改
# 如果有知道怎么改的可以交流下

# 解决办法，如果你要使用NodePort方式访问，你可以删除这grafana-networkPolicy.yaml，
# 再使用自动playboook执行
# 本项目为了减少操作步骤，采用Ingress的方式访问，无需删除文件


# 替换镜像
# 原始镜像经过测试无法拉取，需要修改两个文件的镜像地址，注意对应版本，
manifests/prometheusAdapter-deployment.yaml
41        image: docker.io/developerxu/prometheus-adapter:v0.11.1
manifests/kubeStateMetrics-deployment.yaml
35        image: docker.io/bitnami/kube-state-metrics:2.9.2

manifests/prometheusAdapter-deployment.yaml
40        image: docker.io/developerxu/prometheus-adapter:v0.10.0
manifests/kubeStateMetrics-deployment.yaml
35        image: docker.io/bitnami/kube-state-metrics:2.7.0


# 如果需要其他版本，需要按照相同的命名方式将release文件夹下载后解压，只保留manifests文件夹即可



# nodePort方式部署参考(注意删除grafana-networkPolicy.yaml)
https://blog.csdn.net/m0_51510236/article/details/132601350
```

7. files/harbor/ (harbor)
```bash
#下载docker-compose,下载后放在files/harbor/,其他不用操作
https://github.com/docker/compose/releases/
# 安装包很大，这里就不上传github了，自行下载
https://github.com/docker/compose/releases/download/${version}/docker-compose-linux-x86_64
#下载安装harbor离线包
https://github.com/goharbor/harbor/releases
# 安装包很大，这里就不上传github了，自行下载
https://github.com/goharbor/harbor/releases/download/${version}/harbor-offline-installer-${version}.tgz
# 放在files/harbor/，删除版本编号harbor-offline-installer.tgz
```
- harbor有两种配置方式，其实就是修改containerd的配置文件
1. 通过账号密码进行认证  
  - /etc/containerd/config.toml
```yaml
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.configs]
        [plugins."io.containerd.grpc.v1.cri".registry.configs."{{ harbor_domain }}".tls]
          insecure_skip_verify = true
        [plugins."io.containerd.grpc.v1.cri".registry.configs."{{ harbor_domain }}".auth]
          username = "admin"
          password = "Harbor12345"
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["https://{{ harbor_domain }}"]
```
2. 通过kubectl创建secert
```bash
kubectl create secret docker-registry harbor-auth \
        --docker-server=https://myharbor.com \
        --docker-username=admin \
        --docker-password=Harbor12345 -n default
```
  - /etc/containerd/config.toml  
```yaml
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.configs]
        [plugins."io.containerd.grpc.v1.cri".registry.configs."{{ harbor_domain }}".tls]
          insecure_skip_verify = true
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["https://{{ harbor_domain }}"]
```
   - 拉镜像时需要配置kubectl创建的secret
```yaml
    spec:
      containers:
        - name: nginx
          image: myharbor.com/test/nginx:latest
          ports:
            - containerPort: 80
      imagePullSecrets:
        - name: harbor-auth
```

### 官方源目前的版本
apt版本
```bash
root@master1:/etc/apt/sources.list.d# apt-cache madison kubeadm
   kubeadm | 1.30.2-1.1 | https://pkgs.k8s.io/core:/stable:/v1.30/deb  Packages
   kubeadm | 1.30.1-1.1 | https://pkgs.k8s.io/core:/stable:/v1.30/deb  Packages
   kubeadm | 1.30.0-1.1 | https://pkgs.k8s.io/core:/stable:/v1.30/deb  Packages
   kubeadm | 1.29.0-1.1 | https://pkgs.k8s.io/core:/stable:/v1.29/deb  Packages
   kubeadm | 1.28.5-1.1 | https://pkgs.k8s.io/core:/stable:/v1.28/deb  Packages
   kubeadm | 1.28.4-1.1 | https://pkgs.k8s.io/core:/stable:/v1.28/deb  Packages
   kubeadm | 1.28.3-1.1 | https://pkgs.k8s.io/core:/stable:/v1.28/deb  Packages
   kubeadm | 1.28.2-1.1 | https://pkgs.k8s.io/core:/stable:/v1.28/deb  Packages
   kubeadm | 1.28.1-1.1 | https://pkgs.k8s.io/core:/stable:/v1.28/deb  Packages
   kubeadm | 1.28.0-1.1 | https://pkgs.k8s.io/core:/stable:/v1.28/deb  Packages
   kubeadm | 1.27.9-1.1 | https://pkgs.k8s.io/core:/stable:/v1.27/deb  Packages
   kubeadm | 1.27.8-1.1 | https://pkgs.k8s.io/core:/stable:/v1.27/deb  Packages
   kubeadm | 1.27.7-1.1 | https://pkgs.k8s.io/core:/stable:/v1.27/deb  Packages
   kubeadm | 1.27.6-1.1 | https://pkgs.k8s.io/core:/stable:/v1.27/deb  Packages
   kubeadm | 1.27.5-1.1 | https://pkgs.k8s.io/core:/stable:/v1.27/deb  Packages
   kubeadm | 1.27.4-1.1 | https://pkgs.k8s.io/core:/stable:/v1.27/deb  Packages
   kubeadm | 1.27.3-1.1 | https://pkgs.k8s.io/core:/stable:/v1.27/deb  Packages
   kubeadm | 1.27.2-1.1 | https://pkgs.k8s.io/core:/stable:/v1.27/deb  Packages
   kubeadm | 1.27.1-1.1 | https://pkgs.k8s.io/core:/stable:/v1.27/deb  Packages
   kubeadm | 1.27.0-2.1 | https://pkgs.k8s.io/core:/stable:/v1.27/deb  Packages
   kubeadm | 1.26.12-1.1 | https://pkgs.k8s.io/core:/stable:/v1.26/deb  Packages
   kubeadm | 1.26.11-1.1 | https://pkgs.k8s.io/core:/stable:/v1.26/deb  Packages
   kubeadm | 1.26.10-1.1 | https://pkgs.k8s.io/core:/stable:/v1.26/deb  Packages
   kubeadm | 1.26.9-1.1 | https://pkgs.k8s.io/core:/stable:/v1.26/deb  Packages
   kubeadm | 1.26.8-1.1 | https://pkgs.k8s.io/core:/stable:/v1.26/deb  Packages
   kubeadm | 1.26.7-1.1 | https://pkgs.k8s.io/core:/stable:/v1.26/deb  Packages
   kubeadm | 1.26.6-1.1 | https://pkgs.k8s.io/core:/stable:/v1.26/deb  Packages
   kubeadm | 1.26.5-1.1 | https://pkgs.k8s.io/core:/stable:/v1.26/deb  Packages
   kubeadm | 1.26.4-1.1 | https://pkgs.k8s.io/core:/stable:/v1.26/deb  Packages
   kubeadm | 1.26.3-1.1 | https://pkgs.k8s.io/core:/stable:/v1.26/deb  Packages
   kubeadm | 1.26.2-1.1 | https://pkgs.k8s.io/core:/stable:/v1.26/deb  Packages
   kubeadm | 1.26.1-1.1 | https://pkgs.k8s.io/core:/stable:/v1.26/deb  Packages
   kubeadm | 1.26.0-2.1 | https://pkgs.k8s.io/core:/stable:/v1.26/deb  Packages
   kubeadm | 1.25.16-1.1 | https://pkgs.k8s.io/core:/stable:/v1.25/deb  Packages
   kubeadm | 1.25.15-1.1 | https://pkgs.k8s.io/core:/stable:/v1.25/deb  Packages
   kubeadm | 1.25.14-1.1 | https://pkgs.k8s.io/core:/stable:/v1.25/deb  Packages
   kubeadm | 1.25.13-1.1 | https://pkgs.k8s.io/core:/stable:/v1.25/deb  Packages
   kubeadm | 1.25.12-1.1 | https://pkgs.k8s.io/core:/stable:/v1.25/deb  Packages
   kubeadm | 1.25.11-1.1 | https://pkgs.k8s.io/core:/stable:/v1.25/deb  Packages
   kubeadm | 1.25.10-1.1 | https://pkgs.k8s.io/core:/stable:/v1.25/deb  Packages
   kubeadm | 1.25.9-1.1 | https://pkgs.k8s.io/core:/stable:/v1.25/deb  Packages
   kubeadm | 1.25.8-1.1 | https://pkgs.k8s.io/core:/stable:/v1.25/deb  Packages
   kubeadm | 1.25.7-1.1 | https://pkgs.k8s.io/core:/stable:/v1.25/deb  Packages
   kubeadm | 1.25.6-1.1 | https://pkgs.k8s.io/core:/stable:/v1.25/deb  Packages
   kubeadm | 1.25.5-1.1 | https://pkgs.k8s.io/core:/stable:/v1.25/deb  Packages
   kubeadm | 1.25.4-1.1 | https://pkgs.k8s.io/core:/stable:/v1.25/deb  Packages
   kubeadm | 1.25.3-1.1 | https://pkgs.k8s.io/core:/stable:/v1.25/deb  Packages
   kubeadm | 1.25.2-1.1 | https://pkgs.k8s.io/core:/stable:/v1.25/deb  Packages
   kubeadm | 1.25.1-1.1 | https://pkgs.k8s.io/core:/stable:/v1.25/deb  Packages
   kubeadm | 1.25.0-2.1 | https://pkgs.k8s.io/core:/stable:/v1.25/deb  Packages
```
yum版本
```bash
[root@master1 yum.repos.d]# yum --showduplicates list kubeadm
Available Packages
kubeadm.x86_64                           1.25.0-150500.2.1                            kubernetes1.25
kubeadm.x86_64                           1.25.1-150500.1.1                            kubernetes1.25
kubeadm.x86_64                           1.25.2-150500.1.1                            kubernetes1.25
kubeadm.x86_64                           1.25.3-150500.1.1                            kubernetes1.25
kubeadm.x86_64                           1.25.4-150500.1.1                            kubernetes1.25
kubeadm.x86_64                           1.25.5-150500.1.1                            kubernetes1.25
kubeadm.x86_64                           1.25.6-150500.1.1                            kubernetes1.25
kubeadm.x86_64                           1.25.7-150500.1.1                            kubernetes1.25
kubeadm.x86_64                           1.25.8-150500.1.1                            kubernetes1.25
kubeadm.x86_64                           1.25.9-150500.1.1                            kubernetes1.25
kubeadm.x86_64                           1.25.10-150500.1.1                           kubernetes1.25
kubeadm.x86_64                           1.25.11-150500.1.1                           kubernetes1.25
kubeadm.x86_64                           1.25.12-150500.1.1                           kubernetes1.25
kubeadm.x86_64                           1.25.13-150500.1.1                           kubernetes1.25
kubeadm.x86_64                           1.25.14-150500.1.1                           kubernetes1.25
kubeadm.x86_64                           1.25.15-150500.1.1                           kubernetes1.25
kubeadm.x86_64                           1.25.16-150500.1.1                           kubernetes1.25
kubeadm.x86_64                           1.26.0-150500.2.1                            kubernetes1.26
kubeadm.x86_64                           1.26.1-150500.1.1                            kubernetes1.26
kubeadm.x86_64                           1.26.2-150500.1.1                            kubernetes1.26
kubeadm.x86_64                           1.26.3-150500.1.1                            kubernetes1.26
kubeadm.x86_64                           1.26.4-150500.1.1                            kubernetes1.26
kubeadm.x86_64                           1.26.5-150500.1.1                            kubernetes1.26
kubeadm.x86_64                           1.26.6-150500.1.1                            kubernetes1.26
kubeadm.x86_64                           1.26.7-150500.1.1                            kubernetes1.26
kubeadm.x86_64                           1.26.8-150500.1.1                            kubernetes1.26
kubeadm.x86_64                           1.26.9-150500.1.1                            kubernetes1.26
kubeadm.x86_64                           1.26.10-150500.1.1                           kubernetes1.26
kubeadm.x86_64                           1.26.11-150500.1.1                           kubernetes1.26
kubeadm.x86_64                           1.26.12-150500.1.1                           kubernetes1.26
kubeadm.x86_64                           1.26.13-150500.1.1                           kubernetes1.26
kubeadm.x86_64                           1.27.0-150500.2.1                            kubernetes1.27
kubeadm.x86_64                           1.27.1-150500.1.1                            kubernetes1.27
kubeadm.x86_64                           1.27.2-150500.1.1                            kubernetes1.27
kubeadm.x86_64                           1.27.3-150500.1.1                            kubernetes1.27
kubeadm.x86_64                           1.27.4-150500.1.1                            kubernetes1.27
kubeadm.x86_64                           1.27.5-150500.1.1                            kubernetes1.27
kubeadm.x86_64                           1.27.6-150500.1.1                            kubernetes1.27
kubeadm.x86_64                           1.27.7-150500.1.1                            kubernetes1.27
kubeadm.x86_64                           1.27.8-150500.1.1                            kubernetes1.27
kubeadm.x86_64                           1.27.9-150500.1.1                            kubernetes1.27
kubeadm.x86_64                           1.27.10-150500.1.1                           kubernetes1.27
kubeadm.x86_64                           1.28.0-150500.1.1                            kubernetes1.28
kubeadm.x86_64                           1.28.1-150500.1.1                            kubernetes1.28
kubeadm.x86_64                           1.28.2-150500.1.1                            kubernetes1.28
kubeadm.x86_64                           1.28.3-150500.1.1                            kubernetes1.28
kubeadm.x86_64                           1.28.4-150500.1.1                            kubernetes1.28      已测试通过
kubeadm.x86_64                           1.28.5-150500.1.1                            kubernetes1.28
kubeadm.x86_64                           1.28.6-150500.1.1                            kubernetes1.28
kubeadm.x86_64                           1.29.0-150500.1.1                            kubernetes1.29
kubeadm.x86_64                           1.29.1-150500.1.1                            kubernetes1.29
```
