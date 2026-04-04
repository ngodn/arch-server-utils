# Plan 3: Architecture-Specific Adaptations

## Goal

Modify scripts that have x86_64 assumptions to handle aarch64 correctly.

**Specs**: 03-per-script-adaptations.md, 05-arm-package-compatibility.md

**Depends on**: Plan 1 (detection variables must exist)

---

## Step 1: Modify `yay.sh`

### 1.1 Architecture-aware AUR helper clone

Replace the `yay-bin` clone with architecture detection:

```bash
if (( OMARCHY_IS_ARM )); then
  info "Building yay from source (binary not available for ARM)..."
  git clone https://aur.archlinux.org/yay.git /tmp/yay-build
else
  git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-build
fi
cd /tmp/yay-build
makepkg -si --noconfirm
cd -
rm -rf /tmp/yay-build
```

### 1.2 Verify fakeroot workaround

The existing fakeroot TCP IPC workaround for containers is architecture-agnostic. Verify it works on aarch64 chroot-distro:

```bash
# Existing logic (should work as-is):
if ! ipcs -s &>/dev/null 2>&1; then
  # SYSV IPC unavailable, use TCP
  echo "FAKEROOT_IPC_MODE=tcp" | sudo tee -a /etc/environment
fi
```

No changes needed here — just verify during testing.

---

## Step 2: Modify `windows-vm.sh`

### 2.1 Architecture-aware KVM module loading

Replace hardcoded Intel/AMD module loading:

```bash
if (( OMARCHY_IS_ARM )); then
  warn "Windows VM requires x86_64 KVM — will not work on aarch64"
  warn "Proceeding with setup, but the VM will not boot on this architecture"
  # ARM KVM uses generic module
  sudo modprobe kvm 2>/dev/null || true
else
  # x86_64: try Intel, then AMD
  sudo modprobe kvm-intel 2>/dev/null || sudo modprobe kvm-amd 2>/dev/null || true
fi
```

### 2.2 No other changes

The rest of the script (Docker pull, compose) will proceed but the dockurr/windows image is x86_64 only. The warning covers this — user was informed.

---

## Step 3: Modify `firewall.sh`

### 3.1 Add chroot-distro warning

At the top of the script, before any iptables/UFW operations:

```bash
if (( OMARCHY_IS_CHROOT_DISTRO )); then
  warn "UFW may conflict with Android's iptables rules"
  warn "Android manages iptables externally — rules may be overwritten"
fi
```

No other code changes — UFW itself works on ARM.

---

## Step 4: Modify `docker-dbs.sh` (MSSQL skip)

### 4.1 Skip MSSQL on ARM

Wrap the MSSQL container creation in an architecture check:

```bash
if (( OMARCHY_IS_ARM )); then
  warn "MSSQL Server Docker image is x86_64 only — skipping"
else
  # existing MSSQL docker run command
  docker run -d --name mssql ...
fi
```

All other databases (MySQL, PostgreSQL, Redis, MongoDB, MariaDB) have arm64 images.

---

## Step 5: Verify `dev-env.sh` (No Changes Needed)

Confirm these all work on aarch64 (no code changes required):

- [ ] `curl -fsSL https://astral.sh/uv/install.sh | sh` — uv provides aarch64 binaries (Tier 1)
- [ ] mise installs Node.js, Python, Ruby, Go, Rust for aarch64
- [ ] All mise runtime versions have aarch64 builds

---

## Verification

- [ ] `yay.sh`: yay builds from source on aarch64, AUR packages installable
- [ ] `windows-vm.sh`: warning displayed, script doesn't crash on ARM
- [ ] `firewall.sh`: warning displayed on chroot-distro
- [ ] `docker-dbs.sh`: MSSQL skipped on ARM, other DBs start normally
- [ ] `dev-env.sh`: uv and all mise runtimes install on aarch64
- [ ] All scripts unchanged behavior on x86_64
