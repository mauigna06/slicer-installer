#!/bin/sh
# 3D Slicer one-line installer for Linux and macOS.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/<you>/slicer-installer/main/install.sh | sh
#
# What it does:
#   * Installs the runtime dependencies Slicer needs (Linux only; macOS bundles them).
#   * Downloads the latest STABLE Slicer package from the official server.
#   * Linux : extracts the tarball into ~/.local/opt and links a launcher into ~/.local/bin.
#   * macOS : mounts the .dmg and copies Slicer.app into /Applications.
#
# Environment overrides:
#   SLICER_STABILITY     release (default) | nightly | any
#   SLICER_INSTALL_DIR   Linux only: where to unpack Slicer (default: ~/.local/opt)
#
# Docs: https://slicer.readthedocs.io/en/latest/user_guide/getting_started.html
set -eu

SLICER_STABILITY="${SLICER_STABILITY:-release}"
BASE_URL="https://download.slicer.org/download"

# ---------------------------------------------------------------------------- #
# helpers
# ---------------------------------------------------------------------------- #
log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

download() {
  # download <url> <output-file>
  if have curl; then
    curl -fSL --progress-bar "$1" -o "$2"
  elif have wget; then
    wget --show-progress -qO "$2" "$1"
  else
    err "Neither curl nor wget is available; cannot download Slicer."
  fi
}

as_root() {
  # run a command as root, using sudo only when needed
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif have sudo; then
    sudo "$@"
  else
    err "This step requires root but 'sudo' is not available: $*"
  fi
}

# ---------------------------------------------------------------------------- #
# Linux
# ---------------------------------------------------------------------------- #
install_linux_deps() {
  if have apt-get; then
    log "Installing runtime dependencies with apt-get (may prompt for sudo)…"
    as_root apt-get update -y
    # Common Debian/Ubuntu runtime libraries required by Slicer.
    pkgs="libglu1-mesa libpulse-mainloop-glib0 libnss3 qt5dxcb-plugin libsm6"
    # ALSA lib was renamed during the 64-bit time_t transition (Ubuntu 24.04+).
    if apt-cache show libasound2t64 >/dev/null 2>&1; then
      pkgs="$pkgs libasound2t64"
    else
      pkgs="$pkgs libasound2"
    fi
    # shellcheck disable=SC2086
    as_root apt-get install -y $pkgs
  elif have dnf; then
    log "Installing runtime dependencies with dnf (may prompt for sudo)…"
    as_root dnf install -y \
      mesa-libGLU mesa-libGL libnsl libXrender pulseaudio-libs-glib2 nss \
      libXcomposite libXdamage libXrandr ftgl libXcursor libXi libXtst \
      alsa-lib qt5-qtx11extras
  elif have pacman; then
    warn "Arch Linux detected. A prebuilt AUR package (3dslicer-bin) is also available."
    log "Installing common runtime libraries with pacman…"
    as_root pacman -Sy --needed --noconfirm \
      glu nss alsa-lib libxrender libxcomposite libxdamage libxrandr \
      libxcursor libxi libxtst ftgl || \
      warn "Some packages could not be installed automatically; install them manually if Slicer fails to start."
  else
    warn "Unrecognized package manager: skipping dependency installation."
    warn "Install Slicer's runtime dependencies manually (see the Slicer docs)."
  fi
}

install_linux() {
  install_linux_deps

  DEST="${SLICER_INSTALL_DIR:-$HOME/.local/opt}"
  BINDIR="$HOME/.local/bin"
  url="$BASE_URL?os=linux&stability=$SLICER_STABILITY"

  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT INT TERM

  log "Downloading 3D Slicer for Linux…"
  download "$url" "$TMP/slicer.tar.gz"

  log "Extracting archive…"
  mkdir -p "$TMP/x"
  tar -xzf "$TMP/slicer.tar.gz" -C "$TMP/x"

  srcdir="$(find "$TMP/x" -maxdepth 1 -type d -name 'Slicer-*' | head -n1)"
  [ -n "$srcdir" ] || err "Could not locate the extracted Slicer directory."

  appdir="$DEST/$(basename "$srcdir")"
  mkdir -p "$DEST"
  rm -rf "$appdir"
  mv "$srcdir" "$appdir"

  mkdir -p "$BINDIR"
  ln -sfn "$appdir/Slicer" "$BINDIR/Slicer"   # launcher on PATH
  ln -sfn "$appdir" "$DEST/Slicer"            # stable "current version" link

  log "Installed to: $appdir"
  log "Launcher    : $BINDIR/Slicer"
  case ":$PATH:" in
    *":$BINDIR:"*) log "Run it with: Slicer" ;;
    *) warn "$BINDIR is not on your PATH. Run it with: $BINDIR/Slicer (or add that dir to PATH)." ;;
  esac
}

# ---------------------------------------------------------------------------- #
# macOS
# ---------------------------------------------------------------------------- #
install_macos() {
  # Note: the download server ships an Intel (amd64) build; it runs natively on
  # Intel Macs and via Rosetta 2 on Apple Silicon.
  if [ "$(uname -m)" = "arm64" ] && ! /usr/bin/pgrep -q oahd 2>/dev/null; then
    warn "Apple Silicon detected. Slicer's Intel build needs Rosetta 2."
    warn "If Slicer won't launch, install it with: softwareupdate --install-rosetta --agree-to-license"
  fi

  url="$BASE_URL?os=macosx&stability=$SLICER_STABILITY"
  TMP="$(mktemp -d)"
  MNT="$TMP/mnt"
  cleanup_macos() {
    hdiutil detach "$MNT" -quiet >/dev/null 2>&1 || true
    rm -rf "$TMP"
  }
  trap cleanup_macos EXIT INT TERM

  log "Downloading 3D Slicer for macOS…"
  download "$url" "$TMP/Slicer.dmg"

  log "Mounting disk image…"
  mkdir -p "$MNT"
  hdiutil attach "$TMP/Slicer.dmg" -nobrowse -quiet -mountpoint "$MNT"

  app="$(/usr/bin/find "$MNT" -maxdepth 1 -name '*.app' | head -n1)"
  [ -n "$app" ] || err "No .app bundle found inside the disk image."

  dest="/Applications/$(basename "$app")"
  log "Installing $(basename "$app") to /Applications…"
  rm -rf "$dest" 2>/dev/null || as_root rm -rf "$dest"
  cp -R "$app" /Applications/ 2>/dev/null || as_root cp -R "$app" /Applications/

  # Best-effort: clear the quarantine flag so Gatekeeper lets it open.
  xattr -dr com.apple.quarantine "$dest" 2>/dev/null || true

  log "Installed to: $dest"
  log "Launch it from Launchpad/Applications, or run: open -a Slicer"
}

# ---------------------------------------------------------------------------- #
# main
# ---------------------------------------------------------------------------- #
OS="$(uname -s)"
case "$OS" in
  Linux)  install_linux ;;
  Darwin) install_macos ;;
  *) err "Unsupported operating system: $OS (this script handles Linux and macOS)." ;;
esac

log "3D Slicer installation complete."
