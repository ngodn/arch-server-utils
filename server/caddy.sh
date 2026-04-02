#!/bin/bash
# Caddy Reverse Proxy: HTTPS for local services via mDNS hostname
# Solves: browser webviews/service workers blocked over plain HTTP
[[ -z ${OMARCHY_SERVER_HELPERS:-} ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up Caddy reverse proxy with local HTTPS..."

# Install caddy and avahi for mDNS (.local hostname)
pkg_install caddy avahi nss-mdns

# Prompt for hostname
default_hostname=$(hostname)
echo
read -rp "  Local hostname [${default_hostname}]: " local_hostname
local_hostname="${local_hostname:-$default_hostname}"

# Prompt for HTTPS port
read -rp "  HTTPS port [443]: " https_port
https_port="${https_port:-443}"

# Configure avahi for mDNS broadcasting
sudo mkdir -p /etc/avahi
sudo tee /etc/avahi/avahi-daemon.conf >/dev/null << EOF
[server]
host-name=${local_hostname}
domain-name=local
use-ipv4=yes
use-ipv6=yes

[publish]
publish-addresses=yes
publish-workstation=no

[reflector]

[rlimits]
EOF

# Enable NSS mDNS resolution
if [[ -f /etc/nsswitch.conf ]]; then
  if ! grep -q "mdns_minimal" /etc/nsswitch.conf; then
    sudo sed -i 's/^hosts:.*/hosts: mymachines mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] files dns/' /etc/nsswitch.conf
    info "Enabled mDNS in nsswitch.conf"
  fi
fi

# Discover services to proxy
info "Detecting running services to proxy..."
echo

services=()
proxy_blocks=""

# Check code-server
if pgrep -f code-server &>/dev/null || svc status code-server &>/dev/null 2>&1; then
  cs_port=$(grep -oP 'bind-addr:\s*\S+:\K\d+' "$HOME/.config/code-server/config.yaml" 2>/dev/null || echo "9301")
  info "Found code-server on port $cs_port"
  services+=("code-server:$cs_port")
fi

# If no services detected, ask manually
if (( ${#services[@]} == 0 )); then
  warn "No running services detected"
  read -rp "  Service port to proxy [9301]: " manual_port
  manual_port="${manual_port:-9301}"
  services+=("service:$manual_port")
fi

# Build Caddyfile
if [[ "$https_port" == "443" ]]; then
  listen_addr="https://${local_hostname}.local"
else
  listen_addr="https://${local_hostname}.local:${https_port}"
fi

caddy_config="${listen_addr} {"
for svc_entry in "${services[@]}"; do
  IFS=':' read -r svc_name svc_port <<< "$svc_entry"
  caddy_config+="
    reverse_proxy localhost:${svc_port}"
done
caddy_config+="
}"

sudo mkdir -p /etc/caddy
sudo tee /etc/caddy/Caddyfile >/dev/null <<< "$caddy_config"

info "Caddyfile:"
cat /etc/caddy/Caddyfile

# Create systemd service for caddy
if ! pidof systemd &>/dev/null && command -v serviced &>/dev/null; then
  sudo tee /etc/systemd/system/caddy.service >/dev/null << SVCEOF
[Unit]
Description=Caddy HTTPS reverse proxy
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/caddy run --config /etc/caddy/Caddyfile
Restart=always
User=root

[Install]
WantedBy=default.target
SVCEOF
fi

# Allow caddy to bind low ports without root
if [[ "$https_port" -le 1024 ]]; then
  sudo setcap 'cap_net_bind_service=+ep' /usr/bin/caddy 2>/dev/null || true
fi

# Start services
svc enable avahi-daemon 2>/dev/null || true
svc start avahi-daemon 2>/dev/null || true
svc enable caddy
svc start caddy 2>/dev/null || true

# Wait for caddy to generate certs
sleep 3

# Find and display root CA cert location
ca_cert=""
for path in \
  "$HOME/.local/share/caddy/pki/authorities/local/root.crt" \
  "/var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt" \
  "/root/.local/share/caddy/pki/authorities/local/root.crt"; do
  if [[ -f "$path" ]]; then
    ca_cert="$path"
    break
  fi
done

echo
success "Caddy reverse proxy configured"
echo
info "Access: ${listen_addr}"
info "Hostname: ${local_hostname}.local (via mDNS/Avahi)"
echo
if [[ -n "$ca_cert" ]]; then
  info "Root CA cert: $ca_cert"
  info "Install this cert on your PC/browser to trust HTTPS:"
  echo
  echo -e "  ${BOLD}Linux:${NC}   sudo cp $ca_cert /etc/ca-certificates/trust-source/anchors/ && sudo update-ca-trust"
  echo -e "  ${BOLD}macOS:${NC}   sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain root.crt"
  echo -e "  ${BOLD}Browser:${NC} Import root.crt in Settings > Certificates > Authorities"
else
  warn "Root CA cert not found yet — caddy may need a moment. Check:"
  echo "  ~/.local/share/caddy/pki/authorities/local/root.crt"
fi