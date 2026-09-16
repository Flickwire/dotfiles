#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_DIR
export PATH="$HOME/.local/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
test -s "$NVM_DIR/nvm.sh"
# shellcheck source=/dev/null
source "$NVM_DIR/nvm.sh"
test "$(nvm --version)" = "0.40.7"
test "$(nvm version default)" = "v26.8.2"
test "$(node --version)" = "v26.8.2"
test "$(command -v node)" = "$NVM_DIR/versions/node/v26.8.2/bin/node"
test "$(cat "$REPO_DIR/.nvmrc")" = "26.8.2"
test "$(corepack --version)" = "0.36.0"
test -x "$(dirname -- "$(command -v node)")/pnpm"
test -x "$(dirname -- "$(command -v node)")/yarn"

if [[ "$(uname -s)" == "Darwin" ]]; then
    GLOBAL_PYTHON="$(brew --prefix python@3.14)/bin/python3.14"
else
    GLOBAL_PYTHON=/usr/bin/python3.14
fi
export GLOBAL_PYTHON
test -x "$GLOBAL_PYTHON"
for executable in python python3 python3.14; do
    test "$(command -v "$executable")" = "$HOME/.local/bin/$executable"
    test -L "$HOME/.local/bin/$executable"
    "$executable" - <<'PY'
import bz2
import ctypes
import lzma
import os
import readline
import sqlite3
import ssl
import sys

assert sys.version_info[:2] == (3, 14), sys.version
assert os.path.samefile(sys.executable, os.environ["GLOBAL_PYTHON"]), sys.executable
assert sys.prefix == sys.base_prefix, "Expected a global Python, not a virtualenv"
PY
done

WORK_DIR="$(mktemp -d)"
readonly WORK_DIR
trap 'rm -rf -- "$WORK_DIR"' EXIT
python -m venv "$WORK_DIR/venv"
"$WORK_DIR/venv/bin/python" -m pip --version
"$WORK_DIR/venv/bin/python" -m pip check

# Native repositories may advance patch and minor versions independently.
[[ "$(aws --version)" =~ ^aws-cli/2\.[0-9]+\.[0-9]+ ]]
[[ "$(gh --version)" =~ ^gh\ version\ 2\.[0-9]+\.[0-9]+ ]]
[[ "$(terraform version)" =~ ^Terraform\ v1\.[0-9]+\.[0-9]+ ]]
[[ "$(starship --version)" =~ ^starship\ 1\.[0-9]+\.[0-9]+ ]]
test -f "$HOME/.vim/pack/dotfiles/start/vim-airline/plugin/airline.vim"
test -f "$HOME/.vim/pack/dotfiles/start/vim-terraform/ftdetect/hcl.vim"
vim -Nu "$HOME/.vimrc" -i NONE -es -c 'if !exists(":AirlineToggle") | cquit | endif' -c 'qa!'
touch "$WORK_DIR/main.tf"
vim -Nu "$HOME/.vimrc" -i NONE -es "$WORK_DIR/main.tf" \
    -c 'if &filetype !=# "terraform" | cquit | endif' -c 'qa!'
STARSHIP_CONFIG="$HOME/.config/starship.toml" starship prompt --path "$REPO_DIR" >/dev/null

# Do not let the parent's nvm PATH hide a broken interactive shell setup.
# shellcheck disable=SC2016
env -u NVM_DIR -u NVM_BIN -u NVM_INC \
    PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin \
    zsh -ic '
        set -euo pipefail
        test "$(nvm --version)" = "0.40.7"
        test "$(node --version)" = "v26.8.2"
        test "$(command -v node)" = "$HOME/.nvm/versions/node/v26.8.2/bin/node"
        test "$(corepack --version)" = "0.36.0"
        test "$(command -v python)" = "$HOME/.local/bin/python"
        test "$(command -v python3)" = "$HOME/.local/bin/python3"
        test "$(command -v python3.14)" = "$HOME/.local/bin/python3.14"
        python -c "import sys; assert sys.version_info[:2] == (3, 14)"
        python3 -c "import sys; assert sys.version_info[:2] == (3, 14)"
        [[ "$PROMPT" == *starship* ]]
    '
