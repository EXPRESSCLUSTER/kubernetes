# How to Deploy EXPRESSCLUSTER X SingleServerSafe
- This article shows how to deploy EXPRESSCLUSTER X SingleServerSafe using **sidecar pattern** to monitor some software. 

## Index
- [Overview](#overview)
- [Evaluation Configuration](#evaluation-configuration)
- [Monitoring MariaDB](#Monitoring-MariaDB)
- [Monitoring PostgreSQL](#Monitoring-PostgreSQL)
- [Logging](#Logging)

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
- Master Node (1 node)
- Worker Node (3 nodes)
- CentOS 7.7.1908
- kubernetes v1.16.3
- Docker 1.13.1

## Monitoring MariaDB
### Create Database
1. Create a persistent volume for MariaDB. The following expamle uses StatefulSet.
1. Download [the yaml file for MariaDB only](https://github.com/EXPRESSCLUSTER/kubernetes/blob/master/yaml/mariadb/stateful-mariadb.yaml) and edit the following parameters.
   ```yml
             env:
             - name: MYSQL_ROOT_PASSWORD
               value: password
             - name: MYSQL_DATABASE
               value: watch
   ```   
1. Apply it.
   ```sh
   # kubectl apply -f stateful-mariadb.yaml
   ```
1. Check if MYSQL_DATABSE (e.g. **watch**) directory exists on the persistent volume.
   ```sh
   # ls -l

   -rw-rw---- 1 polkitd ssh_keys    32768 Nov 21 07:06 aria_log.00000001
   -rw-rw---- 1 polkitd ssh_keys       52 Nov 21 07:06 aria_log_control
    :
   drwx------ 2 polkitd ssh_keys     4096 Nov 21 07:06 mysql
   drwx------ 2 polkitd ssh_keys       20 Nov 21 07:03 performance_schema
   drwx------ 2 polkitd ssh_keys       20 Nov 21 07:06 watch   
   ```
1. Delete it.
   ```sh
   # kubectl delete -f stateful-mariadb.yaml
   ```
### Deploy MariaDB and SingleServerSafe
1. Download [the config file for SingleServerSafe](https://github.com/EXPRESSCLUSTER/kubernetes/blob/master/config/mariadb/sss4mariadb.conf) and edit the following parameters.
   - interval
   - timeout
   - database
   - username
   - password
     ```xml
       <monitor>
         <types name="mysqlw"/>
         <mysqlw name="mysqlw">
           <polling>
             <interval>10</interval>
             <timeout>60</timeout>
           : 
           <parameters>
             <database>watch</database>
             <username>root</username>
             <password>password</password>
     ```
1. Create ConfigMap.
   ```sh
   # kubectl create cm sss4mariadb --from-file=sss4mariadb.conf
   ```
1. Check if the config map is created.
   ```sh
   # kubectl get cm/sss4mariadb
   NAME          DATA   AGE
   sss4mariadb   1      1m
   ```
1. Download [the yaml file](https://github.com/EXPRESSCLUSTER/kubernetes/blob/master/yaml/mariadb/stateful-mariadb-sss.yaml) and edit the following parameters.
   ```yml
             env:
             - name: MYSQL_ROOT_PASSWORD
               value: password
             - name: MYSQL_DATABASE
               value: watch
   ```   
1. Create StatefulSet.
   ```sh
   # kubectl create -f stateful-mariadb-sss.yml
   ```
1. Check if the Pods are running.
   ```sh
   # kubectl get pod
   NAME                                     READY   STATUS    RESTARTS   AGE
   mariadb-sss-0                            2/2     Running   0          6m19s
   mariadb-sss-1                            2/2     Running   0          5m57s
   ```
1. Check if SingleServerSafe is running.
   ```sh
   # kubectl exec mariadb-sss-0 -c sss clpstat
    ========================  CLUSTER STATUS  ===========================
     Cluster : mariadb-sss-0
     <server>
      *mariadb-sss-0 ...: Online
         lanhb1         : Normal           LAN Heartbeat
     <group>
       failover ........: Online
         current        : mariadb-sss-0
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
1. SingleServerSafe detects timeout error and terminates mysqld process. Then, MariaDB container stops and kubernetes restart the MariaDB container.
   ```sh
   # kubectl get pod
   NAME                                     READY   STATUS    RESTARTS   AGE
   mariadb-sss-0                            2/2     Running   1          34m
   mariadb-sss-1                            2/2     Running   0          34m
   ```

## Monitoring PostgreSQL
1. Create a persistent volume for PostgreSQL. The following expamle uses StatefulSet.
1. Download [the config file for PostgreSQL](https://github.com/EXPRESSCLUSTER/kubernetes/blob/master/config/postgres/postgres-configmap.yaml) and edit the following parameters.
   ```yml
   data:
   POSTGRES_DB: watch
   POSTGRES_USER: postgres
   POSTGRESS_PASSWORD: password
   ```
1. Apply the config file.
   ```sh
   # kubectl apply -f postgres-configmap.yaml
   # kubectl get cm/postgres-confg
   NAME              DATA   AGE
   postgres-config   3      5s
   ```
1. Download [the yaml file for PostgreSQL only](https://github.com/EXPRESSCLUSTER/kubernetes/blob/master/yaml/postgres/stateful-postgres.yaml) and apply it.
   ```sh
   # kubectl apply -f stateful-postgres.yaml
   ```
1. Check if PostgreSQL directories and files exist on the persistent volume.
   ```sh
   # ls -l

   drwx------ 6 polkitd ssh_keys    54 Nov 22 22:38 base
   drwx------ 2 polkitd ssh_keys  4096 Nov 23 07:35 global
    :
   -rw------- 1 polkitd ssh_keys    36 Nov 22 22:57 postmaster.opts
   -rw------- 1 polkitd ssh_keys    94 Nov 22 22:57 postmaster.pid   
   ```
1. Delete it.
   ```sh
   # kubectl delete -f stateful-postgres.yaml
   ```
### Deploy PostgreSQL and SingleServerSafe
1. Download [the config file for SingleServerSafe](https://github.com/EXPRESSCLUSTER/kubernetes/blob/master/config/postgres/sss4postgres.conf) and edit the following parameters.
   - interval
   - timeout
   - database
   - username
   - password
     ```xml
       <monitor>
         <types name="psqlw"/>
         <mysqlw name="psqlw">
           <polling>
             <interval>10</interval>
             <timeout>60</timeout>
           : 
           <parameters>
             <database>watch</database>
             <username>postgres</username>
             <password>password</password>
     ```
1. Create ConfigMap.
   ```sh
   # kubectl create cm sss4postgres --from-file=sss4postgres.conf
   ```
1. Check if the config map is created.
   ```sh
   # kubectl get cm/sss4postgres
   NAME          DATA   AGE
   sss4postgres   1      1m
   ```
1. Download [the yaml file](https://github.com/EXPRESSCLUSTER/kubernetes/blob/master/yaml/postgres/stateful-postgres-sss.yaml) and create StatefulSet.
   ```sh
   # kubectl create -f stateful-postgres-sss.yml
   ```
1. Check if the Pods are running.
   ```sh
   # kubectl get pod
   NAME                                     READY   STATUS    RESTARTS   AGE
   postgres-sss-0                           2/2     Running   0          6m19s
   postgres-sss-1                           2/2     Running   0          5m57s
   ```
1. Check if SingleServerSafe is running.
   ```sh
   # kubectl exec postgres-sss-0 -c sss clpstat
    ========================  CLUSTER STATUS  ===========================
     Cluster : sss
     <server>
      *postgres-sss-0 ..: Online
         lanhb1         : Normal           LAN Heartbeat
     <group>
       failover ........: Online
         current        : postgres-sss-0
         exec           : Online
     <monitor>
       psqlw            : Normal
    =====================================================================
   ```

### Verify Functionality
1. Run bash on PostgreSQL contaier.
   ```sh
   # kubectl exec -it postgres-sss-0 -c postgres bash
   ```
1. Send SIGSTOP signal to postgres process.
   ```sh
   # kill -s SIGSTOP `pgrep postgres`
   ```
1. SingleServerSafe detects timeout error and terminates postgres process. Then, PostgreSQL container stops and kubernetes restart the PostgreSQL container.
   ```sh
   # kubectl get pod
   NAME             READY   STATUS    RESTARTS   AGE
   postgres-sss-0   2/2     Running   1          5m14s
   postgres-sss-1   2/2     Running   0          5m7s
   ```

## Logging
- This is an example to set up Fluentd container send SingleServerSafe log to the other Fluentd.
  ```
   +--------------------------------+
   | Pod                            |
   | +----------------------------+ | Send logs to the other Fluentd
   | | Fluentd container        -------> 
   | +------------|---------------+ |
   |              | Tail logs       |
   |  +-----------V--------------+  |
   |  | emptyDir                 |  |
   |  +-----------A--------------+  |
   |              | Output logs     |
   | +------------|---------------+ |
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
  
### Install Fluentd
1. Install Fluentd to some Linux machine. For detail, please refer to https://docs.fluentd.org/installation.
1. Modify /etc/td-agent/td-agent.conf as below.
   ```
   <source>
     @type forward
     port 24224
     bind 0.0.0.0
   </source>
   <match **>
     @type file
     format single_value
     append true
     path /var/log/td-agent/containers.log
     time_slice_format %Y-%m-%d
     <buffer>
       path /var/log/td-agent/buffer
       flush_mode interval
       flush_interval 10s
     </buffer>
   </match>
   ```
1. Restart Fluentd.
   ```sh
   # systemctl enable td-agent
   # systemctl daemon-reload
   # systemctl restart td-agent
   ```

### Deploy Fluentd Container
1. Download ConfigMap and set IP address of Fluentd.
   ```
   <match **>
     @type forward
     <server>
       host <IP address>
       port 24224
     </server>
   </match>
   <source>
     @type tail
     format none
     path /mydata/alertlog.alt
     tag clp.alt
   </source>   
   ```
1. Create ConfigMap for Fluentd.
   ```sh
   # kubectl create cm fluentd --from-file=fluent.conf
   ```
1. Download yaml file and apply it.