#!/bin/bash
# Mise: Version manager (Node, Ruby, Python, etc.)
[[ -z ${OMARCHY_SERVER_HELPERS:-} ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up Mise version manager..."

pkg_install mise

# Create default Work directory with mise config
ensure_dir "$HOME/Work"

if [[ ! -f "$HOME/Work/.mise.toml" ]]; then
  cat > "$HOME/Work/.mise.toml" << 'EOF'
[settings]
experimental = true

[env]
_.path = ["./bin"]
EOF
  success "Created ~/Work/.mise.toml"
fi

# Trust the Work directory
mise trust "$HOME/Work" 2>/dev/null || true

success "Mise installed"
info "Install runtimes with: mise use node@lts, mise use ruby@latest, etc."
