# Complete Windows Build Script
# Builds BOTH Windows implementations:
#   1. Native DLL (Kotlin/Native + C interop) - NO JVM REQUIRED
#   2. JAR (JVM + JNA) - Requires JRE 11+
#
# Use this script to build all Windows artifacts at once

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Building ALL Windows Implementations" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Check OS
if ($PSVersionTable.Platform -eq "Unix" -or $PSVersionTable.Platform -eq "MacOS") {
    Write-Host "❌ Error: This script must be run on Windows" -ForegroundColor Red
    exit 1
}

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

# Clean previous builds
Write-Host "[0/2] Cleaning previous builds..." -ForegroundColor Yellow
& $GRADLE_CMD clean
Write-Host "✓ Clean completed" -ForegroundColor Green
Write-Host ""

# Track success/failure
$nativeDllSuccess = $false
$jarSuccess = $false

# ========================================
# Build 1: Windows Native DLL
# ========================================
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "[1/2] Building Windows Native DLL" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  • Implementation: Kotlin/Native + C interop" -ForegroundColor Gray
Write-Host "  • Target: mingwX64 (native Windows DLL)" -ForegroundColor Gray
Write-Host "  • Dependencies: None (no JVM required)" -ForegroundColor Gray
Write-Host "  • Size: ~500KB-1MB" -ForegroundColor Gray
Write-Host ""

# Generate C interop bindings
Write-Host "  [1.1] Generating C interop bindings..." -ForegroundColor Yellow
& $GRADLE_CMD :nioxplugin:cinteropWindowsBluetoothWindowsNative

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ Failed to generate C interop bindings" -ForegroundColor Red
} else {
    Write-Host "  ✓ C interop bindings generated" -ForegroundColor Green
}

# Compile Kotlin/Native
Write-Host "  [1.2] Compiling Kotlin/Native code..." -ForegroundColor Yellow
& $GRADLE_CMD :nioxplugin:compileKotlinWindowsNative

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ Failed to compile Kotlin/Native code" -ForegroundColor Red
} else {
    Write-Host "  ✓ Kotlin/Native code compiled" -ForegroundColor Green
}

# Link native DLL
Write-Host "  [1.3] Linking native DLL..." -ForegroundColor Yellow
& $GRADLE_CMD :nioxplugin:buildWindowsNativeDll

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ Failed to link native DLL" -ForegroundColor Red
} else {
    $dllPath = "nioxplugin\build\outputs\windows\NioxCommunicationPlugin.dll"
    if (Test-Path $dllPath) {
        $dllSize = [math]::Round((Get-Item $dllPath).Length / 1KB, 2)
        Write-Host "  ✓ Native DLL built successfully" -ForegroundColor Green
        Write-Host "    Location: $dllPath" -ForegroundColor Gray
        Write-Host "    Size: $dllSize KB" -ForegroundColor Gray
        $nativeDllSuccess = $true
    } else {
        Write-Host "  ❌ DLL not found at expected location" -ForegroundColor Red
    }
}

Write-Host ""

# ========================================
# Build 2: Windows JAR
# ========================================
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "[2/2] Building Windows JAR" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  • Implementation: JVM + JNA" -ForegroundColor Gray
Write-Host "  • Target: JVM (requires JRE 11+)" -ForegroundColor Gray
Write-Host "  • Dependencies: JNA 5.13.0" -ForegroundColor Gray
Write-Host "  • Size: ~2MB" -ForegroundColor Gray
Write-Host ""

Write-Host "  Building JAR..." -ForegroundColor Yellow
& $GRADLE_CMD :nioxplugin:buildWindowsJar

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ Failed to build Windows JAR" -ForegroundColor Red
} else {
    $jarPath = "nioxplugin\build\outputs\windows\niox-communication-plugin-windows-1.0.0.jar"
    if (Test-Path $jarPath) {
        $jarSize = [math]::Round((Get-Item $jarPath).Length / 1KB, 2)
        Write-Host "  ✓ Windows JAR built successfully" -ForegroundColor Green
        Write-Host "    Location: $jarPath" -ForegroundColor Gray
        Write-Host "    Size: $jarSize KB" -ForegroundColor Gray
        $jarSuccess = $true
    } else {
        Write-Host "  ❌ JAR not found at expected location" -ForegroundColor Red
    }
}

Write-Host ""

# ========================================
# Build Summary
# ========================================
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "BUILD SUMMARY" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

if ($nativeDllSuccess) {
    Write-Host "✅ Native DLL: SUCCESS" -ForegroundColor Green
    $dllPath = "nioxplugin\build\outputs\windows\NioxCommunicationPlugin.dll"
    $dllSize = [math]::Round((Get-Item $dllPath).Length / 1KB, 2)
    Write-Host "   Location: $dllPath" -ForegroundColor Gray
    Write-Host "   Size: $dllSize KB" -ForegroundColor Gray
} else {
    Write-Host "❌ Native DLL: FAILED" -ForegroundColor Red
}

