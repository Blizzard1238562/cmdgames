# ============================================================
#  TETRIS
# ============================================================
$script:TetrisTitle = 'Tetris'
$script:TetrisDesc  = 'stack blocks, clear lines, level up'

$script:TetrisShapes = @{
    'I' = @(@(0,1),@(1,1),@(2,1),@(3,1)); 'O' = @(@(1,0),@(2,0),@(1,1),@(2,1))
    'T' = @(@(1,0),@(0,1),@(1,1),@(2,1)); 'S' = @(@(1,0),@(2,0),@(0,1),@(1,1))
    'Z' = @(@(0,0),@(1,0),@(1,1),@(2,1)); 'J' = @(@(0,0),@(0,1),@(1,1),@(2,1))
    'L' = @(@(2,0),@(0,1),@(1,1),@(2,1))
}
$script:TetrisColors = @{ 'I'='cyan'; 'O'='yellow'; 'T'='purple'; 'S'='green'; 'Z'='red'; 'J'='blue'; 'L'='orange' }

function Get-TetrisRotated {
    param([string]$Kind, [int]$Rot)
    $base = $script:TetrisShapes[$Kind]
    $out = @()
    foreach ($p in $base) {
        $x = $p[0]; $y = $p[1]
    # NOTE: the subtractions MUST be parenthesized. In PowerShell an array
    # literal @(a - b, c) parses as a - (b, c), i.e. number minus array,
    # which throws op_Subtraction at runtime.
    switch ($Rot % 4) {
        0 { $out += ,@($x, $y) }
        1 { $out += ,@((3 - $y), $x) }
        2 { $out += ,@((3 - $x), (3 - $y)) }
        3 { $out += ,@($y, (3 - $x)) }
    }
    }
    return ,$out
}

