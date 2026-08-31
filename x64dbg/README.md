# x64dbg + MCP + Dracula

A one-command **AI-controllable reversing environment** for Windows. Installs
x64dbg, the [x64dbg-MCP-Server](https://github.com/duty1g/x64dbg-mcp-server)
plugin and the [Dracula](https://github.com/CX330Blake/x64dbg-theme-dracula)
theme, then registers the MCP server with Claude Code — reading the auth token
for you.

## Quick start

```powershell
cd x64dbg
powershell -ExecutionPolicy Bypass -File .\setup-x64dbg.ps1
```

Then **restart Claude Code** and check `/mcp` — `x64dbg` should show as
connected. The installer is idempotent — safe to re-run.

## What it installs

| Component | Source | Destination |
|-----------|--------|-------------|
| **x64dbg** (latest snapshot) | [x64dbg/x64dbg](https://github.com/x64dbg/x64dbg) | `C:\tools\x64dbg\release\` |
| **x64dbg-MCP-Server** | [duty1g/x64dbg-mcp-server](https://github.com/duty1g/x64dbg-mcp-server) | `release\x64\plugins\*.dp64` + `release\x32\plugins\*.dp32` |
| **Dracula theme** | [CX330Blake/x64dbg-theme-dracula](https://github.com/CX330Blake/x64dbg-theme-dracula) | `release\themes\Dracula\` |

Releases are resolved through the GitHub API, so you always get the latest. If
the API is unreachable the plugin falls back to the pinned `v1.2`.

Activate the theme under **Options > Theme > Dracula**.

### Flags

| Flag | Default | Effect |
|------|---------|--------|
| `-X64dbgRoot` | `C:\tools\x64dbg` | Install directory |
| `-BindAddress` | `127.0.0.1` | MCP server listen address |
| `-Port` | `9094` | `9094` = x64dbg, `9095` = x32dbg |
| `-SkipX64dbg` | — | Leave x64dbg alone (use an existing install) |
| `-SkipPlugin` | — | Don't deploy the MCP plugin |
| `-SkipTheme` | — | Don't install the Dracula theme |
| `-SkipClaude` | — | Don't launch x64dbg or register the MCP server |
| `-Diagnose` | — | Diagnose only, install nothing |

```powershell
# Full install elsewhere, no theme
.\setup-x64dbg.ps1 -X64dbgRoot D:\re\x64dbg -SkipTheme

# Already installed — just re-register the MCP server after rotating the token
.\setup-x64dbg.ps1 -SkipX64dbg -SkipPlugin -SkipTheme
```

## How the token registration works

The plugin is **not a standalone server**: it is a native (Zig) x64dbg plugin
that stands up an HTTP MCP server inside the debugger process. Two consequences:

- **x64dbg must be running** for the agent to have access.
- The Bearer token is **auto-generated on first launch** and stored in
  `mcp_config.json`, next to the executable.

So the last step of the script launches x64dbg, waits up to 90 s for
`mcp_config.json` to appear, reads the token, and runs:

```powershell
claude mcp add --scope user --transport http x64dbg http://127.0.0.1:9094/ `
    --header "Authorization: Bearer <token>"
```

No copy-pasting the token by hand. If `claude` isn't on `PATH`, the script
prints the JSON structure to add — with the token **redacted** — and tells you
which file holds it.

### Registering x32dbg too

**Each architecture runs its own plugin instance with its own token**, in its
own `mcp_config.json`. Reusing the x64 token for the x32 server gets you a
silent `401`. Everything the script does is derived from `-Port`, so:

```powershell
# after the x64 install, register the 32-bit debugger as well
.\setup-x64dbg.ps1 -SkipX64dbg -SkipPlugin -SkipTheme -Port 9095
```

That launches `x32dbg.exe` if it has never run (so the plugin can generate its
token), reads `release\x32\mcp_config.json`, and registers it under the name
`x32dbg`. Useful for 32-bit samples and implants.

### Manual configuration

In `%USERPROFILE%\.claude.json`, at the **root level** — a sibling of
`"projects"`, not inside it (in there it would only apply to one project):

```json
  "mcpServers": {
    "x64dbg": {
      "type": "http",
      "url": "http://127.0.0.1:9094/",
      "headers": { "Authorization": "Bearer <TOKEN>" }
    },
    "x32dbg": {
      "type": "http",
      "url": "http://127.0.0.1:9095/",
      "headers": { "Authorization": "Bearer <TOKEN>" }
    }
  },
```

See `claude-mcp.example.json`. Back `.claude.json` up before editing it — it is
a large file holding all your project history.

## What the agent gets

84 tools against the debugged process:

- **Debugging** — load binaries, breakpoints (software, hardware, memory,
  conditional), step in/over/out, run, read and write memory, registers,
  threads, call stack.
- **Analysis** — disassembly, pattern scanning, string extraction,
  cross-references, symbol lookup, function analysis, PE structures.
- **Unpacking** — OEP detection, module dumping, SEH inspection, exception
  handling configuration, tracing with history capture.
- **Utilities** — event logging, bookmarks, memory alloc/free, patching.

## The plugin doesn't show up in the Plugins menu

In order of likelihood:

1. **You're opening a different x64dbg.** By far the most common cause. If
   `release\x64dbg.ini` doesn't exist, that x64dbg has never been run from that
   folder. Open literally `C:\tools\x64dbg\release\x64\x64dbg.exe` — not
   `x96dbg.exe`, which is only the launcher, and not some older copy lying
   around.
2. **Mark-of-the-Web.** The `.dp64` comes out of a downloaded zip, Windows flags
   it as originating from the internet, and `LoadLibrary` fails. This is exactly
   why the script runs `Unblock-File` across the whole tree.
3. **Defender.** An HTTP server that drives a debugger is prime detection bait.
   `-Diagnose` queries `Get-MpThreatDetection`.
4. **Architecture mismatch.** `.dp64` belongs in `x64\plugins\`, `.dp32` in
   `x32\plugins\`. A `.dp32` in `x64\plugins\` is silently ignored.

The source of truth is x64dbg's **Log** tab at startup: it prints
`[PLUGIN] x64dbg-MCP-Server.dp64 loaded` or the specific load error. No
`[PLUGIN]` line at all means (1) or (2).

```powershell
.\setup-x64dbg.ps1 -Diagnose
```

Checks paths, Zone.Identifier, `x64dbg.ini`, whether 9094/9095 are listening,
and Defender detections. It prints `mcp_config.json` **with the token redacted**,
so the output is safe to paste anywhere.

## Security

**The plugin binds to `0.0.0.0` by default over plain HTTP, no TLS.** Anyone on
your network holding the token gets full control of the debugger — and therefore
of the process being debugged, and of the machine. Set it to `127.0.0.1` under
**Plugins > x64dbg-MCP Server > Configure MCP Server...**. If you need to reach
it from a VM or WSL, tunnel over SSH rather than exposing the port.

About the token:

- It lives in `mcp_config.json` (next to the executable) and in `.claude.json`,
  **in cleartext** in both. This folder's `.gitignore` blocks both.
- **Never** paste it into issues, PRs, commits or chats. Rotate it from the same
  dialog (*Generate* button) and re-run the script with
  `-SkipX64dbg -SkipPlugin -SkipTheme`.
- `claude mcp add` takes the token as a command-line argument, so it lands in
  the PSReadLine history
  (`%APPDATA%\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt`).
  The script prints that path when it finishes — clear it on a shared machine.

And the obvious one: this hands an agent the ability to write memory into and
patch arbitrary processes. Point it at samples in an isolated lab, not at your
working machine.
