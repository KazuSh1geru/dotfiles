# dotfiles

個人の Claude Code 設定を管理する dotfiles リポジトリ。

## 管理対象

| パス | dotfiles パス | 説明 |
|---|---|---|
| `~/.claude/settings.json` | `claude/settings.json` | プラグイン有効化・マーケットプレイス設定 |
| `~/.claude/CLAUDE.md` | `claude/CLAUDE.md` | グローバル AI 指示（思考パターン・成長課題） |
| `~/.claude/statusline.py` | `claude/statusline.py` | ステータスライン スクリプト |
| `~/.claude/skills/` | `claude/skills/` | グローバルスキル（31個） |

## 管理対象外

- `~/.claude/settings.local.json` — 機械固有の権限設定（センシティブな内容を含む）
- `~/.claude/plugins/` — プラグインキャッシュ（`install.sh` で再インストール）
- `~/.claude/sessions/`, `history.jsonl` 等 — 実行時状態データ

## セットアップ（新しい Mac）

```bash
# 1. dotfiles をクローン
git clone https://github.com/KazuSh1geru/dotfiles.git ~/dotfiles

# 2. セットアップスクリプト実行
bash ~/dotfiles/install.sh

# 3. settings.local.json を手動作成（必要に応じて）
# ~/.claude/settings.local.json に機械固有の権限設定を記載
```

## プラグイン構成

### 公式プラグイン（claude-plugins-official）

| プラグイン | 用途 |
|---|---|
| superpowers | エージェント強化スキル群（brainstorming, debugging, etc.） |
| slack | Slack 読み書き |
| ralph-loop | 自律ループ実行 |
| context7 | ライブラリドキュメント取得 |
| github | GitHub 操作 MCP |
| playwright | ブラウザ自動化 MCP |
| code-review | PR コードレビュー |
| claude-md-management | CLAUDE.md 管理 |
| figma | Figma 連携 MCP |
| frontend-design | フロントエンド設計 |

### カスタムプラグイン

| プラグイン | マーケット | 用途 |
|---|---|---|
| codex | openai-codex | Codex CLI 連携 |
| scheduler | claude-scheduler | スケジュール実行 |
| dxu-pages | dx-ai-skills | 社内ページ公開 |
| claude-telemetry | lmi | テレメトリ |
| discovery | discovery | 探索系スキル |

## グローバルスキル（claude/skills/）

壁打ち・設計・記事執筆・Issue管理などのワークフロースキル。
詳細は `claude/skills/` 以下の各スキルの `SKILL.md` を参照。
