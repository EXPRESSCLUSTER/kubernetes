# How to Deploy Grafana

## Overview
- Save some metrics data using MariaDB.
- Show a graph using Grafana.
  ```
                Web Browser
                     |
                     :
  +------------------|---------+
  | StatefulSet      | :3000   |
  | +----------------+-------+ |
  | | Grafana                | |
  | +----------------+-------+ |
  |                  | :3306   |
  | +----------------+-------+ |
  | | MariaDB                | |
  | +----------------+-------+ |
  +------------------|---------+
                     |
  +------------------|---------+
  | PersistentVolume |         |
  | +----------------+-------+ |
  | | Database files         | |
  | +------------------------+ |
  +----------------------------+
  ```
## Evaluation Environment
- CentOS 7.8
- kubernetes v1.19.1
- Docker 1.13.1

## Prerequisite
- Create a persistent volume for MariaDB in advance.
## Create Secret and ConfigMap
1. Create Secret to save password of MariaDB and Grafana.
   ```sh
   # kubectl create secret generic --save-config grafana-auth \
   --from-literal=root-password=<password of root user for MariaDB> \
   --from-literal=user-password=<password of a user for MariaDB> \
   --from-literal=grafana-password=<password of a user for Grafana>
   ```
1. Create yaml file as below and create ConfigMap.
   ```yaml
   # mysql.yaml
   apiVersion: 1
   datasources:
     - name: testdb
       type: mysql
       url: localhost:3306
       database: testdb
       user: testuser
       password: password
   ```
   ```sh
   # kubectl create configmap --save-config grafana-mysql --from-file=mysql.yaml
   ```   
1. Download [the yaml file](https://github.com/EXPRESSCLUSTER/kubernetes/blob/master/yaml/grafana-mariadb/sts-grafana.yaml) apply it.
1. Apply the manifest file.
   ```sh
   # kubectl apply -f sample-sts-grafana.yaml
   ```

