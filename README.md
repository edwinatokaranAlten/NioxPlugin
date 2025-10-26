# Niox Communication Plugin

A Kotlin Multiplatform library for Bluetooth communication with **NIOX PRO devices** across Android, iOS, and Windows platforms.

## Overview

The Niox Communication Plugin provides a unified API for:
- Checking Bluetooth adapter state
- Scanning for NIOX PRO Bluetooth devices (by default)
- Identifying NIOX devices by service UUID and device name
- Extracting device serial numbers
- **Full BLE support with RSSI values** on all platforms

**Bundle ID**: `com.niox.nioxplugin`

**Default Behavior**: Scans only for NIOX PRO devices using the FDC service UUID (`000fc00b-8a4-4078-874c-14efbd4b510a`). To scan all devices, set `serviceUuidFilter = null`.

## Supported Platforms

- **Android** - Generates AAR file with full BLE support
- **iOS** - Generates XCFramework with full BLE support
- **Windows** - Generates WinRT JAR/DLL with full BLE support

## Prerequisites

- JDK 11 or higher
- Gradle 8.5+
- For iOS builds: Xcode 14.0+ (macOS only)
- For Android builds: Android SDK with API level 34
- For Windows native builds: Visual Studio 2019/2022 with C++/WinRT

## Project Structure

```
niox-communication-plugin/
├── nioxplugin/
│   ├── src/
│   │   ├── commonMain/kotlin/            # Shared code
│   │   ├── androidMain/kotlin/           # Android BLE implementation
│   │   ├── iosMain/kotlin/               # iOS CoreBluetooth implementation
│   │   ├── windowsWinRtMain/kotlin/      # Windows WinRT JAR implementation
│   │   └── windowsWinRtNativeMain/kotlin # Windows WinRT DLL implementation
│   └── build.gradle.kts
├── build.gradle.kts
├── settings.gradle.kts
└── README.md
```

## Building the Library

Each platform has a dedicated build script for easy, streamlined builds.

### Individual Platform Builds

**Android AAR:**
```bash
./build-android.sh
```
Output: `nioxplugin/build/outputs/aar/nioxplugin-release.aar`

**iOS XCFramework** (macOS only):
```bash
./build-ios.sh
```
Output: `nioxplugin/build/XCFrameworks/release/NioxCommunicationPlugin.xcframework`

**Windows WinRT JAR** (For Kotlin/Java - Full BLE support with RSSI):
```powershell
.\build-windows-winrt-jar.ps1
```
Output: `nioxplugin/build/outputs/windows/niox-communication-plugin-windows-winrt-1.0.0.jar`

