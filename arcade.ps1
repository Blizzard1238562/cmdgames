# ============================================================
#  PS-ARCADE  -  generated file, do not edit by hand.
#  Edit files in src/ and run build.ps1 instead.
# ============================================================

# ---- 00-header.ps1 ----
# ============================================================
#  PS-ARCADE - a simple terminal arcade with 10 games
#  Built as a single file. Run:  ./arcade.ps1   or   irm <url> | iex
#  Optional: ./arcade.ps1 -SelfTest   (headless smoke test of all games)
# ============================================================
param(
    [switch]$SelfTest,
    [switch]$ListGames
)

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

Add-Type -TypeDefinition 'public class ArcadeSelfTestDone : System.Exception { public int Frames = 0; public ArcadeSelfTestDone() : base() {} }' -ErrorAction SilentlyContinue

# ---- global state ----
$script:ESC        = [char]27
$script:AppName    = 'PS-ARCADE'
$script:Headless   = $false
$script:SoundOn    = $true
$script:PlayerName = ''
$script:TestKeys   = New-Object System.Collections.Generic.Queue[string]
$script:TestFrames = 0
$script:CompatMode = $false   # true = no ANSI support -> classic console colors
$script:SizeWarned = $false

# ---- config / storage paths ----
$script:ConfigDir  = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.ps-arcade'
$script:ConfigFile = Join-Path $script:ConfigDir 'config.json'
$script:ScoresFile = Join-Path $script:ConfigDir 'scores.json'

# ---- Supabase leaderboard (optional) ----
# The public anon key below is safe to distribute: the scores table only
# allows anonymous INSERT/SELECT (RLS), never update/delete.
# Env vars ARCADE_SUPABASE_URL / ARCADE_SUPABASE_ANON_KEY or entries in
# ~/.ps-arcade/config.json override these defaults.
$script:SupabaseUrl  = 'https://daoothvdwxbfyocyapkl.supabase.co'
$script:SupabaseKey  = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRhb290aHZkd3hiZnlvY3lhcGtsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAyNDA5NjcsImV4cCI6MjEwNTgxNjk2N30.vKGTNe3zGyAoA6-9BObEjmIVa5r3Z1dHyMm7223Xh-E'

# ---- muted color palette (256-color codes) ----
$script:Palette = @{
    'bg'     = 235
    'bg2'    = 237
    'fg'     = 250
    'dim'    = 245
    'accent' = 108
    'green'  = 107
    'red'    = 174
    'orange' = 179
    'yellow' = 180
    'blue'   = 109
    'purple' = 139
    'cyan'   = 116
    'white'  = 254
    'wall'   = 240
    'ink'    = 234
}

# ---- unicode chars (kept as codes so the file stays ASCII-safe) ----
$script:ChBL     = [string][char]0x250C  # top-left corner
$script:ChBH     = [string][char]0x2500  # horizontal
$script:ChBR     = [string][char]0x2510  # top-right corner
$script:ChBV     = [string][char]0x2502  # vertical
$script:ChFL     = [string][char]0x2514  # bottom-left corner
$script:ChFR     = [string][char]0x2518  # bottom-right corner
$script:ChFull   = [string][char]0x2588  # full block
$script:ChMed    = [string][char]0x2592  # medium shade
$script:ChLight  = [string][char]0x2591  # light shade
$script:ChDot    = [string][char]0x00B7  # middle dot (in CP437 raster fonts)
$script:ChDiam   = [string][char]0x25C6  # diamond (in CP437 raster fonts)
$script:ChHeart  = [string][char]0x2665  # heart (in CP437 raster fonts)
$script:ChUp     = [string][char]0x25B2  # up triangle (in CP437 raster fonts)
$script:ChDown   = [string][char]0x25BC  # down triangle (in CP437 raster fonts)
$script:ChLeft   = [string][char]0x25C4  # left triangle (in CP437 raster fonts)
$script:ChRight  = [string][char]0x25BA  # right triangle (in CP437 raster fonts)
$script:ChArrow  = '>'                   # menu cursor (ASCII: renders everywhere)
$script:ChCheck  = '*'                   # ASCII fallback
$script:ChStar   = [string][char]0x263C  # sun glyph (CP437 0x0F, renders everywhere)
$script:ChSmile  = [string][char]0x263A  # smiley (CP437 0x01)

function Get-ColorCode {
    param([string]$Name)
    $c = $script:Palette[$Name]
    if ($null -eq $c) { return 250 }
    return [int]$c
}


# ---- 01-engine.ps1 ----
# ============================================================
#  ENGINE - console setup, renderer, input, timing, sound
# ============================================================

$script:FbW  = 80
$script:FbH  = 30
$script:FbCh = $null
$script:FbFg = $null
$script:FbBg = $null

function Test-VtSupport {
    # Enables the VT bit and reads the mode back to verify it really stuck.
    # Some hosts (PowerShell ISE, very old conhosts) silently ignore it.
    try {
        $sig = @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern IntPtr GetStdHandle(int nStdHandle);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
'@
        Add-Type -MemberDefinition $sig -Name 'NativeConsole' -Namespace 'Arcade' -ErrorAction SilentlyContinue
        $h = [Arcade.NativeConsole]::GetStdHandle(-11)
        $mode = [uint32]0
        if (-not [Arcade.NativeConsole]::GetConsoleMode($h, [ref]$mode)) { return $false }
        if (-not [Arcade.NativeConsole]::SetConsoleMode($h, ($mode -bor 0x0004))) { return $false }
        $check = [uint32]0
        [void][Arcade.NativeConsole]::GetConsoleMode($h, [ref]$check)
        return (($check -band 0x0004) -ne 0)
    } catch { return $false }
}

