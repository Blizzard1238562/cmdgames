# Simulates the exact player one-liner: downloads from GitHub raw and runs it.
$code = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/Blizzard1238562/cmdgames/main/arcade.ps1'
$sb = [scriptblock]::Create($code)
& $sb -ListGames
Write-Host '--- ONE-LINER DOWNLOAD + RUN: OK ---'
