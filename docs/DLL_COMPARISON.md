# DLL Comparison: Stub vs Full-Featured

## ❌ What You're Building Now (WRONG)

### Command You're Using:
```powershell
# PowerShell
.\gradlew.bat :nioxplugin:buildWindowsNativeDll

# Or via build-all.ps1
.\build-all.ps1
```

### What This Builds:
- **File:** `NioxCommunicationPlugin.dll`
- **Location:** `nioxplugin/build/outputs/windows/NioxCommunicationPlugin.dll`
- **Source:** `nioxplugin/src/windowsNativeMain/kotlin/.../NioxCommunicationPlugin.windowsNative.kt`
- **Type:** Kotlin/Native DLL (mingwX64)
- **Features:** ❌ **STUB ONLY** - Returns empty results!

### What This DLL Does:
```csharp
// When you call it:
var state = plugin.checkBluetoothState();
// Returns: UNSUPPORTED (always!)

var devices = plugin.scanForDevices(10000);
// Returns: [] (empty list - always!)
```

### Why It Doesn't Work:
Look at the source code:
```kotlin
// From windowsNativeMain/NioxCommunicationPlugin.windowsNative.kt
class WindowsNativeNioxCommunicationPlugin : NioxCommunicationPlugin {
    override suspend fun checkBluetoothState(): BluetoothState = BluetoothState.UNSUPPORTED

    override suspend fun scanForDevices(...): List<BluetoothDevice> {
        delay(scanDurationMs)  // Just waits
        return emptyList()     // Returns NOTHING!
    }
}
```

**This is a buildable stub for testing build configurations - IT'S NOT FUNCTIONAL!**

---

## ✅ What You SHOULD Build (CORRECT)

### Command You Should Use:

**Option A: Using My New Script (Recommended)**
```powershell
# PowerShell (Windows)
.\build-windows-full.ps1
```

```bash
# Bash (Mac/Linux)
./build-windows-full.sh
```

**Option B: Manual Steps**
```powershell
# Step 1: Build JAR
.\gradlew.bat :nioxplugin:buildWindowsJar

# Step 2: Install IKVM (one time only)
dotnet tool install -g ikvm

# Step 3: Convert JAR to DLL
cd nioxplugin\build\outputs\windows
ikvmc -target:library -out:NioxPlugin.dll niox-communication-plugin-windows-1.0.0.jar
```

### What This Builds:
- **File:** `NioxPlugin.dll` (via IKVM conversion)
- **Location:** `nioxplugin/build/outputs/windows/NioxPlugin.dll`
- **Source:** `nioxplugin/src/windowsMain/kotlin/.../NioxCommunicationPlugin.windows.kt` (367 lines!)
- **Type:** JAR → .NET DLL (via IKVM)
- **Features:** ✅ **FULL BLUETOOTH API**

### What This DLL Does:
```csharp
// When you call it:
var state = plugin.checkBluetoothState();
// Returns: ENABLED, DISABLED, or UNSUPPORTED (real status!)

var devices = plugin.scanForDevices(10000);
// Returns: [Device1, Device2, ...] (actual Bluetooth devices!)
```

### Why It Works:
Look at the source code:
```kotlin
// From windowsMain/NioxCommunicationPlugin.windows.kt (367 lines)
class WindowsNioxCommunicationPlugin : NioxCommunicationPlugin {
    override suspend fun checkBluetoothState(): BluetoothState {
        // Calls Windows BluetoothFindFirstRadio() via JNA
        val findHandle = BluetoothLib.BluetoothFindFirstRadio(params, handleRef)
        // Returns actual state!
    }

    override suspend fun scanForDevices(...): List<BluetoothDevice> {
        // Calls Windows BluetoothFindFirstDevice() via JNA
        val deviceFindHandle = BluetoothLib.BluetoothFindFirstDevice(...)
        // Enumerates REAL devices and returns them!
    }
}
```

**This uses JNA to call real Windows Bluetooth APIs - IT'S FULLY FUNCTIONAL!**

---

## Side-by-Side Comparison

| Feature | ❌ Stub DLL (`buildWindowsNativeDll`) | ✅ Full DLL (`buildWindowsJar` + IKVM) |
|---------|---------------------------------------|----------------------------------------|
| **Build Command** | `buildWindowsNativeDll` | `buildWindowsJar` + IKVM conversion |
| **Output File** | `NioxCommunicationPlugin.dll` | `NioxPlugin.dll` |
| **File Size** | ~50 KB | ~500+ KB |
| **Technology** | Kotlin/Native (mingwX64) | Kotlin/JVM → .NET (IKVM) |
| **Source Lines** | 28 lines (stub) | 367 lines (real implementation) |
| **Uses JNA** | ❌ No | ✅ Yes |
| **Calls Windows APIs** | ❌ No | ✅ Yes (Bthprops.cpl, kernel32) |
| **Check Bluetooth State** | ❌ Always UNSUPPORTED | ✅ Real state checking |
| **Scan for Devices** | ❌ Returns empty list | ✅ Returns actual devices |
| **Works in WinUI/MAUI** | ❌ NO (useless) | ✅ YES (fully functional) |
| **Runtime Requirements** | .NET | .NET (no JVM needed) |
| **Production Ready** | ❌ NO - Just a stub | ✅ YES - Complete implementation |

