# ============================================================
#  MAIN - splash, first-run, entry point
# ============================================================

function Start-Arcade {
    Initialize-Console
    Initialize-ArcadeConfig
    try {
        Clear-Console
        Start-Screen -H 30
        Show-MenuLogo -Y 8
        Set-TextCentered -Y 15 -Text 'insert coin...' -Fg 'dim'
        Show-Frame
        Start-Sleep -Milliseconds 600

        if ($script:PlayerName.Length -eq 0) {
            Clear-Frame
            Show-MenuLogo -Y 6
            Set-TextCentered -Y 13 -Text 'first time here - pick a name for the leaderboards' -Fg 'dim'
            Show-Frame
            $script:PlayerName = Read-PlayerName -Default ''
            Save-ArcadeConfig
        }

        Show-Menu
    } finally {
        Restore-Console
    }
}

# ---- entry ----
if ($ListGames) {
    foreach ($g in $script:Games) { '{0,-12} {1}' -f $g.id, $g.name }
    return
}

if ($SelfTest) {
    # Headless smoke test: run every game's loop for a few simulated frames.
    $script:Headless = $true
    $script:SoundOn = $false
    $script:PlayerName = 'tester'
    $failed = @()
    $only = $env:ARCADE_TEST_GAME
    foreach ($g in $script:Games) {
        if ($only -and $g.id -ne $only) { continue }
        Write-Host ('  run  ' + $g.name)
        $script:TestFrames = 0
        try {
            & $g.fn
            Write-Host ('  ok   ' + $g.name)
        } catch [ArcadeSelfTestDone] {
            Write-Host ('  ok   ' + $g.name + '  (ran ' + $script:TestFrames + ' frames)')
        } catch {
            Write-Host ('  FAIL ' + $g.name + '  -> ' + $_.Exception.Message)
            Write-Host ($_.ScriptStackTrace)
            $failed += $g.name
        }
    }
    # menu draw test
    try {
        $script:TestFrames = 0
        Show-Menu
        Write-Host '  ok   menu'
    } catch [ArcadeSelfTestDone] {
        Write-Host '  ok   menu'
    } catch {
        Write-Host ('  FAIL menu -> ' + $_.Exception.Message)
        $failed += 'menu'
    }
    Write-Host ''
    if ($failed.Count -eq 0) { Write-Host 'all games passed the smoke test' -ForegroundColor Green }
    else { Write-Host ('failed: ' + ($failed -join ', ')) -ForegroundColor Red }
    return
}

Start-Arcade