**Windows WinRT DLL** (For C#/C++ - Full BLE support with RSSI):
```powershell
.\build-winrt-native-dll.ps1           # Normal build
.\build-winrt-native-dll.ps1 -Clean    # Clean build (cache issues)
```
Output: `nioxplugin/build/outputs/windows/NioxCommunicationPluginWinRT.dll`
**Note:** Must build on Windows with Visual Studio 2019/2022 and C++/WinRT

### Build Multiple Platforms

**All mobile platforms:**
```bash
./build-all.sh    # Builds Android + iOS (macOS only for iOS)
```

### Platform Notes

**Windows:**
- **WinRT Native DLL**: Full BLE support via C++/WinRT. No JVM required. **Best for native desktop apps** (C#, C++, WinUI3)
- **WinRT JAR**: Full BLE support via JVM + WinRT APIs. Requires JRE 11+. **Best for JVM applications**
- Both implementations provide **full BLE features including RSSI values, advertisements, and service UUIDs**
- DLL can be used via P/Invoke from C#, C++, Electron
- JAR can be used from Java/Kotlin applications
- Uses modern Windows.Devices.Bluetooth APIs (Windows 10 build 1809+ / Windows 11)

**Troubleshooting:**
- Cache issues with Native DLL: `.\build-winrt-native-dll.ps1 -Clean`
- See [BUILD_SCRIPTS_REFERENCE.md](BUILD_SCRIPTS_REFERENCE.md) for all build options

## Usage

### Common API

All platforms share the same API defined in `NioxCommunicationPlugin` interface:

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

### Android Usage

```kotlin
import com.niox.nioxplugin.*

// Create plugin instance (requires Android Context)
val plugin = createNioxCommunicationPlugin(context)

// Check Bluetooth state
val state = plugin.checkBluetoothState()
when (state) {
    BluetoothState.ENABLED -> println("Bluetooth is enabled")
    BluetoothState.DISABLED -> println("Bluetooth is disabled")
    BluetoothState.UNSUPPORTED -> println("Bluetooth not supported")
    BluetoothState.UNKNOWN -> println("Bluetooth state unknown")
}

// Scan for NIOX devices and get all results as a list
val devices = plugin.scanForDevices()  // Default: scans for NIOX devices only

// Process the results
devices.forEach { device ->
    println("Found NIOX device: ${device.name} - ${device.address}")
    println("Serial number: ${device.getNioxSerialNumber()}")
    println("RSSI: ${device.rssi} dBm")
}

// To scan ALL Bluetooth devices, set serviceUuidFilter to null
val allDevices = plugin.scanForDevices(
    scanDurationMs = 10000,
    serviceUuidFilter = null  // Scan all devices
)

// Filter NIOX devices from all results
val nioxDevices = allDevices.filter { it.isNioxDevice() }
println("Found ${nioxDevices.size} NIOX devices out of ${allDevices.size} total")
```

**Required Permissions** (add to your app's AndroidManifest.xml):

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

### iOS Usage

```swift
import NioxCommunicationPlugin

// Create plugin instance
let plugin = createNioxCommunicationPlugin()

// Check Bluetooth state
Task {
    let state = await plugin.checkBluetoothState()
    switch state {
    case .enabled:
        print("Bluetooth is enabled")
    case .disabled:
        print("Bluetooth is disabled")
    case .unsupported:
        print("Bluetooth not supported")
    case .unknown:
        print("Bluetooth state unknown")
    }
}

// Scan for devices
Task {
    let devices = await plugin.scanForDevices(
        scanDurationMs: 10000,
        serviceUuidFilter: NioxConstants.shared.NIOX_SERVICE_UUID
    )
    devices.forEach { device in
        print("Found device: \(device.name ?? \"Unknown\") - \(device.address)")
        print("RSSI: \(device.rssi ?? 0) dBm")
    }
}
```

**Required Permissions** (add to your app's Info.plist):

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth access to scan for devices</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth access to communicate with devices</string>
```

### Windows Usage

**Kotlin/Java (using WinRT JAR):**

```kotlin
import com.niox.nioxplugin.*

// Create plugin instance
val plugin = createNioxCommunicationPlugin()

// Check Bluetooth state
val state = plugin.checkBluetoothState()

// Scan for devices (returns list with RSSI values)
val devices = plugin.scanForDevices(scanDurationMs = 10000)
devices.forEach { device ->
    println("Found device: ${device.name} - ${device.address}")
    println("  RSSI: ${device.rssi} dBm")  // RSSI available via WinRT BLE API
}
```

**Note:** Windows implementations:
- **WinRT JAR** (For Kotlin/Java) - Full BLE support with RSSI values, advertisements, and service UUIDs
- **WinRT Native DLL** (For C#/C++) - Full BLE support with RSSI values via C++/WinRT
- Both use modern Windows.Devices.Bluetooth APIs (Windows 10/11)

## API Reference

### BluetoothState

```kotlin
enum class BluetoothState {
    ENABLED,      // Bluetooth is enabled
    DISABLED,     // Bluetooth is disabled
    UNSUPPORTED,  // Bluetooth not supported
    UNKNOWN       // State unknown
}
```

### BluetoothDevice

```kotlin
data class BluetoothDevice(
    val name: String?,        // Device name (may be null)
    val address: String,      // MAC address or unique ID
    val rssi: Int? = null     // Signal strength in dBm
)
```

## Platform-Specific Notes

### Android
- Uses Android Bluetooth LE API
- Requires runtime permissions for Android 12+ (BLUETOOTH_SCAN, BLUETOOTH_CONNECT)
- Requires location permissions for Android < 12
- Minimum SDK: API 21 (Android 5.0)
- ✅ Full BLE support with RSSI

### iOS
- Uses CoreBluetooth framework
- Requires Bluetooth usage descriptions in Info.plist
- Works on iOS 13.0+
- ✅ Full BLE support with RSSI

### Windows
- **Two WinRT-based implementations with full BLE support:**
  - **WinRT Native DLL**: Full BLE scanning using Kotlin/Native + C++/WinRT. **No JVM required!** Recommended for native desktop apps (C#, C++, WinUI3)
  - **WinRT JAR**: Full BLE scanning using JVM + WinRT APIs. Requires JRE 11+. Recommended for JVM-based applications
- ✅ **Full BLE support with RSSI values** (via Windows.Devices.Bluetooth APIs)
- ✅ Service UUID filtering and advertisement data
- ✅ Supports checking Bluetooth adapter state (enabled/disabled/unsupported)
- ✅ Modern Windows 10/11 BLE API
- Works on Windows 10 (build 1809+) and Windows 11
- Both implementations can be integrated into C# MAUI/WinUI3 applications
- Native DLL provides smaller footprint, instant startup, and direct P/Invoke integration

## License

Copyright (c) 2024 Niox. All rights reserved.

## Support

For issues and questions, please contact the Niox development team.
