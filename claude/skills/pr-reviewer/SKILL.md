---
name: pr-reviewer
description: >
  PR を diff の内容に応じた観点でレビューし、所見を development-partner に引き継ぐスキル。
  「PRレビューして」「レビューお願い」でトリガー。
---

# PR Reviewer

PR を diff の内容に応じた観点でレビューし、構造化された所見を development-partner に引き継ぐ。

**位置づけ**: deck の生産フロー（development-partner → design-partner → spec-writer → spec-implementer）に対する**検収フロー**の入口。レビュー結果を deck の判断チェーンに接続するのが存在意義。

**関連スキル**:
- `development-partner` → レビュー結果の引き継ぎ先。findings を構造化し、次のアクションを判断する
- `spec-reviewer` → spec ファイルの品質レビュー。サブエージェントとして並列起動する
- `/review` → コード品質レビュー。Claude Code ビルトインの code-review をサブエージェントから Skill tool 経由で呼び出す

---

## ワークフロー

```
1. PR 情報の取得 → 2. diff 分類 → 3. レビュー実行（Task tool）→ 4. 合成 → 5. 出力 + development-partner 起動
```

### Step 1: PR 情報の取得

1. PR 番号を特定する（ユーザー指定 or カレントブランチから自動検出）
2. `gh pr view {number}` で PR メタデータを取得（タイトル、description、author、ブランチ、linked issues）
3. `gh pr diff {number}` で diff を取得
4. diff が大きすぎる場合（目安: 2000行超）、変更ファイル一覧を先に出して主要な変更ファイルを特定する

### Step 2: diff 分類

diff の変更ファイル一覧から、レビュー対象を分類する。

1. **spec ファイルの検出**: `.spec-workflow/specs/` 配下のファイルが含まれているか確認する
   - 含まれている場合 → spec フォルダパスを特定する（例: `.spec-workflow/specs/{name}/`）
   - `has_spec = true`
2. **コードファイルの検出**: `.spec-workflow/` 配下のファイルを除外した上で、残りの変更ファイルがあれば `has_code = true`
3. 分岐を決定する:
   - `has_spec && has_code` → Spec Review + Code Lens 並列
   - `has_spec && !has_code` → Spec Review のみ
   - `!has_spec && has_code` → Code Lens のみ
   - `!has_spec && !has_code` → レビュー対象なし。その旨を出力して終了

### Step 3: レビュー実行（Task tool）

Step 2 の分岐結果に応じて、Task tool でサブエージェントを起動する。

**起動するサブエージェントが複数ある場合は、1メッセージで同時に起動する。順次起動は禁止。**

#### PR Context Summary

PR のコメントと description から、レビュー判断に必要な文脈情報を抽出・要約する。検出層（Spec Review / Code Lens）とは独立した文脈層として機能する。

```
サブエージェント設定:
- subagent_type: "general-purpose"
- model: "sonnet"
- prompt: PR Context Summary プロンプトテンプレート（後述）
- description: "pr-reviewer: PR Context Summary"
- 起動条件: 常に起動する
```

#### Spec Review

spec-reviewer スキルの評価基準に従い、spec ファイル自体の品質をレビューする。

```
サブエージェント設定:
- subagent_type: "general-purpose"
- model: "sonnet"
- prompt: Spec Review プロンプトテンプレート（後述）
- description: "pr-reviewer: Spec Review"
```

#### Code Lens

Codex（OpenAI）経由でコード品質をレビューする。Claude のトークンを節約するため、codex-companion.mjs の task コマンドを直接呼び出す。

```
サブエージェント設定:
- subagent_type: "general-purpose"
- model: "sonnet"
- prompt: Code Lens プロンプトテンプレート（後述）
- description: "pr-reviewer: Code Lens (via Codex)"
```

#### プロンプトテンプレート

subagent に渡す prompt の構造。`{placeholder}` はメイン側が実行時に注入する。

**Spec Review 用:**

```
あなたは pr-reviewer から起動された Spec Review サブエージェントである。
PR の diff に含まれる spec ファイルの品質をレビューする。

## 手順

1. spec-reviewer のスキル定義を読む: Read ツールで `{spec_reviewer_skill_path}` を読み込む
2. spec ファイルを取得する: gh api で PR ブランチから以下のファイルを取得する
   - gh api repos/{owner}/{repo}/contents/{spec_folder_path}/{filename}?ref={pr_branch}
   - 対象: requirements.md, design.md, test-design.md, tasks.md
   - 存在しないファイルは「未作成」として記録する
3. spec-reviewer の「委譲モード（外部起動）」に従ってレビューを実行する:
   - spec_files: 手順2で取得したファイル内容
   - spec_name: {spec_name}
   - diff: 以下の diff テキスト
4. レビューレポートを出力する

## 入力

### PR 情報
{pr_metadata}

### diff
{diff_text}

## ルール
- spec-reviewer SKILL.md の「委譲モード」+ Step 2〜5 に従う
- 出力は spec-reviewer のレビューレポート形式（delta ラベル付き）
- 推測で指摘しない。spec ファイルから読み取れる事実に基づく
```

