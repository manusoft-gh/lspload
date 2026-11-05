;; Inno Setup Lisp Plugin Installer Script
;; 
;; Setup script demonstrating how to install a lisp plugin on any or all
;; supported host platforms, versions, and architectures.

;; LEGAL NOTICE
;;
;; Copyright 2026 ManuSoft (http://www.manusoft.com)
;; All Rights Reserved
;;
;; The setup script and related sample files may be freely modified and used
;; for any purpose. The script and related sample files may be redistributed
;; if any revisions are clearly documented and this legal notice accompanies
;; all files.
;;
;; ManuSoft disclaims any and all liability for your use of this software.
;; The software is provided "as is" without warranty of any kind, either
;; express or implied.

;; PREREQUISITES
;;
;; The Inno Setup Compiler is required to build this script. The easiest
;; (and recommended) way to run the compiler is by using Inno Script Studio.
;; Inno Script Studio is a standalone IDE that is included in the
;; Unicode Inno Setup QuickStart Pack available at the Inno Setup Downloads
;; page:
;; http://www.jrsoftware.org/isdl.php
;;
;; Host [Files] lines and demand-load Pascal are generated from hosts.json
;; into generated\HostsFiles.iss and generated\HostsCode.iss. The generated\
;; folder must sit beside this script; the compiler #includes those fragments.

;; This script uses LspLoad to load a lisp plugin via registry based
;; demand-load keys. The LspLoad binaries must be obtained separately and
;; placed in a LspLoad subfolder relative to the folder containing this
;; script. The LspLoad binaries may be obtained from the ManuSoft web site
;; by downloading LspLoad.zip from the ARX freebies page:
;; http://www.manusoft.com/software/freebies/arx.html


#define MyAppName "My Lisp Plugin"
#define MyAppVersion "2.0"
#define MyAppPublisher "My Company, Inc."
#define MyAppURL "http://www.example.com/"
#define MyAppPublisherKey "MyCompany"

; MyAppBaseName must be set to the base filename of your main lisp file.
#define MyAppBaseName "MyLispPlugin"


[Setup]
AppId={#MyAppBaseName}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
;AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={commonpf}\{#MyAppPublisherKey}\{#MyAppName}
DefaultGroupName={#MyAppPublisherKey}\{#MyAppName}
OutputBaseFilename={#MyAppBaseName}Setup
PrivilegesRequiredOverridesAllowed=commandline
Compression=lzma
SolidCompression=yes
; Git / lab local build: SignTool=manusoft → P:\ManuSoft\Sign.bat $f (jsign).
; package-zips.ps1 STRIPS this line from LispPluginSetup.zip so third parties
; compile unsigned. Authors may add their own Sign Tool if they wish.
SignTool=manusoft

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"


[Files]
Source: {#MyAppBaseName}.lsp; DestDir: {app}; Flags: touch
Source: {#MyAppBaseName}Cmds.lsp; DestDir: {app}; Flags: touch


;; ----------------------------------------------------------------------------
;; Install the demand-load stub files and set up the demand-load registry
;; entries for all supported host applications. Note that the DestName
;; parameter must rename the stub files to match the main lisp filename.
;; Comment or delete any of these lines for unsupported host applications.

#include "generated/HostsFiles.iss"
;; ============================================================================


[Icons]
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"

     
[Registry]
Root: HKLM; Subkey: Software\{#MyAppPublisherKey}\{#MyAppBaseName}; Flags: uninsdeletekeyifempty; Check: IsAdminLoggedOn()
Root: HKCU; Subkey: Software\{#MyAppPublisherKey}\{#MyAppBaseName}; Flags: uninsdeletekeyifempty; Check: not IsAdminLoggedOn()
Root: HKLM; Subkey: Software\{#MyAppPublisherKey}\{#MyAppBaseName}; ValueType: string; ValueName: InstallPath; ValueData: {app}; Flags: uninsdeletekeyifempty uninsdeletevalue; Check: IsAdminLoggedOn()
Root: HKCU; Subkey: Software\{#MyAppPublisherKey}\{#MyAppBaseName}; ValueType: string; ValueName: InstallPath; ValueData: {app}; Flags: uninsdeletekeyifempty uninsdeletevalue; Check: not IsAdminLoggedOn()

 

[CustomMessages]
NoSupportedHost=The plugin files have been installed, however no supported host application has been configured to load them. Please check the plugin documentation for a list of supported host applications.


[Code]
// ============================================================================
// Hand-written helpers. Do not generate:
//   PopulateDemandloadKey, PopulateDemandloadKeyAcadR15,
//   GetPreferredRoot32/64, FoundSupportedHost, CurStepChanged,
//   CurUninstallStepChanged, DeleteDemandloadKeys.
// Host tables, IsAvailable, SetupDemandload, and DeleteAllDemandloadKeys
// live in generated/HostsCode.iss.
// ============================================================================

// ----------------------------------------------------------------------------
// PopulateDemandloadKey
//   - Populate a single demand-load registry key for the application.
// ----------------------------------------------------------------------------
procedure PopulateDemandloadKey(const RootKey: Integer; const AppsKey: String; const Loader: String);
begin
  RegWriteDWordValue(RootKey, AppsKey + '\{#MyAppBaseName}', 'LoadCtrls', 2); //2 = load at startup
  RegWriteStringValue(RootKey, AppsKey + '\{#MyAppBaseName}', 'Description', '{#MyAppName}');
  RegWriteStringValue(RootKey, AppsKey + '\{#MyAppBaseName}', 'Loader', ExpandConstant('{app}') + '\' + Loader);
end;

// ----------------------------------------------------------------------------
// PopulateDemandloadKeyAcadR15
//   - Populate a single demand-load registry key for AutoCAD 2000/2000i/2002.
// ----------------------------------------------------------------------------
procedure PopulateDemandloadKeyAcadR15(const RootKey: Integer; const AppsKey: String; const Loader: String);
begin
  RegWriteDWordValue(RootKey, AppsKey + '\{#MyAppBaseName}', 'LoadCtrls', 2); //2 = load at startup
  RegWriteStringValue(RootKey, AppsKey + '\{#MyAppBaseName}', 'RegPath', '\\HKEY_LOCAL_MACHINE\' + AppsKey + '\{#MyAppBaseName}');
  RegWriteStringValue(RootKey, AppsKey + '\{#MyAppBaseName}\Name', '{#MyAppName}', '{#MyAppName}');
  RegWriteStringValue(RootKey, AppsKey + '\{#MyAppBaseName}\Loader', 'Module', ExpandConstant('{app}') + '\' + Loader);
end;

// ----------------------------------------------------------------------------
// GetPreferredRoot32
//   - Return the preferred registry root for x86 registry access
// ----------------------------------------------------------------------------
function GetPreferredRoot32(): Integer;
begin
  if IsAdminInstallMode() then
    Result := HKLM32
  else
    Result := HKCU32;
end;

// ----------------------------------------------------------------------------
// GetPreferredRoot64
//   - Return the preferred registry root for x64 registry access
// ----------------------------------------------------------------------------
function GetPreferredRoot64(): Integer;
begin
  if IsAdminInstallMode() then
    Result := HKLM64
  else
    Result := HKCU64;
end;

// ----------------------------------------------------------------------------
// CurStepChanged
//   - Standard Inno Setup event handler
// ----------------------------------------------------------------------------
var FoundSupportedHost: Boolean; //this will be False if no supported host was found
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    if not FoundSupportedHost then
      SuppressibleMsgBox(ExpandConstant('{cm:NoSupportedHost}'), mbInformation, MB_OK, IDOK);
  end;
end;

procedure DeleteAllDemandloadKeys(); forward;

// ----------------------------------------------------------------------------
// CurUninstallStepChanged
//   - Standard Inno Setup event handler
// ----------------------------------------------------------------------------
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    DeleteAllDemandloadKeys();
  end;
end;

// ----------------------------------------------------------------------------
// DeleteDemandloadKeys
//   - Delete all demand-load registry keys found under all subkeys of the
//     host key.
// ----------------------------------------------------------------------------
procedure DeleteDemandloadKeys(const RootKey: Integer; const HostKey: String);
var
  Subkeys: TArrayOfString;
  Index: Integer;
begin
  if (Length('{#MyAppBaseName}') > 0) and (RegGetSubkeyNames(RootKey, HostKey, Subkeys)) then
  begin
    for Index := 0 to GetArrayLength(Subkeys)-1 do
      RegDeleteKeyIncludingSubkeys(RootKey, (HostKey + '\' + Subkeys[Index] + '\Applications\{#MyAppBaseName}'));
  end;
end;

#include "generated/HostsCode.iss"
