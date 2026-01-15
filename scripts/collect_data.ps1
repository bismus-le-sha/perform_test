<# 
.SYNOPSIS
    Runs raw data collection and retrieves CSV file from device.
    
.DESCRIPTION
    This script:
    1. Clears old data files from device
    2. Runs the integration test in profile mode
    3. Pulls the CSV file from device to local raw_data/ folder
    4. Validates the data file
    
.NOTES
    CRITICAL: This script produces STRUCTURED DATA, not logs.
    The CSV file is written directly by Dart code, not parsed from stdout.
#>

param(
    [string]$OutputDir = "..\..\raw_data\runs"
)

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  STAGE 1: RAW DATA COLLECTION" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Ensure output directory exists
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "[OK] Created output directory: $OutputDir" -ForegroundColor Green
}

# Check device connection
Write-Host "[1/5] Checking device connection..." -ForegroundColor Yellow
$devices = adb devices | Select-String "device$"
if (-not $devices) {
    Write-Host "[ERROR] No Android device connected!" -ForegroundColor Red
    Write-Host "        Connect device and enable USB debugging." -ForegroundColor Red
    exit 1
}
$deviceId = ($devices -split '\s+')[0]
Write-Host "       Device: $deviceId" -ForegroundColor Gray

# Clear old data files
Write-Host "[2/5] Clearing old data files from device..." -ForegroundColor Yellow
adb shell "rm -f /sdcard/Download/flutter_perf_raw_*.csv" 2>$null
Write-Host "       Done" -ForegroundColor Gray

# Disable screen timeout during test
Write-Host "[3/5] Configuring device for testing..." -ForegroundColor Yellow
adb shell "svc power stayon true"
Write-Host "       Screen timeout disabled" -ForegroundColor Gray

# Run integration test
Write-Host "[4/5] Running data collection test..." -ForegroundColor Yellow
Write-Host "       This will take approximately 20-30 minutes." -ForegroundColor Gray
Write-Host ""

$startTime = Get-Date

# Run the test - output goes to console for monitoring, data goes to file on device
flutter drive `
    --driver=test_driver/integration_test.dart `
    --target=integration_test/raw_data_collector.dart `
    --profile `
    --no-pub

$testExitCode = $LASTEXITCODE
$duration = (Get-Date) - $startTime

Write-Host ""
Write-Host "       Test completed in $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Gray

# Restore screen settings
adb shell "svc power stayon false"

if ($testExitCode -ne 0) {
    Write-Host "[WARNING] Test exited with code $testExitCode" -ForegroundColor Yellow
    Write-Host "          Attempting to retrieve partial data..." -ForegroundColor Yellow
}

# Pull data file from device
Write-Host "[5/5] Retrieving data file from device..." -ForegroundColor Yellow

$remoteFiles = adb shell "ls /sdcard/Download/flutter_perf_raw_*.csv 2>/dev/null"
if (-not $remoteFiles -or $remoteFiles -match "No such file") {
    Write-Host "[ERROR] No data file found on device!" -ForegroundColor Red
    Write-Host "        Check test output for errors." -ForegroundColor Red
    exit 1
}

$remoteFile = $remoteFiles.Trim()
$localFile = Join-Path $OutputDir (Split-Path $remoteFile -Leaf)

adb pull $remoteFile $localFile
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to pull data file!" -ForegroundColor Red
    exit 1
}

# Validate data file
$rowCount = (Get-Content $localFile | Measure-Object -Line).Lines - 1  # Subtract header
$fileSize = (Get-Item $localFile).Length

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  DATA COLLECTION COMPLETE" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "  Output file:  $localFile" -ForegroundColor White
Write-Host "  Data rows:    $rowCount" -ForegroundColor White
Write-Host "  File size:    $([math]::Round($fileSize/1024, 1)) KB" -ForegroundColor White
Write-Host "  Duration:     $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor White
Write-Host ""
Write-Host "  Next step: Run analysis" -ForegroundColor Cyan
Write-Host "  python ..\analysis\scripts\analyze_raw.py $localFile -o ..\analysis\output\" -ForegroundColor Gray
Write-Host ""

# Quick data preview
Write-Host "  Data preview (first 5 rows):" -ForegroundColor Cyan
Get-Content $localFile | Select-Object -First 6 | ForEach-Object {
    Write-Host "    $_" -ForegroundColor Gray
}
Write-Host ""
