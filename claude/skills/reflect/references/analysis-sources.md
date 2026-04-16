# 分析時の参照情報

reflectが重複チェック・分析・保存先判断する際の参照情報。

## 公式ドキュメント

- [Skills](https://code.claude.com/docs/en/skills) - スキルの作り方・frontmatter・supporting files
- [Memory / CLAUDE.md](https://code.claude.com/docs/en/memory) - メモリ階層・CLAUDE.mdの役割
- [Rules (.claude/rules/)](https://code.claude.com/docs/en/memory#modular-rules-with-clauderules) - モジュラールールの構造・paths frontmatter
- [Best Practices](https://code.claude.com/docs/en/best-practices) - CLAUDE.mdの書き方・スキル活用

## 保存先の使い分け

| 保存先 | 性質 | 書き振り | 公式の位置付け |
|--------|------|----------|---------------|
| `.claude/rules/*.md` | トピック別の制約・原則。paths frontmatterで特定ファイルにスコープ可能 | 1トピック1ファイル。命令形（「〜すること」「〜禁止」）1-5行 | 「focused, well-organized rule files」 |
| `CLAUDE.md` | プロジェクト全体の地図。チーム共有の指示。毎セッション読み込まれる | セクション分けされた説明文。箇条書き中心 | 「project-specific instructions, conventions, and context」 |
| `.claude/skills/` | `/skill-name`で呼び出す再利用ワークフロー。必要な時だけ読み込まれる | frontmatter + Workflow + Validation | 「reusable, documented behaviours」 |

### 判断フロー

1. 「〜するな」「〜を使え」（制約・好み）→ `.claude/rules/`
2. プロジェクト構造・全体方針・命名規則 → `CLAUDE.md`
3. 複数ステップの定型作業（入力→処理→出力）→ `.claude/skills/`
4. 迷ったら → rulesかCLAUDE.md（skillは「2回以上繰り返すパターン」が閾値）

### CLAUDE.mdに入れるもの・入れないもの（Best Practices準拠）

**入れる**: Claudeが推測できないBashコマンド / デフォルトと異なるコードスタイル / テスト指示 / リポジトリ作法 / アーキテクチャ決定 / 環境の癖 / 非自明な挙動

**入れない**: コード読めばわかること / 標準的な言語規約 / 詳細なAPIドキュメント（リンクで済む）/ 頻繁に変わる情報 / ファイルごとの説明 / 「きれいなコードを書け」のような自明な指示

**判定基準**: 「この行を削除したらClaudeがミスするか？」→ Noなら削除

## 重複チェック対象

| 種別 | パス | 確認内容 |
|------|------|----------|
| 既存スキル | `.claude/skills/*/SKILL.md` | name, description, Workflow |
| 既存ルール | `.claude/rules/*.md` | ルール内容 |
| CLAUDE.md | `CLAUDE.md` | 全セクション |
| README.md | `README.md` | スキル一覧テーブル |

## スキル化の検出シグナル

セッション中の以下のパターンを探す：

| シグナル | 閾値 | 例 |
|----------|------|-----|
| 同じ手順の繰り返し | 2回以上 | ファイル読み→変換→書き出しを複数回 |
| 複数ツールの定型連鎖 | 3ツール以上の固定順序 | Grep→Read→Edit→Bash |
| 入力→定形出力 | パターンが安定 | ソリューション→プレスリリース |
| チェックリスト的作業 | 3項目以上 | ペルソナとモックの整合性チェック |

## ルール追加の検出シグナル

| シグナル | 例 |
|----------|-----|
| ユーザーの修正指示 | 「日本語で」「コメント入れないで」 |
| 好みの明示 | 「こっちがいい」「〜の方が好き」 |
| 手戻り・失敗 | 削除後に参照切れ発覚、lintエラーの見落とし |
| 繰り返す前提 | 「いつも〜してね」「毎回〜」 |

## CLAUDE.md更新の検出シグナル

| シグナル | 例 |
|----------|-----|
| 新ディレクトリ作成 | `mkdir`で新しいパスが追加された |
| 新ワークフロー確立 | 「今後はこの流れで」 |
| 命名規則の変更 | 新しいファイル命名パターン |
| スキルの追加/削除 | 「利用可能なスキル」セクションの更新が必要 |

## 提案時の注意

- 既存と重複する提案は出さない（まずチェック対象を全部読む）
- 1セッションで大量に提案しない（多くても3-4件）
- 一回きりの作業はスキル化しない
- 曖昧な提案は出さない（具体的なファイルパス・変更内容を示す）
