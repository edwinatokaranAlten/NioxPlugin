# Build script for Windows Native DLL (Full Bluetooth Implementation)
# This builds a FULLY FUNCTIONAL native DLL using Kotlin/Native C interop
# NO JVM REQUIRED - Pure native Windows DLL

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Building Windows Native DLL" -ForegroundColor Cyan
Write-Host "Kotlin/Native + C Interop Implementation" -ForegroundColor Cyan
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

# Check Java version
Write-Host "[1/5] Checking Java version..." -ForegroundColor Yellow
$javaVersion = java -version 2>&1 | Select-Object -First 1
Write-Host "  $javaVersion" -ForegroundColor Gray

if (-not $javaVersion) {
    Write-Host "❌ Java not found. Please install JDK 11 or higher" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Java found" -ForegroundColor Green

# Step 1: Clean previous builds
Write-Host "`n[2/5] Cleaning previous builds..." -ForegroundColor Yellow
& $GRADLE_CMD clean

if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠ Warning: Clean failed, continuing anyway..." -ForegroundColor Yellow
}

Write-Host "✓ Clean completed" -ForegroundColor Green

# Step 2: Generate C interop bindings
Write-Host "`n[3/5] Generating C interop bindings for Windows Bluetooth APIs..." -ForegroundColor Yellow
Write-Host "  This step creates Kotlin bindings for:" -ForegroundColor Gray
Write-Host "    - BluetoothFindFirstRadio" -ForegroundColor Gray
Write-Host "    - BluetoothFindFirstDevice" -ForegroundColor Gray
Write-Host "    - BluetoothFindNextDevice" -ForegroundColor Gray
Write-Host "    - CloseHandle (Kernel32)" -ForegroundColor Gray

& $GRADLE_CMD :nioxplugin:cinteropWindowsBluetoothWindowsNative

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to generate C interop bindings" -ForegroundColor Red
    Write-Host "`nPossible issues:" -ForegroundColor Yellow
    Write-Host "  • Windows SDK headers not found (bluetoothapis.h)" -ForegroundColor Gray
    Write-Host "  • MinGW-w64 toolchain not installed" -ForegroundColor Gray
    Write-Host "  • Check: nioxplugin/src/nativeInterop/cinterop/windowsBluetooth.def" -ForegroundColor Gray
    exit 1
}

Write-Host "✓ C interop bindings generated successfully" -ForegroundColor Green

# Step 3: Compile Kotlin/Native code
Write-Host "`n[4/5] Compiling Kotlin/Native code..." -ForegroundColor Yellow
& $GRADLE_CMD :nioxplugin:compileKotlinWindowsNative

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to compile Kotlin/Native code" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Kotlin/Native code compiled successfully" -ForegroundColor Green

# Step 4: Link native DLL
Write-Host "`n[5/5] Linking native DLL..." -ForegroundColor Yellow
Write-Host "  Linking against:" -ForegroundColor Gray
Write-Host "    - Bthprops.cpl (Windows Bluetooth API)" -ForegroundColor Gray
Write-Host "    - Kernel32.dll (Windows System API)" -ForegroundColor Gray

& $GRADLE_CMD :nioxplugin:buildWindowsNativeDll

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

# Get DLL information
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
    dumpbin /EXPORTS $dllPath | Select-String "createNioxCommunicationPlugin" | ForEach-Object {
        Write-Host "  ✓ $_" -ForegroundColor Green
    }
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

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "Windows Native DLL is ready!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
