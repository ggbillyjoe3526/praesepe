; Windows installer for Project Praesepe (Inno Setup 6), from the owner's katanashotgun and Airsoft-Next projects.
; Built by .github/workflows/release.yml (RELEASING.md), with the forms tools/version.sh gives:
;   ISCC.exe "/DAppVersion=0.1 Dev 1" /DAppTag=v0.1-dev.1 /DAppNumber=0.1.1.1 installer\ProjectPraesepe.iss
; AppVersion is the name players see; AppTag goes in the file name; AppNumber is the four-number version Windows needs
; in the setup exe's properties. It packs what the workflow's export job leaves in build/: the game exe (with the icon
; and version stamped in) and, from tools/make_icon.gd and tools/make_notices.gd, the icon and the licence notices.
; It installs for the current player only, so Windows never asks for an administrator. Saves live in
; %APPDATA%\ProjectPraesepe, never in the install folder, so updating or uninstalling never touches progress.

#ifndef AppVersion
  #define AppVersion "0.0"
#endif
#ifndef AppTag
  #define AppTag "v0.0"
#endif
#ifndef AppNumber
  #define AppNumber "0.0.0.0"
#endif
#ifndef AppPublisher
  #define AppPublisher "ggbillyjoe3526"
#endif

[Setup]
; AppId identifies the game for updates and uninstalling. NEVER change it.
AppId={{A1835353-01FC-4993-8CFA-F1AAFC73AE9E}
AppName=Project Praesepe
AppVerName=Project Praesepe {#AppVersion}
AppVersion={#AppVersion}
VersionInfoVersion={#AppNumber}
VersionInfoProductVersion={#AppNumber}
VersionInfoTextVersion={#AppVersion}
VersionInfoProductTextVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://github.com/ggbillyjoe3526/project-praesepe
AppSupportURL=https://github.com/ggbillyjoe3526/project-praesepe/issues
AppUpdatesURL=https://github.com/ggbillyjoe3526/project-praesepe/releases
DefaultDirName={autopf}\Project Praesepe
DefaultGroupName=Project Praesepe
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline
OutputDir=..\dist
OutputBaseFilename=ProjectPraesepe-{#AppTag}-Windows-Setup
SetupIconFile=..\build\release\icon.ico
UninstallDisplayIcon={app}\ProjectPraesepe.exe
UninstallDisplayName=Project Praesepe
Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\ProjectPraesepe.exe"; DestDir: "{app}"; Flags: ignoreversion
; Licences for the engine and everything third-party, shipped next to the game.
Source: "..\build\release\THIRD_PARTY_NOTICES.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Project Praesepe"; Filename: "{app}\ProjectPraesepe.exe"
Name: "{group}\Uninstall Project Praesepe"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Project Praesepe"; Filename: "{app}\ProjectPraesepe.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\ProjectPraesepe.exe"; Description: "{cm:LaunchProgram,Project Praesepe}"; Flags: nowait postinstall skipifsilent
