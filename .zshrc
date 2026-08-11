HISTFILE="$HOME/.histfile"
HISTSIZE=10000
SAVEHIST=10000

setopt append_history
setopt hist_ignore_dups
setopt rcquotes
setopt share_history
bindkey -e

export PNPM_HOME="$HOME/.local/share/pnpm"
path=("$HOME/.local/bin" "$HOME/.asdf/shims" "$PNPM_HOME" $path)
typeset -U path PATH

fpath=("$HOME/.asdf/completions" $fpath)
autoload -Uz compinit && compinit

if command -v starship >/dev/null; then
    eval "$(starship init zsh)"
fi

alias git-cleanup='git remote prune origin && git fetch -p && for branch in $(git for-each-ref --format ''%(refname) %(upstream:track)'' refs/heads | awk ''$2 == "[gone]" {sub("refs/heads/", "", $1); print $1}''); do git branch -D $branch; done'

if [[ -r "$HOME/.zplug/init.zsh" ]]; then
    source "$HOME/.zplug/init.zsh"
    [[ -r "$HOME/.zsh_plugins" ]] && source "$HOME/.zsh_plugins"
    zplug load
fi

[[ -n "${terminfo[kcuu1]-}" ]] && bindkey "$terminfo[kcuu1]" history-substring-search-up
[[ -n "${terminfo[kcud1]-}" ]] && bindkey "$terminfo[kcud1]" history-substring-search-down
