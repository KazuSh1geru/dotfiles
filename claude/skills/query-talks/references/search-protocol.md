# 議事録検索プロトコル

transcript_markdown/ および meetings/ 内の議事録を検索するための共通アルゴリズム。
query-talks スキルおよび他スキルから参照される。

**検索手段**: transcript_markdown/ は git 未追跡のため、Claude Code の Glob/Grep ツールでは検索できない。すべての検索を Bash コマンド（find/grep）で実行する。

## 検索対象ディレクトリ

### transcript_markdown/（Tactiq自動文字起こし）

| ディレクトリ | 内容 | ファイル数（目安） |
|---|---|---|
| `transcript_markdown/` | メイン（個人・部門横断の会議） | ~130 |
| `transcript_markdown/hokuto/` | 北斗チーム（AI開発定例等） | ~20 |
| `transcript_markdown/DXU/` | DX推進ユニット（朝会・定例等） | ~150 |

### meetings/（手動・プロジェクト固有の会議記録）

> **注**: meetings/ は現リポジトリ（zenn-contents）には存在しない。他リポジトリ（knowledge-vault等）で本プロトコルを参照する場合向けに記述を維持している。

| ディレクトリ | 内容 | ファイル数（目安） |
|---|---|---|
| `meetings/静馬さんmtg/` | MCDX朝会・相談会・リスク管理等 | ~25 |
| `meetings/静馬さんmtg/現場_MTG/` | ENT現場MTGメモ（日付なし多数） | ~135 |
| `meetings/mcdx/` | MCDX朝会・相談会 | ~10 |
| `meetings/相談/` | 1on1・個別相談 | ~6 |

検索は常にすべてのディレクトリを対象にする。

## ファイル名の構造

### transcript_markdown/ のファイル名

```
YYYYMMDD_DD-MM-YYYY [種別マーク] [部門コード] [会議タイトル].md
```

例:
- `20260109_09-01-2026 ○mtg  dev  共有会_RPO~中途採用支援.md`
- `20260116_16-01-2026 ○work  dev  dify ver1.0.1リリース(仮).md`
- `20260403_03-04-2026 ○mtg  dx  MCDX 朝会.md`（DXU/配下）
- `20260114_14-01-2026 北斗 AI開発定例.md`（hokuto/配下）

### meetings/ のファイル名

複数のパターンが混在する:

```
YYYY-MM-DD_タイトル.md          ← 静馬さんmtg/ で主流（ハイフン区切り）
YYYYMMDD_タイトル.md            ← mcdx/ で主流
YYYYMMDD_DD-MM-YYYY [種別] [部門] [タイトル].md  ← 相談/ の一部
0000-00-00_メモ - 「...」.md    ← 現場_MTG/（日付なし、内容検索のみ対象）
```

例:
- `2026-03-17_朝会.md`（静馬さんmtg/）
- `20260403_朝会.md`（mcdx/）
- `20260406_06-04-2026 ○mtg  hrd  1on1（高草木x河野）.md`（相談/）
- `0000-00-00_メモ - 「○mtg__dx__ENT1情報共有」 - コピー.md`（現場_MTG/）

### 共通注意点

- 種別マーク（○, 〇, ◯）は Unicode が異なる3種類が混在する。キーワード検索では丸文字を含めない
- 区切りにダブルスペースが使われるファイルがある。Glob では `*` で吸収する
- 一部の古いファイルは `YYYYMMDD_` プレフィックスがない（例: `06-06-2025 ○mtg ...`）
- `0000-00-00_` プレフィックスのファイルは日付フィルタの対象外。内容検索（Stage 2）でのみヒットする

**部門コード対応表**:

| コード | 意味 | クエリでの言い方 |
|---|---|---|
| dev | 開発部門 | 開発, dev |
| eng | エンジニアリング | エンジニア, eng |
| hrd | 人事 | 人事, HR, hrd |
| org | 組織 | 組織, org |
| dx | DX推進 | DX, DXU |

## 日付解決ルール

クエリ内の日付表現を YYYYMMDD プレフィックスに変換する。
currentDate（今日の日付）はシステムコンテキストから取得する。

### 単一日付

| 表現 | 計算 |
|------|------|
| 今日 | currentDate |
| 昨日 / きのう | currentDate - 1日 |
| おととい / 一昨日 | currentDate - 2日 |
| N日前 | currentDate - N日 |

### 範囲日付

| 表現 | 計算 |
|------|------|
| 今週 | 今週月曜（含む）〜 今日（含む） |
| 先週 | 先週月曜（含む）〜 先週日曜（含む） |
| 今月 | 今月1日〜今日 |
| 先月 | 先月1日〜先月末日 |
| N週間前 | (currentDate - N*7日)の週の月曜〜日曜 |
| 最近 / 直近 | 直近7日 |

### 明示日付

| 表現 | 計算 |
|------|------|
| 〇月〇日 | 当年のその日付。未来日なら前年 |
| 〇/〇 | 同上 |
| YYYY年MM月DD日 | そのまま |

### 日付なし

日付表現がない場合は直近30日を対象にする。

### 解釈の明示

変換結果は必ず出力に含める（ユーザーが検算できるように）:

```
**解釈**: 日付=2026-04-05（昨日）
**解釈**: 日付=2026-03-30〜2026-04-05（先週）
```

## 検索ルート判定

クエリ解析の結果から、以下の判定で検索ルートを選択する:

