#!/bin/bash
# Tailscale: Mesh VPN for secure server networking
[[ -z ${OMARCHY_SERVER_HELPERS:-} ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up Tailscale..."

pkg_install tailscale

# systemd isn't available in chroot/container — just enable for next boot
if ! pidof systemd &>/dev/null; then
  sudo systemctl enable tailscaled 2>/dev/null || true
  success "Tailscale installed (will start on next boot with systemd)"
  info "After booting, run: sudo tailscale up --accept-routes"
else
  sudo systemctl enable --now tailscaled
  info "Starting Tailscale..."
  sudo tailscale up --accept-routes
  success "Tailscale installed and connected"
fi

info "Manage at: https://login.tailscale.com/admin/machines"
