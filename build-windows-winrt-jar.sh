#!/bin/bash
# Build script for Windows WinRT JAR (with full BLE support)

echo "========================================"
echo "Building NIOX Plugin - Windows WinRT JAR"
echo "========================================"
echo ""

echo "Platform: Cross-platform build"
echo "Build Type: WinRT JAR (Bluetooth LE)"
echo ""

# Determine Gradle command
if [ -f "./gradlew" ]; then
    GRADLE_CMD="./gradlew"
else
    GRADLE_CMD="gradle"
fi

echo "Using Gradle: $GRADLE_CMD"
echo ""

# Build the WinRT JAR
echo "Building Windows WinRT JAR..."
$GRADLE_CMD buildWindowsWinRtJar

if [ $? -ne 0 ]; then
    echo ""
    echo "Build failed!"
    exit 1
fi

echo ""
echo "========================================"
echo "Build Successful!"
echo "========================================"
echo ""

# Check if JAR was created
JAR_PATH="nioxplugin/build/outputs/windows/niox-communication-plugin-windows-winrt-1.0.0.jar"
if [ -f "$JAR_PATH" ]; then
    JAR_SIZE=$(ls -lh "$JAR_PATH" | awk '{print $5}')
    echo "Output JAR: $JAR_PATH"
    echo "Size: $JAR_SIZE"
    echo ""
    echo "Features:"
    echo "  - Full Bluetooth LE (BLE) support"
    echo "  - RSSI values available"
    echo "  - Service UUID filtering"
    echo "  - Uses Windows.Devices.Bluetooth APIs"
    echo "  - Compatible with Windows 10/11"
else
    echo "Warning: Output JAR not found at $JAR_PATH"
fi

echo ""
echo "Usage:"
echo "  Add the JAR to your project's classpath"
echo "  Import: import com.niox.nioxplugin.*"
echo "  Create: val plugin = createNioxCommunicationPlugin()"
echo ""
