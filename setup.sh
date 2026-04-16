#!/bin/bash

# setup
git submodule init
git submodule update

# linuxbrew
CI=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)

# brew
brew install -q git bash-completion tmux make vim fzf npm node
rm ~/.gitconfig
brew postinstall -q gcc

# google-cloud-sdk
brew install -q python@3
brew link python@3 --overwrite
curl https://sdk.cloud.google.com > /tmp/install.sh
bash /tmp/install.sh --disable-prompts
rm /tmp/install.sh

# link
$(cd $(dirname $0); pwd)/link.sh