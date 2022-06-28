# How to Install kubernetes with containerd

## Index
- [Evaluation Environment](#evaluation-environment)
- [Install kubernetes on the Control-plane](#install-kubernetes-on-the-control-plane)
- [Install kubectl on the Client](#install-kubectl-on-the-client)

## Evaluation Environment
```
    +-------------------------------+
    | Control-plane                 |
+---+ - Ubuntu 20.04.2              |
|   | - kubernetes 1.12.2           |
|   | - containerd 1.3.3-0ubuntu2.2 |
|   | - Calico                      |
|   +-------------------------------+
|  
|   +-------------------------------+
|   | Client                        |
+---+ - Ubuntu 20.04.2              |
    | - kubectl                     |
    +-------------------------------+
```

## Install kubernetes on the Control-plane
1. Install containerd.
   - https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd
1. If you have the proxy server, do the following steps.
   1. Create the directory.
      ```sh
      $ sudo mkdir -p /etc/systemd/system/containerd.service.d/
      ```
   1. Create the conf file.
      ```sh
      $ sudo vim /etc/systemd/system/containerd.service.d/http-proxy.conf
      ```
   1. Write the following lines.
      ```
      [Service]
      Environment="HTTP_PROXY=<your proxy>"
      Environment="HTTPS_PROXY=<your proxy>"
      Environment="NO_PROXY=<your subnet (e.g. 192.168.1.0/24)>,10.96.0.1"
      ```   
1. Install kubeadm, kubelet and kubectl.
   - https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
1. Create the cluster.
   - https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/
1. Install Calico.
   - https://docs.projectcalico.org/getting-started/kubernetes/quickstart
1. Check the Calico containers are running.
   ```sh
   $ kubectl get pod -n calico-system
   NAME                                      READY   STATUS    RESTARTS   AGE
   calico-kube-controllers-56689cf96-9xk7p   1/1     Running   0          24h
   calico-node-cdqhh                         1/1     Running   0          24h
   calico-typha-776945c458-l686c             1/1     Running   0          24h
   ```
1. Check the node STATUS is **Ready**.
   ```sh
   $ kubectl get node
   NAME         STATUS   ROLES                  AGE   VERSION
   ubuntu-205   Ready    control-plane,master   24h   v1.20.2   
   ```

## Install kubectl on the Client
1. Copy the config file from the control-plane and save it on $HOME/.kube directory.
1. Install kubectl command.
   - https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl
1. Check if you can access the kubernetes cluster from the client.
   ```sh
   $ kubectl get node
   NAME         STATUS   ROLES                  AGE   VERSION
   ubuntu-205   Ready    control-plane,master   24h   v1.20.2
   ```
1. (Optional) Install Docker.
   ```sh
   $ sudo apt install docker.io
   ```

## Import Container Image
1. If you want to import the local container image, you need to use ctr command.
   ```sh
   $ sudo ctr -n=k8s.io images import <tar file name of container image>
   ```