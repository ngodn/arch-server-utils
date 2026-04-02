#!/bin/bash
# Omarchy Server Setup for Arch Linux
# Interactive installer for server-applicable components from Omarchy

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/server/helpers.sh"

# ── Component Definitions ──────────────────────────────────────────
# Format: id|name|description|default (1=selected, 0=unselected)

COMPONENTS=(
  "env-fix|Environment Fix|Fix /etc/environment for services (HOME, PATH for claude/mise/cargo)|1"
  "shell|Shell Config|Bash aliases, functions, inputrc, history + eza, zoxide, fzf, bat|1"
  "starship|Starship|Minimal prompt with git branch and status|1"
  "tmux|Tmux|Terminal multiplexer with dev layouts|1"
  "git|Git Config|Smart defaults (rebase, rerere, aliases)|1"
  "git-tools|Git Tools|Lazygit + GitHub CLI|1"
  "neovim|Neovim|Modern terminal editor|1"
  "yay|Yay|AUR helper for installing community packages|1"
  "cli-tools|CLI Tools|btop, fd, ripgrep, dust, jq, tldr, tree, fastfetch|1"
  "docker|Docker|Docker + Compose + Buildx + Lazydocker|0"
  "ssh|SSH Server|Hardened SSH server (no root login, custom port)|1"
  "gpg|GPG Keys|Multiple fallback keyservers|1"
  "systemd|Systemd|Faster shutdown timeout (5s)|1"
  "firewall|Firewall|UFW firewall with SSH allowed|0"
  "mise|Mise|Version manager (Node, Ruby, Python, etc.)|1"
  "tailscale|Tailscale|Mesh VPN for secure server networking|1"
  "docker-dbs|Docker DBs|MySQL, PostgreSQL, Redis, MongoDB, MariaDB, MSSQL|0"
  "claude-code|Claude Code|AI coding assistant for the terminal|1"
  "dev-env|Dev Environments|Languages via mise (Node, Python, Ruby, Go, etc.)|1"
  "windows-vm|Windows VM|Windows 11 via Docker + KVM with RDP|0"
  "update-system-pkgs|Update Tools|omarchy-update, system/AUR/orphan pkg updaters|1"
  "tz-select|Timezone|Interactive timezone selector|1"
  "reset-sudo|Sudo Reset|Clear sudo lockout after failed attempts|0"
  "drive-info|Drive Info|Drive information viewer (size, model, partitions)|1"
  "code-server|Code Server|VS Code in the browser (port 9301)|0"
  "neko|Neko Browsers|Firefox (9311) + Chrome (9312) in Docker via WebRTC|0"
)

# Parse defaults into selection array
SELECTED=()
for comp in "${COMPONENTS[@]}"; do
  IFS='|' read -r _ _ _ default <<< "$comp"
  SELECTED+=("$default")
done

# ── Preflight Checks ───────────────────────────────────────────────

preflight() {
  if [[ ! -f /etc/arch-release ]]; then
    error "This script is designed for Arch Linux."
    exit 1
  fi

  if ! command -v pacman &>/dev/null; then
    error "pacman not found. Are you running Arch Linux?"
    exit 1
  fi

  if ! command -v sudo &>/dev/null; then
    error "sudo is required. Install it with: pacman -S sudo"
    exit 1
  fi
}

# ── Menu Display ───────────────────────────────────────────────────

show_menu() {
  clear
  echo
  echo -e "  ${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "  ${CYAN}║${NC}${BOLD}          Omarchy Server Setup for Arch Linux            ${NC}${CYAN}║${NC}"
  echo -e "  ${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
  echo
  echo -e "  Select components to install:"
  echo

  for i in "${!COMPONENTS[@]}"; do
    IFS='|' read -r id name desc _ <<< "${COMPONENTS[$i]}"
    local num=$((i + 1))

    if (( SELECTED[i] )); then
      printf "   ${GREEN}[x]${NC} %2d) ${BOLD}%-16s${NC} ${DIM}%s${NC}\n" "$num" "$name" "$desc"
    else
      printf "   ${DIM}[ ] %2d) %-16s %s${NC}\n" "$num" "$name" "$desc"
    fi
  done

  echo
  echo -e "  ${DIM}──────────────────────────────────────────────────────────${NC}"
  echo -e "  Toggle: ${BOLD}[1-${#COMPONENTS[@]}]${NC}  All: ${BOLD}[a]${NC}  None: ${BOLD}[n]${NC}  Install: ${BOLD}[i]${NC}  Quit: ${BOLD}[q]${NC}"
}

# ── Interactive Menu Loop ──────────────────────────────────────────

run_menu() {
  while true; do
    show_menu
    echo
    read -rp "  > " choice

    case $choice in
      [0-9]*)
        local idx=$((choice - 1))
        if (( idx >= 0 && idx < ${#COMPONENTS[@]} )); then
          SELECTED[$idx]=$(( ! SELECTED[idx] ))
        fi
        ;;
      a|A)
        for i in "${!SELECTED[@]}"; do SELECTED[$i]=1; done
        ;;
      n|N)
        for i in "${!SELECTED[@]}"; do SELECTED[$i]=0; done
        ;;
      i|I)
        local any_selected=0
        for s in "${SELECTED[@]}"; do
          (( s )) && any_selected=1 && break
        done
        if (( ! any_selected )); then
          warn "Nothing selected. Toggle components with their number first."
          read -rp "  Press Enter to continue..." _
          continue
        fi
        break
        ;;
      q|Q)
        echo
        info "Cancelled."
        exit 0
        ;;
    esac
  done
}

# ── Installation ───────────────────────────────────────────────────

run_install() {
  echo
  echo
  echo -e "  ${CYAN}━━━ Starting Installation ━━━${NC}"
  echo

  info "Components to install:"
  for i in "${!COMPONENTS[@]}"; do
    if (( SELECTED[i] )); then
      IFS='|' read -r _ name _ _ <<< "${COMPONENTS[$i]}"
      echo -e "    ${GREEN}+${NC} $name"
    fi
  done
  echo

  info "Syncing package database..."
  sudo pacman -Sy --noconfirm
  echo

  for i in "${!COMPONENTS[@]}"; do
    if (( SELECTED[i] )); then
      IFS='|' read -r id name _ _ <<< "${COMPONENTS[$i]}"
      echo
      echo -e "  ${CYAN}━━━ $name ━━━${NC}"
      source "$SCRIPT_DIR/server/$id.sh"
    fi
  done

  echo
  echo -e "  ${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${GREEN}${BOLD}  Setup Complete!${NC}"
  echo -e "  ${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo
  info "Restart your shell or run: ${BOLD}source ~/.bashrc${NC}"
  echo
}

# ── Main ───────────────────────────────────────────────────────────

preflight
run_menu
run_install
