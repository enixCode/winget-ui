# Module: package-selector.ps1
# Exports: Get-PackageItems, Show-PackageSelector

function Get-PackageItems {
    param([Parameter(Mandatory)][object]$ProfileConfig)

    $items = @()

    foreach ($group in $ProfileConfig.packageGroups.PSObject.Properties) {
        foreach ($pkg in $group.Value) {
            $items += @{ Name = $pkg.name; Id = $pkg.id; Group = $group.Name; Selected = [bool]$pkg.selected; Type = "winget" }
        }
    }

    if ($ProfileConfig.commands) {
        foreach ($group in $ProfileConfig.commands.PSObject.Properties) {
            foreach ($cmd in $group.Value) {
                $items += @{ Name = $cmd.name; Command = $cmd.command; Group = $group.Name; Selected = [bool]$cmd.selected; Type = "command" }
            }
        }
    }

    Write-Host "`n  Scanning installed..." -ForegroundColor Yellow
    $installed = winget list 2>$null | Out-String
    foreach ($item in $items | Where-Object { $_.Type -eq "winget" }) {
        $item.Installed = $installed -match [regex]::Escape($item.Id)
    }

    return $items
}

function Show-PackageSelector {
    param(
        [Parameter(Mandatory)][array]$Items,
        [Parameter(Mandatory)][string]$ProfileName
    )

    $sel = 0
    while ($true) {
        Clear-Host
        $sel_count = ($Items | Where-Object { $_.Selected -and -not $_.Installed }).Count

        Write-Host "`n  $ProfileName - $sel_count selected`n" -ForegroundColor Yellow

        $last_group = ""
        for ($i = 0; $i -lt $Items.Count; $i++) {
            $p = $Items[$i]
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
            40 { $sel = [Math]::Min($Items.Count - 1, $sel + 1) }
            32 { if (-not $Items[$sel].Installed) { $Items[$sel].Selected = -not $Items[$sel].Selected } }
            65 { $Items | Where-Object { -not $_.Installed } | ForEach-Object { $_.Selected = $true } }
            78 { $Items | ForEach-Object { $_.Selected = $false } }
            13 { return @($Items | Where-Object { $_.Selected -and -not $_.Installed }) }
            81 { Clear-Host; exit }
        }
    }
}
