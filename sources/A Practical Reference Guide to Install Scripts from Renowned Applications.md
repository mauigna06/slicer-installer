# A Practical Reference Guide to Install Scripts (install.sh & install.ps1) from Renowned Applications

## TL;DR
- The gold-standard installers converge on a small set of patterns: wrap everything in a `main()` function (so a truncated `curl | sh` download never runs half a script), detect OS/arch with `uname`, fail fast with `set -eu`/`$ErrorActionPreference='Stop'`, download over enforced HTTPS/TLS 1.2, and modify PATH idempotently — study Ollama, rustup, Deno, Bun, Docker, Tailscale, oh-my-zsh (shell) and Bun, Scoop (PowerShell) as your templates.
- For **desktop apps specifically**, the reference behavior is: on macOS drop an `.app` bundle into `/Applications` and symlink a CLI helper into `/usr/local/bin` (Ollama); on Linux ship a `.desktop` entry to `~/.local/share/applications` and run `update-desktop-database`; on Windows create Start Menu/desktop `.lnk` shortcuts via `WScript.Shell` and register an uninstaller under `HKCU:\...\Uninstall\` (Bun).
- PowerShell installers differ meaningfully from shell ones: they must set `SecurityProtocol`/TLS or delegate to `curl.exe`, respect Execution Policy, avoid running as admin by default, and write PATH to the registry using `DoNotExpandEnvironmentNames` to avoid corrupting `%VAR%` entries.

## Key Findings

### Curated list of renowned reference scripts (with direct source URLs)

**Shell (install.sh / .sh):**
- **Homebrew** — `https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh` (Bash; served at this raw URL and used directly in the documented one-liner; honors `NONINTERACTIVE=1` for automation per the Homebrew/install README).
- **rustup** — `https://github.com/rust-lang/rustup/blob/main/rustup-init.sh` (POSIX sh; the canonical arch-detection + TLS-hardening reference; served at `https://sh.rustup.rs`).
- **Deno** — `https://github.com/denoland/deno_install/blob/master/install.sh` (served at `https://deno.land/install.sh`).
- **Bun** — `https://github.com/oven-sh/bun/blob/main/src/cli/install.sh` (served at `https://bun.sh/install`).
- **Ollama** — `https://github.com/ollama/ollama/blob/main/scripts/install.sh` (served at `https://ollama.com/install.sh`; best desktop+CLI hybrid example — ~455 lines covering macOS app bundle, Linux binary, systemd, GPU drivers).
- **Tailscale** — `https://github.com/tailscale/tailscale/blob/main/scripts/installer.sh` (served at `https://tailscale.com/install.sh`; best distro/package-manager detection).
- **Docker** — `https://github.com/docker/docker-install/blob/master/install.sh` (served at `https://get.docker.com`; best `--dry-run` and `sudo`/`su` handling).
- **nvm** — `https://github.com/nvm-sh/nvm/blob/master/install.sh` (best shell-profile detection).
- **oh-my-zsh** — `https://github.com/ohmyzsh/ohmyzsh/blob/master/tools/install.sh` (best colored logging, unattended/CI mode, `chsh` handling).
- **Starship** — `https://github.com/starship/starship/blob/master/install/install.sh` (best `--help`/flag parsing and cross-platform binary installer).

**PowerShell (install.ps1):**
- **Bun** — `https://bun.sh/install.ps1` (also `https://github.com/oven-sh/bun/blob/main/src/cli/install.ps1`; best registry-PATH + uninstaller-registration reference).
- **Scoop** — `https://github.com/ScoopInstaller/Install/blob/master/install.ps1` (served at `https://get.scoop.sh`; best prerequisite gating and admin-refusal logic).
- **Deno** — `https://deno.land/install.ps1` (compact PowerShell reference).
- **Ollama** — `https://ollama.com/install.ps1`.

### The single most important safety pattern: wrap everything in `main`
Ollama and Tailscale both open their scripts with the same comment and structure. Tailscale's file (`scripts/installer.sh`) begins verbatim:
```sh
set -eu
# All the code is wrapped in a main function that gets called at the
# bottom of the file, so that a truncated partial download doesn't end
# up executing half a script.
main() {
  ...
}
main
```
This is the defining safety idiom for `curl | sh` installers: because the shell executes the stream as it arrives, a dropped connection mid-download could otherwise run a half-written command. Defining a function and only invoking it on the last line guarantees the whole script downloaded before anything runs.

