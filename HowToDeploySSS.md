# How to Deploy EXPRESSCLUSTER X SingleServerSafe


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


## MariaDB
### Deploy MariaDB and EXPRESSCLUSTER X SingleServerSafe on the Same Container
1. Load the container contains MariaDB and EXPRESSCLUSTER X SingleServerSafe on worker nodes. Regarding the container image, please refer to [Install SingleServerSafe on MariaDB Container](https://github.com/EXPRESSCLUSTER/Docker/blob/master/HowToInstallSSS.md#install-singleserversafe-on-mariadb-container).

### Deploy MariaDB and EXPRESSCLUSTER X SingleServerSafe on the Same Pod
1. 