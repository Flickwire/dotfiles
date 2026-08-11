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
readonly ZPLUG_COMMIT="8f14b4850d8e410f00db92afcd87b88c0c90f771"
readonly VIM_PLUG_COMMIT="88e31471818e9a29a8a20a0ee61360cfd7bdc1cd"
readonly VIM_PLUG_SHA256="7e2b20cd909da9c456498684c98f03c63829170f01e34595dd8e1818a217d37c"
readonly UV_VERSION="0.12.3"
readonly PYTHON_VERSION="3.14.7"
BACKUP_SUFFIX="$(date +%Y%m%d%H%M%S)"
readonly BACKUP_SUFFIX
readonly DRY_RUN="${DOTFILES_DRY_RUN:-0}"

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
        apt-get install -y curl git groff-base htop less tmux unzip vim zsh
}

install_amazon_packages() {
    if [[ "$OS_VERSION_ID" == "2" ]]; then
        run "${SUDO[@]}" yum install -y curl git groff-base htop less tmux unzip \
            vim-enhanced zsh
        return
    fi

    if [[ "$OS_VERSION_ID" != "2023" ]]; then
        printf 'Error: unsupported Amazon Linux release: %s\n' "$OS_VERSION_ID" >&2
        exit 1
    fi

    run "${SUDO[@]}" dnf install -y --allowerasing curl git groff-base htop less \
        tmux unzip vim-enhanced zsh
}

install_dnf_packages() {
    local packages=(curl git groff-base less tmux unzip vim-enhanced zsh)
    if [[ "$OS_ID" == "fedora" ]]; then
        packages+=(htop)
    fi
    run "${SUDO[@]}" dnf install -y "${packages[@]}"
}

install_macos_packages() {
    if [[ "$DRY_RUN" != "1" ]] && ! command -v brew >/dev/null; then
        printf 'Error: Homebrew is required on macOS: https://brew.sh\n' >&2
        exit 1
    fi
    run brew install bash coreutils curl git htop tmux unzip vim zsh
}

install_system_packages() {
    local command_name missing=0 required=(curl git tmux unzip vim zsh)
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
        if ((missing == 0)) && [[ -x "$HOME/.local/bin/python${PYTHON_VERSION%.*}" ]]; then
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

    if [[ ! -d "$plugin_dir/.git" ]]; then
        if [[ -e "$plugin_dir" ]]; then
            printf 'Error: %s exists but is not an asdf plugin checkout.\n' "$plugin_dir" >&2
            exit 1
        fi
        mkdir -p "$HOME/.asdf/plugins"
        git clone --filter=blob:none --no-checkout "$url" "$plugin_dir"
    fi

    if [[ "$(git -C "$plugin_dir" rev-parse HEAD 2>/dev/null || true)" == "$commit" ]] &&
        [[ -x "$plugin_dir/bin/install" ]]; then
        return
    fi

    git -C "$plugin_dir" fetch --depth 1 origin "$commit"
    git -C "$plugin_dir" checkout --detach "$commit"
}

install_asdf_plugins() {
    install_asdf_plugin nodejs https://github.com/asdf-vm/asdf-nodejs.git "$ASDF_NODEJS_COMMIT"
    install_asdf_plugin uv https://github.com/asdf-community/asdf-uv.git "$ASDF_UV_COMMIT"
    install_asdf_plugin awscli https://github.com/MetricMike/asdf-awscli.git "$ASDF_AWSCLI_COMMIT"
    install_asdf_plugin github-cli https://github.com/bartlomiejdanek/asdf-github-cli.git "$ASDF_GITHUB_CLI_COMMIT"
    install_asdf_plugin starship https://github.com/gr1m0h/asdf-starship.git "$ASDF_STARSHIP_COMMIT"
}

install_asdf_tools() {
    local tool version
    while read -r tool version; do
        [[ -z "$tool" || "$tool" == \#* ]] && continue
        "$HOME/.local/bin/asdf" install "$tool" "$version"
    done <"$REPO_DIR/.tool-versions"
    "$HOME/.local/bin/asdf" reshim

    ASDF_UV_VERSION="$UV_VERSION" "$HOME/.asdf/shims/uv" \
        --preview-features python-install-default python install --default "$PYTHON_VERSION"

    mkdir -p "$HOME/.asdf/completions"
    "$HOME/.local/bin/asdf" completion zsh >"$HOME/.asdf/completions/_asdf"
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
$REPO_DIR/.tool-versions|$HOME/.tool-versions
EOF
}

install_plugins() {
    # HOME must expand inside the clean zsh process rather than in this shell.
    # shellcheck disable=SC2016
    env TERM="${TERM:-xterm-256color}" LANG="${LANG:-C.UTF-8}" LC_ALL="${LC_ALL:-C.UTF-8}" \
        zsh -c 'source "$HOME/.zplug/init.zsh"; source "$HOME/.zsh_plugins"; if ! zplug check; then zplug install || true; zplug check; fi'
    vim -Nu "$HOME/.vimrc" -i NONE -es -c 'PlugInstall --sync' -c 'qa!'
}

detect_os
printf 'Detected OS: %s %s\n' "$OS_ID" "$OS_VERSION_ID"
install_system_packages

if [[ "$DRY_RUN" == "1" ]]; then
    exit 0
fi

install_asdf
install_asdf_plugins
install_zplug
install_vim_plug
install_config
install_asdf_tools
install_plugins

printf 'Dotfiles installed. Start zsh or run: chsh -s %q\n' "$(command -v zsh)"
