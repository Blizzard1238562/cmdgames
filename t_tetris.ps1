$code = Get-Content -Raw (Join-Path $PSScriptRoot 'arcade.ps1')
$sb = [scriptblock]::Create($code)
. $sb -ListGames | Out-Null

Write-Output '--- shape data as stored:'
foreach ($k in @('I','O','T')) {
    $v = $script:TetrisShapes[$k]
    Write-Output ("  {0}: outer count {1}, elem0 count {2}, elem0[0]={3} elem0[1]={4}" -f $k, $v.Count, $v[0].Count, $v[0][0], $v[0][1])
}

Write-Output '--- Get-TetrisRotated I rot 1:'
$r = Get-TetrisRotated -Kind 'I' -Rot 1
Write-Output ("  outer count: " + $r.Count)
for ($i = 0; $i -lt $r.Count; $i++) {
    $e = $r[$i]
    $t = if ($e -is [array]) { 'array[' + $e.Count + ']' } else { $e.GetType().Name }
    Write-Output ("  elem $i : $t -> $e")
}

Write-Output '--- now the exact loop from the function, manual:'
$base = $script:TetrisShapes['I']
$xn = $null; $yn = $null
foreach ($p in $base) {
    $xn = $p[0]; $yn = $p[1]
    Write-Output ("  p=($($p[0]),$($p[1])) type p1=$(($p[1]).GetType().Name) 3-y=$(3 - $yn)")
    break
}
