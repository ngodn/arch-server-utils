#!/bin/bash
# Docker: Docker + Compose + Buildx + Lazydocker
[[ -z ${OMARCHY_SERVER_HELPERS:-} ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up Docker..."

pkg_install docker docker-compose docker-buildx

# Lazydocker is in AUR
aur_install lazydocker

# Configure Docker daemon (log rotation + DNS)
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json >/dev/null << 'EOF'
{
    "log-driver": "json-file",
    "log-opts": { "max-size": "10m", "max-file": "5" },
    "dns": ["172.17.0.1"],
    "bip": "172.17.0.1/16"
}
EOF

# Expose systemd-resolved to Docker network
sudo mkdir -p /etc/systemd/resolved.conf.d
echo -e '[Resolve]\nDNSStubListenerExtra=172.17.0.1' | sudo tee /etc/systemd/resolved.conf.d/20-docker-dns.conf >/dev/null
svc restart systemd-resolved 2>/dev/null || true

# Start Docker on-demand via socket activation
svc enable docker.socket

# Give current user privileged Docker access
sudo usermod -aG docker "${USER}"

# Prevent Docker from blocking boot on network-online.target
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/no-block-boot.conf >/dev/null << 'EOF'
[Unit]
DefaultDependencies=no
EOF

svc daemon-reload 2>/dev/null || true

success "Docker installed and configured"
info "Log out and back in for docker group membership to take effect"
