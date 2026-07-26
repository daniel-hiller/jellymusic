; ===========================================================================
;  JellyMusic · Windows installer (Inno Setup 6)
;
;  Built in CI (see .github/workflows/release.yml). Pass the version on the
;  command line; the Flutter release bundle path defaults to the repo layout
;  but can be overridden:
;     ISCC /DMyAppVersion=1.2.3 windows\installer\jellymusic.iss
;     ISCC /DMyAppVersion=1.2.3 /DBuildDir=<abs path> windows\installer\jellymusic.iss
;
;  Per-user install by default (PrivilegesRequired=lowest) → no UAC prompt,
;  installs under %LOCALAPPDATA%\Programs. Pass /ALLUSERS for a system install.
; ===========================================================================

#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif
#ifndef BuildDir
  #define BuildDir "..\..\build\windows\x64\runner\Release"
#endif

#define MyAppName      "JellyMusic"
#define MyAppPublisher "Daniel Hiller"
#define MyAppExeName   "jellymusic.exe"
#define MyAppURL       "https://github.com/daniel-hiller/jellymusic"

[Setup]
; A stable, unique AppId keeps upgrades in place (do not change once shipped).
AppId={{9F3B2A54-6E1D-4C7A-9E2B-0B7A5C1D8E42}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoProductName={#MyAppName}
VersionInfoDescription=JellyMusic - a music-first Jellyfin client
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName} {#MyAppVersion}
; Per-user install by default → no UAC. Pass /ALLUSERS for a system install.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog commandline
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma2/ultra64
LZMAUseSeparateProcess=yes
SolidCompression=yes
OutputDir=Output
OutputBaseFilename=jellymusic-windows-x64-{#MyAppVersion}-setup
SetupIconFile=..\runner\resources\app_icon.ico
LicenseFile=..\..\LICENSE
WizardStyle=modern
ShowLanguageDialog=no
DisableProgramGroupPage=yes
DirExistsWarning=no
CloseApplications=force
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "german"; MessagesFile: "compiler:Languages\German.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; The Flutter Windows release directory: jellymusic.exe + flutter_windows.dll +
; data/ + plugin DLLs. Pull the whole tree.
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; runascurrentuser: if the setup is ever elevated, launch the app as the
; original (non-elevated) user so it reads the right %APPDATA% (token/settings).
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent runascurrentuser