function Initialize-CompatColors {
    # Maps the 256-color palette onto the 16 classic console colors.
    $script:CompatFg = @{
        235 = 'Black'; 234 = 'Black'; 237 = 'DarkGray'; 240 = 'DarkGray'
        243 = 'DarkGray'; 250 = 'Gray'; 254 = 'White'
        107 = 'DarkGreen'; 108 = 'DarkGreen'
        116 = 'DarkCyan'; 109 = 'DarkCyan'
        139 = 'DarkMagenta'; 174 = 'Red'
        179 = 'DarkYellow'; 180 = 'DarkYellow'
    }
    $script:CompatBg = @{
        235 = 'Black'; 234 = 'Black'; 237 = 'Black'; 240 = 'Black'
        243 = 'DarkGray'; 250 = 'Gray'; 254 = 'White'
        107 = 'DarkGreen'; 108 = 'DarkGreen'
        116 = 'DarkCyan'; 109 = 'DarkCyan'
        139 = 'DarkMagenta'; 174 = 'DarkRed'
        179 = 'DarkYellow'; 180 = 'DarkYellow'
    }
}

function Initialize-Console {
    try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
    Initialize-CompatColors
    if (Test-VtSupport) {
        $script:CompatMode = $false
        # alternate screen buffer: no scrollback ghosts, no leftover shell text
        try { [Console]::Out.Write("$($script:ESC)[?1049h$($script:ESC)[2J") } catch { }
    } else {
        $script:CompatMode = $true
    }
    try { $Host.UI.RawUI.WindowTitle = $script:AppName } catch { }
    try {
        $ui = $Host.UI.RawUI
        $minW = 84; $minH = 34
        if ($ui.BufferSize.Width -lt $minW -or $ui.BufferSize.Height -lt $minH) {
            $bs = $ui.BufferSize
            $bs.Width  = [Math]::Max($bs.Width,  $minW)
            $bs.Height = [Math]::Max($bs.Height, $minH + 4)
            $ui.BufferSize = $bs
        }
        if ($ui.WindowSize.Width -lt $minW -or $ui.WindowSize.Height -lt $minH) {
            $ws = $ui.WindowSize
            $ws.Width  = [Math]::Max($ws.Width,  $minW)
            $ws.Height = [Math]::Max($ws.Height, $minH)
            $ui.WindowSize = $ws
        }
    } catch { }
    try { [Console]::CursorVisible = $false } catch { }
}

function Restore-Console {
    try { [Console]::CursorVisible = $true } catch { }
    try { [Console]::ResetColor() } catch { }
    if ($script:CompatMode) {
        Write-Host ''
    } else {
        Write-Host "$($script:ESC)[0m$($script:ESC)[?1049l" -NoNewline
    }
}

function Clear-Console {
    try { [Console]::Clear() } catch { }
}

# ---- frame buffer ----

function Start-Screen {
    # Clears the console and creates a fresh full-screen frame buffer.
    param([int]$H = 30)
    Clear-Console
    New-Frame -W 80 -H $H -Bg 'bg'
    Test-WindowSize
}

function New-Frame {
    param([int]$W = 80, [int]$H = 30, [string]$Bg = 'bg')
    $script:FbW  = $W
    $script:FbH  = $H
    $script:FbCh = New-Object 'char[]' -ArgumentList @(($W * $H))
    $script:FbFg = New-Object 'int[]'  -ArgumentList @(($W * $H))
    $script:FbBg = New-Object 'int[]'  -ArgumentList @(($W * $H))
    Clear-Frame -Bg $Bg
}

function Clear-Frame {
    param([string]$Bg = 'bg')
    $code = Get-ColorCode $Bg
    $fgc  = Get-ColorCode 'fg'
    for ($i = 0; $i -lt $script:FbCh.Length; $i++) {
        $script:FbCh[$i] = ' '
        $script:FbFg[$i] = $fgc
        $script:FbBg[$i] = $code
    }
}

function Set-Cell {
    param([int]$X, [int]$Y, [string]$Char = ' ', [string]$Fg = $null, [string]$Bg = $null)
    if ($X -lt 0 -or $X -ge $script:FbW -or $Y -lt 0 -or $Y -ge $script:FbH) { return }
    $i = ($Y * $script:FbW) + $X
    if ($Char.Length -gt 0) { $script:FbCh[$i] = $Char[0] }
    if ($Fg) { $script:FbFg[$i] = Get-ColorCode $Fg }
    if ($Bg) { $script:FbBg[$i] = Get-ColorCode $Bg }
}

function Set-Text {
    # Hot path: writes directly into the frame buffer arrays (no per-char
    # function calls) because this runs thousands of times per second.
    param([int]$X, [int]$Y, [string]$Text = '', [string]$Fg = 'fg', [string]$Bg = $null)
    if ($Y -lt 0 -or $Y -ge $script:FbH) { return }
    $fc = Get-ColorCode $Fg
    $bc = if ($Bg) { Get-ColorCode $Bg } else { -1 }
    $row = $Y * $script:FbW
    $len = $Text.Length
    for ($i = 0; $i -lt $len; $i++) {
        $x = $X + $i
        if ($x -lt 0 -or $x -ge $script:FbW) { continue }
        $idx = $row + $x
        $script:FbCh[$idx] = $Text[$i]
        $script:FbFg[$idx] = $fc
        if ($bc -ge 0) { $script:FbBg[$idx] = $bc }
    }
}

