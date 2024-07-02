# Ansible使用kubeadm方式一键安装k8s
项目地址  
https://github.com/AYYQ127/k8s_kubeadm_install

## 示例

### 系统环境
ubuntu22.04  
**如果计划使用高可用，请安装ubuntu22.04版本系统**  
[高可用集群](files/ha/README.md)

### 集群规划
主机名可以不用改强制修改为这样，只需要主机名，/etc/hosts和/etc/ansible/hosts都一致即可
主机名 | IP | 用途 
------------|------------|------------
master1  | 192.168.152.200 | 集群主节点1
master2  | 192.168.152.201 | 集群主节点2
node1    | 192.168.152.210 | 工作节点1
node2    | 192.168.152.211 | 工作节点2
harbor   | 192.168.152.220 | 私有镜像仓

### 检查网络环境
四个节点都检查一遍，确保网络没有问题，涉及到后面拉取镜像
```bash
ada@master1:~$ ping pkgs.k8s.io
PING redirect.k8s.io (34.107.204.206) 56(84) bytes of data.
64 bytes from 206.204.107.34.bc.googleusercontent.com (34.107.204.206): icmp_seq=1 ttl=128 time=163 ms

ada@master1:~$ ping registry.aliyuncs.com
PING registry.aliyuncs.com (120.55.105.209) 56(84) bytes of data.
64 bytes from 120.55.105.209 (120.55.105.209): icmp_seq=1 ttl=128 time=30.6 ms
```

### 手动修改所有节点hostname(请注意: 主机名，ansible节点，/etc/hosts要保持一致)
```bash 
ada@master1:~$ sudo hostnamectl set-hostname master1
ada@master2:~$ sudo hostnamectl set-hostname master2
ada@node1:~$ sudo hostnamectl set-hostname node1
ada@node2:~$ sudo hostnamectl set-hostname node2
```

### 手动修改主节点1/etc/hosts(请注意: 主机名，ansible节点，/etc/hosts要保持一致)
```bash 
root@master1:~$ cat /etc/hosts
127.0.0.1 localhost
127.0.1.1 base

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters


192.168.152.200 master1
192.168.152.201 master2
192.168.152.210 node1
192.168.152.211 node2
```

### 配置免密(主节点1)
生成密钥
```bash
ada@master1:~$ sudo su -
root@master1:~# ssh-keygen
Generating public/private rsa key pair.
Enter file in which to save the key (/root/.ssh/id_rsa):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /root/.ssh/id_rsa
Your public key has been saved in /root/.ssh/id_rsa.pub
The key fingerprint is:
SHA256:ZYvD8SqDla9v10b843N/xMMWWS750HEF6m3HbXVAScs root@master1
The key's randomart image is:
+---[RSA 3072]----+
|             o=oo|
|             o.+o|
|        . o . E+B|
|       o * o .++*|
|      o S o.. +=*|
|     o . o  o. *+|
|    . o o  o ....|
|       +. . o + o|
|      .o.. . ..++|
+----[SHA256]-----+
```

暂时开启root密码登录 (四个节点都要操作)
```bash
root@master1:~# echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
root@master1:~# systemctl restart sshd.service
root@master1:~# passwd root
New password:
Retype new password:
passwd: password updated successfully

root@master2:~# echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
root@master2:~# systemctl restart sshd.service
root@master2:~# passwd root
New password:
Retype new password:
passwd: password updated successfully

root@node1:~# echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
root@node1:~# systemctl restart sshd.service
root@node1:~# passwd root
New password:
Retype new password:
passwd: password updated successfully

root@node2:~# echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
root@node2:~# systemctl restart sshd.service
root@node2:~# passwd root
New password:
Retype new password:
passwd: password updated successfully

```

复制密钥到各个节点，包括自己 
循环四次依次输入yes和密码
```bash
root@master1:~# for i in {master1,node1,node2,harbor}; do  ssh-copy-id root@$i; done

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
root@master1:~# ssh root@master1
root@master1:~# ssh root@master2
root@master1:~# ssh root@node1
root@master1:~# ssh root@node2

```

再关闭root密码登录(所有节点都要操作)
```bash
root@master1:~# sed -i '$d' /etc/ssh/sshd_config
root@master1:~# systemctl restart sshd.service

root@master2:~# sed -i '$d' /etc/ssh/sshd_config
root@master2:~# systemctl restart sshd.service

root@node1:~# sed -i '$d' /etc/ssh/sshd_config
root@node1:~# systemctl restart sshd.service

root@node2:~# sed -i '$d' /etc/ssh/sshd_config
root@node2:~# systemctl restart sshd.service
```


