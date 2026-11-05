# THE copier/zipper for the three public zips (no WinZip).
# Harvest only pinned full-* out/Release then rolling gold/. Public zips must
# never contain signing scripts or an active SignTool= (git/lab keeps those).
[CmdletBinding()]
param(
    [switch] $Official,
    # Rebuild-all lab job: every ship:true PE must come from this run's full-*
    # outputs. Do not pass on a normal host-add (overlay is the point).
    [switch] $RequireAllShip,
    [string] $GoldSeedZip = 'P:\Work\LspLoad\LspLoad.zip'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$RepoRoot = Split-Path $PSScriptRoot -Parent
$HostsPath = Join-Path $RepoRoot 'hosts\hosts.json'
$DistDir = Join-Path $RepoRoot 'dist'
$GoldDir = Join-Path $RepoRoot 'gold'
$InnoLspLoad = Join-Path $RepoRoot 'InnoSetup\LspLoad'
$ProductReadMe = Join-Path $RepoRoot 'ReadMe.txt'
$KitReadMe = Join-Path $RepoRoot 'InnoSetup\ReadMe.txt'
$GitIss = Join-Path $RepoRoot 'InnoSetup\MyLispPlugin.iss'
$GenDir = Join-Path $RepoRoot 'InnoSetup\generated'

$ForbiddenNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($n in @('sign-files.ps1', 'SignLispFiles.bat', '#Sign.bat')) {
    [void]$ForbiddenNames.Add($n)
}

$HarvestRel = @(
    'build\vs2022-full-x64\out\Release',
    'build\vs2022-full-win32\out\Release',
    'build\vs2026-full-x64\out\Release'
)

function Test-ForbiddenDrive([string] $path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return }
    if ($path -match '^[XxBb]:') {
        throw "Refusing path on X: or B:: $path"
    }
}

function Get-ShipPeNames {
    if (-not (Test-Path -LiteralPath $HostsPath)) {
        throw "Missing $HostsPath"
    }
    $doc = (Get-Content -LiteralPath $HostsPath -Raw -Encoding UTF8) | ConvertFrom-Json
    $names = [System.Collections.Generic.List[string]]::new()
    foreach ($row in @($doc.targets)) {
        if (-not [bool]$row.ship) { continue }
        $names.Add("$($row.outputName)$($row.ext)")
    }
    return @($names | Sort-Object -Unique)
}

function Ensure-Dir([string] $path) {
    if (-not (Test-Path -LiteralPath $path)) {
        [void](New-Item -ItemType Directory -Path $path -Force)
    }
}

function Get-FileSha256([string] $path) {
    return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Seed-GoldIfEmpty {
    Ensure-Dir $GoldDir
    $existing = @(Get-ChildItem -LiteralPath $GoldDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -match '^\.(arx|brx|zrx|grx)$' })
    if ($existing.Count -gt 0) { return }

    Test-ForbiddenDrive $GoldSeedZip
    if (-not (Test-Path -LiteralPath $GoldSeedZip)) {
        Write-Warning "gold/ is empty and seed zip not found: $GoldSeedZip"
        return
    }

    Write-Host "Seeding gold/ from $GoldSeedZip"
    $zip = [System.IO.Compression.ZipFile]::OpenRead($GoldSeedZip)
    try {
        foreach ($entry in $zip.Entries) {
            $leaf = [System.IO.Path]::GetFileName($entry.FullName)
            if ([string]::IsNullOrWhiteSpace($leaf)) { continue }
            if ($leaf -notmatch '\.(arx|brx|zrx|grx)$') { continue }
            $dest = Join-Path $GoldDir $leaf
            $in = $entry.Open()
            try {
                $out = [System.IO.File]::Create($dest)
                try { $in.CopyTo($out) }
                finally { $out.Dispose() }
            }
            finally { $in.Dispose() }
        }
    }
    finally { $zip.Dispose() }
}

function Get-AuthenticodeStatus([string] $path) {
    $sig = Get-AuthenticodeSignature -LiteralPath $path
    return [string]$sig.Status
}

