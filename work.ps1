# Winget UI - Simple package installer
$ErrorActionPreference = "Stop"

# Parse arguments (Linux-style --config)
$config = $null
for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -eq "--config" -and $i + 1 -lt $args.Count) {
        $config = $args[$i + 1]
    }
}
$Dir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Handle --config parameter or show profile selection
if ($config) {
    # Check configs/ folder first, then script directory
    $configPath = "$Dir\configs\$config"
    if (-not (Test-Path $configPath)) {
        $configPath = "$Dir\$config"
    }
    if (-not (Test-Path $configPath)) {
        Write-Host "`n  ERROR: Config file not found: $config" -ForegroundColor Red
        Write-Host "  Available configs:" -ForegroundColor Yellow
        Get-ChildItem "$Dir\configs" -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    - $($_.Name)" -ForegroundColor Gray }
        Get-ChildItem "$Dir" -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    - $($_.Name)" -ForegroundColor Gray }
        exit 1
    }
    $profileConfig = Get-Content $configPath -Raw | ConvertFrom-Json
} else {
    # Get profiles from configs/ folder and script directory
    $profiles = @()
    Get-ChildItem "$Dir\configs" -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object {
        $c = Get-Content $_.FullName -Raw | ConvertFrom-Json
        $profiles += @{ File = $_.FullName; Name = $c.name }
    }
    Get-ChildItem "$Dir" -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object {
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

    $profileConfig = Get-Content $profiles[$sel].File -Raw | ConvertFrom-Json
}
$packages = @()
foreach ($group in $profileConfig.packageGroups.PSObject.Properties) {
    foreach ($pkg in $group.Value) {
        $packages += @{ Name = $pkg.Name; Id = $pkg.Id; Group = $group.Name; Selected = $false }
    }
}

# Check installed
Write-Host "`n  Scanning installed..." -ForegroundColor Yellow
$installed = winget list 2>$null | Out-String
foreach ($pkg in $packages) {
    $pkg.Installed = $installed -match [regex]::Escape($pkg.Id)
}

# Main loop
$sel = 0
while ($true) {
    Clear-Host
    $selCount = ($packages | Where-Object { $_.Selected -and -not $_.Installed }).Count

    Write-Host "`n  $($profileConfig.name) - $selCount selected`n" -ForegroundColor Yellow

    $lastGroup = ""
    for ($i = 0; $i -lt $packages.Count; $i++) {
        $p = $packages[$i]
        if ($p.Group -ne $lastGroup) {
            Write-Host "  --- $($p.Group) ---" -ForegroundColor Cyan
            $lastGroup = $p.Group
        }

        $cur = if ($i -eq $sel) { ">" } else { " " }
        if ($p.Installed) {
            $box = "[+]"; $color = "DarkGray"; $status = "(installed)"
        } elseif ($p.Selected) {
            $box = "[x]"; $color = "Green"; $status = ""
        } else {
            $box = "[ ]"; $color = "White"; $status = ""
        }
        Write-Host "  $cur $box $($p.Name) $status" -ForegroundColor $color
    }

    Write-Host "`n  [SPACE] Toggle  [A] All  [N] None  [ENTER] Install  [Q] Quit" -ForegroundColor DarkGray

    switch ($Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode) {
        38 { $sel = [Math]::Max(0, $sel - 1) }
        40 { $sel = [Math]::Min($packages.Count - 1, $sel + 1) }
        32 { if (-not $packages[$sel].Installed) { $packages[$sel].Selected = -not $packages[$sel].Selected } }
        65 { $packages | Where-Object { -not $_.Installed } | ForEach-Object { $_.Selected = $true } }
        78 { $packages | ForEach-Object { $_.Selected = $false } }
        13 {
            $toInstall = $packages | Where-Object { $_.Selected -and -not $_.Installed }
            if ($toInstall.Count -gt 0) {
                Clear-Host
                Write-Host "`n  CHECKING PACKAGE SOURCES...`n" -ForegroundColor Yellow

                # Check for non-msstore packages
                $warnings = @()
                foreach ($p in $toInstall) {
                    $info = winget show --id $p.Id 2>$null | Out-String
                    if ($info -notmatch "msstore") {
                        $warnings += $p.Name
                    }
                }

                if ($warnings.Count -gt 0) {
                    Write-Host "  WARNING: The following packages are from community sources" -ForegroundColor Red
                    Write-Host "  (not verified by Microsoft Store):`n" -ForegroundColor Red
                    foreach ($w in $warnings) {
                        Write-Host "    - $w" -ForegroundColor Yellow
                    }
                    Write-Host "`n  These packages are downloaded from third-party sites." -ForegroundColor DarkGray
                    Write-Host "  Proceed with caution.`n" -ForegroundColor DarkGray
                    Write-Host "  [ENTER] Continue  [Q] Cancel" -ForegroundColor White
                    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode
                    if ($key -eq 81) { continue }
                }

                Clear-Host
                Write-Host "`n  INSTALLING $($toInstall.Count) PACKAGES`n" -ForegroundColor Yellow
                foreach ($p in $toInstall) {
                    Write-Host "  $($p.Name)..." -NoNewline
                    $output = winget install --id $p.Id --accept-package-agreements --accept-source-agreements -h 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host " OK" -ForegroundColor Green
                        $p.Installed = $true
                    } else {
                        Write-Host " FAIL" -ForegroundColor Red
                        # Extract error message
                        $errorMsg = ($output | Where-Object { $_ -match "error|failed|not found|no package" }) -join "`n"
                        if (-not $errorMsg) { $errorMsg = $output | Select-Object -Last 3 | Out-String }
                        Write-Host "    $($errorMsg.Trim())" -ForegroundColor DarkRed
                    }
                    $p.Selected = $false
                }
                Write-Host "`n  Press any key..." -ForegroundColor DarkGray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
        81 { Clear-Host; exit }
    }
}
