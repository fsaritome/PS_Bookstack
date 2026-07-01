<#
.SYNOPSIS
    Fully automated BookStack + MariaDB setup for Docker Desktop on Windows.

.DESCRIPTION
    This script:
      1. Creates the project folder structure
      2. Generates a BookStack APP_KEY
      3. Generates random secure database passwords
      4. Writes a complete compose.yaml
      5. Runs docker compose up -d to start both containers

.NOTES
    Requires Docker Desktop to be installed and running.
    Run this from a normal PowerShell window (not as Administrator required).
#>

$ErrorActionPreference = "Continue"
# Note: Docker writes normal progress (pulling, downloading, etc.) to stderr.
# We deliberately use "Continue" and check $LASTEXITCODE ourselves instead of
# letting PowerShell treat stderr output as a terminating error.

# ---------------------------------------------------------------------------
# Configuration - change these if you want different defaults
# ---------------------------------------------------------------------------
$ProjectDir = "$HOME\docker\bookstack"
$HostPort   = 6875
$AppUrl     = "http://localhost:$HostPort"
$Timezone   = "Europe/Berlin"

Write-Host "=== BookStack Docker Compose Setup ===" -ForegroundColor Cyan
Write-Host "Project folder: $ProjectDir"

# ---------------------------------------------------------------------------
# 1. Verify Docker is available
# ---------------------------------------------------------------------------
docker version | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker does not seem to be running. Start Docker Desktop and try again."
    exit 1
}

# ---------------------------------------------------------------------------
# 2. Create folder structure
# ---------------------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $ProjectDir                          | Out-Null
New-Item -ItemType Directory -Force -Path "$ProjectDir\bookstack-config"       | Out-Null

$composePath = Join-Path $ProjectDir "compose.yaml"

if (Test-Path $composePath) {
    Write-Host "`nExisting compose.yaml found at $composePath - reusing its credentials instead of generating new ones." -ForegroundColor Yellow
    Write-Host "(Regenerating would break the existing database, which already has the old password baked in.)" -ForegroundColor Yellow

    $existingContent = Get-Content $composePath -Raw
    $appKey         = ([regex]::Match($existingContent, "APP_KEY=(base64:\S+)")).Groups[1].Value
    $dbPassword     = ([regex]::Match($existingContent, "DB_PASSWORD=(\S+)")).Groups[1].Value
    $dbRootPassword = ([regex]::Match($existingContent, "MYSQL_ROOT_PASSWORD=(\S+)")).Groups[1].Value

    if (-not $appKey -or -not $dbPassword) {
        Write-Error "Could not parse existing credentials from $composePath. Delete that file manually if you want to start fresh, then rerun this script."
        exit 1
    }

    Write-Host "Reusing APP_KEY: $appKey" -ForegroundColor Green
}
else {
    # ---------------------------------------------------------------------------
    # 3. Generate the BookStack APP_KEY
    # ---------------------------------------------------------------------------
    Write-Host "`nGenerating APP_KEY (this pulls the image if you don't have it yet)..." -ForegroundColor Cyan

    $rawOutput = docker run --rm --entrypoint /bin/bash lscr.io/linuxserver/bookstack:latest appkey 2>&1
    $keyLine   = $rawOutput | Select-String "base64:" | Select-Object -Last 1

    if (-not $keyLine) {
        Write-Error "Could not find a generated key in the command output. Raw output was:`n$rawOutput"
        exit 1
    }

    # Pull out just the base64:... token, in case there's surrounding text like "APP_KEY="
    $appKey = ([regex]::Match($keyLine.Line, "base64:[A-Za-z0-9+/=]+")).Value

    if (-not $appKey) {
        Write-Error "Found a line mentioning base64 but couldn't isolate the key. Line was:`n$($keyLine.Line)"
        exit 1
    }

    Write-Host "Generated APP_KEY: $appKey" -ForegroundColor Green

    # ---------------------------------------------------------------------------
    # 4. Generate random passwords
    # ---------------------------------------------------------------------------
    function New-RandomPassword {
        param([int]$Length = 24)
        $chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789"
        -join (1..$Length | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    }

    $dbPassword     = New-RandomPassword
    $dbRootPassword = New-RandomPassword
}

# ---------------------------------------------------------------------------
# 5. Write compose.yaml
# ---------------------------------------------------------------------------
$composeContent = @"
services:
  bookstack:
    image: lscr.io/linuxserver/bookstack:latest
    container_name: bookstack
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=$Timezone
      - APP_URL=$AppUrl
      - APP_KEY=$appKey
      - DB_HOST=bookstack-db
      - DB_PORT=3306
      - DB_USERNAME=bookstack
      - DB_PASSWORD=$dbPassword
      - DB_DATABASE=bookstackapp
    volumes:
      - ./bookstack-config:/config
    ports:
      - "$($HostPort):80"
    depends_on:
      - bookstack-db
    restart: unless-stopped

  bookstack-db:
    image: lscr.io/linuxserver/mariadb:latest
    container_name: bookstack-db
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=$Timezone
      - MYSQL_DATABASE=bookstackapp
      - MYSQL_USER=bookstack
      - MYSQL_PASSWORD=$dbPassword
      - MYSQL_ROOT_PASSWORD=$dbRootPassword
    volumes:
      - bookstack-db-data:/config
    restart: unless-stopped

volumes:
  bookstack-db-data:
"@

$composeContent | Out-File -FilePath $composePath -Encoding utf8 -Force
Write-Host "`nWrote $composePath" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 6. Save generated secrets for your own reference
# ---------------------------------------------------------------------------
$credsPath = Join-Path $ProjectDir "credentials.txt"
@"
APP_KEY=$appKey
DB_PASSWORD=$dbPassword
DB_ROOT_PASSWORD=$dbRootPassword
"@ | Out-File -FilePath $credsPath -Encoding utf8 -Force
Write-Host "Saved generated secrets to $credsPath - keep this file private." -ForegroundColor Yellow

# ---------------------------------------------------------------------------
# 7. Start the stack
# ---------------------------------------------------------------------------
Write-Host "`nStarting containers..." -ForegroundColor Cyan
Push-Location $ProjectDir
docker compose up -d
$composeExitCode = $LASTEXITCODE
Pop-Location

if ($composeExitCode -ne 0) {
    Write-Warning "docker compose exited with code $composeExitCode. Run 'docker compose -f `"$composePath`" logs' to see what happened."
}
else {
    Write-Host "Containers started successfully." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 8. Tell browser the URL to poll, then stream logs
# ---------------------------------------------------------------------------
Write-Output "__URL__:$AppUrl"

Write-Host ""
Write-Host "--- Streaming container logs ---" -ForegroundColor Cyan
Push-Location $ProjectDir
docker compose logs --follow
Pop-Location