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
  or install side by side.

## Install

### Linux / macOS

```sh
curl -fsSL https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.sh | sh
```

- **Linux** — extracts Slicer into `~/.local/opt`, links a launcher into
  `~/.local/bin`, and adds a desktop menu entry. It also prints (but never runs)
  the command that installs Slicer's runtime system libraries, so you decide
  whether to run it.
- **macOS** — mounts the `.dmg` and copies `Slicer.app` into `~/Applications`.

### Windows

In cmd or PowerShell:

```powershell
powershell -c "irm https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.ps1 | iex"
```

Runs the official installer silently and per-user (no Administrator prompt). All
of Slicer's dependencies (Qt, Python, VTK, …) are bundled, so nothing else needs
installing.

## Environment overrides

Both installers read the same environment variables:

| Variable             | Values / default                                | What it does                                                             |
|----------------------|-------------------------------------------------|--------------------------------------------------------------------------|
| `SLICER_RELEASE_TYPE`| `stable` *(default)* · `preview` · `any`        | Which release channel to install from.                                   |
| `SLICER_VERSION`     | e.g. `5.12.0` *(default: latest)*               | Pin an exact version instead of the latest.                              |
| `SLICER_INSTALL_DIR` | see below                                        | Where to install Slicer (must be writable without root).                 |
| `SLICER_IF_EXISTING` | `prompt` *(default)* · `abort` · `reinstall`    | What to do when that version is already installed.                       |
| `NO_COLOR`           | set to any value                                 | Disable colored output (and the logo).                                   |

`SLICER_INSTALL_DIR` defaults per platform:

- **Linux:** `~/.local/opt`
- **macOS:** `~/Applications`
- **Windows:** the installer's default, `%LOCALAPPDATA%\NA-MIC` (use an
  ASCII-only path)

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

# Disable colored output and the logo
curl -fsSL https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.sh | NO_COLOR=1 sh

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

# Disable colored output and the logo
$env:NO_COLOR="1"; irm https://raw.githubusercontent.com/mauigna06/slicer-installer/main/install.ps1 | iex

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
