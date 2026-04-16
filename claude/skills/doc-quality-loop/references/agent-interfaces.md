# Agent 間データフォーマット定義

doc-quality-loop の各 Agent 間で受け渡すデータの構造を定義する。

## 1. Generator → Reviewers

Generator が出力するドラフトのフォーマット。ドキュメント本文にメタデータを付与する。

### メタデータ

```markdown
---
doc_type: article / spec / general
loop_iteration: N
previous_feedback_addressed:
  - FB-B-1: （対応内容の要約）
  - FB-C-2: （対応内容の要約）
  - FB-S-1: （対応内容の要約）
  - FB-T-1: （対応内容の要約）
target_audience: （対象読者の定義）
purpose: （ドキュメントの目的）
format: zenn / qiita / n/a
---
```

### ドラフト本体

```markdown
## はじめに / 概要
（目的と対象読者を明示）

## セクション1: （見出し）
（本文。前方参照なし。セクション内で自己完結）

## セクション2: （見出し）
（本文）

## セクション3: （見出し）
（本文）

## まとめ / 結論
（アクションまたは結論を明確に提示）
```

### 品質チェックリスト（Generator が自己チェック用）

出力前に以下を確認する:

- [ ] `## ` 見出しが3つ以上ある
- [ ] 「後述する」「次の章で」がない
- [ ] 「適切に」「十分に」「概ね」がない
- [ ] 「推進する」「強化する」「図る」がない
- [ ] 目的と対象読者が冒頭で明示されている
- [ ] 結論またはアクションが明確

#### article 追加チェック
- [ ] `# ` (h1) を使っていない
- [ ] 画像パスが `/images/` で始まっている（画像がある場合）
- [ ] 「〜した人は少ない」「〜を知らない人が多い」がない
- [ ] コマンド、手順、コード例のいずれかが1つ以上ある

#### spec 追加チェック
- [ ] 要件→タスクのトレーサビリティがある
- [ ] 完了条件が検証可能（数値・条件で定義）
- [ ] In Scope / Out of Scope が定義されている
- [ ] 前提条件・制約が明示されている

## 2. Reviewers → Integrator

各 Reviewer が出力するフィードバックのフォーマット。

```markdown
## ペルソナフィードバック（自由記述）

（ペルソナの視点からの総合的なフィードバック。
良い点・気になる点・問いかけを含む。）

## スコアカード判定

### MUST 判定
| ID | 判定 | 根拠 | 該当箇所 |
|---|---|---|---|
| M1 | PASS/FAIL | （具体的な根拠） | （ドラフト内の該当箇所を引用） |
| M2 | PASS/FAIL | （具体的な根拠） | （該当箇所） |
| M3 | PASS/FAIL | （具体的な根拠） | （該当箇所） |
| M4 | PASS/FAIL | （具体的な根拠） | （該当箇所） |
| M5 | PASS/FAIL | （具体的な根拠） | （該当箇所） |

### WANT 判定
| ID | 判定 | 根拠 | 該当箇所 |
|---|---|---|---|
| W1 | YES/NO | （具体的な根拠） | （該当箇所） |
| W2 | YES/NO | （具体的な根拠） | （該当箇所） |
| W3 | YES/NO | （具体的な根拠） | （該当箇所） |
| W4 | YES/NO | （具体的な根拠） | （該当箇所） |
| W5 | YES/NO | （具体的な根拠） | （該当箇所） |

## 改善指示

| 指示ID | 対象 | 種別 | 改善内容 |
|---|---|---|---|
| FB-{X}-1 | （対象セクション/箇所） | MUST/WANT | （具体的な改善指示） |
| FB-{X}-2 | （対象セクション/箇所） | MUST/WANT | （改善指示） |
```

### 指示IDの命名規則
- 初心者 Reviewer: `FB-B-N`（B = Beginner）
- 批判的読者 Reviewer: `FB-C-N`（C = Critical）
- Spec Reviewer: `FB-S-N`（S = Spec）
- ターゲット読者 Reviewer: `FB-T-N`（T = Target）
- N は各レビュー内で1から連番

### 改善指示の実行種別タグ

改善内容の先頭に以下のタグを付与する:
- タグなし（デフォルト）: Generator が対応する通常の改善
- `[ADD_BY_AUTHOR]`: 著者の体験・固有データなど、Generator が創作してはいけない情報。Generator はプレースホルダー（TODO コメント）を挿入する

## 3. Integrator → Generator

Integrator が2人のレビューを統合して Generator に渡すフォーマット。

```markdown
## 統合判定結果

### doc_type: {article|spec|general}

### MUST 統合（厳しい側: どちらか一方が FAIL なら FAIL）
| ID | Reviewer A | Reviewer B | 統合 | 理由 |
|---|---|---|---|---|
| M1 | PASS/FAIL | PASS/FAIL | PASS/FAIL | （統合の根拠） |
| M2 | PASS/FAIL | PASS/FAIL | PASS/FAIL | （根拠） |
| M3 | PASS/FAIL | PASS/FAIL | PASS/FAIL | （根拠） |
| M4 | PASS/FAIL | PASS/FAIL | PASS/FAIL | （根拠） |
| M5 | PASS/FAIL | PASS/FAIL | PASS/FAIL | （根拠） |

### WANT 統合（寛容側: どちらか一方が YES なら YES）
| ID | Reviewer A | Reviewer B | 統合 |
|---|---|---|---|
| W1 | YES/NO | YES/NO | YES/NO |
| W2 | YES/NO | YES/NO | YES/NO |
| W3 | YES/NO | YES/NO | YES/NO |
| W4 | YES/NO | YES/NO | YES/NO |
| W5 | YES/NO | YES/NO | YES/NO |

### 収束判定
- MUST 全PASS: YES/NO
- ループ回数: N/5
- WANT YES数: N/5
- **判定**: 続行 / 完了 / 打ち切り

## 交差点（2人共通の指摘）

- （共通指摘1: FB-{X}-N と FB-C-M が同じ問題を指している）
- （共通指摘2）

## 優先順位付き改善指示

### 最優先（MUST FAIL）
1. （統合された改善指示。元の指示ID: FB-{X}-N, FB-C-M）
2. （改善指示）

### 推奨（WANT 改善）
1. （改善指示）
2. （改善指示）

### 連続FAIL警告（該当する場合のみ）
- MN が3回連続FAIL: 以下の具体的修正文案を参考にしてください
  - （具体的な書き換え案）
```
