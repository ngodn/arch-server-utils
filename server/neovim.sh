#!/bin/bash
# Neovim: Modern terminal editor
[[ -z $OMARCHY_SERVER_HELPERS ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up Neovim..."

pkg_install neovim

# Set as default editor if not already set
if [[ -z $EDITOR ]] || [[ $EDITOR != "nvim" ]]; then
  info "Tip: Set EDITOR=nvim in your environment to use neovim as default"
fi

success "Neovim installed"
