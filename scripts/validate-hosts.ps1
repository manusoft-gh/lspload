# Validate hosts/hosts.json against the 6.10 floor and matrix schema.
# Extra ship:true names beyond the floor are allowed (post-6.11).
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path $PSScriptRoot -Parent
$HostsPath = Join-Path $RepoRoot 'hosts\hosts.json'
$GoldPath = Join-Path $RepoRoot 'docs\gold\LspLoad-6.10-names.txt'

$errors = [System.Collections.Generic.List[string]]::new()
function Add-Err([string]$msg) { [void]$errors.Add($msg) }

if (-not (Test-Path -LiteralPath $HostsPath)) {
    Write-Error "Missing $HostsPath"
    exit 1
}
if (-not (Test-Path -LiteralPath $GoldPath)) {
    Write-Error "Missing $GoldPath"
    exit 1
}

$raw = Get-Content -LiteralPath $HostsPath -Raw -Encoding UTF8
$doc = $raw | ConvertFrom-Json
if ($null -eq $doc) {
    Write-Error "hosts.json did not parse"
    exit 1
}

if ($doc.PSObject.Properties.Name -contains 'productVersion') {
    Add-Err 'hosts.json must not contain productVersion'
}

$requiredFamilies = @('ARX', 'BRX', 'ZRX', 'GRX')
$familyExt = @{ ARX = '.arx'; BRX = '.brx'; ZRX = '.zrx'; GRX = '.grx' }
$familyDef = @{
    ARX = 'src/RxExports.def'
    BRX = 'src/RxExports.def'
    ZRX = 'src/ZrxExports.def'
    GRX = 'src/GrxExports.def'
}
$familyEntry = @{ ARX = 'acrx'; BRX = 'acrx'; ZRX = 'zcrx'; GRX = 'gcrx' }

if (-not $doc.families) {
    Add-Err 'missing families object'
}
else {
    foreach ($fam in $requiredFamilies) {
        $f = $doc.families.$fam
        if ($null -eq $f) {
            Add-Err "missing family $fam"
            continue
        }
        if ($f.ext -ne $familyExt[$fam]) { Add-Err "family $fam ext expected $($familyExt[$fam]) got $($f.ext)" }
        if ($f.def -ne $familyDef[$fam]) { Add-Err "family $fam def expected $($familyDef[$fam]) got $($f.def)" }
        if ($f.entry -ne $familyEntry[$fam]) { Add-Err "family $fam entry expected $($familyEntry[$fam]) got $($f.entry)" }
    }
}

if ($null -eq $doc.targets) {
    Add-Err 'missing targets array'
    $targets = @()
}
else {
    $targets = @($doc.targets)
}

$rowRequired = @(
    'id', 'family', 'version', 'arch', 'ext', 'def', 'outputName', 'toolset',
    'sdkEnv', 'sdkInc', 'sdkLib', 'libs', 'defines', 'characterSet',
    'cxxStandard', 'pinWindowsSdk', 'ship'
)
$probeRequired = @('key', 'curVerName', 'curVerHive', 'appsHive', 'writeRoot')
$hives = @('HKCU32', 'HKCU64', 'HKLM32', 'HKLM64')
$writeRoots = @('preferred32', 'preferred64', 'hklm32')
$outputRe = '^LspLoad\.(ARX|BRX|ZRX|GRX)\.[0-9]+(\.x64)?$'
$pinRe = '^v(60|70|80|90|100|110|120|140)'
$probeForbid = @('loader', 'destName', 'filename', 'Loader', 'DestName')

$ids = @{}
$shipNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$grxShip = 0
$grxRows = 0
$sawArx26 = $false
$zrx2023Has2024 = @{ x86 = $false; x64 = $false }
$zrx2025Has2026 = $false

