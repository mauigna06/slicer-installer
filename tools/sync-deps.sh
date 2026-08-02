#!/bin/sh
# Embed deps/<manager>.txt into install.sh.
#
# install.sh is piped straight into `sh`, so at run time it has no repo to read
# from: the package lists have to live inside the script itself. The canonical
# copy is still the plain-text files under deps/ — this script renders them into
# the generated block of install.sh, and `--check` re-renders and fails when the
# committed block no longer matches, so the two can never drift apart.
#
# Usage:
#   tools/sync-deps.sh            rewrite the generated block in install.sh
#   tools/sync-deps.sh --check    exit 1 (with a diff) if it is out of date
set -eu

repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
deps_dir="$repo_root/deps"
target="$repo_root/install.sh"

begin_marker='# --- BEGIN generated dependency lists (tools/sync-deps.sh) --- #'
end_marker='# --- END generated dependency lists --- #'

check=''
case "${1:-}" in
  --check) check=1 ;;
  '') ;;
  *) printf 'usage: %s [--check]\n' "$0" >&2; exit 2 ;;
esac

die() { printf 'sync-deps: %s\n' "$1" >&2; exit 1; }

# Flatten one list file into a single space-separated line: drop comments and
# blank lines, and squeeze the spaces around an "a | b" alternative so it stays
# one shell word for the installer to split on.
read_list() {
  [ -f "$1" ] || die "missing list file: $1"
  awk '
    { sub(/#.*/, "") }
    { gsub(/[ \t]*\|[ \t]*/, "|") }
    { for (i = 1; i <= NF; i++) printf "%s%s", (first++ ? " " : ""), $i }
  ' "$1"
}

# The block as it should appear in install.sh, markers included. Package names
# never contain a single quote, so quoting them this way is safe.
render() {
  printf '%s\n' "$begin_marker"
  printf "%s\n" "# Generated from deps/*.txt — edit those files, then run tools/sync-deps.sh."
  printf "DEPS_APT='%s'\n" "$(read_list "$deps_dir/apt.txt")"
  printf "DEPS_DNF='%s'\n" "$(read_list "$deps_dir/dnf.txt")"
  printf "DEPS_PACMAN='%s'\n" "$(read_list "$deps_dir/pacman.txt")"
  printf '%s\n' "$end_marker"
}

[ -f "$target" ] || die "missing $target"
grep -qxF "$begin_marker" "$target" || die "no BEGIN marker in install.sh"
grep -qxF "$end_marker" "$target" || die "no END marker in install.sh"

tmp_block="$(mktemp)"
tmp_out="$(mktemp)"
trap 'rm -f "$tmp_block" "$tmp_out"' EXIT INT HUP TERM

render >"$tmp_block"

# Splice the rendered block in place of everything between the markers.
awk -v block_file="$tmp_block" -v b="$begin_marker" -v e="$end_marker" '
  $0 == b {
    while ((getline line < block_file) > 0) print line
    close(block_file)
    skip = 1
    next
  }
  $0 == e { skip = 0; next }
  !skip
' "$target" >"$tmp_out"

if cmp -s "$tmp_out" "$target"; then
  [ -n "$check" ] && printf 'sync-deps: install.sh is up to date with deps/.\n'
  exit 0
fi

if [ -n "$check" ]; then
  printf 'sync-deps: install.sh does not match deps/. Run tools/sync-deps.sh and commit the result.\n\n' >&2
  diff -u "$target" "$tmp_out" >&2 || true
  exit 1
fi

cat "$tmp_out" >"$target"
printf 'sync-deps: updated install.sh from deps/.\n'
