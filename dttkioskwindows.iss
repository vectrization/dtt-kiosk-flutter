; -- MyFlutterApp.iss --
[Setup]
AppName=dttkiosk
AppVersion=1.0
DefaultDirName={pf}\DttKiosk
DefaultGroupName=DttKiosk
OutputBaseFilename=DttKioskInstaller
Compression=lzma
SolidCompression=yes

[Files]
; Copy everything from your Release folder
Source: "C:\Users\seonryu\Desktop\Projects\ITE\DTT-KIOSK\kiosk-flutter\build\windows\x64\runner\Release*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\DttKiosk"; Filename: "{app}\kiosk.exe"

[Run]
Filename: "{app}\kiosk.exe"; Description: "Launch kiosk"; Flags: nowait postinstall skipifsilent