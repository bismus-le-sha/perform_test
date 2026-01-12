#!/bin/bash
# Device preparation script for Linux/Mac
# Run this BEFORE starting experiment batch

set -e

SKIP_THERMAL=false
COOLDOWN_MINUTES=2

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-thermal)
            SKIP_THERMAL=true
            shift
            ;;
        --cooldown)
            COOLDOWN_MINUTES="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "========================================"
echo "  Device Preparation for Experiments"
echo "========================================"
echo ""

# Check ADB connection
echo "[1/7] Checking ADB connection..."
if ! adb devices | grep -q "device$"; then
    echo "ERROR: No device connected via ADB"
    echo "Please connect device with USB debugging enabled"
    exit 1
fi
DEVICE_ID=$(adb devices | grep "device$" | head -1 | cut -f1)
echo "  Device connected: $DEVICE_ID"

# Get device info
echo ""
echo "[2/7] Collecting device information..."
DEVICE_MODEL=$(adb shell getprop ro.product.model | tr -d '\r')
ANDROID_VERSION=$(adb shell getprop ro.build.version.release | tr -d '\r')
SDK_VERSION=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
echo "  Model: $DEVICE_MODEL"
echo "  Android: $ANDROID_VERSION (SDK $SDK_VERSION)"

# Check thermal state
if [ "$SKIP_THERMAL" = false ]; then
    echo ""
    echo "[3/7] Checking thermal state..."
    
    TEMP=$(adb shell "cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null" | tr -d '\r')
    if [[ "$TEMP" =~ ^[0-9]+$ ]]; then
        TEMP_C=$((TEMP / 1000))
        echo "  Current temperature: ${TEMP_C}°C"
        if [ "$TEMP_C" -gt 40 ]; then
            echo "  WARNING: Device is warm (>${TEMP_C}°C)"
            echo "  Consider waiting for cooldown to avoid thermal throttling"
        else
            echo "  Temperature OK"
        fi
    else
        echo "  Could not read thermal sensor (may require root)"
    fi
else
    echo ""
    echo "[3/7] Skipping thermal check (--skip-thermal)"
fi

# Set screen brightness
echo ""
echo "[4/7] Setting screen brightness to 50%..."
adb shell settings put system screen_brightness 128
echo "  Brightness set to 50%"

# Check animation settings
echo ""
echo "[5/7] Checking animation settings..."
ANIMATOR=$(adb shell settings get global animator_duration_scale | tr -d '\r')
TRANSITION=$(adb shell settings get global transition_animation_scale | tr -d '\r')
WINDOW=$(adb shell settings get global window_animation_scale | tr -d '\r')
echo "  Animator scale: $ANIMATOR"
echo "  Transition scale: $TRANSITION"
echo "  Window scale: $WINDOW"
echo "  (Leave at 1.0 for accurate frame timing measurements)"

# Kill background apps
echo ""
echo "[6/7] Clearing background processes..."
adb shell am kill-all
echo "  Background apps killed"

# Check storage
echo ""
echo "[7/7] Checking storage for results..."
adb shell df /data | tail -1

# Summary
echo ""
echo "========================================"
echo "  Device Preparation Complete"
echo "========================================"
echo ""
echo "Device is ready for experiments."
echo ""
echo "Recommended steps before running experiments:"
echo "  1. Enable Airplane Mode (reduces variance)"
echo "  2. Close all apps"
echo "  3. Wait $COOLDOWN_MINUTES minutes for thermal stability"
echo "  4. Keep device connected and screen on"
echo ""

# Optional cooldown
if [ "$COOLDOWN_MINUTES" -gt 0 ]; then
    echo "Waiting $COOLDOWN_MINUTES minutes for thermal stability..."
    for ((i=COOLDOWN_MINUTES; i>0; i--)); do
        echo "  $i minute(s) remaining..."
        sleep 60
    done
    echo "Cooldown complete!"
fi

echo ""
echo "Run experiments with:"
echo "  flutter drive --driver=test_driver/integration_test.dart --target=integration_test/benchmark_suite.dart --profile"
