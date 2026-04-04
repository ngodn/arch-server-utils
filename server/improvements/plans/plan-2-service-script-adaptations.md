# Plan 2: Service Management Script Adaptations

## Goal

Modify the 6 scripts that use `systemctl` to use the compatibility helpers, and write optimized serviced units when on chroot-distro.

**Specs**: 03-per-script-adaptations.md, 04-serviced-unit-files.md

**Depends on**: Plan 1 (detection and helpers must exist)

---

## Step 1: Modify `ssh.sh`

### 1.1 Replace systemctl calls

Find all `systemctl` invocations and replace:

- `sudo systemctl enable --now sshd` → `enable_service sshd`
- `sudo systemctl restart sshd` → `restart_service sshd`
- `sudo systemctl stop sshd` → `stop_service sshd`

### 1.2 Write serviced unit (chroot-distro only)

Before enabling sshd, add:

```bash
if (( OMARCHY_IS_CHROOT_DISTRO )); then
  write_serviced_unit "sshd" "/usr/bin/sshd -D" \
    --description "OpenSSH Daemon" \
    --restart "on-failure"
fi
```

Key: `-D` flag runs sshd in foreground (required for serviced's simple type supervision).

### 1.3 Ensure SSH host keys exist

Add after package install, before service start:

```bash
# Generate host keys if missing (chroot may not have them)
if [[ ! -f /etc/ssh/ssh_host_ed25519_key ]]; then
  sudo ssh-keygen -A
fi
```

---

## Step 2: Modify `docker.sh`

### 2.1 Replace systemctl calls

The script already has systemd vs non-systemd branching. Replace:

- `sudo systemctl enable --now docker` → `enable_service docker`
- `sudo systemctl restart docker` → `restart_service docker`
- Any `pidof systemd` checks → use `OMARCHY_HAS_SYSTEMD` variable

### 2.2 Write serviced unit (chroot-distro only)

```bash
if (( OMARCHY_IS_CHROOT_DISTRO )); then
  write_serviced_unit "docker" "/usr/bin/dockerd" \
    --description "Docker Daemon" \
    --restart "on-failure"
fi
```

### 2.3 iptables-legacy handling

Add for chroot-distro (Android defaults to nftables):

```bash
if (( OMARCHY_IS_CHROOT_DISTRO )); then
  # Docker requires iptables-legacy on Android kernels
  if command -v update-alternatives &>/dev/null; then
    sudo update-alternatives --set iptables /usr/sbin/iptables-legacy 2>/dev/null || true
    sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy 2>/dev/null || true
  elif [[ -f /usr/sbin/iptables-legacy ]]; then
    sudo ln -sf /usr/sbin/iptables-legacy /usr/local/bin/iptables
    sudo ln -sf /usr/sbin/ip6tables-legacy /usr/local/bin/ip6tables
  fi
fi
```

### 2.4 Docker daemon.json for chroot

Add storage driver configuration for chroot-distro:

```bash
if (( OMARCHY_IS_CHROOT_DISTRO )); then
  sudo mkdir -p /etc/docker
  cat <<'EOF' | sudo tee /etc/docker/daemon.json > /dev/null
{
  "storage-driver": "overlay2",
  "iptables": true,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
fi
```

---

## Step 3: Modify `code-server.sh`

### 3.1 Review existing serviced handling

`code-server.sh` already has logic for both systemd and serviced. Review and ensure it uses the helper functions:

- Replace any direct `systemctl` calls with `enable_service code-server`
- Replace any direct serviced calls with helpers

### 3.2 Write serviced unit (chroot-distro only)

```bash
if (( OMARCHY_IS_CHROOT_DISTRO )); then
  write_serviced_unit "code-server" "/usr/bin/code-server --bind-addr 0.0.0.0:9301" \
    --description "Code Server" \
    --user "$USER" \
    --env "PASSWORD=${CS_PASSWORD}" \
    --restart "on-failure"
fi
```

---

## Step 4: Modify `tailscale.sh`

### 4.1 Replace systemctl calls

- `sudo systemctl enable --now tailscaled` → `enable_service tailscaled`

### 4.2 Write serviced unit (chroot-distro only)

```bash
if (( OMARCHY_IS_CHROOT_DISTRO )); then
  write_serviced_unit "tailscaled" \
    "/usr/bin/tailscaled --state=/var/lib/tailscale/tailscaled.state --tun=userspace-networking" \
    --description "Tailscale Daemon" \
    --restart "on-failure"
fi
```

### 4.3 Keep existing chroot detection

The script already detects chroot and forces userspace networking. This logic should remain — just ensure it's compatible with the new detection variables.

---

## Step 5: Modify `neko.sh`

### 5.1 Ensure Docker is running

Before `docker compose` commands:

```bash
if ! is_service_active docker; then
  enable_service docker
  sleep 2  # Wait for Docker to start
fi
```

### 5.2 ARM browser handling

Add note about browser limitations:

```bash
if (( OMARCHY_IS_ARM )); then
  info "Note: Using Firefox for Neko on ARM (Chromium may be unavailable)"
  # Could modify compose file to use firefox flavor only
fi
```

---

## Step 6: Modify `docker-dbs.sh`

### 6.1 Ensure Docker is running

Same pattern as neko.sh:

```bash
if ! is_service_active docker; then
  enable_service docker
  sleep 2
fi
```

### 6.2 MSSQL ARM warning

```bash
if (( OMARCHY_IS_ARM )); then
  warn "MSSQL Server is not available for ARM — skipping MSSQL container"
  # Skip the MSSQL docker run command
fi
```

---

## Verification

- [ ] `ssh.sh`: sshd starts and accepts connections on chroot-distro
- [ ] `docker.sh`: Docker daemon starts, can pull and run containers
- [ ] `code-server.sh`: code-server accessible on port 9301
- [ ] `tailscale.sh`: tailscaled starts with userspace networking
- [ ] `neko.sh`: Firefox container starts on ARM
- [ ] `docker-dbs.sh`: DB containers start, MSSQL skipped on ARM
- [ ] All scripts still work identically on x86_64 with systemd
