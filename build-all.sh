#!/bin/bash

# Build script for Niox Communication Plugin (macOS)
# Generates Android AAR and iOS XCFramework

echo "========================================="
echo "Building Niox Communication Plugin (macOS)"
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
    echo "⚠ Warning: This script is intended for macOS to build iOS XCFramework"
    echo "⚠ iOS XCFramework build skipped (macOS required)"
fi

echo ""
echo "========================================="
echo "Build Complete!"
echo "========================================="
