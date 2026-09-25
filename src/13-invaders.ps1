# ============================================================
#  SPACE INVADERS
# ============================================================
$script:InvadersTitle = 'Space Invaders'
$script:InvadersDesc  = 'shoot the alien fleet before it lands'

function Start-Invaders {
    while ($true) {
        Start-Frames
        Start-Screen -H 30
        $bw = 60; $bh = 19
        $bx = 10; $by = 6
        $shipX = [int]($bw / 2)
        $bullets = @()      # @{x,y}
        $bombs = @()        # @{x,y}
        $aliens = New-Object System.Collections.Generic.List[object]   # @{x,y,kind,alive}
        $wave = 1
        $score = 0
        $lives = 3
        $dirR = $true
        $cooldown = 0

        function script:New-InvaderWave {
            param($aliens, $wave)
            $aliens.Clear()
            for ($r = 0; $r -lt 3; $r++) {
                for ($c = 0; $c -lt 8; $c++) {
                    $aliens.Add(@{ x = 6 + $c * 6; y = 1 + $r * 3; alive = $true; kind = $r })
                }
            }
        }
        script:New-InvaderWave -aliens $aliens -wave $wave
        $frame = 0
        $stepEvery = 12   # frames per alien move; decreases per wave

        try {
            $running = $true
            while ($running) {
                $frame++
                $keys = Get-KeysPressed
                if (Mute-ToggleRequested $keys) { }
                if ($keys -contains 'Q') { return }
                if ($keys -contains 'LeftArrow' -or $keys -contains 'A') { $shipX -= 2 }
                if ($keys -contains 'RightArrow' -or $keys -contains 'D') { $shipX += 2 }
                if ($shipX -lt 1) { $shipX = 1 }
                if ($shipX -gt ($bw - 2)) { $shipX = $bw - 2 }
                if (($keys -contains 'Space') -and $cooldown -le 0) {
                    $bullets += @{ x = $shipX; y = $bh - 2 }
                    $cooldown = 3
                    Play-Sfx -Freq 880 -Ms 25
                }
                if ($cooldown -gt 0) { $cooldown-- }

                # move bullets
                $newB = @()
                foreach ($b in $bullets) {
                    $b.y -= 2
                    if ($b.y -ge 0) { $newB += $b }
                }
                $bullets = $newB

                # alien fleet movement
                if (($frame % $stepEvery) -eq 0) {
                    $aliveCount = 0
                    $minX = 999; $maxX = -1; $maxY = -1
                    foreach ($a in $aliens) {
                        if ($a.alive) {
                            $aliveCount++
                            if ($a.x -lt $minX) { $minX = $a.x }
                            if ($a.x -gt $maxX) { $maxX = $a.x }
                            if ($a.y -gt $maxY) { $maxY = $a.y }
                        }
                    }
                    if ($aliveCount -eq 0) {
                        $wave++
                        $score += 100
                        $stepEvery = [Math]::Max(5, 12 - $wave)
                        script:New-InvaderWave -aliens $aliens -wave $wave
                        Play-Sfx -Freq 520 -Ms 60; Play-Sfx -Freq 780 -Ms 80
                    } else {
                        $edge = $false
                        if ($dirR -and ($maxX + 2) -ge ($bw - 1)) { $edge = $true }
                        if (-not $dirR -and ($minX - 1) -le 0) { $edge = $true }
                        if ($edge) {
                            $dirR = -not $dirR
                            foreach ($a in $aliens) { if ($a.alive) { $a.y++ } }
                            if ($maxY -ge ($bh - 3)) { $lives--; if ($lives -le 0) { $running = $false } }
                        } else {
                            foreach ($a in $aliens) { if ($a.alive) { if ($dirR) { $a.x++ } else { $a.x-- } } }
                        }
                        # random bomb
                        if ((Get-Random -Maximum 100) -lt 30) {
                            $shooters = @($aliens | Where-Object { $_.alive })
                            if ($shooters.Count -gt 0) {
                                $sh = $shooters[(Get-Random -Maximum $shooters.Count)]
                                $bombs += @{ x = $sh.x; y = $sh.y }
                            }
                        }
                    }
                }

                # move bombs
                $newBo = @()
                foreach ($bo in $bombs) {
                    $bo.y += 1
                    if ($bo.y -lt $bh) {
                        if (($frame % 2) -eq 0 -and [Math]::Abs($bo.x - $shipX) -le 1 -and $bo.y -ge ($bh - 2)) {
                            $lives--
                            Play-Sfx -Freq 110 -Ms 120
                            if ($lives -le 0) { $running = $false; $newBo += $bo } else { $shipX = [int]($bw / 2) }
                        } else { $newBo += $bo }
                    }
                }
                $bombs = $newBo

                # bullet hits aliens (tolerance 1 row: bullets fly 2 rows/frame,
                # without it they can tunnel straight through a formation row)
                foreach ($b in $bullets) {
                    foreach ($a in $aliens) {
                        if ($a.alive -and [Math]::Abs($a.x - $b.x) -le 1 -and [Math]::Abs($a.y - $b.y) -le 1) {
                            $a.alive = $false
                            $b.y = -99
                            $score += (3 - $a.kind) * 10
                            Play-Sfx -Freq 220 -Ms 30
                        }
                    }
                }
                $bullets = @($bullets | Where-Object { $_.y -ge 0 })

                # draw
                Clear-Frame
                Set-GameHeader -Title $script:InvadersTitle -Score $score -Right ('wave {0}  {1}{2}' -f $wave, $script:ChHeart, $lives)
                Draw-Box -X ($bx - 1) -Y ($by - 1) -W ($bw + 2) -H ($bh + 2) -Fg 'wall'
                foreach ($a in $aliens) {
                    if ($a.alive) {
                        $ch = $script:ChMed
                        $col = @('purple','cyan','green')[$a.kind]
                        Set-Cell -X ($bx + $a.x) -Y ($by + $a.y) -Char $ch -Fg $col
                        Set-Cell -X ($bx + $a.x + 1) -Y ($by + $a.y) -Char $ch -Fg $col
                    }
                }
                foreach ($b in $bullets) { Set-Cell -X ($bx + $b.x) -Y ($by + $b.y) -Char '|' -Fg 'yellow' }
                foreach ($bo in $bombs) { Set-Cell -X ($bx + $bo.x) -Y ($by + $bo.y) -Char '!' -Fg 'red' }
                Set-Text -X ($bx + $shipX - 1) -Y ($by + $bh - 1) -Text ('/' + $script:ChFull + '\') -Fg 'white'
                Set-TextCentered -Y ($by + $bh + 2) -Text 'arrows move - SPACE shoots - q menu' -Fg 'dim'
                Show-Frame
                Wait-Frame 50
            }
        } catch [ArcadeSelfTestDone] { throw }

        if (-not (Complete-Game -GameId 'invaders' -GameName $script:InvadersTitle -Score $score)) { break }
    }
}