**Code Lens 用:**

```
あなたは pr-reviewer から起動された Code Lens サブエージェントである。
PR #{pr_number} のコード品質をレビューする。
レビュー処理は Codex（OpenAI）に委譲する。Claude のトークンを節約するため。

## 手順

1. `gh pr diff {pr_number}` を Bash で実行し、diff を取得する
2. diff が 5000行を超える場合、`gh pr diff {pr_number} --name-only` で変更ファイル一覧を取得し、
   主要な変更ファイルに絞って `gh pr diff {pr_number} -- {file1} {file2} ...` で差分を再取得する
3. 取得した diff テキストを `/tmp/pr-review-{pr_number}.txt` に Write ツールで書き出す
4. 以下の Bash コマンドで Codex に直接レビューを依頼する:

```bash
timeout 300 node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" task --effort medium "PR #{pr_number} のコードレビューを行ってください。

diff は /tmp/pr-review-{pr_number}.txt にあります。cat で読んでください。

## レビュー観点
- 正確性: ロジックのバグ、off-by-one、null/undefined の未処理
- セキュリティ: インジェクション、認証・認可の抜け、機密情報の露出
- パフォーマンス: N+1、不要なループ、大量データの非効率処理
- 保守性: 責務の混在、命名の不整合、過度な複雑性
- テスト: テストの抜け、境界値の未検証

## 出力フォーマット
各指摘を以下の形式で出力:

### [重要度: high/medium/low] 指摘タイトル
- ファイル: path/to/file.ext:行番号
- 問題: 何が問題か
- 提案: どう修正すべきか

指摘がない場合は「コードレビューで指摘事項はありません」と出力。"
```

5. Codex の出力をそのまま返す

## フォールバック
- Codex コマンドが終了コード 124（timeout）で終了した場合、「Codex レビューがタイムアウトしました（5分制限）。」と返す
- Codex コマンドがその他のエラーで失敗した場合、stderr の内容をそのまま返す
- CLAUDE_PLUGIN_ROOT 環境変数が未設定の場合、「Codex プラグインが利用できません。」と返す

## ルール
- Skill tool を呼び出さない。Bash で codex-companion.mjs を直接実行する
- Codex の出力を加工しない。そのまま返す
- Codex がエラーになった場合はエラーメッセージをそのまま返す
```

**PR Context Summary 用:**

```
あなたは pr-reviewer から起動された PR Context Summary サブエージェントである。
PR のコメントと description から、レビュー判断に必要な文脈情報を抽出・要約する。

## 手順

1. PR コメントを取得する:
   a. `gh pr view {pr_number} --json body,comments,reviews` で PR レベルのコメント（会話）を取得
   b. `gh api repos/{owner}/{repo}/pulls/{pr_number}/comments` でインラインレビューコメントを取得
   c. コメント総数が **50件超**の場合、直近50件に切り詰め「{total}件中直近50件を取得」と注記する
2. PR description を読み、変更の意図と背景を抽出する
3. linked issues があれば、変更の動機を補足する
4. コメントを以下の4カテゴリに分類する:
   a. 設計判断の記録（「○○は許容」「△△の方針でいく」等の合意）
   b. 未解決の議論（結論が出ていない論点）
   c. コードの補足説明（diff だけでは読み取れない意図）
   d. ノイズ（LGTM、typo指摘、bot/CI 自動コメント）
5. カテゴリ d は除外する
6. 以下の出力フォーマットに従って要約する

## 入力

### PR 番号
{pr_number}

### リポジトリ
{owner}/{repo}

### PR description
{pr_body}

## 出力フォーマット

### 変更の意図
{PR description + linked issues から。なぜこの変更を行うか、1〜3行}

### 既出の設計判断
- {判断}: {理由}（{誰が言ったか}）
（該当なしの場合「なし」）

### 未解決の論点
- {論点}: {誰が問題視、現状どこまで議論が進んでいるか}
（該当なしの場合「なし」）

### 補足コンテキスト
- {diff だけでは読み取れない意図の説明}
（該当なしの場合は省略）

## ルール
- コメントの内容を改変しない。要約は許容するが、意味を変えない
- 設計判断の記録では、誰がその判断を下したかを括弧で付記する
- 推測で補完しない。コメントに書かれていない判断を推定しない
- 「該当なし」は正当な出力。無理にセクションを埋めない
```

