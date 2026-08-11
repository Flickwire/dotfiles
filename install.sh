#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR
readonly STARSHIP_VERSION="1.26.0"
readonly ZPLUG_COMMIT="8f14b4850d8e410f00db92afcd87b88c0c90f771"
readonly VIM_PLUG_COMMIT="88e31471818e9a29a8a20a0ee61360cfd7bdc1cd"
readonly VIM_PLUG_SHA256="7e2b20cd909da9c456498684c98f03c63829170f01e34595dd8e1818a217d37c"
BACKUP_SUFFIX="$(date +%Y%m%d%H%M%S)"
readonly BACKUP_SUFFIX
readonly DRY_RUN="${DOTFILES_DRY_RUN:-0}"

TEMP_PATHS=()
cleanup() {
    if ((${#TEMP_PATHS[@]})); then
        rm -rf -- "${TEMP_PATHS[@]}"
    fi
}
trap cleanup EXIT

SUDO=()
if ((EUID != 0)); then
    if ! command -v sudo >/dev/null; then
        printf 'Error: sudo is required to install system packages.\n' >&2
        exit 1
    fi
    SUDO=(sudo)
fi

run() {
    if [[ "$DRY_RUN" == "1" ]]; then
        printf 'DRY RUN:'
        printf ' %q' "$@"
        printf '\n'
        return
    fi
    "$@"
}

download() {
    curl --fail --location --silent --show-error --proto '=https' --tlsv1.2 "$@"
}

detect_os() {
    OS_ID="${DOTFILES_OS_ID:-}"
    OS_VERSION_ID="${DOTFILES_OS_VERSION_ID:-}"

    if [[ -n "$OS_ID" ]]; then
        return
    fi

    if [[ "$(uname -s)" == "Darwin" ]]; then
        OS_ID="macos"
        OS_VERSION_ID="$(sw_vers -productVersion)"
        return
    fi

    if [[ ! -r /etc/os-release ]]; then
        printf 'Error: cannot detect this operating system.\n' >&2
        exit 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release
    OS_ID="$ID"
    OS_VERSION_ID="${VERSION_ID:-}"
}

install_apt_packages() {
    run "${SUDO[@]}" apt-get update
    run "${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive \
        apt-get install -y curl gh git htop tmux vim zsh
}

install_rpm_gh_repo() {
    if [[ "$DRY_RUN" == "1" ]]; then
        printf 'DRY RUN: install GitHub CLI RPM repository\n'
        return
    fi
    if command -v gh >/dev/null; then
        return
    fi

    local repo_file
    repo_file="$(mktemp)"
    TEMP_PATHS+=("$repo_file")
    download --output "$repo_file" https://cli.github.com/packages/rpm/gh-cli.repo
    run "${SUDO[@]}" install -m 0644 "$repo_file" /etc/yum.repos.d/gh-cli.repo
}

install_amazon_packages() {
    if [[ "$OS_VERSION_ID" == "2" ]]; then
        run "${SUDO[@]}" yum install -y curl git htop tmux vim-enhanced zsh
        install_rpm_gh_repo
        run "${SUDO[@]}" yum install -y gh
        return
    fi

    if [[ "$OS_VERSION_ID" != "2023" ]]; then
        printf 'Error: unsupported Amazon Linux release: %s\n' "$OS_VERSION_ID" >&2
        exit 1
    fi

    run "${SUDO[@]}" dnf install -y --allowerasing curl git htop tmux vim-enhanced zsh
    install_rpm_gh_repo
    run "${SUDO[@]}" dnf install -y --allowerasing gh
}

install_dnf_packages() {
    local packages=(curl git tmux vim-enhanced zsh)
    if [[ "$OS_ID" == "fedora" ]]; then
        packages+=(htop)
    fi
    run "${SUDO[@]}" dnf install -y "${packages[@]}"
    install_rpm_gh_repo
    run "${SUDO[@]}" dnf install -y gh
}

install_macos_packages() {
    if [[ "$DRY_RUN" != "1" ]] && ! command -v brew >/dev/null; then
        printf 'Error: Homebrew is required on macOS: https://brew.sh\n' >&2
        exit 1
    fi
    run brew install curl gh git htop tmux vim zsh
}

install_system_packages() {
    local command_name missing=0 required=(curl gh git tmux vim zsh)
    if [[ "$OS_ID" != "rhel" ]]; then
        required+=(htop)
    fi
    if [[ "$DRY_RUN" != "1" ]]; then
        for command_name in "${required[@]}"; do
            if ! command -v "$command_name" >/dev/null; then
                missing=1
                break
            fi
        done
        if ((missing == 0)); then
            return
        fi
    fi

    case "$OS_ID" in
        ubuntu | debian)
            install_apt_packages
            ;;
        amzn)
            install_amazon_packages
            ;;
        fedora | rhel)
            install_dnf_packages
            ;;
        macos)
            install_macos_packages
            ;;
        *)
            printf 'Error: unsupported operating system: %s %s\n' "$OS_ID" "$OS_VERSION_ID" >&2
            exit 1
            ;;
    esac
}

