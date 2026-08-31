<#
.SYNOPSIS
    Installs x64dbg + the x64dbg-MCP-Server plugin + the Dracula theme, and
    registers the MCP server with Claude Code, reading the Bearer token for you.

.DESCRIPTION
    - Downloads the latest x64dbg snapshot if it isn't installed already.
    - Deploys the x64dbg-MCP-Server plugin (.dp32 + .dp64) into the right root.
    - Installs the Dracula theme into release\themes\Dracula.
    - Runs Unblock-File across everything extracted. The Mark-of-the-Web stops
      x64dbg from loading plugins downloaded from the internet, and that is the
      number one reason the "Plugins" menu comes up empty.
    - Launches x64dbg, waits for the plugin to generate mcp_config.json, reads
      the token and runs `claude mcp add` with the Authorization header.

    The token is never printed, not even truncated: console output ends up in
    logs, screenshots and terminal history.

.PARAMETER X64dbgRoot
    Install directory. Defaults to C:\tools\x64dbg. The official snapshot
    creates a 'release\' subdirectory inside it, which is the real x64dbg root.

.PARAMETER BindAddress
    MCP server listen address. Defaults to 127.0.0.1. The plugin ships with
    0.0.0.0, which exposes control of the debugger to the whole network.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File setup-x64dbg.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File setup-x64dbg.ps1 -X64dbgRoot D:\re\x64dbg -SkipTheme

.EXAMPLE
    # Only diagnose an existing install
    powershell -ExecutionPolicy Bypass -File setup-x64dbg.ps1 -Diagnose
#>

