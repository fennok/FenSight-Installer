param(
  [Parameter(Mandatory = $true)]
  [string]$InstallerVersion,
  [ValidateSet('Debug','Release')]
  [string]$Configuration = 'Release',
  [string]$Runtime = 'win-x64',
  [string]$SourceRepoRoot,
  [switch]$SkipBundle,
  [switch]$AllowDirty,
  [switch]$NoPush,
  [string]$CommitMessage
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path $PSScriptRoot).Path
$gitDir = Join-Path $repoRoot '.git'
if (-not (Test-Path $gitDir)) {
  throw "Not a git repo: $repoRoot"
}

Push-Location $repoRoot
try {
  if (-not $AllowDirty) {
    $dirty = git status --porcelain
    if ($dirty) {
      throw "Working tree has changes. Commit or stash first, or re-run with -AllowDirty."
    }
  }

  $buildScript = Join-Path $repoRoot 'build-installer.ps1'
  if (-not (Test-Path $buildScript)) {
    throw "build-installer.ps1 not found at $buildScript"
  }

  $buildArgs = @(
    '-InstallerVersion', $InstallerVersion,
    '-Configuration', $Configuration,
    '-Runtime', $Runtime
  )
  if ($SourceRepoRoot) { $buildArgs += @('-SourceRepoRoot', $SourceRepoRoot) }
  if ($SkipBundle) { $buildArgs += '-SkipBundle' }

  & $buildScript @buildArgs

  git add 'artifacts/installer'

  git diff --cached --quiet
  if ($LASTEXITCODE -ne 0) {
    $message = if ($CommitMessage) { $CommitMessage } else { "Release $InstallerVersion" }
    git commit -m $message
  } else {
    Write-Host "No installer changes to commit."
  }

  if (-not $NoPush) {
    git push
  }
}
finally {
  Pop-Location
}
