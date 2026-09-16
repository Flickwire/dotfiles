#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR
readonly NVM_COMMIT="f0b0c6bb0b281ceeb106c8cf9ab8fde141215092" # v0.40.7
readonly COREPACK_VERSION="0.36.0"
readonly STARSHIP_VERSION="1.26.0"
readonly AWSCLI_VERSION="2.36.45"
readonly ZSH_AUTOSUGGESTIONS_COMMIT="85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5"
readonly ZSH_SYNTAX_HIGHLIGHTING_COMMIT="2fc57d63067c18b1100ecdbf684fa5baf49459d1"
readonly ZSH_HISTORY_SEARCH_COMMIT="14c8d2e0ffaee98f2df9850b19944f32546fdea5"
readonly VIM_AIRLINE_COMMIT="ae24f4aca06731d5d7224df1fc5415975331b214"
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
export NVM_DIR="$HOME/.nvm"
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
    OS_CODENAME=""
    if [[ -z "$OS_ID" ]]; then
        if [[ "$(uname -s)" == "Darwin" ]]; then
            OS_ID="macos"
            OS_VERSION_ID="$(sw_vers -productVersion)"
        elif [[ -r /etc/os-release ]]; then
            # shellcheck disable=SC1091
            source /etc/os-release
            OS_ID="$ID"
            OS_VERSION_ID="${VERSION_ID:-}"
            OS_CODENAME="${VERSION_CODENAME:-}"
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
    local required=(curl git gpg groff htop less tar tmux unzip vim zsh)

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
            install_packages ca-certificates curl git gnupg groff-base htop less libatomic1 tar tmux unzip vim zsh software-properties-common
            ;;
        amzn)
            ensure_sudo
            install_packages ca-certificates curl git gnupg2 groff-base htop less libatomic tar tmux unzip vim-enhanced zsh
            ;;
        macos)
            if [[ "$DRY_RUN" != "1" ]] && ! command -v brew >/dev/null; then
                printf 'Error: Homebrew is required on macOS: https://brew.sh\n' >&2
                exit 1
            fi
            run brew update
            install_packages ca-certificates curl git gnupg groff htop less tmux unzip vim zsh
            ;;
    esac
}

apt_has_package() {
    local candidate
    candidate="$(apt-cache policy "$1" | awk '/Candidate:/ {print $2; exit}')"
    [[ -n "$candidate" && "$candidate" != "(none)" ]]
}

install_native_tools() {
    local temp_dir
    temp_dir="$(mktemp -d)"
    TEMP_PATHS+=("$temp_dir")
    case "$OS_ID" in
        ubuntu)
            "${SUDO[@]}" add-apt-repository -y universe
            download --output "$temp_dir/githubcli.gpg" https://cli.github.com/packages/githubcli-archive-keyring.gpg
            download --output "$temp_dir/hashicorp.asc" https://apt.releases.hashicorp.com/gpg
            gpg --batch --yes --dearmor --output "$temp_dir/hashicorp.gpg" "$temp_dir/hashicorp.asc"
            "${SUDO[@]}" install -d -m 0755 /etc/apt/keyrings
            "${SUDO[@]}" install -m 0644 "$temp_dir/githubcli.gpg" /etc/apt/keyrings/githubcli.gpg
            "${SUDO[@]}" install -m 0644 "$temp_dir/hashicorp.gpg" /etc/apt/keyrings/hashicorp.gpg
            printf 'deb [arch=%s signed-by=/etc/apt/keyrings/githubcli.gpg] https://cli.github.com/packages stable main\n' \
                "$(dpkg --print-architecture)" | "${SUDO[@]}" tee /etc/apt/sources.list.d/github-cli.list >/dev/null
            printf 'deb [arch=%s signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com %s main\n' \
                "$(dpkg --print-architecture)" "$OS_CODENAME" | "${SUDO[@]}" tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
            "${SUDO[@]}" apt-get update
            if ! apt_has_package python3.14; then
                "${SUDO[@]}" add-apt-repository -y ppa:deadsnakes/ppa
                "${SUDO[@]}" apt-get update
            fi
            install_packages python3.14 python3.14-venv gh terraform
            if apt_has_package awscli; then
                install_packages awscli
                remove_fallback_links aws aws_completer
            else
                install_awscli
            fi
            if apt_has_package starship; then
                install_packages starship
                remove_fallback_links starship
            else
                install_starship
            fi
            ;;
        amzn)
            download --output "$temp_dir/gh-cli.repo" https://cli.github.com/packages/rpm/gh-cli.repo
            download --output "$temp_dir/hashicorp.repo" https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
            "${SUDO[@]}" install -m 0644 "$temp_dir/gh-cli.repo" /etc/yum.repos.d/gh-cli.repo
            "${SUDO[@]}" install -m 0644 "$temp_dir/hashicorp.repo" /etc/yum.repos.d/hashicorp.repo
            install_packages python3.14 python3.14-pip awscli-2 gh terraform
            remove_fallback_links aws aws_completer
            if "${SUDO[@]}" dnf --releasever=latest info starship >/dev/null 2>&1; then
                install_packages starship
                remove_fallback_links starship
            else
                install_starship
            fi
            ;;
        macos)
            brew tap hashicorp/tap
            install_packages python@3.14 awscli gh starship hashicorp/tap/terraform
            remove_fallback_links aws aws_completer starship
            ;;
    esac
}

