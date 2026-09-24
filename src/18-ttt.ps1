# ============================================================
#  TIC-TAC-TOE (vs CPU)
# ============================================================
$script:TttTitle = 'Tic-Tac-Toe'
$script:TttDesc  = 'beat the CPU - loss ends the run'

function Start-Ttt {
    while ($true) {
        Start-Frames
        Start-Screen -H 30
        $score = 0
        $round = 1

        function script:TttWinner {
            param([string[]]$b)
            $lines = @(@(0,1,2),@(3,4,5),@(6,7,8),@(0,3,6),@(1,4,7),@(2,5,8),@(0,4,8),@(2,4,6))
            foreach ($l in $lines) {
                if ($b[$l[0]] -ne ' ' -and $b[$l[0]] -eq $b[$l[1]] -and $b[$l[1]] -eq $b[$l[2]]) { return $b[$l[0]] }
            }
            $open = @($b | Where-Object { $_ -eq ' ' })
            if ($open.Count -eq 0) { return 'D' }
            return ' '
        }
        function script:TttCpuMove {
            param([string[]]$b)
            $empties = @()
            for ($i = 0; $i -lt 9; $i++) { if ($b[$i] -eq ' ') { $empties += $i } }
            # 1) win, 2) block
            foreach ($me in @('O', 'X')) {
                foreach ($i in $empties) {
                    $t = $b.Clone()
                    $t[$i] = $me
                    if ((script:TttWinner -b $t) -eq $me) { return $i }
                }
            }
            if ($b[4] -eq ' ') { return 4 }
            $corners = @(0, 2, 6, 8) | Where-Object { $b[$_] -eq ' ' }
            if ($corners.Count -gt 0) { return $corners[(Get-Random -Maximum $corners.Count)] }
            return $empties[(Get-Random -Maximum $empties.Count)]
        }
        function script:Draw-TttBoard {
            param([string[]]$b, [int]$cur, [string]$Msg, [string]$MsgCol)
            Clear-Frame
            Set-GameHeader -Title $script:TttTitle -Score $score -Right ('round ' + $round)
            $ox = 28; $oy = 9
            for ($r = 0; $r -lt 3; $r++) {
                for ($c = 0; $c -lt 3; $c++) {
                    $x = $ox + $c * 9; $y = $oy + $r * 4
                    $col = 'bg2'; $fg = 'fg'
                    if ($r * 3 + $c -eq $cur) { $col = 'accent'; $fg = 'ink' }
                    for ($yy = $y; $yy -lt ($y + 3); $yy++) {
                        for ($xx = $x; $xx -lt ($x + 8); $xx++) { Set-Cell -X $xx -Y $yy -Char ' ' -Fg $fg -Bg $col }
                    }
                    $v = $b[$r * 3 + $c]
                    if ($v -ne ' ') { Set-Text -X ($x + 3) -Y ($y + 1) -Text $v -Fg $(if ($v -eq 'X') { 'green' } else { 'red' }) -Bg $col }
                    else { Set-Text -X ($x + 3) -Y ($y + 1) -Text ([string]($r * 3 + $c + 1)) -Fg 'dim' -Bg $col }
                }
            }
            Set-TextCentered -Y 22 -Text $Msg -Fg $MsgCol
            Set-TextCentered -Y 24 -Text 'arrows + enter, or 1-9 - q menu' -Fg 'dim'
            Show-Frame
        }

        try {
            $sessionOver = $false
            while (-not $sessionOver) {
                $b = @(' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ')
                $cur = 4
                $msg = 'your move (X)'
                $msgCol = 'dim'
                $result = ' '
                while ($true) {
                    Wait-Frame 16
                    script:Draw-TttBoard -b $b -cur $cur -Msg $msg -MsgCol $msgCol
                    $k = Wait-RealKey
                    if ($script:Headless) { $k = [string](1 + ($script:TestFrames % 9)) }   # cycle digits 1-9: always reaches every cell, game always terminates
                    if ($k -eq 'Q' -or $k -eq 'Escape') { return }
                    $moved = $false
                    switch ($k) {
                        'UpArrow'    { if ($cur -ge 3) { $cur -= 3; $moved = $true } }
                        'DownArrow'  { if ($cur -le 5) { $cur += 3; $moved = $true } }
                        'LeftArrow'  { if ($cur % 3 -gt 0) { $cur--; $moved = $true } }
                        'RightArrow' { if ($cur % 3 -lt 2) { $cur++; $moved = $true } }
                        { $_ -in @('Enter', 'Space') } {
                            if ($b[$cur] -eq ' ') {
                                $b[$cur] = 'X'
                                Play-Sfx -Freq 440 -Ms 25
                                $w = script:TttWinner -b $b
                                if ($w -ne ' ') { $result = $w; break }
                                $b[(script:TttCpuMove -b $b)] = 'O'
                                Play-Sfx -Freq 330 -Ms 25
                                $w = script:TttWinner -b $b
                                if ($w -ne ' ') { $result = $w; break }
                                $msg = 'your move (X)'
                            } else { $msg = 'occupied - pick another'; $msgCol = 'yellow' }
                        }
                        default {
                            if ($k -match '^[1-9]$') {
                                $idx = [int]$k - 1
                                if ($b[$idx] -eq ' ') {
                                    $cur = $idx
                                    $b[$idx] = 'X'
                                    Play-Sfx -Freq 440 -Ms 25
                                    $w = script:TttWinner -b $b
                                    if ($w -ne ' ') { $result = $w; break }
                                    $b[(script:TttCpuMove -b $b)] = 'O'
                                    Play-Sfx -Freq 330 -Ms 25
                                    $w = script:TttWinner -b $b
                                    if ($w -ne ' ') { $result = $w; break }
                                    $msg = 'your move (X)'
                                } else { $msg = 'occupied - pick another'; $msgCol = 'yellow' }
                            }
                        }
                    }
                    if ($result -ne ' ') { break }
                }

                if ($result -eq 'X') {
                    $score += 100
                    $round++
                    if ($script:Headless) { $sessionOver = $true }   # keep the smoke test finite
                    $msg = 'you win! next round...'
                    script:Draw-TttBoard -b $b -cur $cur -Msg $msg -MsgCol 'green'
                    Play-Sfx -Freq 660 -Ms 60; Play-Sfx -Freq 880 -Ms 80
                    Arcade-Sleep -Ms 900
                } elseif ($result -eq 'D') {
                    $score += 30
                    if ($script:Headless) { $sessionOver = $true }   # keep the smoke test finite
                    $msg = 'draw! replaying...'
                    script:Draw-TttBoard -b $b -cur $cur -Msg $msg -MsgCol 'yellow'
                    Arcade-Sleep -Ms 900
                } else {
                    $msg = 'CPU wins - run over'
                    script:Draw-TttBoard -b $b -cur $cur -Msg $msg -MsgCol 'red'
                    Play-Sfx -Freq 200 -Ms 120; Play-Sfx -Freq 150 -Ms 160
                    Arcade-Sleep -Ms 1100
                    $sessionOver = $true
                }
            }
        } catch [ArcadeSelfTestDone] { throw }

        if (-not (Complete-Game -GameId 'ttt' -GameName $script:TttTitle -Score $score)) { break }
    }
}
