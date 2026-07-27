# Recorta e otimiza as fotos exportadas em 1080x1350 (formato 4:5 do Instagram).
# Essas fotos trazem a imagem real numa faixa horizontal sobre fundo preto — e
# algumas empilham mais de uma foto no mesmo arquivo. O script detecta as faixas
# com conteudo, recorta a faixa escolhida na proporcao pedida e grava em assets/web/.
#
#   .\tools\crop-export.ps1 -Report 46,49,45          -> lista as faixas de cada arquivo
#   .\tools\crop-export.ps1 -Jobs "46:0:institucional-1.jpg"
#
# Job = <numero do png>:<indice da faixa>:<nome de saida>[:<aspecto>]
param(
    [string[]]$Report,
    [string[]]$Jobs,
    [string]$SrcDir = "projects-img",
    [double]$DefaultAspect = 1.5,
    [int]$OutWidth = 1500,
    [int]$Quality = 86
)

Add-Type -AssemblyName System.Drawing

$root   = (Get-Location).Path
$outDir = Join-Path $root "assets\web"

function Get-Bands($path) {
    $bmp = New-Object System.Drawing.Bitmap($path)
    try {
        $w = $bmp.Width; $h = $bmp.Height
        $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
        $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
                              [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
        $stride = $data.Stride
        $bytes = New-Object byte[] ($stride * $h)
        [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
        $bmp.UnlockBits($data)

        # por linha: quantos pixels passam do limiar, e a extensao horizontal deles
        $lumMin = 42       # acima disso conta como conteudo (o fundo preto fica ~0-25)
        $minFrac = 0.012   # fracao minima da largura para a linha valer como conteudo
        $rowHas = New-Object bool[] $h
        $rowL   = New-Object int[] $h
        $rowR   = New-Object int[] $h
        for ($y = 0; $y -lt $h; $y++) {
            $base = $y * $stride
            $cnt = 0; $l = $w; $r = -1
            for ($x = 0; $x -lt $w; $x += 2) {
                $i = $base + $x * 3
                # luminancia aproximada sem ponto flutuante (BGR)
                $v = ([int]$bytes[$i] * 29 + [int]$bytes[$i + 1] * 150 + [int]$bytes[$i + 2] * 77) -shr 8
                if ($v -gt $lumMin) { $cnt++; if ($x -lt $l) { $l = $x }; if ($x -gt $r) { $r = $x } }
            }
            if ($cnt -gt ($w * $minFrac / 2)) { $rowHas[$y] = $true; $rowL[$y] = $l; $rowR[$y] = $r }
        }

        # agrupa linhas vizinhas em faixas, tolerando pequenos vaos
        $bands = @()
        $GAP = [int]($h * 0.02)
        $y = 0
        while ($y -lt $h) {
            if (-not $rowHas[$y]) { $y++; continue }
            $start = $y; $end = $y; $run = 0
            while ($y -lt $h -and $run -le $GAP) {
                if ($rowHas[$y]) { $end = $y; $run = 0 } else { $run++ }
                $y++
            }
            if (($end - $start) -gt ($h * 0.05)) {
                $l = $w; $r = 0
                for ($k = $start; $k -le $end; $k++) {
                    if ($rowHas[$k]) {
                        if ($rowL[$k] -lt $l) { $l = $rowL[$k] }
                        if ($rowR[$k] -gt $r) { $r = $rowR[$k] }
                    }
                }
                $bands += [pscustomobject]@{ Top = $start; Bottom = $end; Left = $l; Right = $r }
            }
        }
        return @{ W = $w; H = $h; Bands = $bands }
    } finally { $bmp.Dispose() }
}

function Export-Band($path, $bandIdx, $outName, $aspect) {
    $info = Get-Bands $path
    if ($bandIdx -ge $info.Bands.Count) {
        Write-Warning "$path : faixa $bandIdx nao existe (tem $($info.Bands.Count))"
        return
    }
    $b = $info.Bands[$bandIdx]
    $cx = ($b.Left + $b.Right) / 2.0
    $cy = ($b.Top + $b.Bottom) / 2.0
    $bw = $b.Right - $b.Left
    $bh = $b.Bottom - $b.Top

    # janela na proporcao pedida, com uma folga para o objeto nao encostar na borda
    $pad = 1.06
    $cw = $bw * $pad
    $ch = $bh * $pad
    if (($cw / $ch) -lt $aspect) { $cw = $ch * $aspect } else { $ch = $cw / $aspect }

    # nunca ultrapassar a imagem: senao sobraria tarja preta no recorte
    if ($cw -gt $info.W) { $cw = $info.W; $ch = $cw / $aspect }
    if ($ch -gt $info.H) { $ch = $info.H; $cw = $ch * $aspect }

    $sx = [math]::Max(0, [math]::Min($cx - $cw / 2.0, $info.W - $cw))
    $sy = [math]::Max(0, [math]::Min($cy - $ch / 2.0, $info.H - $ch))

    $oh = [int]($OutWidth / $aspect)
    $dst = New-Object System.Drawing.Bitmap($OutWidth, $oh)
    $g = [System.Drawing.Graphics]::FromImage($dst)
    try {
        # fundo preto: se a janela passar da borda, a sobra combina com o site
        $g.Clear([System.Drawing.Color]::FromArgb(0, 0, 0))
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

        $src = New-Object System.Drawing.Bitmap($path)
        try {
            $srcRect = New-Object System.Drawing.RectangleF($sx, $sy, $cw, $ch)
            $dstRect = New-Object System.Drawing.RectangleF(0, 0, $OutWidth, $oh)
            $g.DrawImage($src, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
        } finally { $src.Dispose() }
    } finally { $g.Dispose() }

    $enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
    $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]$Quality)
    $outPath = Join-Path $outDir $outName
    $dst.Save($outPath, $enc, $ep)
    $dst.Dispose()
    $kb = [math]::Round((Get-Item $outPath).Length / 1KB)
    Write-Output ("{0,-24} <- {1} faixa {2}   {3}x{4}  {5}KB" -f $outName, (Split-Path $path -Leaf), $bandIdx, $OutWidth, $oh, $kb)
}

function Resolve-Png($n) {
    $hit = Get-ChildItem -Path (Join-Path $root $SrcDir) -Filter "$n.png" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($hit) { return $hit.FullName }
    $flat = Join-Path $root "$n.png"
    if (Test-Path $flat) { return $flat }
    throw "nao achei $n.png"
}

if ($Report) {
    foreach ($n in $Report) {
        $p = Resolve-Png $n.Trim()
        $info = Get-Bands $p
        Write-Output ("--- {0}  ({1}x{2})  {3} faixa(s)" -f (Split-Path $p -Leaf), $info.W, $info.H, $info.Bands.Count)
        for ($i = 0; $i -lt $info.Bands.Count; $i++) {
            $b = $info.Bands[$i]
            Write-Output ("    [{0}] y {1}..{2} (alt {3})  x {4}..{5} (larg {6})  proporcao {7:N2}" -f `
                $i, $b.Top, $b.Bottom, ($b.Bottom - $b.Top), $b.Left, $b.Right, ($b.Right - $b.Left),
                (($b.Right - $b.Left) / [math]::Max(1, $b.Bottom - $b.Top)))
        }
    }
}

if ($Jobs) {
    New-Item -ItemType Directory -Force $outDir | Out-Null
    foreach ($j in $Jobs) {
        $parts = $j.Split(':')
        $aspect = if ($parts.Count -ge 4) { [double]$parts[3] } else { $DefaultAspect }
        Export-Band (Resolve-Png $parts[0].Trim()) ([int]$parts[1]) $parts[2] $aspect
    }
}
