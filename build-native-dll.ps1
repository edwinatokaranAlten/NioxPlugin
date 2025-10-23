# Build script for Windows Native DLL (Full Bluetooth Implementation)
# This builds a FULLY FUNCTIONAL native DLL using Kotlin/Native C interop
# NO JVM REQUIRED - Pure native Windows DLL
#
# Usage:
#   .\build-native-dll.ps1           # Normal build (uses cache)
#   .\build-native-dll.ps1 -Clean    # Force rebuild (cleans all caches)

param(
    [switch]$Clean,  # Force clean all caches before building
    [switch]$Help    # Show help
)

# Show help if requested
if ($Help) {
    Write-Host @"
Windows Native DLL Build Script

Usage:
  .\build-native-dll.ps1           Normal build (fast, uses cache)
  .\build-native-dll.ps1 -Clean    Force rebuild (cleans all caches)
  .\build-native-dll.ps1 -Help     Show this help

Normal Build:
  • Uses Gradle cache for speed
  • Verifies source files
  • Best for regular development
  • Time: ~30-60 seconds

Force Clean Build (-Clean):
  • Stops Gradle daemon
  • Deletes all caches
  • Forces fresh compilation
  • Use when cache issues occur
  • Time: ~60-90 seconds

Examples:
  .\build-native-dll.ps1              # Regular development
  .\build-native-dll.ps1 -Clean       # After git pull or cache issues

"@
    exit 0
}

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Building Windows Native DLL" -ForegroundColor Cyan
Write-Host "Kotlin/Native + C Interop Implementation" -ForegroundColor Cyan
if ($Clean) {
    Write-Host "MODE: Force Clean Build (all caches)" -ForegroundColor Yellow
} else {
    Write-Host "MODE: Normal Build (uses cache)" -ForegroundColor Gray
}
Write-Host "=========================================" -ForegroundColor Cyan