### Step 4: 合成

サブエージェントから結果を受信したら、以下を行う:

1. **重複排除** — 両方のレンズを起動した場合、同じ問題を両方が拾っていたら、より本質的な指摘を残す
2. **重要度ソート** — high → medium → low の順
3. **構造化** — 成果物の定義に従って整形

PR Context は findings の合成パイプライン（重複排除・重要度ソート）には流さない。独立セクションとして成果物に載せる。

重要度の基準:

| 重要度 | 基準 |
|--------|------|
| **high** | 本番障害・データ損失・セキュリティ脆弱性に直結。または設計方針の根本的な問題。spec の致命的指摘 |
| **medium** | 運用負荷の増大、将来の保守性低下、テストの抜け。spec の改善推奨指摘 |
| **low** | 可読性、命名、スタイル。spec の軽微指摘 |

### Step 5: 出力 + development-partner 起動

合成結果を成果物の定義に従って出力した後、**自動的に development-partner を起動**して findings の構造化に入る。

development-partner 起動時のフレーム:
- 統合所見に加えて PR Context セクションを渡す
- dp は PR Context（既出の設計判断、未解決の論点）と findings を突き合わせ、自身の構造化プロセスの中で文脈を判断する
- マージ（gh pr merge 等）を推奨・実行しない。マージはユーザーの判断

---

## ハードルール

1. **findings は全て development-partner に引き継ぐ。** spec-writer / spec-implementer / auto-green に直接ルーティングしない。判断は判断層の仕事
2. **起動するレンズは diff の内容で決定する。** spec ファイルがなければ Spec Review を起動しない。コードファイルがなければ Code Lens を起動しない。固定で2本起動しない
3. **推測で指摘しない。** diff とコードベースから読み取れる事実に基づく。推測がある場合は「（要検証）」をつける
4. **PR の diff 全体を読んでからレビューを開始する。** 部分読みで指摘を始めない
5. **レビュー結果の出力後、自動的に development-partner を起動する。** ユーザーに確認を挟まない
6. **サブエージェントにはPR番号と必要最小限の情報だけ渡す。** コードベースの探索はサブエージェント自身が行う
7. **サブエージェントの出力を大幅に書き換えない。** 形式の統一が崩れた場合の最小限の修正のみ。内容の改変・追加・削除は禁止
8. **findings がないのに無理に指摘を作らない。** 問題がなければ「指摘なし」と明記する
9. **レビューコメントを直接 GitHub に投稿しない。** このスキルの成果物はレビューレポートまで。GitHub への投稿はユーザーの判断

---

## 成果物の定義

起動したレンズに応じて動的に構成する。起動しなかったレンズのセクションは出力しない。

```markdown
# PR Review: #{pr_number} {pr_title}

## 概要
{PR の変更内容を 3〜5 行で要約。何を変えて、なぜ変えたか}
{起動したレンズを明記: 「Spec Review + Code Lens」/「Spec Review のみ」/「Code Lens のみ」}

---

## PR Context
{PR Context Summary サブエージェントの出力をそのまま掲載}
{コメントがなく description も空の場合はセクションごと省略}

---

## Spec Review
{spec-reviewer 形式のレビューレポートをそのまま掲載。起動しなかった場合はセクションごと省略}

---

## Code Lens
{/review の出力をそのまま掲載。起動しなかった場合はセクションごと省略}

---

## 統合所見

重要度順:
1. [high] ...
2. [medium] ...
...

findings 総数: {n} 件（high: {x} / medium: {y} / low: {z}）
```

出力後、development-partner を起動して統合所見の構造化に入る。

---

## 自己評価（応答の最後に必ず実行）

レビューレポートを書き終えたら、送信前に以下を検証する。問題があればレポート自体を修正してから送信する。自己評価の結果はレポート末尾に簡潔に提示する。

### チェック1: diff 分類の正確性
- Step 2 の分類が正しいか。spec ファイルとコードファイルの判定に誤りがないか
- 起動したレンズが分類結果と一致しているか

### チェック2: レンズの独立性
- 両方のレンズを起動した場合、findings が重複していないか。重複があれば排除したか

### チェック3: 重要度の妥当性
- high に分類した findings が本当に「本番障害・データ損失・セキュリティ」レベルか。過剰に high をつけていないか
- spec の「致命的」を high に、「改善推奨」を medium にマッピングしているか

### チェック4: 事実ベース
- 推測に基づく指摘が混じっていないか。推測には「（要検証）」がついているか

### 提示ルール

- **問題を検出した項目**: 修正内容を明記する
- **問題なしの項目**: 一行で済ますか省略
- **分量は3〜5行**を目安。レビューレポートの末尾に独立セクションとして置く
