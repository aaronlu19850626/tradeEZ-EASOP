# Convert the existing artwork to an embedded MT5 bitmap; keep the original intact.
Add-Type -AssemblyName System.Drawing
$sourcePath = Join-Path $PSScriptRoot 'avatar-navy-final.png'
$targetPath = Join-Path $PSScriptRoot 'ea-logo.bmp'
$sourceImage = [System.Drawing.Image]::FromFile($sourcePath)
$bitmap = New-Object System.Drawing.Bitmap 128,128
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
try {
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.DrawImage($sourceImage, 0, 0, 128, 128)
    $bitmap.Save($targetPath, [System.Drawing.Imaging.ImageFormat]::Bmp)
} finally {
    $graphics.Dispose()
    $bitmap.Dispose()
    $sourceImage.Dispose()
}
