# How to Deploy EXPRESSCLUSTER X SingleServerSafe
- This article shows how to deploy EXPRESSCLUSTER X SingleServerSafe using **sidecar pattern** to monitor some software. 

## Index
- [Evaluation Configuration](#evaluation-configuration)
- [Monitoring MariaDB](#Monitoring-MariaDB)

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
   - database
   - username
   - password
     ```xml
       <monitor>
         <types name="mysqlw"/>
         <mysqlw name="mysqlw">
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
