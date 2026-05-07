$ErrorActionPreference = "Stop"

$ProjectPath = "C:\MILA"
$BackupRoot = "C:\MILA_BACKUPS"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

$BackupDir = Join-Path $BackupRoot "MILA_BACKUP_$Timestamp"
$ProjectBackupDir = Join-Path $BackupDir "project"
$DbBackupFile = Join-Path $BackupDir "mila_ai_backup.sql"
$ManifestFile = Join-Path $BackupDir "backup_manifest.txt"
$ZipFile = Join-Path $BackupRoot "MILA_BACKUP_$Timestamp.zip"

Write-Host "=== MILA BACKUP STARTED ===" -ForegroundColor Cyan

New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
New-Item -ItemType Directory -Force -Path $ProjectBackupDir | Out-Null

if (!(Test-Path $ProjectPath)) {
    throw "Project path not found: $ProjectPath"
}

Write-Host "Checking Docker..." -ForegroundColor Cyan

$DockerVersion = docker --version
$DockerComposeVersion = docker compose version

Write-Host $DockerVersion
Write-Host $DockerComposeVersion

Write-Host "Checking PostgreSQL container..." -ForegroundColor Cyan

$ContainerCheck = docker ps --format "{{.Names}}" | Select-String -Pattern "^mila_postgres$"

if (!$ContainerCheck) {
    throw "Container mila_postgres is not running. Run first: docker compose up -d"
}

Write-Host "Creating requirements.txt..." -ForegroundColor Cyan

$VenvPython = Join-Path $ProjectPath ".venv\Scripts\python.exe"

if (Test-Path $VenvPython) {
    & $VenvPython -m pip freeze | Out-File -Encoding UTF8 (Join-Path $ProjectPath "requirements.txt")
} else {
    Write-Host "Warning: .venv Python not found. Skipping pip freeze." -ForegroundColor Yellow
}

Write-Host "Copying project files..." -ForegroundColor Cyan

robocopy $ProjectPath $ProjectBackupDir /E `
    /XD ".venv" "data" "__pycache__" ".git" ".pytest_cache" `
    /XF "*.pyc" "*.pyo" "*.log" | Out-Null

Write-Host "Creating PostgreSQL full backup..." -ForegroundColor Cyan

docker exec mila_postgres pg_dump -U mila -d mila_ai --clean --if-exists > $DbBackupFile

if (!(Test-Path $DbBackupFile)) {
    throw "Database backup file was not created."
}

$DbBackupSize = (Get-Item $DbBackupFile).Length

if ($DbBackupSize -le 0) {
    throw "Database backup file is empty."
}

Write-Host "Saving database table list..." -ForegroundColor Cyan

docker exec mila_postgres psql -U mila -d mila_ai -t -A -c "\dt" > (Join-Path $BackupDir "db_tables.txt")

Write-Host "Saving memory count..." -ForegroundColor Cyan

docker exec mila_postgres psql -U mila -d mila_ai -t -A -c "SELECT COUNT(*) FROM ai_memory;" > (Join-Path $BackupDir "memory_count.txt")

Write-Host "Saving pending actions count..." -ForegroundColor Cyan

docker exec mila_postgres psql -U mila -d mila_ai -t -A -c "SELECT COUNT(*) FROM pending_actions;" > (Join-Path $BackupDir "pending_actions_count.txt")

Write-Host "Saving action logs count..." -ForegroundColor Cyan

docker exec mila_postgres psql -U mila -d mila_ai -t -A -c "SELECT COUNT(*) FROM action_logs;" > (Join-Path $BackupDir "action_logs_count.txt")

Write-Host "Saving Docker status..." -ForegroundColor Cyan

docker ps > (Join-Path $BackupDir "docker_ps.txt")

Write-Host "Creating manifest..." -ForegroundColor Cyan

@"
MILA BACKUP MANIFEST
====================

Backup created at: $Timestamp
Project path: $ProjectPath
Backup folder: $BackupDir
ZIP file: $ZipFile

Docker:
$DockerVersion
$DockerComposeVersion

Included:
- Project files
- .env.local
- requirements.txt
- docker-compose.yml
- db SQL files
- PostgreSQL full dump
- Memory data
- Action Layer data
- Telegram configuration

Excluded:
- .venv
- data/postgres
- __pycache__
- .git
- logs

Database backup size bytes:
$DbBackupSize

IMPORTANT:
This backup contains .env.local with API keys and secrets.
Do not upload this backup to public cloud, GitHub, Telegram, or untrusted devices.
"@ | Out-File -Encoding UTF8 $ManifestFile

Write-Host "Creating ZIP archive..." -ForegroundColor Cyan

Compress-Archive -Path "$BackupDir\*" -DestinationPath $ZipFile -Force

if (!(Test-Path $ZipFile)) {
    throw "ZIP file was not created."
}

$ZipSize = (Get-Item $ZipFile).Length

if ($ZipSize -le 0) {
    throw "ZIP file is empty."
}

Write-Host ""
Write-Host "=== BACKUP COMPLETED SUCCESSFULLY ===" -ForegroundColor Green
Write-Host "Backup folder: $BackupDir" -ForegroundColor Green
Write-Host "ZIP file: $ZipFile" -ForegroundColor Green
Write-Host "ZIP size bytes: $ZipSize" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT: This backup contains .env.local with API keys. Store it safely." -ForegroundColor Yellow