#!/bin/bash
# Git Tools: Lazygit + GitHub CLI
[[ -z $OMARCHY_SERVER_HELPERS ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up Git Tools..."

pkg_install lazygit github-cli

success "Git tools installed (lazygit, gh)"
