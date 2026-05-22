[Setup]
AppName=TOTA Study Bible
AppVersion=1.0.0
DefaultDirName={pf}\TOTA Study Bible
DefaultGroupName=TOTA Study Bible
OutputDir=Output
OutputBaseFilename=TOTAStudyBible-Setup
Compression=lzma
SolidCompression=yes

[Files]
Source: "build\windows\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs

[Icons]
Name: "{group}\TOTA Study Bible"; Filename: "{app}\TOTAStudyBible.exe"
Name: "{commondesktop}\TOTA Study Bible"; Filename: "{app}\TOTAStudyBible.exe"