### 更换主节点1系统源
https://help.mirrors.cernet.edu.cn/ubuntu/   
选择系统版本20.04  
```bash
ada@master1:~$ sudo su -
root@master1:~# cat <<'EOF' > /etc/apt/sources.list
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.cernet.edu.cn/ubuntu/ focal main restricted universe multiverse
# deb-src https://mirrors.cernet.edu.cn/ubuntu/ focal main restricted universe multiverse
deb https://mirrors.cernet.edu.cn/ubuntu/ focal-updates main restricted universe multiverse
# deb-src https://mirrors.cernet.edu.cn/ubuntu/ focal-updates main restricted universe multiverse
deb https://mirrors.cernet.edu.cn/ubuntu/ focal-backports main restricted universe multiverse
# deb-src https://mirrors.cernet.edu.cn/ubuntu/ focal-backports main restricted universe multiverse

# deb https://mirrors.cernet.edu.cn/ubuntu/ focal-security main restricted universe multiverse
# # deb-src https://mirrors.cernet.edu.cn/ubuntu/ focal-security main restricted universe multiverse

deb http://security.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse
# deb-src http://security.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse

# 预发布软件源，不建议启用
# deb https://mirrors.cernet.edu.cn/ubuntu/ focal-proposed main restricted universe multiverse
# # deb-src https://mirrors.cernet.edu.cn/ubuntu/ focal-proposed main restricted universe multiverse
EOF
root@master1:~# apt update
# 其他节点类似
```

### 安装ansible(在主节点安装)
```bash
root@master1:~# apt install ansible -y
root@master1:~# mkdir -p /etc/ansible/
```

### 复制整个k8s_kubeadm_install到主节点任意位置
https://github.com/AYYQ127/k8s_kubeadm_install
```bash
root@master1:~/k8s_kubeadm_install# tree
.
├── How_to_run.md
├── How_to_run_redhat_release.md
├── LICENSE
├── README.md
├── files
│   ├── ansible
│   │   ├── ansible.cfg
│   │   └── hosts
│   ├── calico
│   │   ├── custom-resources_v3.26.4.yaml
│   │   ├── custom-resources_v3.27.0.yaml
│   │   ├── tigera-operator_v3.26.4.yaml
│   │   └── tigera-operator_v3.27.0.yaml
│   ├── cert-manager
│   │   ├── cert-manager_v1.13.3.yaml
│   │   └── cert-manager_v1.14.0-beta.0.yaml
│   ├── dashboard
│   │   ├── README.md
│   │   ├── kubernetes-dashboard_v2.7.0.yaml
│   │   └── kubernetes-dashboard_v3.0.0-alpha0.yaml
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
│   │   ├── components_v0.6.4.yaml
│   │   └── components_v0.7.0.yaml
│   ├── rancher
│   ├── test-ingress.yaml
│   └── vars.yaml
└── playbooks
    ├── cert_manager_install.yaml
    ├── dashboard_install.yaml
    ├── harbor_install.yaml
    ├── main.yaml
    ├── main_redhat_release.yaml
    ├── metrics_server_install.yaml
    └── prometheus_install.yaml
```

### 在主节点1准备ansible环境
```bash 
root@master1:~/k8s_kubeadm_install# vim files/ansible/hosts
root@master1:~/k8s_kubeadm_install# cat files/ansible/hosts
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
root@master1:~/k8s_kubeadm_install# cp -r files/ansible /etc/
```


### 使用ansible统一修改hosts和apt源
```bash
root@master1:~/k8s_kubeadm_install# ansible k8s -m copy -a "src=/etc/hosts dest=/etc/hosts"
root@master1:~/k8s_kubeadm_install# ansible k8s -m copy -a "src=/etc/apt/sources.list dest=/etc/apt/sources.list"
root@master1:~/k8s_kubeadm_install# ansible k8s -m apt -a "update_cache=yes"
```

### 修改files/vars.yaml(主节点1)  
<strong>指定版本，master节点ip等信息</strong>

