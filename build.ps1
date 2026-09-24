# Builds arcade.ps1 by concatenating src/ modules in name order.
# NO BOM: the file is pure ASCII, and a BOM breaks `irm url | iex` parsing.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$src  = Join-Path $root 'src'
$out  = Join-Path $root 'arcade.ps1'

$files = Get-ChildItem -Path $src -Filter '*.ps1' | Sort-Object Name
if ($files.Count -eq 0) { throw "no source files found in $src" }

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# ============================================================')
[void]$sb.AppendLine('#  PS-ARCADE  -  generated file, do not edit by hand.')
[void]$sb.AppendLine('#  Edit files in src/ and run build.ps1 instead.')
[void]$sb.AppendLine('# ============================================================')
foreach ($f in $files) {
    Write-Host ("  + " + $f.Name)
    [void]$sb.AppendLine()
    [void]$sb.AppendLine(('# ---- ' + $f.Name + ' ----'))
    [void]$sb.AppendLine((Get-Content -Raw -Path $f.FullName))
}
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($out, $sb.ToString(), $utf8)
Write-Host ("built " + $out + " (" + [int]((Get-Item $out).Length / 1KB) + " KB)")