function Find-HarvestedPe([string] $name) {
    foreach ($rel in $HarvestRel) {
        $candidate = Join-Path $RepoRoot (Join-Path $rel $name)
        if (Test-Path -LiteralPath $candidate) {
            return [pscustomobject]@{
                Name   = $name
                Path   = $candidate
                Origin = 'rebuilt'
                Source = $rel
            }
        }
    }
    $goldPath = Join-Path $GoldDir $name
    if (Test-Path -LiteralPath $goldPath) {
        return [pscustomobject]@{
            Name   = $name
            Path   = $goldPath
            Origin = 'reused-gold'
            Source = 'gold/'
        }
    }
    return $null
}

function New-ZipFromEntries([string] $zipPath, $entries) {
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    Ensure-Dir (Split-Path $zipPath -Parent)
    $zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($e in $entries) {
            $entryName = ([string]$e.Entry) -replace '\\', '/'
            [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $zip,
                [string]$e.Path,
                $entryName,
                [System.IO.Compression.CompressionLevel]::Optimal
            )
        }
    }
    finally { $zip.Dispose() }
}

function Get-ZipEntryNames([string] $zipPath) {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        return @($zip.Entries | ForEach-Object { $_.FullName -replace '\\', '/' })
    }
    finally { $zip.Dispose() }
}

function Read-ZipEntryText([string] $zipPath, [string] $entryName) {
    $want = $entryName -replace '\\', '/'
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        foreach ($entry in $zip.Entries) {
            $n = $entry.FullName -replace '\\', '/'
            if ($n -ne $want) { continue }
            $sr = New-Object System.IO.StreamReader($entry.Open())
            try { return $sr.ReadToEnd() }
            finally { $sr.Dispose() }
        }
    }
    finally { $zip.Dispose() }
    return $null
}

function Assert-ZipHasNoSigning([string] $zipPath) {
    $names = Get-ZipEntryNames $zipPath
    $errors = [System.Collections.Generic.List[string]]::new()
    foreach ($n in $names) {
        $leaf = [System.IO.Path]::GetFileName($n)
        if ($ForbiddenNames.Contains($leaf)) {
            $errors.Add("${zipPath}: packed forbidden $n")
        }
        if ($leaf -like 'sign-lisp*') {
            $errors.Add("${zipPath}: packed forbidden $n")
        }
        if ($n -match '(^|/)\.agents(/|$)' -or $n -match '(^|/)skills(/|$)') {
            $errors.Add("${zipPath}: packed maintainer skill path $n")
        }
        if ($leaf -like '*.vcxproj' -or $leaf -like '*.pdb') {
            $errors.Add("${zipPath}: packed $n")
        }
        if ($leaf -like '*.iss') {
            $text = Read-ZipEntryText $zipPath $n
            if ($text -match 'SignTool=') {
                $errors.Add("${zipPath}: $n still contains SignTool=")
            }
        }
    }
    if ($errors.Count -gt 0) {
        throw ($errors -join [Environment]::NewLine)
    }
}

