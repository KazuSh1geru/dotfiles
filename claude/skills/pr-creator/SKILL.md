---
name: pr-creator
description: >
  commit → push → PR 作成/更新のツール型スキル。
  「PR作って」「PRにして」でトリガー。
  spec-implementer の完了時フォワーディングも受け付ける。
  実装・設計判断は呼び出し元の管轄。
---

# PR Creator

## ワークフロー

```
Skill tool args パース
  ├─ 1. args パース（title, upstream_context, issue_number, pr_number）
  ├─ 1.5. 既存 PR 判定 + base branch 取得
  │     ├─ args に pr_number あり → gh pr view で headRefName, baseRefName 取得
  │     └─ args に pr_number なし → gh pr list --head で自動判定
  │           ├─ PR あり → 既存 PR モード（number, headRefName, baseRefName）
  │           └─ PR なし → 新規 PR モード + gh repo view で defaultBranch 取得
  ├─ 2. git reset (unstage only) → git status → 変更ファイル確認 → 個別 git add
  │     └─ 変更なし → 「変更なし」を報告して終了
  ├─ 3. git commit（日本語メッセージ）
  ├─ 4. git diff --stat origin/{base}...HEAD → ファイル一覧取得
  ├─ 5. リモート確認
  │     └─ リモートなし → 「リモート未設定」を報告して終了
  ├─ 6a. 新規 PR モード
  │     ├─ git push -u origin HEAD
  │     ├─ PR body 組み立て → /tmp/pr-creator/{branch}/pr-body.md
  │     ├─ gh pr create --base {base}
  │     └─ 失敗 → ファイルパス案内して終了
  ├─ 6b. 既存 PR モード
  │     ├─ gh pr view → 既存 body 取得
  │     ├─ 既存 body + 新 upstream_context → LLM マージ（pr-creator 自身） → マージ済み upstream_context
  │     ├─ git push origin HEAD:{headRefName}
  │     ├─ マージ済み upstream_context で PR body 組み立て → /tmp/pr-creator/{branch}/pr-body.md
  │     ├─ gh pr edit --body-file
  │     └─ 失敗 → push 済みの旨 + ファイルパス + 手動 gh pr edit 案内して終了
  ├─ 7. 成果物出力
  └─ 8. 次どうする？（推奨 + 代替の2-3択を提示）
```

### Step 1: args パース

Skill tool の args から以下を取得する:

| パラメータ | 必須 | 説明 |
|---|---|---|
| `title` | yes | PR タイトル（1行） |
| `upstream_context` | yes | 自由形式 Markdown。PR body 本文上部に注入 |
| `issue_number` | no | 指定時は `Closes #N` を PR body に含める |
| `pr_number` | no | オーバーライド用。省略時は Step 1.5 で自動判定 |

### Step 1.5: 既存 PR 判定 + base branch 取得

現ブランチに紐づく既存 PR の有無を判定し、同時に base branch を取得する。

**args に pr_number がある場合（オーバーライド）:**

```bash
gh pr view {pr_number} --json number,headRefName,baseRefName
```

取得した `number`, `headRefName`, `baseRefName` を使用する。

**args に pr_number がない場合（自動判定）:**

```bash
gh pr list --head "$(git branch --show-current)" --json number,headRefName,baseRefName --jq '.[0]'
```

- 結果あり → 既存 PR モード。`number`, `headRefName`, `baseRefName` を使用する
- 結果なし → 新規 PR モード。base branch は以下で取得する:

```bash
gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'
```

### Step 2: 変更ファイル確認・ステージング

まず既存のステージングをクリアする。呼び出し元が `git add` 済みの場合でも、pr-creator が責任を持ってステージし直す。

```bash
git reset HEAD     # ステージング解除のみ。working tree の変更は保持する
git status --porcelain
```

- 変更ファイルを確認し、意図しないファイル（テスト生成物、一時ファイル、IDE設定等）を除外する
- 意図したファイルのみ `git add` で個別にステージングする
- **ステージングする変更がない場合、commit せず「変更なし」を報告して終了する**

### Step 3: コミット

```bash
git commit -m "{日本語メッセージ}"
```

- メッセージは title と変更内容から自動生成する
- コミットメッセージは日本語

### Step 4: 実装セクション用ファイル一覧

```bash
git diff --stat origin/{base}...HEAD
```

Step 1.5 で取得した base branch を使用する。PR 全体の変更ファイル一覧を取得する（直前の commit だけでなく、base branch からの全差分）。

取得したファイル一覧を PR body の実装セクションに使用する。

### Step 5: リモート確認

```bash
git remote
```

出力が空ならリモート未設定と判定する。未設定の場合、push と PR 作成をスキップし、成果物に「リモートリポジトリ未設定のためスキップ」と記録して終了する。

### Step 6a: 新規 PR モード

```bash
git push -u origin HEAD
```

`mkdir -p /tmp/pr-creator/{branch}` でディレクトリを作成し、PR body テンプレートで body を組み立て、`/tmp/pr-creator/{branch}/pr-body.md` に書き出す。`{branch}` は現在のブランチ名。

```bash
gh pr create --title "{title}" --base {base} --body-file /tmp/pr-creator/{branch}/pr-body.md
```

