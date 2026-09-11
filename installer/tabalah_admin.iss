; ─────────────────────────────────────────────
;  Tabalah Admin — Windows installer
;
;  Build:  ISCC.exe installer\tabalah_admin.iss
;  Expects: flutter build windows --release  (already run)
;
;  Also used by the in-app updater, which runs this silently:
;    TabalahAdmin-Setup-x.y.z.exe /SILENT /NOCANCEL /RESTARTAPPLICATIONS
;  Everything below has to work unattended for that to hold.
; ─────────────────────────────────────────────

#define AppName        "Tabalah Admin"
#define AppNameAr      "لوحة تحكم أكاديمية تبالة"
#define AppPublisher   "Tabalah Academy"
#define AppURL         "https://tabalahacademy.com/"
#define AppExe         "TabalahAdmin.exe"
#define SourceDir      "..\build\windows\x64\runner\Release"

; Passed in by build_installer.ps1 so the version always matches pubspec
; rather than being a second place to remember to bump.
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
; Never change AppId: it is how Windows and the updater recognise an
; existing install and upgrade it in place instead of stacking copies.
AppId={{7C4F1E2A-9B3D-4A16-8E5C-TABALAH0001}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
VersionInfoVersion={#AppVersion}
VersionInfoCompany={#AppPublisher}
VersionInfoProductName={#AppName}

DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
DisableDirPage=auto

; Per-user install: staff machines are often not administrator accounts,
; and requiring elevation would make the silent auto-update fail with a UAC
; prompt nobody is there to accept.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

OutputDir=..\dist
OutputBaseFilename=TabalahAdmin-Setup-{#AppVersion}
SetupIconFile=..\assets\images\logo.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}

Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

; The panel is Arabic-first, so the wizard should be too when available.
ShowLanguageDialog=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"

[Files]
; The whole Release folder: the exe alone does not run - it needs the
; plugin DLLs, flutter_windows.dll and the data\ payload beside it.
Source: "{#SourceDir}\{#AppExe}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\*.dll";     DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\data\*";    DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}";           Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}";     Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
; skipifsilent so the auto-update path does not relaunch behind the user's
; back - RESTARTAPPLICATIONS already handles that case.
Filename: "{app}\{#AppExe}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Flutter writes its cache beside the exe; leaving it behind makes a
; reinstall inherit state from a version that no longer exists.
Type: filesandordirs; Name: "{app}\data"
