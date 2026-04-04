# Spec 06: Integration Flow

## Overview

How the detection and compatibility layer integrates with the existing `server.sh` structure. Minimal changes to the main script; most logic lives in the new `chroot-compat.sh`.

## File Structure (New/Modified)

```
server/
  helpers.sh              # Modified: source chroot-compat.sh
  chroot-compat.sh        # NEW: detection + helper functions
  ssh.sh                  # Modified: use enable_service, write_serviced_unit
  docker.sh               # Modified: use enable_service, write_serviced_unit
  code-server.sh          # Modified: use enable_service (minor)
  tailscale.sh            # Modified: use enable_service, write_serviced_unit
  neko.sh                 # Modified: use enable_service
  docker-dbs.sh           # Modified: use is_service_active
  yay.sh                  # Modified: architecture-aware clone
  windows-vm.sh           # Modified: ARM KVM handling + warning
  firewall.sh             # Modified: chroot warning
server.sh                 # Modified: call detect_environment, pass compat suffix to menu
```

## Startup Sequence

```
1. server.sh starts
2. source server/helpers.sh
3.   helpers.sh sources server/chroot-compat.sh
4.   chroot-compat.sh defines functions (no side effects yet)
5. preflight() runs
6.   Existing checks (arch-release, pacman, sudo)
7. detect_environment() called   <-- NEW
8.   Sets OMARCHY_* exported variables
9.   Prints environment summary:
       "Detected: aarch64 | chroot-distro | serviced"
10. run_menu() runs
11.   show_menu() appends compat suffixes to descriptions
12. run_install() runs
13.   For each selected component:
14.     warn_if_incompatible() prints warning if applicable
15.     source the script (script uses helper functions)
```

## Changes to server.sh

### After preflight(), before run_menu()

```bash
detect_environment

if (( OMARCHY_IS_CHROOT_DISTRO )); then
  info "Environment: chroot-distro (aarch64, serviced)"
elif (( OMARCHY_IS_ARM )); then
  info "Environment: Arch Linux ARM (aarch64)"
else
  info "Environment: Arch Linux (x86_64)"
fi
```

### In show_menu()

Append compatibility suffix to description:

```bash
local suffix
suffix="$(get_compat_suffix "$id")"
desc="${desc}${suffix}"
```

### In run_install(), before sourcing each script

```bash
warn_if_incompatible "$id"
```

## Changes to helpers.sh

Add at the end:

```bash
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
source "$SCRIPT_DIR/chroot-compat.sh"
```

## Backwards Compatibility

On a standard x86_64 Arch Linux server:
- `detect_environment` sets all `OMARCHY_IS_*` to 0, `OMARCHY_HAS_SYSTEMD` to 1
- `get_compat_suffix` returns empty strings
- `warn_if_incompatible` prints nothing
- `enable_service` calls `systemctl enable --now`
- `install_pkg` calls `sudo pacman -S --needed --noconfirm`
- No behavioral change whatsoever
