#!/bin/bash
# Docker: Docker + Compose + Buildx + Lazydocker
[[ -z ${OMARCHY_SERVER_HELPERS:-} ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up Docker..."

pkg_install docker docker-compose docker-buildx

# Lazydocker is in AUR
aur_install lazydocker

# Give current user privileged Docker access
sudo usermod -aG docker "${USER}"

sudo mkdir -p /etc/docker

if (( OMARCHY_IS_CHROOT_DISTRO )); then
  # chroot-distro: overlay2 + iptables-legacy for Android kernel
  sudo tee /etc/docker/daemon.json >/dev/null << 'EOF'
{
    "storage-driver": "overlay2",
    "iptables": true,
    "dns": ["8.8.8.8", "1.1.1.1"],
    "log-driver": "json-file",
    "log-opts": { "max-size": "10m", "max-file": "3" }
}
EOF

  # Docker requires iptables-legacy on Android kernels
  if command -v update-alternatives &>/dev/null; then
    sudo update-alternatives --set iptables /usr/sbin/iptables-legacy 2>/dev/null || true
    sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy 2>/dev/null || true
  elif [[ -f /usr/sbin/iptables-legacy ]]; then
    sudo ln -sf /usr/sbin/iptables-legacy /usr/local/bin/iptables
    sudo ln -sf /usr/sbin/ip6tables-legacy /usr/local/bin/ip6tables
  fi

  write_serviced_unit "docker" "/usr/bin/dockerd" \
    --description "Docker Daemon" \
    --restart "on-failure"
  enable_service docker
elif (( OMARCHY_HAS_SYSTEMD )); then
  # Full systemd: socket activation + resolved DNS bridge
  sudo tee /etc/docker/daemon.json >/dev/null << 'EOF'
{
    "log-driver": "json-file",
    "log-opts": { "max-size": "10m", "max-file": "5" },
    "dns": ["172.17.0.1"],
    "bip": "172.17.0.1/16"
}
EOF
  sudo mkdir -p /etc/systemd/resolved.conf.d
  echo -e '[Resolve]\nDNSStubListenerExtra=172.17.0.1' | sudo tee /etc/systemd/resolved.conf.d/20-docker-dns.conf >/dev/null
  restart_service systemd-resolved
  enable_service docker.socket

  sudo mkdir -p /etc/systemd/system/docker.service.d
  sudo tee /etc/systemd/system/docker.service.d/no-block-boot.conf >/dev/null << 'CONF'
[Unit]
DefaultDependencies=no
CONF
  svc daemon-reload 2>/dev/null || true
else
  # No systemd, no chroot-distro: simple config
  sudo tee /etc/docker/daemon.json >/dev/null << 'EOF'
{
    "log-driver": "json-file",
    "log-opts": { "max-size": "10m", "max-file": "5" }
}
EOF
  enable_service docker
fi

success "Docker installed and configured"
info "Log out and back in for docker group membership to take effect"
