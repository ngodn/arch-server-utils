# Spec 04: Optimized Serviced Unit Files

## Overview

When running on chroot-distro, component scripts write optimized `.service` unit files instead of relying on the default packaged ones. serviced parses standard systemd unit files from `/etc/systemd/system/` (highest priority) and `/usr/lib/systemd/system/`.

Custom units go to `/etc/systemd/system/` to override package defaults.

## Why Custom Units

Default systemd units often include directives that don't work in a chroot:
- `ProtectSystem=`, `ProtectHome=`, `PrivateTmp=` — namespace isolation (requires real systemd)
- `Wants=network-online.target` — no networkd in chroot
- Socket activation (`fd://`) — unsupported by serviced
- `SystemdService=` in D-Bus files — serviced strips these but custom units avoid the issue entirely

## Unit File Specifications

### sshd.service

```ini
[Unit]
Description=OpenSSH Daemon

[Service]
Type=simple
ExecStart=/usr/bin/sshd -D
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Key differences from default:
- `Type=simple` with `-D` flag (foreground) instead of `Type=notify`
- No `ProtectSystem=strict`, `ProtectHome=read-only`
- No `RuntimeDirectory=sshd` (tmpfiles.d handles this)

### docker.service

```ini
[Unit]
Description=Docker Daemon

[Service]
Type=simple
ExecStart=/usr/bin/dockerd
ExecReload=/bin/kill -s HUP $MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

Key differences from default:
- No `fd://` socket activation
- No `Wants=containerd.service` (dockerd manages containerd internally)
- No `MountFlags=slave` (not supported in chroot)

### tailscaled.service

```ini
[Unit]
Description=Tailscale Daemon

[Service]
Type=simple
ExecStart=/usr/bin/tailscaled --state=/var/lib/tailscale/tailscaled.state --tun=userspace-networking
ExecStopPost=/usr/bin/tailscaled --cleanup
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Key differences from default:
- `--tun=userspace-networking` forced (no /dev/net/tun in chroot)
- No `After=network-pre.target`

### code-server.service

```ini
[Unit]
Description=Code Server

[Service]
Type=simple
ExecStart=/usr/bin/code-server --bind-addr 0.0.0.0:9301
Restart=on-failure
RestartSec=5
User=%USER%
Environment=PASSWORD=%PASSWORD%

[Install]
WantedBy=multi-user.target
```

`%USER%` and `%PASSWORD%` are substituted at install time by `code-server.sh`.

### containerd.service (if needed separately)

```ini
[Unit]
Description=containerd

[Service]
Type=simple
ExecStart=/usr/bin/containerd
Restart=always
RestartSec=5
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
```

## Unit File Placement

All custom units written to `/etc/systemd/system/<name>.service`.

serviced search order (highest priority first):
1. `/etc/systemd/system/`
2. `/run/systemd/system/`
3. `/usr/local/lib/systemd/system/`
4. `/usr/lib/systemd/system/`
5. `/lib/systemd/system/`

Custom units in `/etc/systemd/system/` override package defaults in `/usr/lib/systemd/system/`.

## Auto-Start Configuration

When `write_serviced_unit` is called with `enable_service`, serviced adds the unit to its autostart list. On next chroot login, serviced starts all enabled services automatically.
