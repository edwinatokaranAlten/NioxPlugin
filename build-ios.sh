#!/bin/bash

# Build script for iOS XCFramework
# Generates: NioxCommunicationPlugin.xcframework
# Requirements: macOS with Xcode 14.0+

echo "========================================="
echo "Building iOS XCFramework"
echo "========================================="

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ Error: This script must be run on macOS"
    echo "   iOS XCFramework requires Xcode (macOS only)"
    exit 1
fi

# Use system Gradle if wrapper is not available
if [ -f "./gradlew" ] && [ -x "./gradlew" ]; then
    GRADLE_CMD="./gradlew"
elif command -v gradle &> /dev/null; then
    GRADLE_CMD="gradle"
else
    echo "❌ Error: Neither gradlew nor gradle command found"
    exit 1
fi

echo "Using Gradle: $GRADLE_CMD"
echo ""

# Build iOS XCFramework
echo "[1/2] Cleaning previous builds..."
$GRADLE_CMD clean

echo ""
echo "[2/2] Building iOS XCFramework..."
$GRADLE_CMD :nioxplugin:assembleNioxCommunicationPluginXCFramework

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================="
    echo "✅ BUILD SUCCESS"
    echo "========================================="
    echo ""

    XCF_PATH="nioxplugin/build/XCFrameworks/release/NioxCommunicationPlugin.xcframework"

    if [ -d "$XCF_PATH" ]; then
        XCF_SIZE=$(du -sh "$XCF_PATH" | cut -f1)
        echo "📦 iOS XCFramework Information:"
        echo "  Location: $XCF_PATH"
        echo "  Size: $XCF_SIZE"
        echo ""
        echo "Next steps:"
        echo "  1. Drag XCFramework into your Xcode project"
        echo "  2. Add to 'Frameworks, Libraries, and Embedded Content'"
        echo "  3. Import in Swift: import NioxCommunicationPlugin"
        echo ""
    else
        echo "⚠️  XCFramework not found at expected location"
        exit 1
    fi

    exit 0
else
    echo ""
    echo "========================================="
    echo "❌ BUILD FAILED"
    echo "========================================="
    exit 1
fi
