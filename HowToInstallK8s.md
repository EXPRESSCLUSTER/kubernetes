# How to Install kubernetes
## Index
- [Evaluation Configuration](#Evaluation-Configuration)
- [Prerequisite](#Prerequisite)
- [Install Docker](#Install-Docker)
- [Install kubernetes on CentOS](#Install-kubernetes-on-CentOS)
- [Setup Master Node](#Setup-Master-Node)
- [Add Worker Node to the Cluster](#Add-Worker-Node-to-the-Cluster)
- [Deploy metrics-server](#deploy-metrics-server)

## Evaluation Configuration
```
    +--------------------------+
 +--| Master Node (node0)      |
 |  | - CentOS 7.6.1810        |
 |  | - kubernetes v1.15.0     |
 |  | - Docker 1.13.1-96       |
 |  +--------------------------+
 |
 |  +--------------------------+
 +--| Worker Node #1 (node1)   |
 |  | - CentOS 7.6.1810        |
 |  | - kubernetes v1.15.0     |
 |  | - Docker 1.13.1-96       |
 |  +--------------------------+
 |
 |  +--------------------------+
 +--| Worker Node #2 (node2)   |
    | - CentOS 7.6.1810        |
    | - kubernetes v1.15.0     |
    | - Docker 1.13.1-96       |
    +--------------------------+
```

## Prerequisite
1. Check update and apply them in advance.
   ```bash
   # yum update
   ```
- If your environment has the proxy server, you need to modify some files.
  - /etc/yum.conf
    ```bash
    (Add the following lines)
    proxy=<your proxy server name>:<port number>
    sslverify=false  # If you need it.
    ```
  - /etc/wgetrc
    ```bash
    (Add the following lines)
    http_proxy = <your proxy server name>:<port number>
    https_proxy = <your proxy server name>:<port number>
    ftp_proxy = <your proxy server name>:<port number>
    ```
- Modify /etc/hosts file as below.
  ```bash
  # 192.168.1.150 control-plane
  # 192.168.1.151 node1
  # 192.168.1.152 node2
  ```
- Modify /etc/fstab to disalbe swap.
  ```bash
  (Comment out the following line)
  #/dev/mapper/centos-swap swap      swap defaults      0 0
  ```
- Run the following commands or run [the sample script](https://github.com/EXPRESSCLUSTER/kubernetes/blob/master/script/01_setup4k8s.sh) to disable SELinux, firewalld, IPv6 and enable IPv4 forwarding.
  ```bash
  # setenforce 0
  # sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config

  # systemctl stop firewalld
  # systemctl disable firewalld

  # echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
  # echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
  # sysctl -p /etc/sysctl.conf

  # echo 1 > /proc/sys/net/ipv4/ip_forward
  # echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
  # sysctl -p /etc/sysctl.conf
  ```

## Install Docker
- Please refer to [How to Install Docker](https://github.com/EXPRESSCLUSTER/Docker/blob/master/HowToInstallDocker.md)

## Install kubernetes on CentOS
1. Run the following command or [the sample script](https://github.com/EXPRESSCLUSTER/kubernetes/blob/master/script/02_setup4k8s.sh) to prepare to install kubernetes.
   ```bash
   # cat <<EOF >  /etc/sysctl.d/k8s.conf
   net.bridge.bridge-nf-call-ip6tables = 1
   net.bridge.bridge-nf-call-iptables = 1
   EOF
   #sysctl --system
 
   # cat <<EOF > /etc/yum.repos.d/kubernetes.repo
   [kubernetes]
   name=Kubernetes
   baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
   enabled=1
   gpgcheck=1
   repo_gpgcheck=1
   gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
   EOF
   ```
 1. Install kubernetes.
    ```bash
    # yum install -y kubelet kubeadm kubectl
    ```

## Setup Master Node
1. Initialize a cluster.
   ```bash
   # kubeadm init --apiserver-advertise-address=192.168.1.225 --pod-network-cidr=10.0.0.0/16 --token-ttl 0
   ```
   - --apiserver-advertise-address: IP address of the control-plane node
   - --pod-network-cidr: It depends on Container Networking Interface (e.g. Calico, Flannnel, Canal and so on). In this case, we use Calico.
     - If your node network is 192.168.x.0/24, please change the default Calico network 192.168.0.0/16 to the other network (e.g. 10.0.0.0/16).
   - --token-ttl: **0** means **never expire**.
1. After initialization, take a note the following command. It is required to add a worker node to the cluster.
   ```bash
   [addons] Applied essential addon: kube-proxy
   
   Your Kubernetes control-plane has initialized successfully!
   
   To start using your cluster, you need to run the following as a regular user:
   
     mkdir -p $HOME/.kube
     sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
     sudo chown $(id -u):$(id -g) $HOME/.kube/config
   
   You should now deploy a pod network to the cluster.
   Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
     https://kubernetes.io/docs/concepts/cluster-administration/addons/
   
   Then you can join any number of worker nodes by running the following on each as root:
   
   kubeadm join 192.168.1.151:6443 --token 8ohp86.cau1d11offeesc6q --discovery-token-ca-cert-hash sha256:eeb9e3cb74e3652c8a699ec4812131b771ae6eb788e4a4e0b6ec58193eb90241
   ```
1. Check if the node status is NotReady.
   ```bash
   # kubectl get node
   NAME         STATUS   ROLES    AGE   VERSION
   centos-151   NotReady master   10s   v1.15.0
   ```
1. Download the yaml file of Calico.
   ```bash
   # curl https://docs.projectcalico.org/v3.10/manifests/calico.yaml -O
   ```
1. Setup network. 
   ```bash
   # kubectl apply -f calico.yaml
   ```

## Add Worker Node to the Cluster
1. If your environment has the proxy server, you need to save CRT file on the following directory.
   ```
   /etc/docker/certs.d/k8s.gcr.io/
   ```
1. Run the following command on the worker node to add it to the cluster.
   ```bash
   kubeadm join 192.168.1.151:6443 --token 8ohp86.cau1d11offeesc6q --discovery-token-ca-cert-hash sha256:eeb9e3cb74e3652c8a699ec4812131b771ae6eb788e4a4e0b6ec58193eb90241
   ```
1. Run the following command on the control-plane node to check if the all nodes are running.
   ```bash
   # kubectl get node
   NAME         STATUS   ROLES    AGE     VERSION
   centos-151   Ready    master   50m     v1.15.0
   centos-152   Ready    <none>   40m     v1.15.0
   centos-153   Ready    <none>   30m     v1.15.0
   ```

## Deploy metrics-server
1. Install git.
   ```sh
   # yum install git
   ```
1. Clone metrics-server reository.
   ```sh
   # git clone https://github.com/kubernetes-sigs/metrics-server.git
   ```
1. Add **command** to metrics-server-deployment.yaml
   ```yaml
    :
   imagePUllPolicy: Always
   command:
   - /metrics-server
   - --kubelet-insecure-tls
   - --kubelet-preferred-address-types=InternalDNS,InternalIP,ExternalDNS,ExternalIP,Hostname
   ```
1. Apply the yaml files.
   ```sh
   # kubectl apply -f metrics-server/deploy/1.8+/
   ```
1. After some minutes, run kubectl top command.
   ```sh
   # kubectl top pod --all-namespaces
   NAMESPACE     NAME                                       CPU(cores)   MEMORY(bytes)
   kube-system   calico-kube-controllers-564b6667d7-mbgnp   3m           10Mi
   kube-system   calico-node-6d9wj                          27m          43Mi
   kube-system   calico-node-9nqxp                          22m          28Mi
   kube-system   coredns-5644d7b6d9-6j67w                   4m           10Mi
   kube-system   coredns-5644d7b6d9-hv74v                   5m           10Mi
   kube-system   etcd-centos7-11                            19m          68Mi
   kube-system   kube-apiserver-centos7-11                  42m          266Mi
   kube-system   kube-controller-manager-centos7-11         17m          38Mi
   kube-system   kube-proxy-hph5b                           6m           11Mi
   kube-system   kube-proxy-vj5bf                           2m           13Mi
   kube-system   kube-scheduler-centos7-11                  2m           15Mi
   kube-system   metrics-server-9f9dbd8fc-hr6mr             2m           10Mi
   ```