foreach ($row in $targets) {
    $id = [string]$row.id
    if ([string]::IsNullOrWhiteSpace($id)) {
        Add-Err 'target missing id'
        continue
    }
    if ($ids.ContainsKey($id)) { Add-Err "duplicate id $id" }
    else { $ids[$id] = $true }

    foreach ($f in $rowRequired) {
        if (-not ($row.PSObject.Properties.Name -contains $f)) {
            Add-Err "$id missing field $f"
        }
    }

    $arch = [string]$row.arch
    if ($arch -notin @('x86', 'x64')) {
        Add-Err "$id arch must be x86 or x64 (got '$arch')"
    }

    $outName = [string]$row.outputName
    if ($outName -notmatch $outputRe) {
        Add-Err "$id outputName '$outName' does not match $outputRe"
    }
    else {
        $expect = if ($arch -eq 'x64') { "LspLoad.$($row.family).$($row.version).x64" } else { "LspLoad.$($row.family).$($row.version)" }
        if ($outName -ne $expect) { Add-Err "$id outputName '$outName' expected '$expect'" }
        if ($arch -eq 'x86' -and $outName -like '*.x64') { Add-Err "$id x86 outputName must not include .x64" }
        if ($arch -eq 'x64' -and $outName -notlike '*.x64') { Add-Err "$id x64 outputName must end with .x64" }
    }

    $fam = [string]$row.family
    if ($fam -notin $requiredFamilies) { Add-Err "$id unknown family $fam" }
    if ($fam -eq 'GRX') { $grxRows++ }

    $cxx = $row.cxxStandard
    if ($null -ne $cxx -and "$cxx" -ne '17') {
        Add-Err "$id cxxStandard must be 17 or null (got '$cxx')"
    }

    $toolset = [string]$row.toolset
    $pinExpected = [bool]($toolset -match $pinRe)
    if ([bool]$row.pinWindowsSdk -ne $pinExpected) {
        Add-Err "$id pinWindowsSdk is $($row.pinWindowsSdk) but toolset $toolset implies $pinExpected"
    }

    if ($id -eq 'ARX.26.x64') {
        $sawArx26 = $true
        if ($toolset -ne 'v145') { Add-Err "$id toolset must be v145 (got '$toolset')" }
        if ([bool]$row.pinWindowsSdk) { Add-Err "$id pinWindowsSdk must be false" }
        if ([string]$row.sdkEnv -ne 'ARX2027') { Add-Err "$id sdkEnv must be ARX2027" }
        if (@($row.defines) -notcontains '_ACADTARGET=26') { Add-Err "$id must define _ACADTARGET=26" }
        if ($row.cxxStandard -ne '17' -and "$($row.cxxStandard)" -ne '17') { Add-Err "$id cxxStandard must be 17" }
    }

    if ($fam -eq 'ARX' -and [string]$row.version -eq '15') {
        if ([string]$row.characterSet -ne 'MultiByte') { Add-Err "$id characterSet must be MultiByte" }
    }

    $ship = [bool]$row.ship
    $pe = "$outName$($row.ext)"
    if ($ship) { [void]$shipNames.Add($pe) }
    if ($fam -eq 'GRX' -and $ship) { $grxShip++ }

    if (-not ($row.PSObject.Properties.Name -contains 'reg') -or $null -eq $row.reg) {
        Add-Err "$id missing reg"
        continue
    }
    foreach ($rf in @('appsSuffix', 'loaderStyle', 'probes')) {
        if (-not ($row.reg.PSObject.Properties.Name -contains $rf)) {
            Add-Err "$id missing reg.$rf"
        }
    }
    if ($fam -eq 'ARX' -and [string]$row.version -eq '15' -and ($row.reg.PSObject.Properties.Name -contains 'loaderStyle')) {
        if ([string]$row.reg.loaderStyle -ne 'acadR15') { Add-Err "$id loaderStyle must be acadR15" }
    }
    if ($row.reg.PSObject.Properties.Name -contains 'probes') {
        $probes = @($row.reg.probes)
        if ($probes.Count -eq 0) { Add-Err "$id has no probes" }
        foreach ($p in $probes) {
            foreach ($pf in $probeRequired) {
                if (-not ($p.PSObject.Properties.Name -contains $pf) -or [string]::IsNullOrWhiteSpace([string]$p.$pf)) {
                    Add-Err "$id probe missing $pf"
                }
            }
            foreach ($bad in $probeForbid) {
                if ($p.PSObject.Properties.Name -contains $bad) {
                    Add-Err "$id probe must not carry $bad (Loader is row DestName $pe)"
                }
            }
            if ($p.PSObject.Properties.Name -contains 'writeRoot' -and [string]$p.writeRoot -notin $writeRoots) {
                Add-Err "$id probe writeRoot '$($p.writeRoot)' not in $($writeRoots -join ',')"
            }
            if ($fam -eq 'ARX' -and [string]$row.version -eq '15' -and ($p.PSObject.Properties.Name -contains 'writeRoot')) {
                if ([string]$p.writeRoot -ne 'hklm32') { Add-Err "$id probe writeRoot must be hklm32" }
            }
            if ($fam -eq 'BRX') {
                if (($p.PSObject.Properties.Name -contains 'curVerName') -and [string]$p.curVerName -ne 'CURVER') {
                    Add-Err "$id BRX curVerName must be CURVER"
                }
                if ($arch -eq 'x64' -and ($p.PSObject.Properties.Name -contains 'key') -and [string]$p.key -notmatch 'x64$') {
                    Add-Err "$id x64 BRX key must end with x64 (got $($p.key))"
                }
            }
            foreach ($hf in @('curVerHive', 'appsHive')) {
                if ($p.PSObject.Properties.Name -contains $hf -and [string]$p.$hf -notin $hives) {
                    Add-Err "$id probe $hf '$($p.$hf)' not a known hive"
                }
            }
            if ($fam -eq 'ZRX' -and ($p.PSObject.Properties.Name -contains 'key')) {
                if ([string]$row.version -eq '2023' -and [string]$p.key -like '*\2024') {
                    $zrx2023Has2024[$arch] = $true
                }
                if ([string]$row.version -eq '2025' -and [string]$p.key -like '*\2026') {
                    $zrx2025Has2026 = $true
                }
            }
        }
    }

    foreach ($arrName in @('sdkInc', 'sdkLib', 'libs', 'defines')) {
        $val = $row.$arrName
        if ($null -eq $val) { continue }
        # ConvertFrom-Json may scalar-unwrap a one-element array
        if ($val -isnot [System.Array] -and $val -isnot [string]) {
            Add-Err "$id $arrName must be an array"
        }
    }
}

