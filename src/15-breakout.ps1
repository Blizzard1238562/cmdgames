# ============================================================
#  BREAKOUT
# ============================================================
$script:BreakoutTitle = 'Breakout'
$script:BreakoutDesc  = 'bounce the ball, smash every brick'

function Start-Breakout {
    while ($true) {
        Start-Frames
        Start-Screen -H 30
        $bw = 50; $bh = 20
        $bx = 15; $by = 6
        $paddleW = 9
        $padX = [int](($bw - $paddleW) / 2)
        $ballX = [double]($bw / 2)
        $ballY = [double]($bh - 4)
        $vx = 0.5; $vy = -0.6
        $level = 1
        $score = 0
        $lives = 3
        $bricks = $null

        function script:New-BrickWall {
            param($rows, $cols)
            $w = @{ }
            for ($r = 0; $r -lt $rows; $r++) {
                for ($c = 0; $c -lt $cols; $c++) {
                    if ((Get-Random -Maximum 10) -lt 9) { $w["$r,$c"] = (3 - [Math]::Min(2, $r)) }  # strength
                }
            }
            return $w
        }
        $bricks = script:New-BrickWall -rows 4 -cols 12

        try {
            $running = $true
            while ($running) {
                $keys = Get-KeysPressed
                if (Mute-ToggleRequested $keys) { }
                if ($keys -contains 'Q') { return }
                if ($keys -contains 'LeftArrow' -or $keys -contains 'A') { $padX -= 3 }
                if ($keys -contains 'RightArrow' -or $keys -contains 'D') { $padX += 3 }
                if ($padX -lt 1) { $padX = 1 }
                if ($padX -gt ($bw - $paddleW - 1)) { $padX = $bw - $paddleW - 1 }

                $ballX += $vx; $ballY += $vy

                # walls
                if ($ballX -lt 0.5) { $ballX = 0.5; $vx = - $vx; Play-Sfx -Freq 240 -Ms 15 }
                if ($ballX -gt ($bw - 0.5)) { $ballX = $bw - 0.5; $vx = - $vx; Play-Sfx -Freq 240 -Ms 15 }
                if ($ballY -lt 0.5) { $ballY = 0.5; $vy = - $vy; Play-Sfx -Freq 240 -Ms 15 }

                # paddle bounce
                $ibx = [int][Math]::Round($ballX); $iby = [int][Math]::Round($ballY)
                if ($vy -gt 0 -and $iby -ge ($bh - 2) -and $iby -le ($bh - 1) -and $ibx -ge $padX -and $ibx -lt ($padX + $paddleW)) {
                    $vy = -[Math]::Abs($vy)
                    $hit = ($ibx - $padX) / $paddleW   # 0..1
                    $vx = ($hit - 0.5) * 1.6
                    Play-Sfx -Freq 330 -Ms 20
                }

                # bricks: cell width 4, rows start at y=0
                $cw = 4
                if ($iby -ge 0 -and $iby -lt 12) {
                    $bc = [int][Math]::Floor($ballX / $cw)
                    $br = [int][Math]::Floor($ballY / 3)
                    $key = "$br,$bc"
                    if ($bricks.ContainsKey($key)) {
                        $bricks[$key]--
                        if ($bricks[$key] -le 0) { $bricks.Remove($key); $score += 10 * $level }
                        else { $score += 3 }
                        # bounce direction: crude - invert vertical unless hitting side of grid
                        if ($bc -eq 0 -or $bc -eq 11) { $vx = - $vx } else { $vy = - $vy }
                        Play-Sfx -Freq 440 -Ms 20
                    }
                }

                # ball lost
                if ($ballY -ge $bh) {
                    $lives--
                    Play-Sfx -Freq 100 -Ms 150
                    if ($lives -le 0) { $running = $false }
                    else {
                        $ballX = $bw / 2; $ballY = $bh - 4
                        $vx = 0.5; $vy = -0.6
                    }
                }

                # level clear
                if ($bricks.Count -eq 0) {
                    $level++
                    $score += 150
                    $bricks = script:New-BrickWall -rows (4 + [Math]::Min(4, $level)) -cols 12
                    $ballX = $bw / 2; $ballY = $bh - 4
                    $vx = 0.5 * (1 + 0.1 * $level); $vy = -0.65
                    Play-Sfx -Freq 520 -Ms 60; Play-Sfx -Freq 780 -Ms 80
                }

                Clear-Frame
                Set-GameHeader -Title $script:BreakoutTitle -Score $score -Right ('lvl {0}  {1}{2}' -f $level, $script:ChHeart, $lives)
                Draw-Box -X ($bx - 1) -Y ($by - 1) -W ($bw + 2) -H ($bh + 2) -Fg 'wall'
                foreach ($kv in $bricks.GetEnumerator()) {
                    $p = $kv.Key.Split(','); $r = [int]$p[0]; $c = [int]$p[1]
                    $col = @('red','orange','yellow')[$r % 3]
                    $cx = $bx + $c * $cw + 1; $cy = $by + $r * 3
                    for ($i = 0; $i -lt 3; $i++) { Set-Cell -X ($cx + $i) -Y $cy -Char $script:ChMed -Fg $col }
                }
                Set-Text -X ($bx + $padX) -Y ($by + $bh - 1) -Text (([string]$script:ChFull * $paddleW)) -Fg 'cyan'
                Set-Cell -X ($bx + $ibx) -Y ($by + $iby) -Char $script:ChDiam -Fg 'white'
                Set-TextCentered -Y ($by + $bh + 2) -Text 'arrows move the paddle - ball angle depends on hit spot - q menu' -Fg 'dim'
                Show-Frame
                Wait-Frame 40
            }
        } catch [ArcadeSelfTestDone] { throw }

        if (-not (Complete-Game -GameId 'breakout' -GameName $script:BreakoutTitle -Score $score)) { break }
    }
}
