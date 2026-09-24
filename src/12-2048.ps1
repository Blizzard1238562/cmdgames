# ============================================================
#  2048
# ============================================================
$script:G2048Title = '2048'
$script:G2048Desc  = 'slide and merge tiles, reach 2048'

function Start-G2048 {
    while ($true) {
        Start-Frames
        Start-Screen -H 30
        $n = 4
        $cells = New-Object 'int[]' 16
        $score = 0
        $won = $false

        function script:Add-G2048Tile {
            param([int[]]$cells)
            $empty = @()
            for ($i = 0; $i -lt 16; $i++) { if ($cells[$i] -eq 0) { $empty += $i } }
            if ($empty.Count -eq 0) { return $false }
            $cells[$empty[(Get-Random -Maximum $empty.Count)]] = $(if ((Get-Random -Maximum 10) -eq 0) { 4 } else { 2 })
            return $true
        }
        function script:G2048Slide {
            # slides one row (given as indices into $cells) left; returns gained score
            param([int[]]$cells, [int[]]$idx)
            $vals = @()
            foreach ($i in $idx) { if ($cells[$i] -ne 0) { $vals += $cells[$i]; $cells[$i] = 0 } }
            $gained = 0
            $out = @()
            for ($i = 0; $i -lt $vals.Count; $i++) {
                if ($i -lt ($vals.Count - 1) -and $vals[$i] -eq $vals[$i + 1]) {
                    $out += ($vals[$i] * 2)
                    $gained += $vals[$i] * 2
                    $i++
                } else {
                    $out += $vals[$i]
                }
            }
            for ($i = 0; $i -lt $out.Count; $i++) { $cells[$idx[$i]] = $out[$i] }
            return $gained
        }
        function script:G2048Move {
            param([int[]]$cells, [string]$dir)
            $total = 0
            for ($r = 0; $r -lt 4; $r++) {
                $idx = @()
                for ($c = 0; $c -lt 4; $c++) {
                    switch ($dir) {
                        'left'  { $idx += ,($r * 4 + $c) }
                        'right' { $idx += ,(3 - $c + $r * 4) }
                        'up'    { $idx += ,($c * 4 + $r) }
                        'down'  { $idx += ,((3 - $c) * 4 + $r) }
                    }
                }
                $total += script:G2048Slide -cells $cells -idx ([int[]]$idx)
            }
            return $total
        }
        function script:G2048CanMove {
            param([int[]]$cells)
            for ($i = 0; $i -lt 16; $i++) { if ($cells[$i] -eq 0) { return $true } }
            for ($r = 0; $r -lt 4; $r++) {
                for ($c = 0; $c -lt 4; $c++) {
                    $v = $cells[$r * 4 + $c]
                    if ($c -lt 3 -and $cells[$r * 4 + $c + 1] -eq $v) { return $true }
                    if ($r -lt 3 -and $cells[($r + 1) * 4 + $c] -eq $v) { return $true }
                }
            }
            return $false
        }
        function script:G2048TileColor {
            param([int]$v)
            switch ($v) {
                0 { return 'bg2' } 2 { return 'dim' } 4 { return 'fg' }
                8 { return 'accent' } 16 { return 'green' } 32 { return 'cyan' }
                64 { return 'blue' } 128 { return 'purple' } 256 { return 'orange' }
                512 { return 'yellow' } 1024 { return 'red' } default { return 'white' }
            }
        }

        [void](script:Add-G2048Tile -cells $cells)
        [void](script:Add-G2048Tile -cells $cells)
        $ox = 22; $oy = 8   # top-left of tile grid

        try {
            $running = $true
            while ($running) {
                $moved = $false
                if (-not $script:Headless) {
                    Clear-Frame
                    Set-GameHeader -Title $script:G2048Title -Score $score -Right 'q menu'
                    Set-TextCentered -Y 5 -Text 'merge tiles to make 2048' -Fg 'dim'
                    Draw-Box -X ($ox - 2) -Y ($oy - 2) -W 36 -H 19 -Fg 'wall'
                    for ($r = 0; $r -lt 4; $r++) {
                        for ($c = 0; $c -lt 4; $c++) {
                            $v = $cells[$r * 4 + $c]
                            $x = $ox + $c * 8; $y = $oy + $r * 4
                            $col = script:G2048TileColor $v
                            for ($yy = $y; $yy -lt ($y + 3); $yy++) {
                                for ($xx = $x; $xx -lt ($x + 7); $xx++) { Set-Cell -X $xx -Y $yy -Char ' ' -Fg $col -Bg $col }
                            }
                            $t = ''
                            if ($v -gt 0) {
                                $t = [string]$v
                                if ($t.Length -gt 4) { $t = '2k+' }
                            }
                            Set-Text -X ($x + [int]((7 - $t.Length) / 2)) -Y ($y + 1) -Text $t -Fg $(if ($v -ge 8) { 'ink' } else { 'bg' }) -Bg $col
                        }
                    }
                    Set-TextCentered -Y 28 -Text 'arrows to slide - q menu' -Fg 'dim'
                    Show-Frame
                }

                $k = Wait-RealKey
                switch ($k) {
                    'LeftArrow'  { $score += script:G2048Move -cells $cells -dir 'left';  $moved = $true }
                    'RightArrow' { $score += script:G2048Move -cells $cells -dir 'right'; $moved = $true }
                    'UpArrow'    { $score += script:G2048Move -cells $cells -dir 'up';    $moved = $true }
                    'DownArrow'  { $score += script:G2048Move -cells $cells -dir 'down';  $moved = $true }
                    'A' { $score += script:G2048Move -cells $cells -dir 'left';  $moved = $true }
                    'D' { $score += script:G2048Move -cells $cells -dir 'right'; $moved = $true }
                    'W' { $score += script:G2048Move -cells $cells -dir 'up';    $moved = $true }
                    'S' { $score += script:G2048Move -cells $cells -dir 'down';  $moved = $true }
                    'Q' { return }
                    'Escape' { return }
                }
                if ($script:Headless) { $moved = ($script:TestFrames % 2 -eq 0) }

                if ($moved) {
                    if (-not $script:Headless) { Play-Sfx -Freq 300 -Ms 20 }
                    [void](script:Add-G2048Tile -cells $cells)
                    foreach ($v in $cells) { if ($v -ge 2048) { $won = $true } }
                    if (-not (script:G2048CanMove -cells $cells)) { $running = $false }
                    if ($won) { $running = $false }
                }
                Wait-Frame 20
            }
        } catch [ArcadeSelfTestDone] { throw }

        $note = ''
        if ($won) { $note = 'you made 2048!' } elseif (-not (script:G2048CanMove -cells $cells)) { $note = 'no moves left' }
        if (-not (Complete-Game -GameId '2048' -GameName $script:G2048Title -Score $score -Note $note)) { break }
    }
}
