# CLUSTERPRO X SingleServerSafe のデプロイ方法
- CLUSTERPRO X SingleServerSafe を**サイドカー・パターン**でデプロイし、アプリケーションコンテナを監視する方法を紹介します。

## Index
- [概要](#概要)
- [動作確認済みの構成](#動作確認済みの構成)
- [MariaDBを監視する](#MariaDBを監視する)
- [PostgreSQLを監視する](#PostgreSQLを監視する)

## 概要
- SingleServerSafe コンテナはアプリケーションコンテナにアクセスし、応答を監視する。
- SingleServerSafe コンテナはアプリケーションのアクセスエラーやタイムアウトを検知すると、アプリケーションコンテナのプロセスを終了させ、kubernetes に再起動を促す。
- アプリケーションコンテナの再起動後、SingleServerSafe コンテナは監視を再開する。
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

## 動作確認済みの構成
### Kubernetes
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
### アプリケーション
  - MariaDB 10.1, 10.4
  - PostgreSQL 11.3, 11.6
  - EXPRESSCLUSTER X SingleServerSafe 4.1 for Linux

## MariaDBを監視する
### 前提
- データベースコンテナには、SingleServerSafe が監視するためのデータベースが必要です。本手順では、コンテナデプロイ時に監視用のデータベースとユーザを作成します。
- データベースファイルは永続データであるため、データベースコンテナと SingleServerSafe コンテナを StatefulSet としてデプロイし、Pod に PersistentVolume を割り当てます。
- StatefulSet が使用する PersistentVolume、Service は事前に作成しておいてください。

### Secret および ConfigMap の作成
1. データベースの<ルートユーザのパスワード>、<監視ユーザのパスワード>を指定し、データベース認証情報を保持する Secret (name: mariadb-auth) を作成してください。
   ```sh
   # kubectl create secret generic --save-config mariadb-auth \
   --from-literal=root-password=<ルートユーザのパスワード> \
   --from-literal=user-password=<監視ユーザのパスワード>
   ```
1. Secret が作成されたかを確認してください。
   ```sh
   # kubectl get secret/mariadb-auth
   NAME           TYPE     DATA   AGE
   mariadb-auth   Opaque   2      1m
   ```
1. [SingleServerSafe の設定ファイル (sss4mariadb.conf)](https://github.com/EXPRESSCLUSTER/kubernetes/blob/master/config/mariadb/sss4mariadb.conf)をダウンロードしてください。
1. ダウンロードした設定ファイルを指定し、SingleServerSave の設定情報を保持する ConfigMap (name: sss4mariadb) を作成してください。
   ```sh
   # kubectl create configmap --save-config sss4mariadb --from-file=sss4mariadb.conf
   ```
1. ConfigMap が作成されたことを確認してください。
   ```sh
   # kubectl get configmap/sss4mariadb
   NAME          DATA   AGE
   sss4mariadb   1      1m
   ```

### MariaDB および SingleServerSafe のデプロイ
1. [StatefulSet のマニフェストファイル (sample-sts-mariadb-sss.yaml)](https://github.com/EXPRESSCLUSTER/kubernetes/blob/master/yaml/mariadb/sample-sts-mariadb-sss.yaml) をダウンロードし、以下のパラメータを必要に応じて編集してください。MariaDB コンテナと SingleServerSafe コンテナの**監視データベース名**、**監視ユーザ名**は同一の値にしてください。
   - Pod のレプリカ数
     ```yaml
     spec:
       serviceName: mariadb
       replicas: 3            # レプリカの数
     ```
   - MariaDB コンテナの環境変数
     ```yaml
             env:
             - name: MYSQL_ROOT_PASSWORD
               valueFrom:
                 secretKeyRef:
                   name: mariadb-auth
                   key: root-password
             - name: MYSQL_DATABASE
               value: watch               # 監視データベース名
             - name: MYSQL_USER
               value: watcher             # 監視ユーザ名
             - name: MYSQL_PASSWORD
               valueFrom:
                 secretKeyRef:
                   name: mariadb-auth
                   key: user-password
     ```
   - SingleServerSafe コンテナの環境変数
     ```yaml
             env:
             - name: SSS_MAIN_CONTAINER_PROCNAME
               value: mysqld
             - name: SSS_MONITOR_DB_NAME
               value: watch               # 監視データベース名
             - name: SSS_MONITOR_DB_USER
               value: watcher             # 監視ユーザ名
             - name: SSS_MONITOR_DB_PASS
               valueFrom:
                 secretKeyRef:
                   name: mariadb-auth
                   key: user-password
             - name: SSS_MONITOR_DB_PORT
               value: "3306"              # MariaDB の接続先ポート番号
             - name: SSS_MONITOR_PERIOD_SEC
               value: "10"                # 監視インターバル時間(秒)
             - name: SSS_MONITOR_TIMEOUT_SEC
               value: "10"                # 監視タイムアウト時間(秒)
             - name: SSS_MONITOR_RETRY_CNT
               value: "2"                 # 監視リトライ回数
             - name: SSS_MONITOR_INITIAL_DELAY_SEC
               value: "0"                 # 初回監視ディレイ時間(秒)
             - name: SSS_NORECOVERY
               value: "0"                 # 監視エラー時に対象コンテナを終了させない
                                          # (0:終了させる、1:終了させない)
     ```
1. マニフェストを適用し、StatefulSet を作成してください。
   ```sh
   # kubectl apply -f sample-sts-mariadb-sss.yaml
   ```

1. Pod が Running であることを確認してください。
   ```sh
   # kubectl get pod
   NAME            READY   STATUS    RESTARTS   AGE
   mariadb-sss-0   2/2     Running   0          55s
   mariadb-sss-1   2/2     Running   0          39s
   mariadb-sss-2   2/2     Running   0          21s
   ```

1. SingleServerSafe が Online であることを確認してください。
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

### 動作確認
1. MariaDB コンテナで bash を実行してください。
   ```sh
   # kubectl exec -it mariadb-sss-0 -c mariadb bash
   ```
1. mysqld プロセスに SIGSTOP シグナルを送信してください。
   ```sh
   # kill -s SIGSTOP `pgrep mysqld`
   ```
1. SingleServerSafe コンテナが異常を検出し、mysqld プロセスを終了させます。その結果、kubernetes により、MariaDB コンテの再起動が実行されます。
   - SingleServerSafe による mysqld プロセスの終了処理により、MariaDB コンテナが Error になります。
     ```sh
     # kubectl get pod
     NAME            READY   STATUS    RESTARTS   AGE
     mariadb-sss-0   1/2     Error     0          7m54s
     mariadb-sss-1   2/2     Running   0          7m38s
     mariadb-sss-2   2/2     Running   0          7m20s
     ```
   - kubernetes による MariaDB コンテナの再起動により、MariaDB コンテナが Running になります (RESTARTS が +1 されます)。
     ```sh
     # kubectl get pod
     NAME            READY   STATUS    RESTARTS   AGE
     mariadb-sss-0   2/2     Running   1          7m58s
     mariadb-sss-1   2/2     Running   0          7m42s
     mariadb-sss-2   2/2     Running   0          7m24s
     ```

### 監視パラメータの変更
1. マニフェストファイル (yaml) の環境変数の値を変更してください。
1. 変更したマニフェストを適用し、StatefulSet を更新してください。
   ```sh
   # kubectl apply -f sample-sts-mariadb-sss.yaml
   ```
1. ローリングアップデートにより一つずつ Pod が再作成されます。
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

## PostgreSQLを監視する
### 前提

- データベースコンテナには、SingleServerSafe が監視するためのデータベースが必要です。本手順では、コンテナデプロイ時に監視用のデータベースを作成します。監視用のユーザには、PostgreSQLのルートユーザ(postgres)を使用します。
- データベースファイルは永続データであるため、データベースコンテナと SingleServerSafe コンテナを StatefulSet としてデプロイし、Pod に PersistentVolume を割り当てます。
- StatefulSet が使用する PersistentVolume、Service は事前に作成しておいてください。

### Secret および ConfigMap の作成
1. データベースの<ルートユーザのパスワード>を指定し、データベース認証情報を保持する Secret (name: postgres-auth) を作成してください。
   ```sh
   # kubectl create secret generic --save-config postgres-auth \
   --from-literal=root-password=<ルートユーザのパスワード>
   ```
1. Secret が作成されたかを確認してください。
   ```sh
   # kubectl get secret/postgres-auth
   NAME            TYPE     DATA   AGE
   postgres-auth   Opaque   1      64s
   ```
1. [SingleServerSafe の設定ファイル (sss4postgres.conf)](https://github.com/EXPRESSCLUSTER/kubernetes/blob/master/config/postgres/sss4postgres.conf) をダウンロードしてください。
1. ダウンロードした設定ファイルを指定し、SingleServerSave の設定情報を保持する ConfigMap (name: sss4postgres) を作成してください。
   ```sh
   # kubectl create configmap --save-config sss4postgres --from-file=sss4postgres.conf
   ```
1. ConfigMap が作成されたことを確認してください。
   ```sh
   # kubectl get configmap/sss4postgres
   NAME           DATA   AGE
   sss4postgres   1      11s
   ```

### PostgreSQL および SingleServerSafe のデプロイ
1. [StatefulSet のマニフェストファイル (sample-sts-postgres-sss.yaml)](https://github.com/EXPRESSCLUSTER/kubernetes/blob/master/yaml/postgres/sample-sts-postgres-sss.yaml) をダウンロードし、以下のパラメータを必要に応じて編集してください。MariaDB コンテナと SingleServerSafe コンテナの**監視データベース名**、**監視ユーザ名**は同一の値にしてください。
   - Pod のレプリカ数
     ```yaml
     spec:
       serviceName: postgres
       replicas: 3            # レプリカ数
     ```
   - PostgreSQL コンテナの環境変数
     ```yaml
             env:
             - name: POSTGRES_PASSWORD
               valueFrom:
                 secretKeyRef:
                   name: postgres-auth
                   key: root-password
             - name: POSTGRES_DB
               value: watch               # 監視データベース名
             - name: POSTGRES_USER
               value: postgres            # 監視ユーザ名
     ```
   - SingleServerSafe コンテナの環境変数
     ```yaml
             env:
             - name: SSS_MAIN_CONTAINER_PROCNAME
               value: postgres
             - name: SSS_MONITOR_DB_NAME
               value: watch               # 監視データベース名
             - name: SSS_MONITOR_DB_USER
               value: postgres            # 監視ユーザ名
             - name: SSS_MONITOR_DB_PASS
               valueFrom:
                 secretKeyRef:
                   name: postgres-auth
                   key: root-password
             - name: SSS_MONITOR_DB_PORT
               value: "5432"              # PostgreSQL の接続先ポート番号
             - name: SSS_MONITOR_PERIOD_SEC
               value: "10"                # 監視インターバル時間(秒)
             - name: SSS_MONITOR_TIMEOUT_SEC
               value: "10"                # 監視タイムアウト時間(秒)
             - name: SSS_MONITOR_RETRY_CNT
               value: "2"                 # 監視リトライ回数
             - name: SSS_MONITOR_INITIAL_DELAY_SEC
               value: "0"                 # 初回監視ディレイ時間(秒)
             - name: SSS_NORECOVERY
               value: "0"                 # 監視エラー時に対象コンテナを終了させない
                                          # (0:終了させる、1:終了させない)
     ```

1. マニフェストを適用し、StatefulSet を作成してください。
   ```sh
   # kubectl apply -f sample-sts-postgres-sss.yaml
   ```

1. Pod が Running であることを確認してください。
   ```sh
   # kubectl get pod
   NAME            READY   STATUS    RESTARTS   AGE
   postgres-sss-0   2/2     Running   0          31s
   postgres-sss-1   2/2     Running   0          27s
   postgres-sss-2   2/2     Running   0          23s
   ```

1. SingleServerSafe が Online であることを確認してください。
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

### 動作確認
1. PostgreSQL コンテナで bash を実行してください。
   ```sh
   # kubectl exec -it postgres-sss-0 -c mariadb bash
   ```
1. postgres プロセスに SIGSTOP シグナルを送信してください。
   ```sh
   # kill -s SIGSTOP `pgrep postgres`
   ```
1. SingleServerSafe コンテナが異常を検出し、postgres プロセスを終了させます。その結果、kubernetes により、PostgreSQL コンテの再起動が実行されます。
   - SingleServerSafe による postgres プロセスの終了処理により、PostgreSQL コンテナが Error になります。
     ```sh
     # kubectl get pod
     NAME            READY   STATUS    RESTARTS   AGE
     postgres-sss-0   1/2     Error     0          5m43s
     postgres-sss-1   2/2     Running   0          5m39s
     postgres-sss-2   2/2     Running   0          5m35s
     ```
   - kubernetes による PostgreSQL コンテナの再起動により、PostgreSQL コンテナが Running になります (RESTARTS が +1 されます)。
     ```sh
     # kubectl get pod
     NAME            READY   STATUS    RESTARTS   AGE
     postgres-sss-0   2/2     Running   1          5m46s
     postgres-sss-1   2/2     Running   0          5m42s
     postgres-sss-2   2/2     Running   0          5m38s
     ```

### 監視パラメータの変更
1. マニフェストファイル (yaml) の環境変数の値を変更してください。
1. 変更したマニフェストを適用し、StatefulSet を更新してください。
   ```sh
   # kubectl apply -f sample-sts-postgres-sss.yaml
   ```
1. ローリングアップデートにより一つずつ Pod が再作成されます。
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
