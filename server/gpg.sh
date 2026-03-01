#!/bin/bash
# GPG Keys: Multiple fallback keyservers
[[ -z $OMARCHY_SERVER_HELPERS ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up GPG keyservers..."

ensure_dir "$HOME/.gnupg"
chmod 700 "$HOME/.gnupg"

cat > "$HOME/.gnupg/dirmngr.conf" << 'EOF'
keyserver hkps://keyserver.ubuntu.com
keyserver hkps://pgp.surfnet.nl
keyserver hkps://keys.mailvelope.com
keyserver hkps://keyring.debian.org
keyserver hkps://pgp.mit.edu

connect-quick-timeout 4
EOF

# Restart dirmngr to pick up changes
gpgconf --kill dirmngr 2>/dev/null || true

success "GPG configured with 5 fallback keyservers"
