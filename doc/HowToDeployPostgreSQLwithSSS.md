# How to Deploy PostgreSQL with EXPRESSCLUSTER X SingleServerSafe
- This article shows how to deploy EXPRESSCLUSTER X SingleServerSafe using **sidecar pattern** to monitor PostgreSQL.

## Index
- [Overview](#overview)
- [Evaluated Environment](#evaluated-environment)
- [Create Single Node Cluster](#create-single-node-cluster)

## Overview
- SingleServerSafe container accesses to PostgreSQL database.
- If SingleServerSafe cannot receive response within timeout (default: 60 sec) from PostgreSQL, SingleServerSafe terminate PostgreSQL process (e.g., postgres).
  ```
   +--------------------------------+
   | Pod                            |
   | +----------------------------+ |
   | | SingleServerSafe container | |
   | +--|-------------------------+ |
   |    | Monitoring                |
   | +--V-------------------------+ |
   | | PostgreSQL                 | |
   | +--------------------+-------+ |
   +----------------------|---------+
                          | Mount persistent volume
   +----------------------|---------+
   | Persistent Volume    |         |
   | +--------------------+-------+ |
   | | Database files             | |
   | +----------------------------+ |
   +--------------------------------+
  ```

## Evaluated Environment
### Single Node
- Linux
  - Ubuntu 24.04.3 LTS
  - Kubernetes v1.34.2
  - Container
    - [PostgreSQL 18.1](https://hub.docker.com/_/postgres)
    - [EXPRESSCLUSTER X SingleServerSafe 5.3](https://hub.docker.com/r/expresscluster/sss4postgres)
- Windows Server 2025
  - WSL2 (Ubuntu Server 24.04.3 LTS)
  - K3s v1.34.2+k3s1
    - https://www.guide2wsl.com/k3s/
  - Container
    - [PostgreSQL 18.1](https://hub.docker.com/_/postgres)
    - [EXPRESSCLUSTER X SingleServerSafe 5.3](https://hub.docker.com/r/expresscluster/sss4postgres)

## Create Single Node Cluster
### Clone this Repository
1. Create a directory and clone this repository.
   ```sh
   mkdir -p /home/user/github/expresscluster
   ```
   ```sh
   cd /home/user/github/expresscluster
   ```
   ```sh
   git clone https://github.com/EXPRESSCLUSTER/kubernetes.git
   ```
### Create Persistent Volume
- If you use K3s, you don't need to create the Persistent Volume.
1. Create a directory to save PostgreSQL database files.
   ```sh
   sudo mkdir -p /mnt/hostpath/4postgres/postgres
   ```
1. Change the directory owner.
   ```sh
   sudo chown 999:999 /mnt/hostpath/4postgres/postgres
   ```
1. Move to the following directory.
   ```sh
   cd /home/user/github/expresscluster/kubernetes/yaml/posgtres/1-node
   ```
1. Create the Persistent Volume to save PostgreSQL database files.
   ```sh
   kubectl apply -f pv-hostpath-postgres.yaml
   ```
### Create Secret
1. Create Secret (name: postgres-auth) to save password of root user and a user for monitoring.
   ```sh
   kubectl create secret generic \
   --save-config postgres-auth \
   --from-literal=root-password=<password of root user>
   ```
   - Example
     ```sh
     kubectl create secret generic \
     --save-config postgres-auth \
     --from-literal=root-password=password \
     ```
1. Check if the Secret exists.
   ```
   # kubectl get secret/postgres-auth
   NAME           TYPE     DATA   AGE
   postgres-auth   Opaque   2      1m
   ```
### Create ConfigMap
1. Create ConfigMap.
   ```sh
   kubectl create configmap \
   --save-config sss4postgres \
   --from-file=../../../config/postgres/sss4postgres.conf
   ```
1. Check if the ConfigMap exists.
   ```
   # kubectl get configmap/sss4postgres
   NAME          DATA   AGE
   sss4postgres   1      1m
   ```

### Deploy PostgreSQL and SingleServerSafe
1. Create StatefulSet.
   ```sh
   kubectl apply -f sts-1node-postgres-sss.yaml
   ```
1. Check if the pods is running.
   ```
   # kubectl get pod
   NAME             READY   STATUS    RESTARTS      AGE
   postgres-sss-0   2/2     Running   0             43s
   ```
1. Check if SingleServerSafe is online on each container.
   ```
    ========================  CLUSTER STATUS  ===========================
     Cluster : postgres-sss-0
     <server>
      *postgres-sss-0 ..: Online           
         lanhb1         : Normal           LAN Heartbeat
     <group>
       container-recove : Online           
         current        : postgres-sss-0
         exec           : Online           
     <monitor>
       psqlw            : Normal           
    =====================================================================
   ```

### Verify Functionality
1. Run bash on PostgreSQL contaier.
   ```sh
   kubectl exec -it postgres-sss-0 -c postgres -- bash
   ```
1. Send SIGSTOP signal to postgres processes.
   ```sh
   kill -s SIGSTOP `pgrep postgres`
   ```
1. SingleServerSafe detects timeout error and terminates postgres process. Then, PostgreSQL container terminates and Kubernetes restart the PostgreSQL container.
   1. SingleServerSafe terminates postgres process and STATUS changes to Error.
      ```
      # kubectl get pod
      NAME             READY   STATUS    RESTARTS   AGE
      postgres-sss-0   1/2     Error     0          7m54s
      ```
   1. Kubernetes restarts PostgreSQL container and STATUS changes to Running.
      ```
      # kubectl get pod
      NAME             READY   STATUS    RESTARTS   AGE
      postgres-sss-0   2/2     Running   1          7m58s
      ```

### Change Variables for Monitoring
1. Modify variables in ``sts-1node-postgres-sss.yaml``.
   - Number of Replicas
     ```yaml
     spec:
       serviceName: mariadb
       replicas: 1            # Number of replicas
     ```
   - Variables of PostgreSQL
     ```yaml
             env:
             - name: POSTGRES_PASSWORD
               valueFrom:
                 secretKeyRef:
                   name: postgres-auth
                   key: root-password
             - name: POSTGRES_DB
               value: watch               # Database Name for Monitoring
             - name: POSTGRES_USER
               value: postgres
     ```
   - Variables of SingleServerSafe
     ```yaml
             env:
             - name: SSS_MAIN_CONTAINER_PROCNAME
               value: postgres
             - name: SSS_MONITOR_DB_NAME
               value: watch               # Database for Name for Monitoring
             - name: SSS_MONITOR_DB_USER
               value: postgres
             - name: SSS_MONITOR_DB_PASS
               valueFrom:
                 secretKeyRef:
                   name: postgres-auth
                   key: root-password
             - name: SSS_MONITOR_DB_PORT
               value: "5432"              # Port Number of PostgreSQL
             - name: SSS_MONITOR_PERIOD_SEC
               value: "10"                # Interval [sec]
             - name: SSS_MONITOR_TIMEOUT_SEC
               value: "10"                # Timeout [sec]
             - name: SSS_MONITOR_RETRY_CNT
               value: "2"                 # Retry
             - name: SSS_MONITOR_INITIAL_DELAY_SEC
               value: "0"                 # Initial Delay [sec]
             - name: SSS_NORECOVERY
               value: "0"                 # Terminate Container
                                          # (0: Terminate, 1: Do Nothing)
     ```

1. Apply the modified manifest file.
   ```sh
   kubectl apply -f sts-1node-postgres-sss.yaml
   ```
1. The pods will be recreated as below.
   ```
   # kubectl get pod
   NAME             READY   STATUS        RESTARTS   AGE
   postgres-sss-0   2/2     Terminating   1          19m
   ```
   ```
   # kubectl get pod
   NAME             READY   STATUS      RESTARTS   AGE
   postgres-sss-0   0/2     Completed   1          19m
   ```
   ```
   # kubectl get pod
   NAME             READY   STATUS    RESTARTS   AGE
   postgres-sss-0   2/2     Running   0          5s
   ```
