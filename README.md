# FenSight Installer

This repo hosts the public Windows installer for FenSight.

## Download
Primary download host:
https://downloads.fennok.com/fensight-installer/

Current installer zip:
https://downloads.fennok.com/fensight-installer/FenSight-1.0.0-win-x64-installer.zip

GitHub Releases mirror:
https://github.com/fennok/FenSight-Installer/releases

You will typically see:
- `FenSight-<version>-win-x64-setup.exe` (recommended)
- `FenSight-<version>-win-x64.msi`
- `FenSight-<version>-win-x64-installer.zip` (contains both)

## Install (Windows 10/11)
1) Download the `setup.exe` (recommended) or `.msi`.
2) Run the installer and follow the prompts.
3) Launch FenSight from the Start Menu.

## Verify download (optional)
Each build now emits `.sha256` files alongside `.msi`, `.exe`, and `.zip`.

Manual check example:

`Get-FileHash "C:\path\to\FenSight-1.0.0-win-x64-installer.zip" -Algorithm SHA256`

## Uninstall
Open Windows Settings → Apps → Installed apps → FenSight → Uninstall.

## Notes
- This repo is for distribution only.
- Source code is not hosted here.
