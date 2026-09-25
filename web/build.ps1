# Builds web/app.js by concatenating web/src modules in name order.
# Plain UTF-8 (no BOM), classic script so it runs via <script src> and
# can be eval'd in Node for the headless self-test.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$src  = Join-Path $root 'src'
$out  = Join-Path $root 'app.js'

$files = Get-ChildItem -Path $src -Filter '*.js' | Sort-Object Name
if ($files.Count -eq 0) { throw "no source files found in $src" }

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('// ============================================================')
[void]$sb.AppendLine('//  PS-ARCADE WEB - generated file, do not edit by hand.')
[void]$sb.AppendLine('//  Edit files in web/src/ and run web/build.ps1 instead.')
[void]$sb.AppendLine('// ============================================================')
foreach ($f in $files) {
    Write-Host ("  + " + $f.Name)
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('// ---- ' + $f.Name + ' ----')
    $content = Get-Content -Raw -Path $f.FullName
    [void]$sb.AppendLine($content)
}
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($out, $sb.ToString(), $utf8)
Write-Host ("built " + $out + " (" + [int]((Get-Item $out).Length / 1KB) + " KB)")
