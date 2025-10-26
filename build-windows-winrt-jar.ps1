#!/usr/bin/env pwsh
# Build script for Windows WinRT JAR (with full BLE support)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Building NIOX Plugin - Windows WinRT JAR" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running on Windows
if ($PSVersionTable.Platform -and $PSVersionTable.Platform -ne "Win32NT") {
    Write-Host "ERROR: This script must run on Windows" -ForegroundColor Red
    exit 1
}

Write-Host "Platform: Windows" -ForegroundColor Green
Write-Host "Build Type: WinRT JAR (Bluetooth LE)" -ForegroundColor Green
Write-Host ""

# Determine Gradle command
$gradleCmd = if (Test-Path "./gradlew.bat") { "./gradlew.bat" } else { "gradle" }

Write-Host "Using Gradle: $gradleCmd" -ForegroundColor Yellow
Write-Host ""

# Build the WinRT JAR
Write-Host "Building Windows WinRT JAR..." -ForegroundColor Yellow
& $gradleCmd buildWindowsWinRtJar

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Build failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Build Successful!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Check if JAR was created
$jarPath = "nioxplugin/build/outputs/windows/niox-communication-plugin-windows-winrt-1.0.0.jar"
if (Test-Path $jarPath) {
    $jarSize = (Get-Item $jarPath).Length
    $jarSizeMB = [math]::Round($jarSize / 1MB, 2)
    Write-Host "Output JAR: $jarPath" -ForegroundColor Cyan
    Write-Host "Size: $jarSizeMB MB" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Features:" -ForegroundColor Yellow
    Write-Host "  - Full Bluetooth LE (BLE) support" -ForegroundColor White
    Write-Host "  - RSSI values available" -ForegroundColor White
    Write-Host "  - Service UUID filtering" -ForegroundColor White
    Write-Host "  - Uses Windows.Devices.Bluetooth APIs" -ForegroundColor White
    Write-Host "  - Compatible with Windows 10/11" -ForegroundColor White
} else {
    Write-Host "Warning: Output JAR not found at $jarPath" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Usage:" -ForegroundColor Yellow
Write-Host "  Add the JAR to your project's classpath" -ForegroundColor White
Write-Host "  Import: import com.niox.nioxplugin.*" -ForegroundColor White
Write-Host "  Create: val plugin = createNioxCommunicationPlugin()" -ForegroundColor White
Write-Host ""
