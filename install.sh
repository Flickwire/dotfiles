#!/bin/bash

echo 'Installing starship...'
curl -sS https://starship.rs/install.sh | sh
echo 'Configuring starship...'
mkdir -p ~/.config
mkdir -p ~/.config/starship
cp -r ./starship.toml ~/.config/starship/starship.toml
echo 'Configuring zsh...'
cp -r ./.zshrc ~/.zshrc
echo 'Installing zplug...'
curl -sL zplug.sh/installer | zsh
echo 'Installing zsh plugins...'
zsh_plugins=(
    "zsh-users/zsh-autosuggestions"
    "zsh-users/zsh-syntax-highlighting"
    "zsh-users/zsh-history-substring-search"
)
for plugin in "${zsh_plugins[@]}"; do
    zplug install "$plugin"
done
