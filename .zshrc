HISTFILE="$HOME/.histfile"
HISTSIZE=10000
SAVEHIST=10000

setopt append_history
setopt hist_ignore_dups
setopt rcquotes
setopt share_history
bindkey -e

export PNPM_HOME="$HOME/.local/share/pnpm"
if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi
path=("$HOME/.local/bin" "$PNPM_HOME" $path)
typeset -U path PATH

autoload -Uz compinit && compinit

export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

if command -v starship >/dev/null; then
    eval "$(starship init zsh)"
fi

alias git-cleanup='git remote prune origin && git fetch -p && for branch in $(git for-each-ref --format ''%(refname) %(upstream:track)'' refs/heads | awk ''$2 == "[gone]" {sub("refs/heads/", "", $1); print $1}''); do git branch -D $branch; done'

ZSH_PLUGIN_DIR="$HOME/.local/share/zsh/plugins"
[[ -r "$ZSH_PLUGIN_DIR/autosuggestions/zsh-autosuggestions.zsh" ]] &&
    source "$ZSH_PLUGIN_DIR/autosuggestions/zsh-autosuggestions.zsh"
[[ -r "$ZSH_PLUGIN_DIR/history-substring-search/zsh-history-substring-search.zsh" ]] &&
    source "$ZSH_PLUGIN_DIR/history-substring-search/zsh-history-substring-search.zsh"

[[ -n "${terminfo[kcuu1]-}" ]] && bindkey "$terminfo[kcuu1]" history-substring-search-up
[[ -n "${terminfo[kcud1]-}" ]] && bindkey "$terminfo[kcud1]" history-substring-search-down

[[ -r "$ZSH_PLUGIN_DIR/syntax-highlighting/zsh-syntax-highlighting.zsh" ]] &&
    source "$ZSH_PLUGIN_DIR/syntax-highlighting/zsh-syntax-highlighting.zsh"
unset ZSH_PLUGIN_DIR
