#!/bin/bash
# Yay: AUR helper for installing community packages
[[ -z ${OMARCHY_SERVER_HELPERS:-} ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up Yay (AUR helper)..."

if command -v yay &>/dev/null; then
  success "Yay already installed"
  return 0
fi

# Build dependencies
pkg_install base-devel git

# Clone and build yay
TMPDIR=$(mktemp -d)
git clone https://aur.archlinux.org/yay-bin.git "$TMPDIR/yay-bin"
cd "$TMPDIR/yay-bin"
makepkg -si --noconfirm
cd - >/dev/null
rm -rf "$TMPDIR"

success "Yay installed"
