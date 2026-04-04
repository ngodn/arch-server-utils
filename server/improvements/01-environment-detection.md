# Spec 01: Environment Detection

## Overview

A detection phase that runs once at startup before the interactive menu. It identifies the runtime environment (architecture, chroot-distro presence, init system) and exports variables consumed by all component scripts.

## Detection Markers

### chroot-distro Detection

Three markers checked in order — all three must match for `OMARCHY_IS_CHROOT_DISTRO=1`:

1. **Directory marker**: `/data/local/chroot-distro/` exists
2. **Service manager**: `serviced` binary found in PATH
3. **Android groups**: `aid_inet` present in `/etc/group`

If any marker fails, `OMARCHY_IS_CHROOT_DISTRO=0`.

### Architecture Detection

```bash
OMARCHY_ARCH="$(uname -m)"   # aarch64, x86_64, armv7l, i686
OMARCHY_IS_ARM=0
[[ "$OMARCHY_ARCH" == "aarch64" ]] && OMARCHY_IS_ARM=1
```

### Init System Detection

```bash
OMARCHY_HAS_SYSTEMD=0
OMARCHY_HAS_SERVICED=0

pidof systemd &>/dev/null && OMARCHY_HAS_SYSTEMD=1
command -v serviced &>/dev/null && OMARCHY_HAS_SERVICED=1
```

## Exported Variables

| Variable | Type | Description |
|----------|------|-------------|
| `OMARCHY_ARCH` | string | Architecture from `uname -m` |
| `OMARCHY_IS_ARM` | 0/1 | `1` if aarch64 |
| `OMARCHY_IS_CHROOT_DISTRO` | 0/1 | `1` if all three chroot-distro markers match |
| `OMARCHY_HAS_SYSTEMD` | 0/1 | `1` if systemd is PID 1 |
| `OMARCHY_HAS_SERVICED` | 0/1 | `1` if serviced binary available |

## Location

Detection logic lives in `server/chroot-compat.sh`, sourced by `server/helpers.sh`. The function `detect_environment()` is called once from `server.sh` before `run_menu()`.

## Fallback Behavior

On a standard x86_64 Arch Linux server with systemd, all detection results in:
- `OMARCHY_IS_CHROOT_DISTRO=0`
- `OMARCHY_HAS_SYSTEMD=1`
- `OMARCHY_HAS_SERVICED=0`
- `OMARCHY_IS_ARM=0`

No behavior changes — scripts run exactly as they do today.
