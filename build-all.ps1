# Build script for Niox Communication Plugin (Windows PowerShell)
# Generates AAR, XCFramework, and Windows DLL

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Building Niox Communication Plugin" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Clean previous builds
Write-Host "`nCleaning previous builds..." -ForegroundColor Yellow
& .\gradlew.bat clean

# Build Android AAR
Write-Host "`nBuilding Android AAR..." -ForegroundColor Yellow
& .\gradlew.bat :nioxplugin:assembleRelease

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Android AAR built successfully" -ForegroundColor Green
    Write-Host "  Location: nioxplugin/build/outputs/aar/nioxplugin-release.aar" -ForegroundColor Gray
} else {
    Write-Host "✗ Android AAR build failed" -ForegroundColor Red
}

# Build iOS XCFramework (only on macOS)
if ($IsMacOS) {
    Write-Host "`nBuilding iOS XCFramework..." -ForegroundColor Yellow
    & .\gradlew.bat :nioxplugin:assembleNioxCommunicationPluginXCFramework

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ iOS XCFramework built successfully" -ForegroundColor Green
        Write-Host "  Location: nioxplugin/build/XCFrameworks/release/NioxCommunicationPlugin.xcframework" -ForegroundColor Gray
    } else {
        Write-Host "✗ iOS XCFramework build failed" -ForegroundColor Red
    }
} else {
    Write-Host "`n⚠ Skipping iOS XCFramework build (macOS required)" -ForegroundColor Yellow
}

# Build Windows Native DLL (only on Windows hosts)
if ($IsWindows -or $env:OS -eq "Windows_NT") {
    Write-Host "`nBuilding Windows Native DLL..." -ForegroundColor Yellow
    & .\gradlew.bat :nioxplugin:buildWindowsNativeDll

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Windows DLL built successfully" -ForegroundColor Green
        Write-Host "  Location: nioxplugin/build/outputs/windows/NioxCommunicationPlugin.dll" -ForegroundColor Gray
    } else {
        Write-Host "✗ Windows DLL build failed" -ForegroundColor Red
    }
} else {
    Write-Host "`n⚠ Skipping Windows DLL build (requires Windows host)" -ForegroundColor Yellow
}

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "Build Complete!" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
