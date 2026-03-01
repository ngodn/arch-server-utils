#!/bin/bash
# Server Tools: Interactive timezone selector
[[ -z ${OMARCHY_SERVER_HELPERS:-} ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Installing timezone selector..."

pkg_install gum

ensure_dir "$HOME/.local/bin"

cat > "$HOME/.local/bin/omarchy-tz-select" << 'EOF'
#!/bin/bash
# Interactive timezone selection using gum
timezone=$(timedatectl list-timezones | gum filter --height 20 --header "Set timezone") || exit 1
sudo timedatectl set-timezone "$timezone"
echo "Timezone is now set to $timezone"
EOF

chmod +x "$HOME/.local/bin/omarchy-tz-select"

success "Timezone selector installed (omarchy-tz-select)"
