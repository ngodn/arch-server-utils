#!/bin/bash
# CLI Tools: Modern replacements for common commands
[[ -z $OMARCHY_SERVER_HELPERS ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up CLI Tools..."

pkg_install \
  btop \
  dust \
  fd \
  fastfetch \
  jq \
  plocate \
  ripgrep \
  tldr \
  tree

# Update plocate database
if command -v updatedb &>/dev/null; then
  info "Updating plocate database..."
  sudo updatedb 2>/dev/null || true
fi

success "CLI tools installed (btop, dust, fd, fastfetch, jq, plocate, ripgrep, tldr, tree)"
