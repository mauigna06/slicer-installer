# Slicer's runtime system libraries

Slicer bundles Qt, Python, VTK and the rest of its own dependencies, but it
still links against a handful of libraries that come from the distribution. The
files in this directory are the canonical list of those packages — one file per
package manager, one package per line.

| File | Package manager | Distributions |
| ---- | --------------- | ------------- |
| [`apt.txt`](apt.txt) | `apt-get` | Debian, Ubuntu and derivatives |
| [`dnf.txt`](dnf.txt) | `dnf` | Fedora, RHEL, CentOS Stream |
| [`pacman.txt`](pacman.txt) | `pacman` | Arch Linux and derivatives |

## Format

- One package per line; leading and trailing whitespace is ignored.
- Blank lines and `#` comments are ignored.
- `a | b` marks two names for the same library: the installer picks the first
  one the package manager actually knows about. Only `apt.txt` uses this, for
  the `libasound2` → `libasound2t64` rename.

## How these reach the installer

`install.sh` is fetched and piped to `sh` in one line, so it cannot read these
files at run time — it has to be self-contained. Instead the lists are embedded
into it, between the `BEGIN/END generated dependency lists` markers, by:

```sh
tools/sync-deps.sh
```

Run that after editing any file here and commit both changes together.
`tools/sync-deps.sh --check` re-renders the block and fails if it differs from
what is committed; CI runs it on every push, so the embedded copy cannot drift
away from these files.
