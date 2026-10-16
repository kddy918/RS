# Daily RSS feed updater for RS (GitHub Pages mirror)
# Pulls LAN RSS sources and pushes to origin/main.
# Retries failed fetches with backoff; never overwrites a good local XML on final failure.
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$Feeds = @(
  @{ Url = "http://192.168.60.117:1200/t66y/7";  Out = "feeds\t66y-7.xml" },
  @{ Url = "http://192.168.60.117:1200/t66y/20"; Out = "feeds\t66y-20.xml" }
)

# Initial attempt + up to 3 retries; wait before each retry
$MaxAttempts = 4
$BackoffsSec = @(5, 15, 30)

New-Item -ItemType Directory -Force -Path "feeds" | Out-Null

function Get-FeedWithRetry {
  param(
    [Parameter(Mandatory = $true)][string]$Url,
    [Parameter(Mandatory = $true)][string]$OutPath
  )

  $tmp = "$OutPath.tmp"
  $lastError = "unknown"

  for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    if ($attempt -gt 1) {
      $delay = $BackoffsSec[$attempt - 2]
      Write-Host "  Retry $attempt/$MaxAttempts after ${delay}s..."
      Start-Sleep -Seconds $delay
    } else {
      Write-Host "  Attempt $attempt/$MaxAttempts..."
    }

    try {
      Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue

      # Body to temp file; HTTP status on stdout. Do not merge stderr into $httpCode.
      $prevEap = $ErrorActionPreference
      $ErrorActionPreference = "Continue"
      $httpCode = & curl.exe -sS -m 120 -L -o $tmp -w "%{http_code}" -- $Url 2>$null
      $curlExit = $LASTEXITCODE
      $ErrorActionPreference = $prevEap

      if ($curlExit -ne 0) {
        $lastError = "connection/curl failure (exit $curlExit, http=$httpCode)"
        Write-Host "  Attempt $attempt failed: $lastError"
        continue
      }

      $code = ("$httpCode").Trim()
      if ($code -ne "200") {
        $lastError = "HTTP $code (non-200)"
        Write-Host "  Attempt $attempt failed: $lastError"
        continue
      }

      if (-not (Test-Path -LiteralPath $tmp) -or (Get-Item -LiteralPath $tmp).Length -lt 100) {
        $lastError = "empty or too-small response"
        Write-Host "  Attempt $attempt failed: $lastError"
        continue
      }

      Move-Item -LiteralPath $tmp -Destination $OutPath -Force
      $bytes = (Get-Item -LiteralPath $OutPath).Length
      Write-Host "  OK ($bytes bytes) -> $OutPath"
      return $true
    }
    catch {
      $lastError = $_.Exception.Message
      Write-Host "  Attempt $attempt failed: $lastError"
    }
  }

  Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
  $kept = if (Test-Path -LiteralPath $OutPath) { "keeping existing $($OutPath)" } else { "no existing local file" }
  Write-Host "  FINAL FAILURE for $Url — $kept. Last error: $lastError"
  return $false
}

$failed = [System.Collections.Generic.List[string]]::new()
$okCount = 0

foreach ($f in $Feeds) {
  Write-Host "Fetching $($f.Url) -> $($f.Out)"
  if (Get-FeedWithRetry -Url $f.Url -OutPath $f.Out) {
    $okCount++
  } else {
    [void]$failed.Add($f.Url)
  }
}

if ($okCount -eq 0) {
  Write-Host "ERROR: All feeds failed. Not committing. Failed: $($failed -join ', ')"
  exit 1
}

if ($failed.Count -gt 0) {
  Write-Host "WARNING: Partial failure — succeeded=$okCount, failed=$($failed.Count): $($failed -join ', ')"
  Write-Host "Will still commit any successful feed updates."
}

$git = "E:\Program Files\Git\cmd\git.exe"
if (-not (Test-Path -LiteralPath $git)) { $git = "git" }

& $git add feeds/
$status = & $git status --porcelain -- feeds/
if (-not $status) {
  Write-Host "No changes; skip commit."
  exit 0
}

$ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"
& $git commit -m "chore: update RSS feeds ($ts)"

# Prefer gh auth git-credential for HTTPS push when gh is on PATH; else default helper (manager).
$ghCmd = Get-Command gh -ErrorAction SilentlyContinue
if ($ghCmd) {
  Write-Host "Pushing with gh auth git-credential..."
  & $git -c "credential.helper=" -c "credential.helper=!gh auth git-credential" push origin HEAD
} else {
  Write-Host "Pushing with default credential helper..."
  & $git push origin HEAD
}

if ($LASTEXITCODE -ne 0) {
  Write-Host "ERROR: git push failed (exit $LASTEXITCODE)."
  exit $LASTEXITCODE
}

Write-Host "Pushed OK."
if ($failed.Count -gt 0) {
  Write-Host "Done with partial feed failures (successful updates were pushed)."
}
exit 0
