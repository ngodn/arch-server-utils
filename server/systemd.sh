#!/bin/bash
# Systemd: Faster shutdown timeout
[[ -z $OMARCHY_SERVER_HELPERS ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up Systemd tweaks..."

# Reduce shutdown timeout from default 90s to 5s
sudo mkdir -p /etc/systemd/system.conf.d
sudo tee /etc/systemd/system.conf.d/faster-shutdown.conf >/dev/null << 'EOF'
[Manager]
DefaultTimeoutStopSec=5s
EOF

sudo systemctl daemon-reload

success "Systemd shutdown timeout set to 5s"
