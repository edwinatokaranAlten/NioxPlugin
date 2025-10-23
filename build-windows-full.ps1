# Build script for FULL-FEATURED Windows DLL (via JAR + IKVM)
# This builds the REAL Bluetooth implementation, not the stub

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Building FULL-FEATURED Windows DLL" -ForegroundColor Cyan
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

# Step 1: Build Windows JAR (contains FULL Bluetooth implementation)
Write-Host "`n[1/3] Building Windows JAR with FULL Bluetooth API..." -ForegroundColor Yellow
& $GRADLE_CMD :nioxplugin:buildWindowsJar

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to build Windows JAR" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Windows JAR built successfully" -ForegroundColor Green
$jarPath = "nioxplugin\build\outputs\windows\niox-communication-plugin-windows-1.0.0.jar"
Write-Host "  Location: $jarPath" -ForegroundColor Gray

# Check if JAR exists
if (-not (Test-Path $jarPath)) {
    Write-Host "❌ JAR file not found at expected location" -ForegroundColor Red
    exit 1
}

# Step 2: Check if IKVM is installed
Write-Host "`n[2/3] Checking for IKVM..." -ForegroundColor Yellow

if (-not (Get-Command ikvmc -ErrorAction SilentlyContinue)) {
    Write-Host "⚠ IKVM not found. Installing IKVM..." -ForegroundColor Yellow
    dotnet tool install -g ikvm

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to install IKVM" -ForegroundColor Red
        Write-Host "Please install manually: dotnet tool install -g ikvm" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "✓ IKVM installed successfully" -ForegroundColor Green
} else {
    Write-Host "✓ IKVM is already installed" -ForegroundColor Green
    $ikvmVersion = ikvmc -version 2>&1 | Select-Object -First 1
    Write-Host "  Version: $ikvmVersion" -ForegroundColor Gray
}

# Step 3: Convert JAR to DLL using IKVM
Write-Host "`n[3/3] Converting JAR to .NET DLL..." -ForegroundColor Yellow

$outputDir = "nioxplugin\build\outputs\windows"
$dllPath = "$outputDir\NioxPlugin.dll"

# Change to output directory
Push-Location $outputDir

# Run IKVM conversion
ikvmc -target:library `
     -out:NioxPlugin.dll `
     -version:1.0.0.0 `
     niox-communication-plugin-windows-1.0.0.jar

$ikvmExitCode = $LASTEXITCODE

# Return to original directory
Pop-Location

if ($ikvmExitCode -ne 0) {
    Write-Host "❌ Failed to convert JAR to DLL" -ForegroundColor Red
    exit 1
}

Write-Host "✓ DLL created successfully" -ForegroundColor Green
Write-Host "  Location: $dllPath" -ForegroundColor Gray

# Verify DLL exists
if (-not (Test-Path $dllPath)) {
    Write-Host "❌ DLL file not found after conversion" -ForegroundColor Red
    exit 1
}

# Get file size
$dllSize = (Get-Item $dllPath).Length / 1KB
Write-Host "  Size: $([math]::Round($dllSize, 2)) KB" -ForegroundColor Gray

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "SUCCESS! Full-Featured DLL Built!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan

Write-Host "`nYour DLL with FULL Bluetooth features is ready:" -ForegroundColor White
Write-Host "  $dllPath" -ForegroundColor Cyan

Write-Host "`nThis DLL includes:" -ForegroundColor White
Write-Host "  ✓ Bluetooth adapter state checking" -ForegroundColor Green
Write-Host "  ✓ Device scanning (Windows Bluetooth API)" -ForegroundColor Green
Write-Host "  ✓ NIOX device filtering" -ForegroundColor Green
Write-Host "  ✓ Device information (name, address, etc.)" -ForegroundColor Green

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "  1. Copy NioxPlugin.dll to your WinUI/MAUI project" -ForegroundColor White
Write-Host "  2. Follow the guide: docs\WINUI3_STEP_BY_STEP.md" -ForegroundColor White
Write-Host "  3. Add IKVM NuGet package to your project" -ForegroundColor White
Write-Host "  4. Reference the DLL in your .csproj" -ForegroundColor White

Write-Host "`n=========================================" -ForegroundColor Cyan
