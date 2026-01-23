# How to Deploy MariaDB with EXPRESSCLUSTER X SingleServerSafe
- This article shows how to deploy EXPRESSCLUSTER X SingleServerSafe using **sidecar pattern** to monitor MariaDB.

## Index
- [Overview](#overview)

## Overview
- SingleServerSafe container accesses to MariaDB database.
- If SingleServerSafe cannot receive response within timeout (default: 60 sec) from MariaDB, SingleServerSafe terminate MariaDB process (e.g., mariadbd).
  ```
   +--------------------------------+
   | Pod                            |
   | +----------------------------+ |
   | | SingleServerSafe container | |
   | +--|-------------------------+ |
   |    | Monitoring                |
   | +--V-------------------------+ |
   | | MariaDB                    | |
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
    - [MariaDB 11.8.5](https://hub.docker.com/_/mariadb)
    - [EXPRESSCLUSTER X SingleServerSafe 5.3](https://hub.docker.com/r/expresscluster/sss4mariadb)
- Windows Server 2025
  - WSL2 (Ubuntu Server 24.04.3 LTS)
  - K3s v1.34.2+k3s1
    - https://www.guide2wsl.com/k3s/
  - Container
    - [MariaDB 11.8.5](https://hub.docker.com/_/mariadb)
    - [EXPRESSCLUSTER X SingleServerSafe 5.3](https://hub.docker.com/r/expresscluster/sss4mariadb)

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
1. Create a directory to save MariaDB database files.
   ```sh
   sudo mkdir -p /mnt/hostpath/mariadb
   ```
1. Change the directory owner.
   ```sh
   sudo chown 999:999 /mnt/hostpath/mariadb
   ```
1. Move to the following directory.
   ```sh
   cd /home/user/github/expresscluster/kubernetes/yaml/mariadb/1-node
   ```
1. Create the Persistent Volume to save MariaDB database files.
   ```sh
   kubectl apply -f pv-hostpath-mariadb.yaml
   ```
### Create Secret
1. Create Secret (name: mariadb-auth) to save password of root user and a user for monitoring.
   ```sh
   kubectl create secret generic \
   --save-config mariadb-auth \
   --from-literal=root-password=<password of root user> \
   --from-literal=user-password=<password of a user for monitoring>
   ```
   - Example
     ```sh
     kubectl create secret generic \
     --save-config mariadb-auth \
     --from-literal=root-password=password \
     --from-literal=user-password=password
     ```
1. Check if the Secret exists.
   ```
   # kubectl get secret/mariadb-auth
   NAME           TYPE     DATA   AGE
   mariadb-auth   Opaque   2      1m
   ```
### Create ConfigMap
1. Create ConfigMap.
   ```sh
   kubectl create configmap \
   --save-config sss4mariadb \
   --from-file=../../../config/mariadb/sss4mariadb.conf
   ```
1. Check if the ConfigMap exists.
   ```
   # kubectl get configmap/sss4mariadb
   NAME          DATA   AGE
   sss4mariadb   1      1m
   ```

### Deploy MariaDB and SingleServerSafe
1. Create StatefulSet.
   ```sh
   kubectl apply -f sts-1node-mariadb-sss.yaml
   ```
1. Check if the pods is running.
   ```
   # kubectl get pod
   NAME            READY   STATUS    RESTARTS   AGE
   mariadb-sss-0   2/2     Running   0          55s
   ```
1. Check if SingleServerSafe is online on each container.
   ```
   kubectl exec -it mariadb-sss-0 -c sss clpstat
    ========================  CLUSTER STATUS  ===========================
     Cluster : mariadb-sss-0
     <server>
      *mariadb-sss-0 ...: Online
         lanhb1         : Normal           LAN Heartbeat
     <group>
       container-recove : Online
         current        : mariadb-sss-0
         exec           : Online
     <monitor>
       mysqlw           : Normal
    =====================================================================
   ```

### Verify Functionality
1. Run bash on MariaDB contaier.
   ```sh
   kubectl exec -it mariadb-sss-0 -c mariadb -- bash
   ```
1. Send SIGSTOP signal to mariadbd process.
   ```sh
   kill -s SIGSTOP `pgrep mariadbd`
   ```
1. SingleServerSafe detects timeout error and terminates mariadbd process. Then, MariaDB container terminates and Kubernetes restart the MariaDB container.
   1. SingleServerSafe terminates mariadbd process and STATUS changes to Error.
      ```
      # kubectl get pod
      NAME            READY   STATUS    RESTARTS   AGE
      mariadb-sss-0   1/2     Error     0          7m54s
      ```
   1. Kubernetes restarts MariaDB container and STATUS changes to Running.
      ```
      # kubectl get pod
      NAME            READY   STATUS    RESTARTS   AGE
      mariadb-sss-0   2/2     Running   1          7m58s
      ```

### Change Variables for Monitoring
1. Modify variables in ``sts-1node-mariadb-sss.yaml``.
   - Number of Replicas
     ```yaml
     spec:
       serviceName: mariadb
       replicas: 1            # Number of replicas
     ```
   - Variables of MariaDB
     ```yaml
             env:
             - name: MYSQL_ROOT_PASSWORD
               valueFrom:
                 secretKeyRef:
                   name: mariadb-auth
                   key: root-password
             - name: MYSQL_DATABASE
               value: watch               # Database Name for Monitoring
             - name: MYSQL_USER
               value: watcher             # User Name for Monitoring
             - name: MYSQL_PASSWORD
               valueFrom:
                 secretKeyRef:
                   name: mariadb-auth
                   key: user-password
     ```
   - Variables of SingleServerSafe
     ```yaml
             env:
             - name: SSS_MAIN_CONTAINER_PROCNAME
               value: mariadbd
             - name: SSS_MONITOR_DB_NAME
               value: watch               # Database for Name for Monitoring
             - name: SSS_MONITOR_DB_USER
               value: watcher             # User Name for Monitoring
             - name: SSS_MONITOR_DB_PASS
               valueFrom:
                 secretKeyRef:
                   name: mariadb-auth
                   key: user-password
             - name: SSS_MONITOR_DB_PORT
               value: "3306"              # Port Number of MariaDB
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
   kubectl apply -f sts-1node-mariadb-sss.yaml
   ```
1. The pods will be recreated as below.
   ```
   # kubectl get pod
   NAME            READY   STATUS        RESTARTS   AGE
   mariadb-sss-0   2/2     Terminating   1          19m
   ```
   ```
   # kubectl get pod
   NAME            READY   STATUS      RESTARTS   AGE
   mariadb-sss-0   0/2     Completed   1          19m
   ```
   ```
   # kubectl get pod
   NAME            READY   STATUS    RESTARTS   AGE
   mariadb-sss-0   2/2     Running   0          5s
   ```

<!--
```
sudo ~/.local/bin/k3s kubectl create secret generic \
--save-config mariadb-auth \
--from-literal=root-password=password \
--from-literal=user-password=password
```
```
sudo ~/.local/bin/k3s kubectl create configmap \
--save-config sss4mariadb \
--from-file=sss4mariadb.conf
```
1. Open ``sts-1node-mariadb-sss.yaml`` and and modify the following parameters. Set the same value for **Database Name** and **User Name for Monitoring**.
   - Number of Replicas
     ```yaml
     spec:
       serviceName: mariadb
       replicas: 1            # Number of replicas
     ```
   - Variables of MariaDB
     ```yaml
             env:
             - name: MYSQL_ROOT_PASSWORD
               valueFrom:
                 secretKeyRef:
                   name: mariadb-auth
                   key: root-password
             - name: MYSQL_DATABASE
               value: watch               # Database Name for Monitoring
             - name: MYSQL_USER
               value: watcher             # User Name for Monitoring
             - name: MYSQL_PASSWORD
               valueFrom:
                 secretKeyRef:
                   name: mariadb-auth
                   key: user-password
     ```
   - Variables of SingleServerSafe
     ```yaml
             env:
             - name: SSS_MAIN_CONTAINER_PROCNAME
               value: mariadbd
             - name: SSS_MONITOR_DB_NAME
               value: watch               # Database for Name for Monitoring
             - name: SSS_MONITOR_DB_USER
               value: watcher             # User Name for Monitoring
             - name: SSS_MONITOR_DB_PASS
               valueFrom:
                 secretKeyRef:
                   name: mariadb-auth
                   key: user-password
             - name: SSS_MONITOR_DB_PORT
               value: "3306"              # Port Number of MariaDB
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

-->