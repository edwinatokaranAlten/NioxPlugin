#!/bin/bash

# Build script for Niox Communication Plugin
# Generates AAR, XCFramework, and Windows JAR

echo "========================================="
echo "Building Niox Communication Plugin"
echo "========================================="

# Clean previous builds
echo "Cleaning previous builds..."
./gradlew clean

# Build Android AAR
echo ""
echo "Building Android AAR..."
./gradlew :nioxplugin:assembleRelease

if [ $? -eq 0 ]; then
    echo "✓ Android AAR built successfully"
    echo "  Location: nioxplugin/build/outputs/aar/nioxplugin-release.aar"
else
    echo "✗ Android AAR build failed"
fi

# Build iOS XCFramework (only on macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo ""
    echo "Building iOS XCFramework..."
    ./gradlew :nioxplugin:assembleNioxCommunicationPluginXCFramework

    if [ $? -eq 0 ]; then
        echo "✓ iOS XCFramework built successfully"
        echo "  Location: nioxplugin/build/XCFrameworks/release/NioxCommunicationPlugin.xcframework"
    else
        echo "✗ iOS XCFramework build failed"
    fi
else
    echo ""
    echo "⚠ Skipping iOS XCFramework build (macOS required)"
fi

# Build Windows JAR
echo ""
echo "Building Windows JAR..."
./gradlew :nioxplugin:buildWindowsDll

if [ $? -eq 0 ]; then
    echo "✓ Windows JAR built successfully"
    echo "  Location: nioxplugin/build/outputs/windows/niox-communication-plugin-windows.jar"
else
    echo "✗ Windows JAR build failed"
fi

echo ""
echo "========================================="
echo "Build Complete!"
echo "========================================="
