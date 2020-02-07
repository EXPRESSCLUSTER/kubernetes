# How to Deploy EXPRESSCLUSTER X SingleServerSafe
- This article shows how to deploy EXPRESSCLUSTER X SingleServerSafe using **sidecar pattern** to monitor some software. 

## Index
- [Overview](#overview)
- [Evaluation Configuration](#evaluation-configuration)
- [Monitoring MariaDB](#Monitoring-MariaDB)
- [Monitoring PostgreSQL](#Monitoring-PostgreSQL)

## Overview
- SingleServerSafe container connects to the application.
- If SingleServerSafe cannot receive response within timeout (default: 60 sec) from the application, SingleServerSafe terminate the application process.
  ```
   +--------------------------------+
   | Pod                            |
   | +----------------------------+ |
   | | SingleServerSafe container | |
   | +--|-------------------------+ |
   |    | Monitoring                |
   | +--V-------------------------+ |
   | | Application (e.g. Database)| |
   | +--------------------+-------+ |
   +----------------------|---------+
                          | Mount persistent volume
   +----------------------|---------+
   | Persistent Volume    |         |
   | +--------------------+-------+ |
   | | Files (e.g. Database files)| |
   | +----------------------------+ |
   +--------------------------------+
  ```

## Evaluation Configuration
### Kubernetes Cluster
- CentOS
  - Master Node (1 node)
  - Worker Node (3 nodes)
  - CentOS 7.7.1908
  - kubernetes v1.17.2
  - Docker 18.09.7
- Ubuntu
  - Master Node (1 node)
  - Worker Node (3 nodes)
  - Ubuntu 18.04.4 LTS
  - kubernetes v1.17.2
  - Docker 19.03.5
### Application
  - MariaDB 10.1, 10.4
  - PostgreSQL 11.3, 11.6
  - EXPRESSCLUSTER X SingleServerSafe 4.1 for Linux

## Monitoring MariaDB
### Prerequisite
- Create a persistent volume for MariaDB in advance.
- The following expamle uses StatefulSet.

### Create Secret and ConfigMap
1. Create Secret (name: mariadb-auth) to save password of root user and a user for monitoring.
   ```sh
   # kubectl create secret generic --save-config mariadb-auth \
   --from-literal=root-password=<password of root user> \
   --from-literal=user-password=<password of a user for monitoring>
   ```
1. Check if the Secret exists.
   ```sh
   # kubectl get secret/mariadb-auth
   NAME           TYPE     DATA   AGE
   mariadb-auth   Opaque   2      1m
   ```
1. Download SingleServerSafe [config file (sss4mariadb.conf)](https://github.com/EXPRESSCLUSTER/kubernetes/blob/master/config/mariadb/sss4mariadb.conf).
1. Create ConfigMap (name: sss4mariadb).
   ```sh
   # kubectl create configmap --save-config sss4mariadb --from-file=sss4mariadb.conf
   ```
1. Check if the ConfigMap exists.
   ```sh
   # kubectl get configmap/sss4mariadb
   NAME          DATA   AGE
   sss4mariadb   1      1m
   ```

### Deploy MariaDB and SingleServerSafe
1. Download [manifest file (sample-sts-mariadb-sss.yaml)](https://github.com/EXPRESSCLUSTER/kubernetes/blob/master/yaml/mariadb/sample-sts-mariadb-sss.yaml) and modify the following parameters. Set the same value for **Database Name** and **User Name for Monitoring**.
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
               value: mysqld
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
1. Create StatefulSet.
   ```sh
   # kubectl apply -f sample-sts-mariadb-sss.yaml
   ```
1. Check if all pods are running.
   ```sh
   # kubectl get pod
   NAME            READY   STATUS    RESTARTS   AGE
   mariadb-sss-0   2/2     Running   0          55s
   mariadb-sss-1   2/2     Running   0          39s
   mariadb-sss-2   2/2     Running   0          21s
   ```
1. Check if SingleServerSafe is online on each container.
   ```sh
   # for i in {0..2}; do kubectl exec -it mariadb-sss-$i -c sss clpstat; done
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
    ========================  CLUSTER STATUS  ===========================
     Cluster : mariadb-sss-1
     <server>
      *mariadb-sss-1 ...: Online
         lanhb1         : Normal           LAN Heartbeat
     <group>
       container-recove : Online
         current        : mariadb-sss-1
         exec           : Online
     <monitor>
       mysqlw           : Normal
    =====================================================================
    ========================  CLUSTER STATUS  ===========================
     Cluster : mariadb-sss-2
     <server>
      *mariadb-sss-2 ...: Online
         lanhb1         : Normal           LAN Heartbeat
     <group>
       container-recove : Online
         current        : mariadb-sss-2
         exec           : Online
     <monitor>
       mysqlw           : Normal
    =====================================================================
   ```

### Verify Functionality
1. Run bash on MariaDB contaier.
   ```sh
   # kubectl exec -it mariadb-sss-0 -c mariadb bash
   ```
1. Send SIGSTOP signal to mysqld process.
   ```sh
   # kill -s SIGSTOP `pgrep mysqld`
   ```
1. SingleServerSafe detects timeout error and terminates mysqld process. Then, MariaDB container terminates and kubernetes restart the MariaDB container.
   - SingleServerSafe terminates mysqld process and STATUS changes to Error.
     ```sh
     # kubectl get pod
     NAME            READY   STATUS    RESTARTS   AGE
     mariadb-sss-0   1/2     Error     0          7m54s
     mariadb-sss-1   2/2     Running   0          7m38s
     mariadb-sss-2   2/2     Running   0          7m20s
     ```
   - kubernetes restarts MariaDB container and STATUS changes to Running.
     ```sh
     # kubectl get pod
     NAME            READY   STATUS    RESTARTS   AGE
     mariadb-sss-0   2/2     Running   1          7m58s
     mariadb-sss-1   2/2     Running   0          7m42s
     mariadb-sss-2   2/2     Running   0          7m24s
     ```

### Change Variables for Monitoring
1. Modify variables in the manifest file (sample-sts-mariadb-sss.yaml).
1. Apply the modified manifest file.
   ```sh
   # kubectl apply -f sample-sts-mariadb-sss.yaml
   ```
1. The pods are recreated one by one with rolling update.
   ```sh
   # kubectl get pod
   NAME            READY   STATUS        RESTARTS   AGE
   mariadb-sss-0   2/2     Running       1          19m
   mariadb-sss-1   2/2     Running       0          19m
   mariadb-sss-2   2/2     Terminating   0          19m
   ```
   ```sh
   # kubectl get pod
   NAME            READY   STATUS              RESTARTS   AGE
   mariadb-sss-0   2/2     Running             1          20m
   mariadb-sss-1   2/2     Running             0          20m
   mariadb-sss-2   0/2     ContainerCreating   0          4s
   ```
   ```sh
   # kubectl get pod
   NAME            READY   STATUS        RESTARTS   AGE
   mariadb-sss-0   2/2     Running       1          20m
   mariadb-sss-1   2/2     Terminating   0          20m
   mariadb-sss-2   2/2     Running       0          21s
   ```

## Monitoring PostgreSQL
### Prerequisite
- Create a persistent volume for MariaDB in advance.
- The following expamle uses StatefulSet.

### Create Secret and ConfigMap
1. Create Secret (name: postgres-auth) to save password of root user and a user for monitoring.
   ```sh
   # kubectl create secret generic --save-config postgres-auth \
   --from-literal=root-password=<password of root user>
   ```
1. Check if the Secret exists.
   ```sh
   # kubectl get secret/postgres-auth
   NAME           TYPE     DATA   AGE
   postgres-auth  Opaque   2      1m
   ```
1. Download SingleServerSafe [config file (sss4postgres.conf)](https://github.com/EXPRESSCLUSTER/kubernetes/blob/master/config/postgres/sss4postgres.conf).
1. Create ConfigMap (name: sss4postgres).
   ```sh
   # kubectl create configmap --save-config sss4postgres --from-file=sss4postgres.conf
   ```
1. Check if the ConfigMap exists.
   ```sh
   # kubectl get configmap/sss4postgres
   NAME          DATA   AGE
   sss4postgres  1      1m
   ```

### Deploy PostgreSQL and SingleServerSafe
1. Download [manifest file (sample-sts-postgres-sss.yaml)](https://github.com/EXPRESSCLUSTER/kubernetes/blob/master/yaml/postgres/sample-sts-postgres-sss.yaml) and modify the following parameters.
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
               value: postgres            # User Name for Monitoring
     ```
   - Variables of SingleServerSafe
     ```yaml
             env:
             - name: SSS_MAIN_CONTAINER_PROCNAME
               value: postgres
             - name: SSS_MONITOR_DB_NAME
               value: watch               # Database Name for Monitoring
             - name: SSS_MONITOR_DB_USER
               value: postgres            # User Name for Monitoring
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
1. Create StatefulSet.
   ```sh
   # kubectl apply -f sample-sts-mariadb-sss.yaml
   ```
1. Check if all pods are running.
   ```sh
   # kubectl get pod
   NAME            READY   STATUS    RESTARTS   AGE
   postgres-sss-0   2/2     Running   0          31s
   postgres-sss-1   2/2     Running   0          27s
   postgres-sss-2   2/2     Running   0          23s
   ```
1. Check if SingleServerSafe is online on each container.
   ```sh
   # for i in {0..2}; do kubectl exec -it postgres-sss-$i -c sss clpstat; done
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
    ========================  CLUSTER STATUS  ===========================
     Cluster : postgres-sss-1
     <server>
      *postgres-sss-1 ..: Online
         lanhb1         : Normal           LAN Heartbeat
     <group>
       container-recove : Online
         current        : postgres-sss-1
         exec           : Online
     <monitor>
       psqlw            : Normal
    =====================================================================
    ========================  CLUSTER STATUS  ===========================
     Cluster : postgres-sss-2
     <server>
      *postgres-sss-2 ..: Online
         lanhb1         : Normal           LAN Heartbeat
     <group>
       container-recove : Online
         current        : postgres-sss-2
         exec           : Online
     <monitor>
       psqlw            : Normal
    =====================================================================
   ```

### Verify Functionality
1. Run bash on PostgreSQL contaier.
   ```sh
   # kubectl exec -it postgres-sss-0 -c mariadb bash
   ```
1. Send SIGSTOP signal to postgres process.
   ```sh
   # kill -s SIGSTOP `pgrep postgres`
   ```
1. SingleServerSafe detects timeout error and terminates postgres process. Then, PostgreSQL container terminates and kubernetes restart the PostgreSQL container.
   - SingleServerSafe terminates postgres process and STATUS changes to Error.
     ```sh
     # kubectl get pod
     NAME            READY   STATUS    RESTARTS   AGE
     postgres-sss-0   1/2     Error     0          5m43s
     postgres-sss-1   2/2     Running   0          5m39s
     postgres-sss-2   2/2     Running   0          5m35s
     ```
   - kubernetes restarts PostgreSQL container and STATUS changes to Running.
     ```sh
     # kubectl get pod
     NAME            READY   STATUS    RESTARTS   AGE
     postgres-sss-0   2/2     Running   1          5m46s
     postgres-sss-1   2/2     Running   0          5m42s
     postgres-sss-2   2/2     Running   0          5m38s
     ```

### Change Variables for Monitoring
1. Modify variables in the manifest file (sample-sts-postgres-sss.yaml).
1. Apply the modified manifest file.
   ```sh
   # kubectl apply -f sample-sts-postgres-sss.yaml
   ```
1. The pods are recreated one by one with rolling update.
   ```sh
   # kubectl get pod
   NAME            READY   STATUS        RESTARTS   AGE
   postgres-sss-0   2/2     Running       1          9m48s
   postgres-sss-1   2/2     Running       0          9m44s
   postgres-sss-2   0/2     Terminating   0          9m40s
   ```
   ```sh
   # kubectl get pod
   NAME            READY   STATUS              RESTARTS   AGE
   postgres-sss-0   2/2     Running             1          9m49s
   postgres-sss-1   2/2     Running             0          9m45s
   postgres-sss-2   0/2     ContainerCreating   0          1s
   ```
   ```sh
   # kubectl get pod
   NAME            READY   STATUS        RESTARTS   AGE
   postgres-sss-0   2/2     Running       1          10m
   postgres-sss-1   0/2     Terminating   0          10m
   postgres-sss-2   2/2     Running       0          49s
   ```