Write-Host ""

if ($jarSuccess) {
    Write-Host "✅ JAR: SUCCESS" -ForegroundColor Green
    $jarPath = "nioxplugin\build\outputs\windows\niox-communication-plugin-windows-1.0.0.jar"
    $jarSize = [math]::Round((Get-Item $jarPath).Length / 1KB, 2)
    Write-Host "   Location: $jarPath" -ForegroundColor Gray
    Write-Host "   Size: $jarSize KB" -ForegroundColor Gray
} else {
    Write-Host "❌ JAR: FAILED" -ForegroundColor Red
}

Write-Host ""

# ========================================
# Usage Recommendations
# ========================================
if ($nativeDllSuccess -or $jarSuccess) {
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "WHICH IMPLEMENTATION TO USE?" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Use Native DLL when:" -ForegroundColor Yellow
    Write-Host "  ✓ Building C# / WinUI3 / MAUI desktop app" -ForegroundColor Green
    Write-Host "  ✓ Building C++ native application" -ForegroundColor Green
    Write-Host "  ✓ Want smallest footprint (no JVM)" -ForegroundColor Green
    Write-Host "  ✓ Need instant startup" -ForegroundColor Green
    Write-Host "  ✓ Distributing to end users" -ForegroundColor Green
    Write-Host ""

    Write-Host "Use JAR when:" -ForegroundColor Yellow
    Write-Host "  ✓ Building JVM-based application (Kotlin, Java)" -ForegroundColor Green
    Write-Host "  ✓ JRE already bundled in your app" -ForegroundColor Green
    Write-Host "  ✓ Need to build on macOS/Linux (cross-platform build)" -ForegroundColor Green
    Write-Host ""

    Write-Host "Both implementations provide:" -ForegroundColor Cyan
    Write-Host "  • Identical Bluetooth functionality" -ForegroundColor White
    Write-Host "  • Same Windows Bluetooth API access" -ForegroundColor White
    Write-Host "  • NIOX PRO device filtering" -ForegroundColor White
    Write-Host "  • Device scanning and state detection" -ForegroundColor White
    Write-Host ""
}

# ========================================
# Next Steps
# ========================================
if ($nativeDllSuccess -or $jarSuccess) {
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "NEXT STEPS" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "1. Test the implementations:" -ForegroundColor Yellow
    if ($nativeDllSuccess) {
        Write-Host "   → Native DLL: See BUILD_AND_TEST_WINDOWS_NATIVE.md" -ForegroundColor Gray
    }
    if ($jarSuccess) {
        Write-Host "   → JAR: See docs\CSHARP_MAUI_INTEGRATION.md" -ForegroundColor Gray
    }
    Write-Host ""

    Write-Host "2. Integration guides:" -ForegroundColor Yellow
    Write-Host "   → C# / WinUI3: docs\WINDOWS_NATIVE_DLL_GUIDE.md" -ForegroundColor Gray
    Write-Host "   → C# / MAUI: docs\CSHARP_MAUI_INTEGRATION.md" -ForegroundColor Gray
    Write-Host "   → C++: docs\WINDOWS_NATIVE_DLL_GUIDE.md" -ForegroundColor Gray
    Write-Host ""

    Write-Host "3. Copy to your project:" -ForegroundColor Yellow
    if ($nativeDllSuccess) {
        Write-Host "   Copy-Item 'nioxplugin\build\outputs\windows\NioxCommunicationPlugin.dll' -Destination 'YourProject\bin\'" -ForegroundColor Gray
    }
    if ($jarSuccess) {
        Write-Host "   Copy-Item 'nioxplugin\build\outputs\windows\niox-communication-plugin-windows-1.0.0.jar' -Destination 'YourProject\lib\'" -ForegroundColor Gray
    }
    Write-Host ""
}

# ========================================
# Exit Status
# ========================================
if ($nativeDllSuccess -and $jarSuccess) {
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "ALL BUILDS SUCCESSFUL! 🎉" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Cyan
    exit 0
} elseif ($nativeDllSuccess -or $jarSuccess) {
    Write-Host "=========================================" -ForegroundColor Yellow
    Write-Host "PARTIAL SUCCESS" -ForegroundColor Yellow
    Write-Host "=========================================" -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "=========================================" -ForegroundColor Red
    Write-Host "ALL BUILDS FAILED" -ForegroundColor Red
    Write-Host "=========================================" -ForegroundColor Red
    exit 1
}
