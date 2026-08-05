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
    ; A matching uninstall string alone can be stale. Require the running kernel
    ; service, its signed pinned-version image, and a successful feeder API probe.
    nsExec::ExecToStack 'powershell.exe -NoProfile -NonInteractive -Command "$$d=Get-CimInstance Win32_SystemDriver -Filter $\"Name='vjoy'$\" -ErrorAction SilentlyContinue; if (-not $$d -or $$d.State -ne $\"Running$\") { exit 1 }; $$p=$$d.PathName.Trim($\"`\"$\"); if (-not (Test-Path -LiteralPath $$p)) { exit 1 }; $$f=(Get-Item -LiteralPath $$p).VersionInfo.FileVersion; $$s=Get-AuthenticodeSignature -LiteralPath $$p; if ($$f -notlike $\"2.2.2.0*$\" -or $$s.Status -ne $\"Valid$\") { exit 1 }; $$r=& $\"$INSTDIR\resources\vJoyConfig.exe$\" -t -c 2>$$null; $$t=$$r -join $\" $\"; if ($$LASTEXITCODE -ne 0 -or $$t -notmatch $\"Product ID:$\" -or $$t -match $\"not installed|disabled|Failed$\") { exit 1 }; exit 0"'
    Pop $5
    Pop $6
    ${If} $5 == 0
      DetailPrint "Verified running signed vJoy ${VJOY_VERSION} driver and feeder API; preserving ownership."
      ${If} $3 != 1
        WriteRegDWORD HKLM "${TRENINO_REGISTRY_KEY}" "VJoyInstalledByTrenino" 0
      ${EndIf}
    ${Else}
      Abort "A stale or incompatible vJoy ${VJOY_VERSION} installation was detected. Repair or remove vJoy, then run Trenino setup again. No driver changes were made."
    ${EndIf}
  ${Else}
    ; A service without the exact 64-bit uninstall entry may be an alternate-view
    ; or manually installed shared driver. Never replace or claim it unless a
    ; prior Trenino ownership marker proves this is our upgrade.
    ReadRegStr $4 HKLM "SYSTEM\CurrentControlSet\Services\vjoy" "ImagePath"
    ${If} $4 != ""
    ${AndIf} $3 != 1
      Abort "An existing vJoy driver could not be verified as the supported signed version. Repair or remove it, then run Trenino setup again. No driver changes were made."
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
    ; Exit 0 means a healthy API probe and all 16 statuses explicitly MISSING.
    ; Exit 1 means devices exist. Exit 2 means disabled/missing/error: retain.
    nsExec::ExecToStack 'powershell.exe -NoProfile -NonInteractive -Command "$$r=& $\"$INSTDIR\resources\vJoyConfig.exe$\" -t -c 2>$$null; $$t=$$r -join $\" $\"; if ($$LASTEXITCODE -ne 0 -or $$t -notmatch $\"Product ID:$\" -or $$t -match $\"not installed|disabled|Failed$\") { exit 2 }; $$missing=([regex]::Matches($$t,$\"Status:\s+MISSING$\")).Count; if ($$missing -eq 16) { exit 0 } else { exit 1 }"'
    Pop $1
    Pop $2
    ${If} $1 == 0
      ; Device absence cannot prove that no other application depends on vJoy.
      ; Silent uninstall always retains it; interactive removal defaults to No.
      IfSilent vjoy_retain_silent
      MessageBox MB_YESNO|MB_DEFBUTTON2|MB_ICONQUESTION "Trenino installed the vJoy driver and no configured devices remain. Other applications may still depend on it. Remove the shared vJoy driver?" IDYES vjoy_remove_confirmed
      Goto vjoy_retain_choice
      vjoy_retain_silent:
        DetailPrint "Silent uninstall: retaining vJoy because exclusive dependency ownership cannot be proven."
        Goto vjoy_driver_cleanup_done
      vjoy_retain_choice:
        DetailPrint "User chose to retain the potentially shared vJoy driver."
        Goto vjoy_driver_cleanup_done
      vjoy_remove_confirmed:
        ReadRegStr $2 HKLM "${VJOY_UNINSTALL_KEY}" "QuietUninstallString"
        ${If} $2 == ""
          ReadRegStr $2 HKLM "${VJOY_UNINSTALL_KEY}" "UninstallString"
        ${EndIf}
        ${If} $2 != ""
          DetailPrint "User explicitly chose to remove the Trenino-installed vJoy driver."
          ExecWait '$2 /VERYSILENT /NORESTART /SUPPRESSMSGBOXES' $3
          DetailPrint "vJoy uninstaller exited with code $3."
        ${Else}
          DetailPrint "Registered vJoy uninstaller is missing; retaining the driver."
        ${EndIf}
    ${Else}
      ${If} $1 == 1
        DetailPrint "One or more vJoy devices exist; retaining the shared driver."
      ${Else}
        DetailPrint "vJoy API/device enumeration was not known-good; retaining the driver."
      ${EndIf}
    ${EndIf}
  ${Else}
    DetailPrint "vJoy was not installed by Trenino; retaining the shared driver."
  ${EndIf}

  vjoy_driver_cleanup_done:
  DeleteRegValue HKLM "${TRENINO_REGISTRY_KEY}" "VJoyInstalledByTrenino"
  DeleteRegKey /ifempty HKLM "${TRENINO_REGISTRY_KEY}"
  DeleteRegKey /ifempty HKCU "${TRENINO_REGISTRY_KEY}"
!macroend
