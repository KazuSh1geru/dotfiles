---
name: doc-quality-loop
description: ドキュメントを対話型インプット収集→Agent Teams自律改善ループで品質研磨する。ドキュメントタイプに応じたスコアカードとレビュアーで、ダメ出しが収束するまで自動改善する。
disable-model-invocation: true
---

# doc-quality-loop

ドキュメントを Phase 1（対話型インプット収集）で方向性を固め、Phase 2（Agent Teams 自律ループ）でドキュメントタイプに応じたレビュアーのダメ出しが収束するまで自動改善する。

## 前提

- 記事の場合は `article-planner` + `zenn-article-writer` / `qiita-article-writer` でドラフト完成済みが理想。未完成でも Phase 1 で収集する
- Phase 1 はユーザーとの対話。Phase 2 は AI 同士の自律ループ（ユーザーは待つだけ）
- ドキュメントタイプに応じてスコアカードとレビュアーの組み合わせが変わる（`references/reviewer-selector.md` 参照）

## 対応ドキュメントタイプ

| タイプ | 説明 | 例 |
|---|---|---|
| `article` | 技術記事 | Zenn記事、Qiita記事 |
| `spec` | 仕様書・設計書 | 技術仕様書、API仕様、アーキテクチャ設計書 |
| `general` | 汎用ドキュメント | 提案書、ノート、スライド、レポート、議事録 |

## Phase 1: 対話型インプット収集

ユーザーと対話しながら、ドキュメント改善の素材を集める。

### Step 1: コンテキスト収集

以下の情報を対話で集める（一度に全部聞かない。2-3個ずつ聞く）:

1. **ドキュメント**: 既存のファイルパス or テーマ概要
2. **ドキュメントタイプ**: article / spec / general（不明な場合は内容から推定して提案する）
3. **対象読者**: 誰に向けて書いているか（経験レベル、職種、関心）
4. **目的**: このドキュメントで達成したいこと（読者に持ち帰ってほしいこと / 承認を得たいこと / 共有したいこと）
5. **公開先**（articleの場合）: Zenn / Qiita / 両方
6. **懸念点**（あれば）: 自分で気になっている箇所

### Step 2: ドラフト素材の確定

収集した情報を整理し、以下を確定する:

- ドキュメント本文（ファイルパス or 本文テキスト）
- ドキュメントタイプ（article / spec / general）
- 対象読者の定義
- ドキュメントの目的（読者の行動変化 / 意思決定支援 / 情報共有）
- 公開先フォーマット（articleの場合: Zenn / Qiita）

### Step 3: Phase 2 移行の承認

ドラフト素材をまとめて提示し、ユーザーに確認する:

```
以下の素材で Phase 2（自律改善ループ）に進みます。
ドキュメントタイプ「{doc_type}」に応じたレビュアーがスコアカードに基づいてレビューし、
MUST全通過（または5回で打ち切り）まで自動で改善を回します。

使用スコアカード: scorecard-{doc_type}.md
レビュアー: {reviewer_a} + {reviewer_b}

---
（ドラフト素材のサマリ）
---

Phase 2 に進めてよいですか？
```

ユーザーの承認を得てから Phase 2 に進む。

## Phase 2: ralph-loop ベースの自律改善ループ

ralph-loop プラグインの Stop hook でループを駆動する。各イテレーションでは Integrator プロンプトに従い、Generator → [Reviewer A ∥ Reviewer B] 並列レビュー → 統合判定 → ファイル書き出しを1回実行する。

### 状態ファイル

ループの状態はファイルで永続化する（ralph-loop が iteration カウントを管理）:

- `/tmp/doc-quality-loop/draft.md` — 最新ドラフト（Generator の出力）
- `/tmp/doc-quality-loop/scorecard-history.md` — 全イテレーションのスコアカード履歴
- `/tmp/doc-quality-loop/feedback.md` — 最新の統合改善指示
- `/tmp/doc-quality-loop/materials.md` — Phase 1 で確定したドラフト素材（初回のみ書き込み。doc_type を含む）

### ralph-loop 起動

Phase 1 完了後、以下の手順で起動する:

1. `/tmp/doc-quality-loop/` ディレクトリを作成
2. `materials.md` に Phase 1 のドラフト素材を書き出す（`doc_type: {article|spec|general}` を必ず含める）
3. `/ralph-loop` を以下のプロンプトで起動する:

```
/ralph-loop "以下のファイルを Read tool で読み、その指示に従って1イテレーション分の処理を実行せよ。

- .claude/skills/doc-quality-loop/references/integrator-prompt.md

状態ファイル（毎イテレーション開始時に読む。存在しないファイルはスキップ）:
- /tmp/doc-quality-loop/materials.md
- /tmp/doc-quality-loop/draft.md
- /tmp/doc-quality-loop/scorecard-history.md
- /tmp/doc-quality-loop/feedback.md

integrator-prompt.md に記載された完了判定チェックリストに従い、条件を満たしたら <promise>COMPLETE</promise> を出力せよ。
" --max-iterations 5 --completion-promise "COMPLETE"
```

### Phase 2 完了後

最終イテレーションの出力がユーザーに直接表示される:

- **完了の場合**: 最終ドラフト + レビュー履歴サマリ（scorecard-history.md に全履歴が残る）。最終ドラフトを元のファイルに反映するか確認する
- **打ち切りの場合**: 現時点のベストドラフト + 残存課題レポート + 人間への推奨アクション

## 収束条件（参考）

ドキュメントタイプに応じたスコアカード（`references/scorecard-{doc_type}.md`）に定義:

- **完了**: MUST全通過 + (ループ2回以上 or WANT 3/5以上)
- **打ち切り**: ループ5回到達（ralph-loop の `--max-iterations 5` が安全弁）。残存課題レポートを人間に提示
