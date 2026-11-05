# Registry-stub (no CAD): assert generated Inno tables write the row DestName
# for every probe, including ZWCAD 2026 → ZRX.2025.x64.zrx.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path $PSScriptRoot -Parent
$HostsPath = Join-Path $RepoRoot 'hosts\hosts.json'
$FilesIss = Join-Path $RepoRoot 'InnoSetup\generated\HostsFiles.iss'
$CodeIss = Join-Path $RepoRoot 'InnoSetup\generated\HostsCode.iss'
$MainIss = Join-Path $RepoRoot 'InnoSetup\MyLispPlugin.iss'

$errors = [System.Collections.Generic.List[string]]::new()
function Add-Err([string]$msg) { [void]$errors.Add($msg) }

function Get-InnoDestName($row) {
    $archTok = if ([string]$row.arch -eq 'x64') { '.x64' } else { '' }
    return "{#MyAppBaseName}.$($row.family).$($row.version)$archTok$($row.ext)"
}

# Uninstall hive expansion from writeRoot (design table).
function Get-UninstallHives([string]$writeRoot, [string]$arch, [bool]$isWin64, [bool]$isAdmin) {
    $hives = [System.Collections.Generic.List[string]]::new()
    if ($arch -eq 'x64' -and -not $isWin64) { return @() }
    switch ($writeRoot) {
        'preferred32' {
            if ($isAdmin) { [void]$hives.Add('HKLM32') }
            [void]$hives.Add('HKCU32')
        }
        'preferred64' {
            if (-not $isWin64) { return @() }
            if ($isAdmin) { [void]$hives.Add('HKLM64') }
            [void]$hives.Add('HKCU64')
        }
        'hklm32' {
            if ($isAdmin) { [void]$hives.Add('HKLM32') }
            [void]$hives.Add('HKCU32')
        }
        default { throw "unknown writeRoot $writeRoot" }
    }
    return @($hives)
}

$doc = Get-Content -LiteralPath $HostsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$shipRows = @($doc.targets | Where-Object { [bool]$_.ship })

# Simulate SetupDemandload writes: each matching probe gets the ROW DestName.
$writes = [System.Collections.Generic.List[object]]::new()
foreach ($row in $shipRows) {
    $dest = Get-InnoDestName $row
    foreach ($p in @($row.reg.probes)) {
        [void]$writes.Add([pscustomobject]@{
                Id     = [string]$row.id
                Host   = [string]$row.family
                Ver    = [string]$row.version
                Arch   = [string]$row.arch
                Key    = [string]$p.key
                Loader = $dest
            })
    }
}

$z2026 = @($writes | Where-Object { $_.Key -like '*\2026' })
if ($z2026.Count -eq 0) {
    Add-Err 'no simulated write for ZWCAD 2026'
}
foreach ($w in $z2026) {
    if ($w.Ver -ne '2025' -or $w.Id -ne 'ZRX.2025.x64') {
        Add-Err "ZWCAD 2026 write is from $($w.Id) Ver=$($w.Ver) (expected ZRX.2025.x64)"
    }
    if ($w.Loader -ne '{#MyAppBaseName}.ZRX.2025.x64.zrx') {
        Add-Err "ZWCAD 2026 Loader is '$($w.Loader)' (expected 2025 DestName)"
    }
}

$bad2026 = @($writes | Where-Object { $_.Loader -like '*ZRX.2026*' })
if ($bad2026.Count -gt 0) {
    Add-Err ("found ZRX.2026 DestName on {0}" -f ($bad2026.Id -join ', '))
}

# ARX 15: hklm32 uninstall always also walks HKCU32 (defensive leftovers).
$arx15 = @($shipRows | Where-Object { [string]$_.id -eq 'ARX.15' })
if ($arx15.Count -eq 1) {
    $p = @($arx15[0].reg.probes)[0]
    $hives = Get-UninstallHives ([string]$p.writeRoot) ([string]$arx15[0].arch) $true $true
    if ($hives -notcontains 'HKLM32' -or $hives -notcontains 'HKCU32') {
        Add-Err ("ARX.15 uninstall hives were {0} (expected HKLM32+HKCU32)" -f ($hives -join ','))
    }
    if ([string]$arx15[0].reg.loaderStyle -ne 'acadR15') {
        Add-Err 'ARX.15 loaderStyle must be acadR15'
    }
}