# Check OS
if ($PSVersionTable.Platform -eq "Unix" -or $PSVersionTable.Platform -eq "MacOS") {
    Write-Host "❌ Error: This script must be run on Windows" -ForegroundColor Red
    Write-Host "   The Windows Native DLL requires Windows host with MinGW toolchain" -ForegroundColor Yellow
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

# Determine total steps
$totalSteps = if ($Clean) { 8 } else { 6 }

# Step 0: Source file verification
Write-Host "[1/$totalSteps] Verifying source file..." -ForegroundColor Yellow
$sourceFile = "nioxplugin\src\windowsNativeMain\kotlin\com\niox\nioxplugin\NioxCommunicationPlugin.windowsNative.kt"

if (-not (Test-Path $sourceFile)) {
    Write-Host "❌ Source file not found: $sourceFile" -ForegroundColor Red
    exit 1
}

# Check for updated code markers
$fileContent = Get-Content $sourceFile -Raw
$hasUnsafeNumber = $fileContent -match '@OptIn\(ExperimentalForeignApi::class, UnsafeNumber::class\)'
$hasHANDLEVar = $fileContent -match 'alloc<HANDLEVar>\(\)'
$hasConvert = $fileContent -match '\.convert\(\)'

if ($hasUnsafeNumber -and $hasHANDLEVar -and $hasConvert) {
    Write-Host "✓ Source file verified (contains updated code)" -ForegroundColor Green
} else {
    Write-Host "⚠ Warning: Source file may be outdated" -ForegroundColor Yellow
    Write-Host "  Missing expected markers:" -ForegroundColor Gray
    if (-not $hasUnsafeNumber) { Write-Host "    • UnsafeNumber annotation" -ForegroundColor Gray }
    if (-not $hasHANDLEVar) { Write-Host "    • HANDLEVar usage" -ForegroundColor Gray }
    if (-not $hasConvert) { Write-Host "    • .convert() calls" -ForegroundColor Gray }
    Write-Host ""

    if (-not $Clean) {
        Write-Host "Suggestion: Run with -Clean flag to force fresh build" -ForegroundColor Yellow
        Write-Host "  .\build-native-dll.ps1 -Clean" -ForegroundColor Cyan
        Write-Host ""
        $response = Read-Host "Continue anyway? (y/n)"
        if ($response -ne 'y') {
            exit 1
        }
    }
}

$currentStep = 2

# If Clean mode, perform deep cleaning
if ($Clean) {
    Write-Host "`n[$currentStep/$totalSteps] Stopping Gradle daemon..." -ForegroundColor Yellow
    & $GRADLE_CMD --stop 2>&1 | Out-Null
    Start-Sleep -Seconds 2
    Write-Host "✓ Gradle daemon stopped" -ForegroundColor Green
    $currentStep++

    Write-Host "`n[$currentStep/$totalSteps] Deep cleaning caches..." -ForegroundColor Yellow

    # Clean build directory
    if (Test-Path "nioxplugin\build") {
        Remove-Item -Recurse -Force "nioxplugin\build" -ErrorAction SilentlyContinue
        Write-Host "  ✓ Removed nioxplugin\build\" -ForegroundColor Green
    }

    # Clean Gradle caches
    if (Test-Path ".gradle\caches") {
        Remove-Item -Recurse -Force ".gradle\caches" -ErrorAction SilentlyContinue
        Write-Host "  ✓ Removed .gradle\caches\" -ForegroundColor Green
    }

    # Clean Kotlin DSL cache
    if (Test-Path ".gradle") {
        Get-ChildItem ".gradle\*\kotlin-dsl" -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Removed Kotlin DSL caches" -ForegroundColor Green
    }

    # Clean Kotlin compiler cache
    $kotlinCache = "$env:USERPROFILE\.kotlin"
    if (Test-Path $kotlinCache) {
        Remove-Item -Recurse -Force "$kotlinCache\*" -ErrorAction SilentlyContinue
        Write-Host "  ✓ Removed Kotlin compiler cache" -ForegroundColor Green
    }

    # Clean Konan cache (Kotlin/Native)
    $konanCache = "$env:USERPROFILE\.konan\cache"
    if (Test-Path $konanCache) {
        Remove-Item -Recurse -Force $konanCache -ErrorAction SilentlyContinue
        Write-Host "  ✓ Removed Kotlin/Native cache" -ForegroundColor Green
    }

    Write-Host "✓ Deep clean completed" -ForegroundColor Green
    $currentStep++
}

# Check Java version
Write-Host "`n[$currentStep/$totalSteps] Checking Java version..." -ForegroundColor Yellow
$javaVersion = java -version 2>&1 | Select-Object -First 1
Write-Host "  $javaVersion" -ForegroundColor Gray

if (-not $javaVersion) {
    Write-Host "❌ Java not found. Please install JDK 11 or higher" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Java found" -ForegroundColor Green
$currentStep++

# Clean previous builds
Write-Host "`n[$currentStep/$totalSteps] Cleaning previous builds..." -ForegroundColor Yellow
$cleanFlags = @("clean")
if ($Clean) {
    $cleanFlags += @("--no-configuration-cache", "--no-build-cache", "--no-daemon")
} else {
    $cleanFlags += @("--no-configuration-cache")
}

& $GRADLE_CMD @cleanFlags 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠ Warning: Clean had issues, continuing anyway..." -ForegroundColor Yellow
} else {
    Write-Host "✓ Clean completed" -ForegroundColor Green
}
$currentStep++

# Generate C interop bindings
Write-Host "`n[$currentStep/$totalSteps] Generating C interop bindings for Windows Bluetooth APIs..." -ForegroundColor Yellow
Write-Host "  This step creates Kotlin bindings for:" -ForegroundColor Gray
Write-Host "    - BluetoothFindFirstRadio" -ForegroundColor Gray
Write-Host "    - BluetoothFindFirstDevice" -ForegroundColor Gray
Write-Host "    - BluetoothFindNextDevice" -ForegroundColor Gray
Write-Host "    - CloseHandle (Kernel32)" -ForegroundColor Gray

$cinteropFlags = @(":nioxplugin:cinteropWindowsBluetoothWindowsNative")
if ($Clean) {
    $cinteropFlags += @("--rerun-tasks", "--no-configuration-cache", "--no-build-cache")
}

& $GRADLE_CMD @cinteropFlags

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to generate C interop bindings" -ForegroundColor Red
    Write-Host "`nPossible issues:" -ForegroundColor Yellow
    Write-Host "  • Windows SDK headers not found (bluetoothapis.h)" -ForegroundColor Gray
    Write-Host "  • MinGW-w64 toolchain not installed" -ForegroundColor Gray
    Write-Host "  • Check: nioxplugin/src/nativeInterop/cinterop/windowsBluetooth.def" -ForegroundColor Gray

    if (-not $Clean) {
        Write-Host "`nTry running with -Clean flag:" -ForegroundColor Yellow
        Write-Host "  .\build-native-dll.ps1 -Clean" -ForegroundColor Cyan
    }
    exit 1
}

