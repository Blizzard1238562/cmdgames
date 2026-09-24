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
    'dim'    = 243
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
$script:ChDot    = [string][char]0x00B7  # middle dot
$script:ChDiam   = [string][char]0x25C6  # diamond
$script:ChHeart  = [string][char]0x2665  # heart
$script:ChUp     = [string][char]0x25B2  # up triangle
$script:ChDown   = [string][char]0x25BC  # down triangle
$script:ChLeft   = [string][char]0x25C4  # left triangle
$script:ChRight  = [string][char]0x25BA  # right triangle
$script:ChArrow  = [string][char]0x2192  # right arrow
$script:ChCheck  = [string][char]0x2713  # check mark
$script:ChStar   = [string][char]0x2605  # star
$script:ChSmile  = [string][char]0x263A  # smiley

function Get-ColorCode {
    param([string]$Name)
    $c = $script:Palette[$Name]
    if ($null -eq $c) { return 250 }
    return [int]$c
}