---

## How to Tell Which DLL You Have

### Method 1: File Size
```powershell
# In nioxplugin/build/outputs/windows/
dir *.dll

# Stub DLL: ~50 KB
# Full DLL: ~500+ KB (includes IKVM runtime + JNA)
```

### Method 2: File Name
- `NioxCommunicationPlugin.dll` = ❌ Stub (from Kotlin/Native)
- `NioxPlugin.dll` = ✅ Full (from IKVM conversion)

### Method 3: Test It
```csharp
// In your C# app:
var plugin = NioxCommunicationPluginKt.createNioxCommunicationPlugin();
var state = plugin.checkBluetoothState();

// If it ALWAYS returns "UNSUPPORTED" → You have the stub
// If it returns "ENABLED" when Bluetooth is on → You have the full DLL
```

---

## What You Need to Do Now

### Step 1: Delete the Stub DLL (if you built it)
```powershell
# Remove the useless stub
rm nioxplugin\build\outputs\windows\NioxCommunicationPlugin.dll
```

### Step 2: Build the FULL DLL
```powershell
# Use my script (easiest)
.\build-windows-full.ps1

# Or manual steps:
.\gradlew.bat :nioxplugin:buildWindowsJar
dotnet tool install -g ikvm
cd nioxplugin\build\outputs\windows
ikvmc -target:library -out:NioxPlugin.dll niox-communication-plugin-windows-1.0.0.jar
```

### Step 3: Use in Your WinUI App
Follow the guide: [WINUI3_STEP_BY_STEP.md](WINUI3_STEP_BY_STEP.md)

---

## Why Are There Two DLLs?

### Historical Context:
1. **Windows JVM Target** (`windowsMain/`) - Written first with full JNA Bluetooth implementation
2. **Windows Native Target** (`windowsNativeMain/`) - Added later as a stub for potential future native implementation

The native stub exists so the project can "build on Windows" without errors, but **it's not functional**.

### Which Should You Use?
**ALWAYS use the Windows JVM → IKVM DLL!**

The native DLL is just a placeholder. Don't waste time with it.

---

## Visual Guide

```
❌ WRONG WAY (What you're doing now):
┌─────────────────────────────────────────┐
│ windowsNativeMain/                      │
│ └── NioxCommunicationPlugin.kt (28 lines)│
│     └── STUB: Returns empty/UNSUPPORTED │
└─────────────────────────────────────────┘
           ↓ Kotlin/Native Compiler
┌─────────────────────────────────────────┐
│ NioxCommunicationPlugin.dll (50 KB)     │
│ ❌ DOESN'T WORK - Just a stub!         │
└─────────────────────────────────────────┘

✅ CORRECT WAY (What you should do):
┌─────────────────────────────────────────┐
│ windowsMain/                            │
│ └── NioxCommunicationPlugin.kt (367 lines)│
│     └── FULL: JNA + Windows Bluetooth  │
└─────────────────────────────────────────┘
           ↓ Kotlin/JVM Compiler
┌─────────────────────────────────────────┐
│ niox-communication-plugin-windows.jar   │
└─────────────────────────────────────────┘
           ↓ IKVM Converter
┌─────────────────────────────────────────┐
│ NioxPlugin.dll (500+ KB)                │
│ ✅ FULLY FUNCTIONAL - Real Bluetooth!  │
└─────────────────────────────────────────┘
```

---

## Summary

### ❌ Don't Use:
- `buildWindowsNativeDll` task
- `NioxCommunicationPlugin.dll` file
- `windowsNativeMain/` source code

### ✅ Do Use:
- `buildWindowsJar` task + IKVM conversion
- `NioxPlugin.dll` file (from IKVM)
- `windowsMain/` source code (full implementation)

### Quick Commands:
```powershell
# Build the FULL DLL (run this!):
.\build-windows-full.ps1

# Then follow:
docs\WINUI3_STEP_BY_STEP.md
```

---

**You were so close! You just need to build the JAR and convert it to DLL, not build the native stub DLL.**

---

**Last Updated:** October 23, 2024
