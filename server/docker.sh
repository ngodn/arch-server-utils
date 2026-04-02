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

if pidof systemd &>/dev/null; then
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
  svc restart systemd-resolved 2>/dev/null || true
  svc enable docker.socket

  sudo mkdir -p /etc/systemd/system/docker.service.d
  sudo tee /etc/systemd/system/docker.service.d/no-block-boot.conf >/dev/null << 'CONF'
[Unit]
DefaultDependencies=no
CONF
  svc daemon-reload 2>/dev/null || true
else
  # No systemd (chroot/container): simple config, enable service directly
  sudo tee /etc/docker/daemon.json >/dev/null << 'EOF'
{
    "log-driver": "json-file",
    "log-opts": { "max-size": "10m", "max-file": "5" }
}
EOF
  svc enable docker
  svc start docker 2>/dev/null || true
fi

success "Docker installed and configured"
info "Log out and back in for docker group membership to take effect"
