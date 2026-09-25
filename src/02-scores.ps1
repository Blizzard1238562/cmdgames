# ============================================================
#  SCORES - config, local highscores, optional Supabase board
# ============================================================

function Initialize-ArcadeConfig {
    if (-not (Test-Path $script:ConfigDir)) {
        try { New-Item -ItemType Directory -Path $script:ConfigDir -Force | Out-Null } catch { }
    }
    $script:SoundOn = $true
    $script:PlayerName = ''
    $script:PendingOnline = @{ }
    $script:PendingLastTry = [datetime]::MinValue
    if (Test-Path $script:ConfigFile) {
        try {
            $c = Get-Content -Raw -Path $script:ConfigFile | ConvertFrom-Json
            if ($null -ne $c.name)  { $script:PlayerName = [string]$c.name }
            if ($null -ne $c.sound) { $script:SoundOn = [bool]$c.sound }
            if ($script:SupabaseUrl.Length -eq 0 -and $null -ne $c.supabaseUrl) { $script:SupabaseUrl = [string]$c.supabaseUrl }
            if ($script:SupabaseKey.Length -eq 0 -and $null -ne $c.supabaseKey) { $script:SupabaseKey = [string]$c.supabaseKey }
        } catch { }
    }
    # env vars win over the config file
    if ($env:ARCADE_SUPABASE_URL)      { $script:SupabaseUrl = $env:ARCADE_SUPABASE_URL }
    if ($env:ARCADE_SUPABASE_ANON_KEY) { $script:SupabaseKey = $env:ARCADE_SUPABASE_ANON_KEY }
}

function Save-ArcadeConfig {
    try {
        @{
            name        = $script:PlayerName
            sound       = $script:SoundOn
            supabaseUrl = $script:SupabaseUrl
            supabaseKey = $script:SupabaseKey
        } | ConvertTo-Json | Set-Content -Path $script:ConfigFile -Encoding UTF8
    } catch { }
}

# ---------- local scores ----------

function Get-LocalScores {
    param([string]$GameId)
    if (-not (Test-Path $script:ScoresFile)) { return @() }
    try {
        $all = Get-Content -Raw -Path $script:ScoresFile | ConvertFrom-Json
        $prop = $all.PSObject.Properties[$GameId]
        if ($null -eq $prop) { return @() }
        $list = @()
        foreach ($e in $prop.Value) {
            $list += @{ name = [string]$e.name; score = [int]$e.score; when = [string]$e.when }
        }
        return $list
    } catch { return @() }
}

function Add-LocalScore {
    param([string]$GameId, [string]$Name, [int]$Score)
    $all = @{ }
    if (Test-Path $script:ScoresFile) {
        try {
            $obj = Get-Content -Raw -Path $script:ScoresFile | ConvertFrom-Json
            foreach ($p in $obj.PSObject.Properties) {
                $arr = @()
                foreach ($e in $p.Value) { $arr += @{ name = [string]$e.name; score = [int]$e.score; when = [string]$e.when } }
                $all[$p.Name] = $arr
            }
        } catch { }
    }
    $list = @()
    if ($all.ContainsKey($GameId)) { $list = @($all[$GameId]) }
    $list += @{ name = $Name; score = $Score; when = (Get-Date -Format 'yyyy-MM-dd') }
    $list = @($list | Sort-Object { -$_.score })
    if ($list.Count -gt 10) { $list = @($list[0..9]) }
    $rank = -1
    for ($i = 0; $i -lt $list.Count; $i++) {
        if ($list[$i].score -eq $Score -and $list[$i].name -eq $Name -and $rank -lt 0) { $rank = $i + 1 }
    }
    $all[$GameId] = $list
    try {
        $all | ConvertTo-Json -Depth 4 | Set-Content -Path $script:ScoresFile -Encoding UTF8
    } catch { }
    return $rank
}

# ---------- online (Supabase) ----------

function Test-OnlineScores { return ($script:SupabaseUrl.Length -gt 0 -and $script:SupabaseKey.Length -gt 0) }

function Send-OnlineScore {
    # Submits through the server-side RPC, which validates game id, score
    # range and name, and rate-limits per IP. Direct table inserts are
    # blocked by RLS/grants, so this is the only path that works.
    param([string]$GameId, [string]$Name, [int]$Score)
    if (-not (Test-OnlineScores)) { return $false }
    try {
        $uri = "$($script:SupabaseUrl)/rest/v1/rpc/submit_score"
        $headers = @{
            apikey        = $script:SupabaseKey
            Authorization = "Bearer $($script:SupabaseKey)"
            'Content-Type' = 'application/json'
        }
        $body = @{ p_game = $GameId; p_name = $Name; p_score = $Score } | ConvertTo-Json -Compress
        Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $body -TimeoutSec 5 | Out-Null
        return $true
    } catch { return $false }
}

# Online submits are rate-limited server-side (1/min per IP). If a send
# fails (rate limit / network), keep the best unsent score per game and
# retry it on a later game over or menu visit.
function Add-PendingOnlineScore {
    param([string]$GameId, [int]$Score)
    if (-not $script:PendingOnline.ContainsKey($GameId) -or $Score -gt [int]$script:PendingOnline[$GameId]) {
        $script:PendingOnline[$GameId] = $Score
    }
}

function Flush-PendingOnlineScores {
    if ($script:PendingOnline.Count -eq 0) { return }
    if (-not (Test-OnlineScores)) { return }
    if (((Get-Date) - $script:PendingLastTry).TotalSeconds -lt 45) { return }
    $script:PendingLastTry = Get-Date
    foreach ($gid in @($script:PendingOnline.Keys)) {
        if (Send-OnlineScore -GameId $gid -Name $script:PlayerName -Score ([int]$script:PendingOnline[$gid])) {
            $script:PendingOnline.Remove($gid)
        }
    }
}

