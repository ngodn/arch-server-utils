#!/bin/bash
# SSH Hardening: TCP MTU probing for connection reliability
[[ -z $OMARCHY_SERVER_HELPERS ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up SSH hardening..."

# Fix SSH flakiness over certain network paths
if ! grep -q "tcp_mtu_probing" /etc/sysctl.d/99-ssh-mtu.conf 2>/dev/null; then
  echo "net.ipv4.tcp_mtu_probing=1" | sudo tee /etc/sysctl.d/99-ssh-mtu.conf >/dev/null
  sudo sysctl -p /etc/sysctl.d/99-ssh-mtu.conf 2>/dev/null || true
  success "TCP MTU probing enabled for SSH reliability"
else
  success "TCP MTU probing already configured"
fi
