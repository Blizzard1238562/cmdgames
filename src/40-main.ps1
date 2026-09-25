# ============================================================
#  MAIN - splash, first-run, entry point
# ============================================================

function Test-ForUpdate {
    # Compares the built-in version against VERSION.txt on GitHub so the
    # one-liner crowd can be told when a refresh is worth it. Fails silently.
    if ($script:Headless) { return }
    try {
        $uri = 'https://raw.githubusercontent.com/Blizzard1238562/cmdgames/refs/heads/main/VERSION.txt'
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add('User-Agent', 'ps-arcade')
        $txt = $wc.DownloadString($uri)
        $v = ''
        if ($txt -match '(\d+\.\d+\.\d+)') { $v = $Matches[1] }
        $script:UpdateRemoteVersion = $v
        $script:UpdateKnown = ($v.Length -gt 0)
        if ($v -ne '' -and $v -ne $script:ArcadeVersion) {
            $a = $script:ArcadeVersion -split '\.'
            $b = $v -split '\.'
            for ($i = 0; $i -lt 3; $i++) {
                $ai = 0; $bi = 0
                if ($i -lt $a.Count) { $ai = [int]$a[$i] }
                if ($i -lt $b.Count) { $bi = [int]$b[$i] }
                if ($bi -gt $ai) { $script:UpdateAvailable = $true; break }
                if ($ai -gt $bi) { break }
            }
        }
    } catch { }
}

function Start-Arcade {
    Initialize-Console
    Initialize-ArcadeConfig
    Test-ForUpdate
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

function Read-ChallengeTarget {
    # Decodes a challenge code ('AA-004821-1') back into game + score.
    # The second letter and the checksum digit must both verify.
    param([string]$Code)
    $c = ($Code -replace '[^A-Za-z0-9-]', '').ToUpper()
    if ($c -notmatch '^([A-Z])([A-Z])-(\d{6})-(\d)$') { return $null }
    $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
    $i1 = $alphabet.IndexOf($Matches[1])
    $i2 = $alphabet.IndexOf($Matches[2])
    if ($i1 -lt 0 -or $i2 -lt 0) { return $null }
    if ($i2 -ne (($i1 * 7 + 5) % 24)) { return $null }
    $gi = $i1
    $score = [int]$Matches[3]
    $chk = [int]$Matches[4]
    if ((($score + $gi * 7919) % 10) -ne $chk) { return $null }
    return @{ gameIdx = $gi; score = $score }
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
    # menu draw test (Start-Screen first, like the real flow does)
    try {
        $script:TestFrames = 0
        Start-Screen -H 30
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
