# Dotfiles

Personal terminal configuration for GitHub Codespaces and fresh development
environments. The installer configures Zsh, Vim, tmux, nvm-managed Node.js,
native Python 3.14, and a small set of command-line tools without upgrading
the entire operating system. It no longer installs or initializes asdf or uv.

## Supported Systems

- Ubuntu
- Amazon Linux 2023 (AL2023)
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
It copies `.zshrc`, `.vimrc`, `.tmux.conf`, and `starship.toml` (the latter into
`$HOME/.config`) into `$HOME`; when an existing destination
differs, it is preserved with a `.backup-YYYYMMDDHHMMSS` suffix. Re-running the
installer does not create backups for unchanged configuration files, but can
update selected native packages as repositories advance. Editing or pulling
this repository alone does not modify an existing installed environment.

### Node.js And Package Managers

nvm 0.40.7 is installed in `$HOME/.nvm`. The installer reads Node.js **26.8.2**
from `.nvmrc`, installs it, and makes it the nvm default. As of the version
verification date, **2026-09-15**, this is the latest Current release, not LTS.
Node's `npm` and `npx` remain available. The installer also installs Corepack
**0.36.0** globally into this Node installation and enables its pnpm and Yarn
shims; it does not pin a project package manager or install a specific pnpm or
Yarn release. `.zshrc` loads nvm and retains
`PNPM_HOME="$HOME/.local/share/pnpm"` on `PATH`.

### Native Python And CLI Tools

Python 3.14 is a global, native package installation, not a uv-managed download,
source build, or virtual environment. The `python`, `python3`, and `python3.14`
commands in `$HOME/.local/bin` are symlink aliases to the same native Python 3.14:
`/usr/bin/python3.14` on Linux or
`$(brew --prefix python@3.14)/bin/python3.14` on macOS. `.zshrc` adds
`$HOME/.local/bin` to `PATH`. The OS Python is left intact; this does **not** mean
there is only one Python interpreter on the operating system. Projects can
still create isolated environments with `python -m venv`.

AWS CLI, GitHub CLI (`gh`), Starship, and Terraform use native packages wherever
the installer supports them. Python's 3.14 patch version and native CLI package
versions are no longer pinned: they follow the latest available packages in
the configured repositories, which may lag upstream releases.

- **Ubuntu:** enables universe and adds the GitHub CLI and HashiCorp APT
  repositories. It adds the deadsnakes PPA only when `python3.14` has no package
  candidate, then installs `python3.14`, `python3.14-venv`, `gh`, and `terraform`.
  AWS CLI and Starship use APT packages when available; only absent package
  candidates trigger their direct-download fallbacks.
- **Amazon Linux 2023:** adds the GitHub CLI and HashiCorp repositories and
  installs `python3.14`, `python3.14-pip`, `awscli-2`, `gh`, and `terraform`.
  Starship uses a native package when available, otherwise its direct fallback.
  The installer uses `dnf --releasever=latest install -y --allowerasing` for
  selected packages and their dependencies, not a whole-OS upgrade. Dependency
  resolution can replace conflicting packages.
- **macOS:** requires Homebrew, updates its metadata, and installs/upgrades
  selected formulae. Tools are `python@3.14`, `awscli`, `gh`, `starship`, and
  `hashicorp/tap/terraform` from the vendor's `hashicorp/tap` tap.

Bootstrap packages include Git, curl, Zsh, Vim, tmux, htop, and archive utilities.
Linux also installs libatomic, which is required by current Node.js binaries.
Plugin checkouts run with two concurrent jobs by default. Set
`DOTFILES_INSTALL_JOBS` to a positive integer to change this limit.

To make Zsh the login shell after installation:

```bash
chsh -s "$(command -v zsh)"
```

## EC2 User Data

`scripts/ec2-user-data-amazon-linux.sh` requires root and Amazon Linux 2023 and
bootstraps these dotfiles for the `ssm-user` account. Supply the script when
launching an instance with an appropriate AMI, SSM Agent, and IAM configuration:

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
It installs bootstrap packages with a targeted `dnf install`, then runs the
full installer as `ssm-user`, including Node.js and native Python 3.14. It can
be run again and rejects an existing checkout with an unexpected origin or a
destination that is not a Git checkout. `DOTFILES_REPOSITORY` and `DOTFILES_REF`
may be set to use a fork or pinned commit. Pin `DOTFILES_REF` to reproduce the
repository revision; native repository package versions can still change.

## Pinned Dependencies

Version verification date: **2026-09-15**. Node's pin lives in `.nvmrc`;
Corepack, nvm, plugin commits, and fallback versions/checksums live in
`install.sh`. Zsh plugins are sourced directly and Vim uses native packages,
without zplug or vim-plug.

