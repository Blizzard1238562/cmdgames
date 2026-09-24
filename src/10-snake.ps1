# ============================================================
#  SNAKE
# ============================================================
$script:SnakeTitle = 'Snake'
$script:SnakeDesc  = 'eat, grow, do not bite yourself'

function Start-Snake {
    while ($true) {
        Start-Frames
        Start-Screen -H 30
        # board inside a box: 60x22 cells, border at x=9..70, y=5..27
        $bx = 10; $by = 6; $bw = 60; $bh = 20   # playable area (inside border)
        $grid = @{ }
        $snake = New-Object System.Collections.Generic.List[object]
        $sx = $bx + 12; $sy = $by + [int]($bh / 2)
        for ($i = 4; $i -ge 0; $i--) { $snake.Add(@{ x = $sx - $i; y = $sy }) }
        foreach ($s in $snake) { $grid["$($s.x),$($s.y)"] = $true }
        $dir = @{ x = 1; y = 0 }
        $pending = $null
        $food = $null
        $score = 0
        $speedMs = 90
        $grow = 0
        $alive = $true

        function script:Place-SnakeFood {
            param($bx, $by, $bw, $bh, $grid)
            $free = @()
            for ($y = $by; $y -lt ($by + $bh); $y++) {
                for ($x = $bx; $x -lt ($bx + $bw); $x++) {
                    if (-not $grid.ContainsKey("$x,$y")) { $free += ,@($x, $y) }
                }
            }
            if ($free.Count -eq 0) { return $null }
            return $free[(Get-Random -Maximum $free.Count)]
        }
        $food = script:Place-SnakeFood -bx $bx -by $by -bw $bw -bh $bh -grid $grid

        try {
            while ($true) {
                $keys = Get-KeysPressed
                if (Mute-ToggleRequested $keys) { }
                if ($keys -contains 'Q') { return }
                foreach ($k in $keys) {
                    switch ($k) {
                        'UpArrow'    { if ($dir.y -eq 0)  { $pending = @{ x = 0;  y = -1 } } }
                        'DownArrow'  { if ($dir.y -eq 0)  { $pending = @{ x = 0;  y = 1 } } }
                        'LeftArrow'  { if ($dir.x -eq 0)  { $pending = @{ x = -1; y = 0 } } }
                        'RightArrow' { if ($dir.x -eq 0)  { $pending = @{ x = 1;  y = 0 } } }
                        'W' { if ($dir.y -eq 0) { $pending = @{ x = 0;  y = -1 } } }
                        'S' { if ($dir.y -eq 0) { $pending = @{ x = 0;  y = 1 } } }
                        'A' { if ($dir.x -eq 0) { $pending = @{ x = -1; y = 0 } } }
                        'D' { if ($dir.x -eq 0) { $pending = @{ x = 1;  y = 0 } } }
                    }
                }

                # update (only act on direction at tick boundaries)
                if ($null -ne $pending) { $dir = $pending; $pending = $null }
                $head = $snake[0]
                $nx = $head.x + $dir.x
                $ny = $head.y + $dir.y
                if ($nx -lt $bx -or $nx -ge ($bx + $bw) -or $ny -lt $by -or $ny -ge ($by + $bh) -or $grid.ContainsKey("$nx,$ny")) {
                    $alive = $false
                    Play-Sfx -Freq 120 -Ms 180
                    break
                }
                $snake.Insert(0, @{ x = $nx; y = $ny })
                $grid["$nx,$ny"] = $true
                if ($food -ne $null -and $nx -eq $food[0] -and $ny -eq $food[1]) {
                    $score += 10
                    Play-Sfx -Freq 660 -Ms 30
                    $food = script:Place-SnakeFood -bx $bx -by $by -bw $bw -bh $bh -grid $grid
                    if ($score % 50 -eq 0 -and $speedMs -gt 45) { $speedMs -= 6 }
                } else {
                    $tail = $snake[$snake.Count - 1]
                    $grid.Remove("$($tail.x),$($tail.y)")
                    $snake.RemoveAt($snake.Count - 1)
                }

                # draw
                Clear-Frame
                Draw-Box -X ($bx - 1) -Y ($by - 1) -W ($bw + 2) -H ($bh + 2) -Fg 'wall'
                Set-GameHeader -Title $script:SnakeTitle -Score $score -Right ('len ' + $snake.Count)
                if ($food -ne $null) { Set-Cell -X $food[0] -Y $food[1] -Char $script:ChDiam -Fg 'red' }
                for ($i = $snake.Count - 1; $i -ge 0; $i--) {
                    $seg = $snake[$i]
                    $ch = $script:ChFull; $col = 'green'
                    if ($i -eq 0) { $ch = [string][char]0x25CF; $col = 'white' }
                    Set-Cell -X $seg.x -Y $seg.y -Char $ch -Fg $col
                }
                Show-Frame
                Wait-Frame $speedMs
            }
        } catch [ArcadeSelfTestDone] { throw }

        if (-not (Complete-Game -GameId 'snake' -GameName $script:SnakeTitle -Score $score)) { break }
    }
}