remove_fallback_links() {
    local tool target
    for tool in "$@"; do
        case "$tool" in
            starship) target="$HOME/.local/lib/dotfiles/starship" ;;
            *) target="$HOME/.local/aws-cli/v2/current/bin/$tool" ;;
        esac
        if [[ -L "$HOME/.local/bin/$tool" ]] &&
            [[ "$(readlink "$HOME/.local/bin/$tool")" == "$target" ]]; then
            rm -- "$HOME/.local/bin/$tool"
        fi
    done
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
    local arch checksum temp_dir
    case "$(uname -m)" in
        x86_64)
            arch=x86_64
            checksum=b7c232b0e8249d8e55a40beb79c5c43a7d370f3f9408bd215deb0170daeaadf3
            ;;
        arm64 | aarch64)
            arch=aarch64
            checksum=dc30189378d2f2e287384e8a692d3f95ad1df64cf0e8c36aa9201516028aed6b
            ;;
    esac
    temp_dir="$(mktemp -d)"
    TEMP_PATHS+=("$temp_dir")
    download --output "$temp_dir/starship.tar.gz" \
        "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/starship-${arch}-unknown-linux-musl.tar.gz"
    verify_sha256 "$checksum" "$temp_dir/starship.tar.gz"
    tar -xzf "$temp_dir/starship.tar.gz" -C "$temp_dir"
    mkdir -p "$HOME/.local/bin" "$HOME/.local/lib/dotfiles"
    install -m 0755 "$temp_dir/starship" "$HOME/.local/lib/dotfiles/starship"
    ln -sfn "$HOME/.local/lib/dotfiles/starship" "$HOME/.local/bin/starship"
}

install_awscli() {
    local arch checksum temp_dir
    case "$(uname -m)" in
        x86_64)
            arch=x86_64
            checksum=0f02381483b0a5ca127a4cb379e656a73007b346561a5e41d3249d3bc1861226
            ;;
        arm64 | aarch64)
            arch=aarch64
            checksum=a10b80249b10c8fe9d433a42ee90d34c60cf50089b7e65d45c8d75e782c921ec
            ;;
    esac
    temp_dir="$(mktemp -d)"
    TEMP_PATHS+=("$temp_dir")
    download --output "$temp_dir/awscli.zip" \
        "https://awscli.amazonaws.com/awscli-exe-linux-${arch}-${AWSCLI_VERSION}.zip"
    verify_sha256 "$checksum" "$temp_dir/awscli.zip"
    unzip -q "$temp_dir/awscli.zip" -d "$temp_dir"
    "$temp_dir/aws/install" --install-dir "$HOME/.local/aws-cli" --bin-dir "$HOME/.local/bin" --update
}

configure_python() {
    local python
    if [[ "$OS_ID" == "macos" ]]; then
        python="$(brew --prefix python@3.14)/bin/python3.14"
    else
        python=/usr/bin/python3.14
    fi
    "$python" -c 'import sys; assert sys.version_info[:2] == (3, 14)'
    mkdir -p "$HOME/.local/bin"
    # Keep the OS interpreter intact; development commands use one native install.
    ln -sfn "$python" "$HOME/.local/bin/python"
    ln -sfn "$python" "$HOME/.local/bin/python3"
    ln -sfn "$python" "$HOME/.local/bin/python3.14"
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

install_node() {
    local node_version
    node_version="$(<"$REPO_DIR/.nvmrc")"
    install_git_checkout "$NVM_DIR" https://github.com/nvm-sh/nvm.git "$NVM_COMMIT" nvm.sh
    # nvm is sourced shell code and does not support nounset.
    set +u
    # shellcheck source=/dev/null
    source "$NVM_DIR/nvm.sh" --no-use
    nvm install "$node_version"
    nvm alias default "$node_version"
    nvm use default
    npm install --global "corepack@$COREPACK_VERSION"
    corepack enable
    set -u
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
        if [[ -e "$destination" ]] && ! cmp -s "$source" "$destination"; then
            cp -a "$destination" "${destination}.backup-${BACKUP_SUFFIX}"
            printf 'Backed up %s\n' "$destination"
        fi
        install -m 0644 "$source" "$destination"
    done <<EOF
$REPO_DIR/starship.toml|$HOME/.config/starship.toml
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
install_native_tools
configure_python
install_node
install_plugins
install_config
printf 'Dotfiles installed. Start zsh or run: chsh -s %q\n' "$(command -v zsh)"
