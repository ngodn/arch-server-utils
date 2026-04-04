# Spec 05: ARM (aarch64) Package Compatibility

## Overview

Verified package availability for all omarchy-server components on Arch Linux ARM (aarch64). Research conducted 2026-04-04.

## Official ALARM Repos (pacman -S)

All of the following are confirmed available in the Arch Linux ARM `extra` repo for aarch64:

| Package | Script | Status |
|---------|--------|--------|
| bash-completion | shell.sh | Available |
| bat | shell.sh | Available |
| btop | cli-tools.sh | Available |
| docker | docker.sh | Available |
| docker-buildx | docker.sh | Available |
| docker-compose | docker.sh | Available |
| dust | cli-tools.sh | Available |
| eza | shell.sh | Available |
| fd | cli-tools.sh | Available |
| fastfetch | cli-tools.sh | Available |
| fzf | shell.sh | Available |
| github-cli | git-tools.sh | Available |
| gum | tz-select.sh | Available |
| jq | cli-tools.sh | Available |
| lazydocker | docker.sh | Available (official, not AUR) |
| lazygit | git-tools.sh | Available (official, not AUR) |
| neovim | neovim.sh | Available |
| openssh | ssh.sh | Available |
| plocate | cli-tools.sh | Available |
| ripgrep | cli-tools.sh | Available |
| starship | starship.sh | Available |
| tailscale | tailscale.sh | Available |
| tldr | cli-tools.sh | Available |
| tmux | tmux.sh | Available |
| tree | cli-tools.sh | Available |
| ufw | firewall.sh | Available |
| zoxide | shell.sh | Available |

## Non-Repo Packages (Install Scripts / npm)

| Package | Script | Install Method | aarch64 Support |
|---------|--------|---------------|-----------------|
| claude-code | claude-code.sh | `npm i -g @anthropic-ai/claude-code` | Works via npm, Node.js aarch64 required |
| code-server | code-server.sh | AUR or standalone tarball | arm64 binaries in GitHub releases |
| mise | mise.sh | curl install script | Official aarch64 binaries |
| uv | dev-env.sh | curl install script | Tier 1 aarch64 support |
| starship | starship.sh | pacman (preferred) or curl script | Both methods support aarch64 |

## AUR Packages

| Package | Script | aarch64 Build | Notes |
|---------|--------|--------------|-------|
| yay | yay.sh | Source build only | `yay-bin` is x86_64 only; use `yay` (source) on ARM |
| code-server | code-server.sh | AUR builds from source | Slow build; prefer GitHub binary release |

## Docker Images (arm64)

| Image | Script | arm64 Support | Notes |
|-------|--------|--------------|-------|
| m1k1o/neko-firefox | neko.sh | Yes | Multi-arch manifest |
| m1k1o/neko-chromium | neko.sh | Limited | May not be available for arm64 |
| dockurr/windows | windows-vm.sh | No | x86_64 only, fundamental incompatibility |
| mysql | docker-dbs.sh | Yes | Official arm64 images |
| postgres | docker-dbs.sh | Yes | Official arm64 images |
| redis | docker-dbs.sh | Yes | Official arm64 images |
| mongo | docker-dbs.sh | Yes | Official arm64 images |
| mariadb | docker-dbs.sh | Yes | Official arm64 images |
| mcr.microsoft.com/mssql/server | docker-dbs.sh | No | x86_64 only |

## Key Findings

1. **lazydocker and lazygit** are in official ALARM repos — no AUR needed on ARM (simplifies install)
2. **MSSQL** Docker image doesn't support arm64 — `docker-dbs.sh` should warn about this
3. **yay** must be built from source on ARM (use `yay` not `yay-bin`)
4. **code-server** has prebuilt arm64 tarballs — faster than AUR source build
5. All mise-managed runtimes (Node, Python, Ruby, Go, Rust, Java, PHP, etc.) support aarch64
