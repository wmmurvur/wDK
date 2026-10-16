# Derlenmis siteyi bu bilgisayarda gosteren kucuk sunucu (yalnizca bu bilgisayardan erisilir).
# Kullanim: powershell -ExecutionPolicy Bypass -File sunucu.ps1 [site klasoru]
# Klasor verilmezse: yaninda site\ klasoru varsa onu, yoksa bir ust klasoru (indirilen derlemenin kendisi) acar.
param([string]$Kok = '')
if (-not $Kok) {
  $ust = Split-Path -Parent $PSScriptRoot
  if (Test-Path -LiteralPath (Join-Path $ust 'site\index.html')) { $Kok = Join-Path $ust 'site' } else { $Kok = $ust }
}
$ErrorActionPreference = 'Stop'
$Kok = (Resolve-Path $Kok).Path.TrimEnd('\')

$dinleyici = $null
$port = 0
foreach ($p in 8765..8785) {
  try {
    $d = New-Object System.Net.HttpListener
    $d.Prefixes.Add("http://localhost:$p/")
    $d.Start()
    $dinleyici = $d; $port = $p; break
  } catch { }
}
if (-not $dinleyici) { Write-Host 'Bos port bulunamadi.'; exit 1 }

$turler = @{
  '.html' = 'text/html; charset=utf-8'; '.js' = 'text/javascript; charset=utf-8'; '.mjs' = 'text/javascript; charset=utf-8'
  '.css' = 'text/css; charset=utf-8'; '.json' = 'application/json'; '.svg' = 'image/svg+xml'; '.png' = 'image/png'
  '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'; '.webp' = 'image/webp'; '.avif' = 'image/avif'; '.gif' = 'image/gif'
  '.ico' = 'image/x-icon'; '.glb' = 'model/gltf-binary'; '.mp4' = 'video/mp4'; '.webm' = 'video/webm'
  '.woff2' = 'font/woff2'; '.woff' = 'font/woff'; '.xml' = 'application/xml'; '.txt' = 'text/plain; charset=utf-8'
}

$adres = "http://localhost:$port/"
Write-Host ''
Write-Host "Site acildi: $adres"
Write-Host 'Kapatmak icin bu pencereyi kapatin.'
Write-Host ''
try { Start-Process $adres } catch { Write-Host "Tarayicida su adresi acin: $adres" }

while ($dinleyici.IsListening) {
  $baglam = $dinleyici.GetContext()
  $yanit = $baglam.Response
  try {
    $yol = [Uri]::UnescapeDataString($baglam.Request.Url.AbsolutePath)
    if ($yol -match '(^|/)\.\.(/|$)') { $yanit.StatusCode = 403; continue }
    $dosya = Join-Path $Kok ($yol.TrimStart('/') -replace '/', '\')
    if (Test-Path -LiteralPath $dosya -PathType Container) {
      if (-not $yol.EndsWith('/')) { $yanit.StatusCode = 301; $yanit.RedirectLocation = "$yol/"; continue }
      $dosya = Join-Path $dosya 'index.html'
    }
    if (-not (Test-Path -LiteralPath $dosya -PathType Leaf)) { $dosya = Join-Path $Kok '404.html'; $yanit.StatusCode = 404 }
    $uzanti = [IO.Path]::GetExtension($dosya).ToLower()
    $tur = $turler[$uzanti]
    if (-not $tur) { $tur = 'application/octet-stream' }
    $yanit.ContentType = $tur
    $yanit.AddHeader('Cache-Control', 'no-cache')
    $akis = [IO.File]::OpenRead($dosya)
    try {
      $yanit.ContentLength64 = $akis.Length
      if ($baglam.Request.HttpMethod -ne 'HEAD') { $akis.CopyTo($yanit.OutputStream) }
    } finally { $akis.Dispose() }
  } catch {
    try { $yanit.StatusCode = 500 } catch { }
  } finally {
    try { $yanit.OutputStream.Close() } catch { }
    try { $yanit.Close() } catch { }
  }
}
