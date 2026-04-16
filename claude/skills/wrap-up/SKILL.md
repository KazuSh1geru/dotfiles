---
name: wrap-up
description: >
  セッション成果を棚卸しし、Follow-upをissue化してsession-closerにアーカイブを委譲する。
  「wrap-up」「セッション終了」「ログ残して」でトリガー。
  実装・設計判断は管轄外。
---

# Wrap-up

セッション終了時に呼び出し、成果と未解決を棚卸し。Follow-up を GitHub issue に変換し、session-closer にフォワーディングして Obsidian アーカイブを委譲する。

## ワークフロー

```
/wrap-up 呼び出し
  ├─ 1. 会話コンテキスト全体を分析 → 棚卸し（Done / Follow-up）
  │     棚卸し結果を提示 + AskUserQuestion（選択 = 承認 + 行動指示）
  │     Other で修正が入った場合は再提示 → 再度 AskUserQuestion
  │     選択に応じて分岐:
  │       ├─「Follow-up を今片付ける」→ development-partner にフォワーディング（Step 2-3 スキップ）
  │       └─ それ以外 → Step 2-3 を実行
  ├─ 2. Follow-up → GitHub issue 作成（1 Follow-up = 1 issue）
  └─ 3. session-closer を起動（Step 1 で session-closer を含む選択肢が選ばれた場合のみ）
```

**2フェーズ構造**: Step 1 が対話フェーズ（棚卸し結果を提示し AskUserQuestion で選択肢を出す）、Step 2-3 が自動フェーズ。ユーザーが選択肢を選ぶ行為が棚卸し内容の承認と行動指示を兼ねる。

## Step 1: 棚卸し

会話コンテキスト全体を読み、**Done（確定・完了）** と **Follow-up（未解決・次のアクション）** に分離する。

### Done の抽出

```markdown
### ✅ Done（{N}件）

- {意味のある作業単位での成果1}
- {成果2}

> **現在の状態**: {到達点の精密な記述}
```

抽出ヒューリスティック:
- ツール呼び出し履歴（Write, Edit, Bash 等の実行結果）
- スキル使用結果
- 「できた」「完了」「OK」系の発話周辺
- ツール実行の羅列ではなく、意味のある作業単位でまとめる

### Follow-up の抽出

```markdown
### 📋 Follow-up（{N}件）

**[高]** {未解決事項}
> {コンテキスト・背景}

**[中]** {未解決事項}
> {コンテキスト・背景}

**[低]** {未解決事項}
> {コンテキスト・背景}
```

優先度の判定基準:
- **[高]**: ブロッカー。これを解決しないと次に進めない
- **[中]**: 重要だが回避策がある、または次のスコープで対応予定
- **[低]**: nice-to-have。忘れないように記録

抽出ヒューリスティック:
- 明示的な TODO、「次は〜」「あとは〜」「残りは〜」系の発話
- 着手したが完了しなかった作業
- エラー未解決、ブロッカー
- 議論したが結論が出なかった論点
- TaskList に残っている pending/in_progress タスク

### 棚卸し結果の提示と次どうする？

棚卸し結果（Done + Follow-up）をテキスト出力で提示し、直後に AskUserQuestion で選択肢を提示する。

#### 棚卸しテキストの提示フォーマット

```markdown
## 棚卸し — Done {N}件 / Follow-up {N}件（高{n} 中{n} 低{n}）

---

{Done セクション}

---

{Follow-up セクション}
```

サマリーヘッダーでセッション全体の規模感を示し、水平線で Done / Follow-up を視覚的に分離する。Follow-up がない場合は Follow-up セクションを省略し、サマリーヘッダーも `Done {N}件` のみにする。

#### AskUserQuestion で選択肢を提示

棚卸しテキストを出力した直後に AskUserQuestion を呼び出す。

**ユーザーが選択肢を選ぶ行為が、棚卸し内容の承認と行動指示を兼ねる。** 修正したい場合は Other を選んで修正内容を入力する。修正が入った場合は修正版を再提示し、再度 AskUserQuestion で閉じる。ユーザーは Other で以下を修正できる:
- Follow-up の追加・削除・修正（issue にしたくないものは外す）
- Done の追加・削除・修正
- 優先度の変更

**Follow-up あり時:**

```
AskUserQuestion:
  question: "次どうする？"
  header: "次どうする？"
  options:
    - label: "{推奨アクション} (推奨)"
      description: "{推奨の説明}"
    - label: "Follow-up を今片付ける"              ← 固定代替アクションセクション参照
      description: （固定代替アクションテーブルの description を使用）
    - label: "{LLM生成の代替アクション}"             ← 0-1つ
      description: "{文脈の根拠を含む説明}"
  + Other（自動付与）→ 棚卸し内容の修正パス
```

