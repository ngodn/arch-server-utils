#!/bin/bash
# Yay: AUR helper for installing community packages
[[ -z ${OMARCHY_SERVER_HELPERS:-} ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up Yay (AUR helper)..."

if command -v yay &>/dev/null; then
  success "Yay already installed"
  return 0
fi

# Build dependencies
pkg_install base-devel git

# In chroot/container environments (e.g. Android), SYSV IPC is often unavailable
# causing fakeroot to fail. Build from source with --with-ipc=tcp as a workaround.
# Can't use AUR (fakeroot-tcp) since yay isn't installed yet.
if ! fakeroot true &>/dev/null; then
  warn "fakeroot SYSV IPC not supported (chroot/container?), rebuilding with TCP IPC..."
  pkg_install autoconf automake libtool

  FAKEROOT_VER=$(pacman -Q fakeroot 2>/dev/null | awk '{print $2}' | cut -d- -f1)
  FAKEROOT_TMP=$(mktemp -d)
  cd "$FAKEROOT_TMP"

  curl -fsSL "https://deb.debian.org/debian/pool/main/f/fakeroot/fakeroot_${FAKEROOT_VER}.orig.tar.gz" -o fakeroot.tar.gz
  tar xf fakeroot.tar.gz
  cd fakeroot-"$FAKEROOT_VER"
  ./bootstrap
  ./configure --prefix=/usr --with-ipc=tcp --libdir=/usr/lib/libfakeroot
  make -j"$(nproc)"
  sudo make install
  cd /
  rm -rf "$FAKEROOT_TMP"

  if ! fakeroot true &>/dev/null; then
    error "Failed to build fakeroot with TCP IPC"
    return 1
  fi
  success "fakeroot rebuilt with TCP IPC support"
fi

# Clone and build yay
TMPDIR=$(mktemp -d)
git clone https://aur.archlinux.org/yay-bin.git "$TMPDIR/yay-bin"
cd "$TMPDIR/yay-bin"
makepkg -si --noconfirm
cd - >/dev/null
rm -rf "$TMPDIR"

success "Yay installed"
