; Per-user installer (no admin rights). Built by tools/package.sh, which passes VERSION and EXE.
Unicode true
!include "MUI2.nsh"

!define NAME "Premiere Ecoute Player"
!define ID "premiere-ecoute-player"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${ID}"

Name "${NAME}"
OutFile "${OUT}"
InstallDir "$LOCALAPPDATA\Programs\${ID}"
InstallDirRegKey HKCU "Software\${ID}" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma

!define MUI_ICON "..\assets\icon.ico"
!define MUI_UNICON "..\assets\icon.ico"
!define MUI_FINISHPAGE_RUN "$INSTDIR\${ID}.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Launch ${NAME}"

!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "French"

VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "${NAME}"
VIAddVersionKey "FileDescription" "${NAME} installer"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "ProductVersion" "${VERSION}"

Section "Install"
  SetOutPath "$INSTDIR"
  File "/oname=${ID}.exe" "${EXE}"
  WriteUninstaller "$INSTDIR\uninstall.exe"
  CreateShortcut "$SMPROGRAMS\${NAME}.lnk" "$INSTDIR\${ID}.exe"
  WriteRegStr HKCU "Software\${ID}" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "${NAME}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\${ID}.exe"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "Premiere Ecoute"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
SectionEnd

Section "Uninstall"
  Delete "$INSTDIR\${ID}.exe"
  Delete "$INSTDIR\uninstall.exe"
  RMDir "$INSTDIR"
  Delete "$SMPROGRAMS\${NAME}.lnk"
  DeleteRegKey HKCU "${UNINSTALL_KEY}"
  DeleteRegKey HKCU "Software\${ID}"
  ; Settings and sign-in (%APPDATA%\premiere-ecoute-player, Credential Manager) are kept on purpose.
SectionEnd
