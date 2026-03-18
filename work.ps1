# Winget UI - Simple package installer
$ErrorActionPreference = "Stop"
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Load modules
. "$dir\modules\config-loader.ps1"
. "$dir\modules\profile-selector.ps1"
. "$dir\modules\package-selector.ps1"
. "$dir\modules\installer.ps1"

# Get config (returns parsed JSON if --config, or profiles array otherwise)
$result = Get-ProfileConfig -ScriptArgs $args -ScriptDir $dir

if ($result -is [array]) {
    # No --config flag - show profile selector
    $selected_file = Show-ProfileSelector -Profiles $result
    $profile_config = Get-Content $selected_file -Raw | ConvertFrom-Json
} else {
    $profile_config = $result
}

# Build items and show package selector
$items = Get-PackageItems -ProfileConfig $profile_config

# Main loop
while ($true) {
    $queue = Show-PackageSelector -Items $items -ProfileName $profile_config.name
    if ($queue.Count -gt 0) {
        Start-Installation -Queue $queue
    }
}
