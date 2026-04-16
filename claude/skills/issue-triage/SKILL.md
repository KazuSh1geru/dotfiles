---
name: issue-triage
description: Use when open issues have accumulated, after task decomposition changes, or when the user says "棚卸し" "整理して" "不要なissueある？" "クリーンアップ". Also use periodically before sprint planning or after closing a parent issue.
---

# Issue Triage

GitHub Issue の棚卸し。重複・孤児・陳腐化したIssueを検出してクローズ提案する。

## When to Use

- 「棚卸し」「issueを整理して」「不要なissueある？」
- 親Issueをクローズした直後（孤児サブIssue発生リスク）
- タスク分解をやり直した後（旧分解の残骸）
- open Issue が 20件を超えたとき

## Core Pattern: 3パススキャン

1パスだけだと孤児を見逃す。**必ず3パス回す。**

### Pass 1: 全体リスト取得

```bash
gh issue list --state open --json number,title,labels,body --limit 100
```

全open Issueを取得し、以下を抽出:
- Issue番号・タイトル
- ラベル（`decomposed`, `auto implement` 等）
- body内の「親 Issue」「依存」リンク

### Pass 2: 関係グラフ構築 + 分類

各Issueを以下の5カテゴリに分類:

| カテゴリ | 判定基準 | アクション |
|---------|---------|----------|
| **active** | 親がopen、依存先が未完了、または独立Issue | 残す |
| **duplicate** | 同一タイトル or 同一スコープの別Issue | クローズ（残す側の優先: ラベル付き > ラベルなし、番号が若い > 新しい） |
| **orphan** | 親Issueがclosed **または** 親がクローズ対象（stale等） | クローズ（吸収先を明記） |
| **absorbed** | スコープが別Issueに包含された | クローズ（吸収先を明記） |
| **stale** | 方針変更で無効化、または60日以上放置 | クローズ or ユーザー確認 |

### Pass 3: 孤児の孫Issue検出

Pass 2 でクローズ対象になったIssueの番号で body 検索:

```bash
gh issue list --state open --search "CLOSED_ISSUE_NUMBER in:body"
```

これを**クローズ対象全件**に対して実行。ここで見つかるのが「孫孤児」。

**再帰的に繰り返す**: Pass 3 で新たにクローズ対象が見つかったら、その番号でも検索する。孫→ひ孫→…と、新規検出がゼロになるまで回す。

## クローズ時の必須ルール

1. **reason を付ける**: `--reason completed`（完了）or `--reason "not planned"`（不要）
2. **comment で吸収先を明記**: 「#XXX に吸収」「親 #YYY クローズ済み」
3. **一覧テーブルをユーザーに提示してから実行**: 勝手にクローズしない

提示テーブルの形式:

```
| Issue | タイトル | カテゴリ | 理由 |
|-------|---------|---------|------|
| #123  | ...     | orphan  | 親 #100 クローズ済み |
| #124  | ...     | duplicate | #125 と同一 |
```

## Common Mistakes

| ミス | 対策 |
|------|------|
| 1パスで終わる → 孫孤児を見逃す | 必ず3パス。Pass 3 を省略しない |
| auto-decompose の二重起票を見逃す | タイトルだけでなく body の「親 Issue」リンクも比較 |
| クローズ理由なしで閉じる | `--comment` 必須。後から追えなくなる |
| active な Issue を巻き込む | 分類テーブルをユーザーに見せてから実行 |
