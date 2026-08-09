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
- Leave two small scripts inside the installation for the things that are *not*
  installing Slicer — its Linux system libraries, and its interface language —
  so you can run those when you want them. See [After installing](#after-installing).

## Install

### Linux / macOS

```sh
curl -fsSL https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.sh | sh
```

- **Linux** — extracts Slicer into `~/.local/opt`, links a launcher into
  `~/.local/bin`, and adds a desktop menu entry.
- **macOS** — mounts the `.dmg` and copies `Slicer.app` into `~/Applications`.

### Windows

In cmd or PowerShell:

```powershell
powershell -c "irm https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.ps1 | iex"
```

Runs the official installer silently and per-user (no Administrator prompt). All
of Slicer's dependencies (Qt, Python, VTK, …) are bundled, so nothing else needs
installing.

## After installing

Installing Slicer is all the one-liner does. The two things that are *not* that
— installing Slicer's Linux runtime libraries, and choosing an interface
language — are separate scripts that live inside the installation, in Slicer's
own `bin` directory, and you run them when you want them:

| Script | Platform | What it does |
| ------ | -------- | ------------ |
| `slicer-deps` | Linux | Prints the package-manager command that installs the system libraries Slicer needs; `--install` runs it |
| `slicer-language` | Linux · macOS | `list` prints the available interface languages; a code like `es-419` installs it and switches Slicer to it |
| `slicer-language.ps1` | Windows | The same, for Windows |

```sh
# Linux — the installer prints this path when it finishes
~/.local/opt/Slicer/bin/slicer-deps                 # print the command
~/.local/opt/Slicer/bin/slicer-deps --install       # run it (uses sudo)

~/.local/opt/Slicer/bin/slicer-language list        # what languages exist
~/.local/opt/Slicer/bin/slicer-language es-419      # install one and switch to it
```

```sh
# macOS
~/Applications/Slicer.app/Contents/bin/slicer-language list
```

```powershell
# Windows
& "$env:LOCALAPPDATA\NA-MIC\Slicer 5.12.3\bin\slicer-language.ps1" list
& "$env:LOCALAPPDATA\NA-MIC\Slicer 5.12.3\bin\slicer-language.ps1" es-419
```

`slicer-deps` needs root, which is exactly why it is a separate step: the
installer itself never asks for it and only ever writes under `$HOME`.
`slicer-language` needs network access, Slicer's runtime libraries, and — on
Linux — a display; headless machines can supply one with `xvfb-run`. It installs
the [SlicerLanguagePacks](https://github.com/Slicer/SlicerLanguagePacks)
extension, downloads and compiles that language's translation files, verifies
they load, and only then switches Slicer's interface over.

These scripts are maintained in [`inner/`](inner/) and are on their way into the
Slicer packages themselves ([Slicer#9294](https://github.com/Slicer/Slicer/pull/9294)).
Until every package ships them, the installer writes its own copies — but only
when the package does not already contain them, so an upstream copy always wins.

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
already-installed target version exits 0 without downloading anything, so
repeated runs (a config-management converge, a re-run CI job) are cheap no-ops.
Set `SLICER_IF_EXISTING=reinstall` alongside it to replace the existing copy
anyway, or `=uninstall` to remove it. On macOS an installed *different* version
is still replaced, since every version installs as the same `Slicer.app` — that
is an upgrade, not a redundant reinstall. When there is no terminal at all —
piped through `curl | sh`, in a container, or under CI — the installers detect
it and apply the same rule (already-installed target version → exit 0, no
download) rather than hang, so `SLICER_NONINTERACTIVE` mainly matters when a
terminal *is* attached but you still want zero prompts.

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
| `SLICER_NONINTERACTIVE` | set to any value                              | Never prompt (for automations / CI). If the target version is already installed the script exits 0 without downloading anything, so repeated runs converge; set `SLICER_IF_EXISTING=reinstall` to replace it anyway. |
| `SLICER_QUIET`       | set to any value                                 | Silence progress messages, the logo and the download bar; warnings, errors and prompts still show. |
| `NO_COLOR`           | set to any value                                 | Disable colored output (and the logo).                                   |
| `XDG_CACHE_HOME`     | *(default: `~/.cache`)* *(Linux/macOS only)*     | Where the verified download is cached, under `slicer-installer/`, so a re-run doesn't download it again. Windows always uses `%LOCALAPPDATA%\slicer-installer`. See [Download cache](#download-cache). |

`SLICER_INSTALL_DIR` defaults per platform:

- **Linux:** `~/.local/opt`
- **macOS:** `~/Applications`
- **Windows:** the installer's default, `%LOCALAPPDATA%\NA-MIC` (use an
  ASCII-only path)

## Building Docker images

Installing Slicer and installing its runtime system libraries are two steps: the
second needs root, and the installer never asks for it. In an image build you
are already root and automating both is exactly the point, so run them one after
the other. Set `SLICER_NONINTERACTIVE` so the "already installed" prompt never
stops the build, and pass `--install --yes` to `slicer-deps` so it installs
rather than prints, and fails fast instead of waiting for a `sudo` password
nothing can type:

```dockerfile
FROM ubuntu:24.04

# curl to fetch the installer, ca-certificates for HTTPS.
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 1. Install Slicer.
#   SLICER_NONINTERACTIVE never prompt
#   XDG_CACHE_HOME        keep the cached download out of the image (see below)
# 2. Install the system libraries it needs, with the script step 1 left behind
#    in Slicer's bin directory.
RUN curl -fsSL https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.sh \
    | SLICER_NONINTERACTIVE=1 XDG_CACHE_HOME=/tmp/slicer-cache sh \
    && "$HOME/.local/opt/Slicer/bin/slicer-deps" --install --yes \
    && rm -rf /tmp/slicer-cache
```

`slicer-deps` picks the right command for the detected package manager
(`apt-get`, `dnf` or `pacman`) and refreshes the package lists first on `apt`, so
it works from a bare base image; if none of those package managers is found it
errors out rather than leaving you with an image that silently lacks the
libraries. There is no equivalent on macOS or Windows, where all of Slicer's
dependencies are bundled.

Note that the two steps fail at different points than they used to: a missing
package manager or an unusable `sudo` is now reported *after* Slicer has been
downloaded and installed, because `slicer-deps` runs as its own command. The
build still fails — just one layer later.

Which packages those are is kept as plain text in [`deps/`](deps/), one file per
package manager. Neither `slicer-deps` nor `install.sh` can read them at run
time — one ships inside a Slicer installation, the other is piped straight into
`sh` — so they are embedded in two hops (`deps/*.txt` → `inner/slicer-deps` →
`install.sh`) by [`tools/sync-embedded.sh`](tools/sync-embedded.sh), which CI
re-runs with `--check` to fail on any drift. Edit the files in `deps/`, run that
script, and commit all the changes together.

### Download cache

To make re-runs cheap, the installer keeps the verified package it downloaded in
`${XDG_CACHE_HOME:-$HOME/.cache}/slicer-installer` (on Windows,
`%LOCALAPPDATA%\slicer-installer`) and reuses it whenever it still matches the
published checksum. On a normal machine that's what you want; in an image build
it is not, because that package is ~1 GB of `.tar.gz` that you already unpacked
and will never read again — and it lands in the layer permanently.

So point `XDG_CACHE_HOME` at a throwaway directory and delete it **in the same
`RUN`**, as the Dockerfile above does. Deleting it in a later `RUN` doesn't help:
the earlier layer still carries the file, and the image still pays for it.

The same applies to any other build that snapshots `$HOME` — VM images, CI
caches you persist between jobs, `docker commit`.

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

# Linux: also install Slicer's runtime system libraries (for Docker images / automation).
# A second step now, not an override -- see "After installing".
curl -fsSL https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.sh | SLICER_NONINTERACTIVE=1 sh
"$HOME/.local/opt/Slicer/bin/slicer-deps" --install --yes

# See which interface languages are available (installs nothing)
"$HOME/.local/opt/Slicer/bin/slicer-language" list

# Install the SlicerLanguagePacks extension and switch the interface to Spanish
"$HOME/.local/opt/Slicer/bin/slicer-language" es-419

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

# See which interface languages are available (installs nothing).
# A separate script now, not an override -- see "After installing".
& "$env:LOCALAPPDATA\NA-MIC\Slicer 5.12.3\bin\slicer-language.ps1" list

# Install the SlicerLanguagePacks extension and switch the interface to Spanish
& "$env:LOCALAPPDATA\NA-MIC\Slicer 5.12.3\bin\slicer-language.ps1" es-419

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