function Start-Tetris {
    while ($true) {
        Start-Frames
        Start-Screen -H 30
        # board 12 wide x 20 tall, drawn 2 chars per cell
        $bw = 12; $bh = 20
        $ox = 26; $oy = 5
        $grid = @{ }   # "x,y" -> color name
        $bag = New-Object System.Collections.Generic.List[string]
        $score = 0; $lines = 0; $level = 1
        $dropMs = 500
        $gameOver = $false

        function script:New-TetrisPiece {
            param($bag)
            if ($bag.Count -eq 0) {
                foreach ($k in @('I','O','T','S','Z','J','L')) { [void]$bag.Add([string]$k) }
                # simple shuffle
                for ($i = $bag.Count - 1; $i -gt 0; $i--) {
                    $j = Get-Random -Maximum ($i + 1)
                    $tmp = $bag[$i]; $bag[$i] = $bag[$j]; $bag[$j] = $tmp
                }
            }
            $kind = $bag[0]; $bag.RemoveAt(0)
            # refill right away so the NEXT-piece preview always has an item
            if ($bag.Count -eq 0) {
                foreach ($k in @('I','O','T','S','Z','J','L')) { [void]$bag.Add([string]$k) }
                for ($i = $bag.Count - 1; $i -gt 0; $i--) {
                    $j = Get-Random -Maximum ($i + 1)
                    $tmp = $bag[$i]; $bag[$i] = $bag[$j]; $bag[$j] = $tmp
                }
            }
            return @{ kind = $kind; rot = 0; x = 4; y = -1 }
        }
        $piece = script:New-TetrisPiece -bag $bag

        function script:TetrisFits {
            param($piece, $dx, $dy, $rot, $grid, $bw, $bh)
            $cells = Get-TetrisRotated -Kind $piece.kind -Rot $rot
            foreach ($c in $cells) {
                $x = $piece.x + $c[0] + $dx; $y = $piece.y + $c[1] + $dy
                if ($x -lt 0 -or $x -ge $bw -or $y -ge $bh) { return $false }
                if ($y -ge 0 -and $grid.ContainsKey("$x,$y")) { return $false }
            }
            return $true
        }
        function script:LockPiece {
            param($piece, $grid)
            $cells = Get-TetrisRotated -Kind $piece.kind -Rot $piece.rot
            foreach ($c in $cells) {
                $x = $piece.x + $c[0]; $y = $piece.y + $c[1]
                if ($y -lt 0) { return $true }  # locked above top = over
                $grid["$x,$y"] = $piece.kind
            }
            return $false
        }
        function script:ClearLines {
            param($grid, $bw, $bh)
            $cleared = 0
            for ($y = ($bh - 1); $y -ge 0; $y--) {
                $full = $true
                for ($x = 0; $x -lt $bw; $x++) { if (-not $grid.ContainsKey("$x,$y")) { $full = $false; break } }
                if ($full) {
                    $cleared++
                    for ($yy = $y; $yy -gt 0; $yy--) {
                        for ($x = 0; $x -lt $bw; $x++) {
                            if ($grid.ContainsKey("$x,$($yy-1)")) { $grid["$x,$yy"] = $grid["$x,$($yy-1)"] } else { $grid.Remove("$x,$yy") }
                        }
                    }
                    for ($x = 0; $x -lt $bw; $x++) { $grid.Remove("$x,0") }
                    $y++ # re-check same row
                }
            }
            return $cleared
        }

        $tick = 0
        try {
            while ($true) {
                $keys = Get-KeysPressed
                if (Mute-ToggleRequested $keys) { }
                if ($keys -contains 'Q') { return }

                foreach ($k in $keys) {
                    switch ($k) {
                        'LeftArrow'  { if (script:TetrisFits -piece $piece -dx (-1) -dy 0 -rot $piece.rot -grid $grid -bw $bw -bh $bh) { $piece.x--; Play-Sfx -Freq 220 -Ms 15 } }
                        'RightArrow' { if (script:TetrisFits -piece $piece -dx 1   -dy 0 -rot $piece.rot -grid $grid -bw $bw -bh $bh) { $piece.x++; Play-Sfx -Freq 220 -Ms 15 } }
                        'DownArrow'  { if (script:TetrisFits -piece $piece -dx 0 -dy 1 -rot $piece.rot -grid $grid -bw $bw -bh $bh) { $piece.y++; $score += 1 } }
                        'UpArrow'    { if (script:TetrisFits -piece $piece -dx 0 -dy 0 -rot ($piece.rot + 1) -grid $grid -bw $bw -bh $bh) { $piece.rot++; Play-Sfx -Freq 330 -Ms 20 } }
                        'Space'      { while (script:TetrisFits -piece $piece -dx 0 -dy 1 -rot $piece.rot -grid $grid -bw $bw -bh $bh) { $piece.y++; $score += 2 }; Play-Sfx -Freq 180 -Ms 40 }
                    }
                }

                $tick++
                $dropped = $false
                if ($script:Headless -or ($tick % [Math]::Max(1, [int]($dropMs / 50)) -eq 0)) {
                    if (script:TetrisFits -piece $piece -dx 0 -dy 1 -rot $piece.rot -grid $grid -bw $bw -bh $bh) {
                        $piece.y++
                    } else {
                        $over = script:LockPiece -piece $piece -grid $grid
                        $n = script:ClearLines -grid $grid -bw $bw -bh $bh
                        if ($n -gt 0) {
                            $lines += $n
                            $score += @(0, 100, 300, 500, 800)[$n] * $level
                            $level = 1 + [int]($lines / 8)
                            $dropMs = [Math]::Max(120, 500 - (($level - 1) * 45))
                            Play-Sfx -Freq 520 -Ms 50; Play-Sfx -Freq 700 -Ms 60
                        } else {
                            Play-Sfx -Freq 140 -Ms 40
                        }
                        if ($over) { $gameOver = $true; break }
                        $piece = script:New-TetrisPiece -bag $bag
                        if (-not (script:TetrisFits -piece $piece -dx 0 -dy 0 -rot $piece.rot -grid $grid -bw $bw -bh $bh)) { $gameOver = $true; break }
                    }
                    $dropped = $true
                }
                if (-not $dropped) { Start-Sleep -Milliseconds 50 }

                # draw
                Clear-Frame
                Set-GameHeader -Title $script:TetrisTitle -Score $score -Right ('lvl {0}  lines {1}' -f $level, $lines)
                Draw-Box -X ($ox - 1) -Y ($oy - 1) -W ($bw * 2 + 2) -H ($bh + 2) -Fg 'wall'
                foreach ($kv in $grid.GetEnumerator()) {
                    $p = $kv.Key.Split(','); $x = [int]$p[0]; $y = [int]$p[1]
                    Set-Text -X ($ox + $x * 2) -Y ($oy + $y) -Text '[]' -Fg ($script:TetrisColors[$kv.Value])
                }
                $cells = Get-TetrisRotated -Kind $piece.kind -Rot $piece.rot
                foreach ($c in $cells) {
                    $x = $piece.x + $c[0]; $y = $piece.y + $c[1]
                    if ($y -ge 0) { Set-Text -X ($ox + $x * 2) -Y ($oy + $y) -Text '[]' -Fg ($script:TetrisColors[$piece.kind]) }
                }
                # next piece preview
                $nx = $ox + $bw * 2 + 4
                Set-Text -X $nx -Y ($oy + 1) -Text 'NEXT' -Fg 'dim'
                $nc = $script:TetrisShapes[$bag[0]]
                if ($nc) { foreach ($c in $nc) { Set-Text -X ($nx + $c[0] * 2) -Y ($oy + 3 + $c[1]) -Text '[]' -Fg ($script:TetrisColors[$bag[0]]) } }
                Set-Text -X $nx -Y ($oy + 8) -Text 'arrows move' -Fg 'dim'
                Set-Text -X $nx -Y ($oy + 9) -Text 'up rotate' -Fg 'dim'
                Set-Text -X $nx -Y ($oy + 10) -Text 'space drop' -Fg 'dim'
                Show-Frame
                Wait-Frame 50
            }
        } catch [ArcadeSelfTestDone] { throw }

        if (-not (Complete-Game -GameId 'tetris' -GameName $script:TetrisTitle -Score $score)) { break }
    }
}
