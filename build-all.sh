#!/bin/bash

# Build ALL mobile platforms (Android + iOS)
# Calls individual build scripts for each platform
# Requirements: macOS for iOS builds

echo "========================================="
echo "Building ALL Mobile Platforms"
echo "========================================="
echo ""

# Track success/failure
androidSuccess=false
iosSuccess=false

# Build Android AAR
echo "========================================="
echo "[1/2] Building Android AAR"
echo "========================================="
echo ""

if [ -f "./build-android.sh" ] && [ -x "./build-android.sh" ]; then
    ./build-android.sh
    if [ $? -eq 0 ]; then
        androidSuccess=true
    fi
else
    echo "❌ Error: build-android.sh not found or not executable"
fi

echo ""

# Build iOS XCFramework (only on macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "========================================="
    echo "[2/2] Building iOS XCFramework"
    echo "========================================="
    echo ""

    if [ -f "./build-ios.sh" ] && [ -x "./build-ios.sh" ]; then
        ./build-ios.sh
        if [ $? -eq 0 ]; then
            iosSuccess=true
        fi
    else
        echo "❌ Error: build-ios.sh not found or not executable"
    fi
else
    echo "========================================="
    echo "[2/2] iOS Build - SKIPPED"
    echo "========================================="
    echo ""
    echo "⚠️  iOS XCFramework build requires macOS with Xcode"
    echo "   Current platform: $OSTYPE"
    echo ""
fi

# Build Summary
echo ""
echo "========================================="
echo "BUILD SUMMARY"
echo "========================================="
echo ""

if $androidSuccess; then
    echo "✅ Android AAR: SUCCESS"
    echo "   Location: nioxplugin/build/outputs/aar/nioxplugin-release.aar"
else
    echo "❌ Android AAR: FAILED"
fi

echo ""

if [[ "$OSTYPE" == "darwin"* ]]; then
    if $iosSuccess; then
        echo "✅ iOS XCFramework: SUCCESS"
        echo "   Location: nioxplugin/build/XCFrameworks/release/NioxCommunicationPlugin.xcframework"
    else
        echo "❌ iOS XCFramework: FAILED"
    fi
else
    echo "⊘  iOS XCFramework: SKIPPED (macOS required)"
fi

echo ""
echo "========================================="

# Exit status
if $androidSuccess && ($iosSuccess || [[ "$OSTYPE" != "darwin"* ]]); then
    echo "ALL BUILDS SUCCESSFUL! 🎉"
    echo "========================================="
    exit 0
elif $androidSuccess || $iosSuccess; then
    echo "PARTIAL SUCCESS"
    echo "========================================="
    exit 0
else
    echo "ALL BUILDS FAILED"
    echo "========================================="
    exit 1
fi
