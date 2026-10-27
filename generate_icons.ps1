Add-Type -AssemblyName System.Drawing
$srcPath = 'C:\Users\bala1\.gemini\antigravity-ide\brain\a559db37-cb27-4242-b00c-5ce74bc8a310\frostpro_app_icon_1792661999845.jpg'
$srcImg = [System.Drawing.Image]::FromFile($srcPath)

$targets = @{
  'mipmap-mdpi' = 48
  'mipmap-hdpi' = 72
  'mipmap-xhdpi' = 96
  'mipmap-xxhdpi' = 144
  'mipmap-xxxhdpi' = 192
}

foreach ($k in $targets.Keys) {
  $size = $targets[$k]
  $destFolder = "e:\ACService\mobile\android\app\src\main\res\$k"
  if (-not (Test-Path $destFolder)) {
    New-Item -ItemType Directory -Path $destFolder -Force | Out-Null
  }
  $destPath = Join-Path $destFolder 'ic_launcher.png'
  
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.DrawImage($srcImg, 0, 0, $size, $size)
  $g.Dispose()
  
  $bmp.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Host "Generated $destPath"
}
$srcImg.Dispose()
