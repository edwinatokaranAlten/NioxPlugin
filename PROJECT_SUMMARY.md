# Niox Communication Plugin - Project Summary

## Project Details

**Project Name**: Niox Communication Plugin
**Bundle ID**: `com.niox.nioxplugin`
**Version**: 1.0.0
**Type**: Kotlin Multiplatform Library (KMP)

## What This Project Does

This is a **cross-platform Bluetooth library** that provides:
1. **Bluetooth State Check** - Check if Bluetooth is enabled/disabled/unsupported
2. **Bluetooth Device Scanning** - Scan for nearby Bluetooth devices

The library works on:
- **Android** (generates `.aar` file)
- **iOS** (generates `.xcframework` file)
- **Windows** (generates `.dll` file)

## Project Structure

```
NIOXSDKPlugin/
├── build.gradle.kts              # Root build configuration
├── settings.gradle.kts           # Project settings
├── gradle.properties             # Gradle properties
├── gradlew                       # Gradle wrapper (Unix)
├── gradlew.bat                   # Gradle wrapper (Windows)
├── build-all.sh                  # Build script for all platforms
├── README.md                     # Main documentation
├── QUICKSTART.md                 # Quick start guide
├── USAGE_EXAMPLES.md             # Platform-specific usage examples
├── PROJECT_SUMMARY.md            # This file
│
└── nioxplugin/                   # Main library module
    ├── build.gradle.kts          # Module build configuration
    └── src/
        ├── commonMain/kotlin/com/niox/nioxplugin/
        │   ├── NioxCommunicationPlugin.kt    # Main API interface
        │   ├── BluetoothState.kt             # Bluetooth state enum
        │   └── BluetoothDevice.kt            # Device data class
        │
        ├── androidMain/
        │   ├── AndroidManifest.xml           # Android permissions
        │   └── kotlin/com/niox/nioxplugin/
        │       └── NioxCommunicationPlugin.android.kt  # Android implementation
        │
        ├── iosMain/kotlin/com/niox/nioxplugin/
        │   └── NioxCommunicationPlugin.ios.kt         # iOS implementation
        │
        └── windowsNativeMain/kotlin/com/niox/nioxplugin/
            └── NioxCommunicationPlugin.windowsNative.kt  # Windows native implementation
```

## Key Features

### 1. Common API (All Platforms)

```kotlin
interface NioxCommunicationPlugin {
    suspend fun checkBluetoothState(): BluetoothState
    suspend fun scanForDevices(
        scanDurationMs: Long = 10000,
        serviceUuidFilter: String? = NioxConstants.NIOX_SERVICE_UUID
    ): List<BluetoothDevice>
    fun stopScan()
}
```

### 2. Platform Implementations

- **Android**: Uses Android Bluetooth LE API with proper permission handling
- **iOS**: Uses CoreBluetooth framework with CBCentralManager
- **Windows**: Uses Kotlin/Native mingwX64 to generate native DLL

### 3. No UI Components

This is a **pure library** with no user interface - just APIs for Bluetooth operations.

## Build Outputs

After building, you'll get these files:

| Platform | File Type | Location |
|----------|-----------|----------|
| Android | `.aar` | `nioxplugin/build/outputs/aar/nioxplugin-release.aar` |
| iOS | `.xcframework` | `nioxplugin/build/XCFrameworks/release/NioxCommunicationPlugin.xcframework` |
| Windows | `.dll` | `nioxplugin/build/outputs/windows/NioxCommunicationPlugin.dll` |

## How to Build

### Quick Build (All Platforms)
```bash
./build-all.sh
```

### Individual Platforms
```bash
# Android
./gradlew :nioxplugin:assembleRelease

# iOS (macOS only)
./gradlew :nioxplugin:assembleNioxCommunicationPluginXCFramework

# Windows DLL (Windows host only)
./gradlew :nioxplugin:buildWindowsNativeDll
```

## How to Use

### Android Example
```kotlin
val plugin = createNioxCommunicationPlugin(context)
val state = plugin.checkBluetoothState()

val devices = plugin.scanForDevices()
devices.forEach { device ->
    println("Found: ${device.name}")
}
```

### iOS Example (Swift)
```swift
let plugin = NioxCommunicationPluginKt.createNioxCommunicationPlugin()
let state = await plugin.checkBluetoothState()

let devices = await plugin.scanForDevices()
devices.forEach { device in
    print("Found: \(device.name ?? "Unknown")")
}
```

### Windows Example (Native)
```kotlin
// Load the native DLL and use the plugin
val plugin = createNioxCommunicationPlugin()
val state = plugin.checkBluetoothState()

val devices = plugin.scanForDevices()
devices.forEach { device ->
    println("Found: ${device.name}")
}
```

## Technical Details

### Dependencies
- **Kotlin**: 1.9.22
- **Gradle**: 8.5
- **Android**: Min SDK 21, Target SDK 34
- **iOS**: iOS 13.0+
- **Windows**: Kotlin/Native mingwX64 toolchain
- **Coroutines**: 1.7.3

### Android Permissions Required
```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

### iOS Permissions Required (Info.plist)
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>We need Bluetooth to scan for devices</string>
```

## Next Steps

1. **Build the library**: Run `./build-all.sh`
2. **Integrate into your app**: Copy the appropriate file (AAR/XCFramework/JAR) to your project
3. **Check permissions**: Add required permissions for your platform
4. **Use the API**: Follow examples in `USAGE_EXAMPLES.md`

## Documentation Files

- **[README.md](README.md)** - Complete documentation with API reference
- **[QUICKSTART.md](QUICKSTART.md)** - Quick start guide to get up and running
- **[USAGE_EXAMPLES.md](USAGE_EXAMPLES.md)** - Detailed platform-specific code examples
- **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)** - This file

## Requirements Met ✓

- ✓ Project name: "Niox Communication Plugin"
- ✓ Bundle ID: `com.niox.nioxplugin`
- ✓ No UI/UX components
- ✓ Bluetooth state check for Android, iOS, Windows
- ✓ Bluetooth device scanning for all platforms
- ✓ Generates AAR file for Android
- ✓ Generates XCFramework for iOS
- ✓ Generates native DLL for Windows

## Notes

- The Windows implementation uses Kotlin/Native mingwX64 to generate a native DLL. Must be built on a Windows machine.
- All implementations use coroutines for asynchronous operations.
- The library handles permission checks internally but apps must request permissions at runtime.
- iOS XCFramework includes support for device (arm64).

---

**Ready to build!** Just run `./build-all.sh` to generate all platform libraries.
