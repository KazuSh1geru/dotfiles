# DDD & Event-Driven Architecture Reference

## Table of Contents
1. [DDD Strategic Design](#ddd-strategic-design)
2. [DDD Tactical Patterns](#ddd-tactical-patterns)
3. [Event Sourcing](#event-sourcing)
4. [CQRS](#cqrs)
5. [Saga & Process Manager](#saga--process-manager)
6. [Integration Patterns](#integration-patterns)

---

## DDD Strategic Design

### Bounded Context
最も重要な概念。同じ言葉（例: "Order"）がコンテキストによって意味が異なる。
コンテキスト境界を引く = システムの分割単位を決める。

**境界の引き方**:
- 同じ用語の意味が変わるところ
- 異なるチームが管轄するところ
- 異なるライフサイクル（変更頻度）を持つところ

### Context Map
Bounded Context 間の関係を明示する。

| 関係 | 説明 | 典型例 |
|------|------|--------|
| **Shared Kernel** | 共有コード・モデル | 小規模チームでの共有ライブラリ |
| **Customer-Supplier** | 上流が下流の要求を考慮 | プラットフォーム → アプリ |
| **Conformist** | 下流が上流のモデルにそのまま従う | 外部SaaSのAPIをそのまま使う |
| **Anti-Corruption Layer** | 変換層で外部モデルから自分を守る | レガシー連携時の Adapter |
| **Open Host Service** | 汎用プロトコルで公開 | REST API, GraphQL |
| **Published Language** | 共有スキーマ | Protocol Buffers, JSON Schema |
| **Separate Ways** | 統合しない | コスト > 便益のとき |

### Ubiquitous Language
ドメインエキスパートと開発者が同じ言葉を使う。
コード内のクラス名・メソッド名がそのままドメイン用語であるべき。
「技術的な名前」ではなく「業務的な名前」をつける。

---

## DDD Tactical Patterns

### Entity
同一性（identity）で識別される。属性が全部変わっても同じ Entity。
例: User（IDで識別。名前が変わっても同じUser）。

### Value Object
属性の組み合わせで同一性を判定。不変（immutable）。
例: Money(amount=100, currency="JPY")。同じ値なら同じ VO。
**設計指針**: まず VO にできないか考える。Entity は最小限にする。

### Aggregate
一貫性境界。Aggregate Root を通じてのみ内部を操作する。
**設計指針**:
- 小さく保つ（Vaughn Vernon の "Design Small Aggregates"）
- 他の Aggregate への参照は ID のみ
- 1トランザクション = 1 Aggregate の変更

### Domain Event
「〇〇が起きた」を表現。過去形で命名（OrderPlaced, PaymentCompleted）。
Aggregate の状態変化を外部に伝える手段。
結果整合性（Eventual Consistency）の起点。

### Repository
Aggregate の永続化を抽象化。Collection-oriented か Persistence-oriented かの2流派。
**Collection-oriented**: `add()`, `remove()` — メモリ上のコレクションのように振る舞う
**Persistence-oriented**: `save()` — Unit of Work 的

### Domain Service
Entity にも VO にも属さないドメインロジック。
例: 送金処理（2つの Account Entity にまたがる）。
**注意**: Service に何でも入れると Anemic Domain Model になる。まず Entity/VO に入れられないか考える。

### Factory
複雑な Aggregate の生成ロジックをカプセル化。
Aggregate Root の static method か、独立した Factory クラス。

---

## Event Sourcing

### 基本概念
状態を直接保存するのではなく、状態変化のイベント列を保存する。
現在の状態 = イベント列を最初から再生（replay）した結果。

### メリット
- 完全な監査ログ
- 時間遡行クエリ（temporal query）
- 異なるリードモデルの構築が自在

### デメリット・注意点
- イベントスキーマの進化（upcasting）が必要
- Replay のパフォーマンス → Snapshot で緩和
- GDPR 対応（個人情報の削除）が困難 → Crypto Shredding

### Event Store の設計
- Stream = Aggregate 単位
- 楽観ロック: expected version で並行書き込みを検出
- イベントは immutable。過去のイベントは変更しない

---

## CQRS

### Command Query Responsibility Segregation
書き込みモデル（Command）と読み取りモデル（Query）を分離する。

### 分離レベル
1. **コード分離のみ**: 同じDB、同じモデルだが Command/Query のパスを分ける
2. **モデル分離**: Write Model と Read Model を別々に定義。同じDBでも可
3. **DB分離**: Write DB と Read DB を分ける。イベントで同期

### Event Sourcing + CQRS の組み合わせ
- Write 側: Event Store にイベントを追加
- Read 側: イベントを購読して Read Model（Projection）を構築
- Read Model はクエリに最適化した非正規化テーブル

### 適用判断
- 読み書きの負荷特性が大きく異なるとき
- 読み取り用に複数の非正規化ビューが必要なとき
- 単純な CRUD で十分なら CQRS はオーバーキル

---

## Saga & Process Manager

### Saga Pattern
複数の Aggregate / Service にまたがるビジネストランザクションを管理。
分散トランザクション（2PC）の代わりに、補償トランザクション（Compensating Transaction）で一貫性を担保。

### Choreography vs Orchestration

| | Choreography | Orchestration |
|---|---|---|
| **制御** | イベントベースで各サービスが自律的に反応 | 中央の Orchestrator が指揮 |
| **結合度** | 低い | Orchestrator への依存 |
| **可視性** | フロー全体が見えにくい | Orchestrator にフロー定義が集約 |
| **適用** | シンプルなフロー（3-4ステップ） | 複雑なフロー、条件分岐が多い |

### 補償トランザクション
各ステップに「取り消し操作」を定義。
例: 在庫確保 → 決済 → 配送手配。決済失敗時は在庫確保を取り消す。
**べき等性（Idempotency）** が必須。リトライ時に二重処理しない設計。

---

## Integration Patterns

### Anti-Corruption Layer (ACL)
外部システムのモデルをそのまま取り込まない。変換層で自ドメインのモデルに翻訳。
レガシー連携、外部 API 連携で必須。

### Event-Driven Integration
Bounded Context 間をイベントで疎結合に連携。
- **Domain Event**: ドメインの状態変化
- **Integration Event**: BC 間の連携用イベント（Domain Event とは別物にすることが多い）

### 結果整合性 (Eventual Consistency)
Aggregate 間、BC 間は結果整合性が基本。
「強整合性が本当に必要か？」を常に問う。ビジネス的に「数秒遅れてOK」なら結果整合性で十分。
