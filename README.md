# FenSight Installer

This repo hosts the public Windows installer for FenSight.

## Download
Primary download host:
https://downloads.fennok.com/fensight-installer/

Current recommended setup:
https://downloads.fennok.com/fensight-installer/FenSight-1.10.0-win-x64-setup.exe

GitHub Releases mirror:
https://github.com/fennok/FenSight-Installer/releases

You will typically see:
- `FenSight-<version>-win-x64-setup.exe` (recommended)
- `FenSight-<version>-win-x64.msi` (IT/admin deployment)
- `FenSight-<version>-win-x64-installer.zip` (convenience archive containing both)

The setup EXE already embeds the MSI, so ordinary users need only the setup
EXE. The standalone MSI supports managed deployment and `msiexec`. The ZIP is
an archive of both choices, not an additional installer, and is larger because
it contains the application payload twice.

## Install (Windows 10/11)
1) Download the `setup.exe` (recommended) or `.msi`.
2) Run the installer and follow the prompts. The install screen includes a
   "Create a desktop shortcut" option (on by default).
3) When setup finishes, click **Launch** to open FenSight, or start it any time
   from the Start Menu (and the desktop shortcut, if you kept it).

## Verify download (optional)
Each build now emits `.sha256` files alongside `.msi`, `.exe`, and `.zip`.

Manual check example:

`Get-FileHash "C:\path\to\FenSight-1.10.0-win-x64-setup.exe" -Algorithm SHA256`

## Uninstall
Open Windows Settings → Apps → Installed apps → FenSight → Uninstall.

By default, uninstall removes only the FenSight program so reinstalling keeps
your preferences and generated data. The setup uninstaller also offers three
independent, unchecked choices:

- remove settings, licenses, tutorial status, and diagnostics;
- remove generated cache, thumbnails, AI/search indexes, and previews;
- remove known FenSight temporary working and diagnostic files.

Select all three for a fresh reinstall; the FTUE tutorial will appear on the
next launch. Boards, source media, `FenSight Imports`, maintainer signing data,
and unknown files in a custom cache parent are never deleted.

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
