#!/bin/bash
# Chroot-distro compatibility layer for Arch Linux ARM
# Detects environment and provides helper functions that abstract
# differences between standard Arch Linux and chroot-distro on ARM.

[[ -n "${OMARCHY_CHROOT_COMPAT_LOADED:-}" ]] && return 0
OMARCHY_CHROOT_COMPAT_LOADED=1

# ── Environment Detection ─────────────────────────────────────────

detect_environment() {
  export OMARCHY_ARCH="$(uname -m)"
  export OMARCHY_IS_ARM=0
  export OMARCHY_IS_CHROOT_DISTRO=0
  export OMARCHY_HAS_SYSTEMD=0
  export OMARCHY_HAS_SERVICED=0

  # Architecture
  [[ "$OMARCHY_ARCH" == "aarch64" ]] && OMARCHY_IS_ARM=1

  # Init system
  pidof systemd &>/dev/null && OMARCHY_HAS_SYSTEMD=1
  command -v serviced &>/dev/null && OMARCHY_HAS_SERVICED=1

  # chroot-distro: all three markers must match
  if [[ -d "/data/local/chroot-distro" ]] \
    && (( OMARCHY_HAS_SERVICED )) \
    && grep -q "aid_inet" /etc/group 2>/dev/null; then
    OMARCHY_IS_CHROOT_DISTRO=1
  fi
}

# ── Service Management ─────────────────────────────────────────────

enable_service() {
  local name="$1"
  if (( OMARCHY_HAS_SERVICED )); then
    sudo serviced enable "$name"
    sudo serviced start "$name"
  elif (( OMARCHY_HAS_SYSTEMD )); then
    sudo systemctl enable --now "$name"
  else
    warn "No service manager available. Start $name manually."
  fi
}

disable_service() {
  local name="$1"
  if (( OMARCHY_HAS_SERVICED )); then
    sudo serviced stop "$name" 2>/dev/null
    sudo serviced disable "$name"
  elif (( OMARCHY_HAS_SYSTEMD )); then
    sudo systemctl disable --now "$name"
  fi
}

restart_service() {
  local name="$1"
  if (( OMARCHY_HAS_SERVICED )); then
    sudo serviced restart "$name"
  elif (( OMARCHY_HAS_SYSTEMD )); then
    sudo systemctl restart "$name"
  fi
}

stop_service() {
  local name="$1"
  if (( OMARCHY_HAS_SERVICED )); then
    sudo serviced stop "$name"
  elif (( OMARCHY_HAS_SYSTEMD )); then
    sudo systemctl stop "$name"
  fi
}

is_service_active() {
  local name="$1"
  if (( OMARCHY_HAS_SERVICED )); then
    serviced status "$name" 2>/dev/null | grep -q "running"
  elif (( OMARCHY_HAS_SYSTEMD )); then
    systemctl is-active --quiet "$name"
  else
    return 1
  fi
}

# ── Serviced Unit Writer ───────────────────────────────────────────

write_serviced_unit() {
  local name="$1"
  local exec_start="$2"
  shift 2

  local user="" workdir="" restart="on-failure" after="" description="" type="simple"
  local -a envs=()

  while (( $# )); do
    case "$1" in
      --user)        user="$2"; shift 2 ;;
      --workdir)     workdir="$2"; shift 2 ;;
      --env)         envs+=("$2"); shift 2 ;;
      --restart)     restart="$2"; shift 2 ;;
      --after)       after="$2"; shift 2 ;;
      --description) description="$2"; shift 2 ;;
      --type)        type="$2"; shift 2 ;;
      *)             shift ;;
    esac
  done

  [[ -z "$description" ]] && description="$name"

  # serviced reads unit files from standard systemd paths, including /etc/systemd/system/
  local unit_file="/etc/systemd/system/${name}.service"
  local content="[Unit]
Description=${description}"

  [[ -n "$after" ]] && content+=$'\n'"After=${after}"

  content+=$'\n\n'"[Service]"
  content+=$'\n'"Type=${type}"
  content+=$'\n'"ExecStart=${exec_start}"

  [[ -n "$user" ]] && content+=$'\n'"User=${user}"
  [[ -n "$workdir" ]] && content+=$'\n'"WorkingDirectory=${workdir}"

  for env in "${envs[@]}"; do
    content+=$'\n'"Environment=${env}"
  done

  content+=$'\n'"Restart=${restart}"
  content+=$'\n'"RestartSec=5"
  content+=$'\n\n'"[Install]"
  content+=$'\n'"WantedBy=multi-user.target"

  sudo tee "$unit_file" > /dev/null <<< "$content"
}

# ── Compatibility Warnings ─────────────────────────────────────────

declare -A COMPAT_WARNINGS=(
  ["windows-vm:arm"]="Windows VM requires x86_64 KVM — will not work on aarch64"
  ["firewall:chroot"]="UFW may conflict with Android iptables rules in chroot"
  ["neko:arm"]="Some Neko browser flavors unavailable on ARM (Chromium limited)"
  ["docker-dbs:arm"]="MSSQL Docker image is x86_64 only — will be skipped on ARM"
)

declare -A COMPAT_SUFFIXES=(
  ["windows-vm:arm"]=" [x86_64 only]"
  ["firewall:chroot"]=" [chroot warning]"
  ["neko:arm"]=" [limited on ARM]"
  ["docker-dbs:arm"]=" [MSSQL unavailable]"
)

warn_if_incompatible() {
  local id="$1"

  # Show both ARM and chroot warnings if applicable
  if (( OMARCHY_IS_ARM )) && [[ -n "${COMPAT_WARNINGS[${id}:arm]:-}" ]]; then
    warn "${COMPAT_WARNINGS[${id}:arm]}"
  fi
  if (( OMARCHY_IS_CHROOT_DISTRO )) && [[ -n "${COMPAT_WARNINGS[${id}:chroot]:-}" ]]; then
    warn "${COMPAT_WARNINGS[${id}:chroot]}"
  fi
}

get_compat_suffix() {
  local id="$1"
  local suffix=""

  # Prefer chroot suffix over ARM suffix for display (menu space is limited)
  if (( OMARCHY_IS_CHROOT_DISTRO )) && [[ -n "${COMPAT_SUFFIXES[${id}:chroot]:-}" ]]; then
    suffix="${COMPAT_SUFFIXES[${id}:chroot]}"
  elif (( OMARCHY_IS_ARM )) && [[ -n "${COMPAT_SUFFIXES[${id}:arm]:-}" ]]; then
    suffix="${COMPAT_SUFFIXES[${id}:arm]}"
  fi

  echo "$suffix"
}
