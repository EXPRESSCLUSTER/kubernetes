# How to Deploy EXPRESSCLUSTER SingleServerSafe

## Evaluation Configuration
```
    +--------------------------+
 +--| Master Node              |
 |  | - CentOS 7.6.1810        |
 |  | - kubernetes v1.15.0     |
 |  | - Docker 1.13.1-96       |
 |  +--------------------------+
 |
 |  +--------------------------+
 +--| Worker Node #1           |
 |  | - CentOS 7.6.1810        |
 |  | - kubernetes v1.15.0     |
 |  | - Docker 1.13.1-96       |
 |  +--------------------------+
 |
 |  +--------------------------+
 +--| Worker Node #2           |
    | - CentOS 7.6.1810        |
    | - kubernetes v1.15.0     |
    | - Docker 1.13.1-96       |
    +--------------------------+
```
## Prerequisite
- Pull CentOS image from Docker Hub.
  ```bash
  # docker pull centos
  ```
## Load Container Image
1. Create a container images.
1. 
