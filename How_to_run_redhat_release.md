# Ansible使用kubeadm方式一键安装k8s(centos7.9)
项目地址  
https://github.com/AYYQ127/k8s_kubeadm_install


# 从此我也是对k8s社区有贡献的人
事情经过，在准备centos的自动化安装脚本时，我发现复制官方的镜像源配置一直报错，眼尖的我发现少了一个字母"v"
https://kubernetes.io/zh-cn/docs/tasks/administer-cluster/kubeadm/change-package-repository/
![少了两个v.png](https://s2.loli.net/2024/01/19/6ZNyiGpsJlnMOTv.png)
![回复邮件.png](https://s2.loli.net/2024/01/19/6QKLzXMmJDk5h1b.png)
![k8s社区贡献.png](https://s2.loli.net/2024/01/19/1RSWUIlyscn5pkY.png)


## 示例

### 系统环境
Centos7.9

### 集群规划
主机名可以不用改强制修改为这样，只需要主机名，/etc/hosts和/etc/ansible/hosts都一致即可
主机名 | IP | 用途 
------------|------------|------------
master1  | 192.168.181.11 | 集群主节点1
master2  | 192.168.181.12 | 集群主节点2
node1    | 192.168.181.13 | 工作节点1
node2    | 192.168.181.14 | 工作节点2

### 检查网络环境
四个节点都检查一遍，确保网络没有问题，涉及到后面拉取镜像
```bash
[root@master1 ~]# ping pkgs.k8s.io
PING redirect.k8s.io (34.107.204.206) 56(84) bytes of data.
64 bytes from 206.204.107.34.bc.googleusercontent.com (34.107.204.206): icmp_seq=1 ttl=128 time=158 ms

[root@master1 ~]# ping registry.aliyuncs.com
PING registry.aliyuncs.com (120.55.105.209) 56(84) bytes of data.
64 bytes from 120.55.105.209 (120.55.105.209): icmp_seq=1 ttl=128 time=30.4 ms

```

### 手动修改所有节点hostname(请注意: 主机名，ansible节点，/etc/hosts要保持一致)
```bash 
[root@master1 ~]# hostnamectl set-hostname master1
[root@master2 ~]# hostnamectl set-hostname master2
[root@node1 ~]# hostnamectl set-hostname node1
[root@node2 ~]# hostnamectl set-hostname node2
```

### 手动修改主节点1/etc/hosts(请注意: 主机名，ansible节点，/etc/hosts要保持一致)
```bash 
[root@master1 ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6


192.168.181.11 master1
192.168.181.12 master2
192.168.181.13 node1
192.168.181.14 node2

```

### 配置免密(主节点1)
生成密钥
```bash
[root@master1 ~]# ssh-keygen
Generating public/private rsa key pair.
Enter file in which to save the key (/root/.ssh/id_rsa):
Created directory '/root/.ssh'.
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /root/.ssh/id_rsa.
Your public key has been saved in /root/.ssh/id_rsa.pub.
The key fingerprint is:
SHA256:IhGroFT22rFJKOQTECWGm2SfPbvw8IW+Q0MvgAtDEBE root@master1
The key's randomart image is:
+---[RSA 2048]----+
|EX.o.            |
|==+ oo           |
|=Bo.=+           |
|Boo=+=+          |
|o.o.++* S        |
| . o B +         |
|    B =          |
|     *           |
|     .o          |
+----[SHA256]-----+
```

复制密钥到各个节点，包括自己 
循环四次依次输入yes和密码
```bash
[root@master1 ~]# for i in {master1,master2,node1,node2}; do  ssh-copy-id root@$i; done

/usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: "/root/.ssh/id_rsa.pub"
The authenticity of host 'master1 (192.168.152.200)' can't be established.
ECDSA key fingerprint is SHA256:1QncUYX+qzfiSSNgIiU7NQtEBZEuv6+sHOwb7gGdseY.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
root@master1's password:

Number of key(s) added: 1

Now try logging into the machine, with:   "ssh 'root@master1'"
and check to make sure that only the key(s) you wanted were added.
...其他三次省略
```
确认可以使用以下方式远程到四台机
```bash
[root@master1 ~]# ssh root@master1
[root@master1 ~]# ssh root@master2
[root@master1 ~]# ssh root@node1
[root@master1 ~]# ssh root@node2

```

### 更换主节点1系统源
https://help.mirrors.cernet.edu.cn/epel/  
```bash
[root@master1 ~]# sudo yum install epel-release -y
[root@master1 ~]# sudo sed -e 's!^metalink=!#metalink=!g'     -e 's!^#baseurl=!baseurl=!g'     -e 's!https\?://download\.fedoraproject\.org/pub/epel!https://mirrors.cernet.edu.cn/epel!g'     -e 's!https\?://download\.example/pub/epel!https://mirrors.cernet.edu.cn/epel!g'     -i /etc/yum.repos.d/epel{,-testing}.repo

[root@master1 ~]# yum update -y
```

### 安装ansible(在主节点安装)
```bash
[root@master1 ~]# yum -y install ansible
[root@master1 ~]# mkdir -p /etc/ansible/
```

### 复制整个k8s_kubeadm_install到主节点任意位置
https://github.com/AYYQ127/k8s_kubeadm_install
```bash
[root@master1 k8s_kubeadm_install]# tree
.
├── files
│   ├── ansible
│   │   ├── ansible.cfg
│   │   └── hosts
│   ├── calico
│   │   ├── custom-resources_v3.26.4.yaml
│   │   ├── custom-resources_v3.27.0.yaml
│   │   ├── tigera-operator_v3.26.4.yaml
│   │   └── tigera-operator_v3.27.0.yaml
│   ├── ingress
│   │   ├── deploy_v1.9.4.yaml
│   │   └── deploy_v1.9.5.yaml
│   ├── k8s_pkgs
│   │   ├── docker-ce.repo
│   │   ├── kubernetes-apt-keyring.gpg
│   │   ├── kubernetes-lock.repo
│   │   ├── kubernetes-nolock.repo
│   │   ├── repomd.xml.key
│   │   └── source.list
│   ├── metrics
│   │   └── components.yaml
│   ├── rancher
│   ├── test-ingress.yaml
│   └── vars.yaml
├── How_to_run.md
├── How_to_run_redhat_release.md
├── LICENSE
├── playbooks
│   ├── dashboard_install.yaml
│   ├── harbor_install.yaml
│   ├── main_redhat_release.yaml
│   ├── main.yaml
│   ├── metrics_server_install.yaml
│   └── prometheus_install.yaml
└── README.md

```

### 在主节点1准备ansible环境
```bash 
[root@master1 k8s_kubeadm_install~]# vim files/ansible/hosts
[root@master1 k8s_kubeadm_install~]# cat files/ansible/hosts
# 修改hosts节点名,分组不能修改,只加/etc/hosts中对应主机名

###                                                           
#
# 如果不想使用22端口ssh连接,可以添加变量ansible_ssh_port=port_num
# 例如：
# [manage_node]
# master1 ansible_ssh_port=2222
#
#
###

# 执行安装的节点,第一台master
[manage_node]
master1 

# 其他主节点在此添加,不要再加manage_node
[other_masters]
master2 

# 工作节点在此添加
[nodes]
node1 
node2 


# ****************以下内容不要修改*****************

# 除了操作节点的所有节点
[except_manage_node:children]
other_masters
nodes

# 所有主节点(请勿修改)
[masters:children]
manage_node
other_masters

# 所有节点分组(请勿修改)
[k8s:children]
manage_node
other_masters
nodes 


```
```bash
# 修改hosts节点名,分组不能修改(请注意: 主机名，ansible节点，/etc/hosts要保持一致)
[root@master1 k8s_kubeadm_install~]# \cp -r files/ansible /etc/
```


### 使用ansible统一修改hosts和yum源
```bash
[root@master1 k8s_kubeadm_install~]# ansible k8s -m copy -a "src=/etc/hosts dest=/etc/hosts"
[root@master1 k8s_kubeadm_install~]# ansible k8s -m yum -a "update_cache=yes"
[root@master1 k8s_kubeadm_install~]# ansible k8s -m yum -a "name=epel-release state=latest"
[root@master1 k8s_kubeadm_install~]# ansible k8s -m copy -a "src=/etc/yum.repos.d/epel.repo dest=/etc/yum.repos.d/"
[root@master1 k8s_kubeadm_install~]# ansible k8s -m copy -a "src=/etc/yum.repos.d/epel-testing.repo dest=/etc/yum.repos.d/"
[root@master1 k8s_kubeadm_install~]# ansible k8s -m yum -a "update_cache=yes"
```

### 修改files/vars.yaml(主节点1)  
<strong>指定版本，master节点ip等信息</strong>

```bash
[root@master1 k8s_kubeadm_install~]# cat files/vars.yaml
# 时间服务器
NTP: 192.168.181.11

# 控制面板主机名，不需要修改，固定为[manage_node]
control_plane_endpoint: master1

# kubeadm init使用，大版本号，不需要后缀
kubernetes_version: v1.28.4

# 详细版本请看README.md
# apt版本修改这个
kube_3tools_version: 1.28.4-1.1
# yum版本修改这个
kube_3tools_version_yum: 1.28.4-150500.1.1

# 定义pod的cidr网络，kubeadm init使用
pod_network_cidr: 10.244.0.0/16
# kubeadm init使用
apiserver_advertise_address: 192.168.181.11

# 修改calico使用custom-resources.yaml使用
pod_network: 10.244.0.0

# pause所使用镜像版本，需要替换阿里源，官方源国内无法拉取
sandbox_image: pause:3.9

# 有版本依赖，请参考README.md指引更换版本
calico_version: v3.26.4

# 有版本依赖，请参考README.md指引更换版本
ingress_version: v1.9.4

# 有版本依赖，请参考README.md指引更换版本
metrics_server_version: v0.6.4

# 有版本依赖，请参考README.md指引更换版本
kubernetes_dashboard_version: v3.0.0-alpha0
# v3.0.0-alpha0版本ingress中指定的host，用于部署完成后浏览器访问
dashboard_host: k8s.dashboard.example
# 版本低于v3的需要指定端口，请前往k8s_kubeadm_install/files/dashboard/README.md查看
#nodePoart: 30443

# 有版本依赖，请参考README.md指引更换版本
# dashboard版本v3以后必须安装
cert_manager_version: v1.13.3
```


### Run
<strong>必须确认vars.yaml变量是否修改</strong>control_plane_endpoint需要与hosts文件格式一致

安装过程分为三步，第一步会重启所有节点，重启后再次进入主节点1目录运行相同命令(总共执行两次)
```bash
# 默认只安装集群基础功能
[root@master1 k8s_kubeadm_install~]# ansible-playbook playbooks/main_redhat_release.yaml

PLAY [第一步初始化系统] ***********************************************************************************************************************************************************************************************
...
...

PLAY [第二步安装kubeadmin] ***************************************************************************************************************************************************************************************
...
...
PLAY [第三步初始化集群,添加工作节点] ***************************************************************************************************************************************************************************************
...
PLAY RECAP ****************************************************************************************************************************************************************************************************
localhost                  : ok=26   changed=18   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
master1                    : ok=20   changed=16   unreachable=0    failed=0    skipped=17   rescued=0    ignored=0
master2                    : ok=20   changed=15   unreachable=0    failed=0    skipped=17   rescued=0    ignored=0
node1                      : ok=20   changed=15   unreachable=0    failed=0    skipped=17   rescued=0    ignored=0
node2                      : ok=20   changed=16   unreachable=0    failed=0    skipped=17   rescued=0    ignored=0

```

```bash
# 等4-5分钟执行以下命令，集群安装完毕
[root@master1 k8s_kubeadm_install~]# kubectl get nodes
NAME      STATUS   ROLES           AGE     VERSION
master1   Ready    control-plane   6m39s   v1.28.4
master2   Ready    control-plane   5m3s    v1.28.4
node1     Ready    node            6m16s   v1.28.4
node2     Ready    node            6m13s   v1.28.4
```

```bash
# 选装其他插件,harbor需要修改ansible/hosts中分组和/etc/hosts解析
[root@master1 k8s_kubeadm_install~]# ansible-playbook playbooks/main_redhat_release.yaml -t [metrics | harbor | dashboard | prometheus]
```


```bash 
# 暂时只支持metrics
[root@master1 k8s_kubeadm_install]# ansible-playbook playbooks/main_redhat_release.yaml  -t metrics

PLAY [第一步初始化系统] 
********************************

PLAY [第二步 安装 kubeadmin] 
********************************

PLAY [第三步 初始化集群,添加工作节点] 
********************************

PLAY [创建metrics-server资源对象] 
********************************

TASK [检查metrics.lock文件是否存在]  
********************************
ok: [localhost]

TASK [创建metrics-server资源对象]  
********************************
changed: [localhost]

PLAY [开启聚合API]  
********************************

TASK [检查metrics.lock文件是否存在]  
********************************
ok: [master2]
ok: [master1]

TASK [开启聚合API]  
********************************
changed: [master2]
changed: [master1]

TASK [重启kubelet]  
********************************
changed: [master2]
changed: [master1]

PLAY [为kubelet签发证书]  
********************************

TASK [检查metrics.lock文件是否存在]  
********************************
ok: [master2]
ok: [node2]
ok: [node1]
ok: [master1]

TASK [在最后一行插入]  
********************************
changed: [node2]
changed: [master2]
changed: [node1]
changed: [master1]

TASK [重启kubelet]  
********************************
changed: [node2]
changed: [master2]
changed: [node1]
changed: [master1]

PLAY [签发证书]  
********************************

TASK [检查metrics.lock文件是否存在]  
********************************
ok: [master1]

TASK [暂停15秒]  
********************************
Pausing for 15 seconds
(ctrl+C then 'C' = continue early, ctrl+C then 'A' = abort)
ok: [master1]

TASK [获取新发证书名]  
********************************
changed: [master1]

TASK [正式签发证书]  
********************************
changed: [master1] => (item=csr-2q9wb)
changed: [master1] => (item=csr-pwtj6)
changed: [master1] => (item=csr-wll9j)
changed: [master1] => (item=csr-z7wbp)

PLAY [创建lock文件]  
********************************

TASK [检查metrics.lock文件是否存在]  
********************************
ok: [node2]
ok: [node1]
ok: [master2]
ok: [master1]

TASK [file]  
********************************
changed: [master2]
changed: [node1]
changed: [node2]
changed: [master1]

PLAY RECAP  
********************************
localhost                  : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
master1                    : ok=12   changed=7    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
master2                    : ok=8    changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
node1                      : ok=5    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
node2                      : ok=5    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

# 等待pod创建完成
[root@master1 k8s_kubeadm_install]# kubectl get pod -A | grep metrics
kube-system        metrics-server-5b779d9499-znctk            1/1     Running     0              2m5s
[root@master1 k8s_kubeadm_install]# kubectl top node
NAME      CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
master1   120m         6%     1852Mi          50%
master2   115m         5%     1947Mi          53%
node1     46m          2%     1512Mi          41%
node2     46m          2%     1558Mi          42%

```

```bash 
# dashboard
[root@master1 k8s_kubeadm_install]# ansible-playbook playbooks/main_redhat_release.yaml  -t dashboard

PLAY [创建dashboard资源对象] ************************************************************************************************************************************************************************

TASK [检查dashboard.lock文件是否存在] *****************************************************************************************************************************************************************
ok: [localhost]

TASK [请确认cert_manager已经安装] ********************************************************************************************************************************************************************
ok: [localhost] => {
    "msg": "\"请确认cert_manager已经安装,如果没有,请终止playboook,执行ansible-playbook playbooks/main.yaml  -t cert_manager\"\n"
}

TASK [请确认cert_manager已经安装,暂停15秒] **************************************************************************************************************************************************************
Pausing for 15 seconds
(ctrl+C then 'C' = continue early, ctrl+C then 'A' = abort)
Press 'C' to continue the play or 'A' to abort
ok: [localhost]

TASK [判断版本是不是v2.7.0] **************************************************************************************************************************************************************************
skipping: [localhost]

TASK [创建dashboard资源对象] ************************************************************************************************************************************************************************
changed: [localhost]

TASK [授权] *************************************************************************************************************************************************************************************
changed: [localhost]

TASK [生成token] ********************************************************************************************************************************************************************************
changed: [localhost]

TASK [将token写入一个文件保存起来] ***********************************************************************************************************************************************************************
changed: [localhost] => (item=eyJhbGciOiJSUzI1NiIsImtpZCI6IlhDVUhuNEVIR3VublplRlAwa0NZOUY1bWNoZXhJWnRVRElyYUM5UmVjME0ifQ.eyJhdWQiOlsiaHR0cHM6Ly9rdWJlcm5ldGVzLmRlZmF1bHQuc3ZjLmNsdXN0ZXIubG9jYWwiXSwiZXhwIjoyMDIxNjkyMTc4LCJpYXQiOjE3MDYzMzIxNzgsImlzcyI6Imh0dHBzOi8va3ViZXJuZXRlcy5kZWZhdWx0LnN2Yy5jbHVzdGVyLmxvY2FsIiwia3ViZXJuZXRlcy5pbyI6eyJuYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsInNlcnZpY2VhY2NvdW50Ijp7Im5hbWUiOiJrdWJlLWRhc2hib2FyZC1hZG1pbi1zYSIsInVpZCI6IjM4NDk1MjhjLWU0ODktNDQ5NC04MGQzLTExMjM4MTY3MTZkMCJ9fSwibmJmIjoxNzA2MzMyMTc4LCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6a3ViZS1zeXN0ZW06a3ViZS1kYXNoYm9hcmQtYWRtaW4tc2EifQ.VrzelIRT_JF2TnBlV3Fvg0YPfXGRLu_48IX7QkVFgyFMpMd_nk7rBSqZJwULNOS-e-n07oiEv4gzzCUNknsLsAFmA8CgqCRELGQX_fviOKJHZ-S38nFIVS0TeI-BZvTSFnJo9zUFSFAHKOZ0zmjFhIORwsnRGkJyS9u7kvHWNDFMccd15WgmtO9jh9NjBsoR838P8LWsn2c48-G8nsBsP3TtUTy1rpZkbTBSPvfLgGEulSMQUms_51Q5GNDk1sUpLVeIy8ZxLcWyeyvlKYbH_qPyRUzH5yaDW6KmQiPb0PftR7Ip6vQd-xOc7GdjagV2wv8OV5kEhOTHcvS2jRDAKw)

TASK [dashboard的token请查看/root/k8s_install/dashboard_token] ************************************************************************************************************************************
ok: [localhost] => {
    "msg": "cat /root/k8s_install/dashboard_token\n"
}

TASK [创建安装lock文件] *****************************************************************************************************************************************************************************
changed: [localhost]

PLAY RECAP ************************************************************************************************************************************************************************************
localhost                  : ok=9    changed=5    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0


[root@master1 k8s_kubeadm_install]# kubectl -n kubernetes-dashboard  get service
NAME                        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)         AGE
dashboard-metrics-scraper   ClusterIP   10.96.210.243   <none>        8000/TCP        2m48s
kubernetes-dashboard        NodePort    10.97.130.151   <none>        443:30443/TCP   40s

```

