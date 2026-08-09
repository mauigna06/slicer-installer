# Splitting the installers into outer and inner scripts

*2026-08-09*

## Why

`install.sh` and `install.ps1` each did three unrelated jobs in one file:
install Slicer, install Slicer's Linux runtime libraries, and install/select an
interface language. The last two were the awkward ones — the language feature
carried ~150 lines of Python embedded twice, once per platform, and launched
Slicer headlessly; the dependency feature was the only thing in the project that
ever wanted root.

They are now separated by *where they run*, not just by function:

- **Outer** — the `curl | sh` / `irm | iex` one-liner. Download, verify, install
  Slicer, wire up the launcher and desktop entry, handle an existing
  installation. Nothing else.
- **Inner** — standalone scripts that live *inside the installed Slicer
  directory*, in Slicer's own `bin/`, run by the user afterwards.

The inner scripts are destined for the Slicer package itself, via
[Slicer#9294](https://github.com/Slicer/Slicer/pull/9294).

## What moved

| From | To |
| ---- | -- |
| `install.sh`: `list_languages()`, `configure_language()`, both Python programs, the Weblate query | [`inner/slicer-language`](inner/slicer-language) |
| `install.sh`: `run_deps_cmd()`, `handle_linux_deps()`, the `DEPS_*` lists | [`inner/slicer-deps`](inner/slicer-deps) |
| `install.ps1`: the `list` branch and the whole `SLICER_LANGUAGE` block | [`inner/slicer-language.ps1`](inner/slicer-language.ps1) |

Removed from both outer installers: the `SLICER_LANGUAGE` and
`SLICER_INSTALL_DEPS` environment variables, their documentation, and the
`INSTALLED_EXE` plumbing that existed only to hand the launcher to the language
step.

### Interfaces

The inner scripts are run by a person, so they take arguments rather than
environment variables:

```sh
slicer-deps                    # print the package-manager command
slicer-deps --install --yes    # run it; --yes = never wait for a sudo password
slicer-language list           # what languages exist, and how complete each is
slicer-language es-419         # install one and switch Slicer to it
```

```powershell
slicer-language.ps1 list
slicer-language.ps1 es-419
```

Each one **self-locates**: it resolves its own directory and derives the Slicer
launcher from it (`<appdir>/bin/…` → `<appdir>/Slicer` on Linux,
`Slicer.app/Contents/bin/…` → `Contents/MacOS/Slicer` on macOS,
`<installdir>\bin\…` → `<installdir>\Slicer.exe` on Windows). A `--slicer` /
`-SlicerExe` override covers the unusual case.

## How they get onto disk

They ship inside the Slicer package. No package shipping today contains them,
so until [Slicer#9294](https://github.com/Slicer/Slicer/pull/9294) lands and
users install a Slicer built after it, the outer installer writes its own
embedded copies — **but only when the package does not already have them**, so
an upstream copy always wins. Once every supported package ships them, the shim
(`install_inner_tools` / `Install-InnerTools` and the generated blocks) is
deleted in one commit.

## Embedding

[`tools/sync-embedded.sh`](tools/sync-embedded.sh) replaces `tools/sync-deps.sh`,
keeping its shape (marker pair, awk splice, `cmp -s`, `--check` with a `diff -u`)
but running two stages, in order:

```
deps/*.txt  ->  inner/slicer-deps  ->  install.sh
inner/slicer-language              ->  install.sh
inner/slicer-language.ps1          ->  install.ps1
```

`install.sh` carries each inner script in a quoted heredoc whose delimiter we
choose. `install.ps1` cannot do the same: a PowerShell single-quoted here-string
always ends at a line starting with `'@`, and `inner/slicer-language.ps1`
contains exactly that (it embeds Python the same way). So it is emitted as one
single-quoted string per line joined with newlines — the idiom the ASCII logo
already uses in that file — which needs only `'` doubled and has no delimiter to
collide with.

The generator refuses to run if an inner script contains a line equal to the
heredoc delimiter or to one of the markers, rather than silently producing a
truncated installer.

## CI

`.github/workflows/deps-sync.yml` → `.github/workflows/embedded-sync.yml`, and it
now does three things instead of one:

- `tools/sync-embedded.sh --check` — the drift gate, extended to every generated
  block rather than just the dependency lists
- `sh -n` and `shellcheck -s sh` on `install.sh`, both inner sh scripts and the
  generator — the repo previously had no syntax check at all, and this change
  moves a lot of code between files
- a PowerShell parse check of `install.ps1` and `inner/slicer-language.ps1`

Two shellcheck suppressions were added to make that pass: `SC2088` in
`install.sh` (pre-existing; a quoted `~` used as a `case` *pattern*, not an
expansion) and `SC2016` in the generator (a PowerShell variable being written
out verbatim).

## Behavior changes to know about

- **The one-liner no longer accepts `SLICER_LANGUAGE` or
  `SLICER_INSTALL_DEPS`.** Both are separate commands run after installing.
  The README's Docker recipe changed accordingly.
- **Docker builds fail one layer later.** A missing package manager or an
  unusable `sudo` is now reported *after* Slicer has been downloaded and
  installed, because `slicer-deps` runs as its own command rather than inside
  the install. The build still fails.
- **`slicer-language list` needs Slicer installed**, where
  `SLICER_LANGUAGE=list` did not. It only queries the translation server, but it
  now ships inside the installation.
- **The Slicer series is read from the running application**
  (`slicer.app.majorVersion` / `minorVersion`, falling back to
  `applicationVersion`) instead of being parsed out of the package version by
  the shell. This is the one deliberate change to the Python: the inner scripts
  have no access to the installer's `PKG_VERSION`, and asking the application is
  more reliable than guessing from a path.
- `install.sh` grew from 1328 to ~1608 lines. The ~330 lines removed come back
  as ~370 embedded ones plus the write-out machinery. The gain is runtime
  separation and one canonical source per feature; the file shrinks for real
  only when the shim is dropped.

## Verification performed

- Generator is idempotent; `--check` detects drift in both stages; both refusal
  guards fire.
- All three inner scripts extract byte-identically out of the outer scripts
  (sh heredocs executed in isolation; the PowerShell array decoded
  independently).
- `sh -n` and `shellcheck -s sh` clean on every shell script.
- The generated Python compiles, with the `\d` regex and the language
  interpolation intact through the unquoted heredoc.
- Real end-to-end install of Slicer 5.12.3 into an isolated `HOME`: both helpers
  land in `<appdir>/bin`, byte-identical to `inner/`, and `slicer-language
  fr-FR` genuinely launches the installed Slicer.
- `install_inner_tools` verified for all three cases: upstream copy preserved,
  missing copy filled in, second run silent.
- Self-location verified against simulated Linux and macOS layouts, and against
  the real 5.12.3 package (`bin/` sits beside the `Slicer` launcher as assumed).

Not covered: `download.slicer.org` was returning 502 throughout, so the download
path was exercised with the resolver and downloader stubbed to a cached 5.12.3
tarball. Windows was not run — no PowerShell available in this environment; the
`install.ps1` changes are verified by parse and round-trip only.

## Still open

`Utilities/Scripts/SlicerInstallers/CMakeLists.txt` in
[Slicer#9294](https://github.com/Slicer/Slicer/pull/9294) is still
`# TO BE POPULATED`. It needs an `install()` rule placing the inner scripts into
`${Slicer_INSTALL_BIN_DIR}` with executable permissions — one rule covers all
three platforms, which is what keeps that PR small. The outer installers stay
source-only there: they are served from `raw.githubusercontent.com` and are
never installed into the package.
