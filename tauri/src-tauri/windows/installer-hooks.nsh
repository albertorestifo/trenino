; Install the Microsoft Visual C++ Redistributable if not already present.
; The vc_redist.x64.exe is bundled as a resource and installed silently
; during app installation to prevent MSVCP140.dll / VCRUNTIME140.dll errors
; on systems that don't have it pre-installed.

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
!macroend
