#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR
readonly ASDF_VERSION="0.20.0"
readonly ASDF_NODEJS_COMMIT="779c8dc84b3bdab38c2c80622d315c2c3267f74b"
readonly ASDF_UV_COMMIT="1d44a50b8006921f3cb55b4e4d14b1d90472b201"
readonly ASDF_AWSCLI_COMMIT="8489e240cead79912147087f9a3f0ea8ef69616e"
readonly ASDF_GITHUB_CLI_COMMIT="e0605b704ef3829e10a9353b91b4c0bafa5e5582"
readonly ASDF_STARSHIP_COMMIT="56045ec8c5ed34a3da4613b03de9b38c7aa07732"
readonly ASDF_TERRAFORM_COMMIT="d2557f97752761eecb50f63cd31b64c236d23089"
readonly ZSH_AUTOSUGGESTIONS_COMMIT="85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5"
readonly ZSH_SYNTAX_HIGHLIGHTING_COMMIT="c4d95591843d49838b7ad30081e7aba3135a6703"
readonly ZSH_HISTORY_SEARCH_COMMIT="14c8d2e0ffaee98f2df9850b19944f32546fdea5"
readonly VIM_AIRLINE_COMMIT="a2fefe599378b4a493287d10501f51e224753690"
readonly VIM_TERRAFORM_COMMIT="520498fab16a3a11f2ae1b8cb65e0a1684bc317a"
readonly UV_VERSION="0.12.3"
readonly PYTHON_VERSION="3.14.7"
BACKUP_SUFFIX="$(date +%Y%m%d%H%M%S)"
readonly BACKUP_SUFFIX
readonly DRY_RUN="${DOTFILES_DRY_RUN:-0}"
readonly INSTALL_JOBS="${DOTFILES_INSTALL_JOBS:-2}"

if [[ ! "$INSTALL_JOBS" =~ ^[1-9][0-9]*$ ]]; then
    printf 'Error: DOTFILES_INSTALL_JOBS must be a positive integer.\n' >&2
    exit 1
fi

export PATH="$HOME/.local/bin:$HOME/.asdf/shims:$PATH"
export ASDF_NODEJS_AUTO_ENABLE_COREPACK=1

TEMP_PATHS=()
cleanup() {
    if ((${#TEMP_PATHS[@]})); then
        rm -rf -- "${TEMP_PATHS[@]}"
    fi
}
trap cleanup EXIT

SUDO=()

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
    printf 'Error: sudo is required to install missing system packages.\n' >&2
    exit 1
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

map_packages() {
    local family="$1" tool
    shift
    PACKAGES=()
    for tool in "$@"; do
        case "$family:$tool" in
            apt:groff)
                PACKAGES+=(groff-base)
                ;;
            apt:gpg)
                PACKAGES+=(gnupg)
                ;;
            rpm:groff)
                PACKAGES+=(groff-base)
                ;;
            rpm:gpg)
                PACKAGES+=(gnupg2)
                ;;
            rpm:vim)
                PACKAGES+=(vim-enhanced)
                ;;
            brew:gpg)
                PACKAGES+=(gnupg)
                ;;
            *)
                PACKAGES+=("$tool")
                ;;
        esac
    done
}

install_apt_packages() {
    map_packages apt "$@"
    run "${SUDO[@]}" apt-get update
    run "${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive \
        apt-get install -y "${PACKAGES[@]}"
}

install_amazon_packages() {
    map_packages rpm "$@"
    if [[ "$OS_VERSION_ID" == "2" ]]; then
        run "${SUDO[@]}" yum install -y "${PACKAGES[@]}"
        return
    fi

    if [[ "$OS_VERSION_ID" != "2023" ]]; then
        printf 'Error: unsupported Amazon Linux release: %s\n' "$OS_VERSION_ID" >&2
        exit 1
    fi

    run "${SUDO[@]}" dnf install -y --allowerasing "${PACKAGES[@]}"
}

install_dnf_packages() {
    map_packages rpm "$@"
    run "${SUDO[@]}" dnf install -y "${PACKAGES[@]}"
}

