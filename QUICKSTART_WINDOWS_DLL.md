# Quick Start: Windows WinRT DLL

## TL;DR - Build the DLL Now!

```powershell
# On a Windows 10/11 machine with Visual Studio installed:
.\build-winrt-native-dll.ps1
```

**Output**: `nioxplugin/build/outputs/windows/NioxCommunicationPluginWinRT.dll`

---

## Prerequisites (5 minutes)

1. **Windows 10/11** (64-bit)
2. **Visual Studio 2019 or 2022** with:
   - ✅ Desktop development with C++
   - ✅ C++/WinRT (under Individual Components)

Don't have Visual Studio? [Download Visual Studio Community (Free)](https://visualstudio.microsoft.com/downloads/)

---

## Build Steps (3 minutes)

### Option 1: PowerShell Script (Recommended)

```powershell
# Navigate to project directory
cd C:\Path\To\NIOXSDKPlugin

# Run build script
.\build-winrt-native-dll.ps1

# Done! DLL is in nioxplugin/build/outputs/windows/
```

### Option 2: Manual Build

```powershell
# 1. Compile C++ wrapper
cd nioxplugin\src\nativeInterop\cpp
cl.exe /EHsc /std:c++17 /MD /await /c winrt_ble_wrapper.cpp

# 2. Build Kotlin/Native DLL
cd ..\..\..\..
.\gradlew :nioxplugin:linkReleaseSharedWindowsWinRtNative

# 3. Copy DLL
copy nioxplugin\build\bin\windowsWinRtNative\releaseShared\NioxCommunicationPluginWinRT.dll nioxplugin\build\outputs\windows\
```

---

## Use in C# (2 minutes)

### 1. Add DLL to Your Project

Copy `NioxCommunicationPluginWinRT.dll` to your application directory:

```
YourApp/
├── YourApp.exe
└── NioxCommunicationPluginWinRT.dll  ← Copy here
```

### 2. Add P/Invoke Declarations

```csharp
using System;
using System.Runtime.InteropServices;

class NioxScanner
{
    [DllImport("NioxCommunicationPluginWinRT.dll", CallingConvention = CallingConvention.Cdecl)]
    private static extern int niox_init();

    [DllImport("NioxCommunicationPluginWinRT.dll", CallingConvention = CallingConvention.Cdecl)]
    private static extern int niox_check_bluetooth();

    [DllImport("NioxCommunicationPluginWinRT.dll", CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr niox_scan_devices(long durationMs, int nioxOnly);

    [DllImport("NioxCommunicationPluginWinRT.dll", CallingConvention = CallingConvention.Cdecl)]
    private static extern void niox_free_string(IntPtr ptr);

    [DllImport("NioxCommunicationPluginWinRT.dll", CallingConvention = CallingConvention.Cdecl)]
    private static extern void niox_cleanup();
}
```

### 3. Use the API

```csharp
static void Main()
{
    // Initialize
    if (niox_init() != 1)
    {
        Console.WriteLine("Failed to initialize");
        return;
    }

    // Check Bluetooth
    int state = niox_check_bluetooth();
    if (state != 0) // 0 = ENABLED
    {
        Console.WriteLine("Bluetooth is not enabled");
        niox_cleanup();
        return;
    }

    // Scan for NIOX devices (10 seconds)
    IntPtr resultPtr = niox_scan_devices(10000, 1);

    if (resultPtr != IntPtr.Zero)
    {
        // Get JSON result
        string json = Marshal.PtrToStringAnsi(resultPtr);
        Console.WriteLine($"Found devices: {json}");

        // IMPORTANT: Free the string!
        niox_free_string(resultPtr);
    }

    // Cleanup
    niox_cleanup();
}
```

**That's it!** You now have full Bluetooth LE scanning in your C# app.

---

## Example JSON Output

```json
[
  {
    "name": "NIOX PRO 070401992",
    "address": "AA:BB:CC:DD:EE:FF",
    "rssi": -65,
    "isNioxDevice": true,
    "serialNumber": "070401992"
  },
  {
    "name": "NIOX PRO 070401993",
    "address": "11:22:33:44:55:66",
    "rssi": -72,
    "isNioxDevice": true,
    "serialNumber": "070401993"
  }
]
```

---

## API Reference

### Functions

| Function | Returns | Description |
|----------|---------|-------------|
| `niox_init()` | `1` = success, `0` = fail | Initialize plugin |
| `niox_check_bluetooth()` | `0` = enabled, `1` = disabled, `2` = unsupported, `3` = unknown | Check Bluetooth state |
| `niox_scan_devices(ms, nioxOnly)` | JSON string (must free) | Scan for devices |
| `niox_free_string(ptr)` | void | Free JSON string |
| `niox_cleanup()` | void | Cleanup resources |

### Scan Parameters

```csharp
niox_scan_devices(
    10000,  // durationMs: 10 seconds
    1       // nioxOnly: 1 = NIOX only, 0 = all devices
)
```

---

## Complete Examples

See these files for full examples:
- **C#**: [example/Windows/CSharpExample.cs](example/Windows/CSharpExample.cs)
- **Complete Guide**: [WINDOWS_DLL_COMPLETE_GUIDE.md](WINDOWS_DLL_COMPLETE_GUIDE.md)

---

## Troubleshooting

### Build Issues

**"Visual Studio not found"**
→ Install Visual Studio 2019/2022 with "Desktop development with C++"

**"C++/WinRT not found"**
→ Open Visual Studio Installer → Modify → Individual Components → Add "C++/WinRT"

**Build works but no DLL**
→ Try clean build: `.\build-winrt-native-dll.ps1 -Clean`

### Runtime Issues

**"DLL not found"**
→ Copy DLL to same directory as your .exe

**"Bluetooth state returns 1 (DISABLED)"**
→ Enable Bluetooth in Windows Settings

**"No devices found"**
→ Ensure NIOX device is on and in pairing mode
→ Try longer scan: `niox_scan_devices(30000, 1)` (30 seconds)

---

## What's Next?

- ✅ Parse JSON with `System.Text.Json` or `Newtonsoft.Json`
- ✅ Build a proper device class wrapper
- ✅ Add async/await support
- ✅ Implement UI updates during scan
- ✅ Add error handling and logging

See [WINDOWS_DLL_COMPLETE_GUIDE.md](WINDOWS_DLL_COMPLETE_GUIDE.md) for advanced topics!

---

## Key Features

✅ **Full BLE Support** - RSSI values, service UUIDs, advertisements
✅ **No JVM Required** - Pure native DLL
✅ **Fast** - < 50ms startup, < 10MB memory
✅ **Modern** - Uses Windows 10/11 WinRT APIs
✅ **Easy Integration** - Simple C API via P/Invoke

---

**Questions?** See [WINDOWS_DLL_COMPLETE_GUIDE.md](WINDOWS_DLL_COMPLETE_GUIDE.md) for comprehensive documentation.
