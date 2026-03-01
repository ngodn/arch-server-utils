#!/bin/bash
# Server Tools: System package updater + AUR updater + orphan cleanup
[[ -z $OMARCHY_SERVER_HELPERS ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Installing server update tools..."

ensure_dir "$HOME/.local/bin"

# ── omarchy-update-system-pkgs ─────────────────────────────────────
cat > "$HOME/.local/bin/omarchy-update-system-pkgs" << 'EOF'
#!/bin/bash
set -e
echo -e "\e[32m\nUpdate system packages\e[0m"
sudo pacman -Syyu --noconfirm
EOF

# ── omarchy-update-aur-pkgs ───────────────────────────────────────
cat > "$HOME/.local/bin/omarchy-update-aur-pkgs" << 'EOF'
#!/bin/bash
# Update AUR packages if any are installed
if ! command -v yay &>/dev/null; then
  echo "yay not installed, skipping AUR updates"
  exit 0
fi

if pacman -Qem &>/dev/null; then
  echo -e "\e[32m\nUpdate AUR packages\e[0m"
  yay -Sua --noconfirm --cleanafter
  echo
else
  echo "No AUR packages installed"
fi
EOF

# ── omarchy-update-orphan-pkgs ────────────────────────────────────
cat > "$HOME/.local/bin/omarchy-update-orphan-pkgs" << 'EOF'
#!/bin/bash
orphans=$(pacman -Qtdq 2>/dev/null)
if [[ -n $orphans ]]; then
  echo -e "\e[32m\nRemoving orphaned packages\e[0m"
  echo "$orphans"
  sudo pacman -Rs --noconfirm $orphans
else
  echo "No orphaned packages found"
fi
EOF

# ── omarchy-update (all-in-one) ───────────────────────────────────
cat > "$HOME/.local/bin/omarchy-update" << 'EOF'
#!/bin/bash
set -e
echo -e "\e[36m━━━ System Update ━━━\e[0m"
echo

omarchy-update-system-pkgs

if command -v yay &>/dev/null; then
  omarchy-update-aur-pkgs
fi

omarchy-update-orphan-pkgs

echo
echo -e "\e[32m━━━ Update Complete ━━━\e[0m"
EOF

chmod +x "$HOME/.local/bin/omarchy-update-system-pkgs"
chmod +x "$HOME/.local/bin/omarchy-update-aur-pkgs"
chmod +x "$HOME/.local/bin/omarchy-update-orphan-pkgs"
chmod +x "$HOME/.local/bin/omarchy-update"

success "Update tools installed (omarchy-update, omarchy-update-system-pkgs, omarchy-update-aur-pkgs, omarchy-update-orphan-pkgs)"
