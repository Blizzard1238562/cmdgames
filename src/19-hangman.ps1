# ============================================================
#  HANGMAN
# ============================================================
$script:HangTitle = 'Hangman'
$script:HangDesc  = 'guess the word, one letter at a time'

$script:HangWords = @(
    'arcade','pixel','joystick','console','keyboard','monitor','controller','cartridge',
    'neon','wizard','dragon','castle','puzzle','rocket','galaxy','planet','meteor','orbit',
    'cobra','panda','falcon','shark','tiger','zebra','wolf','eagle','dolphin','penguin',
    'pizza','burger','noodle','coffee','donut','waffle','mango','banana','carrot','pepper',
    'guitar','drums','piano','violin','trumpet','banjo','harmonica','accordion',
    'mountain','river','forest','desert','island','volcano','glacier','canyon','meadow',
    'robot','circuit','laser','server','python','script','memory','cache','kernel'
)

function Start-Hangman {
    while ($true) {
        Start-Frames
        Start-Screen -H 30
        $score = 0
        $solved = 0

        function script:Draw-Hangman {
            param([string]$Word, [System.Collections.Generic.HashSet[string]]$Guessed, [int]$Wrong, [string]$Msg, [string]$MsgCol)
            Clear-Frame
            Set-GameHeader -Title $script:HangTitle -Score $score -Right ("solved {0}" -f $solved)
            # gallows
            Set-Text -X 12 -Y 8  -Text ('/' + $script:ChBH + $script:ChBH + $script:ChBH + $script:ChBH + '\') -Fg 'wall'
            Set-Text -X 17 -Y 9  -Text '|' -Fg 'wall'
            Set-Text -X 17 -Y 10 -Text '|' -Fg 'wall'
            Set-Text -X 17 -Y 11 -Text '|' -Fg 'wall'
            Set-Text -X 17 -Y 16 -Text '|' -Fg 'wall'
            Set-Text -X 11 -Y 16 -Text $script:ChBH -Fg 'wall'
            $stages = @('O', "O$([string][char]0x2502)", "O/$([string][char]0x2502)", "O/$([string][char]0x2502)\", "O/$([string][char]0x2502)\", "O/$([string][char]0x2502)\ /")
            if ($Wrong -gt 0) {
                $parts = $stages[$Wrong - 1].ToCharArray()
                Set-Text -X 16 -Y 10 -Text ([string]$parts[0]) -Fg 'red'
                if ($parts.Count -gt 1) { Set-Text -X 17 -Y 11 -Text ([string]$parts[1]) -Fg 'red' }
                if ($parts.Count -gt 2) { Set-Text -X 16 -Y 12 -Text ([string]$parts[2]) -Fg 'red' }
                if ($parts.Count -gt 3) { Set-Text -X 18 -Y 12 -Text ([string]$parts[3]) -Fg 'red' }
                if ($parts.Count -gt 4) { Set-Text -X 16 -Y 13 -Text ([string]$parts[4]) -Fg 'red' }
                if ($parts.Count -gt 5) { Set-Text -X 18 -Y 13 -Text ([string]$parts[5]) -Fg 'red' }
            }
            # word slots
            $wx = 28
            $reveal = ''
            foreach ($ch in $Word.ToCharArray()) {
                if ($Guessed.Contains([string]$ch)) { $reveal += $ch + ' ' } else { $reveal += '_ ' }
            }
            Set-Text -X $wx -Y 10 -Text $reveal -Fg 'white'
            Set-Text -X $wx -Y 12 -Text ('length {0}' -f $Word.Length) -Fg 'dim'
            # guessed letters
            $g = ($Guessed | Sort-Object) -join ' '
            if ($g.Length -gt 40) { $g = $g.Substring(0, 40) }
            Set-Text -X $wx -Y 14 -Text ('used: ' + $g) -Fg 'dim'
            Set-Text -X $wx -Y 16 -Text ('wrong: {0}/6' -f $Wrong) -Fg 'red'
            Set-Text -X $wx -Y 19 -Text $Msg -Fg $MsgCol
            Set-Text -X $wx -Y 21 -Text 'press a letter - q menu' -Fg 'dim'
            Show-Frame
        }

        try {
            $runOver = $false
            while (-not $runOver) {
                $word = $script:HangWords[(Get-Random -Maximum $script:HangWords.Count)].ToUpper()
                $guessed = New-Object 'System.Collections.Generic.HashSet[string]'
                $wrong = 0
                $msg = 'guess a letter'
                $msgCol = 'dim'
                $state = 'play'   # play | won | lost
                while ($state -eq 'play') {
                    Wait-Frame 16
                    script:Draw-Hangman -Word $word -Guessed $guessed -Wrong $wrong -Msg $msg -MsgCol $msgCol
                    $k = Wait-RealKey
                    if ($script:Headless) { $k = [string][char](65 + ($script:TestFrames % 26)) }
                    if ($k -eq 'Q' -or $k -eq 'Escape') { return }
                    if ($k.Length -eq 1 -and $k -match '^[A-Z]$') {
                        if ($guessed.Contains($k)) {
                            $msg = "already tried $k"; $msgCol = 'yellow'
                        } else {
                            [void]$guessed.Add($k)
                            if ($word.Contains($k)) {
                                $msg = "$k is in the word!"; $msgCol = 'green'
                                Play-Sfx -Freq 520 -Ms 30
                            } else {
                                $wrong++
                                $msg = "no $k in the word"; $msgCol = 'red'
                                Play-Sfx -Freq 200 -Ms 40
                            }
                            $done = $true
                            foreach ($ch in $word.ToCharArray()) { if (-not $guessed.Contains([string]$ch)) { $done = $false } }
                            if ($done) { $state = 'won' }
                            elseif ($wrong -ge 6) { $state = 'lost' }
                        }
                    }
                }
                if ($state -eq 'won') {
                    $score += 50 + (6 - $wrong) * 20
                    $solved++
                    $msg = "the word was $word - next one!"
                    script:Draw-Hangman -Word $word -Guessed $guessed -Wrong $wrong -Msg $msg -MsgCol 'green'
                    Play-Sfx -Freq 660 -Ms 60; Play-Sfx -Freq 880 -Ms 80
                    Arcade-Sleep -Ms 1200
                } else {
                    $msg = "it was $word - run over"
                    script:Draw-Hangman -Word $word -Guessed $guessed -Wrong $wrong -Msg $msg -MsgCol 'red'
                    Play-Sfx -Freq 150 -Ms 200
                    Arcade-Sleep -Ms 1400
                    $runOver = $true
                }
            }
        } catch [ArcadeSelfTestDone] { throw }

        if (-not (Complete-Game -GameId 'hangman' -GameName $script:HangTitle -Score $score)) { break }
    }
}
