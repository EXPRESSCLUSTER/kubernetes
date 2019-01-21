# kubernetes with EXPRESSCLUSTER
- This page describes how to create a cluster with kubernetes and EXPRESSCLUSTER X. 

## Evaluation Environment
```
    +--------------------------+
 +--| Master Node              |
 |  | - CentOS 7.6.1810        |
 |  | - kubernetes v1.13       |
 |  | - Docker 1.13.1-88       |
 |  | - EXPRESSCLUSTER X  4.0  |
 |  +--------------------------+
 |
 |  +--------------------------+
 +--| Worker Node #1           |
 |  | - CentOS 7.6.1810        |
 |  | - kubernetes v1.13       |
 |  | - Docker 1.13.1-88       |
 |  | - EXPRESSCLUSTER X  4.0  |
 |  +--------------------------+
 |
 |  +--------------------------+
 +--| Worker Node #2           |
    | - CentOS 7.6.1810        |
    | - kubernetes v1.13       |
    | - Docker 1.13.1-88       |
    | - EXPRESSCLUSTER X  4.0  |
    +--------------------------+

## Install kubernetes
- The following steps were done in our on-premise behind the proxy server.

## Install EXPRESSCLUSTER