**Follow-up なし時:**

```
AskUserQuestion:
  question: "次どうする？"
  header: "次どうする？"
  options:
    - label: "{推奨アクション} (推奨)"
      description: "{推奨の説明}"
    - label: "{LLM生成の代替アクション1}"            ← 1-2つ
      description: "{文脈の根拠を含む説明}"
  + Other（自動付与）→ 棚卸し内容の修正パス
```

#### 推奨アクションの決定テーブル

実行時の条件に応じて推奨アクションを1つ確定し、`(推奨)` を label に付与する。

| 条件 | label | description |
|------|-------|-------------|
| Follow-up あり + Obsidian MCP 接続済み | issue 化 → session-closer (推奨) | Follow-up {N}件を issue 化し、session-closer でアーカイブ |
| Follow-up あり + Obsidian MCP 未接続 | issue 化して完了 (推奨) | Follow-up {N}件を issue 化して終了（session-closer スキップ） |
| Follow-up なし + Obsidian MCP 接続済み | session-closer でアーカイブ (推奨) | Done の記録を session-closer で Obsidian に保存 |
| Follow-up なし + Obsidian MCP 未接続 | このまま完了 (推奨) | アーカイブせず終了 |

Obsidian MCP の接続状態は ToolSearch probe で判定する。AskUserQuestion 提示前に以下を実行し、結果を選択肢テーブルに反映する:

```
ToolSearch: select:mcp__obsidian__write_note
```

- スキーマが返れば **接続済み**
- ツールが見つからなければ **未接続**

#### 固定代替アクション

Follow-up がある場合、以下を固定の代替選択肢として追加する（Follow-up なしの場合は表示しない）。

| 条件 | label | description |
|------|-------|-------------|
| Follow-up あり | Follow-up を今片付ける | issue 化せず development-partner で Follow-up を構造化→着手 |

この選択肢が選ばれた場合、**Step 2-3 はスキップ**し、Skill tool で development-partner にフォワーディングする。

フォワーディング時の args:

```
Follow-up を片付ける。

## Done（文脈理解用）
{Done セクションの内容}

## Follow-up（着手対象）
{Follow-up セクションの内容（優先度付き）}
```

dp が Follow-up を構造化し、適切なスキルにルーティングする。

#### 代替アクション（LLM生成）

推奨と異なる方向の選択肢を、実行中の文脈から生成する。

- label: 短いアクション名
- description: 文脈の根拠を含む1文

考慮する文脈:
- Follow-up の優先度構成（全部 [低] なら「issue 化せず MEMORY.md メモだけ」が自然）
- セッション中に PR を作成/更新していた場合（「PR の最終確認」が候補に上がる）
- Follow-up がない場合に「Follow-up を追加する」パスを代替として明示

生成数:
- Follow-up あり（固定代替が表示される）→ LLM生成は **1つまで**（合計3選択肢+Other を超えない）
- Follow-up なし（固定代替なし）→ LLM生成は **1-2つ**

ガードレール:
- 推奨と同系統にしない（推奨が issue 化 + アーカイブなら、代替は非 issue 化系）
- 固定代替と同系統にしない（「片付ける」系の代替を LLM 生成で重複させない）
- 文脈の根拠を括弧で添える

## Step 2: GitHub issue 作成

Step 1 で承認された Follow-up の各項目について、1 Follow-up = 1 issue で作成する。

### テンプレート

必須セクション（「問題」「方針」）+ オプショナルセクション（「背景」「検討した選択肢」）の累積構造。オプショナルセクションは会話中に該当する情報がある場合のみ生成する。

```bash
gh issue create --title "{未解決事項}" --body "$(cat <<'EOF'
## 問題

{Follow-up の1行要約を展開した問題記述}

## 方針

{次セッションで取るべきアクション}
推奨スキル: {design-partner / spec-implementer 等}

{--- 以下、会話中に該当する情報がある場合のみ ---}

## 背景

{セッション中の議論経緯}

### 検討した選択肢
- **{案名}**: {概要} → 採用 / 棄却: {理由}

---
Priority: {高/中/低}
関連: #{issue番号}, #{PR番号}
EOF
)"
```

### 各セクションの抽出ガイド

