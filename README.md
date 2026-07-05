# FenSight Installer

This repo hosts the public Windows installer for FenSight.

## Download
Primary download host:
https://downloads.fennok.com/fensight-installer/

Current installer zip:
https://downloads.fennok.com/fensight-installer/FenSight-1.7.1-win-x64-installer.zip

GitHub Releases mirror:
https://github.com/fennok/FenSight-Installer/releases

You will typically see:
- `FenSight-<version>-win-x64-setup.exe` (recommended)
- `FenSight-<version>-win-x64.msi`
- `FenSight-<version>-win-x64-installer.zip` (contains both)

## Install (Windows 10/11)
1) Download the `setup.exe` (recommended) or `.msi`.
2) Run the installer and follow the prompts. The install screen includes a
   "Create a desktop shortcut" option (on by default).
3) When setup finishes, click **Launch** to open FenSight, or start it any time
   from the Start Menu (and the desktop shortcut, if you kept it).

## Verify download (optional)
Each build now emits `.sha256` files alongside `.msi`, `.exe`, and `.zip`.

Manual check example:

`Get-FileHash "C:\path\to\FenSight-1.7.1-win-x64-installer.zip" -Algorithm SHA256`

## Uninstall
Open Windows Settings → Apps → Installed apps → FenSight → Uninstall.

Uninstalling removes the FenSight program only. Your boards, settings, and cached
data (thumbnails, AI tags/embeddings, previews) are kept, so reinstalling stays
fast. To reclaim that disk space, open FenSight first and use
**Settings → Clear Thumbnail Cache** and **Clear Index** before uninstalling.

## Maintainer notes
- Installer branding is required. Keep these files in-repo:
  - `Assets/FenSightBanner.bmp`
  - `Assets/FenSightDialog.bmp`
  - `FenSightLicense.rtf`
- `FenSight.wxs` must keep:
  - `WixVariable Id="WixUIBannerBmp" Value="Assets\FenSightBanner.bmp"`
  - `WixVariable Id="WixUIDialogBmp" Value="Assets\FenSightDialog.bmp"`
  - `WixVariable Id="WixUILicenseRtf" Value="FenSightLicense.rtf"`
  - `WixUI_InstallDir` UI flow
  - `ShellExtensionRegistry` component for `.fns` Explorer thumbnail and Preview Pane handlers
- The `.fns` shell handler COM keys must keep the RegAsm-style full assembly name and `InprocServer32\1.0.0.0` subkeys; simplified `mscoree.dll` CLSID entries do not activate reliably.
- The MSI owns the `ShellExtensionRegistry` HKLM entries and removes them on uninstall; local HKCU debug registrations belong in the source repo's dev script, not in shipped installer state.
- `FenSight.Bundle.wxs` must keep `WixInternalUIBootstrapperApplication` (no external `LicenseUrl`).
- `build-installer.ps1` validates these requirements and fails the build if they drift.

## Notes
- This repo is for distribution only.
- Source code is not hosted here.