```bash
root@master1:~/k8s_kubeadm_install# cat files/vars.yaml
# 时间服务器
NTP: 192.168.181.132

# 控制面板主机名，不需要修改，固定为[manage_node]
control_plane_endpoint: master1

# kubeadm init使用，大版本号，不需要后缀
kubernetes_version: v1.28.4

# 通常官方源的版本后缀为-1.1.阿里云的为-00,详细版本请看README.md
kube_3tools_version: 1.28.4-1.1

# 定义pod的cidr网络，kubeadm init使用
pod_network_cidr: 10.244.0.0/16
# kubeadm init使用
apiserver_advertise_address: 192.168.181.132

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


### Init-Run
<strong>必须确认vars.yaml变量是否修改</strong>control_plane_endpoint需要与hosts文件格式一致

安装过程分为三步，第一步会重启所有节点，重启后再次进入主节点1目录运行相同命令(总共执行两次)
```bash
# 默认只安装集群基础功能
ada@master1:~$ sudo su - 
root@master1:~$ cd k8s_kubeadm_install
root@master1:~/k8s_kubeadm_install# ansible-playbook playbooks/main.yaml

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
root@master1:~/k8s_kubeadm_install# kubectl get nodes
NAME      STATUS   ROLES           AGE     VERSION
master1   Ready    control-plane   6m39s   v1.28.4
master2   Ready    control-plane   5m3s    v1.28.4
node1     Ready    node            6m16s   v1.28.4
node2     Ready    node            6m13s   v1.28.4
```

```bash
# 选装其他插件,harbor需要修改ansible/hosts中分组和/etc/hosts解析
root@master1:~/k8s_kubeadm_install# ansible-playbook playbooks/main.yaml -t [metrics | harbor | dashboard | prometheus]
```
### metrics
```bash 
# metrics
root@master1:~/k8s_kubeadm_install# ansible-playbook playbooks/main.yaml  -t metrics

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
root@master1:~/k8s_kubeadm_install# kubectl get pod -A | grep metrics
kube-system        metrics-server-5b779d9499-znctk            1/1     Running     0              2m5s
root@master1:~/k8s_kubeadm_install# kubectl top node
NAME      CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
master1   120m         6%     1852Mi          50%
master2   115m         5%     1947Mi          53%
node1     46m          2%     1512Mi          41%
node2     46m          2%     1558Mi          42%

```

### dashboard
```bash 
# dashboard
root@master1:~/k8s_kubeadm_install# ansible-playbook playbooks/main.yaml  -t dashboard

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

# v2版本旧版使用以下命令查看
root@master1:~/k8s_kubeadm_install# kubectl -n kubernetes-dashboard  get service
NAME                        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)         AGE
dashboard-metrics-scraper   ClusterIP   10.96.210.243   <none>        8000/TCP        2m48s
kubernetes-dashboard        NodePort    10.97.130.151   <none>        443:30443/TCP   40s


# v3版本以上使用这个命令查看
root@master1:~/k8s_kubeadm_install# kubectl get ingress -n kubernetes-dashboard
NAME                  CLASS  HOSTS                ADDRESS                          PORTS     AGE
kubernetes-dashboard  nginx  k8s.dashboard.local  192.168.181.133,192.168.181.134  80, 443   2m14s
```

### prometheus
```bash 
# prometheus
root@master1:~/k8s_kubeadm_install# ansible-playbook playbooks/main.yaml  -t prometheus

PLAY [创建prometheus资源对象] **************************************************************************************************************************************************

TASK [检查prometheus.lock文件是否存在] *******************************************************************************************************************************************
ok: [localhost]

TASK [创建prometheus namespace and CRDs] ***********************************************************************************************************************************
changed: [localhost]

TASK [等待prometheus namespace and CRDs] ***********************************************************************************************************************************
changed: [localhost]

TASK [创建prometheus资源对象] **************************************************************************************************************************************************
changed: [localhost]

TASK [修改grafana-ingress的host] ********************************************************************************************************************************************
ok: [localhost]

TASK [创建grafana-ingress] *************************************************************************************************************************************************
changed: [localhost]

TASK [创建安装lock文件] ********************************************************************************************************************************************************
changed: [localhost]

PLAY RECAP ***************************************************************************************************************************************************************
localhost                  : ok=7    changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0


