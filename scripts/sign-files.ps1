<#
.SYNOPSIS
  Authenticode-sign LspLoad binaries with jsign (YubiKey / SSL.com).

.DESCRIPTION
  Git/lab only — public zips must not include this script.
  Adapted from OpenDCL scripts/sign-files.ps1.
  Production: SSL.com cert on YubiKey -> jsign --storetype YUBIKEY.
  PIN from env (SIGN_STORE_PASSWORD / SIGN_PIN / YUBIKEY_PIN); never commit
  the PIN; jsign receives --storepass env:VAR so it is not on the command line.

  Credential modes (first match wins):
    1. -PfxPath + password (legacy / rare)
    2. Default YubiKey via -StoreType (default YUBIKEY)

  CMake post-build: sign-files.ps1 -Path <PE>
  Skip-if-already-Valid unless -Replace.

.EXAMPLE
  # Set SIGN_STORE_PASSWORD (or SIGN_PIN / YUBIKEY_PIN) in the environment first.
  .\scripts\sign-files.ps1 -Path .\build\vs2022-full-x64\out\Release\LspLoad.BRX.27.x64.brx
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string[]] $Path,

  [string] $StoreType = $(if ($env:SIGN_STORE_TYPE) { $env:SIGN_STORE_TYPE } else { "YUBIKEY" }),
  [string] $StorePasswordEnv = "",
  [string] $Alias = $(if ($env:SIGN_CERT_ALIAS) { $env:SIGN_CERT_ALIAS } else { "X.509 Certificate for PIV Authentication" }),
  [string] $CertFile = $env:SIGN_CERT_FILE,

  [string] $PfxPath = $env:SIGN_PFX_PATH,
  [string] $PfxPassword = "",

  [string] $TimestampUrl = $(if ($env:SIGN_TIMESTAMP_URL) { $env:SIGN_TIMESTAMP_URL } else { "http://ts.ssl.com" }),
  [string] $DescriptionUrl = $(if ($env:SIGN_DESCRIPTION_URL) { $env:SIGN_DESCRIPTION_URL } else { "https://www.manusoft.com" }),
  [string] $ProgramName = $(if ($env:SIGN_PROGRAM_NAME) { $env:SIGN_PROGRAM_NAME } else { "LspLoad" }),
  [string] $FileDigest = "SHA-256",
  [switch] $IncludeBinaries,
  [switch] $Recurse,
  [switch] $SkipVerify,
  [switch] $Replace,
  [string] $Jsign = ""
)

$ErrorActionPreference = "Stop"
Import-Module Microsoft.PowerShell.Security -ErrorAction Stop

function Find-Jsign {
  if ($Jsign -and (Test-Path -LiteralPath $Jsign)) { return (Resolve-Path -LiteralPath $Jsign).Path }
  $cmd = Get-Command jsign.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $cmd = Get-Command jsign -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $choco = "C:\ProgramData\chocolatey\bin\jsign.exe"
  if (Test-Path -LiteralPath $choco) { return $choco }
  throw "jsign not found on PATH. Install with: choco install jsign  (requires Java). Or pass -Jsign."
}

function Resolve-StorePasswordEnvName {
  if ($StorePasswordEnv) {
    if (-not [string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($StorePasswordEnv))) {
      return $StorePasswordEnv
    }
    throw "Store password env var '$StorePasswordEnv' is not set or empty."
  }
  foreach ($name in @("SIGN_STORE_PASSWORD", "SIGN_PIN", "YUBIKEY_PIN")) {
    foreach ($scope in @("Process", "User", "Machine")) {
      $val = [Environment]::GetEnvironmentVariable($name, $scope)
      if (-not [string]::IsNullOrEmpty($val)) {
        if ($scope -ne "Process") {
          [Environment]::SetEnvironmentVariable($name, $val, "Process")
        }
        return $name
      }
    }
  }
  return $null
}

function Get-FilesToSign {
  $files = [System.Collections.Generic.List[string]]::new()
  foreach ($p in $Path) {
    if (-not (Test-Path -LiteralPath $p)) { throw "Path not found: $p" }
    $item = Get-Item -LiteralPath $p
    if ($item.PSIsContainer) {
      $allowed = @(".msi", ".msm", ".exe")
      if ($IncludeBinaries) {
        $allowed += @(".arx", ".brx", ".zrx", ".grx", ".dll", ".cab", ".sys")
      }
      $gci = @{ Path = $item.FullName; File = $true }
      if ($Recurse) { $gci.Recurse = $true }
      Get-ChildItem @gci |
        Where-Object { $allowed -contains $_.Extension.ToLowerInvariant() } |
        ForEach-Object { $files.Add($_.FullName) }
    }
    else {
      $files.Add($item.FullName)
    }
  }
  return @($files | Select-Object -Unique)
}

function Test-ValidAuthenticode([string] $file) {
  try {
    $sig = Get-AuthenticodeSignature -FilePath $file
    return $sig.Status -eq "Valid"
  }
  catch {
    return $false
  }
}

function Normalize-Digest([string] $d) {
  switch -Regex ($d.Trim().ToUpperInvariant()) {
    '^(SHA-?256|SHA256)$' { return "SHA-256" }
    '^(SHA-?1|SHA1)$'     { return "SHA-1" }
    '^(SHA-?384|SHA384)$' { return "SHA-384" }
    '^(SHA-?512|SHA512)$' { return "SHA-512" }
    default { return $d }
  }
}

