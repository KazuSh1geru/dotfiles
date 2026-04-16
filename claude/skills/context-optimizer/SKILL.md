---
name: context-optimizer
description: Use when /context shows high token usage, rules directory has grown, or periodically (weekly) to audit and reduce auto-loaded context. Triggers on "トークン重い", "コンテキスト最適化", "メモリ解放", "rules 整理".
---

# context-optimizer

Auto-loaded context（`.claude/rules/`、Memory）を監査し、トークン使用量を削減する。

## 2層アーキテクチャ

| 層 | パス | ロード | 用途 |
|---|---|---|---|
| rules | `.claude/rules/` | 常時（全セッション） | トリガー条件 + 参照先スタブ |
| references | `.claude/references/` | オンデマンド（Read時のみ） | 詳細な手順・チェックリスト |

**原則**: rules にはスタブのみ。詳細は references に置く。

## 手順

### Step 1: 計測

```bash
# rules のサイズ一覧（降順）
wc -c .claude/rules/*.md | sort -rn
# references のサイズ一覧
wc -c .claude/references/*.md | sort -rn
# Memory ファイル一覧
ls -la ~/.claude/projects/$(pwd | sed 's|/|-|g' | sed 's/^-//')/memory/
```

### Step 2: 移行候補の特定

**閾値**: rules ファイルが **1,000 bytes 超**かつ**常時適用不要**なら移行候補。

判定マトリクス:

| 条件 | 判定 |
|---|---|
| 全セッションで常時適用する行動規範 | rules に維持 |
| 特定トリガー時のみ必要な詳細手順 | references に移行 |
| 既にポインタのみ（< 500 bytes） | rules に維持 |
| 既に references に同名ファイルがある | rules をスタブ化 |

### Step 3: 参照整合性チェック

移行前に、rules ファイルへの参照を確認する:

```bash
# rules ファイル名で CLAUDE.md、skills、agents を検索
grep -r "rules/ファイル名" CLAUDE.md .claude/skills/ .claude/agents/ 2>/dev/null
```

- 参照があれば、参照元も `.claude/references/` パスに更新する
- CLAUDE.md にルール構成の説明がある場合、2層構成の記述が正しいか確認する

### Step 4: スタブ化

移行対象の rules を以下のパターンでスタブ化する:

```markdown
# タイトル

1行の要約。

**詳細**: `.claude/references/ファイル名.md` を参照。

## 適用タイミング

- トリガー条件1
- トリガー条件2
```

**目安**: スタブは 300-500 bytes。トリガー条件がないとオンデマンド読み込みが発火しない。

### Step 5: メモリ監査

Memory ディレクトリの各ファイルを確認:

- **type: project** で 30日以上前 → 現状と照合し、stale なら削除
- **廃止済み** と明記されたもの → 削除
- MEMORY.md の壊れたリンク → 削除

### Step 6: 検証

```bash
# 移行後の rules 合計サイズ
wc -c .claude/rules/*.md | tail -1
# 各 rules ファイルが閾値以下か
wc -c .claude/rules/*.md | sort -rn | head -5
```

確認項目:
- rules 合計サイズが移行前の 50% 以下
- 1,000 bytes 超の rules が「常時適用の行動規範」のみ
- 移行した references に対応するスタブが rules に存在する
- MEMORY.md に壊れたリンクがない

## やらないこと

- CLAUDE.md 本体の大幅書き換え（別タスク）
- skills/ 内のファイル最適化（スキルは必要時のみロードされるため対象外）
- 内容の改変（移行はサイズ削減のみ。ルールの文言変更は別タスク）