| Dependency | Pin |
| --- | --- |
| nvm 0.40.7 | `f0b0c6bb0b281ceeb106c8cf9ab8fde141215092` |
| zsh-autosuggestions | `85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5` |
| zsh-syntax-highlighting | `2fc57d63067c18b1100ecdbf684fa5baf49459d1` |
| zsh-history-substring-search | `14c8d2e0ffaee98f2df9850b19944f32546fdea5` |
| vim-airline | `ae24f4aca06731d5d7224df1fc5415975331b214` |
| vim-terraform | `520498fab16a3a11f2ae1b8cb65e0a1684bc317a` |

Only the direct-download fallbacks are pinned to **AWS CLI 2.36.45** and
**Starship 1.26.0**, with architecture-specific SHA-256 checksums verified
before installation. AWS CLI's fallback installs under `$HOME/.local/aws-cli`
with commands in `$HOME/.local/bin`; Starship's fallback installs
`$HOME/.local/lib/dotfiles/starship` with a symlink in `$HOME/.local/bin`.
If a native package becomes available later, the installer removes only its
own matching fallback command symlinks so they cannot shadow the package.
These are not pins on native package versions.
Update release constants, checksums, and checkout commits deliberately.

## Optional Legacy Cleanup

There is no automatic destructive migration of old asdf or uv installations.
The new configuration does not initialize them, but existing installations,
environments, shims, and project references are not removed or migrated.
Before optionally removing either manager, inventory its installed tools and
environments, global packages, project version files, shell startup references,
and command resolution (for example, `type -a python python3 node npm npx`).
Verify replacement tools and preserve anything still needed by other projects.

Remove only individually identified, unused manager files or installations,
using their documented uninstall procedures. Do not delete whole manager,
cache, or shared binary directories as a blanket migration step. Apply the
same inventory-first approach to any old zplug or vim-plug installation.

## Development

Run static checks and an example bootstrap dispatch dry run from the repository:

```bash
shellcheck install.sh scripts/*.sh
for script in install.sh scripts/*.sh; do bash -n "$script"; done
zsh -n .zshrc
DOTFILES_DRY_RUN=1 DOTFILES_OS_ID=ubuntu DOTFILES_OS_VERSION_ID=24.04 ./install.sh
```

`DOTFILES_DRY_RUN=1` exercises only OS detection and bootstrap package-manager
dispatch without changing the machine. It exits before native tool repository
setup, Python configuration, nvm/Node installation, plugins, or configuration
copying; it is not a complete installation test. `DOTFILES_OS_ID` and
`DOTFILES_OS_VERSION_ID` are test overrides.

After a real installation in a disposable test environment, run:

```bash
bash scripts/validate-install.sh
```

The validation script checks nvm/Node versions and paths, the default Node,
Corepack and its pnpm/Yarn shims, all Python aliases targeting global native
3.14, standard-library imports, venv creation and pip health, CLI major
versions, Vim plugins and Terraform file detection, Starship rendering, and
interactive Zsh startup with a clean inherited tool path.

`.github/workflows/validate.yml` defines:

- ShellCheck, Bash syntax checks for every script, and Zsh syntax checking.
- Bootstrap dry-run dispatch for Ubuntu 24.04/26.04, AL2023, and macOS 15/26.
- Two installer runs followed by installed-configuration validation on
  `ubuntu-24.04`, `ubuntu-latest`, and `macos-latest` runners.
- Two EC2 user-data runs in a digest-pinned AL2023 container, followed by checks
  for the SSM user's login shell, ownership, sudoers validity, passwordless sudo,
  requested checkout revision, and installed configuration.

## Uninstall

There is no automatic uninstaller. Inventory the installed configuration and
tools before removing anything, and restore desired timestamped backups of
`.zshrc`, `.vimrc`, `.tmux.conf`, and `.config/starship.toml`. If necessary,
select another installed login shell before removing Zsh.

Remove only the Python alias symlinks in `$HOME/.local/bin` after confirming
their targets, not the OS Python. Review individual plugin checkouts under
`$HOME/.local/share/zsh/plugins` and `$HOME/.vim/pack/dotfiles/start` before
removing them. Inventory nvm Node versions and global packages before following
nvm's uninstall procedure. Inspect direct AWS CLI/Starship fallback paths and
symlink targets before removing those specific installations; never delete
`$HOME/.local/bin` or other shared directories wholesale.

Native packages must be uninstalled manually through APT, DNF, or Homebrew,
after reviewing dependencies and whether other tools use them. Remove added
repository definitions, keys, or taps only if no remaining packages need them.
System packages and the EC2 SSM account/sudo configuration are not automatically
removed; review their use separately rather than deleting shared resources.

## License

No license has been granted. This repository remains available for inspection,
but reuse or redistribution requires permission from the copyright holder.
