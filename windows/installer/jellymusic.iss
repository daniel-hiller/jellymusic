; Inno Setup script for the JellyMusic Windows installer.
; Built in CI (see .github/workflows/release.yml). Pass the version and the
; Flutter release bundle dir on the command line, e.g.:
;   ISCC /DMyAppVersion=1.2.3 /DBuildDir=<abs path to Release> windows\installer\jellymusic.iss

#define MyAppName "JellyMusic"
#define MyAppPublisher "Daniel Hiller"
#define MyAppURL "https://github.com/daniel-hiller/jellymusic"
#define MyAppExeName "jellymusic.exe"

#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif
#ifndef BuildDir
  #define BuildDir "..\..\build\windows\x64\runner\Release"
#endif

[Setup]
; A stable, unique AppId keeps upgrades in place (do not change once shipped).
AppId={{9F3B2A54-6E1D-4C7A-9E2B-0B7A5C1D8E42}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
DefaultDirName={autopf}\JellyMusic
DefaultGroupName=JellyMusic
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir=Output
OutputBaseFilename=jellymusic-windows-x64-{#MyAppVersion}-setup
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "german"; MessagesFile: "compiler:Languages\German.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\JellyMusic"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\JellyMusic"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,JellyMusic}"; Flags: nowait postinstall skipifsilent
