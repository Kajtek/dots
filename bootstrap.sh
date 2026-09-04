#!/usr/bin/env bash
# Bring this setup up from a blank machine.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/Kajtek/dots/master/bootstrap.sh)
#   ./bootstrap.sh --check --diff      # from a checkout: dry run, show what would change
#   ./bootstrap.sh --tags dotfiles     # any ansible-playbook argument passes through
#
# This file only has to work with what a fresh install ships: it installs git and Ansible
# with the distro package manager, clones the repo to $DOTS_DIR (default ~/projects/dots)
# unless it is already running from a checkout, then hands over to ansible/playbook.yml.
# Everything else, including the distro checks, lives in the playbook so it stays
# idempotent and re-runnable.
set -euo pipefail

DOTS_REPO=${DOTS_REPO:-https://github.com/Kajtek/dots.git}
DOTS_DIR=${DOTS_DIR:-$HOME/projects/dots}

# shellcheck source=/dev/null
. /etc/os-release
case $ID in
    arch)   sudo pacman -Syu --needed --noconfirm git ansible ;;
    ubuntu) sudo apt-get update -qq
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git ansible ;;
    *)      echo "bootstrap: unsupported distribution '$ID' (Arch Linux and Ubuntu 26.04 only)" >&2
            exit 1 ;;
esac

# Run from a checkout (./bootstrap.sh) uses that checkout; piped from curl it clones.
here=$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd) || here=
if [[ -n $here && -f $here/ansible/playbook.yml ]]; then
    DOTS_DIR=$here
elif [[ ! -d $DOTS_DIR/.git ]]; then
    git clone "$DOTS_REPO" "$DOTS_DIR"
fi

# Ask for the sudo password only when sudo needs one (containers and CI usually don't).
ask_pass=()
sudo -n true 2>/dev/null || ask_pass=(--ask-become-pass)

cd "$DOTS_DIR/ansible"
exec ansible-playbook "${ask_pass[@]}" playbook.yml "$@"
