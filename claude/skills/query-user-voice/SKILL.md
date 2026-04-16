---
name: query-user-voice
description: サーベイ・個人回答データの検索。企業名・属性・キーワードで従業員の声を抽出。「ユーザーの声」「回答データ調べて」「〇〇社の回答」「メンバーはどう思ってる」で呼び出す。
allowed-tools: Bash, Read
context: fork
---

# Query User Voice

社員サーベイの回答データから、属性でフィルタリングしてユーザーの生の声を抽出する。
アイデアの検証や課題仮説の裏付けに「ファクト」として引用できる形式で出力。

DuckDB CLI で .duckdb キャッシュを使ってクエリする。Python 不要。初回実行時にCSVから自動ビルド。

## データソース

**統合CSV + マスター2種。** 不足している場合はダウンロード手順を案内する。

### 回答データ: `research/users/回答データ.csv`

| カラム | 説明 |
|-------|------|
| company_code | 会社コード |
| company_name | 企業名 |
| user_limits | ユーザー上限（会社規模の参考） |
| report_date | レポート日 |
| answered_at | 回答日時 |
| attributes | 属性（後述） |
| text | 回答テキスト |
| source | データ種別（'LM定性設問回答' or '個社定性設問'） |
| question_title | 質問タイトル |
| total_answerers | 総回答者数 |
| valid_answer_count | 有効回答数 |

v_回答ビュー経由（セクターマスター配置時のみ）:

| カラム | 説明 |
|-------|------|
| sector | セクター |
| subsector | サブセクター |
| industry | 業種 |
| contract_status | 契約ステータス |

### attributes の構造

`/` 区切りで以下の情報が含まれる:

| 属性 | 例 |
|-----|-----|
| Chapter | Eng Chapter, Biz Chapter |
| Squad | チーム名 |
| Tribe | 組織名 |
| キャリアレベル | L3, L4, L5 |
| 入社時期 | 2023年4月～2024年3月入社 |
| 勤続年数 | 1年未満, 2年以上3年未満 |
| 国籍 | Japanese, Indian, etc |
| 年齢 | 31歳~35歳, 36歳~40歳 |
| 役職 | メンバー, マネージャー |
| 拠点 | 東京, 大阪, etc |
| 雇用形態 | 正社員, 契約社員 |

## 入力

- `$ARGUMENTS`: クエリ条件（自然言語またはフィルタ指定）

### クエリ例

```
/query-user-voice 評価制度について
/query-user-voice マネージャーの声
/query-user-voice 若手社員（勤続3年未満）の不満
/query-user-voice 役職:メンバー キーワード:上司
```

## Workflow

### Step 0: データソース確認 & DBキャッシュ構築

`bash research/users/build-voice-db.sh` を実行する。

- `.duckdb` が存在しない or CSVより古い場合、自動リビルドされる
- 既に最新なら何もしない

**スクリプトがエラー（CSV不足）の場合:**

**CSVがないと分析できない。必ずユーザーにデータ配置を求める。**

AskUserQuestionで以下を表示:

「⚠️ CSVファイルが未配置のため、ユーザーの声を検索できません。
research/users/README.md にダウンロード手順が記載されています。
CSVを配置してから再度実行してください。」

選択肢:
- **README.mdを開く** → `research/users/README.md` を表示してスキルを終了
- **不足のまま続行する** → 存在するファイルのみで検索を実行（結果が不完全になる旨を警告）

**ダウンロード手順:**

> ```bash
> uv run python research/users/fetch-voice-data.py
> ```
>
> `research/users/回答データ.csv` が生成される。

### Step 1: クエリ解析
入力から以下を抽出:
- フィルタ条件（属性の ILIKE パターン）
- キーワード（コメント内検索）
  - **重要**: メインキーワードに加え、関連する同義語・類語を3-5個生成してOR条件にする
  - 例: 「成長機会」→ `成長`, `キャリア`, `スキルアップ`, `育成`, `挑戦`
  - 例: 「上司との関係」→ `上司`, `マネージャー`, `1on1`, `フィードバック`, `指導`
  - 例: 「評価制度への不満」→ `評価`, `査定`, `フィードバック`, `人事考課`, `昇格`