## Details

### 1. OS / architecture detection

**Minimal (Ollama, Bun):** normalize `uname -m` into your release naming.
```sh
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) error "Unsupported architecture: $ARCH" ;;
esac
```
Bun additionally detects Alpine (musl) via `[ -f /etc/alpine-release ]`, detects Rosetta 2 on macOS via `sysctl -n sysctl.proc_translated`, and selects a `-baseline` build when AVX2 is absent (`grep avx2 /proc/cpuinfo`).

**Gold standard (rustup `get_architecture`):** handles libc flavor, Rosetta lies, and 32/64-bit detection.
```sh
_ostype="$(uname -s)"; _cputype="$(uname -m)"; _clibtype="gnu"
if [ "$_ostype" = Linux ]; then
    if ldd --version 2>&1 | grep -q 'musl'; then _clibtype="musl"; fi
fi
if [ "$_ostype" = Darwin ] && [ "$_cputype" = i386 ]; then
    # Darwin `uname -m` lies
    if sysctl hw.optional.x86_64 | grep -q ': 1'; then _cputype=x86_64; fi
fi
```
rustup also inspects the ELF header of `/proc/self/exe` with `od` to determine true bitness — the most thorough detection in the wild.

**Distro detection (Tailscale):** source `/etc/os-release` and switch on `$ID`/`$VERSION_ID` to pick a `PACKAGETYPE` (apt/dnf/yum/zypper/pacman), then configure the official repo. This is the reference for installers that hand off to a native package manager rather than dropping a binary.

**PowerShell (Bun):** reads the architecture from the registry (survives ARM64 emulation) rather than trusting env vars:
```powershell
$Arch = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment').PROCESSOR_ARCHITECTURE
```
Baseline (non-AVX2) CPUs are detected with `IsProcessorFeaturePresent(40)` via P/Invoke, with a recursive `-ForceBaseline` fallback triggered if `bun.exe --revision` exits with `STATUS_ILLEGAL_INSTRUCTION` (`1073741795`).

