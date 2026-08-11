#!/usr/bin/env bash
# Multi-OS detection and setup script
# Works on Amazon Linux 2023, Amazon Linux 2, Ubuntu, and easy to extend.

set -euo pipefail

# Ensure /etc/os-release exists
if [[ ! -f /etc/os-release ]]; then
    echo "Error: /etc/os-release not found. Cannot detect OS."
    exit 1
fi

# Load OS info
. /etc/os-release

echo "Detected OS: $PRETTY_NAME"

# Function for Amazon Linux 2023 setup
setup_amazon_linux_2023() {
    echo "Running Amazon Linux 2023 setup..."
    sudo dnf update -y
    # Example: install dev tools
    sudo dnf install -y git htop zsh curl tmux
    sudo dnf install dnf5-plugins
    sudo dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo
    sudo dnf install gh
}

# Function for Amazon Linux 2 setup
setup_amazon_linux_2() {
    echo "Running Amazon Linux 2 setup..."
    sudo yum update -y
    sudo yum install -y git curl zsh htop tmux
    type -p yum-config-manager >/dev/null || sudo yum install yum-utils
    sudo yum-config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
    sudo yum install gh
}

# Function for Ubuntu setup
setup_ubuntu() {
    echo "Running Ubuntu setup..."
    sudo apt update -y
    sudo apt install -y git curl zsh htop tmux
    #GH CLI
    (type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)) \
	&& sudo mkdir -p -m 755 /etc/apt/keyrings \
	&& out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
	&& cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& sudo mkdir -p -m 755 /etc/apt/sources.list.d \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& sudo apt update \
	&& sudo apt install gh -y
}

# Function for unknown OS
setup_unknown() {
    echo "Unknown OS: $PRETTY_NAME ($ID)"
    echo "Please add setup steps for this OS."
}

# OS detection and dispatch
case "$ID" in
    amzn)
        if [[ "$VERSION_ID" == "2023" ]]; then
            setup_amazon_linux_2023
        elif [[ "$VERSION_ID" == "2" ]]; then
            setup_amazon_linux_2
        else
            setup_unknown
        fi
        ;;
    ubuntu)
        setup_ubuntu
        ;;
    *)
        setup_unknown
        ;;
esac

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
echo 'Installing vimplug...'
curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
cp -r ./.vimrc ~/.vimrc
exit 0


