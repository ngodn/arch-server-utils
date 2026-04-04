#!/bin/bash
# SSH Hardening: SSH server with hardened defaults
[[ -z ${OMARCHY_SERVER_HELPERS:-} ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up SSH server..."

pkg_install openssh

# Prompt for port
echo
read -rp "  SSH port [8622]: " ssh_port
ssh_port="${ssh_port:-8622}"

# Generate host keys if missing
sudo ssh-keygen -A 2>/dev/null

# Configure sshd
sudo tee /etc/ssh/sshd_config.d/99-omarchy-server.conf >/dev/null << EOF
Port $ssh_port
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
X11Forwarding no
MaxAuthTries 3
EOF

# Fix SSH flakiness over certain network paths
if ! grep -q "tcp_mtu_probing" /etc/sysctl.d/99-ssh-mtu.conf 2>/dev/null; then
  echo "net.ipv4.tcp_mtu_probing=1" | sudo tee /etc/sysctl.d/99-ssh-mtu.conf >/dev/null
  sudo sysctl -p /etc/sysctl.d/99-ssh-mtu.conf 2>/dev/null || true
fi

# Write optimized serviced unit for chroot-distro
if (( OMARCHY_IS_CHROOT_DISTRO )); then
  write_serviced_unit "sshd" "/usr/bin/sshd -D" \
    --description "OpenSSH Daemon" \
    --restart "on-failure"
fi

# Enable and start sshd
enable_service sshd

success "SSH server configured on port $ssh_port"
info "Root login disabled. Connect with: ssh ${USER}@<server-ip> -p $ssh_port"
