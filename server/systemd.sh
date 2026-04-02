#!/bin/bash
# Systemd: Faster shutdown timeout
[[ -z ${OMARCHY_SERVER_HELPERS:-} ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up Systemd tweaks..."

# Reduce shutdown timeout from default 90s to 5s
sudo mkdir -p /etc/systemd/system.conf.d
sudo tee /etc/systemd/system.conf.d/faster-shutdown.conf >/dev/null << 'EOF'
[Manager]
DefaultTimeoutStopSec=5s
EOF

svc daemon-reload 2>/dev/null || true

success "Systemd shutdown timeout set to 5s"
