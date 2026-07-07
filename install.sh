#!/bin/sh
# 3D Slicer one-line installer for Linux and macOS.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/<you>/slicer-installer/main/install.sh | sh
#
# What it does:
#   * Preflights required tools and (on Linux) installs Slicer's runtime dependencies.
#   * Downloads the latest STABLE Slicer package from the official server.
#   * Verifies the download against the publisher's SHA-512 checksum.
#   * Linux : extracts the tarball into ~/.local/opt, links a launcher into
#             ~/.local/bin, and adds a desktop menu entry.
#   * macOS : mounts the .dmg and copies Slicer.app into /Applications.
#
# Environment overrides:
#   SLICER_STABILITY     release (default) | nightly | any
#   SLICER_VERSION       pin an exact version, e.g. 5.12.0 (default: latest)
#   SLICER_INSTALL_DIR   Linux only: where to unpack Slicer (default: ~/.local/opt)
#   SLICER_SKIP_DEPS     set to 1 to skip Linux dependency installation
#   NO_COLOR             set to disable colored output
#
# Docs: https://slicer.readthedocs.io/en/latest/user_guide/getting_started.html
#
# All code is wrapped in main(), invoked on the last line, so that a truncated
# `curl | sh` download can never execute a half-written script.

set -eu

SLICER_STABILITY="${SLICER_STABILITY:-release}"
SLICER_VERSION="${SLICER_VERSION:-}"
BASE_URL="https://download.slicer.org/download"
PACKAGES_API="https://slicer-packages.kitware.com/api/v1"

# Initialized empty so `set -u` is satisfied before setup_colors() runs.
C_BLUE='' C_YELLOW='' C_RED='' C_GREEN='' C_RESET=''

# ---------------------------------------------------------------------------- #
# helpers
# ---------------------------------------------------------------------------- #
setup_colors() {
  if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_BLUE=$(printf '\033[1;34m'); C_YELLOW=$(printf '\033[1;33m')
    C_RED=$(printf '\033[1;31m'); C_GREEN=$(printf '\033[1;32m')
    C_RESET=$(printf '\033[0m')
  fi
}

