# Removed Implementations - Windows Classic Bluetooth

This document details the Windows Classic Bluetooth implementations that were removed from the project in favor of the modern WinRT BLE implementations.

## Date Removed
October 24, 2024

## Reason for Removal
The project has been streamlined to focus exclusively on **full BLE (Bluetooth Low Energy)** support across all platforms. The Windows Classic Bluetooth implementations were removed because:

1. **No RSSI Support**: Windows Bluetooth Classic API doesn't provide RSSI (signal strength) values
2. **Limited BLE Features**: Classic API doesn't support modern BLE features like service UUID filtering, advertisements, etc.
3. **Inconsistent Platform Support**: Android and iOS use full BLE APIs, Windows Classic was the outlier
4. **Maintenance Burden**: Four Windows implementations added complexity
5. **Modern API Available**: WinRT provides full BLE support on Windows 10/11

## Removed Components

### 1. Source Code Directories

#### `windowsMain/` - JVM + Bluetooth Classic
**Location**: `nioxplugin/src/windowsMain/`

**Technology**:
- JVM-based implementation
- JNA (Java Native Access) to call Windows APIs
- Bluetooth Classic API via `Bthprops.cpl`

**Files Removed**:
- `windowsMain/kotlin/com/niox/nioxplugin/NioxCommunicationPlugin.windows.kt` (367 lines)
- `windowsMain/kotlin/com/niox/nioxplugin/cli/Main.kt` (75 lines)

**Features**:
- ✅ Device scanning (Classic Bluetooth only)
- ✅ Bluetooth state checking
- ✅ JNA structure definitions for Windows APIs
- ✅ CLI tool for command-line usage
- ❌ No RSSI values
- ❌ No BLE service UUID filtering
- ❌ No advertisement data

#### `windowsNativeMain/` - Native DLL + Bluetooth Classic
**Location**: `nioxplugin/src/windowsNativeMain/`

**Technology**:
- Kotlin/Native with C interop
- Direct Windows API calls via `bluetoothapis.h`
- MinGW-w64 toolchain
- No JVM required

**Files Removed**:
- `windowsNativeMain/kotlin/com/niox/nioxplugin/NioxCommunicationPlugin.windowsNative.kt` (239 lines)
- `windowsNativeMain/kotlin/com/niox/nioxplugin/CApi.kt` (133 lines)

**Features**:
- ✅ Native DLL (~500KB, no JVM)
- ✅ C API exports for P/Invoke
- ✅ Memory-safe operations with `memScoped`
- ✅ Direct Windows Bluetooth API calls
- ❌ No RSSI values
- ❌ No BLE features
- ⚠️ Had DLL export issues (functions not exported correctly)

### 2. C Interop Configuration

**File Removed**: `nioxplugin/src/nativeInterop/cinterop/windowsBluetooth.def`

```def
headers = windows.h bluetoothapis.h
headerFilter = bluetoothapis.h
package = platform.windows.bluetooth

compilerOpts.mingw = -DUNICODE -D_UNICODE
linkerOpts.mingw = -lBthprops -lKernel32
```

This file defined the C interop bindings for Windows Bluetooth Classic APIs.

### 3. Build Scripts

#### `build-native-dll.ps1` (370 lines)
**Purpose**: Build Windows Native DLL with Bluetooth Classic

**Features**:
- Normal mode (fast, uses cache)
- Clean mode (deep clean rebuild)
- Source file verification
- C interop generation
- Comprehensive diagnostics
- Build mode help system

#### `build-windows-jar.ps1` (estimated ~150 lines)
**Purpose**: Build Windows JAR with JVM + Bluetooth Classic

**Features**:
- Clean build process
- JVM + JNA implementation
- Automatic verification
- Usage recommendations

### 4. Build Configuration Changes

**File**: `nioxplugin/build.gradle.kts`

**Removed Gradle Targets**:
```kotlin
// Removed: JVM Windows target (Classic)
jvm("windows") {
    compilations.all {
        kotlinOptions { jvmTarget = "11" }
    }
    attributes {
        attribute(Attribute.of("com.niox.bluetooth.type", String::class.java), "classic")
    }
}

// Removed: Native Windows target (Classic)
mingwX64("windowsNative") {
    compilations.getByName("main") {
        cinterops {
            val windowsBluetooth by creating {
                defFile(project.file("src/nativeInterop/cinterop/windowsBluetooth.def"))
                packageName("platform.windows.bluetooth")
            }
        }
    }
    binaries {
        sharedLib {
            baseName = "NioxCommunicationPlugin"
            linkerOpts("-lBthprops", "-lKernel32")
        }
    }
}
```

**Removed Source Sets**:
```kotlin
val windowsMain by getting {
    dependencies {
        implementation("net.java.dev.jna:jna:5.13.0")
        implementation("net.java.dev.jna:jna-platform:5.13.0")
    }
}

val windowsNativeMain by getting
```

**Removed Build Tasks**:
```kotlin
tasks.register<Jar>("buildWindowsJar") { ... }
tasks.register<Copy>("buildWindowsNativeDll") { ... }
```

### 5. Documentation Updates

**Updated Files**:
- `README.md` - Completely rewritten to focus on WinRT implementations only
- Removed all references to "Legacy" Classic implementations
- Updated platform notes to highlight BLE support
- Simplified build instructions

**Documentation Files Not Updated** (may contain outdated references):
- `BUILD_SCRIPTS_REFERENCE.md`
- `BUILD_AND_TEST_WINDOWS_NATIVE.md`
- `EXPORT_FIX_NEEDED.md`
- `IMPLEMENTATION_CHANGES.md`
- Example application documentation

