# Dotfiles

Personal terminal configuration for GitHub Codespaces and fresh development environments. The installer configures Zsh, Vim, tmux, Mise, Topgrade, and a focused set of command-line tools without upgrading the entire operating system.

## Supported Systems

- Ubuntu
- Amazon Linux 2023
- macOS with [Homebrew](https://brew.sh) already installed

The installer supports x86-64 and ARM64. Other operating systems and architectures fail explicitly rather than attempting a partial installation.

## Install

```bash
git clone https://github.com/Flickwire/dotfiles.git
./dotfiles/install.sh
```

GitHub Codespaces automatically runs `install.sh` when this repository is selected as the account's dotfiles repository. The installer may request `sudo` to install missing bootstrap packages. Existing configuration files are copied aside with a `.backup-YYYYMMDDHHMMSS` suffix when they differ.

## Tool Management

Mise manages development tools defined in `config/mise/config.toml`. Standalone CLIs track current releases, while the configured Node versions remain available for projects that require them.

Mise respects `.nvmrc` files. With Zsh activated, changing directory automatically resolves Node from the nearest `.nvmrc`; use `mise shell node@20` for a temporary override.

The installer downloads a pinned, SHA-256-verified Mise binary and then installs the configured tools. Topgrade uses `config/topgrade.toml` to run `mise upgrade --global` as part of its normal update flow.

## EC2 User Data

`scripts/ec2-user-data-amazon-linux.sh` requires root and Amazon Linux 2023. It creates the `ssm-user` account as needed, grants the passwordless sudo access expected by Session Manager, checks out these dotfiles, runs the installer, and selects Zsh as the login shell.

`DOTFILES_REPOSITORY` and `DOTFILES_REF` may select a fork or pinned revision. Pin `DOTFILES_REF` to reproduce the repository revision.

## Development

Run static checks and a bootstrap dispatch dry run:

```bash
shellcheck install.sh scripts/*.sh
for script in install.sh scripts/*.sh; do bash -n "$script"; done
zsh -n .zshrc
DOTFILES_DRY_RUN=1 DOTFILES_OS_ID=ubuntu DOTFILES_OS_VERSION_ID=24.04 ./install.sh
```

The CI workflow also runs the installer twice on Ubuntu and macOS, validates Mise activation and `.nvmrc` switching, and exercises Amazon Linux 2023 EC2 user data in a container.

## Uninstall

There is no automatic uninstaller. Restore any desired timestamped configuration backups, then remove only the tools and directories you have confirmed are unused:

```bash
rm -rf "$HOME/.local/share/mise" "$HOME/.cache/mise" "$HOME/.config/mise"
rm -rf "$HOME/.local/share/zsh/plugins" "$HOME/.vim/pack/dotfiles"
rm -f "$HOME/.local/bin/mise" "$HOME/.config/starship.toml" "$HOME/.config/topgrade.toml"
```

System packages and EC2 SSM configuration are shared resources and must be reviewed separately.

## License

No license has been granted. This repository remains available for inspection, but reuse or redistribution requires permission from the copyright holder.