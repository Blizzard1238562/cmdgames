# ============================================================
#  FROGGER
# ============================================================
$script:FroggerTitle = 'Frogger'
$script:FroggerDesc  = 'hop across road and river, reach the top'

function Start-Frogger {
    while ($true) {
        Start-Frames
        Start-Screen -H 30
        $bw = 50; $bh = 18
        $bx = 15; $by = 7
        $goalRow = 0
        $riverRows = 1..4
        $roadRows = 6..9
        $medianRow = 5
        $lives = 3
        $score = 0
        $level = 1

        function script:New-FrogLane {
            param([int]$Y, [int]$Dir, [double]$Speed, [int]$Len, [int]$Count, [switch]$Log)
            $items = @()
            $spacing = [int](($bw + 8) / $Count)
            for ($i = 0; $i -lt $Count; $i++) {
                $items += @{ x = -8 + $i * $spacing + (Get-Random -Maximum 4); len = $Len }
            }
            return @{ y = $Y; dir = $Dir; speed = $Speed; items = $items; log = [bool]$Log }
        }

        function script:Build-FrogLanes {
            param([int]$Level)
            $lanes = @()
            $sp = 0.25 + 0.08 * [Math]::Min(6, $Level)
            $lanes += script:New-FrogLane -Y 4 -Dir (-1) -Speed ($sp + 0.05) -Len 5 -Count 3 -Log
            $lanes += script:New-FrogLane -Y 3 -Dir 1    -Speed ($sp + 0.15) -Len 4 -Count 3 -Log
            $lanes += script:New-FrogLane -Y 2 -Dir (-1) -Speed ($sp + 0.25) -Len 6 -Count 2 -Log
            $lanes += script:New-FrogLane -Y 1 -Dir 1    -Speed ($sp + 0.35) -Len 4 -Count 3 -Log
            $lanes += script:New-FrogLane -Y 9 -Dir 1    -Speed ($sp + 0.10) -Len 3 -Count 3
            $lanes += script:New-FrogLane -Y 8 -Dir (-1) -Speed ($sp + 0.20) -Len 2 -Count 4
            $lanes += script:New-FrogLane -Y 7 -Dir 1    -Speed ($sp + 0.30) -Len 3 -Count 3
            $lanes += script:New-FrogLane -Y 6 -Dir (-1) -Speed ($sp + 0.40) -Len 2 -Count 4
            return ,$lanes
        }
        $lanes = script:Build-FrogLanes -Level $level

        function script:Reset-Frog {
            $script:FrogX = [int]($bw / 2)
            $script:FrogY = $bh - 1
        }
        script:Reset-Frog

        try {
            $running = $true
            while ($running) {
                $keys = Get-KeysPressed
                if (Mute-ToggleRequested $keys) { }
                if ($keys -contains 'Q') { return }
                foreach ($k in $keys) {
                    switch ($k) {
                        'UpArrow'    { if ($script:FrogY -gt 0) { $script:FrogY--; Play-Sfx -Freq 400 -Ms 15 } }
                        'DownArrow'  { if ($script:FrogY -lt ($bh - 1)) { $script:FrogY++; Play-Sfx -Freq 300 -Ms 15 } }
                        'LeftArrow'  { if ($script:FrogX -gt 0) { $script:FrogX-- } }
                        'RightArrow' { if ($script:FrogX -lt ($bw - 1)) { $script:FrogX++ } }
                        'W' { if ($script:FrogY -gt 0) { $script:FrogY-- } }
                        'S' { if ($script:FrogY -lt ($bh - 1)) { $script:FrogY++ } }
                        'A' { if ($script:FrogX -gt 0) { $script:FrogX-- } }
                        'D' { if ($script:FrogX -lt ($bw - 1)) { $script:FrogX++ } }
                    }
                }

                # move lanes
                foreach ($lane in $lanes) {
                    foreach ($it in $lane.items) {
                        $it.x += $lane.speed * $lane.dir
                        if ($it.x -gt ($bw + 8)) { $it.x = -$it.len - 6 }
                        if (($it.x + $it.len) -lt -8) { $it.x = $bw + 6 }
                    }
                }

                $fx = $script:FrogX; $fy = $script:FrogY
                $dead = $false

                if ($roadRows -contains $fy) {
                    $lane = $lanes | Where-Object { $_.y -eq $fy }
                    foreach ($it in $lane.items) {
                        if ($fx -ge [int][Math]::Ceiling($it.x) -and $fx -lt ([int][Math]::Ceiling($it.x) + $it.len)) { $dead = $true }
                    }
                } elseif ($riverRows -contains $fy) {
                    $onLog = $false
                    $lane = $lanes | Where-Object { $_.y -eq $fy }
                    foreach ($it in $lane.items) {
                        if ($fx -ge [int][Math]::Ceiling($it.x) -and $fx -lt ([int][Math]::Ceiling($it.x) + $it.len)) {
                            $onLog = $true
                            $script:FrogX = [double]$script:FrogX + ($lane.speed * $lane.dir)
                        }
                    }
                    if (-not $onLog) { $dead = $true }
                    if ($script:FrogX -lt 0 -or $script:FrogX -ge $bw) { $dead = $true }
                } elseif ($fy -eq $goalRow) {
                    $score += 200
                    $level++
                    $lanes = script:Build-FrogLanes -Level $level
                    script:Reset-Frog
                    Play-Sfx -Freq 520 -Ms 50; Play-Sfx -Freq 780 -Ms 70
                    continue
                }

                if ($dead) {
                    $lives--
                    Play-Sfx -Freq 110 -Ms 140
                    if ($lives -le 0) { $running = $false } else { script:Reset-Frog }
                }

                # draw
                Clear-Frame
                Set-GameHeader -Title $script:FroggerTitle -Score $score -Right ('lvl {0}  {1}{2}' -f $level, $script:ChHeart, $lives)
                Draw-Box -X ($bx - 1) -Y ($by - 1) -W ($bw + 2) -H ($bh + 2) -Fg 'wall'
                for ($x = 0; $x -lt $bw; $x++) { Set-Cell -X ($bx + $x) -Y ($by + 0) -Char $script:ChDot -Fg 'yellow' }
                for ($x = 0; $x -lt $bw; $x++) { Set-Cell -X ($bx + $x) -Y ($by + $medianRow) -Char ' ' -Bg 'bg2' }
                foreach ($lane in $lanes) {
                    foreach ($it in $lane.items) {
                        $sx = [int][Math]::Ceiling($it.x)
                        for ($i = 0; $i -lt $it.len; $i++) {
                            $px = $sx + $i
                            if ($px -ge 0 -and $px -lt $bw) {
                                if ($lane.log) { Set-Cell -X ($bx + $px) -Y ($by + $lane.y) -Char $script:ChBH -Fg 'orange' }
                                else { Set-Cell -X ($bx + $px) -Y ($by + $lane.y) -Char $script:ChMed -Fg 'red' }
                            }
                        }
                    }
                }
                $fxi = [int][Math]::Round($script:FrogX)
                Set-Cell -X ($bx + $fxi) -Y ($by + $script:FrogY) -Char $script:ChDiam -Fg 'green'
                Show-Frame
                Wait-Frame 50
            }
        } catch [ArcadeSelfTestDone] { throw }

        if (-not (Complete-Game -GameId 'frogger' -GameName $script:FroggerTitle -Score $score)) { break }
    }
}
