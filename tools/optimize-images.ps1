# Gera copias otimizadas das fotos usadas no site em assets/web/
Add-Type -AssemblyName System.Drawing

$root = "C:\Users\Lucas\Desktop\RARO atelier"
$outDir = Join-Path $root "assets\web"
New-Item -ItemType Directory -Force $outDir | Out-Null

function Resize-Photo($inPath, $outName, $maxDim, $quality) {
    $src = [System.Drawing.Image]::FromFile($inPath)
    try {
        # respeita orientacao EXIF (tag 274)
        if ($src.PropertyIdList -contains 274) {
            $o = $src.GetPropertyItem(274).Value[0]
            switch ($o) {
                3 { $src.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipNone) }
                6 { $src.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone) }
                8 { $src.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipNone) }
            }
        }
        $w = $src.Width; $h = $src.Height
        $scale = [math]::Min(1.0, $maxDim / [math]::Max($w, $h))
        $nw = [int]($w * $scale); $nh = [int]($h * $scale)

        $bmp = New-Object System.Drawing.Bitmap($nw, $nh)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.DrawImage($src, 0, 0, $nw, $nh)
        $g.Dispose()

        $enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
        $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
        $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]$quality)
        $outPath = Join-Path $outDir $outName
        $bmp.Save($outPath, $enc, $ep)
        $bmp.Dispose()
        $kb = [math]::Round((Get-Item $outPath).Length / 1KB)
        Write-Output ("{0}  {1}x{2}  {3}KB" -f $outName, $nw, $nh, $kb)
    } finally { $src.Dispose() }
}

$a = Join-Path $root "assets"

# hero (um pouco maior por ser a imagem principal)
Resize-Photo "$a\rotonda-projeto-1\rotonda-hand.jpg" "rotonda-hand.jpg" 1800 84

# rotonda — galeria / grow / sobre
Resize-Photo "$a\rotonda-projeto-1\rotonda1.jpg" "rotonda-1.jpg" 1400 82
Resize-Photo "$a\rotonda-projeto-1\rotonda2.jpg" "rotonda-2.jpg" 1800 84
Resize-Photo "$a\rotonda-projeto-1\rotonda3.jpg" "rotonda-3.jpg" 1400 82
Resize-Photo "$a\rotonda-projeto-1\rotonda5.jpg" "rotonda-5.jpg" 1800 84
Resize-Photo "$a\rotonda-projeto-1\rotonda6.jpg" "rotonda-6.jpg" 1400 82
Resize-Photo "$a\rotonda-projeto-1\rotonda7.jpg" "rotonda-7.jpg" 1400 82
Resize-Photo "$a\rotonda-projeto-1\rotonda8.jpg" "rotonda-8.jpg" 1400 82

# projeto 002
Resize-Photo "$a\projeto-2\foto-projeto2-1.JPG" "projeto2-1.jpg" 1500 82
Resize-Photo "$a\projeto-2\foto-projeto2-5.JPG" "projeto2-2.jpg" 1200 82
Resize-Photo "$a\projeto-2\foto-projeto2-7.JPG" "projeto2-3.jpg" 1200 82

# projeto 003
Resize-Photo "$a\projeto-3\foto-projeto3-1.jpg" "projeto3-1.jpg" 1500 82
Resize-Photo "$a\projeto-3\foto-projeto3-2.jpg" "projeto3-2.jpg" 1200 82
Resize-Photo "$a\projeto-3\foto-projeto3-4.jpg" "projeto3-3.jpg" 1200 82

# quadros
Resize-Photo "$a\quadros\IMG_0196.JPG" "quadro-savoye.jpg" 1400 82
Resize-Photo "$a\quadros\IMG_0372_VSCO.JPG" "quadro-cristo.jpg" 1400 82
Resize-Photo "$a\quadros\IMG_0199.jpg" "quadro-duo.jpg" 1400 82
Resize-Photo "$a\quadros\AFDC7AE4-7D6A-47EC-A6F4-26A1556DE400.JPG" "quadro-rio.jpg" 1400 82
Resize-Photo "$a\quadros\IMG_0193.JPG" "quadro-par.jpg" 1400 82
Resize-Photo "$a\quadros\E3AB74FF-A235-44D5-80B8-F60FD1DED99D.JPG" "quadro-fachada.jpg" 1400 82
