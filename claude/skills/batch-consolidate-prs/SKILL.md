---
name: batch-consolidate-prs
description: Use when multiple open PRs exist and you want to auto-detect parent issues and consolidate all related PRs at once. No issue number required.
disable-model-invocation: true
---

# batch-consolidate-prs

親Issue番号を指定せずに、全Open PRから親Issue-サブIssue関係を自動検出し、グループごとに統合PRを作成する。

**REQUIRED SUB-SKILL:** consolidate-prs（各グループの統合処理を委譲）

## Phase 1: PR → Issue → 親Issue のマッピング

1. リポジトリを特定する

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

2. 全Open PRを取得する

```bash
gh pr list --repo $REPO --json number,title,body,headRefName --limit 100
```

3. 各PRから関連Issue番号を抽出する
   - PR body の `closes #N` / `fixes #N` / `resolves #N`
   - ブランチ名の `issue-N` / `issue/N` パターン
   - 抽出できないPRは「孤立PR」として報告する

4. 各Issueの親Issueを特定する

```bash
gh issue view <N> --repo $REPO --json body,labels
```

   - Issue body 内の `Parent: #N` / `Part of #N` 記法
   - `decomposed` ラベルが付いた Issue のタスクリスト（`- [ ] #N`）から逆引き
   - 親が見つからない場合はスキップ

5. マッピング結果を表で報告する

```
| 親Issue | サブIssue | PR | ステータス |
|---------|----------|-----|----------|
| #100    | #101     | #201 | open    |
| #100    | #102     | #202 | open    |
| #100    | #103     | -    | (PR なし) |
| -       | -        | #205 | 孤立PR   |
```

## Phase 2: 統合候補の判定

各親Issueグループについて統合可否を判定する。

**統合する条件:**
- グループ内にOpen PRが2件以上ある
- 全サブIssueにPRが存在する（欠損があれば警告を出す）

**スキップする条件:**
- Open PRが1件以下（統合の必要なし）
- 親Issueが `consolidated` ラベルを持つ（統合済み）

判定結果をユーザーに報告し、実行する親Issueを確認する。

```
統合候補:
  ✅ #100 (3 PRs) — 全サブIssueにPRあり
  ⚠️ #200 (2 PRs) — #203 のPRが未作成
  ⏭ #300 (1 PR) — スキップ

実行する親Issueを選んでください（all / 番号指定 / cancel）
```

## Phase 3: バッチ統合実行

選択された親Issueごとに consolidate-prs スキルの Phase 1〜3 を実行する。

実行順序: 依存関係がない限り、番号の小さい親Issueから順に処理する。

各グループの完了後に結果を報告し、次のグループに進む。

## Phase 4: 最終レポート

全グループの処理完了後、サマリを出力する。

```
## 統合結果

| 親Issue | 統合PR | クローズしたPR | ステータス |
|---------|--------|--------------|----------|
| #100    | #301   | #201, #202   | 完了      |
| #200    | #302   | #204, #206   | 完了      |

孤立PR（未統合）: #205
```