$files = @(Get-FilesToSign)
if ($files.Count -eq 0) { throw "No files to sign under Path." }

$skippedSigned = New-Object System.Collections.Generic.List[string]
if (-not $Replace) {
  $pending = New-Object System.Collections.Generic.List[string]
  foreach ($f in $files) {
    if (Test-ValidAuthenticode $f) {
      [void]$skippedSigned.Add($f)
    }
    else {
      [void]$pending.Add($f)
    }
  }
  $files = @($pending)
}

if ($skippedSigned.Count -gt 0) {
  Write-Host "Skip already signed: $($skippedSigned.Count) file(s)"
  foreach ($f in $skippedSigned) { Write-Host "  $f" }
}

if ($files.Count -eq 0) {
  Write-Host "OK nothing to sign ($($skippedSigned.Count) already-signed file(s) skipped)"
  exit 0
}

$jsignPath = Find-Jsign
$digest = Normalize-Digest $FileDigest
$argList = [System.Collections.Generic.List[string]]::new()
[void]$argList.Add("sign")
[void]$argList.AddRange([string[]]@("--alg", $digest))
[void]$argList.AddRange([string[]]@("--tsaurl", $TimestampUrl))
[void]$argList.AddRange([string[]]@("--tsmode", "RFC3161"))
if ($ProgramName) { [void]$argList.AddRange([string[]]@("--name", $ProgramName)) }
if ($DescriptionUrl) { [void]$argList.AddRange([string[]]@("--url", $DescriptionUrl)) }
if ($Replace) { [void]$argList.Add("--replace") }
if ($CertFile) {
  if (-not (Test-Path -LiteralPath $CertFile)) { throw "Cert file not found: $CertFile" }
  [void]$argList.AddRange([string[]]@("--certfile", $CertFile))
}

$mode = $null
if ($PfxPath) {
  if (-not (Test-Path -LiteralPath $PfxPath)) { throw "PFX not found: $PfxPath" }
  [void]$argList.AddRange([string[]]@("--keystore", $PfxPath))
  [void]$argList.AddRange([string[]]@("--storetype", "PKCS12"))
  if ($PfxPassword) {
    # Explicit -PfxPassword only; env path uses env:VAR so the secret is not in argv.
    [void]$argList.AddRange([string[]]@("--storepass", $PfxPassword))
  }
  elseif (-not [string]::IsNullOrEmpty($env:SIGN_PFX_PASSWORD)) {
    [void]$argList.AddRange([string[]]@("--storepass", "env:SIGN_PFX_PASSWORD"))
  }
  else {
    throw "PFX requires -PfxPassword or env SIGN_PFX_PASSWORD."
  }
  if ($Alias) { [void]$argList.AddRange([string[]]@("--alias", $Alias)) }
  $mode = "PKCS12 ($PfxPath)"
}
else {
  $pinEnv = Resolve-StorePasswordEnvName
  if (-not $pinEnv) {
    throw @"
No signing credentials configured.

Preferred (SSL.com YubiKey + jsign):
  1. YubiKey inserted; Yubico PIV Tool installed (ykcs11); SSL.com cert in PIV slot 9a
  2. Set SIGN_STORE_PASSWORD (also SIGN_PIN, YUBIKEY_PIN) in the environment
  3. .\scripts\sign-files.ps1 -Path <file-or-dir>

Never commit PINs or private keys to git. Never put the PIN on the command line.
"@
  }
  [void]$argList.AddRange([string[]]@("--storetype", $StoreType))
  [void]$argList.AddRange([string[]]@("--storepass", "env:$pinEnv"))
  if ($StoreType -match '^(?i)YUBIKEY|PIV$') {
    $pinLen = ([Environment]::GetEnvironmentVariable($pinEnv, 'Process')).Length
    if ($pinLen -lt 6 -or $pinLen -gt 8) {
      throw "YubiKey PIV PIN in env:$pinEnv has length $pinLen (expected 6-8). Refusing to login so we do not burn PIN tries. Set the YubiKey user PIN in SIGN_STORE_PASSWORD (not the SafeNet eToken password)."
    }
  }
  if ($Alias) { [void]$argList.AddRange([string[]]@("--alias", $Alias)) }
  $mode = "$StoreType (PIN from env:$pinEnv)"
}

Write-Host "Signing mode: $mode"
Write-Host "jsign:        $jsignPath"
Write-Host "Timestamp:    $TimestampUrl"
Write-Host "Description:  $DescriptionUrl"
Write-Host "Files:        $($files.Count)"

foreach ($f in $files) { Write-Host "Sign: $f" }
$allArgs = $argList.ToArray() + $files
& $jsignPath @allArgs
if ($LASTEXITCODE -ne 0) {
  throw "jsign failed (exit $LASTEXITCODE). Check YubiKey insertion, PIN env var (YubiKey PIN, not SafeNet), and alias (slot 9a)."
}

Write-Host "OK signed $($files.Count) file(s)."

if (-not $SkipVerify) {
  $bad = @()
  foreach ($f in $files) {
    $sig = Get-AuthenticodeSignature -FilePath $f
    if ($sig.Status -ne "Valid") {
      Write-Warning "Verify $($sig.Status): $f - $($sig.StatusMessage)"
      $bad += $f
    }
  }
  if ($bad.Count) { throw "Authenticode verify failed for $($bad.Count) file(s)." }
  Write-Host "Verified $($files.Count) file(s)."
}
