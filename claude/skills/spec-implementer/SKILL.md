---
name: spec-implementer
description: >
  TDD + DDD に基づく実装スキル。
  「実装して」「コードを書いて」「TDDで」でトリガー。
  設計判断は design-partner の管轄。
---

# TDD + DDD 実装スキル

## 実装フロー

```
0. モード判定 → 1. タスク理解 → 2. ドメイン分析 → 3. テスト設計 (Red) → 4. 最小実装 (Green) → 5. リファクタ (Refactor) → 6. 繰り返し

モード判定:
  spec あり → spec モード（タスク理解で tasks.md を読む）
  spec なし → lightweight モード（タスク理解で会話コンテキストから要件を抽出する）
```

### 0. テスト実行方法の検出（初回のみ）

実装に入る前に、プロジェクトのテスト実行方法を特定する。以下を順に探す:

1. `Makefile` — `make test` 等のターゲットがあるか
2. `pyproject.toml` — `[tool.pytest.ini_options]` や `[tool.hatch]` 等の設定
3. `package.json` — `scripts.test` の定義
4. `Gemfile` — `rspec` / `minitest` 等のテストライブラリ依存
5. `setup.cfg` / `pytest.ini` / `vitest.config.ts` / `jest.config.*` / `.rspec` / `spec/spec_helper.rb`

見つかったコマンドを以降のサイクルで一貫して使う。見つからなければユーザーに確認する。推測で実行しない。

### 1. タスク理解

#### モード判定

以下の順で判定する:

1. ユーザーが spec 名を明示指定 → **spec モード**
2. `.spec-workflow/specs/` に進行中の spec がある（1つ）→ **spec モード**（自動選択し、ユーザーに「{spec名} のタスクを実装する」と伝える）
3. `.spec-workflow/specs/` に進行中の spec がある（複数）→ AskUserQuestion で選択 → **spec モード**
4. 上記いずれにも該当しない → **lightweight モード**

進行中 spec の判定には `mcp__spec-workflow__spec-status` を使い、未完了タスクがある spec を探す。

#### spec モード

- 特定した spec の `tasks.md` を読み、対象タスクの要件を把握する
- **入力と出力**を明確にする。曖昧なまま書き始めない
- 以降、ステップ2（ドメイン分析）に進む

#### lightweight モード

spec なしで実装する。design-partner 等での壁打ち結果が会話コンテキストに残っている前提。

**Step 1: 要件抽出** — 会話コンテキストから以下を抽出し、箇条書きで提示する:

- **ゴール**: 何を作るか（1-2文）
- **入出力**: 関数/API の入力と期待する出力
- **制約・決定事項**: 会話の中で合意した設計判断（技術選定、パターン、境界等）
- **テストシナリオ**: 正常系・異常系・境界値（3-10個）

抽出結果をユーザーに提示し、**過不足がないか確認する**。確認なしで実装に入るのは禁止。

**分量は 5-15 行**を目安。spec-writer のフル4フェーズに相当する構造化はしない。あくまで「テストを書くために最低限必要な情報」を揃える。

確認後、ステップ2（ドメイン分析）に進む。以降のフローは spec モードと共通。

### 2. ドメイン分析

対象タスクに対して、以下を判断する:

| 問い | 判断基準 |
|------|----------|
| Value Object が必要か？ | 同一性ではなく値で比較される概念があるか（金額、メールアドレス、期間、ID等） |
| Entity が必要か？ | ライフサイクルを持ち、IDで識別される概念があるか |
| Repository が必要か？ | 永続化の関心をドメインから分離する必要があるか |
| そもそも DDD パターンが必要か？ | CRUD だけで済むなら素の関数で十分。パターンを強制しない |

**過剰設計チェック:**
- クラスが1つしかメソッドを持たない → 関数で十分
- 抽象クラスの実装が1つしかない → 抽象化不要
- Value Object のバリデーションが `is not None` だけ → 型ヒントで十分
- Repository の中身が1行の ORM 呼び出し → 直接呼べばいい

パターン適用の詳細とコード例 → [references/ddd-patterns.md](references/ddd-patterns.md)

### 3. テスト設計 (Red)

**テストを先に書く。実装コードより先。例外なし。**

```
テスト粒度の判断:
- VO のバリデーション → 単体テスト
- ユースケース全体の振る舞い → 統合テスト（Repository は fake/in-memory）
- 外部API・DB接続 → E2Eテスト or モック（テスト対象に応じて判断）
```

テスト設計の詳細とパターン → [references/tdd-workflow.md](references/tdd-workflow.md)
言語固有のテストパターン → ステップ0で特定した言語に応じて参照:
- Python: [references/tdd-python.md](references/tdd-python.md)
- TypeScript: [references/tdd-typescript.md](references/tdd-typescript.md)
- Ruby: [references/tdd-ruby.md](references/tdd-ruby.md)

**テストを書いたら必ず実行し、失敗（Red）を確認する。** 実行せずに次へ進むのは禁止。
- テストが最初から通ってしまう → テストが何も検証していないか、既に実装済み。見直す
- テストが想定外の理由で落ちる → テストコード自体のバグ。先に直す

### 4. 最小実装 (Green)

- テストが通る最小限のコードを書く
- 美しさは後。まず緑にする
- 型ヒントは最初から入れる（Python）/ 型定義は最初から書く（TypeScript）