function Set-TextCentered {
    param([int]$Y, [string]$Text = '', [string]$Fg = 'fg', [string]$Bg = $null)
    $x = [int]((($script:FbW - $Text.Length) / 2) - 0.5)
    Set-Text -X $x -Y $Y -Text $Text -Fg $Fg -Bg $Bg
}

function Set-TextRight {
    param([int]$Y, [string]$Text = '', [string]$Fg = 'fg', [string]$Bg = $null)
    Set-Text -X ($script:FbW - $Text.Length - 2) -Y $Y -Text $Text -Fg $Fg -Bg $Bg
}

function Draw-Box {
    # Hot path: direct array writes instead of per-cell Set-Cell calls.
    param([int]$X, [int]$Y, [int]$W, [int]$H, [string]$Title = '', [string]$Fg = 'wall', [string]$Bg = 'bg', [string]$FillBg = $null)
    $useBg = if ($FillBg) { Get-ColorCode $FillBg } else { Get-ColorCode $Bg }
    $fgc = Get-ColorCode $Fg
    $fbw = $script:FbW
    $x1 = $X + $W - 1
    $y1 = $Y + $H - 1
    for ($yy = $Y; $yy -le $y1; $yy++) {
        if ($yy -lt 0 -or $yy -ge $script:FbH) { continue }
        $row = $yy * $fbw
        $top = ($yy -eq $Y)
        $bot = ($yy -eq $y1)
        for ($xx = $X; $xx -le $x1; $xx++) {
            if ($xx -lt 0 -or $xx -ge $fbw) { continue }
            $i = $row + $xx
            if ($xx -eq $X) {
                if ($top) { $ch = $script:ChBL } elseif ($bot) { $ch = $script:ChFL } else { $ch = $script:ChBV }
            } elseif ($xx -eq $x1) {
                if ($top) { $ch = $script:ChBR } elseif ($bot) { $ch = $script:ChFR } else { $ch = $script:ChBV }
            } elseif ($top -or $bot) {
                $ch = $script:ChBH
            } else {
                $ch = ' '
            }
            $script:FbCh[$i] = $ch
            $script:FbFg[$i] = $fgc
            $script:FbBg[$i] = $useBg
        }
    }
    if ($Title.Length -gt 0) {
        $tx = $X + [int](($W - $Title.Length) / 2)
        Set-Text -X $tx -Y $Y -Text $Title -Fg 'fg' -Bg $(if ($FillBg) { $FillBg } else { $Bg })
    }
}

function Test-WindowSize {
    # Warn once if the console window cannot fit the frame.
    if ($script:Headless) { return }
    try {
        $ui = $Host.UI.RawUI
        $w = $ui.WindowSize.Width; $h = $ui.WindowSize.Height
        if ($w -lt ($script:FbW + 2) -or $h -lt ($script:FbH + 2)) {
            if (-not $script:SizeWarned) {
                $script:SizeWarned = $true
                try { [Console]::ForegroundColor = [ConsoleColor]::Yellow } catch { }
                Write-Host ''
                Write-Host (' window too small: needs ' + ($script:FbW + 2) + 'x' + ($script:FbH + 2) + ', got ' + $w + 'x' + $h)
                Write-Host ' enlarge this window or zoom out (ctrl + minus) - starting anyway...'
                try { [Console]::ResetColor() } catch { }
                Start-Sleep -Seconds 2
            }
        }
    } catch { }
}

function Show-FrameCompat {
    # Fallback renderer for hosts without ANSI/VT support: classic 16-color
    # console colors, run-length grouped so it stays reasonably fast.
    try { [Console]::SetCursorPosition(0, 0) } catch { }
    for ($y = 0; $y -lt $script:FbH; $y++) {
        $row = $y * $script:FbW
        $run = New-Object System.Text.StringBuilder 128
        $pf = $null; $pb = $null
        for ($x = 0; $x -lt $script:FbW; $x++) {
            $i = $row + $x
            $c = $script:FbCh[$i]
            $cf = $script:CompatFg[$script:FbFg[$i]]; if ($null -eq $cf) { $cf = [ConsoleColor]::Gray }
            $cb = $script:CompatBg[$script:FbBg[$i]]; if ($null -eq $cb) { $cb = [ConsoleColor]::Black }
            if ($cf -ne $pf -or $cb -ne $pb) {
                if ($run.Length -gt 0) {
                    try { [Console]::ForegroundColor = $pf; [Console]::BackgroundColor = $pb } catch { }
                    [Console]::Write($run.ToString())
                    [void]$run.Clear()
                }
                $pf = $cf; $pb = $cb
            }
            [void]$run.Append($c)
        }
        if ($run.Length -gt 0) {
            try { [Console]::ForegroundColor = $pf; [Console]::BackgroundColor = $pb } catch { }
            [Console]::Write($run.ToString())
        }
        try { [Console]::ResetColor() } catch { }
        [Console]::Write("`n")
    }
    try { [Console]::ResetColor() } catch { }
}

