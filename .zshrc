HISTFILE="$HOME/.histfile"
HISTSIZE=10000
SAVEHIST=10000

setopt append_history
setopt hist_ignore_dups
setopt share_history
bindkey -e

export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"

export PNPM_HOME="$HOME/.local/share/pnpm"
path=("$HOME/.local/bin" "$PNPM_HOME" $path)
typeset -U path PATH

if command -v starship >/dev/null; then
    eval "$(starship init zsh)"
fi

git-cleanup() {
    local branch tracking
    git remote prune origin
    git fetch --prune
    git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads |
        while read -r branch tracking; do
            [[ "$tracking" == "[gone]" ]] && git branch -d -- "$branch"
        done
}

if [[ -r "$HOME/.zplug/init.zsh" ]]; then
    source "$HOME/.zplug/init.zsh"
    [[ -r "$HOME/.zsh_plugins" ]] && source "$HOME/.zsh_plugins"
    zplug load
fi

[[ -n "${terminfo[kcuu1]-}" ]] && bindkey "$terminfo[kcuu1]" history-substring-search-up
[[ -n "${terminfo[kcud1]-}" ]] && bindkey "$terminfo[kcud1]" history-substring-search-down
