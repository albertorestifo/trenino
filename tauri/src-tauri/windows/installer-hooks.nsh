; Install the Microsoft Visual C++ Redistributable if not already present.
; The vc_redist.x64.exe is bundled as a resource and installed silently
; during app installation to prevent MSVCP140.dll / VCRUNTIME140.dll errors
; on systems that don't have it pre-installed.

!define VJOY_VERSION "2.2.2.0"
!define VJOY_UNINSTALL_KEY "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{8E31F76F-74C3-47F1-9550-E041EEDC5FBB}_is1"
!define TRENINO_REGISTRY_KEY "SOFTWARE\Trenino"
!define VJOY_DEVICE_MARKER "VJoyDevice1CreatedByTrenino"

!macro NSIS_HOOK_POSTINSTALL
  SetRegView 64
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
  ReadRegDWORD $3 HKLM "${TRENINO_REGISTRY_KEY}" "VJoyInstalledByTrenino"
  ReadRegStr $0 HKLM "${VJOY_UNINSTALL_KEY}" "DisplayVersion"
  ${If} $0 == "${VJOY_VERSION}"
    DetailPrint "Compatible vJoy ${VJOY_VERSION} is already installed; preserving shared ownership."
    ${If} $3 != 1
      WriteRegDWORD HKLM "${TRENINO_REGISTRY_KEY}" "VJoyInstalledByTrenino" 0
    ${EndIf}
  ${Else}
    ; A service without the exact 64-bit uninstall entry may be an alternate-view
    ; or manually installed shared driver. Never replace or claim it unless a
    ; prior Trenino ownership marker proves this is our upgrade.
    ReadRegStr $4 HKLM "SYSTEM\CurrentControlSet\Services\vjoy" "ImagePath"
    ${If} $4 != ""
    ${AndIf} $3 != 1
      DetailPrint "A non-matching vJoy driver service already exists; preserving it as shared state."
      WriteRegDWORD HKLM "${TRENINO_REGISTRY_KEY}" "VJoyInstalledByTrenino" 0
    ${Else}
      DetailPrint "Installing pinned signed vJoy ${VJOY_VERSION} runtime..."
      nsExec::ExecToStack 'powershell.exe -NoProfile -NonInteractive -Command "if ((Get-AuthenticodeSignature -LiteralPath $\"$INSTDIR\resources\vJoySetup.exe$\").Status -eq $\"Valid$\") { exit 0 } else { exit 1 }"'
      Pop $5
      Pop $6
      ${If} $5 != 0
        Abort "The bundled vJoy driver signature is not valid."
      ${EndIf}

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
  ${EndIf}

  ; The installer is privileged setup payload, never a runtime executable.
  Delete "$INSTDIR\resources\vJoySetup.exe"
!macroend

!macro NSIS_HOOK_PREUNINSTALL
  SetRegView 64
  ; Delete device 1 only when its complete capability report matches Trenino's
  ; fixed descriptor: exactly X/Y/Z/Rx/Ry/Rz/Sl0/Sl1, 32 buttons and no POV/FFB.
  ; The comparison is normalized by PowerShell before checking the literal line.
  ReadRegDWORD $4 HKCU "${TRENINO_REGISTRY_KEY}" "${VJOY_DEVICE_MARKER}"
  ${If} $4 == 1
    nsExec::ExecToStack 'powershell.exe -NoProfile -NonInteractive -Command "$$r=& $\"$INSTDIR\resources\vJoyConfig.exe$\" -t 1 -c 2>$$null; $$n=($$r -join $\" $\" -replace $\"\s+$\",$\" $\" ).Trim(); if ($$n -eq $\"vJoyConfig 1 -f -a X Y Z Rx Ry Rz Sl0 Sl1 -b 32$\") { exit 0 } else { exit 1 }"'
    Pop $0
    Pop $1
    ${If} $0 == 0
      DetailPrint "Owned device 1 matches Trenino's descriptor; removing it."
      ExecWait '"$INSTDIR\resources\vJoyConfig.exe" -d 1' $2
      ${If} $2 == 0
        DeleteRegValue HKCU "${TRENINO_REGISTRY_KEY}" "${VJOY_DEVICE_MARKER}"
      ${EndIf}
    ${Else}
      DetailPrint "Owned device marker exists but descriptor differs or is absent; leaving device state unchanged."
    ${EndIf}
  ${Else}
    DetailPrint "No Trenino device ownership marker; device 1 will not be removed."
  ${EndIf}

  ReadRegDWORD $0 HKLM "${TRENINO_REGISTRY_KEY}" "VJoyInstalledByTrenino"
  ${If} $0 == 1
    ReadRegStr $4 HKLM "${VJOY_UNINSTALL_KEY}" "DisplayVersion"
    ${If} $4 != "${VJOY_VERSION}"
      DetailPrint "Owned-driver marker exists but exact vJoy version is unverified; retaining driver."
      Goto vjoy_driver_cleanup_done
    ${EndIf}
    ; Any remaining report for devices 1..16 means vJoy is shared (or device 1
    ; removal failed), so the driver must remain installed.
    nsExec::ExecToStack 'powershell.exe -NoProfile -NonInteractive -Command "$$r=& $\"$INSTDIR\resources\vJoyConfig.exe$\" -t 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 -c 2>$$null; if (($$r -join $\" $\" ) -match $\"vJoyConfig$\") { exit 1 } else { exit 0 }"'
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

  vjoy_driver_cleanup_done:
  DeleteRegValue HKLM "${TRENINO_REGISTRY_KEY}" "VJoyInstalledByTrenino"
  DeleteRegKey /ifempty HKLM "${TRENINO_REGISTRY_KEY}"
  DeleteRegKey /ifempty HKCU "${TRENINO_REGISTRY_KEY}"
!macroend
