# PowerShell script to run all experiments in batch
# This script automates the full experimental cycle

param(
    [string]$OutputDir = "experiments/results",
    [int]$Iterations = 10,
    [int]$WarmUpIterations = 3,
    [switch]$SkipBuild,
    [string[]]$Scenarios = @("all"),
    [int]$PauseBetweenMs = 5000
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$batchId = "batch_$timestamp"
$resultsDir = "$OutputDir/$batchId"

# Create results directory
New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Flutter Performance Experiment Batch" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Batch ID: $batchId"
Write-Host "Output: $resultsDir"
Write-Host "Iterations: $Iterations (warm-up: $WarmUpIterations)"
Write-Host ""

# Collect environment info
Write-Host "[ENV] Collecting environment information..." -ForegroundColor Yellow
$envInfo = @{
    "timestamp" = (Get-Date -Format "o")
    "batchId" = $batchId
    "iterations" = $Iterations
    "warmUpIterations" = $WarmUpIterations
}

# Flutter version
$flutterVersion = & flutter --version --machine 2>$null | ConvertFrom-Json
$envInfo["flutter"] = $flutterVersion

# Git info
try {
    $envInfo["commitHash"] = (& git rev-parse HEAD).Trim()
    $envInfo["gitBranch"] = (& git rev-parse --abbrev-ref HEAD).Trim()
} catch {
    $envInfo["commitHash"] = "unavailable"
}

# Device info via ADB
try {
    $envInfo["deviceModel"] = (& adb shell getprop ro.product.model).Trim()
    $envInfo["androidVersion"] = (& adb shell getprop ro.build.version.release).Trim()
} catch {
    Write-Host "WARNING: Could not get device info via ADB" -ForegroundColor Yellow
}

# Save environment info
$envInfo | ConvertTo-Json -Depth 10 | Out-File "$resultsDir/environment.json"
Write-Host "  Environment saved to $resultsDir/environment.json" -ForegroundColor Green

# Build app in profile mode if not skipped
if (-not $SkipBuild) {
    Write-Host ""
    Write-Host "[BUILD] Building app in profile mode..." -ForegroundColor Yellow
    & flutter build apk --profile
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Build failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "  Build complete" -ForegroundColor Green
}

# Define experiment configurations
$experiments = @(
    @{
        "id" = "SCN-FIB"
        "name" = "Fibonacci Computation"
        "toggle" = "optimFibonacci"
        "measurementDuration" = 5000
    },
    @{
        "id" = "SCN-JSON"
        "name" = "JSON Parsing"
        "toggle" = "largeJsonParce"
        "measurementDuration" = 5000
    },
    @{
        "id" = "SCN-REBUILD"
        "name" = "Widget Rebuild"
        "toggle" = "correctDataUpdate"
        "measurementDuration" = 5000
    },
    @{
        "id" = "SCN-LAZY"
        "name" = "Lazy Loading"
        "toggle" = "lazyLoad"
        "measurementDuration" = 5000
    },
    @{
        "id" = "SCN-IMG"
        "name" = "Image Memory"
        "toggle" = "optimImageSize"
        "measurementDuration" = 5000
    },
    @{
        "id" = "SCN-SHIMMER"
        "name" = "Shimmer Effect"
        "toggle" = "minimizeExpensiveRendering"
        "measurementDuration" = 5000
    }
)

# Filter scenarios if specified
if ($Scenarios -notcontains "all") {
    $experiments = $experiments | Where-Object { $Scenarios -contains $_.id }
}

Write-Host ""
Write-Host "[RUN] Starting experiment batch ($($experiments.Count) experiments)..." -ForegroundColor Yellow
Write-Host ""

$experimentResults = @()

foreach ($exp in $experiments) {
    $expId = $exp.id
    $expName = $exp.name
    $toggle = $exp.toggle
    
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host "Experiment: $expId - $expName" -ForegroundColor Cyan
    Write-Host "Toggle: $toggle" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    
    # Run BASELINE condition
    Write-Host ""
    Write-Host "  [BASELINE] Running with $toggle = false..." -ForegroundColor Yellow
    
    # Update config file
    $configPath = "assets/config/app_config.json"
    $config = Get-Content $configPath | ConvertFrom-Json
    $config.$toggle = $false
    $config | ConvertTo-Json | Out-File $configPath -Encoding utf8
    
    # Run integration test
    $baselineOutput = "$resultsDir/${expId}_baseline.json"
    & flutter drive `
        --driver=test_driver/integration_test.dart `
        --target=integration_test/benchmark_suite.dart `
        --profile `
        --no-pub `
        2>&1 | Tee-Object -Variable baselineLog
    
    # TODO: Parse test output and save to JSON
    # For now, save raw log
    $baselineLog | Out-File "$resultsDir/${expId}_baseline.log"
    Write-Host "  Baseline complete" -ForegroundColor Green
    
    # Pause between conditions
    Write-Host "  Pausing $($PauseBetweenMs/1000)s for thermal stability..."
    Start-Sleep -Milliseconds $PauseBetweenMs
    
    # Run OPTIMIZED condition
    Write-Host ""
    Write-Host "  [OPTIMIZED] Running with $toggle = true..." -ForegroundColor Yellow
    
    # Update config file
    $config.$toggle = $true
    $config | ConvertTo-Json | Out-File $configPath -Encoding utf8
    
    # Run integration test
    $optimizedOutput = "$resultsDir/${expId}_optimized.json"
    & flutter drive `
        --driver=test_driver/integration_test.dart `
        --target=integration_test/benchmark_suite.dart `
        --profile `
        --no-pub `
        2>&1 | Tee-Object -Variable optimizedLog
    
    $optimizedLog | Out-File "$resultsDir/${expId}_optimized.log"
    Write-Host "  Optimized complete" -ForegroundColor Green
    
    # Reset config to baseline for next experiment
    $config.$toggle = $false
    $config | ConvertTo-Json | Out-File $configPath -Encoding utf8
    
    # Store result reference
    $experimentResults += @{
        "id" = $expId
        "name" = $expName
        "toggle" = $toggle
        "baselineLog" = "${expId}_baseline.log"
        "optimizedLog" = "${expId}_optimized.log"
    }
    
    # Pause between experiments
    if ($exp -ne $experiments[-1]) {
        Write-Host ""
        Write-Host "  Pausing before next experiment..."
        Start-Sleep -Milliseconds $PauseBetweenMs
    }
}

# Generate batch summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Batch Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$summary = @{
    "batchId" = $batchId
    "completedAt" = (Get-Date -Format "o")
    "experimentCount" = $experiments.Count
    "experiments" = $experimentResults
}

$summary | ConvertTo-Json -Depth 10 | Out-File "$resultsDir/batch_summary.json"

Write-Host "Results saved to: $resultsDir" -ForegroundColor Green
Write-Host ""
Write-Host "Files generated:"
Get-ChildItem $resultsDir | ForEach-Object { Write-Host "  - $($_.Name)" }
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Review log files for test output"
Write-Host "  2. Parse metrics from DevTools timeline (if recorded)"
Write-Host "  3. Generate comparison reports"
