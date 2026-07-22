<#
.SYNOPSIS
  One-shot setup for a Neovim + Neovide C/C++ dev environment on Windows.

.DESCRIPTION
  Installs the toolchain (Neovim, LLVM/clang, Git, Node LTS, VS Build Tools,
  Claude Code) via winget, installs the JetBrainsMono and Hack Nerd Fonts,
  deploys the Neovim/Neovide configs from this repo, and bootstraps all
  plugins. Safe to re-run (idempotent).

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
Install-Winget "OpenJS.NodeJS.LTS"  # runtime for HTML/CSS/JS/TS/JSON/YAML language servers
Install-Winget "Anthropic.ClaudeCode"
# Telescope's live_grep (<leader>fg) shells out to ripgrep and fails without it;
# conform.nvim's Lua formatter is stylua. fd just makes find_files faster.
Install-Winget "BurntSushi.ripgrep.MSVC"
Install-Winget "sharkdp.fd"
Install-Winget "JohnnyMorganz.StyLua"
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

# --- 3. Nerd Fonts (per-user, no admin) -------------------------------------
# $Name is the nerd-fonts release asset name (Hack.zip, JetBrainsMono.zip); the
# extracted files are named "<Name>NerdFont-*.ttf", which doubles as the
# already-installed check.
$NerdFontsVersion = "v3.2.1"

function Install-NerdFont($Name) {
  Info "Installing $Name Nerd Font"
  $fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
  $already = Get-ChildItem $fontDir -Filter "${Name}NerdFont*" -ErrorAction SilentlyContinue
  if ($already) {
    Ok "$Name Nerd Font already installed"
    return
  }
  $tmp = Join-Path $env:TEMP "nerdfont-$Name"
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  $zip = Join-Path $tmp "$Name.zip"
  $url = "https://github.com/ryanoasis/nerd-fonts/releases/download/$NerdFontsVersion/$Name.zip"
  Invoke-WebRequest -Uri $url -OutFile $zip
  Expand-Archive -Path $zip -DestinationPath "$tmp\extracted" -Force
  New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
  $regPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
  $n = 0
  Get-ChildItem "$tmp\extracted" -Filter "*.ttf" | ForEach-Object {
    $dest = Join-Path $fontDir $_.Name
    Copy-Item $_.FullName $dest -Force
    New-ItemProperty -Path $regPath -Name ($_.BaseName + " (TrueType)") -Value $dest -PropertyType String -Force | Out-Null
    $n++
  }
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
  Ok "Installed $n $Name Nerd Font files"
}

if (-not $SkipFont) {
  Install-NerdFont "JetBrainsMono"
  Install-NerdFont "Hack"
} else {
  Warn "Skipping fonts (-SkipFont)"
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
    Warn "nvim.exe not found yet - open a NEW terminal and run 'neovide' to finish plugin install"
  }
} else {
  Warn "Skipping plugin sync (-SkipSync)"
}

# --- 6. Verify the C/C++ toolchain actually works ---------------------------
# winget reports success once the Build Tools *bootstrapper* is registered,
# even when the VCTools workload never landed - and it then refuses to reinstall
# ("no upgrade available"), so the gap is invisible and unfixable by re-running.
# clang targets the MSVC ABI on Windows, so with no MSVC/SDK headers every
# compile fails on #include <stdio.h>. Compile something real rather than
# trusting exit codes.
function Test-CppToolchain {
  $cc = Get-Command clang++ -ErrorAction SilentlyContinue
  if (-not $cc) { return $false }
  $tmp = Join-Path $env:TEMP "nvim-cpp-toolcheck"
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  $src = Join-Path $tmp "check.cpp"
  # Pulls in both the MSVC STL (iostream) and the Windows SDK (via the CRT).
  Set-Content -Path $src -Encoding ascii -Value @'
#include <iostream>
int main() { std::cout << "ok"; }
'@
  # No 2>&1 here: $ErrorActionPreference is Stop, and redirecting a native
  # command's stderr in PS 5.1 raises NativeCommandError and aborts the script.
  & $cc.Source -std=c++17 $src -o (Join-Path $tmp "check.exe")
  $code = $LASTEXITCODE
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
  return ($code -eq 0)
}

Info "Verifying the C/C++ toolchain"
$ToolchainOk = Test-CppToolchain

Write-Host ""
if ($ToolchainOk) {
  Ok "clang++ compiles and links"
  Write-Host "Done! Launch with:  neovide" -ForegroundColor Green
  Write-Host "First launch finishes any remaining plugin/LSP setup automatically." -ForegroundColor Green
} else {
  Warn "SETUP INCOMPLETE - clang cannot compile a C++ program (see the error above)."
  Write-Host ""
  Write-Host "The MSVC headers/libs are missing, so <F5> will fail on every file." -ForegroundColor Yellow
  Write-Host "Add the VCTools workload from an ELEVATED PowerShell:" -ForegroundColor Yellow
  Write-Host ""
  Write-Host '  & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\setup.exe" modify ``' -ForegroundColor Cyan
  Write-Host '      --installPath "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools" ``' -ForegroundColor Cyan
  Write-Host '      --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --quiet --norestart' -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Then open a NEW terminal and re-run this script to re-verify." -ForegroundColor Yellow
}
