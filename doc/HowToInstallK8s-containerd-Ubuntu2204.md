# How to Install kubernetes with containerd on Ubuntu Server 22.04

## Index
- [Evaluation Environment](#evaluation-environment)
- [Prerequisite](#prerequisite)
- [Install containerd](#install-containerd)
- [Install kubernetes](#install-kubernetes)
- [Create a Cluster](#create-a-cluster)
- [Add a Worker Node to the Cluster](#add-a-worker-node-to-the-cluster)

## Evaluation Environment
```
    +-------------------------------+
    | Control-plane                 |
+---+ - Ubuntu 22.04.3              |
|   | - kubernetes 1.18.1           |
|   | - containerd 1.7.2            |
|   | - Calico                      |
|   +-------------------------------+
|  
|   +-------------------------------+
|   | Worker #1, #2                 |
+---+ - Ubuntu 22.04.3              |
    | - kubernetes 1.18.1           |
    | - containerd 1.7.2            |
    +-------------------------------+
```
## Prerequisite
- See also;
  - https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#before-you-begin
1. Disable swap.
   1. Open /etc/fstab.
      ```sh
      sudo vim /etc/fstab
      ```
   1. Comment out the following line.
      ```
      #/swap.img      none    swap    sw      0       0
      ```
   1. Reboot OS.
1. Change network parameters.
   ```sh
   cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
   overlay
   br_netfilter
   EOF
   ```
   ```sh
   sudo modprobe overlay
   ```
   ```sh
   sudo modprobe br_netfilter
   ```
   ```sh
   cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
   net.bridge.bridge-nf-call-iptables  = 1
   net.bridge.bridge-nf-call-ip6tables = 1
   net.ipv4.ip_forward                 = 1
   EOF
   ```
   ```sh
   sudo sysctl --system
   ```
   ```sh
   lsmod | grep br_netfilter
   ```
   ```sh
   lsmod | grep overlay
   ```
   ```sh
   sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward
   ```
## Install containerd
- See also;
  - https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd
1. Do the following steps on all nodes.
1. Install containerd.
   ```sh
   sudo apt install containerd
   ```
1. If you have a proxy server, do the following steps.
   1. Create the directory.
      ```sh
      sudo mkdir -p /etc/systemd/system/containerd.service.d/
      ```
   1. Create the conf file.
      ```sh
      sudo vim /etc/systemd/system/containerd.service.d/http-proxy.conf
      ```
   1. Write the following lines.
      ```
      [Service]
      Environment="HTTP_PROXY=<your proxy>"
      Environment="HTTPS_PROXY=<your proxy>"
      Environment="NO_PROXY=<your subnet (e.g. 192.168.1.0/24)>,10.96.0.1"
      ```   
1. Create config.toml.
   ```sh
   sudo containerd config default > /etc/containerd/config.toml
   ```
1. Edit config.toml as below.
   ```
                [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
               (snip)
               SystemdCgroup = true   
   ```
1. Restart containerd.
   ```sh
   sudo systemctl daemon-reload
   ```
   ```sh
   sudo systemctl restart containerd
   ```

## Install kubernetes
- See also;
  - https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl
1. Download the public signing key.
   ```sh
   curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
   ```
1. Add kubernetes.list.
   ```sh
   echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
   ```
1. Install kubeadm, kubelet and kubectl.
   ```sh
   sudo apt update
   ```
   ```sh
   sudo apt install -y kubelet kubeadm kubectl
   ```

## Create a Cluster
- See also;
  - kubernetes
    - https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/
  - Calico
    - https://docs.projectcalico.org/getting-started/kubernetes/quickstart
1. Do the follwoing steps on the control-plane node.
1. Run `kubeadm init`.
   ```sh
   sudo kubeadm init --apiserver-advertise-address=192.168.1.171 --pod-network-cidr=10.0.0.0/16 --token-ttl 0
   ```
   - CNI (e.g., Calico) uses the IP address that be set by `--pod-network-cidr` option. 
   - You will get the following result.
     ```
     (snip)
     Your Kubernetes control-plane has initialized successfully!
     
     To start using your cluster, you need to run the following as a regular user:
     
       mkdir -p $HOME/.kube
       sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
       sudo chown $(id -u):$(id -g) $HOME/.kube/config
     
     Alternatively, if you are the root user, you can run:
     
       export KUBECONFIG=/etc/kubernetes/admin.conf
     
     You should now deploy a pod network to the cluster.
     Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
       https://kubernetes.io/docs/concepts/cluster-administration/addons/
     
     Then you can join any number of worker nodes by running the following on each as root:
     
     kubeadm join 192.168.1.171:6443 --token bf9n5s.uthkpeuixiav38ky \
             --discovery-token-ca-cert-hash sha256:837946a411bbd48fb02399e4def3eda23254405a3a5157ac1f87234eee6420b7
     ```
1. Copy admin.conf and rename it as below to use kubectl command.
   ```sh
   mkdir -p $HOME/.kube
   ```
   ```sh
   sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
   ```
   ```sh
   sudo chown $(id -u):$(id -g) $HOME/.kube/config
   ```
1. Chech the status.
   ```
   $ kubectl get node
   NAME           STATUS   ROLES           AGE   VERSION
   ubuntu22-171   NotReady control-plane    1m   v1.28.1
   ```
1. Download YAML files and apply them.
   ```sh
   curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
   ```
   ```sh
   kubectl create -f tigera-operator.yaml
   ```
   ```sh
   curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml
   ```
   - Calico's default network is 192.168.0.0/16. If you want to change it, edit custom-resources.yaml as below. You need to set the same IP address when you run `kubeadm init` command.
     ```yaml
     (snip)
       # Configures Calico networking.
       calicoNetwork:
         # Note: The ipPools section cannot be modified post-install.
         ipPools:
         - blockSize: 26
           cidr: 10.0.0.0/16
           encapsulation: VXLANCrossSubnet
           natOutgoing: Enabled
           nodeSelector: all()
     (snip)
     ```
   ```sh
   kubectl create -f custom-resources.yaml
   ```
1. Check if STATUS is *Ready*.
   ```
   $ kubectl get node
   NAME           STATUS   ROLES           AGE   VERSION
   ubuntu22-171   Ready    control-plane   20m   v1.28.1
   ```

## Add a Worker Node to the Cluster
1. Run the following steps on worker nodes.
1. Run `kubeadm join` command.
   ```sh
   kubeadm join 192.168.1.171:6443 --token bf9n5s.uthkpeuixiav38ky \
   --discovery-token-ca-cert-hash sha256:837946a411bbd48fb02399e4def3eda23254405a3a5157ac1f87234eee6420b7
   ```
1. Enjoy kubernetes!
   ```
   $ kubectl get node
   NAME           STATUS   ROLES           AGE   VERSION
   ubuntu22-171   Ready    control-plane   14h   v1.28.1
   ubuntu22-172   Ready    <none>          13h   v1.28.1
   ubuntu22-173   Ready    <none>          11h   v1.28.1
   $ kubectl get node -o wide
   NAME           STATUS   ROLES           AGE   VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
   ubuntu22-171   Ready    control-plane   14h   v1.28.1   192.168.1.171   <none>        Ubuntu 22.04.3 LTS   5.15.0-83-generic   containerd://1.7.2
   ubuntu22-172   Ready    <none>          13h   v1.28.1   192.168.1.172   <none>        Ubuntu 22.04.3 LTS   5.15.0-83-generic   containerd://1.7.2
   ubuntu22-173   Ready    <none>          11h   v1.28.1   192.168.1.173   <none>        Ubuntu 22.04.3 LTS   5.15.0-83-generic   containerd://1.7.2
   ```