function Show-Frame {
    # Builds ONE ansi string and writes it in a single call (no flicker).
    if ($script:Headless) {
        if ($script:TestFrames -gt 400) { throw (New-Object ArcadeSelfTestDone) }
        return
    }
    if ($script:CompatMode) {
        Show-FrameCompat
        return
    }
    $sb = New-Object System.Text.StringBuilder 16384
    [void]$sb.Append($script:ESC).Append('[H')
    $pf = -1; $pb = -1
    for ($y = 0; $y -lt $script:FbH; $y++) {
        $rowStart = $y * $script:FbW
        # skip trailing spaces: less to render, cleaner look
        $last = $script:FbW - 1
        while ($last -ge 0 -and $script:FbCh[$rowStart + $last] -eq ' ') { $last-- }
        for ($x = 0; $x -le $last; $x++) {
            $i = $rowStart + $x
            $c = $script:FbCh[$i]
            $f = $script:FbFg[$i]; $b = $script:FbBg[$i]
            if ($f -ne $pf) { [void]$sb.Append($script:ESC).Append('[38;5;').Append($f).Append('m'); $pf = $f }
            if ($b -ne $pb) { [void]$sb.Append($script:ESC).Append('[48;5;').Append($b).Append('m'); $pb = $b }
            [void]$sb.Append($c)
        }
        if ($y -lt ($script:FbH - 1)) {
            [void]$sb.Append($script:ESC).Append('[0m').Append("`r`n")
            $pf = -1; $pb = -1
        }
    }
    [void]$sb.Append($script:ESC).Append('[0m')
    try { [Console]::Out.Write($sb.ToString()); [Console]::Out.Flush() } catch { }
}

# ---- input ----

function Get-KeysPressed {
    # Returns string names of console keys pressed since last call.
    $keys = @()
    if ($script:Headless) {
        while ($script:TestKeys.Count -gt 0) { $keys += $script:TestKeys.Dequeue() }
        return ,@($keys)
    }
    try {
        while ([Console]::KeyAvailable) {
            $k = [Console]::ReadKey($true)
            $keys += [string]$k.Key
        }
    } catch { }
    return ,@($keys)
}

function Clear-KeyBuffer {
    if ($script:Headless) { $script:TestKeys.Clear(); return }
    try { while ([Console]::KeyAvailable) { [void][Console]::ReadKey($true) } } catch { }
}

function Wait-RealKey {
    # Blocking wait for a single key (menus / prompts). Headless-safe.
    if ($script:Headless) { return 'Escape' }
    try {
        $k = [Console]::ReadKey($true)
        return [string]$k.Key
    } catch { return 'Escape' }
}

function Wait-KeyAny {
    # Wait until any key is pressed (polls, so it also works after frames).
    while ($true) {
        $keys = Get-KeysPressed
        if ($keys.Count -gt 0) { return $keys[0] }
        if ($script:Headless) { return 'Escape' }
        Start-Sleep -Milliseconds 30
    }
}

# ---- timing ----

function Arcade-Sleep {
    param([int]$Ms = 100)
    if ($script:Headless) { return }
    Start-Sleep -Milliseconds $Ms
}

function Start-Frames {
    $script:FrameStart = [DateTime]::UtcNow
}

function Wait-Frame {
    # Fixed-timestep frame pacing. In headless/selftest mode it just counts
    # frames and aborts a game after 600 frames so tests always terminate.
    param([int]$Ms = 50)
    if ($script:Headless) {
        $script:TestFrames++
        if ($script:TestFrames -gt 250) { throw (New-Object ArcadeSelfTestDone) }
        return
    }
    $target = $script:FrameStart.AddMilliseconds($Ms)
    $now = [DateTime]::UtcNow
    if ($target -gt $now) {
        Start-Sleep -Milliseconds ([Math]::Max(1, [int]($target - $now).TotalMilliseconds))
    }
    $script:FrameStart = [DateTime]::UtcNow
}

# ---- sound ----

function Play-Sfx {
    param([int]$Freq = 440, [int]$Ms = 40)
    if (-not $script:SoundOn -or $script:Headless) { return }
    try { [Console]::Beep($Freq, $Ms) } catch { }
}

# ---- common in-game chrome ----

function Set-GameHeader {
    param([string]$Title, [int]$Score, [string]$Right = '', [string]$Fg = 'accent')
    Set-Text -X 2 -Y 1 -Text $Title.ToUpper() -Fg $Fg
    Set-Text -X 2 -Y 2 -Text ("score {0}" -f $Score) -Fg 'dim'
    if ($Right.Length -gt 0) { Set-TextRight -Y 1 -Text $Right -Fg 'dim' }
    Set-TextRight -Y 2 -Text ('m mute - q menu') -Fg 'dim'
}

function Mute-ToggleRequested {
    param([string[]]$Keys)
    if ($Keys -contains 'M') {
        $script:SoundOn = -not $script:SoundOn
        Save-ArcadeConfig
        return $true
    }
    return $false
}


# ---- 02-scores.ps1 ----
# ============================================================
#  SCORES - config, local highscores, optional Supabase board
# ============================================================

