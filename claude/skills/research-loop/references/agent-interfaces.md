# Agent 間データフォーマット定義（Research）

research-loop の Agent 間で受け渡すデータの構造を定義する。

## Reviewers → Integrator

各 Reviewer が出力するフィードバックのフォーマット。

```markdown
## ペルソナフィードバック（自由記述）

（ペルソナの視点からの総合的なフィードバック。
良い点・気になる点・問いかけを含む。）

## スコアカード判定

### MUST 判定
| ID | 判定 | 根拠 | 該当箇所 |
|---|---|---|---|
| M1 | PASS/FAIL | （具体的な根拠） | （レポート内の該当箇所を引用） |
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
- Coverage Reviewer: `FB-V-N`（V = coVerage）
- Critical Analyst: `FB-A-N`（A = Analyst）
- N は各レビュー内で1から連番

### 改善指示の種別

- **EDIT**: レポート内の既存テキストの修正 → Generator が対応可能
- **SEARCH**: 追加のWebSearch が必要（検索キーワード候補を付記する）→ Generator が追加調査する
- **ADD_BY_AUTHOR**: 著者しか持っていない情報の追加が必要 → Generator はプレースホルダーを挿入

## Integrator → Generator

Integrator が2人のレビューを統合して Generator に渡すフォーマット。

```markdown
## 統合判定結果

### research_type: {competitor|technology|market|general}

### MUST 統合（厳しい側: どちらか一方が FAIL なら FAIL）
| ID | Coverage | Critical | 統合 | 理由 |
|---|---|---|---|---|
| M1 | PASS/FAIL | PASS/FAIL | PASS/FAIL | （統合の根拠） |
| M2 | PASS/FAIL | PASS/FAIL | PASS/FAIL | （根拠） |
| M3 | PASS/FAIL | PASS/FAIL | PASS/FAIL | （根拠） |
| M4 | PASS/FAIL | PASS/FAIL | PASS/FAIL | （根拠） |
| M5 | PASS/FAIL | PASS/FAIL | PASS/FAIL | （根拠） |

### WANT 統合（寛容側: どちらか一方が YES なら YES）
| ID | Coverage | Critical | 統合 |
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

- （共通指摘1: FB-V-N と FB-A-M が同じ問題を指している）

## 優先順位付き改善指示

### 最優先（MUST FAIL）
1. （統合された改善指示。元の指示ID: FB-V-N, FB-A-M）

### 追加調査指示（SEARCH 種別）
1. （追加調査の指示。検索キーワード候補: 〇〇, △△）

### 推奨（WANT 改善）
1. （改善指示）

### 連続FAIL警告（該当する場合のみ）
- MN が3回連続FAIL: 以下の具体的修正文案を参考にしてください
```