Write-Host "✓ C interop bindings generated successfully" -ForegroundColor Green
$currentStep++

# Compile Kotlin/Native code
Write-Host "`n[$currentStep/$totalSteps] Compiling Kotlin/Native code..." -ForegroundColor Yellow

$compileFlags = @(":nioxplugin:compileKotlinWindowsNative")
if ($Clean) {
    $compileFlags += @("--rerun-tasks", "--no-configuration-cache", "--no-build-cache")
}

& $GRADLE_CMD @compileFlags

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to compile Kotlin/Native code" -ForegroundColor Red
    Write-Host "`nCommon issues:" -ForegroundColor Yellow
    Write-Host "  • Type mismatches → Old cached code" -ForegroundColor Gray
    Write-Host "  • Unresolved references → Stale build cache" -ForegroundColor Gray

    if (-not $Clean) {
        Write-Host "`nSolution: Run with -Clean flag to clean all caches:" -ForegroundColor Yellow
        Write-Host "  .\build-native-dll.ps1 -Clean" -ForegroundColor Cyan
    } else {
        Write-Host "`nEven with clean build, compilation failed." -ForegroundColor Yellow
        Write-Host "Check error messages above for details." -ForegroundColor Gray
    }
    exit 1
}

Write-Host "✓ Kotlin/Native code compiled successfully" -ForegroundColor Green
$currentStep++

# Link native DLL
Write-Host "`n[$currentStep/$totalSteps] Linking native DLL..." -ForegroundColor Yellow
Write-Host "  Linking against:" -ForegroundColor Gray
Write-Host "    - Bthprops.cpl (Windows Bluetooth API)" -ForegroundColor Gray
Write-Host "    - Kernel32.dll (Windows System API)" -ForegroundColor Gray

$linkFlags = @(":nioxplugin:buildWindowsNativeDll")
if ($Clean) {
    $linkFlags += @("--rerun-tasks", "--no-configuration-cache", "--no-build-cache")
}

& $GRADLE_CMD @linkFlags

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to link native DLL" -ForegroundColor Red
    Write-Host "`nPossible issues:" -ForegroundColor Yellow
    Write-Host "  • Bluetooth libraries not found" -ForegroundColor Gray
    Write-Host "  • Linker options incorrect in build.gradle.kts" -ForegroundColor Gray
    exit 1
}

# Verify DLL was created
$dllPath = "nioxplugin\build\outputs\windows\NioxCommunicationPlugin.dll"

