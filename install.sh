#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR
readonly MISE_VERSION="2026.11.1"
readonly ZSH_AUTOSUGGESTIONS_COMMIT="85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5"
readonly ZSH_SYNTAX_HIGHLIGHTING_COMMIT="e6683f20e5c38d3e5447f45845d04ddda75d0f23"
readonly ZSH_HISTORY_SEARCH_COMMIT="a0bdb0d47dbaba31dba2db7af8c48a5d9c74049a"
readonly VIM_AIRLINE_COMMIT="8dc1bd0a116de527f6bc58c1d04386ba357c624f"
readonly VIM_TERRAFORM_COMMIT="520498fab16a3a11f2ae1b8cb65e0a1684bc317a"
BACKUP_SUFFIX="$(date +%Y%m%d%H%M%S)"
readonly BACKUP_SUFFIX
readonly DRY_RUN="${DOTFILES_DRY_RUN:-0}"
readonly INSTALL_JOBS="${DOTFILES_INSTALL_JOBS:-2}"

if [[ ! "$INSTALL_JOBS" =~ ^[1-9][0-9]*$ ]]; then
    printf 'Error: DOTFILES_INSTALL_JOBS must be a positive integer.\n' >&2
    exit 1
fi

export PATH="$HOME/.local/bin:$PATH"
TEMP_PATHS=()
SUDO=()

cleanup() {
    if ((${#TEMP_PATHS[@]})); then
        rm -rf -- "${TEMP_PATHS[@]}"
    fi
}
trap cleanup EXIT

run() {
    if [[ "$DRY_RUN" == "1" ]]; then
        printf 'DRY RUN:'
        printf ' %q' "$@"
        printf '\n'
        return
    fi
    "$@"
}

ensure_sudo() {
    if ((EUID == 0)); then
        return
    fi
    if [[ "$DRY_RUN" == "1" ]] || command -v sudo >/dev/null; then
        SUDO=(sudo)
        return
    fi
    printf 'Error: sudo is required to install system packages.\n' >&2
    exit 1
}

download() {
    curl --fail --location --silent --show-error --proto '=https' --tlsv1.2 "$@"
}

detect_os() {
    OS_ID="${DOTFILES_OS_ID:-}"
    OS_VERSION_ID="${DOTFILES_OS_VERSION_ID:-}"
    if [[ -z "$OS_ID" ]]; then
        if [[ "$(uname -s)" == "Darwin" ]]; then
            OS_ID="macos"
            OS_VERSION_ID="$(sw_vers -productVersion)"
        elif [[ -r /etc/os-release ]]; then
            # shellcheck disable=SC1091
            source /etc/os-release
            OS_ID="$ID"
            OS_VERSION_ID="${VERSION_ID:-}"
        else
            printf 'Error: cannot detect this operating system.\n' >&2
            exit 1
        fi
    fi

    case "$OS_ID:$OS_VERSION_ID" in
        ubuntu:* | macos:* | amzn:2023) ;;
        *)
            printf 'Error: supported systems are Ubuntu, macOS, and Amazon Linux 2023.\n' >&2
            exit 1
            ;;
    esac
    case "$(uname -m)" in
        x86_64 | arm64 | aarch64) ;;
        *)
            printf 'Error: only x86-64 and ARM64 are supported.\n' >&2
            exit 1
            ;;
    esac
}

install_packages() {
    case "$OS_ID" in
        ubuntu)
            run "${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
            ;;
        amzn)
            run "${SUDO[@]}" dnf --releasever=latest install -y --allowerasing "$@"
            ;;
        macos)
            run brew install "$@"
            run brew upgrade "$@"
            ;;
    esac
}

install_system_packages() {
    local command_name
    local needs_install=0
    local required=(curl git gpg groff htop less tar tmux unzip vim xz zsh)

    if [[ "$DRY_RUN" == "1" ]]; then
        needs_install=1
    else
        for command_name in "${required[@]}"; do
            if ! command -v "$command_name" >/dev/null; then
                needs_install=1
                break
            fi
        done
        case "$OS_ID" in
            ubuntu)
                dpkg-query --show libatomic1 >/dev/null 2>&1 || needs_install=1
                ;;
            amzn)
                rpm --query libatomic >/dev/null 2>&1 || needs_install=1
                ;;
        esac
    fi
    if ((needs_install == 0)); then
        return
    fi

    case "$OS_ID" in
        ubuntu)
            ensure_sudo
            run "${SUDO[@]}" apt-get update
            install_packages ca-certificates curl git gnupg groff-base htop less libatomic1 tar tmux unzip vim xz-utils zsh software-properties-common
            ;;
        amzn)
            ensure_sudo
            install_packages ca-certificates curl git gnupg2 groff-base htop less libatomic tar tmux unzip vim-enhanced xz zsh
            ;;
        macos)
            if [[ "$DRY_RUN" != "1" ]] && ! command -v brew >/dev/null; then
                printf 'Error: Homebrew is required on macOS: https://brew.sh\n' >&2
                exit 1
            fi
            run brew update
            install_packages ca-certificates curl git gnupg groff htop less tmux unzip vim xz zsh
            ;;
    esac
}

