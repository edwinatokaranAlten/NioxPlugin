# Build script for Niox Communication Plugin (Windows PowerShell)
# Generates Android AAR and Windows DLL

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Building Niox Communication Plugin (Windows)" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Determine which Gradle command to use
if (Test-Path ".\gradlew.bat" -PathType Leaf) {
    $GRADLE_CMD = ".\gradlew.bat"
} elseif (Get-Command gradle -ErrorAction SilentlyContinue) {
    $GRADLE_CMD = "gradle"
} else {
    Write-Host "❌ Error: Neither gradlew.bat nor gradle command found" -ForegroundColor Red
    exit 1
}

Write-Host "Using Gradle: $GRADLE_CMD" -ForegroundColor Gray

# Clean previous builds
Write-Host "`nCleaning previous builds..." -ForegroundColor Yellow
& $GRADLE_CMD clean

# Build Android AAR
Write-Host "`nBuilding Android AAR..." -ForegroundColor Yellow
& $GRADLE_CMD :nioxplugin:assembleRelease

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Android AAR built successfully" -ForegroundColor Green
    Write-Host "  Location: nioxplugin/build/outputs/aar/nioxplugin-release.aar" -ForegroundColor Gray
} else {
    Write-Host "✗ Android AAR build failed" -ForegroundColor Red
}

# Build Windows Native DLL
Write-Host "`nBuilding Windows Native DLL..." -ForegroundColor Yellow
& $GRADLE_CMD :nioxplugin:buildWindowsNativeDll

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Windows DLL built successfully" -ForegroundColor Green
    Write-Host "  Location: nioxplugin/build/outputs/windows/NioxCommunicationPlugin.dll" -ForegroundColor Gray
} else {
    Write-Host "✗ Windows DLL build failed" -ForegroundColor Red
}

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "Build Complete!" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
