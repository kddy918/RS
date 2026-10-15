# Daily RSS feed updater for RS (GitHub Pages mirror)
# Pulls LAN RSS sources and pushes to origin/main.
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$Feeds = @(
  @{ Url = "http://192.168.60.117:1200/t66y/7";  Out = "feeds\t66y-7.xml" },
  @{ Url = "http://192.168.60.117:1200/t66y/20"; Out = "feeds\t66y-20.xml" }
)

New-Item -ItemType Directory -Force -Path "feeds" | Out-Null

foreach ($f in $Feeds) {
  Write-Host "Fetching $($f.Url) -> $($f.Out)"
  curl.exe -sS -m 120 -L -o $f.Out $f.Url
  if (-not (Test-Path $f.Out) -or (Get-Item $f.Out).Length -lt 100) {
    throw "Fetch failed or empty: $($f.Url)"
  }
}

$git = "E:\Program Files\Git\cmd\git.exe"
if (-not (Test-Path $git)) { $git = "git" }

& $git add feeds/
$status = & $git status --porcelain
if (-not $status) {
  Write-Host "No changes; skip commit."
  exit 0
}

$ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"
& $git commit -m "chore: update RSS feeds ($ts)"
& $git push origin HEAD
Write-Host "Pushed OK."
