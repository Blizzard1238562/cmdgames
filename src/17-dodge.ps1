# ============================================================
#  DODGE (arena survival)
# ============================================================
$script:DodgeTitle = 'Dodge'
$script:DodgeDesc  = 'survive the arena, dash through the swarm'

function Start-Dodge {
    while ($true) {
        Start-Frames
        Start-Screen -H 30
        $bw = 60; $bh = 20
        $bx = 10; $by = 6
        $px = [int]($bw / 2); $py = [int]($bh / 2)
        $enemies = New-Object System.Collections.Generic.List[object]
        $score = 0
        $frame = 0
        $spawnEvery = 35
        $dashCd = 0
        $invul = 0

        try {
            $running = $true
            while ($running) {
                $frame++
                $keys = Get-KeysPressed
                if (Mute-ToggleRequested $keys) { }
                if ($keys -contains 'Q') { return }

                $dx = 0; $dy = 0
                foreach ($k in $keys) {
                    switch ($k) {
                        'UpArrow'    { $dy = -1 } 'W' { $dy = -1 }
                        'DownArrow'  { $dy = 1 }  'S' { $dy = 1 }
                        'LeftArrow'  { $dx = -1 } 'A' { $dx = -1 }
                        'RightArrow' { $dx = 1 }  'D' { $dx = 1 }
                    }
                }
                $step = 1
                if ($keys -contains 'Space' -and $dashCd -le 0) {
                    $step = 4
                    $dashCd = 25
                    $invul = 10
                    Play-Sfx -Freq 700 -Ms 30
                }
                if ($dashCd -gt 0) { $dashCd-- }
                if ($invul -gt 0) { $invul-- }
                for ($s = 0; $s -lt $step; $s++) {
                    $nx = $px + $dx; $ny = $py + $dy
                    if ($nx -ge 0 -and $nx -lt $bw) { $px = $nx }
                    if ($ny -ge 0 -and $ny -lt $bh) { $py = $ny }
                }

                # spawn
                if (($frame % $spawnEvery) -eq 0) {
                    $side = Get-Random -Maximum 4
                    switch ($side) {
                        0 { $enemies.Add(@{ x = (Get-Random -Maximum $bw); y = 0 }) }
                        1 { $enemies.Add(@{ x = (Get-Random -Maximum $bw); y = ($bh - 1) }) }
                        2 { $enemies.Add(@{ x = 0; y = (Get-Random -Maximum $bh) }) }
                        3 { $enemies.Add(@{ x = ($bw - 1); y = (Get-Random -Maximum $bh) }) }
                    }
                    if ($spawnEvery -gt 12) { $spawnEvery-- }
                }

                # enemies home toward player every 2 frames
                if (($frame % 2) -eq 0) {
                    foreach ($e in $enemies) {
                        if ($e.x -lt $px) { $e.x++ } elseif ($e.x -gt $px) { $e.x-- }
                        if ($e.y -lt $py) { $e.y++ } elseif ($e.y -gt $py) { $e.y-- }
                    }
                }

                # collision
                if ($invul -le 0) {
                    foreach ($e in $enemies) {
                        if ($e.x -eq $px -and $e.y -eq $py) {
                            $running = $false
                            Play-Sfx -Freq 100 -Ms 200
                            break
                        }
                    }
                }

                $score = [int]($frame / 10) * 5

                Clear-Frame
                Set-GameHeader -Title $script:DodgeTitle -Score $score -Right ('dash ' + $(if ($dashCd -le 0) { 'ready' } else { "$($dashCd)" }))
                Draw-Box -X ($bx - 1) -Y ($by - 1) -W ($bw + 2) -H ($bh + 2) -Fg 'wall'
                foreach ($e in $enemies) { Set-Cell -X ($bx + $e.x) -Y ($by + $e.y) -Char $script:ChMed -Fg 'red' }
                $pcol = 'green'; $pch = $script:ChDiam
                if ($invul -gt 0) { $pcol = 'cyan' }
                Set-Cell -X ($bx + $px) -Y ($by + $py) -Char $pch -Fg $pcol
                Set-TextCentered -Y ($by + $bh + 2) -Text 'arrows move - SPACE = quick dash (short cooldown) - q menu' -Fg 'dim'
                Show-Frame
                Wait-Frame 50
            }
        } catch [ArcadeSelfTestDone] { throw }

        if (-not (Complete-Game -GameId 'dodge' -GameName $script:DodgeTitle -Score $score)) { break }
    }
}