log()  { printf '%s==>%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
warn() { printf '%sWARN:%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()  { printf '%sERROR:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

require_tools() {
  missing=''
  for t in "$@"; do
    have "$t" || missing="$missing $t"
  done
  [ -z "$missing" ] || err "Missing required tools:$missing"
}

# Download a URL to a file over enforced HTTPS/TLS 1.2, with retries.
download() {
  if have curl; then
    curl --fail --location --proto '=https' --tlsv1.2 \
         --retry 3 --retry-delay 2 --retry-connrefused \
         --progress-bar --output "$2" "$1"
  elif have wget; then
    wget --https-only --secure-protocol=TLSv1_2 --tries=3 --timeout=30 \
         --show-progress -qO "$2" "$1"
  else
    err "Neither curl nor wget is available; cannot download Slicer."
  fi
}

# Fetch a URL to stdout (for JSON metadata), same TLS hardening.
fetch() {
  if have curl; then
    curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 "$1"
  elif have wget; then
    wget --https-only --secure-protocol=TLSv1_2 -qO- "$1"
  fi
}

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif have sudo; then
    sudo "$@"
  else
    err "This step requires root but 'sudo' is not available: $*"
  fi
}

# Resolve the Girder item id backing a download endpoint (needs curl).
resolve_item_id() {
  have curl || { echo ''; return 0; }
  redir=$(curl --fail --silent --proto '=https' --tlsv1.2 \
               -o /dev/null -w '%{redirect_url}' "$1" 2>/dev/null || true)
  case "$redir" in
    */bitstream/*) basename "$redir" ;;
    *) echo '' ;;
  esac
}

# Extract the publisher's SHA-512 for a given item id (empty if unavailable).
get_sha512() {
  meta=$(fetch "$PACKAGES_API/item/$1" 2>/dev/null || true)
  printf '%s' "$meta" \
    | grep -oE '"sha512"[[:space:]]*:[[:space:]]*"[a-f0-9]{128}"' \
    | grep -oE '[a-f0-9]{128}' | head -n1
}

verify_sha512() {
  # verify_sha512 <file> <expected-hex>
  if have sha512sum; then
    actual=$(sha512sum "$1" | awk '{print $1}')
  elif have shasum; then
    actual=$(shasum -a 512 "$1" | awk '{print $1}')
  else
    warn "No SHA-512 tool found; skipping checksum verification."
    return 0
  fi
  [ "$actual" = "$2" ] || err "Checksum verification failed (expected $2, got $actual)."
  log "Checksum verified (SHA-512)."
}

# Download the package for an OS, verifying its checksum when possible.
# Writes the package to $1 (output path); $2 is the OS token (linux|macosx).
download_verified() {
  out="$1"; os="$2"
  dl_url="$BASE_URL?os=$os&stability=$SLICER_STABILITY"
  [ -n "$SLICER_VERSION" ] && dl_url="$dl_url&version=$SLICER_VERSION"

  item_id=$(resolve_item_id "$dl_url")
  sha=''; src_url="$dl_url"
  if [ -n "$item_id" ]; then
    sha=$(get_sha512 "$item_id")
    src_url="$PACKAGES_API/item/$item_id/download"
  fi

  log "Downloading 3D Slicer ($os)…"
  download "$src_url" "$out"

  if [ -n "$sha" ]; then
    verify_sha512 "$out" "$sha"
  else
    warn "Could not obtain a checksum from the server; skipping verification."
  fi
}

# ---------------------------------------------------------------------------- #
# Linux
# ---------------------------------------------------------------------------- #
install_linux_deps() {
  if [ "${SLICER_SKIP_DEPS:-0}" = "1" ]; then
    log "SLICER_SKIP_DEPS=1 set; skipping dependency installation."
    return 0
  fi
  if [ "$(id -u)" -ne 0 ] && ! have sudo; then
    warn "No root privileges and 'sudo' not found; skipping dependency installation."
    warn "If Slicer fails to start, install its runtime libraries manually (see docs)."
    return 0
  fi

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

# Add an XDG desktop menu entry so Slicer appears in application launchers.
install_desktop_entry() {
  appdir="$1"
  apps_dir="$HOME/.local/share/applications"
  desktop_file="$apps_dir/slicer.desktop"
  mkdir -p "$apps_dir"

  icon=$(find "$appdir" -maxdepth 3 -iname 'slicer*.png' 2>/dev/null | head -n1 || true)
  [ -n "$icon" ] || icon="$appdir/Slicer"

  cat > "$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Name=3D Slicer
GenericName=Medical Image Computing
Comment=Analyze and visualize medical image data
Exec=$appdir/Slicer %F
Icon=$icon
Terminal=false
Categories=Graphics;Science;Education;
Keywords=medical;imaging;DICOM;visualization;segmentation;
EOF

  if have update-desktop-database; then
    update-desktop-database "$apps_dir" >/dev/null 2>&1 || true
  fi
  log "Desktop menu entry created: $desktop_file"
}

install_linux() {
  require_tools tar
  install_linux_deps

  DEST="${SLICER_INSTALL_DIR:-$HOME/.local/opt}"
  BINDIR="$HOME/.local/bin"

  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT INT TERM

  download_verified "$TMP/slicer.tar.gz" linux

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

  install_desktop_entry "$appdir"

  log "Installed to: $appdir"
  log "Launcher    : $BINDIR/Slicer"
  case ":$PATH:" in
    *":$BINDIR:"*) log "Run it with: ${C_GREEN}Slicer${C_RESET} (or from your app menu)." ;;
    *) warn "$BINDIR is not on your PATH. Run it with: $BINDIR/Slicer (or add that dir to PATH)." ;;
  esac
}

# ---------------------------------------------------------------------------- #
# macOS
# ---------------------------------------------------------------------------- #
install_macos() {
  require_tools hdiutil

  # The download server ships an Intel (amd64) build; it runs natively on Intel
  # Macs and via Rosetta 2 on Apple Silicon.
  if [ "$(uname -m)" = "arm64" ] && ! /usr/bin/pgrep -q oahd 2>/dev/null; then
    warn "Apple Silicon detected. Slicer's Intel build needs Rosetta 2."
    warn "If Slicer won't launch, install it with: softwareupdate --install-rosetta --agree-to-license"
  fi

  # Stop any running instance so /Applications can be replaced cleanly.
  if /usr/bin/pgrep -x Slicer >/dev/null 2>&1; then
    log "Stopping running Slicer instance…"
    /usr/bin/pkill -x Slicer 2>/dev/null || true
    sleep 1
  fi

  TMP="$(mktemp -d)"
  MNT="$TMP/mnt"
  cleanup_macos() {
    hdiutil detach "$MNT" -quiet >/dev/null 2>&1 || true
    rm -rf "$TMP"
  }
  trap cleanup_macos EXIT INT TERM

  download_verified "$TMP/Slicer.dmg" macosx

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
  log "Launch it from Launchpad/Applications, or run: ${C_GREEN}open -a Slicer${C_RESET}"
}

# ---------------------------------------------------------------------------- #
# main
# ---------------------------------------------------------------------------- #
main() {
  setup_colors
  have curl || have wget || err "This installer requires 'curl' or 'wget'."

  OS="$(uname -s)"
  case "$OS" in
    Linux)  install_linux ;;
    Darwin) install_macos ;;
    *) err "Unsupported operating system: $OS (this script handles Linux and macOS)." ;;
  esac

  log "${C_GREEN}3D Slicer installation complete.${C_RESET}"
}

main "$@"
