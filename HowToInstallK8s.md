# How to Install kubernetes
## Index
- [Evaluation Configuration](#Evaluation-Configuration)
- [Prerequisite](#Prerequisite)
- [Install Docker](#Install-Docker)
- [Install kubernetes](#Install-kubernetes)
- [Setup Master Node](#Setup-Master-Node)
- [Add Worker Node to the Cluster](#Add-Worker-Node-to-the-Cluster)

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
  # 192.168.1.150 master
  # 192.168.1.151 worker1
  # 192.168.1.152 worker2
  ```
- Modify /etc/fstab to disalbe swap.
  ```bash
  (Comment out the following line)
  #/dev/mapper/centos-swap swap      swap defaults      0 0
  ```
- Run the following commands or run [the sample script](#https://github.com/EXPRESSCLUSTER/kubernetes/blob/master/script/01_setup4k8s.sh) to disable SELinux, firewalld, IPv6 and enable IPv4 forwarding.
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

## Install kubernetes
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
   # kubeadm init --apiserver-advertise-address=192.168.1.151 --pod-network-cidr=10.244.0.0/16  --token-ttl 0
   ```
   - --apiserver-advertise-address: IP address of master node
   - --pod-network-cidr: It depends on FIXME. In this case, we use flannel.
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
1. Setup network. 
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
   ```
   - By default, the above command will be available but it failed in our lab. So, we did the following steps to setup network.
     1. Download the YAML file for flannel.
        ```bash
         # wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml --no-check-certificate
        ```
     1. Get the container image of flannel (quay.io/coreos/flannel). In our case, create an instance of AWS and get the container image.
        ```bash
        # docker pull quay.io/coreos/flannel
        # docker save quay.io/coreos/flannel > flannel.tar
        ```
     1. Copy the tar file and load the container image to master node.
        ```bash
        # docker laod < flannel.tar
        ```
     1. Apply the YAML file for flannel.
        ```bash
        # kubectl apply -f kube-flannel.yml
        ```

## Add Worker Node to the Cluster
1. Load flannel image.
   ```bash
   # docker laod < flannel.tar
   ```
1. If your environment has the proxy server, you need to save CRT file on the following directory.
   ```
   /etc/docker/certs.d/k8s.gcr.io/
   ```
1. Run the following command on the worker node to add it to the cluster.
   ```bash
   kubeadm join 192.168.1.151:6443 --token 8ohp86.cau1d11offeesc6q --discovery-token-ca-cert-hash sha256:eeb9e3cb74e3652c8a699ec4812131b771ae6eb788e4a4e0b6ec58193eb90241
   ```
1. Run the following command on the master node to check if the all nodes are running.
   ```bash
   # kubectl get node
   NAME         STATUS   ROLES    AGE     VERSION
   centos-151   Ready    master   50m     v1.15.0
   centos-152   Ready    <none>   40m     v1.15.0
   centos-153   Ready    <none>   30m     v1.15.0
   ```