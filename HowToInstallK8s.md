# How to Install kubernetes
- We wrote the following setup steps with the proxy server. 

## Index

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
## 
## Install kubernetes

## Setup Master Node
1. Initialize a cluster.
   - --apiserver-advertise-address: IP address of master node
   - --pod-network-cidr: It depends on FIXME. In this case, we use flannel.
   - --token-ttl: 
     ```bash
     # kubeadm init --apiserver-advertise-address=192.168.1.151 --pod-network-cidr=10.244.0.0/16  --token-ttl 0
     ```

## Add Worker Node to the Cluster
1. Add worker node to the cluster.
   ```bash
   # kubeadm join <IP Address of Master Node>:6443 --token 8ohp86.cau1...(snip)...sc6q --discovery-token-ca-cert-hash sha256:eeb9...(snip)...0241
   ```
1. 