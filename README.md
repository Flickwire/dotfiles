# Dotfiles

Personal terminal configuration for GitHub Codespaces and fresh development
environments. The installer configures Zsh, Vim, asdf, and a small set of
command-line tools without upgrading the entire operating system.

## Supported Systems

- Ubuntu and Debian
- Amazon Linux 2 and 2023
- Fedora and RHEL
- macOS with [Homebrew](https://brew.sh) already installed

The installer supports x86-64 and ARM64. Other operating systems and
architectures fail explicitly rather than attempting a partial installation.
Node.js 24 is skipped on Amazon Linux 2 because its glibc 2.26 is older than
the glibc 2.28 required by official Node.js binaries.

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

asdf manages the user-facing development tools pinned in `.tool-versions`:

- Node.js 24.19.0, the latest LTS release
- uv 0.12.3
- AWS CLI 2.36.20
- GitHub CLI 2.97.0
- Starship 1.26.0
- Terraform 1.15.8

uv installs a prebuilt Python 3.14.7, the latest stable release; Python does not
designate LTS releases. This avoids compiling CPython during bootstrap. The OS
package manager installs only missing bootstrap utilities and shell/editor
tools. Independent asdf plugin and tool downloads run concurrently. asdf
installs its tools under `$HOME/.asdf` and exposes them through
`$HOME/.asdf/shims`.

To make Zsh the login shell after installation:

```bash
chsh -s "$(command -v zsh)"
```

## EC2 User Data

The scripts under `scripts/` bootstrap these dotfiles for the `ssm-user`
account on Amazon Linux 2 or Amazon Linux 2023. Supply the matching script when
launching an instance:

```bash
aws ec2 run-instances \
  --image-id ami-xxxxxxxxxxxxxxxxx \
  --instance-type t3.micro \
  --iam-instance-profile Name=your-ssm-instance-profile \
  --user-data file://scripts/ec2-user-data-amazon-linux-2023.sh
```

Each script creates `ssm-user` when the SSM Agent has not created it yet, grants
the passwordless sudo access expected by Session Manager, installs from a
checkout at `~ssm-user/.local/src/dotfiles`, and selects Zsh as the login shell.
It is safe to run again. `DOTFILES_REPOSITORY` and `DOTFILES_REF` may be set to
use a fork or pinned commit; pin `DOTFILES_REF` for reproducible launches.
Node.js is omitted because current releases do not support Amazon Linux 2's
older glibc. Amazon Linux 2023 installs the complete pinned toolset, including
Node.js.

## Pinned Dependencies

The asdf binary is pinned to a release and verified with SHA-256. asdf plugins,
directly sourced Zsh plugins, and native Vim packages are pinned to commits or
tags. Tool versions live in `.tool-versions`; uv's prebuilt Python distributions
are also checksummed. Update the corresponding constants, checksums, and tool
versions deliberately when upgrading them.

zplug is no longer used. Existing installations may remove `$HOME/.zplug` and
`$HOME/.zsh_plugins` after upgrading. vim-plug is also no longer used, so
`$HOME/.vim/autoload/plug.vim` and `$HOME/.vim/plugged` may be removed.

## Development

Run the same validation used by CI:

```bash
shellcheck install.sh scripts/*.sh
bash -n install.sh scripts/*.sh
zsh -n .zshrc
DOTFILES_DRY_RUN=1 DOTFILES_OS_ID=ubuntu DOTFILES_OS_VERSION_ID=24.04 ./install.sh
STARSHIP_CONFIG="$PWD/starship.toml" starship prompt --path "$PWD" >/dev/null
asdf current
```

`DOTFILES_DRY_RUN=1` validates package-manager dispatch without changing the
machine. `DOTFILES_OS_ID` and `DOTFILES_OS_VERSION_ID` are test overrides.

## Uninstall

Remove the installed files and restore any desired timestamped backups:

```bash
rm -rf "$HOME/.asdf" "$HOME/.local/share/uv" "$HOME/.local/share/zsh/plugins"
rm -rf "$HOME/.vim/pack/dotfiles"
rm -f "$HOME/.local/bin/asdf" "$HOME/.local/bin/python" "$HOME/.local/bin/python3"
rm -f "$HOME/.local/bin/python3.14"
rm -f "$HOME/.config/starship.toml" "$HOME/.zshrc" "$HOME/.vimrc"
rm -f "$HOME/.tool-versions"
```

System packages are not removed automatically because they may be shared with
other tools.

## License

No license has been granted. This repository remains available for inspection,
but reuse or redistribution requires permission from the copyright holder.