### Step 6b: 既存 PR モード

#### 6b-1. 既存 body 取得

```bash
gh pr view {pr_number} --json body --jq '.body'
```

#### 6b-2. upstream_context のマージ

pr-creator 自身が同一ターン内で生成する（subagent は使わない）。

既存 PR body 全文と新しい upstream_context を入力として、この PR 全体が何をしているかを説明する概要（= マージ済み upstream_context）を生成する。

**マージのルール:**

- 既存 body のうち「## 実装」以降のセクションは参照しなくてよい（Step 4 で再生成する）
- 重複する内容は1つにまとめる
- **情報を落とさない**。既存 body にあった情報も新しい upstream_context の情報も両方含める
- 出力はそのまま PR body テンプレートの `{upstream_context}` の位置に入る

#### 6b-3. push

Step 1.5 で取得した `headRefName` に push する。

```bash
git push origin HEAD:{headRefName}
```

#### 6b-4. PR body 組み立て・更新

`mkdir -p /tmp/pr-creator/{branch}` でディレクトリを作成し、マージ済み upstream_context を使って PR body テンプレート（6a/6b 共通）で body を組み立て、`/tmp/pr-creator/{branch}/pr-body.md` に書き出す。`{branch}` は現在のブランチ名。

```bash
gh pr edit {pr_number} --body-file /tmp/pr-creator/{branch}/pr-body.md
```

PR body の更新に失敗した場合、push 済みのコードはリモートに反映されている。成果物に以下を案内する:
- push は成功している旨
- `/tmp/pr-creator/{branch}/pr-body.md` のファイルパス
- 手動で `gh pr edit {pr_number} --body-file /tmp/pr-creator/{branch}/pr-body.md` を実行する案内

### PR body テンプレート（6a / 6b 共通）

```markdown
{issue_number がある場合: Closes #{issue_number}}

{upstream_context}

## 実装

{git diff --stat origin/{base}...HEAD から自動生成。ファイルパスと追加/変更/削除を箇条書き}
```

### Step 7: 成果物出力

以下のフォーマットでテキスト出力する:

```
## pr-creator 結果

- **PR URL**: {URL}（未作成の場合はその旨）
- **ブランチ**: {ブランチ名}
```

失敗時（PR 作成/更新に失敗した場合）は、上記に加えて `/tmp/pr-creator/{branch}/pr-body.md` のパスを案内する。

### Step 8: 次どうする？

成果物を出力した直後に AskUserQuestion で選択肢を提示する。

```
AskUserQuestion:
  question: "PR の次どうする？"
  header: "次どうする？"
  options:
    - label: "/pr-reviewer で検収 (推奨)"
      description: "PR #{pr_number} をレビューして品質チェック"
    - label: "{代替アクション1}"
      description: "{文脈の根拠を含む説明}"
    （- label: "{代替アクション2}"
      description: "{文脈の根拠を含む説明}"）
  + Other（自動付与）
```

#### 推奨アクション

固定: `/pr-reviewer で検収 (推奨)`。label に `(推奨)` を付与する。

#### 代替アクション

推奨と異なる方向の選択肢を、実行中の文脈から1-2つ生成する。

- label: 5語以内のアクション名
- description: 文脈の根拠を含む1文

考慮する文脈:
- diff の規模（小さければ「このまま完了」が自然）
- issue 紐付き（あれば issue ステータス更新の案内）
- 既存 PR 更新（前回レビュー済みなら「差分だけ目視」）

ガードレール:
- 推奨と同系統にしない（推奨がレビュー系なら、代替は非レビュー系）
- 文脈の根拠を括弧で添える

#### フォワーディング

ユーザーがフォワーディングを含む選択肢を選んだら Skill tool で起動する。

```
Skill tool:
  skill: "pr-reviewer"
  args: "{pr_number}"
```

## ハードルール

- `git add -A` は使わない。ファイルを個別にステージングする
- PR 作成/更新に失敗した場合、body を縮小してリトライしない。`/tmp/pr-creator/{branch}/pr-body.md` がディスクに残っているので、成果物にはファイルパスを案内する
- ステージングする変更がない場合（git status が空）、commit せず「変更なし」を報告して終了

## 自己評価（応答の最後に必ず実行）

### チェック1: 意図しないファイルの混入

- git add でステージングしたファイルに、テスト生成物・一時ファイル・IDE設定が含まれていないか
- 問題があれば `git reset HEAD {file}` でアンステージする

### チェック2: PR body の整合性

- upstream_context が PR body に正しく注入されているか
- 実装セクションのファイル一覧が実際の diff と一致しているか
- issue_number がある場合、`Closes #N` が含まれているか
- 既存 PR モード時: 既存 body と新 upstream_context の両方の主要情報がマージ結果に含まれているか

### チェック3: 成果物の完全性

- PR URL（またはスキップ理由）が成果物に含まれているか
- 失敗時: `/tmp/pr-creator/{branch}/pr-body.md` のパスが案内されているか

### 提示ルール

- 問題を検出した項目: 修正内容を明記
- 問題なしの項目: 一行で済ますか省略
- 分量は3〜5行