**実装を書いたら必ずテストを実行し、成功（Green）を確認する。** 全テストが通るまで次へ進まない。
- 対象テストだけでなく、既存テストも含めて全件通ること
- 新しいテストは通ったが既存テストが壊れた → リグレッション。先に直す

### 5. リファクタ (Refactor)

テストが緑のまま:
- 重複を除去する
- 命名を改善する
- ドメインパターンを適用する（VO への切り出し、Repository への分離等）
- **リファクタのたびにテストを実行する。** 壊れたらリファクタではなく仕様変更。戻してやり直す

### 6. 繰り返し

1つのテストケースごとに Red → Green → Refactor を回す。一度に全部書かない。

#### 進行ルール（自動進行がデフォルト）

テストが Green になったら、ユーザーに確認せず次に進む。これは spec モード・lightweight モード共通。

- **spec モード**: タスクの全テストが Green → 進捗を1行報告し、次のタスクに着手する
- **lightweight モード**: テストケースの Red → Green → Refactor 完了 → 次のテストケースに着手する

**停止条件** — 以下のいずれかに該当したら手を止めてユーザーに報告する:

- Red が3回の修正で Green にならない（auto-green へのフォワーディングを提案）
- タスクの要件に曖昧さがあり、設計判断が必要
- 既存テストのリグレッションが発生し、原因がタスクの要件と矛盾する

```
進捗報告の例:
  ✓ タスク3完了（テスト全通過）→ タスク4に着手
  ✗ タスク4 Red×3 収束せず → auto-green を提案
```

#### 完了時アクション: 次どうする？

全タスクが Green になったら（spec モード: 全タスク完了 / lightweight モード: 全テストケース完了）:

1. 完了サマリを1行報告する
2. AskUserQuestion で選択肢を提示する

```
AskUserQuestion:
  question: "実装完了、次どうする？"
  header: "次どうする？"
  options:
    - label: "{推奨アクション} (推奨)"
      description: "{推奨の説明}"
    - label: "{代替アクション1}"
      description: "{文脈の根拠を含む説明}"
    （- label: "{代替アクション2}"
      description: "{文脈の根拠を含む説明}"）
  + Other（自動付与）
```

##### 推奨アクションの決定テーブル

実行時の条件に応じて推奨アクションを1つ確定し、`(推奨)` を label に付与する。

| 条件 | label | description |
|------|-------|-------------|
| Red×3 で停止したタスクあり | /auto-green で収束 (推奨) | Red×3 のタスクを auto-green で修正 |
| デフォルト | /pr-creator で PR 作成 (推奨) | 実装結果を PR にまとめる |

##### 代替アクション

推奨と異なる方向の選択肢を、実行中の文脈から1-2つ生成する。

- label: 5語以内のアクション名
- description: 文脈の根拠を含む1文

考慮する文脈:
- テスト実装中に感じたカバレッジの不足（具体的な観点を添える）
- 実装中に設計の怪しさを感じた箇所（design-partner へのフォワーディング）
- lightweight モードで要件の曖昧さが残った箇所

ガードレール:
- 推奨と同系統にしない
- 文脈の根拠を括弧で添える
- 「感じた」レベルの曖昧な根拠でも出してよい（ユーザーが判断する）

##### フォワーディング

ユーザーがフォワーディングを含む選択肢を選んだら、以下の args を組み立てて `Skill tool` で起動する。

| arg | spec モード | lightweight モード |
|-----|------------|-------------------|
| `title` | `{prefix}: {spec名}` | `{prefix}: {ゴールの要約（1行）}` |
| `upstream_context` | spec 概要 + 完了タスク一覧（箇条書き） | 要件抽出結果（Step 1 で提示した内容） |
| `issue_number` | spec に紐づく issue があれば付与 | 会話中で言及された issue があれば付与 |

**title prefix の推定**: spec の内容や会話コンテキストから `feat` / `fix` / `refactor` を推定する。「修正」「バグ」→ `fix`、「リファクタ」→ `refactor`、それ以外 → `feat`。提案時に title を表示するので、ユーザーが修正可能。

## テスト実行のルール（ハードルール）

- **各ステップでテストを実行する。** Red で失敗確認、Green で成功確認、Refactor で維持確認。スキップ禁止
- **テストが通らない限り次のステップに進まない。** Red → Green の遷移はテスト実行結果で判定する
- **ステップ0で検出したコマンドを使う。** 実行方法が不明なまま進めない

## ディレクトリ構成の指針

```
src/
├── domain/           # Entity, Value Object, Domain Service
│   ├── models/       # Entity + VO
│   └── repositories/ # Repository インターフェース（Protocol）
├── infrastructure/   # Repository 実装、外部サービスアダプタ
├── application/      # ユースケース（薄く保つ）
└── presentation/     # API エンドポイント、CLI
tests/
├── unit/             # VO, Entity, Domain Service のテスト
├── integration/      # ユースケース + fake Repository のテスト
└── e2e/              # API エンドポイント、外部接続のテスト
```

**注意:** この構成はフル DDD が必要な場合の最大形。小さい機能なら `domain/` と `tests/` だけで十分。既存プロジェクトの構成に合わせることを優先する。

## 判断に迷ったら

- 「このパターン、本当に必要？」→ 必要になるまで入れない（YAGNI）
- 「テストが書きにくい」→ 設計が悪いサイン。依存関係を見直す
- 「Repository 要る？」→ テストで外部依存を差し替えたいなら要る。そうでなければ不要
- 「Value Object にすべき？」→ バリデーションルールがあるか、複数箇所で同じ制約を強制するなら VO にする
