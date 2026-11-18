; Inno Setup script for the Ant Manager Windows installer (UNSIGNED until a code-signing cert exists).
;
; Build (from the repo root, after `flutter build windows --release` in app/):
;   iscc /DAppVersion=1.2.3 packaging\windows\installer.iss
; Optional overrides: /DSourceDir=<flutter Release dir> /DOutputDir=<dir>
; Output: dist\AntManager-<AppVersion>-windows-setup.exe
;
; Relative paths below resolve against this script's directory.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\app\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif
#define AppName "Ant Manager"
#define AppExe "ant_manager.exe"

[Setup]
; AppId identifies the install for upgrades/uninstall. Never change it.
AppId={{25124EB0-1C11-4F0B-9DE4-973E1D2CD4C9}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Ant Manager
AppPublisherURL=https://github.com/thecodepapaya/ant-manager
AppSupportURL=https://github.com/thecodepapaya/ant-manager/issues
; Per-user install (no UAC prompt), so the updater can replace it without elevation.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DefaultDirName={autopf}\{#AppName}
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#OutputDir}
OutputBaseFilename=AntManager-{#AppVersion}-windows-setup
SetupIconFile=..\..\app\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