| セクション | 必須/任意 | 抽出元 |
|---|---|---|
| **問題** | 必須 | Follow-up の項目を展開。1行要約ではなく、次セッションで文脈が分かる程度に記述する |
| **方針** | 必須 | 会話末尾の「次は〜」系の発話、フォワーディング提案。推奨スキルがあれば付記する |
| **背景** | 任意 | dp/design-partner での壁打ち経緯、問題の構造化結果、制約・前提の整理 |
| **検討した選択肢** | 任意 | 下記の抽出ヒューリスティック参照 |
| **関連** | 任意 | 会話中で言及された issue/PR 番号 |

### 「検討した選択肢」の抽出ヒューリスティック

以下のいずれかに該当する情報が会話中にある場合にセクションを生成する:

- design-partner の案比較（名前つき案 + 比較表）
- AskUserQuestion の選択肢と選択結果
- dp の「どこから掘る？」で提示された選択肢とユーザーの選択
- idea-breaker の seed 出力
- 明示的な「〇〇は却下」「〇〇はやめた」系の発話

**自然消滅した案（触れたが比較対象に上がらなかった案）は拾わない。** 明示的に検討・棄却されたもののみ扱う。

### 運用ルール

- リポジトリ: 現在の作業ディレクトリの git リポジトリに作成する
- ラベル: 付与しない（リポジトリごとにラベル体系が異なるため）
- issue 作成に失敗した場合: 失敗した項目を CLI 出力で報告する。残りの項目の作成は続行する

## Step 3: session-closer 起動

Step 1 でユーザーが session-closer を含む選択肢を選んだ場合のみ実行する。それ以外の選択肢が選ばれた場合、このステップはスキップする。

Skill tool で session-closer を起動する。引数は不要。session-closer は会話コンテキストから全情報を自力抽出する（承認済みの棚卸し結果、issue URL を含む）。session-closer の完了を待って終了する。

- **wrap-up は Obsidian に直接書き込まない。** アーカイブの整合性保証は session-closer の責務

## ハードルール

- **選択肢の選択なしに issue を作成しない**。必ず棚卸し結果と選択肢を提示し、ユーザーが選択肢を選んでから自動フェーズに進む
- **選択肢の選択なしに自動フェーズへ進まない**。Follow-up の有無にかかわらず、棚卸し結果と選択肢を提示してユーザーの選択を待つ
- **評価・採点しない**。「良いセッションだった」等の価値判断を入れない
- **ユーザーの発話を改変しない**。意思決定の根拠等はユーザーの言葉を尊重する
- **優先度を根拠なく付けない**。未解決事項の優先度はセッション中の発話・文脈から判断する
- **確定していないものを Done に混入させない**。「候補」「検討中」は Follow-up に回す
- **Obsidian に直接書き込まない**。アーカイブは session-closer に委譲する
- **カテゴリ抽出を行わない**。抽出は session-closer の責務

## 成果物の定義

| # | 成果物 | 形式 | 生成ステップ |
|---|---|---|---|
| 1 | 棚卸しテキスト | Markdown（Done + Follow-up） | Step 1 で提示・選択 |
| 2 | GitHub issue | 1 Follow-up = 1 issue | Step 2 で作成（Follow-up がある場合のみ） |
| 3 | session-closer 委譲 | Skill tool 呼び出し | Step 3 で起動（Step 1 で session-closer を含む選択肢が選ばれた場合のみ） |
| 4 | development-partner フォワーディング | Skill tool 呼び出し（args に Done + Follow-up） | Step 1 固定代替選択時のみ |

各成果物のテンプレート・フォーマットは該当 Step を参照。

## 自己評価（応答の最後に必ず実行）

自動フェーズ（Step 2-3）に進む前に以下を検証する。session-closer を起動しないフローでも必ず実行する。問題があれば出力内容を修正してから送信する。

### チェック1: Done / Follow-up の分離

- Done に「候補」「検討中」の事項が混入していないか？
- Follow-up に既に完了した事項が混入していないか？
### チェック2: issue の整合性（Step 2 実行時のみ）

- Step 1 で承認された Follow-up の件数と、Step 2 で作成した issue の件数が一致しているか？
- Step 2 をスキップした場合はこのチェックをスキップする

### チェック3: 推測混入チェック

- 抽出した内容は、すべて会話中の発話・ツール実行結果に根拠があるか？
- 会話に存在しない情報を補完していないか？

### 提示ルール

- 自動フェーズ（Step 2-3）の**直前**に独立セクションとして提示する
- **問題を検出した項目**: 修正内容を明記する
- **問題なしの項目**: 省略
- **全項目問題なし**: 「自己評価: 全チェック通過」の1行のみ
- **分量は1〜3行**を目安

## Tools Required

- `AskUserQuestion`: 棚卸し後の選択肢提示
- `Bash`: issue 作成（`gh issue create`）
- `Skill`: session-closer へのフォワーディング
