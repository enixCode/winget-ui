function Start-Installation {
    param(
        [array]$Queue
    )

    for ($j = 0; $j -lt $Queue.Count; $j++) {
        $p = $Queue[$j]
        Clear-Host
        Write-Host "`n  [$($j + 1)/$($Queue.Count)] $($p.Name)" -ForegroundColor Yellow

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

        if ($j -lt $Queue.Count - 1) {
            Write-Host "`n  Done. Next: $($Queue[$j + 1].Name)" -ForegroundColor Green
            Write-Host "  [ENTER] Continue  [S] Skip next  [Q] Stop" -ForegroundColor DarkGray
            $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode
            if ($key -eq 81) { break }
            if ($key -eq 83) { $Queue[$j + 1].Selected = $false; continue }
        }
    }

    Write-Host "`n  All done! Press any key to go back..." -ForegroundColor Green
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