function Get-OnlineScores {
    param([string]$GameId)
    if (-not (Test-OnlineScores)) { return $null }
    try {
        $uri = "$($script:SupabaseUrl)/rest/v1/scores?game=eq.$GameId&select=name,score,created_at&order=score.desc,created_at.asc&limit=10"
        $headers = @{
            apikey        = $script:SupabaseKey
            Authorization = "Bearer $($script:SupabaseKey)"
        }
        $rows = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -TimeoutSec 4
        $list = @()
        foreach ($r in @($rows)) { $list += @{ name = [string]$r.name; score = [int]$r.score } }
        return ,$list
    } catch { return $null }
}

# ---------- in-game name prompt ----------

function Read-PlayerName {
    param([string]$Default = '')
    $name = $Default
    $cy = [int]($script:FbH / 2) + 2
    while ($true) {
        $shown = $name
        if ($shown.Length -eq 0) { $shown = '_' }
        Draw-Box -X 24 -Y ($cy - 3) -W 32 -H 5 -Title ' enter your name ' -Fg 'accent' -FillBg 'bg2'
        Set-Text -X 27 -Y ($cy - 1) -Text ('> ' + $shown).PadRight(26) -Fg 'white' -Bg 'bg2'
        Set-Text -X 27 -Y ($cy + 1) -Text 'letters/numbers, max 16'.PadRight(26) -Fg 'dim' -Bg 'bg2'
        Show-Frame
        try { [Console]::CursorVisible = $true; [Console]::SetCursorPos(27 + 2 + $name.Length, $cy - 1) } catch { }
        $k = [Console]::ReadKey($true)
        try { [Console]::CursorVisible = $false } catch { }
        $key = [string]$k.Key
        if ($key -eq 'Enter') { break }
        if ($key -eq 'Escape') { $name = $Default; break }
        if ($key -eq 'Backspace') { if ($name.Length -gt 0) { $name = $name.Substring(0, $name.Length - 1) } }
        elseif ($name.Length -lt 16 -and -not [Console]::Modifiers) {
            $ch = $k.KeyChar
            if ($ch -and ($ch -match '[A-Za-z0-9 _\-]')) { $name += $ch }
        }
    }
    $name = $name.Trim()
    if ($name.Length -eq 0) { $name = 'anonymous' }
    return $name
}

# ---------- game over / score flow ----------

function Show-GameOverScreen {
    param([string]$GameName, [int]$Score, [string]$Note = '', [string]$SubNote = '')
    Draw-Box -X 20 -Y 11 -W 40 -H 8 -Title ' game over ' -Fg 'red' -FillBg 'bg2'
    Set-TextCentered -Y 13 -Text ('{0} - score {1}' -f $GameName, $Score) -Fg 'white' -Bg 'bg2'
    if ($Note.Length -gt 0) { Set-TextCentered -Y 14 -Text $Note -Fg 'yellow' -Bg 'bg2' }
    if ($SubNote.Length -gt 0) { Set-TextCentered -Y 15 -Text $SubNote -Fg 'dim' -Bg 'bg2' }
    Set-TextCentered -Y 16 -Text '[R] play again    [Q] menu' -Fg 'fg' -Bg 'bg2'
    Show-Frame
    Clear-KeyBuffer
    while ($true) {
        $k = Wait-RealKey
        if ($k -eq 'R') { return $true }
        if ($k -in @('Q', 'Escape', 'Enter')) { return $false }
        if ($script:Headless) { return $false }
    }
}

function Complete-Game {
    # Called when a run ends. The score is saved BEFORE the game-over
    # prompt, so [R] retry runs are recorded too. The 'personal best'
    # note compares against the player's own previous best for this game.
    # Returns $true if the player wants a rematch.
    param([string]$GameId, [string]$GameName, [int]$Score, [string]$Note = '')

    if ($script:Headless) { return $false }

    $note = $Note
    $sub = ''
    $code = ''
    try { $code = (ConvertTo-ChallengeCode -GameId $GameId -Score $Score) } catch { }
    if ($Score -gt 0) {
        Flush-PendingOnlineScores
        $locals = @(Get-LocalScores -GameId $GameId)
        $prevBest = 0
        foreach ($e in $locals) {
            if ($e.name -eq $script:PlayerName -and [int]$e.score -gt $prevBest) { $prevBest = [int]$e.score }
        }
        $rank = Add-LocalScore -GameId $GameId -Name $script:PlayerName -Score $Score
        $online = $false
        if (Test-OnlineScores) {
            $online = Send-OnlineScore -GameId $GameId -Name $script:PlayerName -Score $Score
            if (-not $online) { Add-PendingOnlineScore -GameId $GameId -Score $Score }
        }
        if ($Score -gt $prevBest) { $note = 'new personal best!' }
        elseif ($note -eq '' -and $code -ne '') { $note = 'run code: {0}' -f $code }
        $rankTxt = ''
        if ($rank -gt 0) { $rankTxt = ' - rank #{0}' -f $rank }
        $codeTxt = ''
        if ($code -ne '') { $codeTxt = ' - {0}' -f $code }
        if ($online) { $sub = 'score uploaded' + $rankTxt + $codeTxt } else { $sub = 'saved locally' + $rankTxt + $codeTxt }
        if ($rank -eq 1) { Play-Sfx -Freq 660 -Ms 60; Play-Sfx -Freq 880 -Ms 90 }
    }

    return (Show-GameOverScreen -GameName $GameName -Score $Score -Note $note -SubNote $sub)
}
