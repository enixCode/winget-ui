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

**Single-script application**: `work.ps1` contains all application logic (~160 lines).

**Configuration-driven profiles**: JSON files in `configs/` define package sets. Each profile has:
- `name`: Display name
- `description`: Profile description
- `packageGroups`: Object with group names as keys, arrays of package objects as values
- Package objects: `{ "Name": "Display Name", "Id": "winget.package.id", "Selected": true }`

**External tool integration**: The script shells out to winget commands:
- `winget list` - Detects installed packages
- `winget show --id <package>` - Checks package source
- `winget install --id <package>` - Installs packages

## Requirements

- Windows 10/11
- PowerShell 5.1+
- winget CLI installed
