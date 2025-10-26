#!/bin/bash

# Build script for Android AAR
# Generates: nioxplugin-release.aar

echo "========================================="
echo "Building Android AAR"
echo "========================================="

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

# Build Android AAR
echo "[1/2] Cleaning previous builds..."
$GRADLE_CMD clean

echo ""
echo "[2/2] Building Android AAR..."
$GRADLE_CMD :nioxplugin:assembleRelease

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================="
    echo "✅ BUILD SUCCESS"
    echo "========================================="
    echo ""

    AAR_PATH="nioxplugin/build/outputs/aar/nioxplugin-release.aar"

    if [ -f "$AAR_PATH" ]; then
        AAR_SIZE=$(du -h "$AAR_PATH" | cut -f1)
        echo "📦 Android AAR Information:"
        echo "  Location: $AAR_PATH"
        echo "  Size: $AAR_SIZE"
        echo ""
        echo "Next steps:"
        echo "  1. Copy AAR to your Android project: libs/"
        echo "  2. Add to build.gradle: implementation(files('libs/nioxplugin-release.aar'))"
        echo ""
    else
        echo "⚠️  AAR file not found at expected location"
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