function Initialize-ArcadeConfig {
    if (-not (Test-Path $script:ConfigDir)) {
        try { New-Item -ItemType Directory -Path $script:ConfigDir -Force | Out-Null } catch { }
    }
    $script:SoundOn = $true
    $script:PlayerName = ''
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
    param([string]$GameName, [int]$Score, [string]$Note = '')
    Draw-Box -X 20 -Y 11 -W 40 -H 8 -Title ' game over ' -Fg 'red' -FillBg 'bg2'
    Set-TextCentered -Y 13 -Text ('{0} - score {1}' -f $GameName, $Score) -Fg 'white' -Bg 'bg2'
    if ($Note.Length -gt 0) { Set-TextCentered -Y 14 -Text $Note -Fg 'yellow' -Bg 'bg2' }
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
    # Called when a run ends. Handles game-over art, score saving,
    # leaderboard display. Returns $true if the player wants a rematch.
    param([string]$GameId, [string]$GameName, [int]$Score, [string]$Note = '')

    if ($script:Headless) { return $false }

    $locals = @(Get-LocalScores -GameId $GameId)
    $qualifies = $Score -gt 0 -and ($locals.Count -lt 10 -or $Score -gt [int]($locals[$locals.Count - 1].score))
    $note = $Note
    if ($qualifies) { $note = 'new personal best!' }

    $retry = Show-GameOverScreen -GameName $GameName -Score $Score -Note $note

    if ($qualifies -and -not $retry) {
        $script:PlayerName = Read-PlayerName -Default $script:PlayerName
        $rank = Add-LocalScore -GameId $GameId -Name $script:PlayerName -Score $Score
        Save-ArcadeConfig
        $online = Send-OnlineScore -GameId $GameId -Name $script:PlayerName -Score $Score
        if ($rank -eq 1) { Play-Sfx -Freq 660 -Ms 60; Play-Sfx -Freq 880 -Ms 90 }
        $msg = 'saved locally'
        if ($online) { $msg = 'saved locally + uploaded to global board' }
        Draw-Box -X 14 -Y 9 -W 52 -H 12 -Title ' high scores ' -Fg 'accent' -FillBg 'bg2'
        Set-Text -X 17 -Y 11 -Text ('rank #{0} - {1}' -f $rank, $msg) -Fg 'yellow' -Bg 'bg2'
        $top = @(Get-LocalScores -GameId $GameId)
        $y = 13
        for ($i = 0; $i -lt [Math]::Min(5, $top.Count); $i++) {
            $line = '{0}. {1}' -f ($i + 1), $top[$i].name
            $line = $line.PadRight(22) + ('{0,6}' -f $top[$i].score)
            Set-Text -X 20 -Y $y -Text $line -Fg $(if ($i -eq ($rank - 1)) { 'yellow' } else { 'fg' }) -Bg 'bg2'
            $y++
        }
        Set-TextCentered -Y 19 -Text 'press any key' -Fg 'dim' -Bg 'bg2'
        Show-Frame
        Clear-KeyBuffer
        [void](Wait-KeyAny)
        return $false
    }
    return $retry
}


# ---- 10-snake.ps1 ----
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
                    if ($i -eq 0) { $ch = '@'; $col = 'white' }
                    Set-Cell -X $seg.x -Y $seg.y -Char $ch -Fg $col
                }
                Show-Frame
                Wait-Frame $speedMs
            }
        } catch [ArcadeSelfTestDone] { throw }

        if (-not (Complete-Game -GameId 'snake' -GameName $script:SnakeTitle -Score $score)) { break }
    }
}


