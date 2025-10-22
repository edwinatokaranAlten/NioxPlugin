# Niox Communication Plugin

A Kotlin Multiplatform library for Bluetooth communication with **NIOX PRO devices** across Android, iOS, and Windows platforms.

## Overview

The Niox Communication Plugin provides a unified API for:
- Checking Bluetooth adapter state
- Scanning for NIOX PRO Bluetooth devices (by default)
- Identifying NIOX devices by service UUID and device name
- Extracting device serial numbers

**Bundle ID**: `com.niox.nioxplugin`

**Default Behavior**: Scans only for NIOX PRO devices using the FDC service UUID (`000fc00b-8a4-4078-874c-14efbd4b510a`). To scan all devices, set `serviceUuidFilter = null`.

## Supported Platforms

- **Android** - Generates AAR file
- **iOS** - Generates XCFramework
- **Windows** - Generates JAR/DLL file

## Prerequisites

- JDK 11 or higher
- Gradle 8.5+
- For iOS builds: Xcode 14.0+ (macOS only)
- For Android builds: Android SDK with API level 34

## Project Structure

```
niox-communication-plugin/
├── nioxplugin/
│   ├── src/
│   │   ├── commonMain/kotlin/     # Shared code
│   │   ├── androidMain/kotlin/    # Android implementation
│   │   ├── iosMain/kotlin/        # iOS implementation
│   │   └── windowsMain/kotlin/    # Windows implementation
│   └── build.gradle.kts
├── build.gradle.kts
├── settings.gradle.kts
└── README.md
```

## Building the Library

### Build All Platforms

```bash
./gradlew build
```

### Build Android AAR

```bash
./gradlew :nioxplugin:assembleRelease
```

Output: `nioxplugin/build/outputs/aar/nioxplugin-release.aar`

### Build iOS XCFramework

```bash
./gradlew :nioxplugin:assembleNioxCommunicationPluginXCFramework
```

Output: `nioxplugin/build/XCFrameworks/release/NioxCommunicationPlugin.xcframework`

### Build Windows Libraries

**JAR (JVM-based implementation - RECOMMENDED):**
```bash
./gradlew :nioxplugin:buildWindowsJar
```
Output: `nioxplugin/build/outputs/windows/niox-communication-plugin-windows-1.0.0.jar`

**DLL (Native stub - limited functionality):**
```bash
./gradlew :nioxplugin:buildWindowsNativeDll
```
Output: `nioxplugin/build/outputs/windows/NioxCommunicationPlugin.dll`

**Notes:**
- **JAR**: Full implementation using JVM + JNA with functional Bluetooth scanning via Windows Bluetooth APIs. **Use this for production.**
- **DLL**: Kotlin/Native stub that always returns `UNSUPPORTED` state. Not functional for Bluetooth operations.
- The JAR can be used from C# MAUI applications (see [CSHARP_MAUI_INTEGRATION.md](CSHARP_MAUI_INTEGRATION.md))
- Building the JAR requires JDK 11+
- Building the DLL requires a Windows host with mingw-w64 toolchain

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

```kotlin
import com.niox.nioxplugin.*

// Create plugin instance
val plugin = createNioxCommunicationPlugin()

// Check Bluetooth state
val state = plugin.checkBluetoothState()

// Scan for devices (returns list)
val devices = plugin.scanForDevices(scanDurationMs = 10000)
devices.forEach { device ->
    println("Found device: ${device.name} - ${device.address}")
}
```

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

### iOS
- Uses CoreBluetooth framework
- Requires Bluetooth usage descriptions in Info.plist
- Works on iOS 13.0+

### Windows
- **JAR Implementation (Recommended)**: Full Bluetooth scanning using JNA to access Windows Bluetooth Classic APIs
- Supports checking Bluetooth adapter state (enabled/disabled/unsupported)
- Supports device scanning with duration control and NIOX device filtering
- Uses `Bthprops.cpl` (Windows Bluetooth API) for device enumeration
- RSSI (signal strength) is not available on Windows Bluetooth Classic API
- Requires JRE 11+ to run
- Works on Windows 10/11 with Bluetooth hardware
- Can be integrated into C# MAUI applications (see [CSHARP_MAUI_INTEGRATION.md](CSHARP_MAUI_INTEGRATION.md))
- **DLL Implementation**: Native stub only, not functional for Bluetooth operations

## License

Copyright (c) 2024 Niox. All rights reserved.

## Support

For issues and questions, please contact the Niox development team.
