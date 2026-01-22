# FenSight-Installer (Public)

This repo holds only the installer project and the public release artifacts.
The private source code stays in `F:\Dev\FenSight` and must never be copied here.

## Folder layout
- `F:\Dev\FenSight` (private): full source, tests, internal docs.
- `F:\Dev\FenSight-Installer` (public): installer scripts, WiX projects, release outputs.

## One-time setup (if you are new to Git)
1) Install Git for Windows.
2) Install .NET SDK 9.x.
3) Install WiX Toolset if builds fail (the `.wixproj` files require it).
4) Make sure you can access GitHub (SSH key or HTTPS password/token).

## Build the installer (from the public repo)
The build script publishes the app from the private repo, then builds the MSI/EXE.

Example (explicit source path):
```powershell
cd F:\Dev\FenSight-Installer
.\build-installer.ps1 -SourceRepoRoot F:\Dev\FenSight -InstallerVersion 1.2.3
```

Example (set an environment variable once):
```powershell
$env:FENSIGHT_SOURCE_REPO = 'F:\Dev\FenSight'
cd F:\Dev\FenSight-Installer
.\build-installer.ps1 -InstallerVersion 1.2.3
```

Output artifacts land in:
```
F:\Dev\FenSight-Installer\artifacts\installer\
```

## Release workflow (plain-English)
1) Make code changes in the private repo (`F:\Dev\FenSight`).
2) Build the installer from this repo using `build-installer.ps1`.
3) Verify the MSI/EXE in `artifacts\installer\`.
4) Commit and push only the installer repo (public).
5) Optionally create a GitHub Release and upload the MSI/EXE/ZIP.

## Basic Git commands (short version)
```powershell
git status           # See what changed
git add .            # Stage changes
git commit -m "Message"  # Save changes locally
git push             # Upload to GitHub
```

## Safety rules
- Never copy `F:\Dev\FenSight` source files into this repo.
- Do not commit secrets or local paths.
- Keep only installer scripts and release artifacts here.
