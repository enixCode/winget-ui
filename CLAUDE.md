# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Winget UI is a PowerShell-based Terminal User Interface for batch installing Windows packages via winget. It provides profile-based package management with interactive keyboard navigation.

## Running the Application

```powershell
# Interactive mode - select profile from menu
.\work.ps1

# Direct mode - specify config directly
.\work.ps1 --config dev.json
.\work.ps1 --config designer.json
.\work.ps1 --config office.json
.\work.ps1 --config opensource.json
```

No build step, tests, or linting are configured for this project.

## Architecture

**Single-script application**: `work.ps1` contains all application logic (~145 lines).

**UI flow** has two phases:
1. **Profile selection** — arrow keys to navigate profiles, Enter to select, Q to quit
2. **Package selection** — arrow keys to navigate, Space to toggle, A/N for select all/none, Enter to install, Q to quit

**Configuration-driven profiles**: JSON files in `configs/` define package sets. Config lookup order: `configs/` folder first, then script root directory (root-level JSON files must have a `packageGroups` key to be recognized as profiles). Each profile has:
- `name`: Display name
- `description`: Profile description
- `packageGroups`: Object with group names as keys, arrays of package objects as values
- Package objects: `{ "name": "Display Name", "id": "winget.package.id", "selected": true }`
- `commands` (optional): Object with group names as keys, arrays of command objects as values
- Command objects: `{ "name": "Display Name", "command": "shell command to run", "selected": false }`

All config keys use camelCase. The `selected` field sets the initial selection state in the TUI.

**Execution model**: Every selected item launches in its own new terminal window via `Start-Process powershell`. This allows:
- Winget installs to show full output and handle interactive prompts (UAC, license, etc.)
- Custom commands (npm, pip, curl, etc.) to run with normal terminal behavior
- Multiple installs to run in parallel

**External tool integration**: The script shells out to winget commands:
- `winget list` - Detects installed packages (at startup, to mark already-installed packages)

**Visual distinction in TUI**: Winget packages use `[x]`/`[ ]` checkboxes, custom commands use `{x}`/`{ }` braces. Already-installed packages show as `[+]` in DarkGray with `(installed)` and cannot be toggled.

## Requirements

- Windows 10/11
- PowerShell 5.1+
- winget CLI installed
