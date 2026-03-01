#!/bin/bash
# Firewall: UFW firewall setup
[[ -z $OMARCHY_SERVER_HELPERS ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up UFW firewall..."

pkg_install ufw

# Allow SSH before enabling (don't lock yourself out!)
sudo ufw allow ssh

# Enable firewall
sudo ufw --force enable
sudo systemctl enable ufw

success "UFW firewall enabled (SSH allowed)"
info "Add more rules with: sudo ufw allow <port>"