root@master1:~/k8s_kubeadm_install# kubectl get pod -o wide -n monitoring
NAME                                   READY   STATUS    RESTARTS   AGE     IP                NODE      NOMINATED NODE   READINESS GATES
alertmanager-main-0                    2/2     Running   0          4m46s   10.244.104.9      node2     <none>           <none>
alertmanager-main-1                    2/2     Running   0          4m46s   10.244.104.10     node2     <none>           <none>
alertmanager-main-2                    2/2     Running   0          4m46s   10.244.166.137    node1     <none>           <none>
blackbox-exporter-6cfc4bffb6-z7mv2     3/3     Running   0          6m17s   10.244.166.133    node1     <none>           <none>
grafana-748964b847-5rfl7               1/1     Running   0          6m17s   10.244.166.134    node1     <none>           <none>
kube-state-metrics-5745cdffdb-zpnl9    3/3     Running   0          6m16s   10.244.104.7      node2     <none>           <none>
node-exporter-kv845                    2/2     Running   0          6m16s   192.168.152.201   master2   <none>           <none>
node-exporter-nhtms                    2/2     Running   0          6m16s   192.168.152.211   node2     <none>           <none>
node-exporter-r29ln                    2/2     Running   0          6m16s   192.168.152.210   node1     <none>           <none>
node-exporter-z9stv                    2/2     Running   0          6m16s   192.168.152.200   master1   <none>           <none>
prometheus-adapter-56958d6684-chx94    1/1     Running   0          6m15s   10.244.104.8      node2     <none>           <none>
prometheus-adapter-56958d6684-n2zbf    1/1     Running   0          6m15s   10.244.166.135    node1     <none>           <none>
prometheus-k8s-0                       2/2     Running   0          4m44s   10.244.166.138    node1     <none>           <none>
prometheus-k8s-1                       2/2     Running   0          4m44s   10.244.104.11     node2     <none>           <none>
prometheus-operator-68f6c79f9d-k9thg   2/2     Running   0          6m14s   10.244.166.136    node1     <none>           <none>

root@master1:~/k8s_kubeadm_install# kubectl get ingress -n monitoring
NAME              CLASS   HOSTS                   ADDRESS                           PORTS   AGE
grafana-ingress   nginx   grafana.example.local   192.168.152.210,192.168.152.211   80      6m48s


# 添加host解析，以访问grafana，默认密码admin/admin，首次登录强制修改密码
```

### harbor
- 由于之前初始化没有添加ansible访问harbor，在这里需要再进行之前的配置
1. 修改主机名
```bash
ada@harbor:~$ sudo hostnamectl set-hostname harbor

root@master1:~$ echo "192.168.152.220 harbor" >> /etc/hosts
```
2. 在master1配置免密访问
```bash
ada@harbor:~$ sudo su -
root@harbor:~# echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
root@harbor:~# systemctl restart sshd.service
root@harbor:~# passwd root
New password:
Retype new password:
passwd: password updated successfully

root@master1:~# ssh-copy-id root@harbor

root@harbor:~# sed -i '$d' /etc/ssh/sshd_config
root@harbor:~# systemctl restart sshd.service
```
3. 使用ansible远程
```bash
root@master1:~/k8s_kubeadm_install# cp -r files/ansible /etc/
root@master1:~# ansible harbor -m ping
harbor | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
```
4. 复制hosts和apt源
```bash
root@master1:~/k8s_kubeadm_install# ansible all -m copy -a "src=/etc/hosts dest=/etc/hosts"
root@master1:~/k8s_kubeadm_install# ansible harbor -m copy -a "src=/etc/apt/sources.list dest=/etc/apt/sources.list"
root@master1:~/k8s_kubeadm_install# ansible harbor -m apt -a "update_cache=yes"
```

5. 执行安装
```bash
#
#
# 在执行安装前，需要修改vars.yaml中的几个变量
#
#
# harbor域名,私有仓库域名
harbor_domain: myharbor.com
harbor_ip: 192.168.152.220
# 使用哪种方式访问harbor(此处默认使用password，如果使用secert，需要在每个资源文件中添加参数imagePullSecrets,详情参考仓库根目录readme)
passord_or_secert: password
# 如果修改了harbor的默认密码，需要修改/etc/containerd/config.toml: password = "yourpassword"
# 重启containerd服务
```

```bash 
# harbor
root@master1:~/k8s_kubeadm_install# ansible-playbook playbooks/main.yaml  -t harbor

TASK [温馨提示1] *************************************************************************************************************************************************************************************************
ok: [master1] => {
    "msg": "如需测试可以执行harbor目录中的两个文件,进行验证: kubectl apply -f files/harbor/test-harbor_with_password.yaml\n"
}

