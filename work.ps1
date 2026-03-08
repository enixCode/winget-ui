# Winget UI - Simple package installer
$ErrorActionPreference = "Stop"

# Parse arguments (Linux-style --config)
$config = $null
for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -eq "--config" -and $i + 1 -lt $args.Count) {
        $config = $args[$i + 1]
    }
}
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Handle --config parameter or show profile selection
if ($config) {
    # Check configs/ folder first, then script directory
    $config_path = "$dir\configs\$config"
    if (-not (Test-Path $config_path)) {
        $config_path = "$dir\$config"
    }
    if (-not (Test-Path $config_path)) {
        Write-Host "`n  ERROR: Config file not found: $config" -ForegroundColor Red
        Write-Host "  Available configs:" -ForegroundColor Yellow
        Get-ChildItem "$dir\configs" -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    - $($_.Name)" -ForegroundColor Gray }
        Get-ChildItem "$dir" -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    - $($_.Name)" -ForegroundColor Gray }
        exit 1
    }
    $profile_config = Get-Content $config_path -Raw | ConvertFrom-Json
} else {
    # Get profiles from configs/ folder and script directory
    $profiles = @()
    Get-ChildItem "$dir\configs" -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object {
        $c = Get-Content $_.FullName -Raw | ConvertFrom-Json
        $profiles += @{ File = $_.FullName; Name = $c.name }
    }
    Get-ChildItem "$dir" -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object {
        $c = Get-Content $_.FullName -Raw | ConvertFrom-Json
        if ($c.packageGroups) { $profiles += @{ File = $_.FullName; Name = $c.name } }
    }

    # Select profile
    $sel = 0
    while ($true) {
        Clear-Host
        Write-Host "`n  SELECT PROFILE`n" -ForegroundColor Yellow
        for ($i = 0; $i -lt $profiles.Count; $i++) {
            $cur = if ($i -eq $sel) { ">" } else { " " }
            Write-Host "  $cur $($profiles[$i].Name)" -ForegroundColor $(if ($i -eq $sel) { "White" } else { "Gray" })
        }
        Write-Host "`n  [UP/DOWN] Navigate  [ENTER] Select  [Q] Quit" -ForegroundColor DarkGray

        switch ($Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode) {
            38 { $sel = [Math]::Max(0, $sel - 1) }
            40 { $sel = [Math]::Min($profiles.Count - 1, $sel + 1) }
            13 { break }
            81 { exit }
        }
        if ($Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode -eq 13) { break }
    }

    $profile_config = Get-Content $profiles[$sel].File -Raw | ConvertFrom-Json
}
$items = @()
foreach ($group in $profile_config.packageGroups.PSObject.Properties) {
    foreach ($pkg in $group.Value) {
        $items += @{ Name = $pkg.name; Id = $pkg.id; Group = $group.Name; Selected = [bool]$pkg.selected; Type = "winget" }
    }
}
if ($profile_config.commands) {
    foreach ($group in $profile_config.commands.PSObject.Properties) {
        foreach ($cmd in $group.Value) {
            $items += @{ Name = $cmd.name; Command = $cmd.command; Group = $group.Name; Selected = [bool]$cmd.selected; Type = "command" }
        }
    }
}

# Check installed (winget packages only)
Write-Host "`n  Scanning installed..." -ForegroundColor Yellow
$installed = winget list 2>$null | Out-String
foreach ($item in $items | Where-Object { $_.Type -eq "winget" }) {
    $item.Installed = $installed -match [regex]::Escape($item.Id)
}

# Main loop
$sel = 0
while ($true) {
    Clear-Host
    $sel_count = ($items | Where-Object { $_.Selected -and -not $_.Installed }).Count

    Write-Host "`n  $($profile_config.name) - $sel_count selected`n" -ForegroundColor Yellow

    $last_group = ""
    for ($i = 0; $i -lt $items.Count; $i++) {
        $p = $items[$i]
        if ($p.Group -ne $last_group) {
            Write-Host "  --- $($p.Group) ---" -ForegroundColor Cyan
            $last_group = $p.Group
        }

        $cur = if ($i -eq $sel) { ">" } else { " " }
        if ($p.Installed) {
            $box = "[+]"; $color = "DarkGray"; $status = "(installed)"
        } elseif ($p.Selected) {
            $box = if ($p.Type -eq "command") { "{x}" } else { "[x]" }
            $color = "Green"; $status = ""
        } else {
            $box = if ($p.Type -eq "command") { "{ }" } else { "[ ]" }
            $color = "White"; $status = ""
        }
        Write-Host "  $cur $box $($p.Name) $status" -ForegroundColor $color
    }

    Write-Host "`n  [SPACE] Toggle  [A] All  [N] None  [ENTER] Launch  [Q] Quit" -ForegroundColor DarkGray

    switch ($Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode) {
        38 { $sel = [Math]::Max(0, $sel - 1) }
        40 { $sel = [Math]::Min($items.Count - 1, $sel + 1) }
        32 { if (-not $items[$sel].Installed) { $items[$sel].Selected = -not $items[$sel].Selected } }
        65 { $items | Where-Object { -not $_.Installed } | ForEach-Object { $_.Selected = $true } }
        78 { $items | ForEach-Object { $_.Selected = $false } }
        13 {
            $queue = @($items | Where-Object { $_.Selected -and -not $_.Installed })
            if ($queue.Count -gt 0) {
                for ($j = 0; $j -lt $queue.Count; $j++) {
                    $p = $queue[$j]
                    Clear-Host
                    Write-Host "`n  [$($j + 1)/$($queue.Count)] $($p.Name)" -ForegroundColor Yellow

                    if ($p.Type -eq "winget") {
                        $cmd = "Write-Host 'Installing $($p.Name)...' -ForegroundColor Yellow; winget install --id $($p.Id) --accept-package-agreements --accept-source-agreements; pause"
                        Write-Host "  Opening terminal..." -ForegroundColor Cyan
                        Start-Process powershell -ArgumentList "-Command", $cmd -Wait
                    } else {
                        $cmd = "Write-Host 'Running: $($p.Command)' -ForegroundColor Yellow; $($p.Command); pause"
                        Write-Host "  Opening terminal..." -ForegroundColor Magenta
                        Start-Process powershell -ArgumentList "-Command", $cmd -Wait
                    }
                    $p.Selected = $false

                    if ($j -lt $queue.Count - 1) {
                        Write-Host "`n  Done. Next: $($queue[$j + 1].Name)" -ForegroundColor Green
                        Write-Host "  [ENTER] Continue  [S] Skip next  [Q] Stop" -ForegroundColor DarkGray
                        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode
                        if ($key -eq 81) { break }
                        if ($key -eq 83) { $queue[$j + 1].Selected = $false; continue }
                    }
                }
                Write-Host "`n  All done! Press any key to go back..." -ForegroundColor Green
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
        81 { Clear-Host; exit }
    }
}