function Write-StrippedIss([string] $src, [string] $dest) {
    $raw = Get-Content -LiteralPath $src -Raw -Encoding UTF8
    # Drop any line that would make the public zip fail the SignTool= scan,
    # including comments that mention the lab alias.
    $kept = [System.Collections.Generic.List[string]]::new()
    $stripped = $false
    # PowerShell -split with a negative max counts from the end; 0 = all.
    foreach ($line in ($raw -split '\r?\n')) {
        if ($line -match 'SignTool=' -or
            $line -match 'package-zips\.ps1 STRIPS' -or
            $line -match 'compile unsigned\. Authors may add their own Sign Tool') {
            $stripped = $true
            continue
        }
        $kept.Add($line)
    }
    $text = $kept -join "`r`n"
    if ($stripped -and $text -notmatch 'Public kit copy: Inno Sign Tool alias omitted') {
        $insert = '; Public kit copy: Inno Sign Tool alias omitted so the sample compiles unsigned.'
        if ($text -match '(?m)^\[Setup\]\s*$') {
            $text = [regex]::Replace($text, '(?m)^\[Setup\]\s*$', "[Setup]`r`n$insert", 1)
        }
        else {
            $text = $insert + "`r`n" + $text
        }
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($dest, $text.TrimEnd() + "`r`n", $utf8NoBom)
}

function Write-UnsignedLisp([string] $src, [string] $dest) {
    Copy-Item -LiteralPath $src -Destination $dest -Force
    $acsign = $null
    foreach ($c in @('P:\Tools\Lisp\acsigntool.exe', 'T:\Lisp\AcSignTool.exe')) {
        Test-ForbiddenDrive $c
        if (Test-Path -LiteralPath $c) { $acsign = $c; break }
    }
    if ($acsign) {
        & $acsign -remove -force "/file:$dest" 2>$null | Out-Null
    }
    $bytes = [System.IO.File]::ReadAllBytes($dest)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    $stripped = [regex]::Replace(
        $text,
        '(?ms)\r?\n;;[-]*\s*BEGIN[^\r\n]*SIGNATURE.*?\r?\n;;[-]*\s*END[^\r\n]*SIGNATURE[^\r\n]*',
        ''
    )
    if ($stripped -ne $text) {
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($dest, $stripped, $utf8NoBom)
    }
    $check = [System.IO.File]::ReadAllText($dest)
    if ($check -match 'BEGIN[^\r\n]*SIGNATURE') {
        throw "Unsigned lisp still looks signed: $dest"
    }
}

Test-ForbiddenDrive $RepoRoot
Test-ForbiddenDrive $GoldSeedZip

$shipNames = @(Get-ShipPeNames)
if ($shipNames.Count -eq 0) {
    throw 'hosts.json has no ship:true targets'
}

Seed-GoldIfEmpty
Ensure-Dir $DistDir
Ensure-Dir $InnoLspLoad

$harvest = [System.Collections.Generic.List[object]]::new()
$missing = [System.Collections.Generic.List[string]]::new()
$notRebuilt = [System.Collections.Generic.List[string]]::new()
$authFail = [System.Collections.Generic.List[string]]::new()
$reused = 0
$rebuilt = 0

foreach ($name in $shipNames) {
    $hit = Find-HarvestedPe $name
    if ($null -eq $hit) {
        $missing.Add($name)
        continue
    }
    if ($Official) {
        $st = Get-AuthenticodeStatus $hit.Path
        if ($st -ne 'Valid') {
            $authFail.Add("$name Authenticode=$st origin=$($hit.Origin)")
        }
        $hit | Add-Member -NotePropertyName Auth -NotePropertyValue $st
    }
    else {
        $hit | Add-Member -NotePropertyName Auth -NotePropertyValue (Get-AuthenticodeStatus $hit.Path)
    }
    if ($RequireAllShip -and $hit.Origin -ne 'rebuilt') {
        $notRebuilt.Add("$name origin=$($hit.Origin) source=$($hit.Source)")
        continue
    }
    if ($hit.Origin -eq 'rebuilt') { $rebuilt++ } else { $reused++ }
    Write-Host ("  {0,-32} {1,-12} {2}" -f $name, $hit.Origin, $hit.Source)
    $harvest.Add($hit)
}

if ($missing.Count -gt 0) {
    throw "Missing ship:true PE (not in full-* out/Release or gold/):`n  $($missing -join "`n  ")"
}
if ($notRebuilt.Count -gt 0) {
    throw "-RequireAllShip: every ship:true PE must be rebuilt this run (not reused-gold):`n  $($notRebuilt -join "`n  ")"
}
if ($authFail.Count -gt 0) {
    throw "Authenticode not Valid:`n  $($authFail -join "`n  ")"
}

$stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("lspload-pkg-" + [guid]::NewGuid().ToString('N'))
Ensure-Dir $stageRoot
try {
    $binStage = Join-Path $stageRoot 'bin'
    $kitStage = Join-Path $stageRoot 'kit'
    Ensure-Dir $binStage
    Ensure-Dir $kitStage

    Copy-Item -LiteralPath $ProductReadMe -Destination (Join-Path $binStage 'ReadMe.txt') -Force
    Get-ChildItem -LiteralPath $InnoLspLoad -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -match '^\.(arx|brx|zrx|grx)$' } |
        Remove-Item -Force
    foreach ($h in $harvest) {
        Copy-Item -LiteralPath $h.Path -Destination (Join-Path $binStage $h.Name) -Force
        Copy-Item -LiteralPath $h.Path -Destination (Join-Path $InnoLspLoad $h.Name) -Force
    }

    $binEntries = @(
        @{ Path = (Join-Path $binStage 'ReadMe.txt'); Entry = 'ReadMe.txt' }
    )
    foreach ($h in ($harvest | Sort-Object Name)) {
        $binEntries += @{ Path = (Join-Path $binStage $h.Name); Entry = $h.Name }
    }

    # Source zip: public-domain stub sources only. Never pack sign-files.ps1.
    $srcFiles = @(
        @{ Rel = 'CMakeLists.txt' },
        @{ Rel = 'CMakePresets.json' },
        @{ Rel = 'VERSION' },
        @{ Rel = 'PUBLIC-DOMAIN.txt' },
        @{ Rel = 'ReadMe.txt' },
        @{ Rel = 'cmake\LspLoadHosts.cmake' },
        @{ Rel = 'cmake\LspLoadTargets.cmake' },
        @{ Rel = 'hosts\hosts.json' },
        @{ Rel = 'src\LspLoad.cpp' },
        @{ Rel = 'src\RxExports.def' },
        @{ Rel = 'src\ZrxExports.def' },
        @{ Rel = 'src\GrxExports.def' },
        @{ Rel = 'scripts\sync-from-hosts.ps1' },
        @{ Rel = 'scripts\validate-hosts.ps1' },
        @{ Rel = 'scripts\package-zips.ps1' }
    )
    $srcEntries = @()
    foreach ($sf in $srcFiles) {
        $abs = Join-Path $RepoRoot $sf.Rel
        if (-not (Test-Path -LiteralPath $abs)) {
            throw "Source zip missing $($sf.Rel)"
        }
        $entry = ($sf.Rel -replace '\\', '/')
        $srcEntries += @{ Path = $abs; Entry = $entry }
    }

    $kitIss = Join-Path $kitStage 'MyLispPlugin.iss'
    Write-StrippedIss -src $GitIss -dest $kitIss
    $kitLsp = Join-Path $kitStage 'MyLispPlugin.lsp'
    $kitCmds = Join-Path $kitStage 'MyLispPluginCmds.lsp'
    Write-UnsignedLisp -src (Join-Path $RepoRoot 'InnoSetup\MyLispPlugin.lsp') -dest $kitLsp
    Write-UnsignedLisp -src (Join-Path $RepoRoot 'InnoSetup\MyLispPluginCmds.lsp') -dest $kitCmds

    $kitEntries = @(
        @{ Path = $KitReadMe; Entry = 'ReadMe.txt' },
        @{ Path = $kitIss; Entry = 'MyLispPlugin.iss' },
        @{ Path = $kitLsp; Entry = 'MyLispPlugin.lsp' },
        @{ Path = $kitCmds; Entry = 'MyLispPluginCmds.lsp' },
        @{ Path = (Join-Path $GenDir 'HostsFiles.iss'); Entry = 'generated/HostsFiles.iss' },
        @{ Path = (Join-Path $GenDir 'HostsCode.iss'); Entry = 'generated/HostsCode.iss' }
    )
    foreach ($ke in $kitEntries) {
        if (-not (Test-Path -LiteralPath $ke.Path)) {
            throw "Kit zip missing $($ke.Path)"
        }
    }

    $zipBin = Join-Path $DistDir 'LspLoad.zip'
    $zipSrc = Join-Path $DistDir 'LspLoadSource.zip'
    $zipKit = Join-Path $DistDir 'LispPluginSetup.zip'

    New-ZipFromEntries $zipBin $binEntries
    New-ZipFromEntries $zipSrc $srcEntries
    New-ZipFromEntries $zipKit $kitEntries

    Assert-ZipHasNoSigning $zipSrc
    Assert-ZipHasNoSigning $zipKit
    Assert-ZipHasNoSigning $zipBin

    $binNames = @(Get-ZipEntryNames $zipBin)
    $binPe = @($binNames | Where-Object { $_ -ne 'ReadMe.txt' } | Sort-Object)
    $expectedPe = @($shipNames | Sort-Object)
    $onlyZip = Compare-Object $expectedPe $binPe | Where-Object { $_.SideIndicator -eq '=>' }
    $onlyShip = Compare-Object $expectedPe $binPe | Where-Object { $_.SideIndicator -eq '<=' }
    if ($onlyZip -or $onlyShip) {
        throw "LspLoad.zip PE names must equal ship:true set. extra=$($onlyZip.InputObject -join ',') missing=$($onlyShip.InputObject -join ',')"
    }
    if ($binNames -notcontains 'ReadMe.txt') {
        throw 'LspLoad.zip missing ReadMe.txt'
    }

    $srcNames = Get-ZipEntryNames $zipSrc
    if ($srcNames -contains 'scripts/sign-files.ps1' -or $srcNames -contains 'scripts\sign-files.ps1') {
        throw 'LspLoadSource.zip contains sign-files.ps1'
    }
    $kitNames = Get-ZipEntryNames $zipKit
    foreach ($bad in @('SignLispFiles.bat', 'sign-files.ps1', '#Sign.bat')) {
        if ($kitNames | Where-Object { $_ -match [regex]::Escape($bad) }) {
            throw "LispPluginSetup.zip contains $bad"
        }
    }
    $kitPe = @($kitNames | Where-Object { $_ -match '\.(arx|brx|zrx|grx)$' })
    if ($kitPe.Count -gt 0) {
        throw "LispPluginSetup.zip must not contain PE: $($kitPe -join ', ')"
    }
    $kitWant = @(
        'ReadMe.txt', 'MyLispPlugin.iss', 'MyLispPlugin.lsp', 'MyLispPluginCmds.lsp',
        'generated/HostsFiles.iss', 'generated/HostsCode.iss'
    ) | Sort-Object
    $kitHave = @($kitNames | ForEach-Object { $_ -replace '\\', '/' } | Sort-Object)
    $kitExtra = Compare-Object $kitWant $kitHave | Where-Object { $_.SideIndicator -eq '=>' }
    $kitMissing = Compare-Object $kitWant $kitHave | Where-Object { $_.SideIndicator -eq '<=' }
    if ($kitExtra -or $kitMissing) {
        throw "LispPluginSetup.zip entries must be the kit sources only. extra=$($kitExtra.InputObject -join ',') missing=$($kitMissing.InputObject -join ',')"
    }

    $sumsPath = Join-Path $DistDir 'SHA256SUMS.txt'
    $lines = [System.Collections.Generic.List[string]]::new()
    [void]$lines.Add('# name  bytes  sha256  authenticode  origin')
    foreach ($h in ($harvest | Sort-Object Name)) {
        $len = (Get-Item -LiteralPath $h.Path).Length
        $hash = Get-FileSha256 $h.Path
        [void]$lines.Add("$($h.Name)  $len  $hash  $($h.Auth)  $($h.Origin)")
    }
    [void]$lines.Add('# zips')
    foreach ($z in @($zipBin, $zipSrc, $zipKit)) {
        $item = Get-Item -LiteralPath $z
        $hash = Get-FileSha256 $z
        [void]$lines.Add("$($item.Name)  $($item.Length)  $hash")
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllLines($sumsPath, $lines, $utf8NoBom)

    if ($Official) {
        # Rolling overlay: this successful official zip becomes next run's gold/.
        foreach ($old in @(Get-ChildItem -LiteralPath $GoldDir -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Extension -match '^\.(arx|brx|zrx|grx)$' })) {
            if ($shipNames -notcontains $old.Name) {
                Remove-Item -LiteralPath $old.FullName -Force
            }
        }
        foreach ($h in $harvest) {
            Copy-Item -LiteralPath (Join-Path $binStage $h.Name) -Destination (Join-Path $GoldDir $h.Name) -Force
        }
    }

    Write-Host "Packed $zipBin  ($($binPe.Count) PE, rebuilt=$rebuilt reused-gold=$reused)"
    Write-Host "Packed $zipSrc"
    Write-Host "Packed $zipKit"
    Write-Host "Wrote $sumsPath"
}
finally {
    if (Test-Path -LiteralPath $stageRoot) {
        Remove-Item -LiteralPath $stageRoot -Recurse -Force
    }
}
