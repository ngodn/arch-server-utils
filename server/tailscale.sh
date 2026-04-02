#!/bin/bash
# Tailscale: Mesh VPN for secure server networking
[[ -z ${OMARCHY_SERVER_HELPERS:-} ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up Tailscale..."

pkg_install tailscale

svc enable tailscaled
svc start tailscaled 2>/dev/null || true

success "Tailscale installed"
info "Connect with: sudo tailscale up --accept-routes"
info "Manage at: https://login.tailscale.com/admin/machines"