# BRX CURVER
$brx = @($shipRows | Where-Object { [string]$_.family -eq 'BRX' })
foreach ($row in $brx) {
    foreach ($p in @($row.reg.probes)) {
        if ([string]$p.curVerName -ne 'CURVER') {
            Add-Err "$($row.id) curVerName is '$($p.curVerName)' (expected CURVER)"
        }
    }
}

# preferred64 skips when not Win64
$z25 = @($shipRows | Where-Object { [string]$_.id -eq 'ZRX.2025.x64' })[0]
$p64 = @($z25.reg.probes)[0]
$skip = @(Get-UninstallHives ([string]$p64.writeRoot) 'x64' $false $true)
if ($skip.Count -ne 0) {
    Add-Err 'preferred64 x64 probe must skip uninstall when not IsWin64()'
}

if (-not (Test-Path -LiteralPath $FilesIss) -or -not (Test-Path -LiteralPath $CodeIss)) {
    Add-Err 'generated HostsFiles.iss / HostsCode.iss missing; run scripts/sync-from-hosts.ps1'
}
else {
    $filesText = [System.IO.File]::ReadAllText($FilesIss)
    $codeText = [System.IO.File]::ReadAllText($CodeIss)
    if ($filesText -match '(?m)^\[Files\]') { Add-Err 'HostsFiles.iss has a [Files] header' }
    if ($codeText -match '(?m)^\[Code\]') { Add-Err 'HostsCode.iss has a [Code] header' }
    if ($filesText -notmatch 'LspLoad\.ZRX\.2025\.x64\.zrx') { Add-Err 'HostsFiles.iss missing ZRX.2025 Source' }
    if ($filesText -match 'ZRX\.2026') { Add-Err 'HostsFiles.iss mentions ZRX.2026' }
    if ($codeText -notmatch "\{#MyAppBaseName\}\.ZRX\.2025\.x64\.zrx") {
        Add-Err 'HostsCode.iss missing ZRX.2025 DestName'
    }
    if ($codeText -notmatch "Software\\ZWSOFT\\ZWCAD\\2026") {
        Add-Err 'HostsCode.iss missing ZWCAD 2026 probe key'
    }
    if ($codeText -notmatch "SetHostProbe\([^;]*'ZRX', '2025', 'x64', 'CurVer', 'Software\\ZWSOFT\\ZWCAD\\2026'") {
        Add-Err 'ZWCAD 2026 probe is not bound to ZRX Ver 2025'
    }
    if ($codeText -notmatch 'FoundSupportedHost := True') {
        Add-Err 'IsAvailable must set FoundSupportedHost'
    }
    if ($codeText -notmatch 'DeleteDemandloadKeys\(') {
        Add-Err 'DeleteAllDemandloadKeys must call DeleteDemandloadKeys'
    }
}

$iss = [System.IO.File]::ReadAllText($MainIss)
if ($iss -notmatch '(?m)^SignTool=manusoft\s*$') {
    Add-Err 'git MyLispPlugin.iss must keep SignTool=manusoft'
}
if ($iss -notmatch '#include "generated/HostsFiles.iss"') {
    Add-Err 'MyLispPlugin.iss missing HostsFiles include'
}
if ($iss -notmatch '#include "generated/HostsCode.iss"') {
    Add-Err 'MyLispPlugin.iss missing HostsCode include'
}
if ($iss -notmatch 'LEGAL NOTICE') {
    Add-Err 'MyLispPlugin.iss missing LEGAL NOTICE'
}
if ($iss -notmatch '#define MyAppVersion "2.0"') {
    Add-Err 'MyAppVersion must stay 2.0 (not coupled to LspLoad VERSION)'
}

if ($errors.Count -gt 0) {
    Write-Host "test-inno-demandload.ps1: $($errors.Count) error(s)"
    $errors | ForEach-Object { Write-Host "  $_" }
    exit 1
}

Write-Host ("test-inno-demandload.ps1: OK ({0} simulated Loader writes; ZRX 2026 → 2025 DestName)" -f $writes.Count)
exit 0
