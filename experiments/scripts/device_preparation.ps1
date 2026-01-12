# PowerShell script for device preparation before experiments
# Run this BEFORE starting experiment batch

param(
    [switch]$SkipThermalCheck,
    [int]$CooldownMinutes = 2
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Device Preparation for Experiments" -ForegroundColor Cyan  
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check ADB connection
Write-Host "[1/7] Checking ADB connection..." -ForegroundColor Yellow
$adbDevices = & adb devices 2>&1
if ($adbDevices -notmatch "device$") {
    Write-Host "ERROR: No device connected via ADB" -ForegroundColor Red
    Write-Host "Please connect device with USB debugging enabled" -ForegroundColor Red
    exit 1
}
$deviceLine = ($adbDevices -split "`n" | Where-Object { $_ -match "device$" })[0]
$deviceId = ($deviceLine -split "\t")[0]
Write-Host "  Device connected: $deviceId" -ForegroundColor Green

# Get device info
Write-Host ""
Write-Host "[2/7] Collecting device information..." -ForegroundColor Yellow
$deviceModel = & adb shell getprop ro.product.model
$androidVersion = & adb shell getprop ro.build.version.release
$sdkVersion = & adb shell getprop ro.build.version.sdk
Write-Host "  Model: $deviceModel"
Write-Host "  Android: $androidVersion (SDK $sdkVersion)"

# Check thermal state
if (-not $SkipThermalCheck) {
    Write-Host ""
    Write-Host "[3/7] Checking thermal state..." -ForegroundColor Yellow
    
    # Try multiple thermal zone paths
    $thermalPaths = @(
        "/sys/class/thermal/thermal_zone0/temp",
        "/sys/devices/virtual/thermal/thermal_zone0/temp"
    )
    
    $temp = $null
    foreach ($path in $thermalPaths) {
        try {
            $tempRaw = & adb shell "cat $path 2>/dev/null"
            if ($tempRaw -match "^\d+$") {
                $temp = [int]$tempRaw / 1000  # Convert millidegrees to degrees
                break
            }
        } catch {}
    }
    
    if ($temp) {
        Write-Host "  Current temperature: ${temp}°C"
        if ($temp -gt 40) {
            Write-Host "  WARNING: Device is warm (>${temp}°C)" -ForegroundColor Yellow
            Write-Host "  Consider waiting for cooldown to avoid thermal throttling" -ForegroundColor Yellow
        } else {
            Write-Host "  Temperature OK" -ForegroundColor Green
        }
    } else {
        Write-Host "  Could not read thermal sensor (may require root)" -ForegroundColor Yellow
    }
} else {
    Write-Host ""
    Write-Host "[3/7] Skipping thermal check (--SkipThermalCheck)" -ForegroundColor Yellow
}

# Set screen brightness to 50%
Write-Host ""
Write-Host "[4/7] Setting screen brightness to 50%..." -ForegroundColor Yellow
& adb shell settings put system screen_brightness 128
Write-Host "  Brightness set to 50%" -ForegroundColor Green

# Disable animations (optional - may affect some experiments)
Write-Host ""
Write-Host "[5/7] Checking animation settings..." -ForegroundColor Yellow
$animatorDuration = & adb shell settings get global animator_duration_scale
$transitionDuration = & adb shell settings get global transition_animation_scale
$windowDuration = & adb shell settings get global window_animation_scale
Write-Host "  Animator scale: $animatorDuration"
Write-Host "  Transition scale: $transitionDuration"
Write-Host "  Window scale: $windowDuration"
Write-Host "  (Leave at 1.0 for accurate frame timing measurements)" -ForegroundColor Cyan

# Kill background apps
Write-Host ""
Write-Host "[6/7] Clearing background processes..." -ForegroundColor Yellow
& adb shell am kill-all
Write-Host "  Background apps killed" -ForegroundColor Green

# Check available storage
Write-Host ""
Write-Host "[7/7] Checking storage for results..." -ForegroundColor Yellow
$storage = & adb shell df /data | Select-Object -Last 1
Write-Host "  Storage: $storage"

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Device Preparation Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Device is ready for experiments." -ForegroundColor Green
Write-Host ""
Write-Host "Recommended steps before running experiments:" -ForegroundColor Yellow
Write-Host "  1. Enable Airplane Mode (reduces variance)"
Write-Host "  2. Close all apps"
Write-Host "  3. Wait $CooldownMinutes minutes for thermal stability"
Write-Host "  4. Keep device connected and screen on"
Write-Host ""

# Optional cooldown
if ($CooldownMinutes -gt 0) {
    Write-Host "Waiting $CooldownMinutes minutes for thermal stability..." -ForegroundColor Yellow
    for ($i = $CooldownMinutes; $i -gt 0; $i--) {
        Write-Host "  $i minute(s) remaining..."
        Start-Sleep -Seconds 60
    }
    Write-Host "Cooldown complete!" -ForegroundColor Green
}

Write-Host ""
Write-Host "Run experiments with:" -ForegroundColor Cyan
Write-Host "  flutter drive --driver=test_driver/integration_test.dart --target=integration_test/benchmark_suite.dart --profile"
