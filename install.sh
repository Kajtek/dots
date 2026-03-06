#!/usr/bin/env bash
# Dotfiles installation script using GNU Stow
# Minimal, idempotent, and interactive

set -euo pipefail

# === Colors ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# === Helper Functions ===

error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
info()    { echo -e "${BLUE}[INFO]${RESET} $*"; }
success() { echo -e "${GREEN}[OK]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $*"; }

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --dry-run    Simulate installation (pass --simulate to stow)
  --help       Show this help message

This script installs dotfiles using GNU Stow.
EOF
}

# === Argument Parsing ===
DRY_RUN=false

for arg in "$@"; do
    case $arg in
        --dry-run) DRY_RUN=true ;;
        --help) usage; exit 0 ;;
        *) error "Unknown option: $arg"; usage; exit 1 ;;
    esac
done

# === Environment Checks ===
command -v stow >/dev/null 2>&1 || { error "GNU stow is required."; exit 1; }

# === Determine Repo Root ===
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

PACKAGES=()
for dir in "$REPO_ROOT"/*/; do
    [[ -d "$dir" ]] || continue
    dir_name="$(basename "$dir")"
    PACKAGES+=("$dir_name")
done

if [[ ${#PACKAGES[@]} -eq 0 ]]; then
    error "No stowable packages found"
    exit 1
fi

# === User Selection ===
echo "Available packages:"
for i in "${!PACKAGES[@]}"; do
    printf "  %d) %s\n" $((i+1)) "${PACKAGES[i]}"
done
echo "  a) Install all"

read -rp "Select packages to install (e.g., 1 3 4 or 'a'): " selection

INSTALL_PACKAGES=()
if [[ "$selection" == "a" ]]; then
    INSTALL_PACKAGES=("${PACKAGES[@]}")
else
    for idx in $selection; do
        if [[ "$idx" =~ ^[0-9]+$ ]] && (( idx >= 1 && idx <= ${#PACKAGES[@]} )); then
            INSTALL_PACKAGES+=("${PACKAGES[idx-1]}")
        else
            warn "Skipping invalid selection: $idx"
        fi
    done
fi

# === Install Function ===
install_package() {
    local pkg="$1"
    local stow_opts=("-v")
    $DRY_RUN && stow_opts+=("--simulate")

    info "Installing package: $pkg"
    if ! stow "${stow_opts[@]}" -d "$REPO_ROOT" -t "$HOME" "$pkg"; then
        warn "Conflict detected for $pkg"
        while true; do
            read -rp "Choose action: [s]kip, [o]verwrite, [b]ackup: " action
            case "$action" in
                s) warn "Skipping $pkg"; return ;;
                o) echo "FIRST TRY"
                   stow -D -d "$REPO_ROOT" -t "$HOME" "$pkg" >/dev/null 2>&1 || true
                   echo "SECOND TRY"
                   stow "${stow_opts[@]}" -d "$REPO_ROOT" -t "$HOME" "$pkg"
                   echo "THIRD TRY"
                   success "Overwritten $pkg"; return ;;
                b) stow -D -d "$REPO_ROOT" -t "$HOME" "$pkg" --adopt >/dev/null 2>&1 || true
                   stow "${stow_opts[@]}" -d "$REPO_ROOT" -t "$HOME" "$pkg"
                   success "Backed up and installed $pkg"; return ;;
                *) echo "Invalid choice";;
            esac
        done
    else
        success "Installed $pkg"
    fi
}

# === Main Installation Loop ===
for pkg in "${INSTALL_PACKAGES[@]}"; do
    install_package "$pkg"
done

success "All selected packages processed."