starship_target() {
    local machine os
    machine="$(uname -m)"
    os="$(uname -s)"

    case "$os:$machine" in
        Linux:x86_64)
            STARSHIP_ASSET="x86_64-unknown-linux-musl"
            STARSHIP_SHA256="b7c232b0e8249d8e55a40beb79c5c43a7d370f3f9408bd215deb0170daeaadf3"
            ;;
        Linux:aarch64 | Linux:arm64)
            STARSHIP_ASSET="aarch64-unknown-linux-musl"
            STARSHIP_SHA256="dc30189378d2f2e287384e8a692d3f95ad1df64cf0e8c36aa9201516028aed6b"
            ;;
        Darwin:x86_64)
            STARSHIP_ASSET="x86_64-apple-darwin"
            STARSHIP_SHA256="5548f406a4b6f5695903bdea83f77ce47ec12c8c0e62dabd33122d8f133e4207"
            ;;
        Darwin:arm64 | Darwin:aarch64)
            STARSHIP_ASSET="aarch64-apple-darwin"
            STARSHIP_SHA256="c40b27b11f580411e068f2fa6c1be7830a387c0bc47a94d1d37f32b054c5361d"
            ;;
        *)
            printf 'Error: unsupported Starship target: %s %s\n' "$os" "$machine" >&2
            exit 1
            ;;
    esac
}

verify_sha256() {
    local expected="$1" file="$2"
    if command -v sha256sum >/dev/null; then
        printf '%s  %s\n' "$expected" "$file" | sha256sum --check --status
    else
        printf '%s  %s\n' "$expected" "$file" | shasum -a 256 --check --status
    fi
}

install_starship() {
    if [[ -x "$HOME/.local/bin/starship" ]] &&
        [[ "$("$HOME/.local/bin/starship" --version | awk 'NR == 1 {print $2}')" == "$STARSHIP_VERSION" ]]; then
        return
    fi

    local archive temp_dir url
    starship_target
    temp_dir="$(mktemp -d)"
    TEMP_PATHS+=("$temp_dir")
    archive="$temp_dir/starship.tar.gz"
    url="https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/starship-${STARSHIP_ASSET}.tar.gz"

    download --output "$archive" "$url"
    verify_sha256 "$STARSHIP_SHA256" "$archive"
    tar -xzf "$archive" -C "$temp_dir"
    mkdir -p "$HOME/.local/bin"
    install -m 0755 "$temp_dir/starship" "$HOME/.local/bin/starship"
}

install_zplug() {
    if [[ ! -d "$HOME/.zplug/.git" ]]; then
        if [[ -e "$HOME/.zplug" ]]; then
            printf 'Error: %s exists but is not a zplug Git checkout.\n' "$HOME/.zplug" >&2
            exit 1
        fi
        git clone --filter=blob:none https://github.com/zplug/zplug.git "$HOME/.zplug"
    fi

    if [[ "$(git -C "$HOME/.zplug" rev-parse HEAD)" == "$ZPLUG_COMMIT" ]]; then
        return
    fi

    git -C "$HOME/.zplug" fetch --depth 1 origin "$ZPLUG_COMMIT"
    git -C "$HOME/.zplug" checkout --detach "$ZPLUG_COMMIT"
}

install_vim_plug() {
    mkdir -p "$HOME/.vim/autoload"
    if [[ -f "$HOME/.vim/autoload/plug.vim" ]] &&
        verify_sha256 "$VIM_PLUG_SHA256" "$HOME/.vim/autoload/plug.vim"; then
        return
    fi
    download --output "$HOME/.vim/autoload/plug.vim" \
        "https://raw.githubusercontent.com/junegunn/vim-plug/${VIM_PLUG_COMMIT}/plug.vim"
    verify_sha256 "$VIM_PLUG_SHA256" "$HOME/.vim/autoload/plug.vim"
}

install_config() {
    local destination source
    mkdir -p "$HOME/.config"

    while IFS='|' read -r source destination; do
        if [[ -e "$destination" ]] && ! cmp -s "$source" "$destination"; then
            cp -a "$destination" "${destination}.backup-${BACKUP_SUFFIX}"
            printf 'Backed up %s\n' "$destination"
        fi
        install -m 0644 "$source" "$destination"
    done <<EOF
$REPO_DIR/starship.toml|$HOME/.config/starship.toml
$REPO_DIR/.zshrc|$HOME/.zshrc
$REPO_DIR/.zsh_plugins|$HOME/.zsh_plugins
$REPO_DIR/.vimrc|$HOME/.vimrc
EOF
}

install_plugins() {
    # HOME must expand inside the clean zsh process rather than in this shell.
    # shellcheck disable=SC2016
    env TERM="${TERM:-xterm-256color}" LANG="${LANG:-C.UTF-8}" LC_ALL="${LC_ALL:-C.UTF-8}" \
        zsh -c 'source "$HOME/.zplug/init.zsh"; source "$HOME/.zsh_plugins"; zplug check || zplug install'
    vim -Nu "$HOME/.vimrc" -i NONE -es -c 'PlugInstall --sync' -c 'qa!'
}

detect_os
printf 'Detected OS: %s %s\n' "$OS_ID" "$OS_VERSION_ID"
install_system_packages

if [[ "$DRY_RUN" == "1" ]]; then
    exit 0
fi

install_starship
install_zplug
install_vim_plug
install_config
install_plugins

printf 'Dotfiles installed. Start zsh or run: chsh -s %q\n' "$(command -v zsh)"
