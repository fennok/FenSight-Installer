param(
  [ValidateSet('Debug','Release')]
  [string]$Configuration = 'Release',
  [string]$Runtime = 'win-x64',
  [string]$InstallerVersion = '1.0.0',
  [string]$SourceRepoRoot,
  [switch]$SkipBundle,
  [string]$PublicBaseUrl = 'https://downloads.fennok.com/fensight-installer'
)

$ErrorActionPreference = 'Stop'

$installerRepoRoot = (Resolve-Path $PSScriptRoot).Path

function Write-Sha256Sidecar {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  if (-not (Test-Path $Path)) {
    throw "Cannot hash missing file: $Path"
  }

  $hash = Get-FileHash -Path $Path -Algorithm SHA256
  $leaf = Split-Path -Leaf $Path
  $sidecar = "$Path.sha256"
  $line = "{0}  {1}" -f $hash.Hash.ToLowerInvariant(), $leaf
  Set-Content -Path $sidecar -Value $line -NoNewline -Encoding ascii
  Write-Host "SHA256 ${leaf}: $($hash.Hash)"
  Write-Host "Wrote hash: $sidecar"
  return @{
    Hash = $hash.Hash
    Sidecar = $sidecar
  }
}

if (-not $SourceRepoRoot) {
  if ($env:FENSIGHT_SOURCE_REPO) {
    $SourceRepoRoot = $env:FENSIGHT_SOURCE_REPO
  }
}

if (-not $SourceRepoRoot) {
  $defaultSource = Join-Path $installerRepoRoot '..\\FenSight'
  if (Test-Path $defaultSource) {
    $SourceRepoRoot = (Resolve-Path $defaultSource).Path
  }
}

if (-not $SourceRepoRoot) {
  throw "Source repo not found. Pass -SourceRepoRoot or set FENSIGHT_SOURCE_REPO."
}

$SourceRepoRoot = (Resolve-Path $SourceRepoRoot).Path
$sourceProject = Join-Path $SourceRepoRoot 'FenSight.csproj'
if (-not (Test-Path $sourceProject)) {
  throw "FenSight.csproj not found at $sourceProject"
}

$publishDir = Join-Path $installerRepoRoot "artifacts\\publish\\$Runtime\\"
$installerOutDir = Join-Path $installerRepoRoot "artifacts\\installer\\"

New-Item -ItemType Directory -Force -Path $publishDir | Out-Null
New-Item -ItemType Directory -Force -Path $installerOutDir | Out-Null

Push-Location $installerRepoRoot
try {
  Write-Host "Publishing FenSight to $publishDir ..."
  dotnet publish $sourceProject -c $Configuration -r $Runtime --self-contained true `
    /p:PublishDir="$publishDir" `
    /p:PublishSingleFile=false `
    /p:PublishReadyToRun=true `
    /p:DebugType=None `
    /p:DebugSymbols=false

  Write-Host "Building MSI installer..."
  dotnet build "$installerRepoRoot\\FenSight.Installer.wixproj" -c $Configuration `
    /p:PublishDir="$publishDir" `
    /p:SourceRepoRoot="$SourceRepoRoot" `
    /p:InstallerVersion="$InstallerVersion"

  $msi = Get-ChildItem -Path $installerOutDir -Filter "FenSight.msi" -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $msi) { throw "MSI not found in $installerOutDir" }
  $finalName = "FenSight-$InstallerVersion-$Runtime.msi"
  $finalPath = Join-Path $installerOutDir $finalName
  Copy-Item -Force $msi.FullName $finalPath
  Write-Host "Created installer: $finalPath"

  if (-not $SkipBundle) {
    Write-Host "Building EXE bundle installer..."
    dotnet build "$installerRepoRoot\\FenSight.Bundle.wixproj" -c $Configuration `
      /p:MsiPath="$($msi.FullName)" `
      /p:SourceRepoRoot="$SourceRepoRoot" `
      /p:InstallerVersion="$InstallerVersion"

    $bundleExe = Get-ChildItem -Path $installerOutDir -Filter "FenSightSetup.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $bundleExe) { throw "Bundle EXE not found in $installerOutDir" }
    $finalBundleName = "FenSight-$InstallerVersion-$Runtime-setup.exe"
    $finalBundlePath = Join-Path $installerOutDir $finalBundleName
    Copy-Item -Force $bundleExe.FullName $finalBundlePath
    Write-Host "Created bundle: $finalBundlePath"
  }

  $zipItems = @($finalPath)
  if ($finalBundlePath) {
    $zipItems += $finalBundlePath
  }
  $zipName = "FenSight-$InstallerVersion-$Runtime-installer.zip"
  $zipPath = Join-Path $installerOutDir $zipName
  if (Test-Path $zipPath) {
    Remove-Item -Force $zipPath
  }
  Compress-Archive -Path $zipItems -DestinationPath $zipPath
  Write-Host "Created zip: $zipPath"

  $msiHash = Write-Sha256Sidecar -Path $finalPath
  $exeHash = $null
  if ($finalBundlePath) {
    $exeHash = Write-Sha256Sidecar -Path $finalBundlePath
  }
  $zipHash = Write-Sha256Sidecar -Path $zipPath

  $publicBase = ''
  if ($null -ne $PublicBaseUrl) {
    $publicBase = $PublicBaseUrl.Trim().TrimEnd('/')
  }
  if ($publicBase) {
    $msiLeaf = Split-Path -Leaf $finalPath
    Write-Host "Public MSI URL: $publicBase/$msiLeaf"
    Write-Host "Public MSI SHA256 URL: $publicBase/$msiLeaf.sha256"
    if ($finalBundlePath) {
      $exeLeaf = Split-Path -Leaf $finalBundlePath
      Write-Host "Public EXE URL: $publicBase/$exeLeaf"
      Write-Host "Public EXE SHA256 URL: $publicBase/$exeLeaf.sha256"
    }
    $zipLeaf = Split-Path -Leaf $zipPath
    Write-Host "Public ZIP URL: $publicBase/$zipLeaf"
    Write-Host "Public ZIP SHA256 URL: $publicBase/$zipLeaf.sha256"
  }
}
finally {
  Pop-Location
}
