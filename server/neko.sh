#!/bin/bash
# Neko: Virtual browsers in Docker (Firefox + Google Chrome)
[[ -z ${OMARCHY_SERVER_HELPERS:-} ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up Neko virtual browsers..."

if ! command -v docker &>/dev/null; then
  error "Docker is required for Neko. Select the Docker component first."
  return 1
fi

# Prompt for passwords
echo
read -rp "  User password [neko]: " neko_user_pass
neko_user_pass="${neko_user_pass:-neko}"

read -rp "  Admin password [admin]: " neko_admin_pass
neko_admin_pass="${neko_admin_pass:-admin}"

# Detect server IP for WebRTC
SERVER_IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
read -rp "  Server IP for WebRTC [$SERVER_IP]: " neko_ip
neko_ip="${neko_ip:-$SERVER_IP}"

# Create config directory and persistent profile dirs
ensure_dir "$HOME/.config/neko"
ensure_dir "$HOME/.neko/firefox"
ensure_dir "$HOME/.neko/google-chrome"

# Generate docker-compose.yml
cat > "$HOME/.config/neko/docker-compose.yml" << EOF
services:
  firefox:
    image: ghcr.io/m1k1o/neko/firefox:latest
    container_name: neko-firefox
    restart: unless-stopped
    shm_size: "8gb"
    ports:
      - "9311:8080"
      - "52000-52049:52000-52049/udp"
    environment:
      NEKO_DESKTOP_SCREEN: "1194x834@30"
      NEKO_WEBRTC_EPR: "52000-52049"
      NEKO_WEBRTC_ICELITE: 1
      NEKO_WEBRTC_NAT1TO1: "$neko_ip"
      NEKO_MEMBER_MULTIUSER_USER_PASSWORD: "$neko_user_pass"
      NEKO_MEMBER_MULTIUSER_ADMIN_PASSWORD: "$neko_admin_pass"
    volumes:
      - \$HOME/.neko/firefox:/home/neko/.mozilla/firefox

  google-chrome:
    image: ghcr.io/m1k1o/neko/google-chrome:latest
    container_name: neko-google-chrome
    restart: unless-stopped
    shm_size: "8gb"
    cap_add:
      - SYS_ADMIN
    ports:
      - "9312:8080"
      - "52050-52099:52050-52099/udp"
    environment:
      NEKO_DESKTOP_SCREEN: "1194x834@30"
      NEKO_WEBRTC_EPR: "52050-52099"
      NEKO_WEBRTC_ICELITE: 1
      NEKO_WEBRTC_NAT1TO1: "$neko_ip"
      NEKO_MEMBER_MULTIUSER_USER_PASSWORD: "$neko_user_pass"
      NEKO_MEMBER_MULTIUSER_ADMIN_PASSWORD: "$neko_admin_pass"
    volumes:
      - \$HOME/.neko/google-chrome:/home/neko/.config/google-chrome
EOF

# Start the containers
info "Pulling and starting Neko containers..."
docker compose -f "$HOME/.config/neko/docker-compose.yml" up -d

success "Neko virtual browsers running"
echo
info "Firefox:       http://$neko_ip:9311"
info "Google Chrome: http://$neko_ip:9312"
echo
info "Config: ~/.config/neko/docker-compose.yml"
info "Profiles: ~/.neko/firefox, ~/.neko/google-chrome"
echo
info "Stop:   docker compose -f ~/.config/neko/docker-compose.yml down"
info "Update: docker compose -f ~/.config/neko/docker-compose.yml pull && docker compose -f ~/.config/neko/docker-compose.yml up -d"
