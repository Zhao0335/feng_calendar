[Setup]
AppName=枫枫子的备忘录
AppVersion=1.0.0
AppPublisher=Feng
DefaultDirName={autopf}\枫枫子的备忘录
DefaultGroupName=枫枫子的备忘录
OutputDir=..\..\build
OutputBaseFilename=枫枫子的备忘录-Setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加图标:"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\枫枫子的备忘录"; Filename: "{app}\feng_calendar.exe"
Name: "{userdesktop}\枫枫子的备忘录"; Filename: "{app}\feng_calendar.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\feng_calendar.exe"; Description: "立即启动"; Flags: nowait postinstall skipifsilent
