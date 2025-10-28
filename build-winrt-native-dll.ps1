#!/usr/bin/env pwsh
# Build script for Windows WinRT Native DLL (with full BLE support via C++/WinRT)

param(
    [switch]$Clean
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Building NIOX Plugin - Windows WinRT DLL" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running on Windows
if ($PSVersionTable.Platform -and $PSVersionTable.Platform -ne "Win32NT") {
    Write-Host "ERROR: This script must run on Windows" -ForegroundColor Red
    exit 1
}

Write-Host "Platform: Windows" -ForegroundColor Green
Write-Host "Build Type: WinRT Native DLL (Bluetooth LE via C++/WinRT)" -ForegroundColor Green
Write-Host ""

# Check for required tools
Write-Host "Checking for required tools..." -ForegroundColor Yellow

# Check for cl.exe (MSVC compiler) - Optional warning only
$clPath = (Get-Command cl.exe -ErrorAction SilentlyContinue)
if (-not $clPath) {
    Write-Host "WARNING: MSVC compiler (cl.exe) not found in PATH!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Build may fail if not running from Developer Command Prompt." -ForegroundColor Yellow
    Write-Host "If build fails, please:" -ForegroundColor Yellow
    Write-Host "  1. Open 'Developer Command Prompt for VS 2022' or 'Developer PowerShell for VS 2022'" -ForegroundColor White
    Write-Host "  2. Navigate to this directory" -ForegroundColor White
    Write-Host "  3. Run this script again" -ForegroundColor White
    Write-Host ""
    Write-Host "Continuing anyway..." -ForegroundColor Cyan
}
else {
    Write-Host "  √ MSVC compiler found: $($clPath.Path)" -ForegroundColor Green
}

# Check for MinGW (for Kotlin/Native)
$mingwPath = (Get-Command x86_64-w64-mingw32-gcc.exe -ErrorAction SilentlyContinue)
if (-not $mingwPath) {
    Write-Host "WARNING: MinGW not found in PATH" -ForegroundColor Yellow
    Write-Host "  Kotlin/Native will attempt to use its bundled compiler" -ForegroundColor Yellow
}
else {
    Write-Host "  √ MinGW found: $($mingwPath.Path)" -ForegroundColor Green
}

Write-Host ""

# Determine Gradle command
$gradleCmd = if (Test-Path "./gradlew.bat") { "./gradlew.bat" } else { "gradle" }

Write-Host "Using Gradle: $gradleCmd" -ForegroundColor Yellow
Write-Host ""

# Clean if requested
if ($Clean) {
    Write-Host "Cleaning previous builds..." -ForegroundColor Yellow
    & $gradleCmd clean
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Clean failed!" -ForegroundColor Red
        exit 1
    }
    Write-Host ""
}

# Build the WinRT DLL
Write-Host "Building Windows WinRT Native DLL..." -ForegroundColor Yellow
Write-Host "  Step 1: Compiling C++ WinRT wrapper..." -ForegroundColor Cyan
Write-Host "  Step 2: Compiling Kotlin/Native code..." -ForegroundColor Cyan
Write-Host "  Step 3: Linking shared library..." -ForegroundColor Cyan
Write-Host ""

& $gradleCmd buildWindowsWinRtNativeDll

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Build failed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Common issues:" -ForegroundColor Yellow
    Write-Host "  1. Not running from Developer Command Prompt for VS" -ForegroundColor White
    Write-Host "  2. Missing C++/WinRT tools or Windows SDK" -ForegroundColor White
    Write-Host "  3. MinGW compiler issues with Kotlin/Native" -ForegroundColor White
    Write-Host ""
    Write-Host "Solutions:" -ForegroundColor Yellow
    Write-Host "  - Open 'Developer Command Prompt for VS 2019/2022'" -ForegroundColor White
    Write-Host "  - Navigate to project directory" -ForegroundColor White
    Write-Host "  - Run this script again: .\build-winrt-native-dll.ps1" -ForegroundColor White
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Build Successful!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Check if DLL was created
$dllPath = "nioxplugin/build/outputs/windows/NioxCommunicationPluginWinRT.dll"
if (Test-Path $dllPath) {
    $dllSize = (Get-Item $dllPath).Length
    $dllSizeMB = [math]::Round($dllSize / 1MB, 2)
    Write-Host "Output DLL: $dllPath" -ForegroundColor Cyan
    Write-Host "Size: $dllSizeMB MB" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Features:" -ForegroundColor Yellow
    Write-Host "  √ Full Bluetooth LE (BLE) support" -ForegroundColor Green
    Write-Host "  √ RSSI values available" -ForegroundColor Green
    Write-Host "  √ Hardware service UUID filtering" -ForegroundColor Green
    Write-Host "  √ Uses Windows.Devices.Bluetooth APIs" -ForegroundColor Green
    Write-Host "  √ Compatible with Windows 10/11" -ForegroundColor Green
    Write-Host "  √ C API for P/Invoke from C#" -ForegroundColor Green
    Write-Host ""
    Write-Host "Exported Functions:" -ForegroundColor Yellow
    Write-Host "  - niox_init()" -ForegroundColor White
    Write-Host "  - niox_check_bluetooth()" -ForegroundColor White
    Write-Host "  - niox_scan_devices(durationMs, nioxOnly)" -ForegroundColor White
    Write-Host "  - niox_free_string(ptr)" -ForegroundColor White
    Write-Host "  - niox_cleanup()" -ForegroundColor White
    Write-Host "  - niox_version()" -ForegroundColor White
    Write-Host "  - niox_implementation()" -ForegroundColor White
} else {
    Write-Host "Warning: Output DLL not found at $dllPath" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Usage in C#:" -ForegroundColor Yellow
Write-Host "  1. Copy NioxCommunicationPluginWinRT.dll to your project" -ForegroundColor White
Write-Host "  2. Use P/Invoke to call exported functions" -ForegroundColor White
Write-Host "  3. See example/Windows/NioxBluetoothApp/ for integration" -ForegroundColor White
Write-Host ""
Write-Host "API Comparison:" -ForegroundColor Yellow
Write-Host "  Old DLL (NioxCommunicationPlugin.dll):" -ForegroundColor White
Write-Host "    - Bluetooth Classic only" -ForegroundColor Red
Write-Host "    - No RSSI values" -ForegroundColor Red
Write-Host "    - Name-based filtering" -ForegroundColor Red
Write-Host ""
Write-Host "  New DLL (NioxCommunicationPluginWinRT.dll):" -ForegroundColor White
Write-Host "    - Bluetooth LE (BLE)" -ForegroundColor Green
Write-Host "    - RSSI values included" -ForegroundColor Green
Write-Host "    - Hardware UUID filtering" -ForegroundColor Green
Write-Host ""