TASK [温馨提示2] *************************************************************************************************************************************************************************************************
ok: [master1] => {
    "msg": "如果选择的是secert方式,需要提前创建secert,并修改test-harbor_with_secert.yaml中的imagePullSecrets,详情参考仓库根目录readme\n"
}


PLAY RECAP ***************************************************************************************************************************************************************************************************
harbor                     : ok=37   changed=33   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
master1                    : ok=11   changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
master2                    : ok=11   changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
node1                      : ok=11   changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
node2                      : ok=11   changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```


6. 测试
```bash
root@master1:~/k8s_kubeadm_install# docker login myharbor.com -u admin
Password:
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
root@master1:~/k8s_kubeadm_install#
root@master1:~/k8s_kubeadm_install#
root@master1:~/k8s_kubeadm_install# docker pull nginx
Using default tag: latest
latest: Pulling from library/nginx
e1caac4eb9d2: Pull complete
88f6f236f401: Pull complete
c3ea3344e711: Pull complete
cc1bb4345a3a: Pull complete
da8fa4352481: Pull complete
c7f80e9cdab2: Pull complete
18a869624cb6: Pull complete
Digest: sha256:c26ae7472d624ba1fafd296e73cecc4f93f853088e6a9c13c0d52f6ca5865107
Status: Downloaded newer image for nginx:latest
docker.io/library/nginx:latest
root@master1:~/k8s_kubeadm_install# docker tag nginx:latest myharbor.com/test/nginx:latest
# 在harbor中创建test项目
root@master1:~/k8s_kubeadm_install# docker push myharbor.com/test/nginx:latest
The push refers to repository [myharbor.com/test/nginx]
61a7fb4dabcd: Pushed
bcc6856722b7: Pushed
188d128a188c: Pushed
7d52a4114c36: Pushed
3137f8f0c641: Pushed
84619992a45b: Pushed
ceb365432eec: Pushed
latest: digest: sha256:678226242061e7dd8c007c32a060b7695318f4571096cbeff81f84e50787f581 size: 1778
root@master1:~/k8s_kubeadm_install#
root@master1:~/k8s_kubeadm_install# kubectl apply -f files/harbor/test-harbor_with_password.yaml
statefulset.apps/nginx-statefulset created
service/nginx-cp created
ingress.networking.k8s.io/app-nginx-ing created
root@master1:~/k8s_kubeadm_install# kubectl get ing
NAME            CLASS   HOSTS         ADDRESS                           PORTS   AGE
app-nginx-ing   nginx   foo.bar.com   192.168.152.210,192.168.152.211   80      5m57s
root@master1:~/k8s_kubeadm_install# curl http://foo.bar.com --resolve foo.bar.com:80:192.168.152.210
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>

```

### master节点参与调度
```bash
# 查看污点
root@master1:~# kubectl describe node master2 |grep Taints
Taints:             node-role.kubernetes.io/control-plane:NoSchedule

# 删除污点
root@master1:~# kubectl taint nodes master2 node-role.kubernetes.io/control-plane:NoSchedule-
node/master2 untainted
root@master1:~# kubectl describe node master2 |grep Taints
Taints:             <none>

# 添加master2为node角色
root@master1:~# kubectl label nodes master2 node-role.kubernetes.io/node=
root@master1:~# kubectl label nodes master2 node-role.kubernetes.io/control-plane-
node/master2 unlabeled
root@master1:~#
root@master1:~#
root@master1:~# kubectl get nodes
NAME      STATUS   ROLES           AGE   VERSION
master1   Ready    control-plane   38d   v1.28.4
master2   Ready    node            38d   v1.28.4
node1     Ready    node            38d   v1.28.4
node2     Ready    node            38d   v1.28.4

```


### Volume(持久卷)
1. 静态Provisioning
```bash
sudo parted /dev/sdb
(parted) p
(parted) mklabel
New disk label type? gpt
(parted) mkpart
Partition name?  []? vrayst01
File system type?  [ext2]? xfs
Start? 0%
End? 100%
 (parted) q
Information: You may need to update /etc/fstab.
+
mkfs.xfs -f /dev/sdb1
blkid /dev/sdb1
+
vi /etc/fstab
/dev/sdb1               /data8                  xfs     defaults        0 0
UUID="42c3f78d-61f3-48bf-b5b8-36eaf149d2b8"  /hdd_data                 xfs     defaults        0 0




