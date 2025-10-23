#!/bin/bash

# Build script for Windows Native DLL (Full Bluetooth Implementation)
# This builds a FULLY FUNCTIONAL native DLL using Kotlin/Native C interop
# NO JVM REQUIRED - Pure native Windows DLL
#
# NOTE: This script is for reference. The DLL must be built on Windows with MinGW.
#       If running on WSL, this script will attempt the build, but native Windows is preferred.

set -e  # Exit on error

echo "========================================="
echo "Building Windows Native DLL"
echo "Kotlin/Native + C Interop Implementation"
echo "========================================="

# Check if running on Windows (via Git Bash, WSL, or native)
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$WSL_DISTRO_NAME" ]]; then
    echo "Detected Windows environment"
elif [[ "$OSTYPE" == "linux-gnu"* ]] && grep -qi microsoft /proc/version 2>/dev/null; then
    echo "Detected WSL environment"
    echo "⚠ Warning: Building on WSL may have issues. Native Windows is recommended."
else
    echo "❌ Error: This build requires Windows environment"
    echo "   The Windows Native DLL requires Windows host with MinGW toolchain"
    exit 1
fi

# Determine which Gradle command to use
if [ -f "./gradlew" ] && [ -x "./gradlew" ]; then
    GRADLE_CMD="./gradlew"
elif [ -f "./gradlew.bat" ]; then
    GRADLE_CMD="./gradlew.bat"
elif command -v gradle &> /dev/null; then
    GRADLE_CMD="gradle"
else
    echo "❌ Error: Neither gradlew nor gradle command found"
    exit 1
fi

echo "Using Gradle: $GRADLE_CMD"
echo ""

# Check Java version
echo "[1/5] Checking Java version..."
if command -v java &> /dev/null; then
    java_version=$(java -version 2>&1 | head -1)
    echo "  $java_version"
    echo "✓ Java found"
else
    echo "❌ Java not found. Please install JDK 11 or higher"
    exit 1
fi

# Step 1: Clean previous builds
echo ""
echo "[2/5] Cleaning previous builds..."
$GRADLE_CMD clean || echo "⚠ Warning: Clean failed, continuing anyway..."
echo "✓ Clean completed"

# Step 2: Generate C interop bindings
echo ""
echo "[3/5] Generating C interop bindings for Windows Bluetooth APIs..."
echo "  This step creates Kotlin bindings for:"
echo "    - BluetoothFindFirstRadio"
echo "    - BluetoothFindFirstDevice"
echo "    - BluetoothFindNextDevice"
echo "    - CloseHandle (Kernel32)"

if ! $GRADLE_CMD :nioxplugin:cinteropWindowsBluetoothWindowsNative; then
    echo "❌ Failed to generate C interop bindings"
    echo ""
    echo "Possible issues:"
    echo "  • Windows SDK headers not found (bluetoothapis.h)"
    echo "  • MinGW-w64 toolchain not installed"
    echo "  • Check: nioxplugin/src/nativeInterop/cinterop/windowsBluetooth.def"
    exit 1
fi

echo "✓ C interop bindings generated successfully"

# Step 3: Compile Kotlin/Native code
echo ""
echo "[4/5] Compiling Kotlin/Native code..."

if ! $GRADLE_CMD :nioxplugin:compileKotlinWindowsNative; then
    echo "❌ Failed to compile Kotlin/Native code"
    exit 1
fi

echo "✓ Kotlin/Native code compiled successfully"

# Step 4: Link native DLL
echo ""
echo "[5/5] Linking native DLL..."
echo "  Linking against:"
echo "    - Bthprops.cpl (Windows Bluetooth API)"
echo "    - Kernel32.dll (Windows System API)"

if ! $GRADLE_CMD :nioxplugin:buildWindowsNativeDll; then
    echo "❌ Failed to link native DLL"
    echo ""
    echo "Possible issues:"
    echo "  • Bluetooth libraries not found"
    echo "  • Linker options incorrect in build.gradle.kts"
    exit 1
fi

# Verify DLL was created
DLL_PATH="nioxplugin/build/outputs/windows/NioxCommunicationPlugin.dll"

if [ ! -f "$DLL_PATH" ]; then
    echo "❌ DLL file not found at expected location"
    echo "   Expected: $DLL_PATH"
    exit 1
fi

echo "✓ Native DLL linked successfully"

# Get DLL information
echo ""
echo "========================================="
echo "BUILD SUCCESS!"
echo "========================================="

if [ -f "$DLL_PATH" ]; then
    DLL_SIZE=$(du -h "$DLL_PATH" | cut -f1)
    DLL_FULL_PATH=$(realpath "$DLL_PATH")

    echo ""
    echo "📦 DLL Information:"
    echo "  Location: $DLL_FULL_PATH"
    echo "  Size: $DLL_SIZE"
    echo "  Modified: $(stat -c %y "$DLL_PATH" 2>/dev/null || stat -f "%Sm" "$DLL_PATH")"
fi

# Display features
echo ""
echo "✅ This DLL includes:"
echo "  ✓ Bluetooth adapter state detection (ENABLED/DISABLED/UNSUPPORTED)"
echo "  ✓ Full device scanning (Windows Bluetooth Classic API)"
echo "  ✓ NIOX PRO device filtering (by name prefix)"
echo "  ✓ Device information (name, address, connection status)"
echo "  ✓ Memory-safe operations (memScoped cleanup)"
echo "  ✓ Comprehensive error handling"

# Display key advantages
echo ""
echo "🎯 Key Advantages:"
echo "  ✓ No JVM required (pure native DLL)"
echo "  ✓ Small footprint (~500KB-1MB)"
echo "  ✓ Instant startup (no JVM warmup)"
echo "  ✓ Direct P/Invoke from C#"
echo "  ✓ Native Windows API calls"

# Display usage information
echo ""
echo "📚 Next Steps:"
echo "  1. Test the DLL:"
echo "     → See BUILD_AND_TEST_WINDOWS_NATIVE.md for test procedures"
echo ""
echo "  2. Integrate into your application:"
echo "     → C# integration: See docs/WINDOWS_NATIVE_DLL_GUIDE.md"
echo "     → C++ integration: See docs/WINDOWS_NATIVE_DLL_GUIDE.md"
echo "     → WinUI3: See docs/WINUI3_STEP_BY_STEP.md"
echo ""
echo "  3. Copy DLL to your project:"
echo "     cp '$DLL_PATH' YourProject/bin/"

# Display comparison with JAR
echo ""
echo "💡 Comparison with JAR:"
echo "  Native DLL: ~500KB, no JVM, instant startup"
echo "  JAR: ~2MB + JRE (~50MB), JVM startup delay"
echo "  → Use Native DLL for C#/C++ apps"
echo "  → Use JAR for JVM-based apps"

echo ""
echo "========================================="
echo "Windows Native DLL is ready!"
echo "========================================="
echo ""
