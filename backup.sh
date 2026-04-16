#!/bin/bash

# 移行先のディレクトリを指定
BACKUP_DIR="$HOME/dev/dotfiles/dotfiles"

# バックアップディレクトリが存在しない場合は作成
mkdir -p "$BACKUP_DIR"

# 移行するdotfileのリスト
DOTFILES=(
    ".bashrc"
    ".vimrc"
    ".gitconfig"
    ".zshrc"
    ".tmux.conf"
)

# 各dotfileをバックアップディレクトリにコピー
for file in "${DOTFILES[@]}"; do
    if [ -f "$HOME/$file" ]; then
        cp "$HOME/$file" "$BACKUP_DIR"
        echo "バックアップしました: $file"
    else
        echo "見つかりませんでした: $file"
    fi
done

echo "dotfileの移行が完了しました。"