```
クエリに人名が含まれるか？
  ├─ Yes → Route B（内容検索優先）
  └─ No
       ↓
     クエリに日付がなくトピックのみか？
       ├─ Yes → Route B（内容検索優先）
       └─ No → Route A（ファイル名マッチ優先）
```

**Route A**: 日付 + 会議種別/部門コードなど、ファイル名に含まれる情報だけで絞れるクエリ
**Route B**: 人名・トピックなど、ファイル内容を見ないと判定できないクエリ

### Route A: ファイル名マッチ優先

日付 + ファイル名キーワードで高速に絞り込む。人名を含まないクエリ向け。すべて Bash コマンドで実行する。

1. 日付を YYYYMMDD に変換
2. **月プレフィックス find → 日付フィルタ**（日単位の検索は禁止）:

```bash
# transcript_markdown/（YYYYMMDD形式）
find transcript_markdown/ -maxdepth 1 -name "{YYYYMM}*.md" -type f 2>/dev/null
find transcript_markdown/hokuto/ -maxdepth 1 -name "{YYYYMM}*.md" -type f 2>/dev/null
find transcript_markdown/DXU/ -maxdepth 1 -name "{YYYYMM}*.md" -type f 2>/dev/null

# meetings/（YYYYMMDD形式）
find meetings/mcdx/ -maxdepth 1 -name "{YYYYMM}*.md" -type f 2>/dev/null
find meetings/静馬さんmtg/現場_MTG/ -maxdepth 1 -name "{YYYYMM}*.md" -type f 2>/dev/null

# meetings/（YYYY-MM-DD形式 — ハイフン区切り）
find meetings/静馬さんmtg/ -maxdepth 1 -name "{YYYY-MM}-*.md" -type f 2>/dev/null

# meetings/相談/（両形式混在）
find meetings/相談/ -maxdepth 1 -name "{YYYYMM}*.md" -type f 2>/dev/null
find meetings/相談/ -maxdepth 1 -name "{YYYY-MM}-*.md" -type f 2>/dev/null
```

**単一日付でも月プレフィックスを使う**理由: find 回数を一定に保つため。
範囲が月をまたぐ場合（例: 3/30〜4/5）は、両月のプレフィックスで find し結合する。

3. 結果を日付範囲でフィルタ（YYYYMMDD / YYYY-MM-DD 両方認識）
4. ファイル名をキーワードでフィルタ:
   - 会議種別が含まれるか（「1on1」「朝会」「定例」等）
   - 部門コードが含まれるか（「dev」「hrd」等）
   - トピックが含まれるか（「Dify」「採用」等）
5. キーワードフィルタはAND条件。ヒット0件ならOR条件に緩和して再試行
6. それでも0件 → Route B にフォールバック

**存在しないディレクトリの find はエラーにならず0件を返す（`2>/dev/null` で抑制）。スキップ処理は不要。**

### Route B: 内容検索優先

人名・トピックなど、ファイル内容を見ないと判定できないクエリ向け。すべて Bash コマンドで実行する。

1. **まず find で日付範囲のファイル一覧を取得**（キーワードフィルタなし）:
   - Route A と同じ月プレフィックス find を実行
   - 日付がないクエリの場合は直近30日分
   - 結果を日付範囲でフィルタ

2. **取得したファイルに対して grep で人名/トピックをマッチ**:
```bash
grep -rl "{人名}" transcript_markdown/ --include="*.md" 2>/dev/null
grep -rl "{人名}" meetings/ --include="*.md" 2>/dev/null
grep -rl "{トピック}" transcript_markdown/ --include="*.md" 2>/dev/null
grep -rl "{トピック}" meetings/ --include="*.md" 2>/dev/null
```

3. 人名検索のコツ:
   - 出席者セクション（`出席者`, `参加者`）に名前があるかを確認
   - 本文中の発言者名としても検索（`{名前}:` や `{名前}さん`）

4. grep 結果を Step 1 のファイル一覧と突合し、日付範囲内のファイルのみ残す
   - YYYYMMDD 形式と YYYY-MM-DD 形式の両方を認識する
   - `0000-00-00_` プレフィックスのファイルは日付フィルタをスキップ（常にヒット候補に含める）

5. 結果のランキング:
   - 日付降順（新しい順）
   - 複数キーワードにマッチするファイルを優先
   - 最大10件

## フォールバック

1. Stage 1 + Stage 2 でヒット0件の場合:
   - キーワードを緩める（例: 「1on1」→「1on1」OR「面談」OR「MTG」）
   - 日付範囲を広げる（7日→30日）
   - 1回だけリトライ

2. それでも0件: 「該当する議事録が見つかりませんでした」と返す

## 出力フォーマット

```markdown
## 検索結果

**クエリ**: {元のクエリ}
**解釈**: 日付={解決した日付}, 人名={人名}, 種別={会議種別}

### ヒット（N件）

1. `transcript_markdown/{ファイル名}`
   - マッチ: {根拠}（例: ファイル名: 河野, 1on1）

2. `transcript_markdown/DXU/{ファイル名}`
   - マッチ: {根拠}（例: 内容: 出席者に河野を確認）

3. `meetings/静馬さんmtg/{ファイル名}`
   - マッチ: {根拠}（例: ファイル名: 朝会）

4. `meetings/相談/{ファイル名}`
   - マッチ: {根拠}（例: ファイル名: 1on1, 河野）
```

ファイルパスを返す。内容の要約は返さない。
呼び出し元が内容を必要とする場合は、返されたパスを Read する。
