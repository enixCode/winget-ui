function Show-ProfileSelector {
    param(
        [Parameter(Mandatory)]
        [array]$Profiles
    )

    $sel = 0
    while ($true) {
        Clear-Host
        Write-Host "`n  SELECT PROFILE`n" -ForegroundColor Yellow
        for ($i = 0; $i -lt $Profiles.Count; $i++) {
            $cur = if ($i -eq $sel) { ">" } else { " " }
            Write-Host "  $cur $($Profiles[$i].Name)" -ForegroundColor $(if ($i -eq $sel) { "White" } else { "Gray" })
        }
        Write-Host "`n  [UP/DOWN] Navigate  [ENTER] Select  [Q] Quit" -ForegroundColor DarkGray

        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode
        switch ($key) {
            38 { $sel = [Math]::Max(0, $sel - 1) }
            40 { $sel = [Math]::Min($Profiles.Count - 1, $sel + 1) }
            13 { return $Profiles[$sel].File }
            81 { exit }
        }
    }
}
