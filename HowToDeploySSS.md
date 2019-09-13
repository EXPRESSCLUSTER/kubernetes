# How to Deploy EXPRESSCLUSTER X SingleServerSafe


## Evaluation Configuration
```
    +--------------------------+
 +--| Master Node              |
 |  | - CentOS 7.6.1810        |
 |  | - kubernetes v1.15.3     |
 |  | - Docker 1.13.1          |
 |  +--------------------------+
 |
 |  +--------------------------+
 +--| Worker Node #1           |
 |  | - CentOS 7.6.1810        |
 |  | - kubernetes v1.15.3     |
 |  | - Docker 1.13.1          |
 |  +--------------------------+
 |
 |  +--------------------------+
 +--| Worker Node #2           |
    | - CentOS 7.6.1810        |
    | - kubernetes v1.15.3     |
    | - Docker 1.13.1          |
    +--------------------------+
```

## MariaDB
### Create PV and PVC
1. Create persistent volumes for MariaDB and SingleServerSafe.
   1. Create yaml files as below.
      - pv-mariadb01.yml
        ```yml
        apiVersion: v1
        kind: PersistentVolume
        metadata:
          name: mariadb01
        spec:
          capacity:
            storage: 10Gi
          volumeMode: Filesystem
          accessModes:
            - ReadWriteOnce
          persistentVolumeReclaimPolicy: Retain
          hostPath:
            path: <your path>
            type: DirectoryOrCreate
        ```
      - pv-sss01.yml
        ```yml
        apiVersion: v1
        kind: PersistentVolume
        metadata:
          name: sss01
        spec:
          capacity:
            storage: 1Gi
          volumeMode: Filesystem
          accessModes:
            - ReadWriteOnce
          persistentVolumeReclaimPolicy: Retain
          hostPath:
            path: <your path>
            type: DirectoryOrCreate
        ```
   1. Apply the yaml file.
      ```sh
      # kubectl apply -f pv-mariadb01.yml
      # kubectl apply -f pv-sss01.yml
      ```
1. Create persistent volume claims for MariaDB and SingleServerSafe.
   1. Create yaml files as below.
      - pvc-mariadb01.yml
        ```yaml
        apiVersion: v1
        kind: PersistentVolumeClaim
        metadata:
          name: pvc-mariadb01
        spec:
          accessModes:
          - ReadWriteOnce
          volumeMode: Filesystem
          resources:
            requests:
              storage: 10Gi
        ```
      - pvc-sss01.yml
        ```yaml
        apiVersion: v1
        kind: PersistentVolumeClaim
        metadata:
          name: pvc-sss01
        spec:
          accessModes:
          - ReadWriteOnce
          volumeMode: Filesystem
          resources:
            requests:
              storage: 1Gi
        ```
   1. Apply the yaml files.
      ```sh
      # kubectl apply -f pvc-mariadb01.yml
      # kubectl apply -f pvc-sss01.yml
      ```
1. Check the PV and PVC status.
   ```sh
   # kubectl get pv,pvc
   NAME                         CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                   STORAGECLASS   REASON   AGE
   persistentvolume/mariadb01   10Gi       RWO            Retain           Bound    default/pvc-mariadb01                           5h10m
   persistentvolume/sss01       1Gi        RWO            Retain           Bound    default/pvc-sss01                               5h9m
   
   NAME                                  STATUS   VOLUME      CAPACITY   ACCESS MODES   STORAGECLASS   AGE
   persistentvolumeclaim/pvc-mariadb01   Bound    mariadb01   10Gi       RWO                           5h5m
   persistentvolumeclaim/pvc-sss01       Bound    sss01       1Gi        RWO                           5h4m
   ```
### Pull MariaDB Image and Create Database
1. Pull MariaDB image.
   ```sh
   # docker pull mariadb
   ```
1. Create a yaml file.
   - pod-mariadb.yml
     ```yaml
     apiVersion: v1
     kind: Pod
     metadata:
       name: mariadb
       labels:
         app: mariadb
     spec:
       containers:
       - name: mariadb01
         image: mariadb:latest
         imagePullPolicy: Never
         volumeMounts:
         - name: pvc-mariadb01
           mountPath: /var/lib/mysql
         ports:
         - containerPort: 3306
         env:
         - name: MYSQL_USER
           value: <user name>
         - name: MYSQL_PASSWORD
           value: <your password>
         - name: MYSQL_ROOT_PASSWORD
           value: <password of root user>
         - name: MYSQL_DATABASE
           value: testdb
       volumes:
       - name: pvc-mariadb01
         persistentVolumeClaim:
           claimName: pvc-mariadb01
     ```
1. Apply the yaml file.
   ```sh
   # kubectl apply -f pod-mariadb.yml
   ```
