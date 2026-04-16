---
name: research-loop
description: リサーチ（競合調査・技術調査・市場調査）をralph-loopの反復改善ループで品質担保する。調査→批評→追加調査を収束まで自動実行する。
disable-model-invocation: true
---

# research-loop

リサーチ対象（課題仮説/ソリューション仮説/プロダクトアイデア/技術テーマ）を Phase 1（対話型インプット収集）で方向性を固め、Phase 2（Agent Teams 自律ループ）で調査品質がスコアカード基準を満たすまで自動改善する。

## トリガー

- `/research-loop <対象>`
- 「深く調べて」「調査ループで」「リサーチループで」

## 前提

- idea-feedback の逐次パイプライン（競合調査→批評→水平思考→改善）を ralph-loop の反復改善モデルに載せ替えたもの
- Phase 1 はユーザーとの対話。Phase 2 は AI 同士の自律ループ（ユーザーは待つだけ）
- リサーチタイプに応じてスコアカードは共通、Reviewer の観点が変わる

## 対応リサーチタイプ

| タイプ | 説明 | Generator の重点 |
|---|---|---|
| `competitor` | 競合調査 | WebSearch + 既存CSV活用。直接/間接競合・代替手段の網羅 |
| `technology` | 技術調査 | WebSearch + ドキュメント読み込み。技術的な実現可能性・トレードオフ |
| `market` | 市場調査 | WebSearch + 統計データ。市場規模・トレンド・セグメント |
| `general` | 汎用リサーチ | 上記に当てはまらないリサーチ |

## Phase 1: 対話型インプット収集

ユーザーと対話しながら、リサーチの素材を集める。

### Step 1: コンテキスト収集

以下の情報を対話で集める（一度に全部聞かない。2-3個ずつ聞く）:

1. **リサーチ対象**: 何を調べるか（ファイルパス or テキスト概要）
2. **リサーチタイプ**: competitor / technology / market / general（不明な場合は内容から推定して提案する）
3. **目的**: この調査結果を何に使うか（意思決定 / 企画 / 設計 / 記事執筆）
4. **既知情報**: 既に知っていること・調査済みの内容
5. **特に知りたいこと**: 重点的に調べてほしい観点
6. **制約**（あれば）: 調査範囲の限定、除外条件

### Step 2: 事前データ収集（自動）

ユーザーとの対話と並行して、以下のデータを自動収集する:

- **既存リサーチデータ**: `research/` 配下の関連ファイル
- **過去の議論**: `/query-talks` で関連する会議録を検索
- **既存ノート**: `Zettelkasten/` 内の関連ノート

### Step 3: リサーチ素材の確定

収集した情報を整理し、以下を確定する:

- リサーチ対象の定義（1-2文）
- リサーチタイプ（competitor / technology / market / general）
- 調査の目的と期待する出力
- 既知情報のサマリ
- 重点調査観点

### Step 4: Phase 2 移行の承認

リサーチ素材をまとめて提示し、ユーザーに確認する:

```
以下の素材で Phase 2（自律リサーチループ）に進みます。
リサーチタイプ「{research_type}」に応じた Reviewer がスコアカードに基づいてレビューし、
MUST全通過（または5回で打ち切り）まで自動で調査→批評→追加調査を回します。

使用スコアカード: scorecard.md
Reviewer A: coverage-reviewer（網羅性チェッカー）
Reviewer B: critical-analyst（批判的分析者）

---
（リサーチ素材のサマリ）
---

Phase 2 に進めてよいですか？
```

ユーザーの承認を得てから Phase 2 に進む。

## Phase 2: ralph-loop ベースの自律リサーチループ

ralph-loop プラグインの Stop hook でループを駆動する。各イテレーションでは Integrator プロンプトに従い、Generator（調査+分析）→ [Coverage Reviewer ∥ Critical Analyst] 並列レビュー → 統合判定 → ファイル書き出しを1回実行する。

### 状態ファイル

ループの状態はファイルで永続化する（ralph-loop が iteration カウントを管理）:

- `/tmp/research-loop/draft.md` — 最新リサーチレポート（Generator の出力）
- `/tmp/research-loop/scorecard-history.md` — 全イテレーションのスコアカード履歴
- `/tmp/research-loop/feedback.md` — 最新の統合改善指示
- `/tmp/research-loop/materials.md` — Phase 1 で確定したリサーチ素材（初回のみ書き込み。research_type を含む）

### ralph-loop 起動

Phase 1 完了後、以下の手順で起動する:

1. `/tmp/research-loop/` ディレクトリを作成
2. `materials.md` に Phase 1 のリサーチ素材を書き出す（`research_type: {competitor|technology|market|general}` を必ず含める）
3. `/ralph-loop` を以下のプロンプトで起動する:

```
/ralph-loop "以下のファイルを Read tool で読み、その指示に従って1イテレーション分の処理を実行せよ。

- .claude/skills/research-loop/references/integrator-prompt.md

状態ファイル（毎イテレーション開始時に読む。存在しないファイルはスキップ）:
- /tmp/research-loop/materials.md
- /tmp/research-loop/draft.md
- /tmp/research-loop/scorecard-history.md
- /tmp/research-loop/feedback.md

integrator-prompt.md に記載された完了判定チェックリストに従い、条件を満たしたら <promise>COMPLETE</promise> を出力せよ。
" --max-iterations 5 --completion-promise "COMPLETE"
```

### Phase 2 完了後

最終イテレーションの出力がユーザーに直接表示される:

- **完了の場合**: 最終リサーチレポート + レビュー履歴サマリ。最終レポートの保存先を確認する
- **打ち切りの場合**: 現時点のベストレポート + 残存課題レポート + 人間への推奨アクション（追加調査すべき領域）

### 成果物の保存

Phase 2 完了後、リサーチレポートを以下に保存する:

- **competitor**: `research/competitors/[対象名]/` 配下
- **technology**: `research/technology/[テーマ名]/` 配下
- **market**: `research/market/[テーマ名]/` 配下
- **general**: `research/general/[テーマ名]/` 配下

## 収束条件（参考）

詳細は `references/scorecard.md` に定義:

- **完了**: MUST全通過 + (ループ2回以上 or WANT 3/5以上)
- **打ち切り**: ループ5回到達（ralph-loop の `--max-iterations 5` が安全弁）。残存課題レポートを人間に提示

## 既存スキルの再利用

Generator は以下の既存スキルを呼び出してリサーチを実行する（独自にロジックを持たない）:

| スキル | 役割 | スキル定義 |
|---|---|---|
| `/research-competitors` | 競合・類似サービス・既存アプローチの調査 | `.claude/skills/research-competitors/SKILL.md` |
| `/critique-idea` | 調査結果の批判的分析（前提・盲点・弱点の検証） | `.claude/skills/critique-idea/SKILL.md` |
| `/lateral-thinking` | 水平思考で別の視点・アプローチを探索 | `.claude/skills/lateral-thinking/SKILL.md` |

詳細は `references/generator-prompt.md` を参照。

## idea-feedback との関係

- idea-feedback は逐次パイプライン（1回実行で完結）。同じスキル群を使うが、フィードバックループがない
- research-loop は反復改善モデル（品質が基準を満たすまでループ）。同じスキル群を使い、Reviewer のダメ出しで追加調査を回す
- 使い分け: 広く浅く全体像を見たい → idea-feedback、特定領域を深く調べたい → research-loop
