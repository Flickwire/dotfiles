echo 'Installing starship...'
if command -v starship &> /dev/null; then
    echo "Starship is already installed."
else
    curl -sS https://starship.rs/install.sh | sh
    echo "Starship has been installed."
fi
echo 'Configuring starship...'
mkdir -p ~/.config
mkdir -p ~/.config/starship
cp -r ./starship.toml ~/.config/starship/starship.toml
echo 'Starship configuration has been set up.'
echo 'Configuring zsh...'
cp -r ./zshrc ~/.zshrc
echo 'Zsh configuration has been set up.'
echo 'Installing zplug...'
if [ ! -d "$HOME/.zplug" ]; then
    curl -sL zplug.sh/installer | zsh
    echo 'Zplug has been installed.'
else
    echo 'Zplug is already installed.'
fi
echo 'Installing zsh plugins...'
zsh_plugins=(
    "zsh-users/zsh-autosuggestions"
    "zsh-users/zsh-syntax-highlighting"
    "zsh-users/zsh-history-substring-search"
)
for plugin in "${zsh_plugins[@]}"; do
    if zplug check "$plugin"; then
        echo "$plugin is already installed."
    else
        echo "Installing $plugin..."
        zplug install "$plugin"
    fi
done
