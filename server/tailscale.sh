#!/bin/bash
# Tailscale: Mesh VPN for secure server networking
[[ -z ${OMARCHY_SERVER_HELPERS:-} ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up Tailscale..."

pkg_install tailscale

svc enable tailscaled
if svc start tailscaled 2>/dev/null; then
  info "Starting Tailscale..."
  sudo tailscale up --accept-routes
  success "Tailscale installed and connected"
else
  success "Tailscale installed (start with: sudo tailscale up --accept-routes)"
fi

info "Manage at: https://login.tailscale.com/admin/machines"