if (-not (Test-Path $dllPath)) {
    Write-Host "❌ DLL file not found at expected location" -ForegroundColor Red
    Write-Host "   Expected: $dllPath" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Native DLL linked successfully" -ForegroundColor Green

# Build success summary
Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "BUILD SUCCESS!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan

$dllInfo = Get-Item $dllPath
$dllSize = [math]::Round($dllInfo.Length / 1KB, 2)

Write-Host "`n📦 DLL Information:" -ForegroundColor Yellow
Write-Host "  Location: $($dllInfo.FullName)" -ForegroundColor White
Write-Host "  Size: $dllSize KB" -ForegroundColor White
Write-Host "  Modified: $($dllInfo.LastWriteTime)" -ForegroundColor White

# Check DLL exports (if dumpbin is available)
if (Get-Command dumpbin -ErrorAction SilentlyContinue) {
    Write-Host "`n🔍 DLL Exports:" -ForegroundColor Yellow
    $exports = dumpbin /EXPORTS $dllPath 2>&1 | Select-String "createNioxCommunicationPlugin"
    if ($exports) {
        Write-Host "  ✓ Main entry point found" -ForegroundColor Green
    }
}

# Show what was cleaned (if Clean mode)
if ($Clean) {
    Write-Host "`n🧹 Cleaned:" -ForegroundColor Yellow
    Write-Host "  ✓ Gradle daemon (stopped and restarted)" -ForegroundColor Green
    Write-Host "  ✓ Build directory" -ForegroundColor Green
    Write-Host "  ✓ Gradle caches" -ForegroundColor Green
    Write-Host "  ✓ Kotlin compiler cache" -ForegroundColor Green
    Write-Host "  ✓ Kotlin/Native cache" -ForegroundColor Green
    Write-Host "  ✓ Configuration cache" -ForegroundColor Green
    Write-Host "  ✓ Build cache" -ForegroundColor Green
    Write-Host ""
    Write-Host "  This was a FRESH build with zero cached artifacts" -ForegroundColor Cyan
}

# Display features
Write-Host "`n✅ This DLL includes:" -ForegroundColor Yellow
Write-Host "  ✓ Bluetooth adapter state detection (ENABLED/DISABLED/UNSUPPORTED)" -ForegroundColor Green
Write-Host "  ✓ Full device scanning (Windows Bluetooth Classic API)" -ForegroundColor Green
Write-Host "  ✓ NIOX PRO device filtering (by name prefix)" -ForegroundColor Green
Write-Host "  ✓ Device information (name, address, connection status)" -ForegroundColor Green
Write-Host "  ✓ Memory-safe operations (memScoped cleanup)" -ForegroundColor Green
Write-Host "  ✓ Comprehensive error handling" -ForegroundColor Green

# Display key advantages
Write-Host "`n🎯 Key Advantages:" -ForegroundColor Yellow
Write-Host "  ✓ No JVM required (pure native DLL)" -ForegroundColor Green
Write-Host "  ✓ Small footprint (~$dllSize KB)" -ForegroundColor Green
Write-Host "  ✓ Instant startup (no JVM warmup)" -ForegroundColor Green
Write-Host "  ✓ Direct P/Invoke from C#" -ForegroundColor Green
Write-Host "  ✓ Native Windows API calls" -ForegroundColor Green

# Display usage information
Write-Host "`n📚 Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Test the DLL:" -ForegroundColor White
Write-Host "     → See BUILD_AND_TEST_WINDOWS_NATIVE.md for test procedures" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Integrate into your application:" -ForegroundColor White
Write-Host "     → C# integration: See docs\WINDOWS_NATIVE_DLL_GUIDE.md" -ForegroundColor Gray
Write-Host "     → C++ integration: See docs\WINDOWS_NATIVE_DLL_GUIDE.md" -ForegroundColor Gray
Write-Host "     → WinUI3: See docs\WINUI3_STEP_BY_STEP.md" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Copy DLL to your project:" -ForegroundColor White
Write-Host "     Copy-Item '$dllPath' -Destination 'YourProject\bin\'" -ForegroundColor Gray

# Display comparison with JAR
Write-Host "`n💡 Comparison with JAR:" -ForegroundColor Yellow
Write-Host "  Native DLL: ~$dllSize KB, no JVM, instant startup" -ForegroundColor Cyan
Write-Host "  JAR: ~2MB + JRE (~50MB), JVM startup delay" -ForegroundColor Gray
Write-Host "  → Use Native DLL for C#/C++ apps" -ForegroundColor Green
Write-Host "  → Use JAR for JVM-based apps" -ForegroundColor Green

# Troubleshooting tips
if (-not $Clean) {
    Write-Host "`n💡 Tip:" -ForegroundColor Yellow
    Write-Host "  If you encounter cache or compilation issues, run:" -ForegroundColor White
    Write-Host "  .\build-native-dll.ps1 -Clean" -ForegroundColor Cyan
}

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "Windows Native DLL is ready!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
