# Distributed Systems Design Reference

## Table of Contents
1. [Fundamental Theorems & Trade-offs](#fundamental-theorems--trade-offs)
2. [Consistency Patterns](#consistency-patterns)
3. [Data Partitioning & Replication](#data-partitioning--replication)
4. [Communication Patterns](#communication-patterns)
5. [Reliability Patterns](#reliability-patterns)
6. [Scalability Patterns](#scalability-patterns)

---

## Fundamental Theorems & Trade-offs

### CAP Theorem
分散システムは Consistency, Availability, Partition Tolerance の3つのうち2つしか同時に保証できない。
ネットワーク分断は必ず起きる（P は実質必須）ので、実際は **CP か AP** の選択。

- **CP**: 一貫性優先。分断時は一部リクエストを拒否。例: ZooKeeper, etcd, HBase
- **AP**: 可用性優先。分断時も応答するが古いデータを返す可能性。例: Cassandra, DynamoDB

**実務での考え方**: 「全体で CP/AP」ではなく、データの種類ごとに使い分ける。在庫数は CP、商品レビューは AP、のように。

### PACELC Theorem
CAP の拡張。Partition 時は A/C のトレードオフ、Else（正常時）は Latency/Consistency のトレードオフ。
正常時でも「低レイテンシか一貫性か」の判断が必要。

### BASE vs ACID
- **ACID**: Atomicity, Consistency, Isolation, Durability — RDB のトランザクション
- **BASE**: Basically Available, Soft state, Eventual consistency — 分散システムの現実的モデル

---

## Consistency Patterns

### Strong Consistency
書き込み後、全てのリーダーが最新値を返す。
実装: 2PC, Raft/Paxos ベースのコンセンサス。
コスト: レイテンシ・可用性を犠牲にする。

### Eventual Consistency
書き込み後、時間が経てばいつかは全リーダーが最新値を返す。
実装: 非同期レプリケーション、イベント伝播。
注意: 「いつか」の定義が曖昧。SLA で上限を決めるべき。

### Causal Consistency
因果関係のある操作は順序が保証される。因果関係のない操作は順序不定。
Strong と Eventual の中間。実用的なバランスが良い。

### Read Your Own Writes
自分が書いた内容は直後に読める。他人の書き込みは遅延あり。
実装: 書き込み後は Primary から読む、Session Consistency。

---

## Data Partitioning & Replication

### Partitioning (Sharding)

| 方式 | 仕組み | 長所 | 短所 |
|------|--------|------|------|
| **Hash** | key のハッシュで分散 | 均等分散 | Range query が困難 |
| **Range** | key の範囲で分割 | Range query が効率的 | ホットスポットのリスク |
| **Consistent Hashing** | リング上にノード配置 | ノード追加・削除時の再配置が最小 | 負荷偏り → Virtual Node で緩和 |

### Replication

| 方式 | 説明 | 典型 |
|------|------|------|
| **Single-Leader** | 1台の Leader が書き込みを受け付け | PostgreSQL Streaming Replication |
| **Multi-Leader** | 複数 Leader。コンフリクト解決が必要 | CockroachDB, マルチリージョン構成 |
| **Leaderless** | 全ノードが読み書き。Quorum で一貫性確保 | Cassandra, DynamoDB |

### Quorum
N ノード中、W ノードに書き込み成功 + R ノードから読み込み。
**W + R > N** なら Strong Consistency を保証。
典型: N=3, W=2, R=2。

---

## Communication Patterns

### Synchronous
- **REST**: リソース指向。HTTP ベース。シンプルだが chatty になりがち
- **gRPC**: Protocol Buffers。高性能、型安全。サービス間通信向き
- **GraphQL**: クライアント主導のクエリ。BFF (Backend for Frontend) 向き

### Asynchronous
- **Message Queue**: Point-to-point。1つのメッセージは1つのコンシューマが処理。例: SQS, RabbitMQ
- **Pub/Sub**: 1つのメッセージを複数のサブスクライバが受信。例: SNS, Kafka Topics
- **Event Streaming**: 順序付きログ。リプレイ可能。例: Kafka, Kinesis

### 選択基準
- リアルタイム応答が必要 → Sync
- 発行者は結果を待たなくてよい → Async
- 1対多の通知 → Pub/Sub
- 順序保証 + 再処理が必要 → Event Streaming
- 負荷の平準化 → Message Queue

---

## Reliability Patterns

### Circuit Breaker
障害が連鎖しないよう、失敗が続くサービスへのリクエストを遮断。
Closed → Open → Half-Open の状態遷移。
実装: resilience4j, Polly, tenacity (Python)。

### Retry with Backoff
一時的障害に対してリトライ。Exponential Backoff + Jitter で雪崩を防ぐ。
**べき等性が前提**。非べき等な操作をリトライすると二重処理。

### Bulkhead
リソースを区画化して障害の影響範囲を限定。
例: スレッドプール分離、コネクションプール分離。
タイタニック号の隔壁が由来。

### Timeout
全ての外部呼び出しにタイムアウトを設定。デフォルトのタイムアウトなし（∞）は事故の元。
接続タイムアウトと読み取りタイムアウトを分けて設定。

### Dead Letter Queue (DLQ)
処理できないメッセージを別キューに退避。
後で原因調査・再処理できるようにする。無限リトライループを防止。

### Idempotency
同じ操作を複数回実行しても結果が同じ。
実装: Idempotency Key（リクエストに一意キーを付与し、処理済みなら結果を返す）。

---

## Scalability Patterns

### Horizontal vs Vertical Scaling
- **Vertical**: マシンスペックを上げる。限界がある
- **Horizontal**: マシン台数を増やす。ステートレス設計が前提

### Stateless Design
サーバーに状態を持たない。セッションは外部ストア（Redis等）に。
ステートレスなら水平スケールが容易。

### CQRS for Read Scaling
読み取り負荷が支配的なら、Read Model を別 DB に持ち、Read Replica を並べる。

### Event-Driven Scaling
非同期処理でピーク負荷を平準化。
プロデューサーとコンシューマを独立にスケール。

### Cache Strategies

| パターン | 説明 | 用途 |
|----------|------|------|
| **Cache-Aside** | アプリが Cache miss 時に DB から取得しキャッシュ | 汎用。最も一般的 |
| **Write-Through** | 書き込み時にキャッシュも同時更新 | 読み取り頻度が高いデータ |
| **Write-Behind** | キャッシュに書き込み、非同期で DB 反映 | 書き込み負荷の平準化 |
| **Read-Through** | キャッシュが DB からの取得を代行 | Cache-Aside の自動化版 |
