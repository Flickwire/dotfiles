#!/usr/bin/env bash

set -euo pipefail

readonly SSM_USER="ssm-user"
readonly DOTFILES_REPOSITORY="${DOTFILES_REPOSITORY:-https://github.com/Flickwire/dotfiles.git}"
readonly DOTFILES_REF="${DOTFILES_REF:-main}"

if [[ "$(id -u)" -ne 0 ]]; then
    printf 'Error: EC2 user data must run as root.\n' >&2
    exit 1
fi

# shellcheck source=/dev/null
source /etc/os-release
if [[ "$ID" != "amzn" || "$VERSION_ID" != "2023" ]]; then
    printf 'Error: this user-data script supports Amazon Linux 2023 only.\n' >&2
    exit 1
fi

dnf install -y --allowerasing \
    curl git gnupg2 groff-base htop less sudo tar tmux unzip util-linux vim-enhanced zsh

if ! id "$SSM_USER" >/dev/null 2>&1; then
    useradd --create-home --shell /bin/bash "$SSM_USER"
fi

SSM_HOME="$(getent passwd "$SSM_USER" | cut -d: -f6)"
SSM_GROUP="$(id -gn "$SSM_USER")"
readonly SSM_HOME SSM_GROUP
readonly CHECKOUT_DIR="$SSM_HOME/.local/src/dotfiles"
readonly SUDOERS_FILE="/etc/sudoers.d/90-ssm-user-dotfiles"

run_as_ssm_user() {
    runuser -u "$SSM_USER" -- env HOME="$SSM_HOME" "$@"
}

printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$SSM_USER" >"$SUDOERS_FILE"
chmod 0440 "$SUDOERS_FILE"
visudo -cf "$SUDOERS_FILE" >/dev/null

install -d -m 0755 -o "$SSM_USER" -g "$SSM_GROUP" \
    "$SSM_HOME/.local" "$(dirname -- "$CHECKOUT_DIR")"

if [[ -e "$CHECKOUT_DIR" && ! -d "$CHECKOUT_DIR/.git" ]]; then
    printf 'Error: %s exists but is not a Git checkout.\n' "$CHECKOUT_DIR" >&2
    exit 1
fi

if [[ ! -d "$CHECKOUT_DIR/.git" ]]; then
    run_as_ssm_user git clone --filter=blob:none --no-checkout \
        "$DOTFILES_REPOSITORY" "$CHECKOUT_DIR"
elif [[ "$(run_as_ssm_user git -C "$CHECKOUT_DIR" remote get-url origin)" != \
    "$DOTFILES_REPOSITORY" ]]; then
    printf 'Error: %s has an unexpected origin.\n' "$CHECKOUT_DIR" >&2
    exit 1
fi

run_as_ssm_user git -C "$CHECKOUT_DIR" fetch --depth 1 origin "$DOTFILES_REF"
run_as_ssm_user git -C "$CHECKOUT_DIR" checkout --detach FETCH_HEAD
run_as_ssm_user bash "$CHECKOUT_DIR/install.sh"

usermod --shell "$(command -v zsh)" "$SSM_USER"
printf 'Dotfiles installed for %s from %s at %s.\n' \
    "$SSM_USER" "$DOTFILES_REPOSITORY" "$DOTFILES_REF"
