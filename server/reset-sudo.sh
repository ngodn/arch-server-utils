#!/bin/bash
# Server Tools: Reset sudo lockout
[[ -z ${OMARCHY_SERVER_HELPERS:-} ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Installing sudo reset tool..."

ensure_dir "$HOME/.local/bin"

cat > "$HOME/.local/bin/omarchy-reset-sudo" << 'EOF'
#!/bin/bash
# Reset the sudo lockout/faillock for the current user.
# Clears any failed authentication attempts that may have locked the user out.
su -c "faillock --reset --user $USER"
echo "Sudo lockout cleared for $USER"
EOF

chmod +x "$HOME/.local/bin/omarchy-reset-sudo"

success "Sudo reset tool installed (omarchy-reset-sudo)"