install_macos_packages() {
    if [[ "$DRY_RUN" != "1" ]] && ! command -v brew >/dev/null; then
        printf 'Error: Homebrew is required on macOS: https://brew.sh\n' >&2
        exit 1
    fi
    map_packages brew "$@"
    run brew install "${PACKAGES[@]}"
}

install_system_packages() {
    local command_name required=(curl git gpg groff less tar tmux unzip vim zsh)
    local missing=()

    case "$OS_ID" in
        ubuntu | debian | amzn | fedora | rhel | macos) ;;
        *)
            printf 'Error: unsupported operating system: %s %s\n' "$OS_ID" "$OS_VERSION_ID" >&2
            exit 1
            ;;
    esac

    if [[ "$OS_ID" != "rhel" ]]; then
        required+=(htop)
    fi
    if [[ "$DRY_RUN" == "1" ]]; then
        missing=("${required[@]}")
    else
        for command_name in "${required[@]}"; do
            if ! command -v "$command_name" >/dev/null; then
                missing+=("$command_name")
            fi
        done
    fi
    if ((${#missing[@]} == 0)); then
        return
    fi

    case "$OS_ID" in
        ubuntu | debian)
            ensure_sudo
            install_apt_packages "${missing[@]}"
            ;;
        amzn)
            ensure_sudo
            install_amazon_packages "${missing[@]}"
            ;;
        fedora | rhel)
            ensure_sudo
            install_dnf_packages "${missing[@]}"
            ;;
        macos)
            install_macos_packages "${missing[@]}"
            ;;
    esac
}

asdf_target() {
    local machine os
    machine="$(uname -m)"
    os="$(uname -s)"

    case "$os:$machine" in
        Linux:x86_64)
            ASDF_ASSET="linux-amd64"
            ASDF_SHA256="9c25e1af7cc4c9d59ff3736eba14fd000480c32929258f80d8c5a8b290ebee14"
            ;;
        Linux:aarch64 | Linux:arm64)
            ASDF_ASSET="linux-arm64"
            ASDF_SHA256="bbc1889886a9826ce3f57f56e4bae575767a4af3d35d649d62116ee14334e59a"
            ;;
        Darwin:x86_64)
            ASDF_ASSET="darwin-amd64"
            ASDF_SHA256="8217f33fd165131546aa034f3dabd1a6978cced71c271b4079b4f880965554c1"
            ;;
        Darwin:arm64 | Darwin:aarch64)
            ASDF_ASSET="darwin-arm64"
            ASDF_SHA256="cc94a8cb12bd9692cd760ca184291552fd7206cf8306e51e4de45db94eea3cb5"
            ;;
        *)
            printf 'Error: unsupported asdf target: %s %s\n' "$os" "$machine" >&2
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

install_asdf() {
    if [[ -x "$HOME/.local/bin/asdf" ]] &&
        [[ "$("$HOME/.local/bin/asdf" version)" == "v$ASDF_VERSION"* ]]; then
        return
    fi

    local archive temp_dir url
    asdf_target
    temp_dir="$(mktemp -d)"
    TEMP_PATHS+=("$temp_dir")
    archive="$temp_dir/asdf.tar.gz"
    url="https://github.com/asdf-vm/asdf/releases/download/v${ASDF_VERSION}/asdf-v${ASDF_VERSION}-${ASDF_ASSET}.tar.gz"

    download --output "$archive" "$url"
    verify_sha256 "$ASDF_SHA256" "$archive"
    tar -xzf "$archive" -C "$temp_dir"
    mkdir -p "$HOME/.local/bin"
    install -m 0755 "$temp_dir/asdf" "$HOME/.local/bin/asdf"
}

install_asdf_plugin() {
    local commit="$3" name="$1" plugin_dir url="$2"
    plugin_dir="$HOME/.asdf/plugins/$name"

    install_git_checkout "$plugin_dir" "$url" "$commit" bin/install
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
    wait_for_jobs "${PIDS[@]}"
    PIDS=()
}

