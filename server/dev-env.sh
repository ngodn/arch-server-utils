#!/bin/bash
# Dev Environments: Languages via mise (Node, Python, Ruby, Go, etc.)
[[ -z $OMARCHY_SERVER_HELPERS ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up Development Environments..."

# Ensure mise is installed
if ! command -v mise &>/dev/null; then
  info "Installing mise (version manager)..."
  pkg_install mise
fi

# Activate mise for this session
eval "$(mise activate bash)" 2>/dev/null || true

# Language definitions
LANG_NAMES=("Node.js" "Python" "Ruby on Rails" "Go" "Rust" "PHP" "Java" "Elixir" ".NET" "Bun" "Deno" "Zig")
LANG_SELECTED=(0 0 0 0 0 0 0 0 0 0 0 0)

show_lang_menu() {
  echo
  info "Select languages to install:"
  echo

  for i in "${!LANG_NAMES[@]}"; do
    local num=$((i + 1))
    if (( LANG_SELECTED[i] )); then
      printf "   ${GREEN}[x]${NC} %2d) %s\n" "$num" "${LANG_NAMES[$i]}"
    else
      printf "   ${DIM}[ ] %2d) %s${NC}\n" "$num" "${LANG_NAMES[$i]}"
    fi
  done

  echo
  echo -e "  Toggle: ${BOLD}[1-${#LANG_NAMES[@]}]${NC}  All: ${BOLD}[a]${NC}  Done: ${BOLD}[d]${NC}  Skip: ${BOLD}[s]${NC}"
}

while true; do
  show_lang_menu
  read -rp "  > " lang_choice

  case $lang_choice in
    [0-9]*)
      lang_idx=$((lang_choice - 1))
      if (( lang_idx >= 0 && lang_idx < ${#LANG_NAMES[@]} )); then
        LANG_SELECTED[$lang_idx]=$(( ! LANG_SELECTED[lang_idx] ))
      fi
      ;;
    a|A) for i in "${!LANG_SELECTED[@]}"; do LANG_SELECTED[$i]=1; done ;;
    d|D) break ;;
    s|S) success "Skipped dev environment setup"; return 0 ;;
  esac
done

# Install selected languages
for i in "${!LANG_NAMES[@]}"; do
  if (( LANG_SELECTED[i] )); then
    case $i in
      0) # Node.js
        info "Installing Node.js..."
        mise use --global node@lts
        success "Node.js $(node -v 2>/dev/null || echo 'installed')"
        ;;
      1) # Python
        info "Installing Python..."
        mise use --global python@latest
        info "Installing uv package manager..."
        curl -fsSL https://astral.sh/uv/install.sh | sh
        success "Python $(python --version 2>/dev/null || echo 'installed')"
        ;;
      2) # Ruby on Rails
        info "Installing Ruby on Rails..."
        pkg_install libyaml
        mise use --global ruby@latest
        mise settings add ruby.compile false 2>/dev/null || true
        echo "gem: --no-document" > ~/.gemrc
        mise x ruby -- gem install rails --no-document
        success "Ruby $(ruby -v 2>/dev/null || echo 'installed') + Rails"
        ;;
      3) # Go
        info "Installing Go..."
        mise use --global go@latest
        success "Go $(go version 2>/dev/null || echo 'installed')"
        ;;
      4) # Rust
        info "Installing Rust via rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env" 2>/dev/null || true
        success "Rust $(rustc --version 2>/dev/null || echo 'installed')"
        ;;
      5) # PHP
        info "Installing PHP..."
        pkg_install php composer
        success "PHP $(php -v 2>/dev/null | head -1 || echo 'installed')"
        ;;
      6) # Java
        info "Installing Java..."
        mise use --global java@latest
        success "Java $(java --version 2>/dev/null | head -1 || echo 'installed')"
        ;;
      7) # Elixir
        info "Installing Elixir..."
        mise use --global erlang@latest
        mise use --global elixir@latest
        mise x elixir -- mix local.hex --force 2>/dev/null || true
        success "Elixir installed"
        ;;
      8) # .NET
        info "Installing .NET..."
        mise use --global dotnet@latest
        success ".NET $(dotnet --version 2>/dev/null || echo 'installed')"
        ;;
      9) # Bun
        info "Installing Bun..."
        mise use --global bun@latest
        success "Bun $(bun --version 2>/dev/null || echo 'installed')"
        ;;
      10) # Deno
        info "Installing Deno..."
        mise use --global deno@latest
        success "Deno $(deno --version 2>/dev/null | head -1 || echo 'installed')"
        ;;
      11) # Zig
        info "Installing Zig..."
        mise use --global zig@latest
        mise use --global zls@latest 2>/dev/null || true
        success "Zig installed"
        ;;
    esac
  fi
done

success "Dev environments configured"