# ---- 11-tetris.ps1 ----
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
        switch ($Rot % 4) {
            0 { $out += ,@($x, $y) }
            1 { $out += ,@(3 - $y, $x) }
            2 { $out += ,@(3 - $x, 3 - $y) }
            3 { $out += ,@($y, 3 - $x) }
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


# ---- 12-2048.ps1 ----
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


# ---- 13-invaders.ps1 ----
# ============================================================
#  SPACE INVADERS
# ============================================================
$script:InvadersTitle = 'Space Invaders'
$script:InvadersDesc  = 'shoot the alien fleet before it lands'

function Start-Invaders {
    while ($true) {
        Start-Frames
        Start-Screen -H 30
        $bw = 60; $bh = 19
        $bx = 10; $by = 6
        $shipX = [int]($bw / 2)
        $bullets = @()      # @{x,y}
        $bombs = @()        # @{x,y}
        $aliens = New-Object System.Collections.Generic.List[object]   # @{x,y,kind,alive}
        $wave = 1
        $score = 0
        $lives = 3
        $dirR = $true
        $cooldown = 0

        function script:New-InvaderWave {
            param($aliens, $wave)
            $aliens.Clear()
            for ($r = 0; $r -lt 3; $r++) {
                for ($c = 0; $c -lt 8; $c++) {
                    $aliens.Add(@{ x = 6 + $c * 6; y = 1 + $r * 3; alive = $true; kind = $r })
                }
            }
        }
        script:New-InvaderWave -aliens $aliens -wave $wave
        $frame = 0
        $stepEvery = 12   # frames per alien move; decreases per wave

        try {
            $running = $true
            while ($running) {
                $frame++
                $keys = Get-KeysPressed
                if (Mute-ToggleRequested $keys) { }
                if ($keys -contains 'Q') { return }
                if ($keys -contains 'LeftArrow' -or $keys -contains 'A') { $shipX -= 2 }
                if ($keys -contains 'RightArrow' -or $keys -contains 'D') { $shipX += 2 }
                if ($shipX -lt 1) { $shipX = 1 }
                if ($shipX -gt ($bw - 2)) { $shipX = $bw - 2 }
                if (($keys -contains 'Space') -and $cooldown -le 0) {
                    $bullets += @{ x = $shipX; y = $bh - 2 }
                    $cooldown = 3
                    Play-Sfx -Freq 880 -Ms 25
                }
                if ($cooldown -gt 0) { $cooldown-- }

                # move bullets
                $newB = @()
                foreach ($b in $bullets) {
                    $b.y -= 2
                    if ($b.y -ge 0) { $newB += $b }
                }
                $bullets = $newB

                # alien fleet movement
                if (($frame % $stepEvery) -eq 0) {
                    $aliveCount = 0
                    $minX = 999; $maxX = -1; $maxY = -1
                    foreach ($a in $aliens) {
                        if ($a.alive) {
                            $aliveCount++
                            if ($a.x -lt $minX) { $minX = $a.x }
                            if ($a.x -gt $maxX) { $maxX = $a.x }
                            if ($a.y -gt $maxY) { $maxY = $a.y }
                        }
                    }
                    if ($aliveCount -eq 0) {
                        $wave++
                        $score += 100
                        $stepEvery = [Math]::Max(5, 12 - $wave)
                        script:New-InvaderWave -aliens $aliens -wave $wave
                        Play-Sfx -Freq 520 -Ms 60; Play-Sfx -Freq 780 -Ms 80
                    } else {
                        $edge = $false
                        if ($dirR -and ($maxX + 2) -ge ($bw - 1)) { $edge = $true }
                        if (-not $dirR -and ($minX - 1) -le 0) { $edge = $true }
                        if ($edge) {
                            $dirR = -not $dirR
                            foreach ($a in $aliens) { if ($a.alive) { $a.y++ } }
                            if ($maxY -ge ($bh - 3)) { $lives--; if ($lives -le 0) { $running = $false } }
                        } else {
                            foreach ($a in $aliens) { if ($a.alive) { if ($dirR) { $a.x++ } else { $a.x-- } } }
                        }
                        # random bomb
                        if ((Get-Random -Maximum 100) -lt 30) {
                            $shooters = @($aliens | Where-Object { $_.alive })
                            if ($shooters.Count -gt 0) {
                                $sh = $shooters[(Get-Random -Maximum $shooters.Count)]
                                $bombs += @{ x = $sh.x; y = $sh.y }
                            }
                        }
                    }
                }

                # move bombs
                $newBo = @()
                foreach ($bo in $bombs) {
                    $bo.y += 1
                    if ($bo.y -lt $bh) {
                        if (($frame % 2) -eq 0 -and [Math]::Abs($bo.x - $shipX) -le 1 -and $bo.y -ge ($bh - 2)) {
                            $lives--
                            Play-Sfx -Freq 110 -Ms 120
                            if ($lives -le 0) { $running = $false; $newBo += $bo } else { $shipX = [int]($bw / 2) }
                        } else { $newBo += $bo }
                    }
                }
                $bombs = $newBo

                # bullet hits aliens
                foreach ($b in $bullets) {
                    foreach ($a in $aliens) {
                        if ($a.alive -and [Math]::Abs($a.x - $b.x) -le 1 -and [Math]::Abs($a.y - $b.y) -le 0) {
                            $a.alive = $false
                            $b.y = -99
                            $score += (3 - $a.kind) * 10
                            Play-Sfx -Freq 220 -Ms 30
                        }
                    }
                }
                $bullets = @($bullets | Where-Object { $_.y -ge 0 })

                # draw
                Clear-Frame
                Set-GameHeader -Title $script:InvadersTitle -Score $score -Right ('wave {0}  {1}{2}' -f $wave, $script:ChHeart, $lives)
                Draw-Box -X ($bx - 1) -Y ($by - 1) -W ($bw + 2) -H ($bh + 2) -Fg 'wall'
                foreach ($a in $aliens) {
                    if ($a.alive) {
                        $ch = $script:ChMed
                        $col = @('purple','cyan','green')[$a.kind]
                        Set-Cell -X ($bx + $a.x) -Y ($by + $a.y) -Char $ch -Fg $col
                        Set-Cell -X ($bx + $a.x + 1) -Y ($by + $a.y) -Char $ch -Fg $col
                    }
                }
                foreach ($b in $bullets) { Set-Cell -X ($bx + $b.x) -Y ($by + $b.y) -Char '|' -Fg 'yellow' }
                foreach ($bo in $bombs) { Set-Cell -X ($bx + $bo.x) -Y ($by + $bo.y) -Char '!' -Fg 'red' }
                Set-Text -X ($bx + $shipX - 1) -Y ($by + $bh - 1) -Text ('/' + $script:ChFull + '\') -Fg 'white'
                Show-Frame
                Wait-Frame 50
            }
        } catch [ArcadeSelfTestDone] { throw }

        if (-not (Complete-Game -GameId 'invaders' -GameName $script:InvadersTitle -Score $score)) { break }
    }
}


# ---- 14-flappy.ps1 ----
# ============================================================
#  FLAPPY BIRD
# ============================================================
$script:FlappyTitle = 'Flappy'
$script:FlappyDesc  = 'one button, flap through the gaps'

function Start-Flappy {
    while ($true) {
        Start-Frames
        Start-Screen -H 30
        $bw = 60; $bh = 20
        $bx = 10; $by = 6
        $birdY = [double]([int]($bh / 2))
        $vel = 0.0
        $pipes = @()      # @{x, gap}
        $score = 0
        $frame = 0
        $gravity = 0.35
        $flapV = -1.6
        $speed = 0.7
        $gap = 7

        for ($i = 0; $i -lt 3; $i++) { $pipes += @{ x = ($bw + 10 + $i * 24); gap = (Get-Random -Minimum 3 -Maximum ($bh - $gap - 4)) } }

        try {
            $running = $true
            while ($running) {
                $frame++
                $keys = Get-KeysPressed
                if (Mute-ToggleRequested $keys) { }
                if ($keys -contains 'Q') { return }
                if ($keys -contains 'Space' -or $keys -contains 'UpArrow' -or $keys -contains 'W') {
                    $vel = $flapV
                    Play-Sfx -Freq 500 -Ms 20
                }

                $vel += $gravity
                $birdY += $vel

                foreach ($p in $pipes) { $p.x -= $speed }
                if ($pipes[0].x -lt -3) {
                    $pipes.RemoveAt(0)
                    $lastX = $pipes[$pipes.Count - 1].x
                    $pipes += @{ x = $lastX + 24; gap = (Get-Random -Minimum 3 -Maximum ($bh - $gap - 4)) }
                }

                # scoring
                foreach ($p in $pipes) {
                    if (-not $p.scored -and $p.x -lt 4) { $p.scored = $true; $score++; Play-Sfx -Freq 700 -Ms 30 }
                }

                # collisions
                if ($birdY -ge ($bh - 1) -or $birdY -lt 0) { $running = $false; Play-Sfx -Freq 120 -Ms 150 }
                foreach ($p in $pipes) {
                    if ($p.x -lt 5 -and $p.x -gt 2) {   # pipe occupies x..x+1, bird is at x=4
                        if ($birdY -lt $p.gap -or $birdY -gt ($p.gap + $gap)) { $running = $false; Play-Sfx -Freq 120 -Ms 150 }
                    }
                }

                Clear-Frame
                Set-GameHeader -Title $script:FlappyTitle -Score $score
                Draw-Box -X ($bx - 1) -Y ($by - 1) -W ($bw + 2) -H ($bh + 2) -Fg 'wall'
                $py = [int][Math]::Floor($birdY)
                foreach ($p in $pipes) {
                    $px = [int][Math]::Floor($p.x)
                    for ($y = 0; $y -lt $bh; $y++) {
                        if ($y -lt $p.gap -or $y -gt ($p.gap + $gap)) {
                            Set-Cell -X ($bx + $px) -Y ($by + $y) -Char $script:ChFull -Fg 'green'
                            if ($px + 1 -lt $bw) { Set-Cell -X ($bx + $px + 1) -Y ($by + $y) -Char $script:ChFull -Fg 'green' }
                        }
                    }
                }
                Set-Cell -X ($bx + 4) -Y ($by + $py) -Char $script:ChStar -Fg 'yellow'
                Show-Frame
                Wait-Frame 50
            }
        } catch [ArcadeSelfTestDone] { throw }

        if (-not (Complete-Game -GameId 'flappy' -GameName $script:FlappyTitle -Score $score)) { break }
    }
}


# ---- 15-breakout.ps1 ----
# ============================================================
#  BREAKOUT
# ============================================================
$script:BreakoutTitle = 'Breakout'
$script:BreakoutDesc  = 'bounce the ball, smash every brick'

function Start-Breakout {
    while ($true) {
        Start-Frames
        Start-Screen -H 30
        $bw = 50; $bh = 20
        $bx = 15; $by = 6
        $paddleW = 9
        $padX = [int](($bw - $paddleW) / 2)
        $ballX = [double]($bw / 2)
        $ballY = [double]($bh - 4)
        $vx = 0.5; $vy = -0.6
        $level = 1
        $score = 0
        $lives = 3
        $bricks = $null

        function script:New-BrickWall {
            param($rows, $cols)
            $w = @{ }
            for ($r = 0; $r -lt $rows; $r++) {
                for ($c = 0; $c -lt $cols; $c++) {
                    if ((Get-Random -Maximum 10) -lt 9) { $w["$r,$c"] = (3 - [Math]::Min(2, $r)) }  # strength
                }
            }
            return $w
        }
        $bricks = script:New-BrickWall -rows 4 -cols 12

        try {
            $running = $true
            while ($running) {
                $keys = Get-KeysPressed
                if (Mute-ToggleRequested $keys) { }
                if ($keys -contains 'Q') { return }
                if ($keys -contains 'LeftArrow' -or $keys -contains 'A') { $padX -= 3 }
                if ($keys -contains 'RightArrow' -or $keys -contains 'D') { $padX += 3 }
                if ($padX -lt 1) { $padX = 1 }
                if ($padX -gt ($bw - $paddleW - 1)) { $padX = $bw - $paddleW - 1 }

                $ballX += $vx; $ballY += $vy

                # walls
                if ($ballX -lt 0.5) { $ballX = 0.5; $vx = - $vx; Play-Sfx -Freq 240 -Ms 15 }
                if ($ballX -gt ($bw - 0.5)) { $ballX = $bw - 0.5; $vx = - $vx; Play-Sfx -Freq 240 -Ms 15 }
                if ($ballY -lt 0.5) { $ballY = 0.5; $vy = - $vy; Play-Sfx -Freq 240 -Ms 15 }

                # paddle bounce
                $ibx = [int][Math]::Round($ballX); $iby = [int][Math]::Round($ballY)
                if ($vy -gt 0 -and $iby -ge ($bh - 2) -and $iby -le ($bh - 1) -and $ibx -ge $padX -and $ibx -lt ($padX + $paddleW)) {
                    $vy = -[Math]::Abs($vy)
                    $hit = ($ibx - $padX) / $paddleW   # 0..1
                    $vx = ($hit - 0.5) * 1.6
                    Play-Sfx -Freq 330 -Ms 20
                }

                # bricks: cell width 4, rows start at y=0
                $cw = 4
                if ($iby -ge 0 -and $iby -lt 12) {
                    $bc = [int][Math]::Floor($ballX / $cw)
                    $br = [int][Math]::Floor($ballY / 3)
                    $key = "$br,$bc"
                    if ($bricks.ContainsKey($key)) {
                        $bricks[$key]--
                        if ($bricks[$key] -le 0) { $bricks.Remove($key); $score += 10 * $level }
                        else { $score += 3 }
                        # bounce direction: crude - invert vertical unless hitting side of grid
                        if ($bc -eq 0 -or $bc -eq 11) { $vx = - $vx } else { $vy = - $vy }
                        Play-Sfx -Freq 440 -Ms 20
                    }
                }

                # ball lost
                if ($ballY -ge $bh) {
                    $lives--
                    Play-Sfx -Freq 100 -Ms 150
                    if ($lives -le 0) { $running = $false }
                    else {
                        $ballX = $bw / 2; $ballY = $bh - 4
                        $vx = 0.5; $vy = -0.6
                    }
                }

                # level clear
                if ($bricks.Count -eq 0) {
                    $level++
                    $score += 150
                    $bricks = script:New-BrickWall -rows (4 + [Math]::Min(4, $level)) -cols 12
                    $ballX = $bw / 2; $ballY = $bh - 4
                    $vx = 0.5 * (1 + 0.1 * $level); $vy = -0.65
                    Play-Sfx -Freq 520 -Ms 60; Play-Sfx -Freq 780 -Ms 80
                }

                Clear-Frame
                Set-GameHeader -Title $script:BreakoutTitle -Score $score -Right ('lvl {0}  {1}{2}' -f $level, $script:ChHeart, $lives)
                Draw-Box -X ($bx - 1) -Y ($by - 1) -W ($bw + 2) -H ($bh + 2) -Fg 'wall'
                foreach ($kv in $bricks.GetEnumerator()) {
                    $p = $kv.Key.Split(','); $r = [int]$p[0]; $c = [int]$p[1]
                    $col = @('red','orange','yellow')[$r % 3]
                    $cx = $bx + $c * $cw + 1; $cy = $by + $r * 3
                    for ($i = 0; $i -lt 3; $i++) { Set-Cell -X ($cx + $i) -Y $cy -Char $script:ChMed -Fg $col }
                }
                Set-Text -X ($bx + $padX) -Y ($by + $bh - 1) -Text (([string]$script:ChFull * $paddleW)) -Fg 'cyan'
                Set-Cell -X ($bx + $ibx) -Y ($by + $iby) -Char $script:ChDiam -Fg 'white'
                Show-Frame
                Wait-Frame 40
            }
        } catch [ArcadeSelfTestDone] { throw }

        if (-not (Complete-Game -GameId 'breakout' -GameName $script:BreakoutTitle -Score $score)) { break }
    }
}


# ---- 16-frogger.ps1 ----
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


# ---- 17-dodge.ps1 ----
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
                Show-Frame
                Wait-Frame 50
            }
        } catch [ArcadeSelfTestDone] { throw }

        if (-not (Complete-Game -GameId 'dodge' -GameName $script:DodgeTitle -Score $score)) { break }
    }
}


