# Design Patterns & Principles Reference

## Table of Contents
1. [SOLID Principles](#solid-principles)
2. [GoF Patterns — Creational](#gof-creational)
3. [GoF Patterns — Structural](#gof-structural)
4. [GoF Patterns — Behavioral](#gof-behavioral)
5. [Clean Architecture](#clean-architecture)
6. [Other Key Principles](#other-key-principles)

---

## SOLID Principles

### SRP — Single Responsibility Principle
クラスを変更する理由は1つだけにする。「誰のために変更するか」で責務を切る（Uncle Bob の "actor" 概念）。

**適用判断**: 1つのクラスに異なるステークホルダーの要求が混在しているとき。
**過剰適用の兆候**: 1メソッドしかないクラスが大量発生。責務の粒度を間違えている。

### OCP — Open/Closed Principle
拡張に開き、修正に閉じる。Strategy や Plugin で振る舞いを差し替え可能にする。

**適用判断**: 同じ switch/if 分岐が複数箇所に出現しているとき。
**過剰適用の兆候**: 全てを interface 化して、実装が1つしかない abstraction が乱立。

### LSP — Liskov Substitution Principle
サブタイプは親の契約を破ってはならない。Square extends Rectangle 問題が典型。

**適用判断**: 継承階層で「この子クラスだけ例外的に振る舞う」が出たとき。
**設計への示唆**: 継承よりコンポジションを優先すべきサイン。

### ISP — Interface Segregation Principle
クライアントが使わないメソッドへの依存を強制しない。

**適用判断**: 実装クラスで `raise NotImplementedError` が頻出するとき。
**設計への示唆**: Fat interface を role-based interface に分割。

### DIP — Dependency Inversion Principle
上位モジュールは下位モジュールに依存しない。両方とも抽象に依存する。

**適用判断**: ビジネスロジックが DB ドライバや外部 API クライアントを直接 import しているとき。
**実装パターン**: Constructor Injection, Abstract Repository, Port/Adapter。

---

## GoF Creational

| Pattern | 一言 | 使いどき | 注意 |
|---------|------|----------|------|
| **Factory Method** | 生成をサブクラスに委譲 | 生成ロジックが条件分岐で膨らむとき | Simple Factory で十分なら Method まで要らない |
| **Abstract Factory** | 関連オブジェクト群をまとめて生成 | DB方言切替、OS別UI等、ファミリー単位の切替 | 製品追加が頻繁だと interface 変更が連鎖する |
| **Builder** | 複雑なオブジェクトの段階的構築 | コンストラクタ引数が5個以上、任意パラメータが多い | Fluent API にしすぎると可読性が落ちることも |
| **Singleton** | インスタンスを1つに制限 | Config, Connection Pool, Logger | テスタビリティの敵。DI で代替できないか常に検討 |
| **Prototype** | 既存オブジェクトのクローンで生成 | 生成コストが高く、バリエーションが微差のとき | Deep copy の罠に注意 |

## GoF Structural

| Pattern | 一言 | 使いどき | 注意 |
|---------|------|----------|------|
| **Adapter** | インターフェース変換 | 既存クラスを新しいインターフェースに合わせたいとき | Anti-Corruption Layer (DDD) と同じ役割 |
| **Facade** | 複雑なサブシステムに簡易インターフェース | 外部ライブラリや複雑な内部モジュールのラッピング | Facade が肥大化したら分割サイン |
| **Decorator** | 動的に責務を追加 | ログ、キャッシュ、認証等の横断的関心事 | Python の @decorator と相性が良い |
| **Proxy** | アクセス制御・遅延初期化 | Remote Proxy, Lazy Loading, Access Control | Decorator との違いはライフサイクル管理の有無 |
| **Composite** | 木構造を均一に扱う | ファイルシステム、UI コンポーネントツリー、組織構造 | リーフとノードの振る舞いの差をどう扱うか |
| **Bridge** | 抽象と実装を分離 | 複数軸の変化がある（形状×描画方式等） | 過剰適用しやすい。軸が本当に独立かを確認 |

## GoF Behavioral

| Pattern | 一言 | 使いどき | 注意 |
|---------|------|----------|------|
| **Strategy** | アルゴリズムを差し替え可能に | 同じ処理の複数バリエーション | Python なら関数渡しで十分なケースも多い |
| **Observer** | 状態変化を通知 | イベント駆動、Pub/Sub の基礎 | 循環通知・メモリリーク（弱参照推奨） |
| **Command** | 操作をオブジェクト化 | Undo/Redo、キュー、マクロ記録 | CQRS の C 側の基盤概念 |
| **State** | 状態ごとに振る舞いを変える | ワークフロー、注文ステータス管理 | 状態数が爆発するなら State Machine ライブラリを検討 |
| **Template Method** | 骨格を親で定義、詳細を子で実装 | フレームワークのフック機構 | 継承ベースなので Strategy + 合成 の方が柔軟なことが多い |
| **Chain of Responsibility** | 処理を連鎖させる | ミドルウェア、バリデーション、フィルタ | Express/FastAPI のミドルウェアスタックがこれ |
| **Iterator** | 内部構造を隠して順次アクセス | コレクション抽象化 | Python の `__iter__` / Generator が組み込み対応 |
| **Mediator** | オブジェクト間の直接通信を減らす | チャットルーム、フォームバリデーション連動 | Mediator 自体が God Object になるリスク |

---

## Clean Architecture

### レイヤー構造（内→外）
1. **Entities** — ビジネスルール。外部依存ゼロ
2. **Use Cases** — アプリケーション固有のビジネスルール
3. **Interface Adapters** — Controller, Presenter, Gateway
4. **Frameworks & Drivers** — DB, Web, UI, 外部サービス

### 依存性の方向
常に外→内。内側のレイヤーは外側のレイヤーを知らない。

### Dependency Rule の実装
- Use Case が Repository interface を定義（Port）
- Infrastructure 層が Repository を実装（Adapter）
- DI Container or Manual Injection で接続

### 適用判断
- ビジネスロジックのテストに DB や Web フレームワークの起動が必要 → 依存方向が逆転している
- 「フレームワークを変えたらビジネスロジックも書き直し」 → 結合度が高すぎる

### 過剰適用の兆候
- CRUD しかないのに4層全部作っている
- Use Case が Repository を呼ぶだけの Pass-through になっている
- 全エンティティに対して機械的に同じ層構造を作っている

---

## Other Key Principles

### DRY — Don't Repeat Yourself
知識の重複を排除。ただし「似ているコード」と「同じ知識」は違う。
**WET (Write Everything Twice)** の方が良いケースもある：早すぎる抽象化を避ける Rule of Three。

### KISS — Keep It Simple, Stupid
最もシンプルな解法を選ぶ。「将来必要になるかも」は YAGNI で切る。

### YAGNI — You Ain't Gonna Need It
今必要ない機能は作らない。拡張ポイントも「今」根拠がなければ作らない。

### Tell, Don't Ask
オブジェクトにデータを聞いて外で判断するのではなく、オブジェクトに振る舞いを委譲する。

### Composition over Inheritance
継承は「is-a」関係が自明なときだけ。それ以外はコンポジションで柔軟性を確保。

### Law of Demeter (Principle of Least Knowledge)
`a.b.c.d.doSomething()` はやめる。直接の友人とだけ話す。
Train Wreck を避ける。ただし Fluent API や Builder は例外。

### Separation of Concerns
異なる関心事を異なるモジュールに分離。
横断的関心事（ログ、認証、キャッシュ）は AOP or Decorator パターンで処理。

### Principle of Least Astonishment
API やインターフェースは、ユーザーが最も驚かない振る舞いをすべき。
命名、デフォルト値、エラー処理すべてに適用。
