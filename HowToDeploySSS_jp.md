# CLUSTERPRO X SingleServerSafe のデプロイ方法(編集中)
- CLUSTERPRO X SingleServerSafe を**サイドカー・パターン**でデプロイし、アプリケーションコンテナを監視する方法を紹介します。

## Index
- [概要](#概要)
- [動作確認済みの構成](#動作確認済みの構成)
- [MariaDBを監視する](#MariaDBを監視する)

## 概要
- SingleServerSafe コンテナがデータベースコンテナに接続、SQLを発行し、データベースの応答を監視する。
- SingleServerSafe コンテナはデータベースへのアクセスエラーやタイムアウトを検知すると、データベースコンテナのプロセスを終了させ、kubernetes に再起動を促す。
- データベースコンテナの再起動後、SingleServerSafe コンテナはデータベースの監視を再開する。

  ```
   +--------------------------------+
   | Pod                            |
   | +----------------------------+ |
   | | SingleServerSafe コンテナ  | |
   | +--|-------------------------+ |
   |    | (SQL による監視)          |
   | +--V-------------------------+ |
   | | データベースコンテナ       | |
   | +--------------------+-------+ |
   +----------------------|---------+
                          | (PersistentVolume をマウント)
   +----------------------|---------+
   | PersistentVolume     |         |
   | +--------------------+-------+ |
   | | データベースファイル       | |
   | +----------------------------+ |
   +--------------------------------+
  ```

## 動作確認済みの構成
- Master Node (1 ノード)
- Worker Node (2 ノード)
- CentOS 7.6.1810
- kubernetes v1.15.0
- Docker 18.09.7

## MariaDBを監視する
### 前提
- データベースコンテナには、SingleServerSafe が監視するためのデータベースが必要です。本手順では、コンテナデプロイ時に監視用のデータベースとユーザを作成します。
- データベースファイルは永続データであるため、StatefulSet としてデプロイし、Pod に PersistentVolume を割り当てます。
- StatefulSet が使用する PersistentVolume、Service は事前に作成しておいてください。

### ConfigMap、Secret の作成

1. データベースの<ルートユーザのパスワード>、<監視ユーザのパスワード>を指定し、データベース認証情報を保持する Secret (name: mariadb-auth) を作成。
   ```sh
   # kubectl create secret generic --save-config mariadb-auth \
   --from-literal=root-password=<ルートユーザのパスワード> \
   --from-literal=user-password=<監視ユーザのパスワード>
   ```
1. Secret が作成されたかを確認。
   ```sh
   # kubectl get secret/mariadb-auth
   NAME           TYPE     DATA   AGE
   mariadb-auth   Opaque   2      1m
   ```
1. [SingleServerSafe の設定ファイル(sss4mariadb.conf)](https://github.com/EXPRESSCLUSTER/kubernetes/blob/master/config/mariadb/sss4mariadb.conf)をダウンロードする。
1. ダウンロードした設定ファイルを指定し、SingleServerSave の設定情報を保持する ConfigMap (name: sss4mariadb) を作成する。
   ```sh
   # kubectl create configmap --save-config sss4mariadb --from-file=sss4mariadb.conf
   ```
1. ConfigMap が作成されたかを確認。
   ```sh
   # kubectl get configmap/sss4mariadb
   NAME          DATA   AGE
   sss4mariadb   1      1m
   ```

### MariaDB + SingleServerSafe のデプロイ
1. [StatefulSet のマニフェストファイル(yaml)](https://github.com/EXPRESSCLUSTER/kubernetes/blob/master/yaml/mariadb/sample-sts-mariadb-sss.yaml)をダウンロードし、以下のパラメータを必要に応じて編集。
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
1. マニフェストを適用し、StatefulSet を作成。
   ```sh
   kubectl apply -f sample-sts-mariadb-sss.yaml
   ```

1. Pod が Running であることを確認。
   ```sh
   # kubectl get pod
   NAME            READY   STATUS    RESTARTS   AGE
   mariadb-sss-0   2/2     Running   0          55s
   mariadb-sss-1   2/2     Running   0          39s
   mariadb-sss-2   2/2     Running   0          21s
   ```

1. SingleServerSafe が Online であることを確認。
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
1. MariaDB コンテナで bash を実行。
   ```sh
   # kubectl exec -it mariadb-sss-0 -c mariadb bash
   ```
1. mysqld プロセスに SIGSTOP シグナルを送信。
   ```sh
   # kill -s SIGSTOP `pgrep mysqld`
   ```
1. SingleServerSafe コンテナが異常を検出し、mysqld プロセスを終了させる。その結果、kubernetes による再起動が実行され、MariaDB コンテナが復帰。
   - SingleServerSafe の終了処理により、MariaDB コンテナが Error になる。
     ```sh
     # kubectl get pod
     NAME            READY   STATUS    RESTARTS   AGE
     mariadb-sss-0   1/2     Error     0          7m54s
     mariadb-sss-1   2/2     Running   0          7m38s
     mariadb-sss-2   2/2     Running   0          7m20s
     ```
   - kubernetes の再起動により、MariaDB コンテナが Running になる。(RESTARTS が +1 される)
     ```sh
     # kubectl get pod
     NAME            READY   STATUS    RESTARTS   AGE
     mariadb-sss-0   2/2     Running   1          7m58s
     mariadb-sss-1   2/2     Running   0          7m42s
     mariadb-sss-2   2/2     Running   0          7m24s
     ```

### 監視パラメータを変更するには
1. マニフェストファイル(yaml)の環境変数の値を変更。
1. マニフェストを適用し、StatefulSet を更新。
   ```sh
   kubectl apply -f sample-sts-mariadb-sss.yaml
   ```
1. ローリングアップデートにより一つずつ Pod が再作成される。
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