#nfs-server install
root@harbor:~# apt install nfs-kernel-server nfs-common -y 
root@harbor:~# cat /etc/exports
# /etc/exports: the access control list for filesystems which may be exported
#               to NFS clients.  See exports(5).
#
# Example for NFSv2 and NFSv3:
# /srv/homes       hostname1(rw,sync,no_subtree_check) hostname2(ro,sync,no_subtree_check)
#
# Example for NFSv4:
# /srv/nfs4        gss/krb5i(rw,sync,fsid=0,crossmnt,no_subtree_check)
# /srv/nfs4/homes  gss/krb5i(rw,sync,no_subtree_check)
#
/nfs/aa 192.168.152.0/24(rw,sync,no_root_squash,no_all_squash)
/nfs/sc 192.168.152.0/24(rw,sync,no_root_squash,no_all_squash)

rw： 这个选项表示允许客户端以读写方式挂载共享。也就是说，客户端可以对共享目录中的文件进行读取和写入操作。

sync： 这个选项指定 NFS 服务器在收到写操作请求时立即将数据写入到磁盘中，并等待写操作完成后再返回。这可以确保数据的一致性，但可能会影响性能。

no_root_squash： 这个选项禁止了 root 用户的权限被限制（"root squashing"）。通常情况下，NFS 服务器会将 root 用户的操作映射为匿名用户，以提高安全性。使用这个选项可以允许 root 用户拥有共享目录的完全权限。

no_all_squash： 这个选项禁止了所有用户的权限被限制（"all squashing"）。类似于 no_root_squash，这个选项允许所有用户拥有共享目录的完全权限。


root@harbor:~# mkdir -p /nfs/{pv,sc}
root@harbor:~# echo "this is pv-pvc test" > /nfs/pv/index.html

# all node install
ansible k8s -m shell -a "apt update"
ansible k8s -m shell -a "apt install nfs-common -y" 



root@master1:~# kubectl apply -f pv-example.yaml
root@master1:~# kubectl apply -f pvc-example.yaml
root@master1:~# kubectl apply -f test-pv-pvc.yaml

root@master1:~# curl http://test-pvc.bar.com --resolve test-pvc.bar.com:80:192.168.152.210
this is pv-pvc test


# 验证持久化
root@master1:~# kubectl delete -f test-pv-pvc.yaml
root@harbor:~# cat  /nfs/pv/index.html
this is pv-pvc test
```

2. 基于storageclass的动态 Provisioning
```bash 
root@master1:~/k8s_kubeadm_install# kubectl apply  -f files/nfs_volume/storageclass/sc-rbac.yaml
root@master1:~/k8s_kubeadm_install# kubectl apply  -f files/nfs_volume/storageclass
root@master1:~/k8s_kubeadm_install# kubectl apply -f test-sc.yaml -f scm-pvc.yaml -f sc.yaml -f provisioner.yaml
deployment.apps/nginx-pvc-example created
service/nginx-sc-service created
ingress.networking.k8s.io/sc-nginx-ing created
persistentvolumeclaim/scm-pvc created
storageclass.storage.k8s.io/sc-storage created
deployment.apps/nfs-client-provisioner created

root@master1:~/k8s_kubeadm_install# kubectl get sc
NAME         PROVISIONER        RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
sc-storage   sc-storage-class   Delete          Immediate           true                   5m41s


root@master1:~/k8s_kubeadm_install# kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM             STORAGECLASS   REASON   AGE
pvc-e8cb26b6-7818-4211-a17e-2ebf1a8ffc87   10Gi       RWO            Delete           Bound    default/scm-pvc   sc-storage              6m13s

root@master1:~/k8s_kubeadm_install# kubectl get pvc
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
scm-pvc   Bound    pvc-e8cb26b6-7818-4211-a17e-2ebf1a8ffc87   10Gi       RWO            sc-storage     6m36

root@harbor:/nfs/sc# ls
default-scm-pvc-pvc-29e2dd5c-7fcd-44c4-b235-a2329cfc3be2
root@harbor:/nfs/sc# echo "this is sc test" > default-scm-pvc-pvc-29e2dd5c-7fcd-44c4-b235-a2329cfc3be2/index.html

