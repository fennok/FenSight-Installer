param(
  [ValidateSet('Debug','Release')]
  [string]$Configuration = 'Release',
  [string]$Runtime = 'win-x64',
  [string]$InstallerVersion = '1.10.0',
  [string]$SourceRepoRoot,
  [string]$LocalAiAssetDir = $env:FENSIGHT_LOCAL_AI_ASSET_DIR,
  [switch]$SkipPublish,
  [switch]$SkipLocalAiModels,
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

function Assert-InstallerBranding {
  param(
    [Parameter(Mandatory = $true)]
    [string]$InstallerRepoRoot
  )

  $requiredFiles = @(
    (Join-Path $InstallerRepoRoot 'FenSight.wxs'),
    (Join-Path $InstallerRepoRoot 'FenSight.Bundle.wxs'),
    (Join-Path $InstallerRepoRoot 'FenSightLicense.rtf'),
    (Join-Path $InstallerRepoRoot 'Assets\FenSightBanner.bmp'),
    (Join-Path $InstallerRepoRoot 'Assets\FenSightDialog.bmp'),
    (Join-Path $InstallerRepoRoot 'Assets\FenSightLogo.png'),
    (Join-Path $InstallerRepoRoot 'Assets\FenSightTheme.xml'),
    (Join-Path $InstallerRepoRoot 'Assets\FenSightTheme.wxl')
  )

  foreach ($requiredFile in $requiredFiles) {
    if (-not (Test-Path $requiredFile)) {
      throw "Missing required installer branding file: $requiredFile"
    }
  }

  $msiWxsPath = Join-Path $InstallerRepoRoot 'FenSight.wxs'
  $msiWxs = Get-Content -Path $msiWxsPath -Raw
  $requiredMsiPatterns = @(
    'WixVariable\s+Id="WixUILicenseRtf"\s+Value="FenSightLicense\.rtf"',
    'WixVariable\s+Id="WixUIBannerBmp"\s+Value="Assets\\FenSightBanner\.bmp"',
    'WixVariable\s+Id="WixUIDialogBmp"\s+Value="Assets\\FenSightDialog\.bmp"',
    '<ui:WixUI\s+Id="WixUI_InstallDir"\s*/>',
    'Id="CleanupFenSightUserData"',
    'Id="CleanupFenSightMachineData"',
    'NOT UPGRADINGPRODUCTCODE'
  )

  foreach ($pattern in $requiredMsiPatterns) {
    if ($msiWxs -notmatch $pattern) {
      throw "FenSight.wxs is missing required branded UI configuration pattern: $pattern"
    }
  }

  $bundleWxsPath = Join-Path $InstallerRepoRoot 'FenSight.Bundle.wxs'
  $bundleWxs = Get-Content -Path $bundleWxsPath -Raw
  if ($bundleWxs -notmatch '<bal:WixStandardBootstrapperApplication') {
    throw "FenSight.Bundle.wxs must use WixStandardBootstrapperApplication for the branded themed installer."
  }
  if ($bundleWxs -notmatch 'LicenseFile\s*=\s*"FenSightLicense\.rtf"') {
    throw "FenSight.Bundle.wxs must embed FenSightLicense.rtf via LicenseFile for the themed bootstrapper."
  }
  if ($bundleWxs -match 'LicenseUrl\s*=') {
    throw "FenSight.Bundle.wxs contains LicenseUrl. External license links are not allowed."
  }
  if ($bundleWxs -notmatch 'MsiPackage[^>]+Visible="no"') {
    throw "FenSight.Bundle.wxs must hide its embedded MSI so Installed Apps exposes one FenSight uninstaller."
  }

  foreach ($variableName in @('PurgeFenSightAppData', 'PurgeFenSightCache', 'PurgeFenSightTemp')) {
    if ($bundleWxs -notmatch ('Variable\s+Name="' + $variableName + '"\s+Value="0"')) {
      throw "FenSight.Bundle.wxs must define the opt-in cleanup variable $variableName with a zero default."
    }
    if ($bundleWxs -notmatch ('MsiProperty\s+Name="PURGEFENSIGHT' +
        ($variableName -replace '^PurgeFenSight', '').ToUpperInvariant() +
        '"\s+Value="\[' + $variableName + '\]"')) {
      throw "FenSight.Bundle.wxs must pass $variableName to the MSI."
    }
  }

  $themePath = Join-Path $InstallerRepoRoot 'Assets\FenSightTheme.xml'
  $theme = Get-Content -Path $themePath -Raw
  foreach ($checkboxName in @('PurgeFenSightAppData', 'PurgeFenSightCache', 'PurgeFenSightTemp')) {
    if ($theme -notmatch ('Checkbox\s+Name="' + $checkboxName + '"')) {
      throw "FenSightTheme.xml is missing the uninstall cleanup checkbox $checkboxName."
    }
  }
  [xml]$themeXml = $theme
  $themeWindow = $themeXml.Theme.Window
  $modifyPage = @($themeWindow.Page) | Where-Object { $_.Name -eq 'Modify' } | Select-Object -First 1
  $safetyLabel = @($modifyPage.Label) |
    Where-Object { $_.'#text' -eq '#(loc.ModifyDataSafetyNote)' } |
    Select-Object -First 1
  if ([int]$themeWindow.Height -lt 340 -or -not $safetyLabel -or [int]$safetyLabel.Height -lt 48) {
    throw "FenSightTheme.xml must reserve the validated accessible height for the uninstall safety notice."
  }

  Write-Host "Verified installer branding, cleanup choices, and upgrade-preservation guards."
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

Assert-InstallerBranding -InstallerRepoRoot $installerRepoRoot

Push-Location $installerRepoRoot
try {
  if (-not $SkipPublish) {
    # Clean Release obj/ so that asset changes (favicon.ico, resources) are always re-embedded.
    Write-Host "Cleaning previous Release output for $Runtime ..."
    dotnet clean $sourceProject -c $Configuration -r $Runtime --verbosity quiet
    if ($LASTEXITCODE -ne 0) {
      throw "FenSight clean failed with exit code $LASTEXITCODE."
    }

    Write-Host "Publishing FenSight to $publishDir ..."
    dotnet publish $sourceProject -c $Configuration -r $Runtime --self-contained true `
      /p:PublishDir="$publishDir" `
      /p:PublishSingleFile=false `
      /p:PublishReadyToRun=true `
      /p:DebugType=None `
      /p:DebugSymbols=false
    if ($LASTEXITCODE -ne 0) {
      throw "FenSight publish failed with exit code $LASTEXITCODE. No installer was built."
    }

    if (-not $SkipLocalAiModels) {
      $stageLocalAiScript = Join-Path $SourceRepoRoot 'tools\Stage-LocalAiModels.ps1'
      if (-not (Test-Path $stageLocalAiScript)) {
        throw "Local AI staging script not found: $stageLocalAiScript"
      }

      Write-Host "Staging Local AI model assets to $publishDir ..."
      $stageArgs = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $stageLocalAiScript,
        '-PublishDir', $publishDir
      )
      if (-not [string]::IsNullOrWhiteSpace($LocalAiAssetDir)) {
        $stageArgs += @('-SourceDir', $LocalAiAssetDir)
      }
      & powershell @stageArgs
      if ($LASTEXITCODE -ne 0) {
        throw "Local AI model staging failed with exit code $LASTEXITCODE."
      }
    }
  } elseif (-not (Test-Path (Join-Path $publishDir 'FenSightApp.exe'))) {
    throw "Signed publish output not found at $publishDir. Run once without -SkipPublish, sign that publish directory, then re-run with -SkipPublish."
  } else {
    Write-Host "Reusing existing publish output at $publishDir (expected to be signed)."
  }

  Write-Host "Building MSI installer..."
  dotnet build "$installerRepoRoot\\FenSight.Installer.wixproj" -c $Configuration `
    /p:PublishDir="$publishDir" `
    /p:SourceRepoRoot="$SourceRepoRoot" `
    /p:InstallerVersion="$InstallerVersion"
  if ($LASTEXITCODE -ne 0) {
    throw "MSI build failed with exit code $LASTEXITCODE."
  }

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
    if ($LASTEXITCODE -ne 0) {
      throw "Bundle build failed with exit code $LASTEXITCODE."
    }

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
