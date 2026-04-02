#!/bin/bash
# Code Server: VS Code in the browser
[[ -z ${OMARCHY_SERVER_HELPERS:-} ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up Code Server..."

# Install via AUR
if command -v yay &>/dev/null; then
  aur_install code-server
else
  info "Installing via official script..."
  curl -fsSL https://code-server.dev/install.sh | sh
fi

# Prompt for port and password
echo
read -rp "  Port [9301]: " cs_port
cs_port="${cs_port:-9301}"

read -rsp "  Password (leave empty for auto-generated): " cs_password
echo

# Generate config
ensure_dir "$HOME/.config/code-server"

if [[ -n $cs_password ]]; then
  CS_PASSWORD="$cs_password"
else
  CS_PASSWORD=$(head -c 16 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 16)
  info "Auto-generated password: $CS_PASSWORD"
fi

cat > "$HOME/.config/code-server/config.yaml" << EOF
bind-addr: 0.0.0.0:$cs_port
auth: password
password: $CS_PASSWORD
cert: false
EOF

# serviced doesn't support template units (code-server@user), create a concrete service
if ! pidof systemd &>/dev/null && command -v serviced &>/dev/null; then
  sudo tee /etc/systemd/system/code-server.service >/dev/null << SVCEOF
[Unit]
Description=code-server
After=network.target

[Service]
Type=exec
ExecStart=/usr/bin/code-server
Restart=always
User=${USER}

[Install]
WantedBy=default.target
SVCEOF
  svc enable code-server
  svc start code-server 2>/dev/null || true
else
  svc enable code-server@${USER}
  svc start code-server@${USER} 2>/dev/null || true
fi

success "Code Server installed and running on port $cs_port"
echo
info "Access: http://<server-ip>:$cs_port"
info "Config: ~/.config/code-server/config.yaml"
info "Password: stored in config file above"
info "For HTTPS, set cert: true in config or use a reverse proxy"
