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
# causing fakeroot to fail. Build a temporary fakeroot with TCP IPC to bootstrap,
# then use it to install fakeroot-tcp from AUR properly via makepkg.
# Ref: https://gist.github.com/tytydraco/df14e4f7af737e7b51ba35842f75342b
if ! fakeroot true &>/dev/null; then
  warn "fakeroot SYSV IPC not supported (chroot/container?), bootstrapping fakeroot-tcp..."
  pkg_install autoconf automake libtool po4a

  FAKEROOT_TMP=$(mktemp -d)
  cd "$FAKEROOT_TMP"

  # Build a temporary fakeroot with TCP IPC into /opt/fakeroot
  curl -fsSL "http://ftp.debian.org/debian/pool/main/f/fakeroot/fakeroot_1.37.2.orig.tar.gz" -o fakeroot.tar.gz
  tar xf fakeroot.tar.gz
  cd fakeroot-1.37.2
  ./bootstrap
  ./configure --prefix=/opt/fakeroot --libdir=/opt/fakeroot/libs --disable-static --with-ipc=tcp
  make -j"$(nproc)"
  sudo make install

  # Put temporary fakeroot first in PATH, then build fakeroot-tcp from AUR
  export PATH="/opt/fakeroot/bin:$PATH"
  cd "$FAKEROOT_TMP"
  git clone https://aur.archlinux.org/fakeroot-tcp.git
  cd fakeroot-tcp
  makepkg -si --noconfirm

  # Clean up temporary fakeroot
  sudo rm -rf /opt/fakeroot
  cd /
  rm -rf "$FAKEROOT_TMP"

  if ! fakeroot true &>/dev/null; then
    error "Failed to install fakeroot-tcp"
    return 1
  fi
  success "fakeroot-tcp installed"
fi

# Clone and build yay
TMPDIR=$(mktemp -d)
git clone https://aur.archlinux.org/yay-bin.git "$TMPDIR/yay-bin"
cd "$TMPDIR/yay-bin"
makepkg -si --noconfirm
cd - >/dev/null
rm -rf "$TMPDIR"

success "Yay installed"
