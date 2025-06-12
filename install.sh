#!/bin/bash

echo 'Installing starship...'
curl -sS https://starship.rs/install.sh > starship.sh
sh starship.sh --yes
echo 'Configuring starship...'
mkdir -p ~/.config
cp -r ./starship.toml ~/.config/starship.toml
echo 'Configuring zsh...'
cp -r ./.zshrc ~/.zshrc
echo 'Installing zplug...'
curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
