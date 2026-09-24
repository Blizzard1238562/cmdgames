# ============================================================
#  FLAPPY BIRD
# ============================================================
$script:FlappyTitle = 'Flappy'
$script:FlappyDesc  = 'one button, flap through the gaps'

function Start-Flappy {
    while ($true) {
        Start-Frames
        Start-Screen -H 30
        $bw = 60; $bh = 20
        $bx = 10; $by = 6
        $birdY = [double]([int]($bh / 2))
        $vel = 0.0
        $pipes = @()      # @{x, gap}
        $score = 0
        $frame = 0
        $gravity = 0.35
        $flapV = -1.6
        $speed = 0.7
        $gap = 7

        for ($i = 0; $i -lt 3; $i++) { $pipes += @{ x = ($bw + 10 + $i * 24); gap = (Get-Random -Minimum 3 -Maximum ($bh - $gap - 4)) } }

        try {
            $running = $true
            while ($running) {
                $frame++
                $keys = Get-KeysPressed
                if (Mute-ToggleRequested $keys) { }
                if ($keys -contains 'Q') { return }
                if ($keys -contains 'Space' -or $keys -contains 'UpArrow' -or $keys -contains 'W') {
                    $vel = $flapV
                    Play-Sfx -Freq 500 -Ms 20
                }

                $vel += $gravity
                $birdY += $vel

                foreach ($p in $pipes) { $p.x -= $speed }
                if ($pipes[0].x -lt -3) {
                    $pipes.RemoveAt(0)
                    $lastX = $pipes[$pipes.Count - 1].x
                    $pipes += @{ x = $lastX + 24; gap = (Get-Random -Minimum 3 -Maximum ($bh - $gap - 4)) }
                }

                # scoring
                foreach ($p in $pipes) {
                    if (-not $p.scored -and $p.x -lt 4) { $p.scored = $true; $score++; Play-Sfx -Freq 700 -Ms 30 }
                }

                # collisions
                if ($birdY -ge ($bh - 1) -or $birdY -lt 0) { $running = $false; Play-Sfx -Freq 120 -Ms 150 }
                foreach ($p in $pipes) {
                    if ($p.x -lt 5 -and $p.x -gt 2) {   # pipe occupies x..x+1, bird is at x=4
                        if ($birdY -lt $p.gap -or $birdY -gt ($p.gap + $gap)) { $running = $false; Play-Sfx -Freq 120 -Ms 150 }
                    }
                }

                Clear-Frame
                Set-GameHeader -Title $script:FlappyTitle -Score $score
                Draw-Box -X ($bx - 1) -Y ($by - 1) -W ($bw + 2) -H ($bh + 2) -Fg 'wall'
                $py = [int][Math]::Floor($birdY)
                foreach ($p in $pipes) {
                    $px = [int][Math]::Floor($p.x)
                    for ($y = 0; $y -lt $bh; $y++) {
                        if ($y -lt $p.gap -or $y -gt ($p.gap + $gap)) {
                            Set-Cell -X ($bx + $px) -Y ($by + $y) -Char $script:ChFull -Fg 'green'
                            if ($px + 1 -lt $bw) { Set-Cell -X ($bx + $px + 1) -Y ($by + $y) -Char $script:ChFull -Fg 'green' }
                        }
                    }
                }
                Set-Cell -X ($bx + 4) -Y ($by + $py) -Char $script:ChStar -Fg 'yellow'
                Show-Frame
                Wait-Frame 50
            }
        } catch [ArcadeSelfTestDone] { throw }

        if (-not (Complete-Game -GameId 'flappy' -GameName $script:FlappyTitle -Score $score)) { break }
    }
}
