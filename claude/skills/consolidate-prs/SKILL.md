---
name: consolidate-prs
description: 親Issueに紐づく複数のPRを1つの統合PRにまとめる。サブIssue・PR特定→統合ブランチ作成→統合PR作成&個別PRクローズの3フェーズで実行。
disable-model-invocation: true
argument-hint: "[親Issue番号]"
---

# consolidate-prs

親Issueに紐づく複数のPRを1つの統合PRにまとめる。

## 前提条件

- 親Issueに紐づくサブIssueがあり、それぞれにOpen PRが存在する
- 各PRのブランチがリモートにpush済みである

## 手順

### Phase 0: リポジトリ特定

現在のリポジトリを動的に取得する。以降の全ての `gh` コマンドで `--repo $REPO` を使用する。

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

### Phase 1: 現状把握

1. `gh issue view $ARGUMENTS --repo $REPO` で親Issueの内容を取得する
2. 親Issueの本文・コメントからサブIssue番号を特定する
3. 各サブIssueに紐づくOpen PRを `gh pr list --repo $REPO --search` で特定する
4. 各PRの変更ファイルを `gh pr view --repo $REPO --json files` で取得する
5. 現状をユーザーに報告する:
   - 親Issue / サブIssueの一覧（状態含む）
   - 関連PRの一覧（番号・タイトル・変更ファイル）
   - ファイル競合の有無（同じファイルを複数PRが変更しているか）

### Phase 2: 統合ブランチの作成

6. リポジトリをクローンする: `gh repo clone $REPO /tmp/consolidate-$ARGUMENTS`
7. 全PRブランチを fetch する
8. `merge/issue-$ARGUMENTS` ブランチを `main` から作成する
9. 各PRブランチを **ストーリーライン順**（親Issueの記載順）にマージする:
   - `git merge origin/<branch> --no-edit`
   - コンフリクトが発生した場合:
     a. コンフリクト内容を確認する
     b. 先にマージ済みのブランチ（統合ブランチ側）の内容を優先する（より詳細・修正済みの内容を持つため）
     c. コンフリクトマーカーが残っていないことを `grep` で確認する
     d. コミットする
10. 全PRブランチのマージ完了後、成果物ファイルの存在を確認する

### Phase 3: 統合PR作成 & 個別PRクローズ

11. 統合ブランチをリモートにpushする
12. 統合PRを `gh pr create --repo $REPO` で作成する。bodyには以下を含める:
    - Summary: 親Issueの概要 + 統合理由
    - 含まれる成果物テーブル（ファイル / 元Issue / 内容）
    - `closes #<親Issue番号>` + 各サブIssueの `closes #<番号>`
13. 個別PRをすべてクローズする（`gh pr close --repo $REPO --comment "統合PR #<番号> に統合済み"`）
14. 結果を報告する:
    - 統合PR URL
    - クローズした個別PR一覧
    - closes対象のIssue一覧

## コンフリクト解決の方針

- **同一ファイルを複数PRが変更している場合**: 先にマージしたブランチ（より基盤的な内容）を優先しつつ、後のブランチの追加内容を取り込む
- **判断に迷う場合**: ユーザーに確認する（自動で解決しない）
- **解決後**: コンフリクトマーカー（`<<<<<<<`, `=======`, `>>>>>>>`）が残っていないことを必ず検証する

## 注意

- 統合ブランチの作成は `/tmp/` 配下の一時クローンで行う（作業ディレクトリを汚さない）
- マージ順は親Issueのストーリーライン（サブIssue記載順）に従う
- 作業完了後、一時クローンの後片付けは不要（`/tmp/` は自動クリーンアップされる）
