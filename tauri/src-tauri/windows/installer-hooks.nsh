; Install the Microsoft Visual C++ Redistributable if not already present.
; The vc_redist.x64.exe is bundled as a resource and installed silently
; during app installation to prevent MSVCP140.dll / VCRUNTIME140.dll errors
; on systems that don't have it pre-installed.

!define VJOY_VERSION "2.2.2.0"
!define VJOY_UNINSTALL_KEY "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{8E31F76F-74C3-47F1-9550-E041EEDC5FBB}_is1"
!define TRENINO_REGISTRY_KEY "SOFTWARE\Trenino"

!macro NSIS_HOOK_POSTINSTALL
  ; Check if VC++ Redistributable is already installed via registry
  ReadRegStr $0 HKLM "SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64" "Installed"
  ${If} $0 != "1"
    DetailPrint "Installing Visual C++ Redistributable..."
    ExecWait '"$INSTDIR\resources\vc_redist.x64.exe" /install /quiet /norestart' $1
    DetailPrint "Visual C++ Redistributable installer exited with code $1"
  ${Else}
    DetailPrint "Visual C++ Redistributable already installed, skipping."
  ${EndIf}

  ; Clean up the installer from resources — it's not needed at runtime
  Delete "$INSTDIR\resources\vc_redist.x64.exe"

  ; Preserve compatible pre-existing vJoy installations as shared system state.
  ReadRegStr $0 HKLM "${VJOY_UNINSTALL_KEY}" "DisplayVersion"
  ${If} $0 == "${VJOY_VERSION}"
    DetailPrint "Compatible vJoy ${VJOY_VERSION} is already installed; preserving shared ownership."
    WriteRegDWORD HKLM "${TRENINO_REGISTRY_KEY}" "VJoyInstalledByTrenino" 0
  ${Else}
    DetailPrint "Installing pinned signed vJoy ${VJOY_VERSION} runtime..."
    ExecWait '"$INSTDIR\resources\vJoySetup.exe" /VERYSILENT /NORESTART /SUPPRESSMSGBOXES' $1
    ${If} $1 == 0
      WriteRegDWORD HKLM "${TRENINO_REGISTRY_KEY}" "VJoyInstalledByTrenino" 1
      DetailPrint "Trenino installed vJoy ${VJOY_VERSION}; ownership marker recorded."

      ; vJoy setup may create its default device. Trenino's virtual joystick
      ; mode is initially off, so remove only the default created by this
      ; installation. Never alter a compatible pre-existing installation.
      ExecWait '"$INSTDIR\resources\vJoyConfig.exe" -d 1' $2
      DetailPrint "Cleared installer-created vJoy default device 1 (exit code $2)."
    ${Else}
      DetailPrint "vJoy installer exited with code $1; ownership was not claimed."
      Abort "The signed vJoy driver could not be installed (exit code $1)."
    ${EndIf}
  ${EndIf}

  ; The installer is privileged setup payload, never a runtime executable.
  Delete "$INSTDIR\resources\vJoySetup.exe"
!macroend

!macro NSIS_HOOK_PREUNINSTALL
  ; Delete device 1 only when its complete capability report matches Trenino's
  ; fixed descriptor: exactly X/Y/Z/Rx/Ry/Rz/Sl0/Sl1, 32 buttons and no POV/FFB.
  ; The comparison is normalized by PowerShell before checking the literal line.
  nsExec::ExecToStack 'powershell.exe -NoProfile -NonInteractive -Command "$$r=& $\"$INSTDIR\resources\vJoyConfig.exe$\" -t 1 -c 2>$$null; $$n=($$r -join $\" $\" -replace $\"\s+$\",$\" $\" ).Trim(); if ($$n -eq $\"vJoyConfig 1 -f -a X Y Z Rx Ry Rz Sl0 Sl1 -b 32$\") { exit 0 } else { exit 1 }"'
  Pop $0
  Pop $1
  ${If} $0 == 0
    DetailPrint "Device 1 matches Trenino's descriptor; removing it."
    ExecWait '"$INSTDIR\resources\vJoyConfig.exe" -d 1' $2
  ${Else}
    DetailPrint "Device 1 is absent or does not match Trenino's descriptor; leaving shared device state unchanged."
  ${EndIf}

  ReadRegDWORD $0 HKLM "${TRENINO_REGISTRY_KEY}" "VJoyInstalledByTrenino"
  ${If} $0 == 1
    ; Any report for devices 2..16 means vJoy is shared and must remain installed.
    nsExec::ExecToStack 'powershell.exe -NoProfile -NonInteractive -Command "$$r=& $\"$INSTDIR\resources\vJoyConfig.exe$\" -t 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 -c 2>$$null; if (($$r -join $\" $\" ) -match $\"vJoyConfig$\") { exit 1 } else { exit 0 }"'
    Pop $1
    Pop $2
    ${If} $1 == 0
      ReadRegStr $2 HKLM "${VJOY_UNINSTALL_KEY}" "QuietUninstallString"
      ${If} $2 == ""
        ReadRegStr $2 HKLM "${VJOY_UNINSTALL_KEY}" "UninstallString"
      ${EndIf}
      ${If} $2 != ""
        DetailPrint "No shared vJoy devices remain; removing the Trenino-owned driver."
        ExecWait '$2 /VERYSILENT /NORESTART /SUPPRESSMSGBOXES' $3
        DetailPrint "vJoy uninstaller exited with code $3."
      ${Else}
        DetailPrint "Trenino owns vJoy but its registered uninstaller is missing; leaving the driver installed."
      ${EndIf}
    ${Else}
      DetailPrint "Other vJoy devices exist; retaining the shared driver."
    ${EndIf}
  ${Else}
    DetailPrint "vJoy was not installed by Trenino; retaining the shared driver."
  ${EndIf}

  DeleteRegValue HKLM "${TRENINO_REGISTRY_KEY}" "VJoyInstalledByTrenino"
  DeleteRegKey /ifempty HKLM "${TRENINO_REGISTRY_KEY}"
!macroend
