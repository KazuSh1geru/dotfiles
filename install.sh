#!/bin/bash
# Claude Code environment setup script
# Usage: bash install.sh
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "=== Claude Code Environment Setup ==="
echo "DOTFILES_DIR: $DOTFILES_DIR"
echo ""

# ----------------------------------------
# 1. ~/.claude ディレクトリ確認
# ----------------------------------------
mkdir -p "$CLAUDE_DIR"

# ----------------------------------------
# 2. シンボリックリンク作成
# ----------------------------------------
echo "[1/4] Creating symlinks..."

link() {
  local src="$1" dst="$2"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "  Backing up existing $dst → ${dst}.bak"
    mv "$dst" "${dst}.bak"
  fi
  ln -sf "$src" "$dst"
  echo "  ✓ $dst → $src"
}

link "$DOTFILES_DIR/claude/settings.json"  "$CLAUDE_DIR/settings.json"
link "$DOTFILES_DIR/claude/CLAUDE.md"      "$CLAUDE_DIR/CLAUDE.md"
link "$DOTFILES_DIR/claude/statusline.py"  "$CLAUDE_DIR/statusline.py"
link "$DOTFILES_DIR/claude/skills"         "$CLAUDE_DIR/skills"

# ----------------------------------------
# 3. カスタムマーケットプレイス登録
# ----------------------------------------
echo ""
echo "[2/4] Registering custom marketplaces..."

claude plugins marketplace add lmi-mcs/claude-code-telemetry --scope user 2>/dev/null && echo "  ✓ lmi" || echo "  - lmi (already registered or failed)"
claude plugins marketplace add lmi-mcs/discovery-skills --scope user 2>/dev/null && echo "  ✓ discovery" || echo "  - discovery (already registered or failed)"
claude plugins marketplace add lmi-mcs/dx-ai-skills --scope user 2>/dev/null && echo "  ✓ dx-ai-skills" || echo "  - dx-ai-skills (already registered or failed)"
claude plugins marketplace add lmi-mcs/dx-risk-manager --scope user 2>/dev/null && echo "  ✓ dx-risk-manager" || echo "  - dx-risk-manager (already registered or failed)"
claude plugins marketplace add openai/codex-plugin-cc --scope user 2>/dev/null && echo "  ✓ openai-codex" || echo "  - openai-codex (already registered or failed)"

# ----------------------------------------
# 4. プラグインインストール（公式）
# ----------------------------------------
echo ""
echo "[3/4] Installing official plugins..."

install_plugin() {
  local plugin="$1"
  claude plugins install "$plugin" 2>/dev/null && echo "  ✓ $plugin" || echo "  - $plugin (already installed or failed)"
}

# claude-plugins-official
install_plugin "superpowers@claude-plugins-official"
install_plugin "slack@claude-plugins-official"
install_plugin "ralph-loop@claude-plugins-official"
install_plugin "context7@claude-plugins-official"
install_plugin "github@claude-plugins-official"
install_plugin "playwright@claude-plugins-official"
install_plugin "code-review@claude-plugins-official"
install_plugin "claude-md-management@claude-plugins-official"
install_plugin "figma@claude-plugins-official"
install_plugin "frontend-design@claude-plugins-official"

# ----------------------------------------
# 5. プラグインインストール（カスタム）
# ----------------------------------------
echo ""
echo "[4/4] Installing custom plugins..."

install_plugin "codex@openai-codex"
install_plugin "scheduler@claude-scheduler"
install_plugin "dxu-pages@dx-ai-skills"
install_plugin "claude-telemetry@lmi"
install_plugin "discovery@discovery"

# awesome-claude-skills（未使用につきコメントアウト。必要に応じて有効化）
# install_plugin "changelog-generator@awesome-claude-skills"
# install_plugin "confluence-automation@awesome-claude-skills"
# install_plugin "figma-automation@awesome-claude-skills"
# install_plugin "gitlab-automation@awesome-claude-skills"
# install_plugin "google-calendar-automation@awesome-claude-skills"
# install_plugin "googlesheets-automation@awesome-claude-skills"
# install_plugin "mcp-builder@awesome-claude-skills"
# install_plugin "slack-automation@awesome-claude-skills"
# install_plugin "skill-creator@awesome-claude-skills"
# install_plugin "supabase-automation@awesome-claude-skills"
# install_plugin "webapp-testing@awesome-claude-skills"
# install_plugin "jira-automation@awesome-claude-skills"

# anthropic-agent-skills（サンプル。不要なら省略可）
# install_plugin "example-skills@anthropic-agent-skills"
# install_plugin "document-skills@anthropic-agent-skills"

echo ""
echo "=== Setup complete! ==="
echo ""
echo "NOTE: settings.local.json は手動で作成してください（機械固有の権限設定）"
echo "  参考: ~/.claude/settings.local.json.example があれば確認してください"
echo ""
echo "Verify with:"
echo "  ls -la ~/.claude/settings.json   # symlink確認"
echo "  claude plugins list               # プラグイン一覧"
