#Requires -Version 5.1
<#
.SYNOPSIS
  Downloads ClothesDryer's runtime dependencies into this folder.

.DESCRIPTION
  When the entitlement gate is enabled the mod reads SCUM.db (SQLite), but these
  binaries are deliberately NOT committed to git. Run this once after cloning or
  deploying the mod; it fetches each dependency from its official source and
  verifies it against a pinned SHA-256 before installing.

  Currently: sqlite3.exe - the official public-domain command-line shell from
  sqlite.org (https://sqlite.org/copyright.html). Public domain = free to
  download, use, and redistribute; this script just automates fetching it.

  (You only need this if you set entitlementsEnabled = true in Config.lua. With
  entitlements off the dryer works in any flag and no DB / sqlite3.exe is used.)

.PARAMETER Force
  Re-download even if the file is already present.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\install-libraries.ps1
  (or just double-click install-libraries.cmd)
#>
[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

# Windows PowerShell 5.1 often defaults to TLS 1.0/1.1, which sqlite.org rejects.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Here = $PSScriptRoot

# Each dependency: where to get it, the SHA-256 to verify the download against,
# which file to pull out of the archive, and where to put it.
$Dependencies = @(
    [pscustomobject]@{
        Name      = 'sqlite3'
        Version   = '3.50.4'
        Url       = 'https://sqlite.org/2025/sqlite-tools-win-x64-3500400.zip'
        Sha256    = '8ce18347ea86a1ce65f33b533d2f144d8d1237140529fbf818574ca11fa13ad5'
        ZipMember = 'sqlite3.exe'
        Dest      = 'sqlite3.exe'
        License   = 'Public Domain (sqlite.org)'
        VerifyArg = '-version'
    }
)

function Install-Dependency {
    param([Parameter(Mandatory = $true)]$Dep)

    $destPath = Join-Path $Here $Dep.Dest
    Write-Host ''
    Write-Host ("== {0} {1}  [{2}] ==" -f $Dep.Name, $Dep.Version, $Dep.License)

    if ((Test-Path $destPath) -and -not $Force) {
        Write-Host ("  already present: {0}  (use -Force to re-download)" -f $Dep.Dest)
        return
    }

    $tmpDir = Join-Path $env:TEMP ('cd_dl_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    try {
        $zip = Join-Path $tmpDir 'pkg.zip'
        Write-Host ("  downloading {0}" -f $Dep.Url)
        Invoke-WebRequest -Uri $Dep.Url -OutFile $zip -UseBasicParsing

        Write-Host '  verifying SHA-256 ...'
        $actual = (Get-FileHash -Path $zip -Algorithm SHA256).Hash
        if ($actual -ine $Dep.Sha256) {
            throw ("SHA-256 mismatch for {0}`n    expected {1}`n    got      {2}" -f $Dep.Name, $Dep.Sha256, $actual)
        }
        Write-Host '  hash OK'

        $extract = Join-Path $tmpDir 'x'
        Expand-Archive -Path $zip -DestinationPath $extract -Force
        $member = Join-Path $extract $Dep.ZipMember
        if (-not (Test-Path $member)) {
            throw ("'{0}' not found inside the archive" -f $Dep.ZipMember)
        }
        Copy-Item -Path $member -Destination $destPath -Force
        Write-Host ("  installed -> {0}" -f $destPath)

        if ($Dep.VerifyArg) {
            $ver = & $destPath $Dep.VerifyArg | Select-Object -First 1
            Write-Host ("  verify: {0}" -f $ver)
        }
    }
    finally {
        try { Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction Stop } catch { }
    }
}

Write-Host 'ClothesDryer - installing runtime libraries into:'
Write-Host ("  {0}" -f $Here)

$failed = 0
foreach ($d in $Dependencies) {
    try { Install-Dependency -Dep $d }
    catch { Write-Warning ("{0} FAILED: {1}" -f $d.Name, $_.Exception.Message); $failed++ }
}

Write-Host ''
if ($failed -gt 0) {
    Write-Warning ("{0} dependency/dependencies failed - see messages above." -f $failed)
    exit 1
}
Write-Host 'All dependencies installed.'
