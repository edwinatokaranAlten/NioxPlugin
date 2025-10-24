# Build script for Windows JAR (JVM Implementation)
# Generates: niox-communication-plugin-windows-1.0.0.jar
# Technology: JVM + JNA for Windows Bluetooth API access
# Requirements: JDK 11+

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Building Windows JAR" -ForegroundColor Cyan
Write-Host "JVM + JNA Implementation" -ForegroundColor Cyan
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
Write-Host ""

# Build JAR
Write-Host "[1/2] Cleaning previous builds..." -ForegroundColor Yellow
& $GRADLE_CMD clean

Write-Host ""
Write-Host "[2/2] Building Windows JAR..." -ForegroundColor Yellow
& $GRADLE_CMD :nioxplugin:buildWindowsJar

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "✅ BUILD SUCCESS" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""

    $jarPath = "nioxplugin\build\outputs\windows\niox-communication-plugin-windows-1.0.0.jar"

    if (Test-Path $jarPath) {
        $jarSize = [math]::Round((Get-Item $jarPath).Length / 1KB, 2)
        Write-Host "📦 Windows JAR Information:" -ForegroundColor White
        Write-Host "  Location: $jarPath" -ForegroundColor Gray
        Write-Host "  Size: $jarSize KB" -ForegroundColor Gray
        Write-Host "  Technology: JVM + JNA" -ForegroundColor Gray
        Write-Host "  Requirements: JRE 11+" -ForegroundColor Gray
        Write-Host ""

        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "  1. Copy JAR to your project: libs/" -ForegroundColor White
        Write-Host "  2. Add to dependencies (Gradle):" -ForegroundColor White
        Write-Host "     implementation(files('libs/niox-communication-plugin-windows-1.0.0.jar'))" -ForegroundColor Gray
        Write-Host "  3. Ensure JNA dependency is included" -ForegroundColor White
        Write-Host ""

        Write-Host "Use for:" -ForegroundColor Cyan
        Write-Host "  ✓ JVM-based applications (Kotlin, Java)" -ForegroundColor Green
        Write-Host "  ✓ Cross-platform JVM apps" -ForegroundColor Green
        Write-Host "  ✓ When JRE is already bundled" -ForegroundColor Green
        Write-Host ""

        exit 0
    } else {
        Write-Host "⚠️  JAR file not found at expected location" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Red
    Write-Host "❌ BUILD FAILED" -ForegroundColor Red
    Write-Host "=========================================" -ForegroundColor Red
    exit 1
}
