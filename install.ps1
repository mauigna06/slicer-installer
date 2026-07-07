<#
    3D Slicer one-line installer for Windows.

    Usage (PowerShell):
        irm https://raw.githubusercontent.com/<you>/slicer-installer/main/install.ps1 | iex

    What it does:
        * Downloads the latest STABLE Slicer installer from the official server.
        * Runs it silently, per-user (no Administrator rights required).
        * All of Slicer's dependencies (Qt, Python, VTK, ...) are bundled in the
          installer, so nothing else needs to be installed on Windows.

    Environment overrides:
        SLICER_STABILITY     release (default) | nightly | any
        SLICER_INSTALL_DIR   install directory (default: the installer's default,
                             %LOCALAPPDATA%\NA-MIC). Use an ASCII-only path.

    Docs: https://slicer.readthedocs.io/en/latest/user_guide/getting_started.html
#>

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }

$stability = if ($env:SLICER_STABILITY) { $env:SLICER_STABILITY } else { 'release' }
$url = "https://download.slicer.org/download?os=win&stability=$stability"

$installer = Join-Path $env:TEMP ("Slicer-" + [guid]::NewGuid().ToString('N') + ".exe")

try {
    Write-Step "Downloading 3D Slicer for Windows..."
    Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing

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
