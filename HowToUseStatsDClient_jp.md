# SingleServerSafe コンテナから StatsD でメトリクスを送信する方法
SingleServerSafe コンテナに StatsD クライアント機能を設定し、StatsD サーバへメトリクスを送信する方法を紹介します。

## Index

- [概要](#概要)
  - [サポートするメトリクス](#サポートするメトリクス)
- [動作確認済みの構成](#動作確認済みの構成)
- [StatsDクライアントを設定する](#StatsDクライアントを設定する)

## 概要

- SingleServerSafe コンテナは StatsD クライアントとしてアプリケーションコンテナの監視間隔と同じ間隔で、直近の監視応答時間(ミリ秒)を StatsD サーバへ送信する。
- StatsD サーバは自身の設定に基づいて、クライアントから受け取ったメトリクスデータを収集、集合し、バックエンドのモニタリングツールへ送信する。
  ```
   Kubernetes Cluster
   +--------------------------------+         +---------------------------------+
   | Pod                            |         | Pod (e.g. Amazon CWAgent)       |
   | +----------------------------+ |         |   +-------------------------+   |
   | | SingleServerSafe container +---------------> StatsD server container |   |
   | +--|-------------------------+ | Sending |   +-------|-----------------+   |
   |    | Monitoring                | metric  +-----------|---------------------+
   | +--V-------------------------+ | (UDP)               |
   | | Application (e.g. Database)| |                     |
   | +----------------------------+ |                     | Sending metric
   +--------------------------------+                     |
                                                          |
   - - - - - - - - - - - - - - - - - - - - - - - - - - - -|- - - - - - - - - - -
                                                          |
   Backend                                                |
   +------------------------------------------------------V---------------------+
   | Monitoring tool (e.g. Amazon CloudWatch)                                   |
   +----------------------------------------------------------------------------+
  ```

### サポートするメトリクス

|項目|値|説明|
|:---|:-|:---|
|メトリクス名|clp_monitor_response_time|監視の応答時間|
|メトリクスタイプ|timers|処理の開始から終了までの経過時間(ミリ秒)を扱うメトリクス|
|タグ|Namespace|メトリクス送信元 Pod が所属する名前空間|
||NodeName|メトリクス送信元 Pod が起動するワーカーノード名|
||PodName|メトリクス送信元 Pod 名|
||MonitorName|SingleServerSafe のモニタ名|

## 動作確認済みの構成

### Amazon Web Service

|コンポーネント|ソフトウェア/サービス|
|:-------------|:--------------------|
|Kubernetes クラスタ|Amazon Elastic Kubernetes Service (EKS)|
|StatsD サーバ|Amazon CloudWatch Agent コンテナ(StatsD 有効化)|
||デプロイ方式: Deployment、DaemonSet、サイドカー|
|モニタリングツール|Amazon CloudWatch|

## StatsDクライアントを設定する

### 前提
- 利用するモニタリングツールに応じて、Kubernetes クラスタへ StatsD サーバコンテナをデプロイします。([AWS の場合のデプロイ手順](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-StatsD.html))
<!--
英語URL:https://docs.aws.amazon.com/us_en/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-StatsD.html
-->
- [CLUSTERPRO X SingleServerSafe のデプロイ方法](https://github.com/EXPRESSCLUSTER/kubernetes/blob/master/HowToDeploySSS_jp.md)に従って SingleServerSafe コンテナをデプロイします。

### StatsD クライアント用 ConfigMap の作成

1. [ConfigMap のマニフェストファイル (sample-cm-statsd.yaml)](https://github.com/EXPRESSCLUSTER/kubernetes/blob/master/yaml/statsd-client/sample-cm-statsd.yaml)をダウンロードし、以下のパラメータを必要に応じて編集してください。
   - ConfigMap のパラメータ
     ```yaml
     data:
       STATSD_SERVER: ""
       STATSD_PORT: "8125"
       STATSD_METRICTYPE: "ms"
       STATSD_RATE: "1"
     ```
     |パラメータ|説明|
     |:---------|:---|
     |STATSD_SERVER|StatsD サーバのエンドポイント|
     ||StatsD サーバのコンテナを Deployment 等でデプロイし、Service として公開している場合は Service の名前を指定します。(例: サービス名を `statsd`、名前空間を `hoge` とした場合、`statsd.hoge` を指定します。Service がメトリクス送信元 Pod と同一の名前空間である場合、名前空間は省略できます。)|
     ||StatsD サーバのコンテナを DaemontSet としてデプロイし、ワーカーノードのIPアドレス/ポート番号で公開している場合は、空文字 `""` を指定します。
     ||StatsD サーバのコンテナを メトリクス送信元 Pod のサイドカーとしてデプロイしている場合は、`localhost` を指定します。
     |STATSD_PORT|StatsD サーバの待ち受けポート番号(UDP)|
     ||StatsD サーバ側の設定に合わせて変更してください。|
     |STATSD_METRICTYPE|StatsD サーバに送信するメトリクスのタイプ。変更しないでください。|
     |STATSD_RATE|StatsD サーバに送信するメトリクスのサンプリングレート|
     ||0 から 1 の間の浮動小数点数(0 と 1 を含む)を指定します。バックエンドのモニタリングツールへのデータ送信頻度を軽減したい場合に変更します。|
1. マニフェストを適用し、ConfigMap を作成してください。
   ```sh
   # kubectl apply -f sample-cm-statsd.yaml
   ```
1. ConfigMap が作成されたことを確認してください。
   ```sh
   # kubectl get configmap/statsd-config
   NAME            DATA   AGE
   statsd-config   4      1m
   ```

### SingleServerSafe コンテナの StatsD クライアント機能を有効化

1. SingleServerSafe コンテナをデプロイした StatefulSet のマニフェストファイルを以下の通り編集します。
   - SingleServerSafe コンテナの環境変数
     ```yaml
             env:
             ...snip...
             - name: SSS_USE_STATSD
               value: "false"
             - name: K8S_NAMESPACE
               valueFrom:
                 fieldRef:
                   fieldPath: metadata.namespace
             - name: K8S_NODENAME
               valueFrom:
                 fieldRef:
                   fieldPath: spec.nodeName
             - name: K8S_PODNAME
               valueFrom:
                 fieldRef:
                   fieldPath: metadata.name
             #envFrom:
             #- configMapRef:
             #    name: statsd-config
             ...snip...
     ```
   1. SSS_USE_STATSD の値を "true" へ変更する
      ```yaml
              - name: SSS_USE_STATSD
                value: "true"
      ```
   1. envFrom のコメントアウトを削除する
      ```yaml
              envFrom:
              - configMapRef:
                  name: statsd-config
        ```
1. 編集したマニフェストファイルを適用し、StatefulSet を更新します。
   ```sh
   # kubectl apply -f <manifest file>
   ```
1. StatefulSet 配下の Pod が再作成され、Running 状態になるのを確認します。
   ```sh
   # kubectl get pod
   NAME            READY   STATUS    RESTARTS   AGE
   xxxxxxx-sss-0   2/2     Running   0          55s
   xxxxxxx-sss-1   2/2     Running   0          39s
   xxxxxxx-sss-2   2/2     Running   0          21s
   ```
1. モニタリングツール(または、StatsD サーバ)でメトリクスを受信していることを確認します。
