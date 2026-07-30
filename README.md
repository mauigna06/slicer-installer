# slicer-installer

```
                           .
                     -=+*#$+-=++- ..........
                .-*#$&XX@&-=xxxx* &XXXXXX$.-
              -*$XXXX&&X$ =x**xx+ X@@@@@@&.-
            +$XXX&&&&&&X.=x**x+-= X@@@@@@&.-
         .+$XX&&&&&&&&X=.x**x-=&$ &XXXXXX$ -       .
        -$XX&&&&&&&&&X$ *x*x--XX$ ======== +******+..
       *XX&&&&&&&&&&&X=-x*x+ &&&$ ######$x X@@@@@@X -
    . #X&&&&&&&&&&&&X& *x*x *X&&$ x######x X@@@@X@&..
    .#X&&&&&&&&&&&&&X*.x*x+ &&&&$ #$####$x @@@@@@@X.-
    xX&&&&&&&&&&&&&&X==x*x.=X&&&$ =++++++= *xxxxxx* .
  .=X&&&&&&&&&&&&&&&X.+x*x *X&&&$ $&&&&&&# x######x x######x .
   $X&&&&&&&&&&&&&&X& *xx* #X&&&$ X@@@@@@& &XXXXXX& #$$$$$$# .
  -X&&&&&&&&&&&&&&&X# x*x* $&&&&$ X@@@@@@& $X&&&&X$ #$$$$$$# .
  +X&&&&&&&&&&&&&&&X# x*x+ &&&&X$ X@@@@X@& $X&&&&X$ #$$####x .
  xX&&&&&&&&&&&&&&&X# x*x+ &&&X&* -------- -------- .- =++++..
  xX&&&&&&&&&&&&&&&X# x*x* &X&*.                     .*XX&XX.
  +X&&&&&&&&&&&&&&&X#.x*x* x*.                   .-+x&XXXX$-
 ..X&&&&&&&&&&&&&&&X&.*xx+            . ..-==+*x#&X@@X&$#+=#-.
   #X&&&&&&&&&&&&&&&&.**==#$$$$$##$$$$$&&XXX@@@XX&$#x*++*#X$ .
  .-X&&&&&&&&&&&&&&&X=..+$&&&&&&&&&&&&&$$##xx*++++**x#$&&$X-
    +X&&&&&&&&&&&&&&X$xxx*++++++++++++++***xx#$&&XX&$$$$#X*
     *X&&&&&&&&&&&&&&XXXXXXXXXXXXXXXXXXXXXXXXXXX&&$#$$$#Xx .
      *XX&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&$$$$$$X*
       =&X&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&$$$$$&&+
        .xXX&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&X&$$$$$$&#.
          -#&XX&&&&&&&&&&&&&&&&&&&&&&&&&&&&&$$#$$&&#=
            -x&XXX&&&&&&&&&&&&&&&&&&&&X&&&$##$&&$x=
              .=x$XXXX&&&&&&&&&&&&&&&&$$$$$&&$#+.
                 .=*#$&XXXXXXXXXXX&&&&&&&$#*=.
                      .=+**x#######x**+=-.
                              ...

                           3D Slicer
```

## What is this?

