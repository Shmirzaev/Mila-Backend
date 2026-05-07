$ErrorActionPreference = "Stop"

$ProjectPath = "C:\MILA"
$BackupRoot = "C:\MILA_BACKUPS"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

$BackupDir = Join-Path $BackupRoot "MILA_BACKUP_$Timestamp"
$ProjectBackupDir = Join-Path $BackupDir "project"
$DbBackupFile = Join-Path $BackupDir "mila_ai_backup.sql"
$ZipFile = Join-Path $BackupRoot "MILA_BACKUP_$Timestamp.zip"

Write-Host "Creating backup folder..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
New-Item -ItemType Directory -Force -Path $ProjectBackupDir | Out-Null

Write-Host "Checking project path..." -ForegroundColor Cyan
if (!(Test-Path $ProjectPath)) {
    throw "Project path not found: $ProjectPath"
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
    /XD ".venv" "data" "__pycache__" ".git" `
    /XF "*.pyc" "*.pyo" | Out-Null

Write-Host "Checking Docker container..." -ForegroundColor Cyan

$ContainerCheck = docker ps --format "{{.Names}}" | Select-String -Pattern "^mila_postgres$"

if (!$ContainerCheck) {
    throw "Docker container mila_postgres is not running. Start it first with: docker compose up -d"
}

Write-Host "Creating PostgreSQL backup..." -ForegroundColor Cyan

docker exec mila_postgres pg_dump -U mila -d mila_ai --clean --if-exists > $DbBackupFile

Write-Host "Saving memory count..." -ForegroundColor Cyan

docker exec mila_postgres psql -U mila -d mila_ai -t -A -c "SELECT COUNT(*) FROM ai_memory;" > (Join-Path $BackupDir "memory_count.txt")

Write-Host "Saving Docker container list..." -ForegroundColor Cyan

docker ps > (Join-Path $BackupDir "docker_ps.txt")

Write-Host "Creating ZIP archive..." -ForegroundColor Cyan

Compress-Archive -Path "$BackupDir\*" -DestinationPath $ZipFile -Force

Write-Host ""
Write-Host "BACKUP COMPLETED SUCCESSFULLY" -ForegroundColor Green
Write-Host "Backup folder: $BackupDir" -ForegroundColor Green
Write-Host "ZIP file: $ZipFile" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT: This backup contains .env.local with API keys. Store it safely." -ForegroundColor YellowGet-ChildItem C:\MILA_BACKUPS | Sort-Object LastWriteTime -Descending | Select-Object -First 3