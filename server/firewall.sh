#!/bin/bash
# Firewall: UFW firewall setup
[[ -z ${OMARCHY_SERVER_HELPERS:-} ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up UFW firewall..."

# UFW requires iptables kernel modules — skip in chroot/container environments
if ! sudo iptables -L &>/dev/null; then
  warn "iptables not available (chroot/container?) — skipping firewall setup"
  info "Run this component again after booting into a full system"
  return 0
fi

pkg_install ufw

# Allow SSH before enabling (don't lock yourself out!)
sudo ufw allow ssh

# Enable firewall
sudo ufw --force enable
sudo systemctl enable ufw

success "UFW firewall enabled (SSH allowed)"
info "Add more rules with: sudo ufw allow <port>"
