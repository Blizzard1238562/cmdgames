# ============================================================
#  MENU - game registry, logo, hub navigation
# ============================================================

$script:Games = @(
    @{ id='snake';    name='Snake';          desc='eat, grow, survive';            fn='Start-Snake' }
    @{ id='tetris';   name='Tetris';         desc='stack and clear lines';         fn='Start-Tetris' }
    @{ id='2048';     name='2048';           desc='merge tiles to 2048';           fn='Start-G2048' }
    @{ id='invaders'; name='Space Invaders'; desc='shoot the alien fleet';         fn='Start-Invaders' }
    @{ id='flappy';   name='Flappy';         desc='flap through the gaps';         fn='Start-Flappy' }
    @{ id='breakout'; name='Breakout';       desc='smash every brick';             fn='Start-Breakout' }
    @{ id='frogger';  name='Frogger';        desc='hop across road and river';     fn='Start-Frogger' }
    @{ id='dodge';    name='Dodge';          desc='survive the swarm';             fn='Start-Dodge' }
    @{ id='ttt';      name='Tic-Tac-Toe';    desc='beat the CPU';                  fn='Start-Ttt' }
    @{ id='hangman';  name='Hangman';        desc='guess the word';                fn='Start-Hangman' }
)

function Show-MenuLogo {
    param([int]$Y = 6)
    # Pure ASCII (figlet "Big"): must stay ASCII-only so irm|iex works
    # even when PS 5.1 mis-decodes the downloaded bytes as Latin-1.
    $art = @(
        '  _____   _____              _____   _____          _____  ______ ',
        ' |  __ \ / ____|       /\   |  __ \ / ____|   /\   |  __ \|  ____|',
        ' | |__) | (___ ______ /  \  | |__) | |       /  \  | |  | | |__   ',
        ' |  ___/ \___ \______/ /\ \ |  _  /| |      / /\ \ | |  | |  __|  ',
        ' | |     ____) |    / ____ \| | \ \| |____ / ____ \| |__| | |____ ',
        ' |_|    |_____/    /_/    \_\_|  \_\\_____/_/    \_\_____/|______|'
    )
    for ($i = 0; $i -lt $art.Count; $i++) {
        Set-TextCentered -Y ($Y + $i) -Text $art[$i] -Fg 'accent'
    }
}

function Show-HighscoresScreen {
    # One game per page: rank / player / score in clean columns.
    # left/right flips pages, esc goes back. Starts on the game the
    # player selected in the menu.
    param([string]$GameId = 'snake')
    $ids = @('snake','tetris','2048','invaders','flappy','breakout','frogger','dodge','ttt','hangman')
    if ($ids -notcontains $GameId) { $GameId = 'snake' }
    $idx = $ids.IndexOf($GameId)

    while ($true) {
        $gid = $ids[$idx]
        $g = $script:Games | Where-Object { $_.id -eq $gid }
        $online = Get-OnlineScores -GameId $gid
        if ($null -ne $online) {
            $list = @($online)
            $source = 'global leaderboard (live)'
            $srcCol = 'cyan'
        } else {
            $list = @(Get-LocalScores -GameId $gid)
            $source = 'local scores (offline mode)'
            $srcCol = 'dim'
        }

        Clear-Frame
        Draw-Box -X 10 -Y 3 -W 60 -H 24 -Title ' high scores ' -Fg 'accent'

        # pager header:  <  Game Name  >
        Set-Text -X 14 -Y 5 -Text '<' -Fg 'dim'
        Set-Text -X 65 -Y 5 -Text '>' -Fg 'dim'
        Set-TextCentered -Y 5 -Text ([string]$g.name) -Fg 'yellow'
        Set-TextCentered -Y 6 -Text ([string]$g.desc) -Fg 'dim'

        # column headers (score right-aligned with the values below)
        Set-Text -X 16 -Y 8 -Text '#' -Fg 'dim'
        Set-Text -X 20 -Y 8 -Text 'player' -Fg 'dim'
        Set-Text -X 59 -Y 8 -Text 'score' -Fg 'dim'

        if ($list.Count -eq 0) {
            Set-TextCentered -Y 13 -Text 'no scores yet' -Fg 'dim'
            Set-TextCentered -Y 14 -Text 'be the first!' -Fg 'dim'
        } else {
            $y = 9
            for ($i = 0; $i -lt [Math]::Min(10, $list.Count); $i++) {
                $rank = $i + 1
                $name = [string]$list[$i].name
                if ($name.Length -gt 16) { $name = $name.Substring(0, 16) }
                $scoreStr = '{0}' -f [int]$list[$i].score
                $col = 'fg'
                if ($rank -eq 1) { $col = 'yellow' }
                Set-Text -X 16 -Y $y -Text ('{0,2}.' -f $rank) -Fg $col
                Set-Text -X 20 -Y $y -Text $name.PadRight(17) -Fg $col
                Set-Text -X (64 - $scoreStr.Length) -Y $y -Text $scoreStr -Fg $col
                if ($script:PlayerName -and $name -eq $script:PlayerName) {
                    Set-Text -X 38 -Y $y -Text '<- you' -Fg 'accent'
                }
                $y++
            }
        }

        # personal best + footer (all inside the box)
        $local = @(Get-LocalScores -GameId $gid)
        $pb = 'your local best: --'
        if ($local.Count -gt 0) { $pb = 'your local best: {0}  ({1})' -f $local[0].score, $local[0].name }
        Set-TextCentered -Y 20 -Text $pb -Fg 'dim'
        Set-TextCentered -Y 22 -Text 'left/right: other games   esc: back' -Fg 'dim'
        Set-TextCentered -Y 23 -Text $source -Fg $srcCol
        Show-Frame

        $k = Wait-RealKey
        switch ($k) {
            'LeftArrow'  { $idx = ($idx - 1 + $ids.Count) % $ids.Count }
            'RightArrow' { $idx = ($idx + 1) % $ids.Count }
            'A'          { $idx = ($idx - 1 + $ids.Count) % $ids.Count }
            'D'          { $idx = ($idx + 1) % $ids.Count }
            { $_ -in @('Q', 'Escape', 'Enter', 'Space') } { return }
        }
    }
}

