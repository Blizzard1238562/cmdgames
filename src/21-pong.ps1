# ============================================================
#  PONG - you vs the CPU, first to 5 wins
# ============================================================
$script:PongTitle = 'Pong'
$script:PongDesc  = 'classic paddle duel, first to 5'

function Start-Pong {
    while ($true) {
        Start-Frames
        Start-Screen -H 30
        $bx0 = 14; $by0 = 4; $bw = 52; $bh = 20
        $pX = 17; $cX = 62          # paddle columns
        $p = 11; $c = 11            # paddle top rows (paddles are 4 tall)
        $pPts = 0; $cPts = 0
        $hits = 0
        $bx = 40.0; $by = 13.0
        $dx = 1; $dy = 0.75
        if ((Get-Random -Maximum 2) -eq 0) { $dx = -1 }
        if ((Get-Random -Maximum 2) -eq 0) { $dy = -0.75 }
        $speed = 1                  # |dx| per move; grows to 2 in long rallies
        $moveEvery = 2              # ball advances every Nth frame
        $mvCount = 0
        $trail = New-Object System.Collections.Generic.List[object]
        $running = $true

        try {
            while ($running) {
                $keys = Get-KeysPressed
                if (Mute-ToggleRequested $keys) { }
                if ($keys -contains 'Q') { return }
                if ($script:Headless) { $keys = @([string](1 + ($script:TestFrames % 9))) }
                if ($keys -contains 'UpArrow' -or $keys -contains 'W' -or $keys -contains '1' -or $keys -contains '2' -or $keys -contains '3') { $p-- }
                if ($keys -contains 'DownArrow' -or $keys -contains 'S' -or $keys -contains '7' -or $keys -contains '8' -or $keys -contains '9') { $p++ }
                if ($p -lt 5) { $p = 5 }
                if ($p -gt 19) { $p = 19 }

                # cpu: follows the ball with capped speed and a small aim error
                $target = 12
                if ($dx -gt 0) { $target = [int]$by + (Get-Random -Minimum -1 -Maximum 2) }
                if ($c -lt ($target - 1)) { $c++ }
                elseif ($c -gt ($target + 1)) { $c-- }
                if ($c -lt 5) { $c = 5 }
                if ($c -gt 19) { $c = 19 }

                # ball movement, paced, with 1-cell sub-steps (no tunneling)
                $mvCount++
                if ($mvCount -ge $moveEvery) {
                    $mvCount = 0
                    $pointScored = $false
                    $serve = 1
                    for ($step = 0; $step -lt $speed -and -not $pointScored; $step++) {
                        $trail.Add(@{ x = $bx; y = $by })
                        while ($trail.Count -gt 3) { $trail.RemoveAt(0) }
                        $bx += $dx
                        $by += $dy
                        $row = [int][Math]::Floor($by)
                        if ($row -le 5)  { $by = 5.01;  $dy = [Math]::Abs($dy) }
                        if ($row -ge 22) { $by = 21.99; $dy = -[Math]::Abs($dy) }
                        $row = [int][Math]::Floor($by)
                        if ($dx -lt 0 -and $bx -le $pX) {
                            if ($row -ge $p -and $row -le ($p + 3)) {
                                $off = $row - $p
                                $dy = 0.66 * ($off - 1.5)
                                if ([Math]::Abs($dy) -lt 0.25) { $dy = 0.4; if ((Get-Random -Maximum 2) -eq 0) { $dy = -0.4 } }
                                $bx = $pX + 1
                                $dx = $speed
                                $hits++
                                Play-Sfx -Freq 520 -Ms 18
                                if ($hits -ge 8) { $speed = 2 }
                            }
                        } elseif ($dx -gt 0 -and $bx -ge $cX) {
                            if ($row -ge $c -and $row -le ($c + 3)) {
                                $off = $row - $c
                                $dy = 0.66 * ($off - 1.5)
                                if ([Math]::Abs($dy) -lt 0.25) { $dy = 0.4; if ((Get-Random -Maximum 2) -eq 0) { $dy = -0.4 } }
                                $bx = $cX - 1
                                $dx = -$speed
                                $hits++
                                Play-Sfx -Freq 440 -Ms 18
                                if ($hits -ge 8) { $speed = 2 }
                            }
                        }
                        if ($bx -lt 16) { $cPts++; $pointScored = $true; $serve = -1 }
                        elseif ($bx -gt 63) { $pPts++; $pointScored = $true; $serve = 1 }
                    }
                    if ($pointScored) {
                        Play-Sfx -Freq 200 -Ms 120
                        if ($pPts -ge 5 -or $cPts -ge 5) { $running = $false }
                        else {
                            $bx = 40.0; $by = 13.0
                            $dx = $serve
                            $dy = (Get-Random -Minimum 3 -Maximum 8) / 10
                            if ((Get-Random -Maximum 2) -eq 0) { $dy = -$dy }
                            $speed = 1; $hits = 0
                            $trail.Clear()
                        }
                    }
                }

                # draw
                Clear-Frame
                Set-GameHeader -Title $script:PongTitle -Score $pPts -Right ('cpu {0} - first to 5' -f $cPts)
                Draw-Box -X $bx0 -Y $by0 -W $bw -H $bh -Fg 'wall'
                for ($yy = 5; $yy -le 22; $yy += 2) { Set-Cell -X 40 -Y $yy -Char $script:ChDot -Fg 'wall' }
                foreach ($t in $trail) {
                    $tx = [int][Math]::Floor($t.x); $ty = [int][Math]::Floor($t.y)
                    if ($tx -ge 15 -and $tx -le 64 -and $ty -ge 5 -and $ty -le 22) {
                        Set-Cell -X $tx -Y $ty -Char '.' -Fg 'dim'
                    }
                }
                Set-Cell -X ([int][Math]::Floor($bx)) -Y ([int][Math]::Floor($by)) -Char '@' -Fg 'yellow'
                for ($i = 0; $i -lt 4; $i++) {
                    Set-Cell -X $pX -Y ($p + $i) -Char $script:ChFull -Fg 'accent'
                    Set-Cell -X $cX -Y ($c + $i) -Char $script:ChFull -Fg 'red'
                }
                Set-TextCentered -Y 25 -Text 'up/down or w/s move - q menu' -Fg 'dim'
                Show-Frame
                Wait-Frame 45
            }
        } catch [ArcadeSelfTestDone] { throw }

        if (-not (Complete-Game -GameId 'pong' -GameName $script:PongTitle -Score ($pPts * 1000 + $hits))) { break }
    }
}
