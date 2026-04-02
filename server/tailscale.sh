#!/bin/bash
# Tailscale: Mesh VPN for secure server networking
[[ -z ${OMARCHY_SERVER_HELPERS:-} ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up Tailscale..."

pkg_install tailscale

# Detect chroot environment and enable userspace networking
# (avoids TUN device conflicts with Android's Tailscale app)
if ! pidof systemd &>/dev/null; then
  if ! grep -q "userspace-networking" /etc/default/tailscaled 2>/dev/null; then
    sudo sed -i 's|FLAGS=""|FLAGS="--tun=userspace-networking"|' /etc/default/tailscaled
    info "Enabled userspace networking (chroot detected)"
  fi
fi

svc enable tailscaled
svc start tailscaled 2>/dev/null || true

# Wait for socket
sleep 2

# Check if already logged in
if tailscale status &>/dev/null 2>&1; then
  success "Tailscale already connected"
else
  info "Authenticate Tailscale:"
  tailscale up
fi

# Offer to serve code-server over HTTPS
if command -v code-server &>/dev/null || svc status code-server &>/dev/null 2>&1; then
  echo
  read -rp "  Serve code-server over Tailscale HTTPS? [Y/n]: " serve_cs
  serve_cs="${serve_cs:-y}"

  if [[ "$serve_cs" =~ ^[Yy]$ ]]; then
    tailscale serve --bg http://localhost:9301 2>/dev/null && \
      success "Code-server available at: https://$(tailscale status --json 2>/dev/null | grep -o '"DNSName":"[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/\.$//')" || \
      warn "tailscale serve failed — you can run it manually: tailscale serve --bg http://localhost:9301"
  fi
fi

echo
success "Tailscale installed"
info "Manage at: https://login.tailscale.com/admin/machines"