- 件数制限（デフォルト20件）

### Step 2: データ抽出
`duckdb` CLI で v_回答 ビューをクエリ:

```bash
duckdb -json -readonly research/users/voice.duckdb -c "
SELECT company_code, user_limits, report_date, attributes, text, industry
FROM v_回答
WHERE company_code NOT LIKE '9%'
  AND text IS NOT NULL
  AND length(trim(text)) >= 10
  AND (text ILIKE '%評価%' OR text ILIKE '%査定%' OR text ILIKE '%フィードバック%')
LIMIT 20;
"
```

属性フィルタの例:
```bash
duckdb -json -readonly research/users/voice.duckdb -c "
SELECT company_code, user_limits, report_date, attributes, text, industry
FROM v_回答
WHERE company_code NOT LIKE '9%'
  AND text IS NOT NULL
  AND length(trim(text)) >= 10
  AND attributes ILIKE '%役職:メンバー%'
  AND attributes ILIKE '%勤続年数:%3年%'
  AND (text ILIKE '%上司%' OR text ILIKE '%マネージャー%')
LIMIT 20;
"
```

ヒット件数を知りたい場合:
```bash
duckdb -json -readonly research/users/voice.duckdb -c "
SELECT COUNT(*) as total_matched
FROM v_回答
WHERE company_code NOT LIKE '9%'
  AND text IS NOT NULL
  AND length(trim(text)) >= 10
  AND (text ILIKE '%評価%' OR text ILIKE '%査定%');
"
```

### Step 3: 出力整形
JSON結果を以下のフォーマットに整形して出力:

```markdown
## ユーザーの声クエリ結果

### クエリ条件
- **フィルタ**: [適用したフィルタ]
- **キーワード**: [検索キーワード]
- **ヒット件数**: XX件（表示: YY件）

---

### 回答一覧

#### Voice #1
> [コメント本文]

- **属性**: 役職:メンバー / 勤続年数:2年以上3年未満 / 年齢:31歳~35歳
- **業種**: [industry]
- **会社規模**: [user_limits]名規模

---

### 傾向サマリー
- [共通して言及されているテーマ]
- [特徴的な意見]

### 引用用フォーマット
> 「[コメント抜粋]」
> — メンバー, 勤続2年, 30代, IT業界
```

## フィルタ指定方法

### 属性フィルタ（SQL ILIKE）
```sql
attributes ILIKE '%役職:メンバー%'
attributes ILIKE '%役職:マネージャー%'
attributes ILIKE '%勤続年数:%1年未満%'
attributes ILIKE '%勤続年数:%3年%'
attributes ILIKE '%年齢:%20%'
attributes ILIKE '%年齢:%30%'
attributes ILIKE '%キャリアレベル:L3%'
```

### キーワード検索（OR条件）
```sql
text ILIKE '%評価%'
(text ILIKE '%評価%' OR text ILIKE '%査定%' OR text ILIKE '%フィードバック%')
```

## よくあるクエリパターン

### 課題仮説の検証
- 「評価制度への不満」→ `text ILIKE '%評価%'` + `attributes ILIKE '%役職:メンバー%'`
- 「上司との関係」→ `text ILIKE '%上司%' OR text ILIKE '%マネージャー%'`
- 「キャリア成長の不安」→ `text ILIKE '%キャリア%'` + `attributes ILIKE '%勤続年数:%3年未満%'`

### セグメント別の声
- 「若手の声」→ `attributes ILIKE '%年齢:%20%'` または `attributes ILIKE '%勤続年数:%1年未満%'`
- 「ベテランの声」→ `attributes ILIKE '%勤続年数:%5年%'`
- 「マネージャーの声」→ `attributes ILIKE '%役職:マネージャー%'`

## 注意事項

- 統合データにはcompany_nameが含まれるため、外部向け引用時は匿名化すること
- 引用時は個人が特定されない形で使用
- テストデータ（company_codeが9で始まる）は `WHERE company_code NOT LIKE '9%'` で自動除外
- 20,000件以上あるので、必ずフィルタリングして使用