# ---- 18-ttt.ps1 ----
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
                    if ($script:Headless) { $k = @('RightArrow', 'Enter', 'RightArrow', 'Enter')[$script:TestFrames % 4] }
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
                    $msg = 'you win! next round...'
                    script:Draw-TttBoard -b $b -cur $cur -Msg $msg -MsgCol 'green'
                    Play-Sfx -Freq 660 -Ms 60; Play-Sfx -Freq 880 -Ms 80
                    Arcade-Sleep -Ms 900
                } elseif ($result -eq 'D') {
                    $score += 30
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


# ---- 19-hangman.ps1 ----
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


# ---- 30-menu.ps1 ----
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


# ---- 40-main.ps1 ----
# ============================================================
#  MAIN - splash, first-run, entry point
# ============================================================

function Start-Arcade {
    Initialize-Console
    Initialize-ArcadeConfig
    try {
        Clear-Console
        Start-Screen -H 30
        Show-MenuLogo -Y 8
        Set-TextCentered -Y 15 -Text 'insert coin...' -Fg 'dim'
        Show-Frame
        Start-Sleep -Milliseconds 600

        if ($script:PlayerName.Length -eq 0) {
            Clear-Frame
            Show-MenuLogo -Y 6
            Set-TextCentered -Y 13 -Text 'first time here - pick a name for the leaderboards' -Fg 'dim'
            Show-Frame
            $script:PlayerName = Read-PlayerName -Default ''
            Save-ArcadeConfig
        }

        Show-Menu
    } finally {
        Restore-Console
    }
}

# ---- entry ----
if ($ListGames) {
    foreach ($g in $script:Games) { '{0,-12} {1}' -f $g.id, $g.name }
    return
}

if ($SelfTest) {
    # Headless smoke test: run every game's loop for a few simulated frames.
    $script:Headless = $true
    $script:SoundOn = $false
    $script:PlayerName = 'tester'
    $failed = @()
    $only = $env:ARCADE_TEST_GAME
    foreach ($g in $script:Games) {
        if ($only -and $g.id -ne $only) { continue }
        Write-Host ('  run  ' + $g.name)
        $script:TestFrames = 0
        try {
            & $g.fn
            Write-Host ('  ok   ' + $g.name)
        } catch [ArcadeSelfTestDone] {
            Write-Host ('  ok   ' + $g.name + '  (ran ' + $script:TestFrames + ' frames)')
        } catch {
            Write-Host ('  FAIL ' + $g.name + '  -> ' + $_.Exception.Message)
            Write-Host ($_.ScriptStackTrace)
            $failed += $g.name
        }
    }
    # menu draw test
    try {
        $script:TestFrames = 0
        Show-Menu
        Write-Host '  ok   menu'
    } catch [ArcadeSelfTestDone] {
        Write-Host '  ok   menu'
    } catch {
        Write-Host ('  FAIL menu -> ' + $_.Exception.Message)
        $failed += 'menu'
    }
    Write-Host ''
    if ($failed.Count -eq 0) { Write-Host 'all games passed the smoke test' -ForegroundColor Green }
    else { Write-Host ('failed: ' + ($failed -join ', ')) -ForegroundColor Red }
    return
}

Start-Arcade