root@master1:~/k8s_kubeadm_install# curl http://test-sc.bar.com --resolve test-sc.bar.com:80:192.168.152.210
this is sc test


```
3. helm安装
```bash 
https://github.com/helm/helm/tags
wget https://get.helm.sh/helm-${version}-linux-amd64.tar.gz
tar -zxvf helm-${version}-linux-amd64.tar.gz
root@master1:~/k8s_kubeadm_install# mv files/helm/install_helm/helm /usr/local/bin/helm
root@master1:~/k8s_kubeadm_install# chmod +x /usr/local/bin/helm
```

4. 使用helm安装jms
```bash 
helm repo add jumpserver https://jumpserver.github.io/helm-charts
helm repo list
vi values.yaml
https://github.com/jumpserver/helm-charts/blob/main/charts/jumpserver/values.yaml

4  imageRegistry: docker.io

21  storageClass: "sc-storage"

67    hosts:
68    - "ayyq.jumpserver.example"

82  secretKey: "LB47qqmfyBZ1RrzJrhY8rwDB8bv9cuYwscDeFCS7Bg90EnOIsV"
    ## Generate a new random bootstrap token by execute `cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 24`
84    bootstrapToken: "DfzASZTSAnePAuxA0UBG4FDR"


# 安装数据库和redis
root@master1:~/k8s_kubeadm_install# kubectl apply -f files/helm/jms/mysql.yaml -f files/helm/jms/redis.yaml
root@master1:~/k8s_kubeadm_install# kubectl exec -it mysql-deployment-75d4df5d9c-pqfdb -- bash

bash-4.4# mysql -uroot -pjumpserver
mysql> CREATE DATABASE jumpserver DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;
Query OK, 1 row affected, 2 warnings (0.01 sec)

mysql> CREATE USER 'jumpserver'@'%' IDENTIFIED BY 'jumpserver';
Query OK, 0 rows affected (0.01 sec)

mysql> GRANT ALL PRIVILEGES ON  jumpserver.* TO 'jumpserver'@'%';
Query OK, 0 rows affected (0.00 sec)

mysql> FLUSH PRIVILEGES;
Query OK, 0 rows affected (0.00 sec)

# 安装
helm install jms-k8s jumpserver/jumpserver -n default -f values.yaml
# 或自己打包
tar -czvf jms.tgz jumpserver
root@master1:~/k8s_kubeadm_install# helm install jms-k8s files/helm/jms/jms.tgz

# 卸载
helm uninstall jms-k8s -n default
```

### 证书过期设置
查看证书有效期
```bash
root@master1:~# openssl x509 -noout -text -in /etc/kubernetes/pki/apiserver.crt | awk '/Validity/,/Subject:/ { if ($1 == "Not" && ($2 == "Before:" || $2 == "After" )) print $0 }'
            Not Before: Jun 18 09:16:19 2024 GMT
            Not After : Jun 16 09:16:19 2035 GMT

```
https://github.com/yuyicai/update-kube-cert/blob/master/README-zh_CN.md
```
该脚本用于处理已过期或者即将过期的 kubernetes 集群证书

该脚本适用于所有 k8s 版本集群证书更新(使用 kubeadm 初始化的集群)

kubeadm 生成的证书有效期为 1 年，该脚本可将 kubeadm 生成的证书有效期更新为 10 年

该脚本只处理 master 节点上的证书，worker node 节点的 kubelet 证书默认自动轮换更新，无需关心过期问题

**如果有多个 master 节点，在每个 master 节点都执行一次**

bash update-kubeadm-cert.sh all --cri containerd

root@master1:~# openssl x509 -noout -text -in /etc/kubernetes/pki/apiserver.crt | awk '/Validity/,/Subject:/ { if ($1 == "Not" && ($2 == "Before:" || $2 == "After" )) print $0 }'
            Not Before: Jun 18 09:16:19 2024 GMT
            Not After : Jun 16 09:16:19 2034 GMT

root@master1:/home/ubuntu/k8s_kubeadm_install# kubeadm certs check-expiration
[check-expiration] Reading configuration from the cluster...
[check-expiration] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'