function Show-HelpScreen {
    Clear-Frame
    Draw-Box -X 14 -Y 4 -W 52 -H 21 -Title ' how to play ' -Fg 'accent'
    $lines = @(
        @('arrow keys / WASD', 'move in most games'),
        @('space', 'action: shoot / flap / dash'),
        @('q', 'quit to menu from any game'),
        @('m', 'toggle sound on/off'),
        @('esc', 'back / cancel'),
        @('', ''),
        @('highscores', 'saved per game, top 10'),
        @('online board', 'auto-uploads if configured'),
        @('', ''),
        @('tip', 'run arcade.ps1 -SelfTest to verify'),
        @('', 'everything works on your machine')
    )
    $y = 6
    foreach ($l in $lines) {
        Set-Text -X 17 -Y $y -Text $l[0].PadRight(18) -Fg 'accent'
        Set-Text -X 35 -Y $y -Text $l[1] -Fg 'fg'
        $y++
    }
    Set-TextCentered -Y 23 -Text 'press any key to go back' -Fg 'dim'
    Show-Frame
    Clear-KeyBuffer
    [void](Wait-KeyAny)
}

function Show-Menu {
    $sel = 0
    while ($true) {
        # retry any online submits that failed earlier (rate limit / offline)
        Flush-PendingOnlineScores
        Clear-Frame
        Show-MenuLogo -Y 3
        Set-TextCentered -Y 10 -Text ('a tiny terminal arcade - 10 games - hi ' + $(if ($script:PlayerName) { $script:PlayerName } else { 'player' })) -Fg 'dim'
        $y0 = 11
        for ($i = 0; $i -lt $script:Games.Count; $i++) {
            $y = $y0 + $i
            $g = $script:Games[$i]
            $prefix = '  '
            $nameCol = 'fg'
            $descCol = 'dim'
            if ($i -eq $sel) {
                $prefix = "$($script:ChArrow) "
                $nameCol = 'yellow'
                Set-Text -X 26 -Y $y -Text ' ' -Bg 'bg2'
                Set-Text -X 27 -Y $y -Text ' ' -Bg 'bg2'
            }
            Set-Text -X 28 -Y $y -Text ($prefix + $g.name) -Fg $nameCol
            Set-Text -X 46 -Y $y -Text $g.desc -Fg $descCol
        }
        $top = @(Get-LocalScores -GameId $script:Games[$sel].id)
        $hsText = 'your best: --'
        if ($top.Count -gt 0) { $hsText = 'your best: {0}  ({1})' -f $top[0].score, $top[0].name }
        Set-TextCentered -Y 23 -Text $hsText -Fg 'dim'
        Set-TextCentered -Y 25 -Text 'up/down select - enter play - h highscores - ? help - m sound - q quit' -Fg 'dim'
        Set-TextCentered -Y 26 -Text ('sound: ' + $(if ($script:SoundOn) { 'on' } else { 'off' }) + '   ' + $(if (Test-OnlineScores) { 'global board: connected' } else { 'global board: offline' })) -Fg 'dim'
        Show-Frame
        $k = Wait-RealKey
        if ($script:Headless) { $k = 'Q' }
        switch ($k) {
            'UpArrow'   { $sel = ($sel - 1 + $script:Games.Count) % $script:Games.Count; Play-Sfx -Freq 350 -Ms 12 }
            'DownArrow' { $sel = ($sel + 1) % $script:Games.Count; Play-Sfx -Freq 350 -Ms 12 }
            'W'         { $sel = ($sel - 1 + $script:Games.Count) % $script:Games.Count }
            'S'         { $sel = ($sel + 1) % $script:Games.Count }
            { $_ -in @('Enter', 'Space') } {
                $g = $script:Games[$sel]
                Clear-KeyBuffer
                & $g.fn
                Start-Screen -H 30
            }
            'H' { Show-HighscoresScreen -GameId $script:Games[$sel].id }
            { $_ -in @('OemQuestion', 'Slash', 'F1') } { Show-HelpScreen }
            'M' { $script:SoundOn = -not $script:SoundOn; Save-ArcadeConfig }
            { $_ -in @('Q', 'Escape') } { return }
        }
    }
}