## What Remains

### Current Windows Implementations

The project now has **two WinRT-based implementations**, both with full BLE support:

#### 1. `windowsWinRtMain` - JVM + WinRT BLE
**Location**: `nioxplugin/src/windowsWinRtMain/`

**Features**:
- ✅ Full BLE support
- ✅ RSSI values
- ✅ Service UUID filtering
- ✅ Advertisement data
- ✅ JVM deployment
- ⚠️ Implementation incomplete (WinRT bindings partial)

**Output**: `niox-communication-plugin-windows-winrt-1.0.0.jar`

#### 2. `windowsWinRtNativeMain` - Native DLL + WinRT BLE
**Location**: `nioxplugin/src/windowsWinRtNativeMain/`

**Features**:
- ✅ Full BLE support
- ✅ RSSI values
- ✅ No JVM required
- ✅ C++/WinRT wrapper
- ⚠️ Implementation incomplete

**Output**: `NioxCommunicationPluginWinRT.dll`

**C++ Wrapper**: `nioxplugin/src/nativeInterop/cpp/winrt_ble_wrapper.cpp`

### Remaining Build Scripts

1. `build-android.sh` - Android AAR
2. `build-ios.sh` - iOS XCFramework
3. `build-windows-winrt-jar.ps1` - Windows WinRT JAR
4. `build-windows-winrt-jar.sh` - Windows WinRT JAR (Unix)
5. `build-winrt-native-dll.ps1` - Windows WinRT DLL

### Remaining C Interop Files

- `nioxplugin/src/nativeInterop/cinterop/winrtBle.def` - WinRT BLE bindings
- `nioxplugin/src/nativeInterop/cpp/winrt_ble_wrapper.cpp` - C++/WinRT wrapper
- `nioxplugin/src/nativeInterop/cpp/winrt_ble_wrapper.h` - C++/WinRT header

## Migration Guide

### For Users of `windowsMain` (Classic JAR)

**Before** (Classic JAR):
```kotlin
// Used Bluetooth Classic API, no RSSI
val plugin = createNioxCommunicationPlugin()
val devices = plugin.scanForDevices()
// device.rssi was always null
```

**After** (WinRT JAR):
```kotlin
// Uses WinRT BLE API, has RSSI
val plugin = createNioxCommunicationPlugin()
val devices = plugin.scanForDevices()
// device.rssi now contains actual signal strength
```

**Build Change**:
```powershell
# Before
.\build-windows-jar.ps1

# After
.\build-windows-winrt-jar.ps1
```

**Output Change**:
- Before: `niox-communication-plugin-windows-1.0.0.jar`
- After: `niox-communication-plugin-windows-winrt-1.0.0.jar`

### For Users of `windowsNativeMain` (Classic DLL)

**Before** (Classic DLL):
```csharp
// P/Invoke to Classic DLL
[DllImport("NioxCommunicationPlugin.dll")]
private static extern int niox_check_bluetooth();
```

**After** (WinRT DLL):
```csharp
// P/Invoke to WinRT DLL
[DllImport("NioxCommunicationPluginWinRT.dll")]
private static extern int niox_check_bluetooth();
```

**Build Change**:
```powershell
# Before
.\build-native-dll.ps1

# After
.\build-winrt-native-dll.ps1
```

**Output Change**:
- Before: `NioxCommunicationPlugin.dll`
- After: `NioxCommunicationPluginWinRT.dll`

**API Changes**:
- Same C API function signatures
- WinRT version returns RSSI values in scan results
- Requires Windows 10 build 1809+ (Windows Classic worked on older versions)

## Benefits of Removal

1. **✅ Consistent BLE Support**: All platforms now use full BLE APIs with RSSI
2. **✅ Reduced Complexity**: Two Windows implementations instead of four
3. **✅ Easier Maintenance**: Less code to maintain and test
4. **✅ Modern APIs**: Focus on Windows 10/11 with WinRT
5. **✅ Better Features**: RSSI, service UUIDs, advertisements on Windows
6. **✅ Clearer Documentation**: Simpler to understand and use

## Potential Drawbacks

1. **⚠️ Windows 7/8 Support Lost**: WinRT requires Windows 10 build 1809+
2. **⚠️ Incomplete WinRT**: Current WinRT implementations are partial
3. **⚠️ Breaking Change**: Users of Classic implementations must migrate

## Recommendations

### If You Need Windows 7/8 Support

The Classic implementations were removed from the main branch. If you need support for older Windows versions:

1. **Option A**: Use an older version/commit of this library
2. **Option B**: Implement your own Bluetooth Classic wrapper
3. **Option C**: Upgrade to Windows 10/11 (recommended)

### If You Need the Removed Code

The removed implementations are preserved in git history:

```bash
# View last commit with Classic implementations
git log --all --full-history -- "nioxplugin/src/windowsMain/"

# Restore Classic implementations from git history
git checkout <commit-hash> -- nioxplugin/src/windowsMain/
git checkout <commit-hash> -- nioxplugin/src/windowsNativeMain/
```

## Summary

The removal of Windows Classic Bluetooth implementations streamlines the project to focus on **modern, full-featured BLE support** across all platforms. While this is a breaking change, it provides better functionality (RSSI values, service UUIDs, etc.) and aligns Windows with the capabilities already available on Android and iOS.

**Current Platform Support**:
- ✅ Android: Full BLE with RSSI
- ✅ iOS: Full BLE with RSSI
- ✅ Windows: Full BLE with RSSI (WinRT implementations)

All three platforms now provide a consistent, feature-rich BLE experience.
