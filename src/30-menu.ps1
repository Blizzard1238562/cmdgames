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
    # 70 cols wide, CP437 box glyphs only -> renders in every console font
    $art = @(
        '██████╗ ███████╗       █████╗ ██████╗  ██████╗ █████╗ ██████╗ ███████╗',
        '██╔══██╗██╔════╝      ██╔══██╗██╔══██╗██╔════╝██╔══██╗██╔══██╗██╔════╝',
        '██████╔╝███████╗█████╗███████║██████╔╝██║     ███████║██║  ██║█████╗',
        '██╔═══╝ ╚════██║╚════╝██╔══██║██╔══██╗██║     ██╔══██║██║  ██║██╔══╝',
        '██║     ███████║      ██║  ██║██║  ██║╚██████╗██║  ██║██████╔╝███████╗',
        '╚═╝     ╚══════╝      ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═════╝ ╚══════╝'
    )
    for ($i = 0; $i -lt $art.Count; $i++) {
        Set-TextCentered -Y ($Y + $i) -Text $art[$i] -Fg 'accent'
    }
}

function Show-HighscoresScreen {
    Clear-Frame
    Draw-Box -X 10 -Y 3 -W 60 -H 25 -Title ' global high scores ' -Fg 'accent'
    $games = @('snake','tetris','2048','invaders','flappy','breakout','frogger','dodge','ttt','hangman')
    $x = 14
    foreach ($gid in $games) {
        $online = Get-OnlineScores -GameId $gid
        $list = @()
        if ($null -ne $online) { $list = @($online) } else { $list = @(Get-LocalScores -GameId $gid) }
        $g = $script:Games | Where-Object { $_.id -eq $gid }
        Set-Text -X $x -Y 5 -Text ('-- ' + $g.name + ' --').ToLower() -Fg 'accent'
        $y = 7
        if ($list.Count -eq 0) {
            Set-Text -X $x -Y $y -Text '(no scores yet)' -Fg 'dim'
            $y++
        } else {
            for ($i = 0; $i -lt [Math]::Min(5, $list.Count); $i++) {
                $line = '{0}. {1}' -f ($i + 1), $list[$i].name
                $line = $line.PadRight(18) + ('{0,6}' -f $list[$i].score)
                Set-Text -X $x -Y $y -Text $line -Fg $(if ($i -eq 0) { 'yellow' } else { 'fg' })
                $y++
            }
        }
        if ($x -eq 14) { $x = 40 } else { $x = 14; $y = 7; $curY = 0 }
        $curY = 0
    }
    if (Test-OnlineScores) { Set-Text -X 12 -Y 26 -Text 'live from supabase' -Fg 'cyan' }
    else { Set-Text -X 12 -Y 26 -Text 'local scores only (offline mode)' -Fg 'dim' }
    Set-TextCentered -Y 27 -Text 'press any key to go back' -Fg 'dim'
    Show-Frame
    Clear-KeyBuffer
    [void](Wait-KeyAny)
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
        Clear-Frame
        Show-MenuLogo -Y 4
        Set-TextCentered -Y 9 -Text ('a tiny terminal arcade - 10 games - hi ' + $(if ($script:PlayerName) { $script:PlayerName } else { 'player' })) -Fg 'dim'
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
            'H' { Show-HighscoresScreen }
            { $_ -in @('OemQuestion', 'Slash', 'F1') } { Show-HelpScreen }
            'M' { $script:SoundOn = -not $script:SoundOn; Save-ArcadeConfig }
            { $_ -in @('Q', 'Escape') } { return }
        }
    }
}
