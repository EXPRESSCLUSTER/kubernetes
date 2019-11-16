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
1. Create persistent volume for StatefulSet.
1. Download [config file](https://github.com/EXPRESSCLUSTER/kubernetes/blob/master/config/mariadb/sss4mariadb.conf) and edit the following parameters.
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
1. Download the [yaml file]() and edit the following parameters.
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