**One-line installers that make installing [3D Slicer](https://www.slicer.org/)
easy** on Linux, macOS and Windows.

Slicer is normally installed by hand: find the right download for your OS and
architecture, unpack or mount it, drop it somewhere sensible, and wire up a
launcher. These scripts do all of that for you in a single command. They:

- Download the latest **stable** Slicer straight from the official server.
- Verify the download against the publisher's **SHA-512** checksum.
- Install **per-user, without root/Administrator** — everything lands under your
  home directory.
- Add a launcher / menu entry so Slicer is ready to start.
- Notice when the same version is already installed and let you abort, reinstall,
  install side by side, or uninstall it.

## Install

### Linux / macOS

```sh
curl -fsSL https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.sh | sh
```

- **Linux** — extracts Slicer into `~/.local/opt`, links a launcher into
  `~/.local/bin`, and adds a desktop menu entry. It also prints (but never runs)
  the command that installs Slicer's runtime system libraries, so you decide
  whether to run it — or set `SLICER_INSTALL_DEPS` to have the installer run it
  for you (see [Building Docker images](#building-docker-images)).
- **macOS** — mounts the `.dmg` and copies `Slicer.app` into `~/Applications`.

### Windows

In cmd or PowerShell:

```powershell
powershell -c "irm https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.ps1 | iex"
```

Runs the official installer silently and per-user (no Administrator prompt). All
of Slicer's dependencies (Qt, Python, VTK, …) are bundled, so nothing else needs
installing.

## When a version is already installed

Before downloading, the installer checks whether the version it's about to
install is already there — on Linux and Windows each version lives in its own
directory, so this means that exact version; on macOS every version installs as
`Slicer.app`, so it means whatever bundle occupies the target. When it is, and
`SLICER_IF_EXISTING=prompt` (the default), you're offered four choices:

1. **Abort** — leave the existing installation untouched and exit. This is the
   default (just press Enter).
2. **Reinstall** — replace it with a freshly downloaded copy. On macOS, where any
   version overwrites any other, this discards the current `Slicer.app` for the
   version being downloaded.
3. **Install elsewhere** — keep both copies, installing into a directory you
   choose so the two live side by side.
4. **Uninstall** — remove the existing installation and exit without installing
   anything. Linux deletes the version's directory and its launcher, menu entry
   and symlinks; macOS deletes `Slicer.app`; Windows runs Slicer's own
   uninstaller silently.

Set `SLICER_IF_EXISTING` to skip the prompt: `abort` takes option 1, `reinstall`
takes option 2, and `uninstall` takes option 4. To install side by side without
being asked (option 3), point `SLICER_INSTALL_DIR` at a different directory.
Option 3 is only offered interactively.

These only apply when the target version is already installed, so
`SLICER_IF_EXISTING=uninstall` removes that version when it is present and
otherwise just installs it as usual.

### Non-interactive mode (automations / CI)

This prompt is the only point where either installer stops for input, so setting
`SLICER_NONINTERACTIVE` (to any value) is enough to run fully unattended: an
already-installed target version is reinstalled rather than prompted about. Set
`SLICER_IF_EXISTING=abort` or `=uninstall` alongside it to pick a different action
for that case. When there is no terminal at all — piped through `curl | sh`, in a
container, or under CI — the installers already detect it and reinstall without
hanging, so `SLICER_NONINTERACTIVE` mainly matters when a terminal *is* attached
but you still want zero prompts.

Every other override still applies in non-interactive mode. In particular,
`SLICER_VERSION` pins the exact version to install (and `SLICER_RELEASE_TYPE`
chooses the channel), so automations can install a known version reproducibly:

```sh
# Linux / macOS: install a pinned version, no prompts, quiet output
curl -fsSL https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.sh | \
  SLICER_NONINTERACTIVE=1 SLICER_VERSION=5.12.0 SLICER_QUIET=1 sh
```

```powershell
# Windows: install a pinned version, no prompts, quiet output
$env:SLICER_NONINTERACTIVE="1"; $env:SLICER_VERSION="5.12.0"; $env:SLICER_QUIET="1"
irm https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.ps1 | iex
```

When even a version is not precise enough — preview builds all share the same
version number, and a stable version can be rebuilt — `SLICER_REVISION` pins
one exact build by its Kitware revision (the number Slicer shows next to the
version, e.g. `5.12.3` revision `34627`), so every machine gets a byte-identical
package. A revision already names a single build across all channels, so
`SLICER_RELEASE_TYPE` is ignored, and combining it with `SLICER_VERSION` is an
error:

```sh
# Linux / macOS: install one exact build by revision
curl -fsSL https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.sh | \
  SLICER_NONINTERACTIVE=1 SLICER_REVISION=34627 SLICER_QUIET=1 sh
```

## Environment overrides

Both installers read the same environment variables:

| Variable             | Values / default                                | What it does                                                             |
|----------------------|-------------------------------------------------|--------------------------------------------------------------------------|
| `SLICER_RELEASE_TYPE`| `stable` *(default)* · `preview` · `any`        | Which release channel to install from.                                   |
| `SLICER_VERSION`     | e.g. `5.12.0` *(default: latest)*               | Pin an exact version instead of the latest.                              |
| `SLICER_REVISION`    | e.g. `34627`                                    | Pin one exact build by its Kitware revision. A revision is unambiguous across channels, so `SLICER_RELEASE_TYPE` is ignored; cannot be combined with `SLICER_VERSION`. |
| `SLICER_INSTALL_DIR` | see below                                        | Where to install Slicer (must be writable without root).                 |
| `SLICER_IF_EXISTING` | `prompt` *(default)* · `abort` · `reinstall` · `uninstall` | What to do when that version is already installed.             |
| `SLICER_NONINTERACTIVE` | set to any value                              | Never prompt (for automations / CI). If the target version is already installed it is reinstalled, unless `SLICER_IF_EXISTING` is `abort` or `uninstall`. |
| `SLICER_INSTALL_DEPS` | set to any value *(Linux only)*                 | Run the package-manager command that installs Slicer's runtime system libraries, instead of only printing it. Uses `sudo` when not already root. For building Docker images and similar automation. |
| `SLICER_QUIET`       | set to any value                                 | Silence progress messages, the logo and the download bar; warnings, errors and prompts still show. |
| `NO_COLOR`           | set to any value                                 | Disable colored output (and the logo).                                   |

`SLICER_INSTALL_DIR` defaults per platform:

- **Linux:** `~/.local/opt`
- **macOS:** `~/Applications`
- **Windows:** the installer's default, `%LOCALAPPDATA%\NA-MIC` (use an
  ASCII-only path)

## Building Docker images

On Linux the installer normally only *prints* the command that installs Slicer's
runtime system libraries, because doing so needs root and this script otherwise
writes only under `$HOME`. When you're building a container image that's exactly
what you want automated, so set `SLICER_INSTALL_DEPS` to have the installer run
that command for you (using `sudo` only when not already root). Combine it with
`SLICER_NONINTERACTIVE` so the "already installed" prompt never stops the build:

```dockerfile
FROM ubuntu:24.04

# curl to fetch the installer, ca-certificates for HTTPS.
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Slicer and its runtime system libraries in a single step.
#   SLICER_INSTALL_DEPS   run the apt-get command for Slicer's libraries
#   SLICER_NONINTERACTIVE never prompt
RUN curl -fsSL https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.sh \
    | SLICER_INSTALL_DEPS=1 SLICER_NONINTERACTIVE=1 sh
```

`SLICER_INSTALL_DEPS` picks the right command for the detected package manager
(`apt-get`, `dnf` or `pacman`) and refreshes the package lists first on `apt`, so
it works from a bare base image; if none of those package managers is found it
errors out rather than leaving you with an image that silently lacks the
libraries. It has no effect on macOS or Windows, where all of Slicer's
dependencies are bundled.

## Advanced use of the one-liners

Set any of the variables above inline before running the installer.

### Linux / macOS

Prefix the `sh` at the end of the pipe with the variables:

```sh
# Install a specific pinned version
curl -fsSL https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.sh | SLICER_VERSION=5.12.0 sh

# Install the latest preview build instead of the stable release
curl -fsSL https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.sh | SLICER_RELEASE_TYPE=preview sh

# Install from any channel (stable or preview, whichever is newest)
curl -fsSL https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.sh | SLICER_RELEASE_TYPE=any sh

# Install into a custom directory
curl -fsSL https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.sh | SLICER_INSTALL_DIR="$HOME/apps/slicer" sh

# Reinstall over an existing copy without being asked
curl -fsSL https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.sh | SLICER_IF_EXISTING=reinstall sh

# Abort instead of prompting if the version is already installed
curl -fsSL https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.sh | SLICER_IF_EXISTING=abort sh

# Uninstall the target version if it is installed, without prompting
curl -fsSL https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.sh | SLICER_IF_EXISTING=uninstall sh

# Disable colored output and the logo
curl -fsSL https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.sh | NO_COLOR=1 sh

# Silence progress messages (warnings and errors still show)
curl -fsSL https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.sh | SLICER_QUIET=1 sh

# Run fully unattended: never prompt (reinstall if the version is already present)
curl -fsSL https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.sh | SLICER_NONINTERACTIVE=1 sh

# Linux: also install Slicer's runtime system libraries (for Docker images / automation)
curl -fsSL https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.sh | SLICER_INSTALL_DEPS=1 SLICER_NONINTERACTIVE=1 sh

# Combine several overrides at once
curl -fsSL https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.sh | \
  SLICER_RELEASE_TYPE=preview SLICER_INSTALL_DIR="$HOME/apps/slicer" SLICER_IF_EXISTING=reinstall sh
```

### Windows

Set `$env:` variables before the pipe, separated by `;`:

```powershell
# Install a specific pinned version
$env:SLICER_VERSION="5.12.0"; irm https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.ps1 | iex

# Install the latest preview build instead of the stable release
$env:SLICER_RELEASE_TYPE="preview"; irm https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.ps1 | iex

# Install from any channel (stable or preview, whichever is newest)
$env:SLICER_RELEASE_TYPE="any"; irm https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.ps1 | iex

# Install into a custom directory (ASCII-only path)
$env:SLICER_INSTALL_DIR="C:\Slicer"; irm https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.ps1 | iex

# Reinstall over an existing copy without being asked
$env:SLICER_IF_EXISTING="reinstall"; irm https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.ps1 | iex

# Abort instead of prompting if the version is already installed
$env:SLICER_IF_EXISTING="abort"; irm https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.ps1 | iex

# Uninstall the target version if it is installed, without prompting
$env:SLICER_IF_EXISTING="uninstall"; irm https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.ps1 | iex

# Disable colored output and the logo
$env:NO_COLOR="1"; irm https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.ps1 | iex

# Silence progress messages (warnings and errors still show)
$env:SLICER_QUIET="1"; irm https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.ps1 | iex

# Run fully unattended: never prompt (reinstall if the version is already present)
$env:SLICER_NONINTERACTIVE="1"; irm https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.ps1 | iex

# Combine several overrides at once
$env:SLICER_RELEASE_TYPE="preview"; $env:SLICER_INSTALL_DIR="C:\Slicer"; $env:SLICER_IF_EXISTING="reinstall"; `
  irm https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.ps1 | iex
```

> **Note:** `$env:` variables persist for the rest of your PowerShell session.
> Open a new window (or `Remove-Item Env:\SLICER_VERSION`) before a later run if
> you don't want them applied again.

## Links

- 3D Slicer: <https://www.slicer.org/>
- Getting started guide: <https://slicer.readthedocs.io/en/latest/user_guide/getting_started.html>
- Download Slicer manually: <https://download.slicer.org/>
- Discourse post about this feature: <https://discourse.slicer.org/t/slicer-oneline-installer-script/>
