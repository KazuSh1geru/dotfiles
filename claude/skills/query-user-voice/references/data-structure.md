# 回答データ構造

## ファイル情報

- **パス**: `research/users/回答データ.csv`
- **DB**: `research/users/voice.duckdb`（テーブル「回答データ」+ ビュー「v_回答」）
- **エンコーディング**: UTF-8
- **特記事項**: 改行を含むフィールドあり

## カラム詳細

### 回答データテーブル

| カラム | 説明 | 例 |
|-------|------|-----|
| company_code | 会社コード | `1002177101` |
| company_name | 企業名 | `株式会社〇〇` |
| user_limits | 契約ユーザー上限（会社規模参考） | `200` |
| report_date | サーベイのレポート日 | `2024-06-20 12:59` |
| answered_at | 回答日時 | `2024-06-15 09:30` |
| attributes | 回答者の属性情報（`/`区切り） | 下記参照 |
| text | 回答テキスト | 自由記述 |
| source | データ種別 | `LM定性設問回答` or `個社定性設問` |
| question_title | 質問タイトル | `職場の雰囲気について` |
| total_answerers | 総回答者数 | `150` |
| valid_answer_count | 有効回答数 | `120` |

### v_回答ビュー（セクターマスター配置時のみ）

| カラム | 説明 | 例 |
|-------|------|-----|
| sector | セクター | - |
| subsector | サブセクター | - |
| industry | 業種 | `各種受託システム開発` |
| contract_status | 契約ステータス | - |

## attributes の構造

`/` 区切りで複数の属性が格納。形式: `属性名:値 / 属性名:値 / ...`

| 属性名 | 値の例 | 説明 |
|-------|-------|------|
| Chapter | Eng Chapter, Biz Chapter | 所属チャプター |
| Squad | チーム名 | 所属スクワッド |
| Tribe | 組織名 | 所属トライブ |
| キャリアレベル | L3, L4, L5 | 職位レベル |
| 入社時期 | 2023年4月～2024年3月入社 | 入社年度 |
| 勤続年数 | 1年未満, 2年以上3年未満, 5年以上 | 在籍期間 |
| 国籍 | Japanese, Indian, Swedish | 国籍 |
| 年齢 | 26歳~30歳, 31歳~35歳, 36歳~40歳 | 年齢層 |
| 役職 | メンバー, マネージャー | 役職 |
| 拠点 | 東京, 大阪, 木場 | 勤務地 |
| 雇用形態 | 正社員, 契約社員 | 雇用形態 |

## サンプルクエリコード

```bash
duckdb -json -readonly research/users/voice.duckdb -c "
SELECT company_code, company_name, user_limits, report_date, attributes, text, industry, source
FROM v_回答
WHERE company_code NOT LIKE '9%'
  AND text IS NOT NULL
  AND length(trim(text)) >= 10
  AND attributes ILIKE '%役職:メンバー%'
  AND (text ILIKE '%評価%')
LIMIT 10;
"
```

## データ除外条件

以下は自動的に除外すべき:

1. **テストデータ**: `company_code` が `9` で始まる
2. **空回答**: `text` が空または10文字未満
3. **無効な回答**: 意味のない短い回答
