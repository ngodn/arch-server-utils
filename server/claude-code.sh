#!/bin/bash
# Claude Code: AI coding assistant for the terminal
[[ -z ${OMARCHY_SERVER_HELPERS:-} ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up Claude Code..."

export PATH="$HOME/.local/bin:$PATH"
curl -fsSL https://claude.ai/install.sh | bash

success "Claude Code installed"
info "Run with: claude"
