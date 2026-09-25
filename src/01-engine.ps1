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
    # NOTE: PowerShell variables are case-insensitive, so the loop var must
    # NOT be named $x here - it would collide with the $X parameter and the
    # position would accumulate across iterations (letters drifting apart).
    for ($i = 0; $i -lt $len; $i++) {
        $cx = $X + $i
        if ($cx -lt 0 -or $cx -ge $script:FbW) { continue }
        $idx = $row + $cx
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
        # skip trailing spaces BUT erase to end-of-line afterwards with the
        # row's true background, otherwise leftover pixels from longer frames
        # of previous screens ghost through
        $last = $script:FbW - 1
        while ($last -ge 0 -and $script:FbCh[$rowStart + $last] -eq ' ') { $last-- }
        $rowBg = $script:FbBg[$rowStart + $script:FbW - 1]
        for ($x = 0; $x -le $last; $x++) {
            $i = $rowStart + $x
            $c = $script:FbCh[$i]
            $f = $script:FbFg[$i]; $b = $script:FbBg[$i]
            if ($f -ne $pf) { [void]$sb.Append($script:ESC).Append('[38;5;').Append($f).Append('m'); $pf = $f }
            if ($b -ne $pb) { [void]$sb.Append($script:ESC).Append('[48;5;').Append($b).Append('m'); $pb = $b }
            [void]$sb.Append($c)
        }
        [void]$sb.Append($script:ESC).Append('[48;5;').Append($rowBg).Append('m').Append($script:ESC).Append('[K')
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
            $kn = [string]$k.Key
            # .NET calls the key 'Spacebar', but every game checks 'Space'
            if ($kn -eq 'Spacebar') { $kn = 'Space' }
            $keys += $kn
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

function Wait-KeyOrIdle {
    # Waits up to N seconds for a key; returns the key name or $null on
    # timeout. Lets screens run cheap idle animations (blink, attract).
    param([int]$Seconds = 3)
    if ($script:Headless) { return 'Escape' }   # headless: pretend a key was pressed so idle loops exit
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        try {
            if ([Console]::KeyAvailable) {
                $k = [Console]::ReadKey($true)
                return [string]$k.Key
            }
        } catch { return $null }
        Start-Sleep -Milliseconds 30
    }
    return $null
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
        if ($script:TestFrames -gt 120) { throw (New-Object ArcadeSelfTestDone) }
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