1. Run **ls -l** on PV directory and wait **testdb** directory to be created.
   ```sh
   # ls -l
    :
   drwx------. 2 polkitd ssh_keys     4096 Sep 12 13:51 mysql
   drwx------. 2 polkitd ssh_keys       20 Sep 12 13:50 performance_schema
   drwx------. 2 polkitd ssh_keys       64 Sep 12 13:54 testdb
   ```
1. Check if root user can access to MariaDB.
   ```sh
   # kubectrl exec -it mariadb bash
   (On the container)
   # mysql -u root -p
   Enter password:
   Welcome to the MariaDB monitor.  Commands end with ; or \g.
   Your MariaDB connection id is 748
   Server version: 10.4.7-MariaDB-1:10.4.7+maria~bionic mariadb.org binary distribution
   
   Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.
   
   Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.
   
   MariaDB [(none)]> show databases;
   +--------------------+
   | Database           |
   +--------------------+
   | information_schema |
   | mysql              |
   | performance_schema |
   | testdb             |
   +--------------------+
   4 rows in set (0.001 sec)

   MariaDB [(none)]> quit
   Bye
   ```
1. Delete the MariaDB pod.
   ```sh
   # kubectl delete -f pod-mariadb.yml
   ```

### Pull SingleServerSafe Image and Change Parameterss
1. Pull SingleServerSafe image.
   ```sh
   # docker pull expresscluster/sssoncentos4mariadb
   ```
1. Create a container.
   ```sh
   # docker run -it -d --name sssoncentos4mariadb-work -v /root/work/pv/mariadb-sss01/sss/:/opt/nec/clusterpro/etc -p 19003:29003 docker.io/expresscluster/sssoncentos4mariadb bash
   ```
1. Login the container.
   ```sh
   # docker exec -it sssoncentos4mariadb-work bash
   ```
1. Copy the configuration files.
   ```sh
   # cd /opt/nec/clusterpro
   # cp -a etc-temp/* etc/
   ```
1. Run the following shell files.
   ```sh
   # cd /opt/nec/clusterpro/etc/systemd
   # ./clusterpro_evt start
   # ./clusterpro_trn start
   # ./clusterpro_webmgr start
   ```
1. Start web browser and access http://<IP address of container host>:19003 to start Cluster WebUI.
1. Change **Config Mode** and change the following parameters of mysqlw.

   |Parameter      |Value|
   |---------------|-----|
   |Database Name  |testdb|
   |Port           |3306|
   |User Name      |your user account|
   |Password       |your user password|

1. Stop and remove the container.
   ```sh
   # docker stop sssoncentos4mariadb-work
   # docker rm sssoncentos4mariadb-work
   ```
### Create a Pod
1. Create a yaml file as below.
   - pod-sss4mariadb.yml
     ```yaml
     apiVersion: v1
     kind: Pod
     metadata:
       name: sss4mariadb01
       labels:
         app: sss4mariadb01
     spec:
       shareProcessNamespace: true
       containers:
       - name: mariadb01
         image: mariadb:latest
         imagePullPolicy: Never
         volumeMounts:
         - name: pvc-mariadb01
           mountPath: /var/lib/mysql
         ports:
         - containerPort: 3306
       - name: sss01
         image: sssoncentos4mariadb:latest
         imagePullPolicy: Never
         command: ['/usr/local/bin/docker-entrypoint.sh']
         volumeMounts:
         - name: pvc-sss01
           mountPath: /opt/nec/clusterpro/etc
         ports:
         - containerPort: 29003
       volumes:
       - name: pvc-mariadb01
         persistentVolumeClaim:
           claimName: pvc-mariadb01
       - name: pvc-sss01
         persistentVolumeClaim:
           claimName: pvc-sss01
     ```
1. Apply the yaml file.
   ```sh
   # kubectl apply -f pod-sss4mariadb.yml
   ```
1. Check the SingleServerSafe container is running.
   ```sh
   # kubectl exec -it sss4mariadb01 -c sss01 bash
   # clpstat 
     ========================  CLUSTER STATUS  ===========================
     Cluster : sss4mariadb01
     <server>
      *sss4mariadb01 ...: Online
         lanhb1         : Normal           LAN Heartbeat
     <group>
       failover ........: Online
         current        : sss4mariadb01
         exec           : Online
     <monitor>
       mysqlw           : Normal
    =====================================================================  
   ```
1. Create a yaml file.
   - svc-sss4mariadb01.yml
     ```yaml
     apiVersion: v1
     kind: Service
     metadata:
       name: sss4mariadb01
     spec:
       type: NodePort
       ports:
         - name: mariadb01
           protocol: TCP
           port: 9106
           targetPort: 3306
           nodePort: 30106
         - name: sss01
           protocol: TCP
           port: 9103
           targetPort: 29003
           nodePort: 30103
       selector:
         app: sss4mariadb01     
     ```
1. Check if MariaDB client can access to the database.
   ```sh
   # mysql -u root -p -h <IP address of the container host> -P 30106
   ```
1. Check if web browsr can access to the cluster with http://<IP address of the container host>:30103.