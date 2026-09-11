# ─────────────────────────────────────────────
#  Build the Windows release and wrap it in an
#  Inno Setup installer.
#
#  Usage:  .\installer\build_installer.ps1
#          .\installer\build_installer.ps1 -SkipBuild
#
#  Output: dist\TabalahAdmin-Setup-<version>.exe
# ─────────────────────────────────────────────
param(
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# The version comes from pubspec so there is one place to bump it. The
# installer filename, the exe metadata and the value the updater compares
# against all derive from this line.
$line = Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(.+)$' | Select-Object -First 1
if (-not $line) { throw 'No version: line in pubspec.yaml' }
$version = ($line.Matches[0].Groups[1].Value -split '\+')[0].Trim()
Write-Host "Version: $version"

if (-not $SkipBuild) {
    Write-Host 'Building Windows release...'
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw 'flutter build failed' }
}

$release = Join-Path $root 'build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $release 'TabalahAdmin.exe'))) {
    throw "No build output at $release - run without -SkipBuild"
}

$iscc = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $iscc) {
    throw 'Inno Setup 6 not found. Install it: winget install JRSoftware.InnoSetup'
}

New-Item -ItemType Directory -Force -Path (Join-Path $root 'dist') | Out-Null

& $iscc "/DAppVersion=$version" (Join-Path $PSScriptRoot 'tabalah_admin.iss')
if ($LASTEXITCODE -ne 0) { throw 'ISCC failed' }

$out = Join-Path $root "dist\TabalahAdmin-Setup-$version.exe"
$mb = [math]::Round((Get-Item $out).Length / 1MB, 1)
Write-Host ""
Write-Host "Installer: $out  ($mb MB)"
