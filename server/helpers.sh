#!/bin/bash
# Shared helper functions for Omarchy Server Setup

OMARCHY_SERVER_HELPERS=1

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()    { echo -e "  ${CYAN}::${NC} $1"; }
success() { echo -e "  ${GREEN}OK${NC} $1"; }
warn()    { echo -e "  ${YELLOW}!!${NC} $1"; }
error()   { echo -e "  ${RED}**${NC} $1"; }

pkg_install() {
  local to_install=()

  for pkg in "$@"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
      to_install+=("$pkg")
    fi
  done

  if (( ${#to_install[@]} > 0 )); then
    info "Installing: ${to_install[*]}"
    sudo pacman -S --noconfirm --needed "${to_install[@]}"
  else
    info "Already installed: $*"
  fi
}

aur_install() {
  if ! command -v yay &>/dev/null; then
    warn "yay not found, skipping AUR packages: $*"
    return 1
  fi

  local to_install=()

  for pkg in "$@"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
      to_install+=("$pkg")
    fi
  done

  if (( ${#to_install[@]} > 0 )); then
    info "Installing (AUR): ${to_install[*]}"
    yay -S --noconfirm --needed "${to_install[@]}"
  else
    info "Already installed: $*"
  fi
}

# Service manager wrapper: uses serviced in chroot, systemctl otherwise
svc() {
  if pidof systemd &>/dev/null; then
    sudo systemctl "$@"
  elif command -v serviced &>/dev/null; then
    sudo serviced "$@"
  else
    warn "No service manager available, skipping: systemctl $*"
    return 1
  fi
}

ensure_dir() {
  mkdir -p "$1"
}

backup_file() {
  if [[ -f $1 && ! -L $1 ]]; then
    cp "$1" "$1.bak.$(date +%s)"
    info "Backed up $1"
  fi
}
