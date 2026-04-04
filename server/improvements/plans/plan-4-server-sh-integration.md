# Plan 4: server.sh Integration

## Goal

Wire the detection and compatibility layer into the main `server.sh` entry point. Minimal, surgical changes.

**Specs**: 06-integration-flow.md

**Depends on**: Plan 1 (chroot-compat.sh must exist)

---

## Step 1: Modify `helpers.sh` to Source `chroot-compat.sh`

Add at the end of `server/helpers.sh`:

```bash
# Source chroot compatibility layer
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/chroot-compat.sh"
```

This makes all helper functions available to every component script automatically (they already source helpers.sh via server.sh).

---

## Step 2: Add Detection Call to `server.sh`

After `preflight` call (line 180), before `run_menu` call:

```bash
preflight
detect_environment              # <-- ADD

echo
if (( OMARCHY_IS_CHROOT_DISTRO )); then
  info "Environment: chroot-distro (${OMARCHY_ARCH}, serviced)"
elif (( OMARCHY_IS_ARM )); then
  info "Environment: Arch Linux ARM (${OMARCHY_ARCH})"
else
  info "Environment: Arch Linux (${OMARCHY_ARCH})"
fi

run_menu
run_install
```

---

## Step 3: Add Compat Suffix to Menu Display

In `show_menu()` function, after parsing `id`, `name`, `desc` from the component:

```bash
# After: IFS='|' read -r id name desc _ <<< "${COMPONENTS[$i]}"
local suffix
suffix="$(get_compat_suffix "$id")"
desc="${desc}${suffix}"
```

This appends warnings like ` [x86_64 only]` to the description in the interactive menu.

---

## Step 4: Add Warning Before Component Install

In `run_install()` function, before `source "$SCRIPT_DIR/server/$id.sh"`:

```bash
# Before: source "$SCRIPT_DIR/server/$id.sh"
warn_if_incompatible "$id"
source "$SCRIPT_DIR/server/$id.sh"
```

---

## Step 5: Relax Preflight for ARM

The existing `preflight()` checks for `/etc/arch-release` and `pacman`. Both exist on Arch Linux ARM. No changes needed to preflight.

However, verify that the `sudo` check works in chroot-distro (user may be root directly):

```bash
# If running as root in chroot, sudo may not be needed
# but should still be installed for component scripts
if ! command -v sudo &>/dev/null; then
  if (( EUID == 0 )); then
    pacman -S --needed --noconfirm sudo
  else
    error "sudo is required. Install it with: pacman -S sudo"
    exit 1
  fi
fi
```

---

## Verification

- [ ] `server.sh` starts and detects environment correctly on x86_64
- [ ] `server.sh` starts and detects chroot-distro on aarch64
- [ ] Menu shows compat suffixes for incompatible components
- [ ] Warnings appear before incompatible component installation
- [ ] All component scripts can access `OMARCHY_*` variables
- [ ] All component scripts can call `enable_service`, `install_pkg`, etc.
- [ ] Standard x86_64 behavior unchanged
