<#
    3D Slicer one-line installer for Windows.

    Usage (PowerShell):
        irm https://raw.githubusercontent.com/<you>/slicer-installer/main/install.ps1 | iex

    What it does:
        * Downloads the latest STABLE Slicer installer from the official server.
        * Verifies it against the publisher's SHA-512 checksum.
        * Runs it silently, per-user (no Administrator rights required).
        * All of Slicer's dependencies (Qt, Python, VTK, ...) are bundled in the
          installer, so nothing else needs to be installed on Windows.

    Environment overrides:
        SLICER_STABILITY     release (default) | nightly | any
        SLICER_VERSION       pin an exact version, e.g. 5.12.0 (default: latest)
        SLICER_INSTALL_DIR   install directory (default: the installer's default,
                             %LOCALAPPDATA%\NA-MIC). Use an ASCII-only path.

    Docs: https://slicer.readthedocs.io/en/latest/user_guide/getting_started.html
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# Invoke-WebRequest's progress bar makes large downloads crawl in Windows
# PowerShell; disabling it speeds the ~250 MB download up dramatically.
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Note($msg) { Write-Host "    $msg" -ForegroundColor DarkGray }

if (-not [Environment]::Is64BitOperatingSystem) {
    Write-Error "3D Slicer requires 64-bit Windows."
    exit 1
}
if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') {
    Write-Note "ARM64 Windows detected: Slicer ships an x64 build that runs under emulation."
}

$stability   = if ($env:SLICER_STABILITY) { $env:SLICER_STABILITY } else { 'release' }
$packagesApi = 'https://slicer-packages.kitware.com/api/v1'
$downloadUrl = "https://download.slicer.org/download?os=win&stability=$stability"
if ($env:SLICER_VERSION) { $downloadUrl += "&version=$($env:SLICER_VERSION)" }

# Note if Slicer is already installed; the NSIS installer upgrades in place.
$existing = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
                             'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' `
            -ErrorAction SilentlyContinue |
            Where-Object { $_.PSObject.Properties['DisplayName'] -and $_.DisplayName -like '*Slicer*' } |
            Select-Object -First 1
if ($existing) {
    Write-Note "Existing installation found ($($existing.DisplayName)); it will be upgraded."
}

# Resolve the Girder item id behind the download endpoint so we can fetch the
# publisher's checksum. Best-effort: on any failure we fall back to an
# unverified download rather than blocking the install.
function Resolve-SlicerItemId {
    param([string]$Url)
    $loc = $null
    try {
        $resp = Invoke-WebRequest -Uri $Url -MaximumRedirection 0 -UseBasicParsing -ErrorAction Stop
        if ($resp.Headers.ContainsKey('Location')) { $loc = $resp.Headers['Location'] }
    } catch {
        $r = $_.Exception.Response
        if ($r) {
            try { $loc = [string]$r.Headers.Location } catch {}
            if (-not $loc) { try { $loc = $r.Headers['Location'] } catch {} }
        }
    }
    $loc = [string]$loc
    if ($loc -match '/bitstream/([0-9a-fA-F]+)') { return $Matches[1] }
    return $null
}

function Get-SlicerSha512 {
    param([string]$ItemId)
    try {
        $meta = Invoke-RestMethod -Uri "$packagesApi/item/$ItemId" -UseBasicParsing
        return [string]$meta.meta.sha512
    } catch { return $null }
}

$installer = Join-Path $env:TEMP ("Slicer-" + [guid]::NewGuid().ToString('N') + ".exe")

try {
    $itemId   = Resolve-SlicerItemId -Url $downloadUrl
    $expected = if ($itemId) { Get-SlicerSha512 -ItemId $itemId } else { $null }
    $source   = if ($itemId) { "$packagesApi/item/$itemId/download" } else { $downloadUrl }

    Write-Step "Downloading 3D Slicer for Windows..."
    Invoke-WebRequest -Uri $source -OutFile $installer -UseBasicParsing

    if ($expected) {
        $actual = (Get-FileHash -Path $installer -Algorithm SHA512).Hash.ToLower()
        if ($actual -ne $expected.ToLower()) {
            throw "Checksum verification failed (expected $expected, got $actual)."
        }
        Write-Step "Checksum verified (SHA-512)."
    } else {
        Write-Warning "Could not obtain a checksum from the server; skipping verification."
    }

    # The Slicer installer is NSIS-based:
    #   /S           silent install
    #   /D=<path>    install directory (must be the LAST argument, unquoted)
    $arguments = @('/S')
    if ($env:SLICER_INSTALL_DIR) {
        if ($env:SLICER_INSTALL_DIR -match '[^\x20-\x7E]') {
            throw "SLICER_INSTALL_DIR must contain only ASCII characters: $($env:SLICER_INSTALL_DIR)"
        }
        $arguments += "/D=$($env:SLICER_INSTALL_DIR)"
    }

    Write-Step "Running the installer silently..."
    $proc = Start-Process -FilePath $installer -ArgumentList $arguments -Wait -PassThru
    if ($proc.ExitCode -ne 0) {
        throw "Installer exited with code $($proc.ExitCode)."
    }

    # Locate the installed launcher so we can tell the user where it went.
    $searchRoots = @()
    if ($env:SLICER_INSTALL_DIR) { $searchRoots += $env:SLICER_INSTALL_DIR }
    $searchRoots += (Join-Path $env:LOCALAPPDATA 'NA-MIC')
    $searchRoots += (Join-Path ${env:ProgramFiles} 'NA-MIC')

    $exe = $null
    foreach ($root in $searchRoots) {
        if ($root -and (Test-Path $root)) {
            $exe = Get-ChildItem -Path $root -Recurse -Filter 'Slicer.exe' -ErrorAction SilentlyContinue |
                   Select-Object -First 1
            if ($exe) { break }
        }
    }

    if ($exe) {
        Write-Step "Installed to: $($exe.FullName)"
    } else {
        Write-Step "Installation finished. Launch 3D Slicer from the Start menu."
    }
    Write-Host "3D Slicer installation complete." -ForegroundColor Green
}
finally {
    if (Test-Path $installer) { Remove-Item $installer -Force -ErrorAction SilentlyContinue }
}