### 2. Safe error handling
- **Shell:** `set -eu` (Ollama, Tailscale; Docker uses `set -e`) or `set -euo pipefail` (Bun's install.sh uses `#!/usr/bin/env bash` + `set -euo pipefail`). `-e` exits on error, `-u` errors on unset variables, `pipefail` propagates failures through pipes.
- Use a `trap` for cleanup: `TEMP_DIR=$(mktemp -d); cleanup() { rm -rf $TEMP_DIR; }; trap cleanup EXIT` (Ollama). Ollama cleverly chains traps: `trap install_success EXIT` prints the success banner, and `trap start_service EXIT` restarts the systemd service on exit.
- **PowerShell:** set `$ErrorActionPreference = "Stop"` (Bun) so non-terminating errors become terminating; Scoop sets it right before invoking its main function.

### 3. Dependency checking
Common helper across Ollama, Docker, oh-my-zsh:
```sh
command_exists() { command -v "$@" >/dev/null 2>&1; }
```
Ollama's `require` accumulates all missing tools and reports them together, rather than failing on the first:
```sh
require() {
    local MISSING=''
    for TOOL in $*; do
        if ! available $TOOL; then MISSING="$MISSING $TOOL"; fi
    done
    echo $MISSING
}
NEEDS=$(require curl awk grep sed tee xargs)
```
Bun does a one-liner: `command -v unzip >/dev/null || error 'unzip is required to install bun'`.

### 4. Download & verification
- **Shell:** the canonical curl invocation is `curl -fsSL <url>` (`-f` fail on HTTP errors, `-s` silent, `-S` still show errors, `-L` follow redirects). For a downloaded file, Ollama and Bun use `curl --fail --location --progress-bar --output`.
- **TLS hardening (rustup):** enforces protocol and cipher suites: `curl --proto '=https' --tlsv1.2 --silent --show-error --fail --location`, with a wget fallback (`wget --https-only --secure-protocol=TLSv1_2`) and graceful degradation when BusyBox wget can't do strong ciphers. rustup's documented one-liner is `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh` (the rustup book also documents an arg-passing form, e.g. `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --profile minimal --default-toolchain nightly`).
- **Checksums:** Deno publishes a `SHA256SUM` and documents verifying the installer with `shasum -a 256 -c --ignore-missing`. Deno's own `deno upgrade` re-verifies release assets; each release ships a matching `.sha256sum`.
- **PowerShell (Bun):** primary download via `curl.exe "-#SfLo"`, with an `Invoke-RestMethod` fallback, then it verifies the extracted `bun.exe` exists and runs `bun.exe --revision`, decoding exit codes (`STATUS_DLL_NOT_FOUND` → prompts to install VC++ redistributable). Notably Bun's PS1 does **not** set `SecurityProtocol`/TLS 1.2 (it relies on curl.exe). Scoop, by contrast, explicitly enables TLS in `Optimize-SecurityProtocol` (`[System.Net.ServicePointManager]::SecurityProtocol = 3072 -bor 768 -bor 192`, i.e. TLS 1.2/1.1/1.0) unless .NET 4.7+ SystemDefault is already active.

### 5. Privilege escalation
**Shell (Docker — the reference):** compute an `sh_c` prefix once and reuse it, degrading gracefully:
```sh
sh_c='sh -c'
if [ "$user" != 'root' ]; then
    if command_exists sudo; then sh_c='sudo -E sh -c'
    elif command_exists su; then sh_c='su -c'
    else echo "Error: this installer needs the ability to run commands as root."; exit 1
    fi
fi
if is_dry_run; then sh_c="echo"; fi
```
Ollama uses the simpler `SUDO=` variable and, importantly, only uses sudo for privileged steps (installing to `/usr/local`, systemd) rather than requiring the whole script to run as root. Homebrew *refuses* to run as root (`check_run_command_as_root`) except inside CI/Docker containers (detected via `/proc/1/cgroup`).

**PowerShell (Scoop — the reference):** *refuses* to run elevated by default, since Scoop is a per-user tool:
```powershell
if (!$RunAsAdmin -and (Test-IsAdministrator)) {
    $exception = ($env:USERNAME -eq 'WDAGUtilityAccount') -or ($env:GITHUB_ACTIONS -eq 'true' -and $env:CI -eq 'true')
    if (!$exception) {
        Deny-Install 'Running the installer as administrator is disabled by default...'
    }
}
```
(The two exceptions are Windows Sandbox — `WDAGUtilityAccount` — and GitHub Actions CI.) Desktop apps that must write to `Program Files` should instead check for elevation and relaunch with `Start-Process -Verb RunAs`.

### 6. PATH modification & shell-profile detection
**Shell (nvm — the reference for profile detection):** honor `$SHELL`, check for `.bashrc`/`.zshrc`/`.zprofile`, respect `$ZDOTDIR`, and fall back through a candidate list:
```sh
if [ "${SHELL#*zsh}" != "$SHELL" ]; then
    if [ -f "${ZDOTDIR:-${HOME}}/.zshrc" ]; then DETECTED_PROFILE="${ZDOTDIR:-${HOME}}/.zshrc"
    ...
fi
# fall back through candidates if none detected:
for EACH_PROFILE in ".profile" ".bashrc" ".bash_profile" ".zprofile" ".zshrc"; do ... done
```
Bun writes idempotently per-shell (bash/zsh/fish), appends `export BUN_INSTALL=...` and `export PATH="$BUN_INSTALL/bin:$PATH"`, and if it can't write the profile, prints the exact commands for the user to add manually. Deno appends a `. "$HOME/.deno/env"` line.

**PowerShell (Bun & Scoop — the reference for registry PATH):** never use `[Environment]::SetEnvironmentVariable` naively because it expands `%VAR%` tokens (corrupting other users' PATH entries). Instead read/write the registry with `DoNotExpandEnvironmentNames`:
```powershell
function Get-Env {
  param([String] $Key)
  $RegisterKey = Get-Item -Path 'HKCU:'
  $EnvRegisterKey = $RegisterKey.OpenSubKey('Environment')
  $EnvRegisterKey.GetValue($Key, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
}
```
`Write-Env` chooses `ExpandString` vs `String` based on whether the value contains `%`, then a `Publish-Env` helper P/Invokes `SendMessageTimeout` with `WM_SETTINGCHANGE`/`HWND_BROADCAST` so open apps pick up the change without a reboot. (Both scripts credit prefix-dev/pixi for these helpers.) Scoop's `Add-ShimsDirToPath` prepends `$SCOOP_SHIMS_DIR` and only does so if PATH doesn't already contain it (idempotency):
```powershell
if ($userEnvPath -notmatch [Regex]::Escape($SCOOP_SHIMS_DIR)) {
    Write-Env 'PATH' "$SCOOP_SHIMS_DIR;$userEnvPath"   # future sessions
    $env:PATH = "$SCOOP_SHIMS_DIR;$env:PATH"           # current session
}
```

### 7. Idempotency, upgrades, and handling existing installs
- Ollama removes an old macOS app before reinstalling (`rm -rf "/Applications/Ollama.app"`), cleans an old Linux lib dir, and checks whether the `/usr/local/bin/ollama` symlink already points to the right target before recreating it.
- oh-my-zsh detects an existing `$ZSH` directory and aborts with three explicit remediation options; it backs up an existing `.zshrc` to `.zshrc.pre-oh-my-zsh` before writing its template.
- Scoop refuses if `scoop` is already on PATH: `Deny-Install "Scoop is already installed. Run 'scoop update'..." -ErrorCode 0` (exit 0, not an error).
- Bun (Windows) registers an uninstall entry so it appears in "Add or Remove Programs" (see §9).
- **Counter-example / caveat:** Docker's script is explicit in its header that it *"Isn't designed to upgrade an existing Docker installation"* and warns at runtime that re-running *resets any custom changes in the deb and rpm repo configuration files to match the parameters passed to the script* — a reminder that not every famous installer is safe to re-run.

### 8. Non-interactive / CI modes, flags, and version pinning
- **oh-my-zsh** auto-detects non-interactive use (`if [ ! -t 0 ]`) and disables `chsh`/running zsh; it also parses `--unattended`, `--skip-chsh`, `--keep-zshrc` and honors env vars `CHSH`, `RUNZSH`, `KEEP_ZSHRC`.
- **Homebrew** honors `NONINTERACTIVE=1` for automation.
- **Starship** parses full flags: `-y/--force` (skip confirmation), `-b/--bin-dir`, `-a/--arch`, `-v/--version`, `-B/--base-url`, `--verbose`, `--help`.
- **Version pinning:** Deno — `curl -fsSL https://deno.land/install.sh | sh -s v1.0.0` (shell) and `$v="1.0.0"; irm https://deno.land/install.ps1 | iex` (PowerShell). Tailscale — `curl -fsSL https://tailscale.com/install.sh | TAILSCALE_VERSION=1.88.4 sh`. Docker — `--version` and `--channel stable|test`. rustup — `--default-toolchain`, `--profile minimal|default|complete`, `--channel`. Bun — `curl ... | bash -s "bun-v1.x.x"`.
- **Install-dir override via env var:** Deno `DENO_INSTALL`, Bun `BUN_INSTALL`, rustup `CARGO_HOME`/`RUSTUP_HOME`, Ollama `OLLAMA_INSTALL_DIR`.

### 9. Desktop-application-specific concerns (the primary interest)

**macOS — app bundles (Ollama is the best public reference):**
```sh
if [ "$OS" = "Darwin" ]; then
    if pgrep -x Ollama >/dev/null 2>&1; then pkill -x Ollama; sleep 2; fi   # stop running app
    if [ -d "/Applications/Ollama.app" ]; then rm -rf "/Applications/Ollama.app"; fi  # remove old
    curl --fail --show-error --location --progress-bar -o "$TEMP_DIR/Ollama-darwin.zip" "$DOWNLOAD_URL"
    unzip -q "$TEMP_DIR/Ollama-darwin.zip" -d "$TEMP_DIR"
    mv "$TEMP_DIR/Ollama.app" "/Applications/"
    # symlink the CLI helper inside the bundle into the PATH:
    ln -sf "/Applications/Ollama.app/Contents/Resources/ollama" "/usr/local/bin/ollama" \
        2>/dev/null || sudo ln -sf ...
    open -a Ollama --args hidden   # launch the GUI app
fi
```
Key desktop lessons: stop any running instance first (`pgrep`/`pkill`), install into `/Applications`, expose the CLI portion via a `/usr/local/bin` symlink (attempt without sudo, fall back to sudo), and launch the app at the end. Homebrew Cask distributes GUI apps by downloading a `.dmg`/`.pkg` and verifying a `sha256`.

**Linux — `.desktop` entries:** the XDG-standard way to make a downloaded/extracted app appear in application menus:
```sh
cat > ~/.local/share/applications/myapp.desktop <<EOF
[Desktop Entry]
Name=MyApp
Exec=/opt/myapp/myapp %U
Icon=/opt/myapp/icon.png
Type=Application
Categories=Utility;Development;
Terminal=false
EOF
update-desktop-database ~/.local/share/applications
```
Use `~/.local/share/applications` for per-user, `/usr/share/applications` for system-wide; `desktop-file-validate` to validate and `desktop-file-install` as a higher-level installer. Run `update-desktop-database` after writing so menus/MIME associations refresh.

**Linux — daemons:** Ollama writes a systemd unit to `/etc/systemd/system/ollama.service`, creates a dedicated service user (`useradd -r -s /bin/false -U -m -d /usr/share/ollama ollama`), then `systemctl daemon-reload && systemctl enable ollama` — but only after checking `systemctl is-system-running` so it degrades gracefully on non-systemd/WSL systems.

**Windows — Start Menu / desktop shortcuts** via the `WScript.Shell` COM object (works from PowerShell installers):
```powershell
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\MyApp.lnk")
$Shortcut.TargetPath = "$InstallDir\MyApp.exe"
$Shortcut.IconLocation = "$InstallDir\MyApp.exe"
$Shortcut.WorkingDirectory = $InstallDir
$Shortcut.Save()
```
Use `$WshShell.SpecialFolders("Desktop")` or `"AllUsersPrograms"` for the target folder.

**Windows — register an uninstaller (Bun is the reference):** write to `HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\<App>` so the app shows up in "Add or Remove Programs":
```powershell
$RegistryKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Bun"
New-Item -Path $RegistryKey -Force
New-ItemProperty -Path $RegistryKey -Name "DisplayName"      -Value "Bun"          -PropertyType String -Force
New-ItemProperty -Path $RegistryKey -Name "InstallLocation"  -Value "${BunRoot}"   -PropertyType String -Force
New-ItemProperty -Path $RegistryKey -Name "DisplayIcon"      -Value $BunBin\bun.exe -PropertyType String -Force
New-ItemProperty -Path $RegistryKey -Name "UninstallString"  -Value "powershell -c ... uninstall.ps1 ..." -PropertyType String -Force
```
For a per-machine install use `HKLM:` (requires elevation); for per-user use `HKCU:`. Scoop, for GUI apps it installs, creates shortcuts in a dedicated "Scoop Apps" Start Menu folder and shims for CLI tools in `~\scoop\shims` (on PATH).

### 10. Colored logging & progress output
oh-my-zsh's `setup_color` is the widely-copied pattern — only emit ANSI codes when attached to a TTY:
```sh
setup_color() {
    if [ -t 1 ]; then
        RED=$(printf '\033[31m'); GREEN=$(printf '\033[32m')
        YELLOW=$(printf '\033[33m'); BOLD=$(printf '\033[1m'); RESET=$(printf '\033[m')
    else
        RED=""; GREEN=""; YELLOW=""; BOLD=""; RESET=""
    fi
}
```
Bun guards colors with `if [[ -t 1 ]]` and defines `error()/info()/success()` helpers; Ollama uses `tput` (`tput setaf 1`) with fallbacks. For download progress, `curl --progress-bar` (Ollama, Bun) shows a clean bar rather than the noisy default meter.

### 11. `curl | sh` interactivity trick (rustup)
When piped, stdin is consumed by the shell, so an installer can't prompt. rustup reconnects the terminal by reading from `/dev/tty` for its subsequent interactive binary — worth knowing if your desktop installer needs to ask questions.

## Recommendations

**Stage 1 — Start from the right skeleton.** For a shell installer copy the structure of **Ollama's `install.sh`** (it's the best hybrid: handles macOS `.app` bundles, Linux binaries, systemd, PATH, and cleanup traps in ~455 lines). For PowerShell, start from **Bun's `install.ps1`** (registry PATH, uninstaller registration, arch detection) or **Scoop's** (prerequisite gating). Adopt these non-negotiables immediately:
1. Wrap the whole shell script in `main() { ... }` and call `main "$@"` on the last line.
2. `set -eu` (or `set -euo pipefail` if you require bash) in shell; `$ErrorActionPreference = "Stop"` in PowerShell.
3. `mktemp -d` + `trap cleanup EXIT` for temp files.
4. Guard colored output behind `[ -t 1 ]`.

**Stage 2 — Make it robust and portable.**
1. Detect OS/arch with a `case "$(uname -m)"` block; add musl detection (`ldd | grep musl`) and Rosetta detection if you ship macOS binaries.
2. Check dependencies up front and report *all* missing tools at once (Ollama's `require`).
3. Download with `curl -fsSL` / `curl --fail --location --progress-bar`; enforce `--proto '=https' --tlsv1.2` like rustup. In PowerShell either set `[System.Net.ServicePointManager]::SecurityProtocol` to include TLS 1.2 (Scoop) or delegate to `curl.exe` (Bun).
4. **Verify downloads with a published SHA-256 checksum** (Deno's model) — this is the biggest gap in most homegrown installers. Ship a `SHA256SUM` file and `shasum -a 256 -c`.

**Stage 3 — Desktop polish (your priority).**
1. macOS: install to `/Applications`, stop running instances first, symlink any CLI helper into `/usr/local/bin` (try without sudo, fall back to sudo), `open -a` at the end.
2. Linux: write a validated `.desktop` file and run `update-desktop-database`; if it's a daemon, add a systemd unit guarded by a `systemctl is-system-running` check.
3. Windows: create Start Menu/desktop `.lnk` shortcuts via `WScript.Shell`; register an uninstall entry under `...\CurrentVersion\Uninstall\`; modify PATH via the registry with `DoNotExpandEnvironmentNames` and broadcast `WM_SETTINGCHANGE`.

**Stage 4 — Ergonomics & lifecycle.**
1. Support non-interactive/CI mode (detect `! -t 0`, honor an `--unattended`/`CI` flag) and version pinning via an env var and/or positional arg.
2. Make re-runs idempotent (detect existing install → upgrade in place; back up user config before overwriting).
3. Ship an uninstall path (Homebrew/Deno/Bun all do) and document a `--dry-run` (Docker) if your script touches system state.

**Thresholds that change the recommendation:** If your app is a pure single-binary CLI tool, you can skip the desktop-integration stages and model Deno/Starship directly. If you must write to `Program Files` or `/usr/local` system-wide, add explicit elevation (relaunch with `RunAs` / require sudo only for the privileged steps). If you distribute through OS package repos, follow Tailscale's model (detect distro, add the official repo, hand off to apt/dnf) instead of dropping binaries — it gives users automatic updates.

## Caveats
- **Scripts change.** All excerpts reflect the repositories as fetched on July 7, 2026 (mostly `main`/`master` `HEAD`). Pin to a tag or commit if you need stability; e.g., Bun's PS1 currently does *not* set a TLS SecurityProtocol block (it uses `curl.exe`), which differs from older documentation and from Scoop's approach.
- **`curl | sh` is inherently a trust decision.** Even well-written installers ask users to pipe remote code into a shell. The `main()` wrapper mitigates *partial-download* execution, not a *compromised host*. Encourage users to download-and-inspect, or publish a checksum (Deno) or a verification service pattern.
- **Idempotency is not universal.** Docker's own script warns it *"isn't designed to upgrade an existing installation"* and resets repo config on re-run — don't assume every famous script is safe to re-run; design yours to be.
- **Desktop integration is environment-specific.** `.desktop` handling varies across GNOME/KDE/XFCE; `WScript.Shell` shortcuts to Microsoft Store/sideloaded apps need the app's special AUMID rather than a plain exe path; and macOS Gatekeeper may quarantine unsigned `.app` bundles downloaded via curl (code-signing/notarization is out of scope of the install script itself).
- **Community mirrors vs official sources.** Several search hits were third-party forks/gists; the URLs listed under Key Findings point to the official upstream repositories, which are the ones to follow.