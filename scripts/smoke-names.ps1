# Smoke: dist/LspLoad.zip PE names equal current hosts.json ship:true.
[CmdletBinding()]
param(
    [string] $ZipPath,
    [string] $HostsPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$RepoRoot = Split-Path $PSScriptRoot -Parent
if (-not $ZipPath) { $ZipPath = Join-Path $RepoRoot 'dist\LspLoad.zip' }
if (-not $HostsPath) { $HostsPath = Join-Path $RepoRoot 'hosts\hosts.json' }

function Test-ForbiddenDrive([string] $path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return }
    if ($path -match '^[XxBb]:') {
        throw "Refusing path on X: or B:: $path"
    }
}

function Get-ShipPeNames([string] $jsonPath) {
    $doc = (Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8) | ConvertFrom-Json
    if ($null -eq $doc.targets) {
        throw "hosts.json missing targets: $jsonPath"
    }
    $names = [System.Collections.Generic.List[string]]::new()
    foreach ($row in @($doc.targets)) {
        if (-not [bool]$row.ship) { continue }
        $names.Add("$($row.outputName)$($row.ext)")
    }
    return @($names | Sort-Object -Unique)
}

function Get-ZipPeNames([string] $zipPath) {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $names = [System.Collections.Generic.List[string]]::new()
        foreach ($entry in $zip.Entries) {
            $n = $entry.FullName -replace '\\', '/'
            if ($n.EndsWith('/')) { continue }
            $leaf = [System.IO.Path]::GetFileName($n)
            if ($leaf -notmatch '\.(arx|brx|zrx|grx)$') { continue }
            if ($n -ne $leaf) {
                throw "LspLoad.zip PE must be flat (no folder prefix): $n"
            }
            $names.Add($leaf)
        }
        return @($names | Sort-Object -Unique)
    }
    finally { $zip.Dispose() }
}

Test-ForbiddenDrive $RepoRoot
Test-ForbiddenDrive $ZipPath
Test-ForbiddenDrive $HostsPath

foreach ($p in @($ZipPath, $HostsPath)) {
    if (-not (Test-Path -LiteralPath $p)) {
        throw "Missing $p (run package-zips.ps1 first for dist/LspLoad.zip)"
    }
}

$errors = [System.Collections.Generic.List[string]]::new()
$ship = @(Get-ShipPeNames $HostsPath)
$zipPe = @(Get-ZipPeNames $ZipPath)

if ($ship.Count -eq 0) { [void]$errors.Add("hosts.json has no ship:true targets: $HostsPath") }
if ($zipPe.Count -eq 0) { [void]$errors.Add("no PE entries in $ZipPath") }

$onlyZip = Compare-Object $ship $zipPe | Where-Object { $_.SideIndicator -eq '=>' }
$onlyShip = Compare-Object $ship $zipPe | Where-Object { $_.SideIndicator -eq '<=' }
foreach ($x in @($onlyZip)) { [void]$errors.Add("zip has PE not in ship:true: $($x.InputObject)") }
foreach ($x in @($onlyShip)) { [void]$errors.Add("ship:true missing from zip: $($x.InputObject)") }

if ($errors.Count -gt 0) {
    Write-Host "smoke-names.ps1: $($errors.Count) error(s)"
    $errors | ForEach-Object { Write-Host "  $_" }
    exit 1
}

Write-Host ("smoke-names.ps1: OK (zip={0} PE, ship:true={1})" -f $zipPe.Count, $ship.Count)
exit 0