mise_target() {
    local machine os
    machine="$(uname -m)"
    os="$(uname -s)"

    case "$os:$machine" in
        Linux:x86_64)
            MISE_ASSET="linux-x64"
            MISE_SHA256="7eb7cd0f3d60443b17bc0915534b65b68c2f9b37e721946687dc6a72d006d32c"
            ;;
        Linux:aarch64 | Linux:arm64)
            MISE_ASSET="linux-arm64"
            MISE_SHA256="0b26aa92ace34dae2e376c62920473cdb6e857e0b43ae5cc6e59922d7c934301"
            ;;
        Darwin:x86_64)
            MISE_ASSET="macos-x64"
            MISE_SHA256="4c86f557c17d237784bd259e6842e2a231d7f550afedca522a69da8a5dca1282"
            ;;
        Darwin:arm64 | Darwin:aarch64)
            MISE_ASSET="macos-arm64"
            MISE_SHA256="4fd6dabcc9a57050e8f2fd1e53fc6b74e82d8cd85ed1751fd172756888aa98bc"
            ;;
        *)
            printf 'Error: unsupported Mise target: %s %s\n' "$os" "$machine" >&2
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

install_mise() {
    if [[ -x "$HOME/.local/bin/mise" ]] &&
        [[ "$("$HOME/.local/bin/mise" --version | awk '{print $1}')" == "$MISE_VERSION" ]]; then
        return
    fi

    local archive temp_dir url
    mise_target
    temp_dir="$(mktemp -d)"
    TEMP_PATHS+=("$temp_dir")
    archive="$temp_dir/mise.tar.xz"
    url="https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-${MISE_ASSET}.tar.xz"

    download --output "$archive" "$url"
    verify_sha256 "$MISE_SHA256" "$archive"
    tar -xJf "$archive" -C "$temp_dir"
    mkdir -p "$HOME/.local/bin"
    install -m 0755 "$(find "$temp_dir" -type f -name mise -print -quit)" "$HOME/.local/bin/mise"
}

install_git_checkout() {
    local checkout_dir="$1" commit="$3" required_file="$4" url="$2"
    if [[ ! -d "$checkout_dir/.git" ]]; then
        if [[ -e "$checkout_dir" ]]; then
            printf 'Error: %s exists but is not a Git checkout.\n' "$checkout_dir" >&2
            exit 1
        fi
        mkdir -p "$(dirname -- "$checkout_dir")"
        git clone --filter=blob:none --no-checkout "$url" "$checkout_dir"
    fi
    if [[ "$(git -C "$checkout_dir" rev-parse HEAD 2>/dev/null || true)" == "$commit" ]] &&
        [[ -r "$checkout_dir/$required_file" ]]; then
        return
    fi
    git -C "$checkout_dir" fetch --depth 1 origin "$commit"
    git -C "$checkout_dir" checkout --detach "$commit"
}

wait_for_jobs() {
    local pid status=0
    for pid in "$@"; do
        wait "$pid" || status=1
    done
    return "$status"
}

PIDS=()
run_job() {
    "$@" & PIDS+=("$!")
    if ((${#PIDS[@]} >= INSTALL_JOBS)); then
        wait_for_jobs "${PIDS[@]}"
        PIDS=()
    fi
}

finish_jobs() {
    if ((${#PIDS[@]})); then
        wait_for_jobs "${PIDS[@]}"
    fi
    PIDS=()
}

install_mise_tools() {
    "$HOME/.local/bin/mise" install --yes
}

install_plugins() {
    local plugin_root="$HOME/.local/share/zsh/plugins"
    local package_root="$HOME/.vim/pack/dotfiles/start"
    run_job install_git_checkout "$plugin_root/autosuggestions" https://github.com/zsh-users/zsh-autosuggestions.git \
        "$ZSH_AUTOSUGGESTIONS_COMMIT" zsh-autosuggestions.zsh
    run_job install_git_checkout "$plugin_root/syntax-highlighting" https://github.com/zsh-users/zsh-syntax-highlighting.git \
        "$ZSH_SYNTAX_HIGHLIGHTING_COMMIT" zsh-syntax-highlighting.zsh
    run_job install_git_checkout "$plugin_root/history-substring-search" https://github.com/zsh-users/zsh-history-substring-search.git \
        "$ZSH_HISTORY_SEARCH_COMMIT" zsh-history-substring-search.zsh
    run_job install_git_checkout "$package_root/vim-airline" https://github.com/vim-airline/vim-airline.git \
        "$VIM_AIRLINE_COMMIT" plugin/airline.vim
    run_job install_git_checkout "$package_root/vim-terraform" https://github.com/hashivim/vim-terraform.git \
        "$VIM_TERRAFORM_COMMIT" ftdetect/hcl.vim
    finish_jobs
}

install_config() {
    local destination source
    mkdir -p "$HOME/.config"
    while IFS='|' read -r source destination; do
        mkdir -p "$(dirname -- "$destination")"
        if [[ -e "$destination" ]] && ! cmp -s "$source" "$destination"; then
            cp -a "$destination" "${destination}.backup-${BACKUP_SUFFIX}"
            printf 'Backed up %s\n' "$destination"
        fi
        install -m 0644 "$source" "$destination"
    done <<EOF
$REPO_DIR/starship.toml|$HOME/.config/starship.toml
$REPO_DIR/config/mise/config.toml|$HOME/.config/mise/config.toml
$REPO_DIR/config/topgrade.toml|$HOME/.config/topgrade.toml
$REPO_DIR/.zshrc|$HOME/.zshrc
$REPO_DIR/.vimrc|$HOME/.vimrc
$REPO_DIR/.tmux.conf|$HOME/.tmux.conf
EOF
}

detect_os
printf 'Detected OS: %s %s\n' "$OS_ID" "$OS_VERSION_ID"
install_system_packages
if [[ "$DRY_RUN" == "1" ]]; then
    exit 0
fi

install_mise
install_plugins
install_config
install_mise_tools

printf 'Dotfiles installed. Start zsh or run: chsh -s %q\n' "$(command -v zsh)"
