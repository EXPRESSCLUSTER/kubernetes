# kubernetes with EXPRESSCLUSTER
- This page describes how to create a cluster with kubernetes and EXPRESSCLUSTER X. 
- The following steps were done in our on-premise behind the proxy server.

## Evaluation Environment
```
    +--------------------------+
 +--| Master Node              |
 |  | - CentOS 7.6.1810        |
 |  | - kubernetes v1.13.1     |
 |  | - Docker 1.13.1-88       |
 |  | - EXPRESSCLUSTER X  4.0  |
 |  +--------------------------+
 |
 |  +--------------------------+
 +--| Worker Node #1           |
 |  | - CentOS 7.6.1810        |
 |  | - kubernetes v1.13.1     |
 |  | - Docker 1.13.1-88       |
 |  | - EXPRESSCLUSTER X  4.0  |
 |  +--------------------------+
 |
 |  +--------------------------+
 +--| Worker Node #2           |
    | - CentOS 7.6.1810        |
    | - kubernetes v1.13.1     |
    | - Docker 1.13.1-88       |
    | - EXPRESSCLUSTER X  4.0  |
    +--------------------------+
```

## Install Docker
1. Edit yum.conf to add IP address and port number of proxy server.
   ```sh
   # vi /etc/yum.conf
     :
   proxy=<your proxy server>:<port number>
   ```
1. Check the latest update.
   ```sh
   # yum check-update
   ```
1. Apply the latest update.
   ```sh
   # yum update 
   ```
1. Install Docker.
   ```sh
   # yum install -y docker
   ```


## Install kubernetes


## Install EXPRESSCLUSTER
