# Spec 03: Per-Script Adaptations

## Overview

Categorization of all 27 component scripts by the changes needed for chroot-distro aarch64 support.

## Category 1: No Changes (15 scripts)

These scripts are fully architecture-agnostic and environment-agnostic:

| Script | Reason |
|--------|--------|
| `env-fix.sh` | Pure environment variable config |
| `git.sh` | Git config only |
| `gpg.sh` | Keyserver config only |
| `helpers.sh` | Utility functions (will source chroot-compat.sh) |
| `reset-sudo.sh` | Sudo lockout fix |
| `starship.sh` | Prompt config + pacman install (available on ARM) |
| `shell.sh` | Bash config + pacman packages (all available on ARM) |
| `tmux.sh` | Tmux config + pacman install |
| `cli-tools.sh` | All packages available in ALARM official repos |
| `update-system-pkgs.sh` | Pure shell scripts |
| `tz-select.sh` | gum available on ARM |
| `drive-info.sh` | Shell utilities (lsblk, awk) |
| `claude-code.sh` | npm install (works on aarch64) |
| `mise.sh` | Install script provides aarch64 binaries |
| `neovim.sh` | pacman install (available on ARM) |

## Category 2: Service Management Swap (6 scripts)

Replace `systemctl` calls with helper functions. Write optimized serviced units when on chroot-distro.

### `ssh.sh`

**Current**: `sudo systemctl enable --now sshd`
**Change**: `enable_service sshd`
**Serviced unit**: Write clean `sshd.service` — `Type=simple`, `ExecStart=/usr/bin/sshd -D` (foreground mode, no socket activation)

### `docker.sh`

**Current**: Already handles systemd vs non-systemd
**Change**: Use `enable_service docker` and `write_serviced_unit` for Docker daemon
**Serviced unit**: `ExecStart=/usr/bin/dockerd --iptables=true --storage-driver=overlay2`
**Note**: Docker on chroot-distro needs iptables-legacy (serviced handles this swap)

### `code-server.sh`

**Current**: Already handles systemd vs serviced
**Change**: Minimal — verify existing serviced path works, use `enable_service`
**Serviced unit**: Already creates one, verify it's optimized

### `tailscale.sh`

**Current**: Detects chroot, enables userspace networking
**Change**: Use `enable_service tailscaled`, existing chroot detection is good
**Serviced unit**: `ExecStart=/usr/bin/tailscaled --state=/var/lib/tailscale/tailscaled.state --tun=userspace-networking`

### `neko.sh`

**Current**: Docker-based, uses `docker compose`
**Change**: Use `enable_service docker` before compose commands
**Note**: ARM browser flavor limitations — warn user

### `docker-dbs.sh`

**Current**: Docker-based, uses `docker run`
**Change**: Ensure Docker service is running via `is_service_active docker`

## Category 3: Architecture Adaptation (2 scripts)

### `yay.sh`

**Current**: Clones `yay-bin` (prebuilt binary)
**Change on ARM**: Clone `yay` (source build) instead of `yay-bin`

```bash
if (( OMARCHY_IS_ARM )); then
  git clone https://aur.archlinux.org/yay.git /tmp/yay-build
else
  git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-build
fi
```

The existing fakeroot workaround (TCP IPC for containers) is already ARM-compatible.

### `dev-env.sh`

**Current**: `curl -fsSL https://astral.sh/uv/install.sh | sh`
**Change**: None needed — uv provides aarch64 linux binaries (Tier 1 support)
**Note**: All mise-installed runtimes (Node, Python, Ruby, Go, Rust, etc.) support aarch64

## Category 4: Incompatibility Warnings (3 scripts)

### `windows-vm.sh`

**Warning**: "Windows VM requires x86_64 KVM — will not work on aarch64"
**ARM changes**:
- Skip `modprobe kvm-intel` / `modprobe kvm-amd` on ARM
- On ARM, attempt `modprobe kvm` (generic)
- Docker image `dockurr/windows` is x86_64 only — will fail on ARM
- Script proceeds anyway (user chose to see warnings, not block)

### `firewall.sh`

**Warning**: "UFW may conflict with Android iptables rules in chroot-distro"
**Note**: Android manages iptables externally; UFW rules may be overwritten or cause conflicts
**No code change** — just warning

### `neko.sh`

**Warning**: "Some browser flavors unavailable on ARM (Firefox works, Chromium limited)"
**Note**: m1k1o/neko provides arm64 images but not all browsers compile for ARM

## Summary Table

| Category | Count | Scripts |
|----------|-------|---------|
| No changes | 15 | env-fix, git, gpg, helpers, reset-sudo, starship, shell, tmux, cli-tools, update-system-pkgs, tz-select, drive-info, claude-code, mise, neovim |
| Service swap | 6 | ssh, docker, code-server, tailscale, neko, docker-dbs |
| Arch adaptation | 2 | yay, dev-env (confirmed no change needed) |
| Warnings | 3 | windows-vm, firewall, neko |
