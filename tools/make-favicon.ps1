# Gera assets/favicon.png a partir da marca (corta o texto, fundo preto)
Add-Type -AssemblyName System.Drawing

$root = "C:\Users\Lucas\Desktop\RARO atelier"
$src = New-Object System.Drawing.Bitmap("$root\assets\logo raro atelier.png")

# ocupacao de cada linha (pixels com alpha relevante)
$w = $src.Width; $h = $src.Height
$rowFill = New-Object int[] $h
for ($y = 0; $y -lt $h; $y++) {
    $count = 0
    for ($x = 0; $x -lt $w; $x += 2) {
        if ($src.GetPixel($x, $y).A -gt 20) { $count++ }
    }
    $rowFill[$y] = $count
}
$top = 0; while ($top -lt $h -and $rowFill[$top] -eq 0) { $top++ }
$bottom = $h - 1; while ($bottom -gt 0 -and $rowFill[$bottom] -eq 0) { $bottom-- }

# maior faixa vazia na metade inferior = separacao emblema/texto
$gapStart = -1; $gapLen = 0; $bestStart = -1; $bestLen = 0
for ($y = [int](($top + $bottom) / 2); $y -le $bottom; $y++) {
    if ($rowFill[$y] -eq 0) {
        if ($gapStart -lt 0) { $gapStart = $y; $gapLen = 0 }
        $gapLen++
        if ($gapLen -gt $bestLen) { $bestLen = $gapLen; $bestStart = $gapStart }
    } else { $gapStart = -1 }
}
$cropBottom = if ($bestLen -ge 4) { $bestStart } else { $bottom }
Write-Output "bbox: top=$top bottom=$bottom | gap: start=$bestStart len=$bestLen | cropBottom=$cropBottom"

# colunas dentro do recorte
$left = 0; $right = $w - 1
$colHasInk = { param($x) for ($y = $top; $y -lt $cropBottom; $y++) { if ($src.GetPixel($x, $y).A -gt 20) { return $true } } return $false }
while ($left -lt $w -and -not (& $colHasInk $left)) { $left++ }
while ($right -gt 0 -and -not (& $colHasInk $right)) { $right-- }
Write-Output "cols: left=$left right=$right"

$cw = $right - $left + 1; $ch = $cropBottom - $top
$crop = $src.Clone([System.Drawing.Rectangle]::new($left, $top, $cw, $ch), $src.PixelFormat)

# compor centralizado em quadrado preto 512 com 14% de respiro
$size = 512; $pad = [int]($size * 0.14)
$avail = $size - 2 * $pad
$scale = [math]::Min($avail / $cw, $avail / $ch)
$nw = [int]($cw * $scale); $nh = [int]($ch * $scale)

$fav = New-Object System.Drawing.Bitmap($size, $size)
$g = [System.Drawing.Graphics]::FromImage($fav)
$g.Clear([System.Drawing.Color]::Black)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($crop, [int](($size - $nw) / 2), [int](($size - $nh) / 2), $nw, $nh)
$g.Dispose()
$fav.Save("$root\assets\favicon.png", [System.Drawing.Imaging.ImageFormat]::Png)
$fav.Dispose(); $crop.Dispose(); $src.Dispose()
Write-Output "favicon salvo"