if ($grxRows -ne 0) { Add-Err "GRX family must have zero targets (found $grxRows)" }
if ($grxShip -ne 0) { Add-Err "GRX ship:true is not allowed (found $grxShip)" }
foreach ($need in @('ZRX.2024', 'ZRX.2024.x64')) {
    $found = @($targets | Where-Object { [string]$_.id -eq $need })
    if ($found.Count -eq 0) {
        Add-Err "missing $need row (must exist with ship:false)"
        continue
    }
    foreach ($m in $found) {
        if ([bool]$m.ship) { Add-Err "$need must have ship:false" }
    }
}
if (-not $sawArx26) { Add-Err 'missing ARX.26.x64 row' }
if (-not $zrx2023Has2024['x86']) { Add-Err 'ZRX.2023 x86 must probe ZWCAD 2024' }
if (-not $zrx2023Has2024['x64']) { Add-Err 'ZRX.2023 x64 must probe ZWCAD 2024' }
if (-not $zrx2025Has2026) { Add-Err 'ZRX.2025 must probe ZWCAD 2026 (2025 DestName, not ZRX.2026)' }

$gold = Get-Content -LiteralPath $GoldPath | ForEach-Object { $_.Trim() } | Where-Object { $_ }
foreach ($name in $gold) {
    $match = @($targets | Where-Object { "$($_.outputName)$($_.ext)" -eq $name })
    if ($match.Count -eq 0) {
        Add-Err "gold floor name $name has no matching row"
        continue
    }
    foreach ($m in $match) {
        if (-not [bool]$m.ship) { Add-Err "gold floor name $name must remain ship:true" }
    }
}

if ($errors.Count -gt 0) {
    Write-Host "validate-hosts.ps1: $($errors.Count) error(s)"
    $errors | ForEach-Object { Write-Host "  $_" }
    exit 1
}

Write-Host ("validate-hosts.ps1: OK ({0} targets, {1} ship:true, {2} gold-floor names)" -f $targets.Count, $shipNames.Count, $gold.Count)
exit 0
