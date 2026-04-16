# Reviewer セレクター

ドキュメントタイプに応じて、使用するレビュアーとスコアカードの組み合わせを定義する。

## マッピング

| doc_type | Reviewer A | Reviewer B | スコアカード |
|---|---|---|---|
| `article` | beginner-reader（FB-B） | critical-reader（FB-C） | scorecard-article.md |
| `spec` | spec-reviewer（FB-S） | critical-reader（FB-C） | scorecard-spec.md |
| `general` | target-reader（FB-T） | critical-reader（FB-C） | scorecard-general.md |

## レビュアープロンプトファイル

| レビュアー | プロンプトファイル | 指示ID接頭辞 |
|---|---|---|
| beginner-reader | `beginner-reviewer-prompt.md` | FB-B-N |
| critical-reader | `critical-reviewer-prompt.md` | FB-C-N |
| spec-reviewer | `spec-reviewer-prompt.md` | FB-S-N |
| target-reader | `target-reader-prompt.md` | FB-T-N |

## Reviewer B（critical-reader）の共通性

critical-reader はすべてのドキュメントタイプで共通して使用される。
ただし、評価に使用するスコアカードは doc_type に応じて切り替わる。
Integrator が critical-reader を起動する際、対応する scorecard-{doc_type}.md の内容を渡すこと。

## 選択ロジック

```
materials.md から doc_type を読み取る
  ↓
doc_type に対応する行を上記マッピングから取得
  ↓
Reviewer A のプロンプトファイルを読み込む
Reviewer B（critical-reviewer-prompt.md）を読み込む
scorecard-{doc_type}.md を読み込む
  ↓
Integrator が Agent tool で並列起動する
```
