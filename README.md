# Kubernetes
- The purpose of this project to open knowledge for Kubernetes and EXPRESSCLUSTER.

## How to Install Kubernetes
- Please refer to the latest document.
  - https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/
- We have installed Kubernetes with `kubeadm` command on the following machines. We hope these will be helpful for you to understand how to install Kubernetes.
  - [Ubuntu Server 22.04](doc/HowToInstallK8s-containerd-Ubuntu2204.md)
    - Kubernetes v1.28.1
    - containerd 1.7.2
  - [Ubuntu Server 20.04](doc/HowToInstallK8s-containerd.md)
    - Kubernetes v1.12.2
    - containerd 1.3.3
  - [CentOS 7.6](doc/HowToInstallK8s.md)
    - Kubernetes v1.15.0
    - Docker 1.13.1-96

## How to Deploy EXPRESSCLUSTER X SingleServerSafe
- Please refer to the following steps.
  - English
    - [MariaDB](doc/HowToDeployMariaDBwithSSS.md)
    - [PostgreSQL](doc/HowToDeployPostgreSQLwithSSS.md)
  - [Japanese](doc/HowToDeploySSS_jp.md)

## How to Deploy Grafana
- Please refer to [How to Deploy Grafana](doc/HowToDeployGrafana.md).