[CmdletBinding()]
param(
    [string]$X64dbgRoot  = "C:\tools\x64dbg",
    [string]$BindAddress = "127.0.0.1",
    [int]   $Port        = 9094,
    [switch]$SkipX64dbg,
    [switch]$SkipPlugin,
    [switch]$SkipTheme,
    [switch]$SkipClaude,
    [switch]$Diagnose
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$UA  = @{ "User-Agent" = "WindowsDevEnv-setup" }
$Tmp = Join-Path $env:TEMP "windevenv-x64dbg"
if (-not (Test-Path $Tmp)) { New-Item -ItemType Directory -Path $Tmp -Force | Out-Null }

function Info { param($m) Write-Host "[*] $m" -ForegroundColor Cyan }
function Ok   { param($m) Write-Host "[+] $m" -ForegroundColor Green }
function Warn { param($m) Write-Host "[!] $m" -ForegroundColor Yellow }
function Err  { param($m) Write-Host "[x] $m" -ForegroundColor Red }

function Get-Release {
    # Returns the real x64dbg root: the folder containing x32\ and x64\
    param([string]$Base)
    if (Test-Path (Join-Path $Base "release\x64\x64dbg.exe")) { return (Join-Path $Base "release") }
    if (Test-Path (Join-Path $Base "x64\x64dbg.exe"))         { return $Base }
    return $null
}

function Unblock-Tree {
    # Expand-Archive propagates the Zone.Identifier stream to extracted files on
    # some Windows builds. A .dp64 flagged as internet-sourced fails to
    # LoadLibrary and x64dbg simply never shows the plugin.
    param([string]$Path)
    Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
        Unblock-File -ErrorAction SilentlyContinue
}

# ================================================================ DIAGNOSTICS
if ($Diagnose) {
    Write-Host "=== x64dbg-MCP diagnostics ===" -ForegroundColor Cyan
    $root = Get-Release $X64dbgRoot
    if (-not $root) { Err "No x64dbg found under $X64dbgRoot"; exit 1 }
    Ok "Root: $root"

    foreach ($p in @("x64\plugins\x64dbg-MCP-Server.dp64", "x32\plugins\x64dbg-MCP-Server.dp32")) {
        $f = Join-Path $root $p
        if (Test-Path $f) {
            $blocked = Get-Item -Path $f -Stream Zone.Identifier -ErrorAction SilentlyContinue
            if ($blocked) { Err "$p exists but is BLOCKED (Mark-of-the-Web) -> Unblock-File" }
            else          { Ok  "$p ok" }
        } else { Err "$p MISSING" }
    }

    $ini = Join-Path $root "x64dbg.ini"
    if (Test-Path $ini) { Ok "x64dbg.ini present (x64dbg has run from here)" }
    else { Warn "No x64dbg.ini -> this x64dbg has never been launched. Check you aren't opening a different copy." }

    # Printed REDACTED on purpose: mcp_config.json holds the Bearer token, and
    # diagnostic output ends up pasted into issues and chats.
    Get-ChildItem -Path $root -Recurse -Filter "mcp_config.json" -ErrorAction SilentlyContinue |
        ForEach-Object {
            Ok "Plugin config: $($_.FullName)"
            $c = Get-Content $_.FullName -Raw | ConvertFrom-Json
            $c.PSObject.Properties | ForEach-Object {
                if ($_.Name -match "token|bearer|auth") {
                    $len = if ($null -eq $_.Value) { 0 } else { $_.Value.ToString().Length }
                    Write-Host "      $($_.Name) = <REDACTED, $len chars>"
                } else {
                    Write-Host "      $($_.Name) = $($_.Value)"
                }
            }
        }

    $listen = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
              Where-Object { $_.LocalPort -in 9094, 9095 }
    if ($listen) { $listen | Format-Table LocalAddress, LocalPort, OwningProcess -AutoSize }
    else { Warn "Nothing listening on 9094/9095 (x64dbg closed, or plugin not loaded)" }

    try {
        $det = Get-MpThreatDetection -ErrorAction Stop |
               Where-Object { $_.Resources -match "x64dbg-MCP" }
        if ($det) { Err "Defender has acted on the plugin:"; $det | Format-List Resources, InitialDetectionTime }
    } catch { }
    exit 0
}

# ==================================================================== 1. x64dbg
if (-not $SkipX64dbg -and -not (Get-Release $X64dbgRoot)) {
    Info "No x64dbg under $X64dbgRoot - downloading snapshot..."
    $rel   = Invoke-RestMethod "https://api.github.com/repos/x64dbg/x64dbg/releases/latest" -Headers $UA
    $asset = $rel.assets | Where-Object { $_.name -like "snapshot_*.zip" } | Select-Object -First 1
    if (-not $asset) { throw "No snapshot_*.zip asset in release $($rel.tag_name)" }

    $zip = Join-Path $Tmp $asset.name
    Info "$($asset.name)  ($([math]::Round($asset.size / 1MB, 1)) MB)"
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -UseBasicParsing

    if (-not (Test-Path $X64dbgRoot)) { New-Item -ItemType Directory -Path $X64dbgRoot -Force | Out-Null }
    Expand-Archive -Path $zip -DestinationPath $X64dbgRoot -Force
    Ok "x64dbg extracted to $X64dbgRoot"
} else {
    Ok "x64dbg already present"
}

$Root = Get-Release $X64dbgRoot
if (-not $Root) { throw "Cannot find x64dbg.exe under $X64dbgRoot" }
Info "x64dbg root: $Root"

# ================================================================= 2. MCP plugin
if (-not $SkipPlugin) {
    Info "Downloading x64dbg-MCP-Server..."
    try {
        $mrel   = Invoke-RestMethod "https://api.github.com/repos/duty1g/x64dbg-mcp-server/releases/latest" -Headers $UA
        $masset = $mrel.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
        $murl   = $masset.browser_download_url
        Info "Release $($mrel.tag_name) -> $($masset.name)"
    } catch {
        Warn "GitHub API unavailable, falling back to pinned v1.2"
        $murl = "https://github.com/duty1g/x64dbg-mcp-server/releases/download/v1.2/x64dbg-MCP-Server.zip"
    }

    $mzip = Join-Path $Tmp "x64dbg-MCP-Server.zip"
    Invoke-WebRequest -Uri $murl -OutFile $mzip -UseBasicParsing
    Unblock-File $mzip -ErrorAction SilentlyContinue

    $mdir = Join-Path $Tmp "mcp"
    if (Test-Path $mdir) { Remove-Item $mdir -Recurse -Force }
    Expand-Archive -Path $mzip -DestinationPath $mdir -Force

    # The zip ships either 'dist\x32|x64' or 'x32|x64' at the top level
    if     (Test-Path (Join-Path $mdir "dist\x64")) { $src = Join-Path $mdir "dist" }
    elseif (Test-Path (Join-Path $mdir "x64"))      { $src = $mdir }
    else { throw "Unexpected zip layout: $((Get-ChildItem $mdir).Name -join ', ')" }

    Copy-Item -Path (Join-Path $src "*") -Destination $Root -Recurse -Force
    Ok "Plugin deployed"
}

# =============================================================== 3. Dracula theme
if (-not $SkipTheme) {
    Info "Downloading the Dracula theme..."
    $tzip = Join-Path $Tmp "dracula.zip"
    $done = $false
    foreach ($branch in @("main", "master")) {
        try {
            Invoke-WebRequest -Uri "https://github.com/CX330Blake/x64dbg-theme-dracula/archive/refs/heads/$branch.zip" `
                              -OutFile $tzip -UseBasicParsing
            $done = $true; break
        } catch { }
    }
    if (-not $done) { Warn "Could not download the Dracula theme, continuing" }
    else {
        $tdir = Join-Path $Tmp "dracula"
        if (Test-Path $tdir) { Remove-Item $tdir -Recurse -Force }
        Expand-Archive -Path $tzip -DestinationPath $tdir -Force

        $theme = Get-ChildItem -Path $tdir -Recurse -Directory |
                 Where-Object { $_.Name -eq "Dracula" } | Select-Object -First 1
        if (-not $theme) { Warn "No Dracula\ folder inside the zip" }
        else {
            $themes = Join-Path $Root "themes"
            if (-not (Test-Path $themes)) { New-Item -ItemType Directory -Path $themes -Force | Out-Null }
            Copy-Item -Path $theme.FullName -Destination $themes -Recurse -Force
            Ok "Theme at $themes\Dracula  (enable via Options > Theme > Dracula)"
        }
    }
}

# ==================================================================== 4. Unblock
Info "Stripping the Mark-of-the-Web from extracted files..."
Unblock-Tree $Root
Ok "Unblock-File applied"

# ===================================================================== 5. Verify
$dp64 = Join-Path $Root "x64\plugins\x64dbg-MCP-Server.dp64"
$dp32 = Join-Path $Root "x32\plugins\x64dbg-MCP-Server.dp32"
$fail = $false
foreach ($p in @($dp64, $dp32)) {
    if (Test-Path $p) { Ok "OK  $p" } else { Err "MISSING $p"; $fail = $true }
}
if ($fail) { throw "Incomplete deployment" }

# =========================================================== 6. Token + Claude
if ($SkipClaude) {
    Write-Host ""
    Ok "Done. Launch $Root\x64\x64dbg.exe and check the Log tab."
    exit 0
}

$exe = Join-Path $Root "x64\x64dbg.exe"
Info "Launching $exe so the plugin generates its token..."
Start-Process -FilePath $exe -WorkingDirectory (Join-Path $Root "x64")

$cfg = $null
$deadline = (Get-Date).AddSeconds(90)
while ((Get-Date) -lt $deadline) {
    $cfg = Get-ChildItem -Path $Root -Recurse -Filter "mcp_config.json" -ErrorAction SilentlyContinue |
           Select-Object -First 1
    if ($cfg) { break }
    Start-Sleep -Seconds 2
}

if (-not $cfg) {
    Err "The plugin did not generate mcp_config.json within 90s."
    Warn "Open x64dbg's Log tab: no [PLUGIN] line at all means the .dp64 isn't loading."
    Warn "Re-run this script with -Diagnose for details."
    exit 1
}

Ok "Plugin config: $($cfg.FullName)"
$json  = Get-Content $cfg.FullName -Raw | ConvertFrom-Json
$token = $json.PSObject.Properties |
         Where-Object { $_.Name -match "token|bearer|auth" } |
         Select-Object -First 1 -ExpandProperty Value

if (-not $token) {
    Err "No token key found in the JSON."
    Err "Keys present: $(($json.PSObject.Properties.Name) -join ', ')"
    Err "Open Plugins > x64dbg-MCP Server > Configure MCP Server... and copy it manually."
    exit 1
}
# Never print the token, not even truncated: console output ends up in logs,
# screenshots and terminal history.
Ok "Token read from mcp_config.json ($($token.Length) chars)"

# Safe bind: the plugin ships listening on 0.0.0.0
$bindProp = $json.PSObject.Properties |
            Where-Object { $_.Name -match "bind|host|address" } | Select-Object -First 1
if ($bindProp -and $bindProp.Value -ne $BindAddress) {
    Warn "The plugin is listening on '$($bindProp.Value)'. Change it to $BindAddress under"
    Warn "  Plugins > x64dbg-MCP Server > Configure MCP Server..."
}

$url = "http://${BindAddress}:${Port}/"
Info "Registering the MCP server with Claude Code -> $url"

$claudeJson = Join-Path $env:USERPROFILE ".claude.json"
if (Test-Path $claudeJson) {
    $backup = "$claudeJson.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
    Copy-Item $claudeJson $backup -Force
    Ok "Backup: $backup"
}

$claude = Get-Command claude -ErrorAction SilentlyContinue
if ($claude) {
    & claude mcp remove x64dbg --scope user 2>$null | Out-Null
    & claude mcp add --scope user --transport http x64dbg $url --header "Authorization: Bearer $token"
    if ($?) { Ok "MCP server 'x64dbg' registered. Restart Claude Code and check /mcp" }
} else {
    Warn "'claude' is not on PATH. Add this to $claudeJson at the ROOT level"
    Warn "(a sibling of 'projects', not inside it):"
    Write-Host ""
    Write-Host "  `"mcpServers`": {"
    Write-Host "    `"x64dbg`": {"
    Write-Host "      `"type`": `"http`","
    Write-Host "      `"url`": `"$url`","
    Write-Host "      `"headers`": { `"Authorization`": `"Bearer <TOKEN>`" }"
    Write-Host "    }"
    Write-Host "  },"
    Write-Host ""
    Warn "<TOKEN> lives in $($cfg.FullName) - keep it out of chats, issues and commits."
}

Write-Host ""
Warn "The token was passed on the 'claude mcp add' command line, so it may be"
Warn "sitting in your PowerShell history:"
Warn "  $($(Get-PSReadlineOption).HistorySavePath)"
Warn "Clear it if this machine isn't only yours."
Write-Host ""
Ok "Done."
