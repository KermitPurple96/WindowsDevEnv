<#
.SYNOPSIS
  One-shot setup for a Neovim + Neovide C/C++ dev environment on Windows.

.DESCRIPTION
  Installs the toolchain (Neovim, LLVM/clang, Git, VS Build Tools) via winget,
  installs the JetBrainsMono Nerd Font, deploys the Neovim/Neovide configs from
  this repo, and bootstraps all plugins. Safe to re-run (idempotent).

.NOTES
  Run from this repo's folder:   powershell -ExecutionPolicy Bypass -File .\install.ps1
  No admin rights required (per-user installs and per-user font install).
#>

[CmdletBinding()]
param(
  [switch]$SkipBuildTools,   # skip the large VS Build Tools download
  [switch]$SkipFont,         # skip Nerd Font install
  [switch]$SkipSync          # skip the headless plugin bootstrap
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Info($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "  OK $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  !! $m" -ForegroundColor Yellow }

# --- 0. Prerequisite: winget ------------------------------------------------
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  throw "winget not found. Install 'App Installer' from the Microsoft Store, then re-run."
}

# --- 1. Toolchain via winget ------------------------------------------------
function Install-Winget($id, $extra) {
  Info "Installing $id"
  $args = @("install", "--id", $id, "-e", "--source", "winget",
            "--accept-source-agreements", "--accept-package-agreements",
            "--silent", "--disable-interactivity")
  if ($extra) { $args += $extra }
  winget @args
  # winget exit codes: 0 = installed, -1978335189 (0x8A15002B) = already installed / no upgrade
  if ($LASTEXITCODE -eq 0) { Ok "$id installed" }
  elseif ($LASTEXITCODE -eq -1978335189 -or $LASTEXITCODE -eq -1978335212) { Ok "$id already present" }
  else { Warn "$id winget exit code $LASTEXITCODE (continuing)" }
}

Install-Winget "Neovim.Neovim"
Install-Winget "LLVM.LLVM"
Install-Winget "Git.Git"
if (-not $SkipBuildTools) {
  # VCTools workload = the actual MSVC C++ compiler/headers (big download).
  Install-Winget "Microsoft.VisualStudio.2022.BuildTools" @(
    "--override",
    "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
  )
} else {
  Warn "Skipping VS Build Tools (-SkipBuildTools)"
}

# --- 2. Ensure LLVM is on the user PATH -------------------------------------
$llvm = "C:\Program Files\LLVM\bin"
if (Test-Path $llvm) {
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  if ($userPath -notlike "*$llvm*") {
    [Environment]::SetEnvironmentVariable("Path", ($userPath.TrimEnd(';') + ";" + $llvm), "User")
    Ok "Added LLVM to user PATH (restart terminals to pick it up)"
  } else { Ok "LLVM already on PATH" }
  # Make tools available to THIS session for the sync step below
  $env:Path = "$llvm;C:\Program Files\Git\cmd;" + $env:Path
}

# --- 3. JetBrainsMono Nerd Font (per-user, no admin) ------------------------
if (-not $SkipFont) {
  Info "Installing JetBrainsMono Nerd Font"
  $already = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Fonts" -Filter "JetBrainsMonoNerdFont*" -ErrorAction SilentlyContinue
  if ($already) {
    Ok "Nerd Font already installed"
  } else {
    $tmp = Join-Path $env:TEMP "jbmono-nf"
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $zip = Join-Path $tmp "JetBrainsMono.zip"
    $url = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip"
    Invoke-WebRequest -Uri $url -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath "$tmp\extracted" -Force
    $fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
    New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
    $regPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    $n = 0
    Get-ChildItem "$tmp\extracted" -Filter "*.ttf" | ForEach-Object {
      $dest = Join-Path $fontDir $_.Name
      Copy-Item $_.FullName $dest -Force
      New-ItemProperty -Path $regPath -Name ($_.BaseName + " (TrueType)") -Value $dest -PropertyType String -Force | Out-Null
      $n++
    }
    Ok "Installed $n Nerd Font files"
  }
} else {
  Warn "Skipping font (-SkipFont)"
}

# --- 4. Deploy configs ------------------------------------------------------
function Deploy($src, $dstDir, $backup) {
  if ($backup -and (Test-Path $dstDir)) {
    $bak = "$dstDir.bak"
    if (Test-Path $bak) { Remove-Item $bak -Recurse -Force }
    Rename-Item $dstDir $bak
    Warn "Backed up existing $dstDir -> $bak"
  }
  New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
  robocopy $src $dstDir /E /NFL /NDL /NJH /NJS /NP | Out-Null
}

Info "Deploying Neovim config -> $env:LOCALAPPDATA\nvim"
Deploy "$RepoRoot\nvim" "$env:LOCALAPPDATA\nvim" $true
Ok "nvim config deployed"

Info "Deploying Neovide config -> $env:APPDATA\neovide"
New-Item -ItemType Directory -Force -Path "$env:APPDATA\neovide" | Out-Null
Copy-Item "$RepoRoot\neovide\config.toml" "$env:APPDATA\neovide\config.toml" -Force
Ok "neovide config deployed"

Info "Deploying .clang-format -> $env:USERPROFILE"
Copy-Item "$RepoRoot\.clang-format" "$env:USERPROFILE\.clang-format" -Force
Ok ".clang-format deployed"

# --- 5. Bootstrap plugins (headless) ----------------------------------------
if (-not $SkipSync) {
  Info "Bootstrapping plugins (this can take a couple of minutes)..."
  $nvim = "C:\Program Files\Neovim\bin\nvim.exe"
  if (Test-Path $nvim) {
    & $nvim --headless "+Lazy! sync" +qa
    Ok "Plugins installed"
  } else {
    Warn "nvim.exe not found yet — open a NEW terminal and run 'neovide' to finish plugin install"
  }
} else {
  Warn "Skipping plugin sync (-SkipSync)"
}

Write-Host ""
Write-Host "Done! Launch with:  neovide" -ForegroundColor Green
Write-Host "First launch finishes any remaining plugin/LSP setup automatically." -ForegroundColor Green
