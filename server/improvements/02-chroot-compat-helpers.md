# Spec 02: Chroot Compatibility Helpers

## Overview

`server/chroot-compat.sh` provides helper functions that abstract away differences between a standard Arch Linux server (systemd, x86_64) and a chroot-distro ARM environment (serviced, aarch64). All component scripts use these instead of calling systemctl/pacman directly.

## Service Management Functions

### `enable_service <name>`

Enables and starts a service.

- **systemd**: `sudo systemctl enable --now "$1"`
- **serviced**: `sudo serviced enable "$1" && sudo serviced start "$1"`

### `disable_service <name>`

Disables and stops a service.

- **systemd**: `sudo systemctl disable --now "$1"`
- **serviced**: `sudo serviced stop "$1" && sudo serviced disable "$1"`

### `restart_service <name>`

Restarts a running service.

- **systemd**: `sudo systemctl restart "$1"`
- **serviced**: `sudo serviced restart "$1"`

### `stop_service <name>`

Stops a service.

- **systemd**: `sudo systemctl stop "$1"`
- **serviced**: `sudo serviced stop "$1"`

### `is_service_active <name>`

Checks if a service is running. Returns 0 if active, 1 if not.

- **systemd**: `systemctl is-active --quiet "$1"`
- **serviced**: `serviced status "$1" 2>/dev/null | grep -q "running"`

## Serviced Unit Writer

### `write_serviced_unit <name> <exec_start> [options...]`

Writes a clean `.service` unit file optimized for the chroot environment. Only used when `OMARCHY_IS_CHROOT_DISTRO=1`.

Writes to `/etc/systemd/system/<name>.service` (serviced reads from the same paths).

Strips directives incompatible with chroot-distro:
- No `SocketActivation` / `fd://` arguments
- No `SystemdService=` in D-Bus activation files
- No `ProtectSystem=`, `ProtectHome=`, `PrivateTmp=` (sandbox directives unsupported)
- No `Wants=network-online.target` (no networkd in chroot)

Optional parameters:
- `--user <user>` — User= directive
- `--workdir <path>` — WorkingDirectory= directive
- `--env <KEY=VALUE>` — Environment= directive (repeatable)
- `--restart <policy>` — Restart= directive (default: `on-failure`)
- `--after <unit>` — After= directive

### Example Output

```ini
[Unit]
Description=OpenSSH Daemon
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/sshd -D
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

## Package Install Wrapper

### `install_pkg <packages...>`

Installs packages via pacman. Handles the difference between running as root (common in chroot) vs using sudo.

```bash
install_pkg() {
  if (( EUID == 0 )); then
    pacman -S --needed --noconfirm "$@"
  else
    sudo pacman -S --needed --noconfirm "$@"
  fi
}
```

## Incompatibility Warning

### `warn_if_incompatible <component_id>`

Checks a component against known incompatibilities and prints a warning. Returns 0 always (warnings don't block installation — user chose option C).

Known incompatibilities:

| Component | Condition | Warning |
|-----------|-----------|---------|
| `windows-vm` | `OMARCHY_IS_ARM=1` | "Windows VM requires x86_64 KVM — will not work on aarch64" |
| `firewall` | `OMARCHY_IS_CHROOT_DISTRO=1` | "UFW may conflict with Android iptables rules in chroot" |
| `neko` | `OMARCHY_IS_ARM=1` | "Some Neko browser flavors unavailable on ARM (Chromium limited)" |

## Menu Description Suffix

### `get_compat_suffix <component_id>`

Returns a suffix string for the menu display. Empty string if compatible.

- `windows-vm` on ARM → ` [x86_64 only]`
- `firewall` on chroot-distro → ` [chroot warning]`
- `neko` on ARM → ` [limited on ARM]`

Used by `show_menu()` to append warnings to component descriptions.
