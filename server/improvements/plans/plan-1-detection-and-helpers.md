# Plan 1: Environment Detection & Compatibility Helpers

## Goal

Create `server/chroot-compat.sh` with detection logic and helper functions. Integrate into `helpers.sh` and `server.sh`.

**Specs**: 01-environment-detection.md, 02-chroot-compat-helpers.md, 06-integration-flow.md

---

## Step 1: Create `server/chroot-compat.sh`

Create the new file with the following sections:

### 1.1 Detection Function

```bash
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
```

### 1.2 Service Management Functions

```bash
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
```

### 1.3 Package Install Wrapper

```bash
install_pkg() {
  if (( EUID == 0 )); then
    pacman -S --needed --noconfirm "$@"
  else
    sudo pacman -S --needed --noconfirm "$@"
  fi
}
```

### 1.4 Serviced Unit Writer

```bash
write_serviced_unit() {
  local name="$1"
  local exec_start="$2"
  shift 2

  local user="" workdir="" restart="on-failure" after="" description="" type="simple"
  local -a envs=()

  while (( $# )); do
    case "$1" in
      --user)       user="$2"; shift 2 ;;
      --workdir)    workdir="$2"; shift 2 ;;
      --env)        envs+=("$2"); shift 2 ;;
      --restart)    restart="$2"; shift 2 ;;
      --after)      after="$2"; shift 2 ;;
      --description) description="$2"; shift 2 ;;
      --type)       type="$2"; shift 2 ;;
      *)            shift ;;
    esac
  done

  [[ -z "$description" ]] && description="$name"

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
```

### 1.5 Compatibility Warning Functions

```bash
# Incompatibility database
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
  local key=""

  if (( OMARCHY_IS_ARM )); then
    key="${id}:arm"
  fi
  if (( OMARCHY_IS_CHROOT_DISTRO )); then
    key="${id}:chroot"
  fi

  if [[ -n "${COMPAT_WARNINGS[$key]:-}" ]]; then
    warn "${COMPAT_WARNINGS[$key]}"
  fi
}

get_compat_suffix() {
  local id="$1"
  local key=""

  if (( OMARCHY_IS_ARM )); then
    key="${id}:arm"
  fi
  if (( OMARCHY_IS_CHROOT_DISTRO )); then
    # chroot warnings take precedence over ARM warnings
    [[ -n "${COMPAT_SUFFIXES[${id}:chroot]:-}" ]] && key="${id}:chroot"
  fi

  echo "${COMPAT_SUFFIXES[$key]:-}"
}
```

---

## Step 2: Integrate into `helpers.sh`

Add at the end of `server/helpers.sh`:

```bash
# Source chroot compatibility layer
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/chroot-compat.sh"
```

---

## Step 3: Modify `server.sh`

### 3.1 Add detection call after preflight

After `preflight` and before `run_menu`, add:

```bash
detect_environment

echo
if (( OMARCHY_IS_CHROOT_DISTRO )); then
  info "Environment: chroot-distro (${OMARCHY_ARCH}, serviced)"
elif (( OMARCHY_IS_ARM )); then
  info "Environment: Arch Linux ARM (${OMARCHY_ARCH})"
else
  info "Environment: Arch Linux (${OMARCHY_ARCH})"
fi
```

### 3.2 Add compat suffix to menu display

In `show_menu()`, after parsing `desc` from the component, append:

```bash
local suffix
suffix="$(get_compat_suffix "$id")"
desc="${desc}${suffix}"
```

### 3.3 Add warning before component install

In `run_install()`, before `source "$SCRIPT_DIR/server/$id.sh"`, add:

```bash
warn_if_incompatible "$id"
```

---

## Step 4: Verify

- [ ] On x86_64 with systemd: all variables default, no behavior change
- [ ] On aarch64 chroot-distro: detection works, helpers route to serviced
- [ ] Menu shows suffixes for incompatible components
- [ ] Warnings display before incompatible component install
- [ ] `enable_service`, `install_pkg`, `write_serviced_unit` work correctly
