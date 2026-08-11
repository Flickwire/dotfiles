# Dotfiles

Personal terminal configuration for GitHub Codespaces and fresh development
environments. The installer configures Zsh, Starship, Vim, GitHub CLI, and a
small set of command-line tools without upgrading the entire operating system.

## Supported Systems

- Ubuntu and Debian
- Amazon Linux 2 and 2023
- Fedora and RHEL
- macOS with [Homebrew](https://brew.sh) already installed

The installer supports x86-64 and ARM64. Other operating systems and
architectures fail explicitly rather than attempting a partial installation.

## Install

Clone the repository and run the installer from any directory:

```bash
git clone https://github.com/Flickwire/dotfiles.git
./dotfiles/install.sh
```

GitHub Codespaces automatically runs `install.sh` when this repository is
selected as the account's dotfiles repository.

The script installs system packages and therefore may request `sudo` access.
It copies the tracked configuration into `$HOME`; when an existing destination
differs, it is preserved with a `.backup-YYYYMMDDHHMMSS` suffix. Re-running the
installer is safe and does not create backups for unchanged files.

To make Zsh the login shell after installation:

```bash
chsh -s "$(command -v zsh)"
```

## Prompt Font

The Starship prompt uses Nerd Font and Powerline glyphs. Select a
[Nerd Font](https://www.nerdfonts.com/) in the local terminal to render every
symbol correctly. Codespaces controls the terminal font in the client rather
than inside the container.

## Pinned Dependencies

Starship downloads are pinned to a release and verified with SHA-256. zplug,
vim-plug, Zsh plugins, and Vim plugins are pinned to tags or commits. Update the
corresponding constants and checksums deliberately when upgrading them.

## Development

Run the same validation used by CI:

```bash
shellcheck install.sh
bash -n install.sh
zsh -n .zshrc .zsh_plugins
DOTFILES_DRY_RUN=1 DOTFILES_OS_ID=ubuntu DOTFILES_OS_VERSION_ID=24.04 ./install.sh
STARSHIP_CONFIG="$PWD/starship.toml" starship prompt --path "$PWD" >/dev/null
```

`DOTFILES_DRY_RUN=1` validates package-manager dispatch without changing the
machine. `DOTFILES_OS_ID` and `DOTFILES_OS_VERSION_ID` are test overrides.

## Uninstall

Remove the installed files and restore any desired timestamped backups:

```bash
rm -rf "$HOME/.zplug" "$HOME/.vim/autoload/plug.vim" "$HOME/.vim/plugged"
rm -f "$HOME/.local/bin/starship" "$HOME/.zsh_plugins"
rm -f "$HOME/.config/starship.toml" "$HOME/.zshrc" "$HOME/.vimrc"
```

System packages are not removed automatically because they may be shared with
other tools.

## License

No license has been granted. This repository remains available for inspection,
but reuse or redistribution requires permission from the copyright holder.
