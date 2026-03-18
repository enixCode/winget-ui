# config-loader.ps1 - Handles config argument parsing and profile discovery

function Get-ProfileConfig {
    param(
        [array]$ScriptArgs,
        [string]$ScriptDir
    )

    # Parse --config argument
    $config = $null
    for ($i = 0; $i -lt $ScriptArgs.Count; $i++) {
        if ($ScriptArgs[$i] -eq "--config" -and $i + 1 -lt $ScriptArgs.Count) {
            $config = $ScriptArgs[$i + 1]
        }
    }

    if ($config) {
        # Check configs/ folder first, then script root
        $config_path = "$ScriptDir\configs\$config"
        if (-not (Test-Path $config_path)) {
            $config_path = "$ScriptDir\$config"
        }
        if (-not (Test-Path $config_path)) {
            Write-Host "`n  ERROR: Config file not found: $config" -ForegroundColor Red
            Write-Host "  Available configs:" -ForegroundColor Yellow
            Get-ChildItem "$ScriptDir\configs" -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object {
                Write-Host "    - $($_.Name)" -ForegroundColor Gray
            }
            Get-ChildItem "$ScriptDir" -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object {
                Write-Host "    - $($_.Name)" -ForegroundColor Gray
            }
            exit 1
        }
        return Get-Content $config_path -Raw | ConvertFrom-Json
    } else {
        # Discover all JSON profiles from configs/ and root (root must have packageGroups)
        $profiles = @()
        Get-ChildItem "$ScriptDir\configs" -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object {
            $c = Get-Content $_.FullName -Raw | ConvertFrom-Json
            $profiles += @{ File = $_.FullName; Name = $c.name }
        }
        Get-ChildItem "$ScriptDir" -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object {
            $c = Get-Content $_.FullName -Raw | ConvertFrom-Json
            if ($c.packageGroups) { $profiles += @{ File = $_.FullName; Name = $c.name } }
        }
        return $profiles
    }
}
