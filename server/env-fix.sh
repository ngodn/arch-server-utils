#!/bin/bash
# Environment Fix: Ensure /etc/environment has proper HOME and user paths
# Services started by serviced (code-server, sshd, tailscaled, etc.) inherit
# their environment from /etc/environment. Without HOME and user-specific paths,
# tools like claude, mise, cargo, and node are not found in service terminals.
[[ -z ${OMARCHY_SERVER_HELPERS:-} ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Fixing /etc/environment for service compatibility..."

if [[ ! -f /etc/environment ]]; then
  warn "/etc/environment not found, skipping"
  return 0 2>/dev/null || exit 0
fi

changed=0

# Ensure HOME is set
if ! grep -q "^HOME=" /etc/environment; then
  echo "HOME=$HOME" | sudo tee -a /etc/environment >/dev/null
  info "Added HOME=$HOME"
  changed=1
fi

# Ensure user paths are in PATH (claude, mise, cargo, etc.)
if grep -q "^PATH=" /etc/environment; then
  if ! grep -q "$HOME/.local/bin" /etc/environment; then
    sudo sed -i "s|^PATH=|PATH=$HOME/.local/bin:$HOME/.local/share/mise/shims:$HOME/.cargo/bin:|" /etc/environment
    info "Added user paths to PATH"
    changed=1
  fi
else
  echo "PATH=$HOME/.local/bin:$HOME/.local/share/mise/shims:$HOME/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" | sudo tee -a /etc/environment >/dev/null
  info "Created PATH with user paths"
  changed=1
fi

if (( changed )); then
  success "Environment fixed — restart services for changes to take effect"
else
  success "Environment already configured correctly"
fi