CERTIFICATE                EXPIRES                  RESIDUAL TIME   CERTIFICATE AUTHORITY   EXTERNALLY MANAGED
admin.conf                 Jun 19, 2034 06:34 UTC   9y              ca                      no
apiserver                  Jun 19, 2034 06:34 UTC   9y              ca                      no
apiserver-etcd-client      Jun 19, 2034 06:34 UTC   9y              etcd-ca                 no
apiserver-kubelet-client   Jun 19, 2034 06:34 UTC   9y              ca                      no
controller-manager.conf    Jun 19, 2034 06:34 UTC   9y              ca                      no
etcd-healthcheck-client    Jun 19, 2034 06:34 UTC   9y              etcd-ca                 no
etcd-peer                  Jun 19, 2034 06:34 UTC   9y              etcd-ca                 no
etcd-server                Jun 19, 2034 06:34 UTC   9y              etcd-ca                 no
front-proxy-client         Jun 19, 2034 06:34 UTC   9y              front-proxy-ca          no
scheduler.conf             Jun 19, 2034 06:34 UTC   9y              ca                      no
super-admin.conf           Jun 19, 2034 06:34 UTC   9y              ca                      no

CERTIFICATE AUTHORITY   EXPIRES                  RESIDUAL TIME   EXTERNALLY MANAGED
ca                      Jun 19, 2034 06:34 UTC   9y              no
etcd-ca                 Jun 19, 2034 06:34 UTC   9y              no
front-proxy-ca          Jun 19, 2034 06:34 UTC   9y              no

```



### 离线安装
由于docker无法再正常使用，对于初学者有一定的使用门槛，我已经将所需镜像全部打包好，需要的可以关注公众号私信获取。  
较以前相比，安装命令没有任何变化，只需将一下三个版本之一放入指定目录files/docker-images/v1.xx.x，执行main.yaml即可一键安装。
```text
├── v1.28.4
│   ├── coredns-v1.10.1.tar
│   ├── docker.io-calico-apiserver-v3.26.3.tar
│   ├── docker.io-calico-cni-v3.26.3.tar
│   ├── docker.io-calico-csi_v3.26.3.tar
│   ├── docker.io-calico-kube-controllers_v3.26.3.tar
│   ├── docker.io-calico-node-driver-registrar-v3.26.3.tar
│   ├── docker.io-calico-node-v3.26.3.tar
│   ├── docker.io-calico-pod2daemon_flexvol-v3.26.3.tar
│   ├── docker.io-calico-typha-v3.26.3.tar
│   ├── etcd-3.5.9-0.tar
│   ├── kube-apiserver-v1.28.4.tar
│   ├── kube-controller-manager-v1.28.4.tar
│   ├── kube-proxy-v1.28.4.tar
│   ├── kube-scheduler-v1.28.4.tar
│   └── pause-3.9.tar
├── v1.29.6
│   ├── coredns-v1.11.1.tar
│   ├── docker.io-calico-apiserver-v3.28.0.tar
│   ├── docker.io-calico-cni-v3.28.0.tar
│   ├── docker.io-calico-csi-v3.28.0.tar
│   ├── docker.io-calico-kube-controllers-v3.28.0.tar
│   ├── docker.io-calico-node-driver-registrar-v3.28.0.tar
│   ├── docker.io-calico-node-v3.28.0.tar
│   ├── docker.io-calico-pod2daemon-flexvol-v3.28.0.tar
│   ├── docker.io-calico-typha-v3.28.0.tar
│   ├── etcd-3.5.12-0.tar
│   ├── kube-apiserver-v1.29.6.tar
│   ├── kube-controller-manager-v1.29.6.tar
│   ├── kube-proxy-v1.29.6.tar
│   ├── kube-scheduler-v1.29.6.tar
│   └── pause-3.9.tar
└── v1.30.2
    ├── coredns-v1.11.1.tar
    ├── docker.io-calico-apiserver-v3.28.0.tar
    ├── docker.io-calico-cni-v3.28.0.tar
    ├── docker.io-calico-csi-v3.28.0.tar
    ├── docker.io-calico-kube-controllers-v3.28.0.tar
    ├── docker.io-calico-node-driver-registrar-v3.28.0.tar
    ├── docker.io-calico-node-v3.28.0.tar
    ├── docker.io-calico-pod2daemon-flexvol-v3.28.0.tar
    ├── docker.io-calico-typha-v3.28.0.tar
    ├── etcd-3.5.12-0.tar
    ├── kube-apiserver-v1.30.2.tar
    ├── kube-controller-manager-v1.30.2.tar
    ├── kube-proxy-v1.30.2.tar
    ├── kube-scheduler-v1.30.2.tar
    └── pause-3.9.tar
```

