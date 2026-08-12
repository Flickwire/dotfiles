# Dotfiles

Personal terminal configuration for GitHub Codespaces and fresh development
environments. The installer configures Zsh, Vim, asdf, and a small set of
command-line tools without upgrading the entire operating system.

## Supported Systems

- Ubuntu and Debian
- Amazon Linux 2023
- Fedora and RHEL 9 or 10
- macOS with [Homebrew](https://brew.sh) already installed

The installer supports x86-64 and ARM64. Other operating systems and
architectures fail explicitly rather than attempting a partial installation.
Amazon Linux 2 is not supported. RHEL 9 uses a user-local Vim build because its
vendor Vim is older than YouCompleteMe's minimum supported release.

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
- AWS CLI 2.36.21
- GitHub CLI 2.97.0
- Starship 1.26.0
- Terraform 1.15.8

Vim includes the commit-pinned YouCompleteMe plugin with semantic completion
for JavaScript, TypeScript, and Python. JSON and YAML use pinned Node language
servers, while Terraform uses `terraform-ls` 0.39.0. `vim-terraform` provides
syntax and identifier completion for generic HCL; `terraform-ls` intentionally
only receives Terraform files because HashiCorp does not support arbitrary HCL.

YouCompleteMe requires Vim 9.1.0016 or newer with embedded Python 3.12 or newer.
The installer selects distribution packages where compatible, directs Amazon
Linux 2023 Vim to its side-by-side Python 3.12 runtime, and installs a current
Vim under `~/.local` on RHEL 9. CMake and a C++17 compiler are installed as
build dependencies. The first installation compiles YouCompleteMe and can take
several minutes; subsequent runs reuse a validated build fingerprint.

uv installs a prebuilt Python 3.14.7, the latest stable release; Python does not
designate LTS releases. This avoids compiling CPython during bootstrap. The OS
package manager installs only missing bootstrap utilities and shell/editor
tools. Independent plugin and tool downloads use two concurrent jobs by default
to remain safe on small instances. Set `DOTFILES_INSTALL_JOBS` to a positive
integer to change the limit. asdf installs its tools under `$HOME/.asdf` and
exposes them through `$HOME/.asdf/shims`.

To make Zsh the login shell after installation:

```bash
chsh -s "$(command -v zsh)"
```

## EC2 User Data

`scripts/ec2-user-data-amazon-linux.sh` bootstraps these dotfiles for the
`ssm-user` account on Amazon Linux 2023. Supply the script when launching an
instance:

```bash
aws ec2 run-instances \
  --image-id ami-xxxxxxxxxxxxxxxxx \
  --instance-type t3.micro \
  --iam-instance-profile Name=your-ssm-instance-profile \
  --user-data file://scripts/ec2-user-data-amazon-linux.sh
```

The script creates `ssm-user` when the SSM Agent has not created it yet, grants
the passwordless sudo access expected by Session Manager, installs from a
checkout at `~ssm-user/.local/src/dotfiles`, and selects Zsh as the login shell.
It is safe to run again. `DOTFILES_REPOSITORY` and `DOTFILES_REF` may be set to
use a fork or pinned commit; pin `DOTFILES_REF` for reproducible launches.
Amazon Linux 2023 installs the complete pinned toolset, including Node.js and
the Vim completion stack.

## Pinned Dependencies

The asdf binary is pinned to a release and verified with SHA-256. asdf plugins,
directly sourced Zsh plugins, and native Vim packages are pinned to commits or
tags. Tool versions live in `.tool-versions`; uv's prebuilt Python distributions
are also checksummed. Update the corresponding constants, checksums, and tool
versions deliberately when upgrading them.

YouCompleteMe is pinned to a commit because the project does not publish release
tags, and its recursive submodules are synchronized before every build. The
Node language servers use a committed npm lockfile. `terraform-ls` is installed
from HashiCorp's release archive after SHA-256 verification.

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
rm -rf "$HOME/.vim/pack/dotfiles" "$HOME/.local/share/dotfiles-language-servers"
rm -rf "$HOME/.local/state/dotfiles"
rm -f "$HOME/.local/bin/asdf" "$HOME/.local/bin/python" "$HOME/.local/bin/python3"
rm -f "$HOME/.local/bin/python3.14"
rm -f "$HOME/.local/bin/terraform-ls" "$HOME/.local/bin/vscode-json-language-server"
rm -f "$HOME/.local/bin/yaml-language-server"
rm -f "$HOME/.config/starship.toml" "$HOME/.zshrc" "$HOME/.vimrc"
rm -f "$HOME/.tool-versions"
```

System packages are not removed automatically because they may be shared with
other tools.

## License

No license has been granted. This repository remains available for inspection,
but reuse or redistribution requires permission from the copyright holder.
