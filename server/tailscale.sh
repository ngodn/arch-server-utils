#!/bin/bash
# Tailscale: Mesh VPN for secure server networking
[[ -z ${OMARCHY_SERVER_HELPERS:-} ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up Tailscale..."

# Install via official script (handles Arch repos automatically)
curl -fsSL https://tailscale.com/install.sh | sh

# Enable and start
sudo systemctl enable --now tailscaled

info "Starting Tailscale..."
sudo tailscale up --accept-routes

success "Tailscale installed and connected"
info "Manage at: https://login.tailscale.com/admin/machines"