install_asdf_plugins() {
    run_job install_asdf_plugin nodejs https://github.com/asdf-vm/asdf-nodejs.git "$ASDF_NODEJS_COMMIT"
    run_job install_asdf_plugin uv https://github.com/asdf-community/asdf-uv.git "$ASDF_UV_COMMIT"
    run_job install_asdf_plugin awscli https://github.com/MetricMike/asdf-awscli.git "$ASDF_AWSCLI_COMMIT"
    run_job install_asdf_plugin github-cli https://github.com/bartlomiejdanek/asdf-github-cli.git "$ASDF_GITHUB_CLI_COMMIT"
    run_job install_asdf_plugin starship https://github.com/gr1m0h/asdf-starship.git "$ASDF_STARSHIP_COMMIT"
    run_job install_asdf_plugin terraform https://github.com/asdf-community/asdf-hashicorp.git "$ASDF_TERRAFORM_COMMIT"
    finish_jobs
}

install_asdf_tool() {
    cd "$HOME"
    "$HOME/.local/bin/asdf" install "$1" "$2"
}

install_asdf_tools() {
    local tool version
    while read -r tool version; do
        [[ -z "$tool" || "$tool" == \#* ]] && continue
        if [[ "$OS_ID" == "amzn" && "$OS_VERSION_ID" == "2" && "$tool" == "nodejs" ]]; then
            printf 'Skipping Node.js %s: Amazon Linux 2 glibc is unsupported.\n' "$version"
            continue
        fi
        run_job install_asdf_tool "$tool" "$version"
    done <"$REPO_DIR/.tool-versions"
    finish_jobs
    "$HOME/.local/bin/asdf" reshim

    ASDF_UV_VERSION="$UV_VERSION" "$HOME/.asdf/shims/uv" \
        --preview-features python-install-default python install --default "$PYTHON_VERSION"

    mkdir -p "$HOME/.asdf/completions"
    "$HOME/.local/bin/asdf" completion zsh >"$HOME/.asdf/completions/_asdf"
}

install_zsh_plugins() {
    local plugin_root="$HOME/.local/share/zsh/plugins"
    run_job install_git_checkout "$plugin_root/autosuggestions" https://github.com/zsh-users/zsh-autosuggestions.git \
        "$ZSH_AUTOSUGGESTIONS_COMMIT" zsh-autosuggestions.zsh
    run_job install_git_checkout "$plugin_root/syntax-highlighting" https://github.com/zsh-users/zsh-syntax-highlighting.git \
        "$ZSH_SYNTAX_HIGHLIGHTING_COMMIT" zsh-syntax-highlighting.zsh
    run_job install_git_checkout "$plugin_root/history-substring-search" https://github.com/zsh-users/zsh-history-substring-search.git \
        "$ZSH_HISTORY_SEARCH_COMMIT" zsh-history-substring-search.zsh
    finish_jobs
}

install_vim_plugins() {
    local package_root="$HOME/.vim/pack/dotfiles/start"
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
        if [[ -e "$destination" ]] && ! cmp -s "$source" "$destination"; then
            cp -a "$destination" "${destination}.backup-${BACKUP_SUFFIX}"
            printf 'Backed up %s\n' "$destination"
        fi
        install -m 0644 "$source" "$destination"
    done <<EOF
$REPO_DIR/starship.toml|$HOME/.config/starship.toml
$REPO_DIR/.zshrc|$HOME/.zshrc
$REPO_DIR/.vimrc|$HOME/.vimrc
$REPO_DIR/.tool-versions|$HOME/.tool-versions
$REPO_DIR/.tmux.conf|$HOME/.tmux.conf
EOF
}

detect_os
printf 'Detected OS: %s %s\n' "$OS_ID" "$OS_VERSION_ID"
install_system_packages

if [[ "$DRY_RUN" == "1" ]]; then
    exit 0
fi

install_asdf
install_asdf_plugins
install_zsh_plugins
install_vim_plugins
install_config
install_asdf_tools

printf 'Dotfiles installed. Start zsh or run: chsh -s %q\n' "$(command -v zsh)"
