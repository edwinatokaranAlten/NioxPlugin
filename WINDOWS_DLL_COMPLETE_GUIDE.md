# Windows WinRT Native DLL - Complete Guide

## Overview

The **NioxCommunicationPluginWinRT.dll** is a native Windows library that provides full Bluetooth Low Energy (BLE) scanning capabilities with RSSI (signal strength) values. It's built using Kotlin/Native with C++/WinRT for direct access to Windows 10/11 Bluetooth APIs.

### Key Features

- ✅ **Full BLE Support**: Complete Bluetooth LE scanning with RSSI values
- ✅ **No JVM Required**: Native DLL, no Java runtime dependency
- ✅ **WinRT Integration**: Uses modern Windows.Devices.Bluetooth APIs
- ✅ **C API Exports**: Easy P/Invoke integration from C#, C++, or other languages
- ✅ **NIOX Device Filtering**: Built-in filtering for NIOX PRO devices
- ✅ **Small Footprint**: ~2-5 MB DLL size, <10MB memory usage
- ✅ **Windows 10/11**: Supports Windows 10 build 1809+ and Windows 11

## Prerequisites

### For Building the DLL

- **Windows 10/11** (64-bit)
- **Visual Studio 2019 or 2022** with:
  - Desktop development with C++
  - C++/WinRT component
  - Windows 10/11 SDK
- **Gradle 8.5+** (or use included wrapper)
- **JDK 11+** (for Gradle build process only)

### For Using the DLL

- **Windows 10 build 1809+** or **Windows 11**
- **Bluetooth adapter** with BLE support
- Your application (.NET, C++, etc.)

## Building the DLL

### Quick Start

```powershell
# Normal build (recommended)
.\build-winrt-native-dll.ps1

# Clean build (if you encounter issues)
.\build-winrt-native-dll.ps1 -Clean
```

### Build Process Details

The build script performs these steps:

1. **Checks for Visual Studio** and required components
2. **Compiles C++ WinRT wrapper** using MSVC compiler
3. **Builds Kotlin/Native code** and links with C++ object files
4. **Creates the final DLL** with exported C functions
5. **Copies to output directory**: `nioxplugin/build/outputs/windows/`
6. **Verifies DLL exports** using dumpbin (if available)

### Build Output

```
nioxplugin/build/outputs/windows/
└── NioxCommunicationPluginWinRT.dll
```

**File size**: Approximately 2-5 MB (varies by Kotlin/Native version)

### Troubleshooting Build Issues

#### Error: Visual Studio not found

**Solution**: Install Visual Studio 2019 or 2022 with "Desktop development with C++" workload

#### Error: C++/WinRT not found

**Solution**:
1. Open Visual Studio Installer
2. Modify your installation
3. Add "C++/WinRT" component under "Individual Components"

#### Error: Windows SDK not found

**Solution**: Install Windows 10/11 SDK via Visual Studio Installer

#### Build succeeds but DLL missing

**Solution**: Check the console output for errors. Run with `-Clean` flag:
```powershell
.\build-winrt-native-dll.ps1 -Clean
```

## Using the DLL

### C API Reference

The DLL exports the following C functions:

#### 1. Initialize Plugin

```c
int niox_init();
```

**Returns**:
- `1` = Success
- `0` = Failure

**Description**: Initializes the plugin. Must be called before other functions.

---

#### 2. Check Bluetooth State

```c
int niox_check_bluetooth();
```

**Returns**:
- `0` = ENABLED (Bluetooth is on and ready)
- `1` = DISABLED (Bluetooth is off)
- `2` = UNSUPPORTED (No Bluetooth adapter)
- `3` = UNKNOWN (State cannot be determined)

**Description**: Checks the current Bluetooth adapter state.

---

#### 3. Scan for Devices

```c
char* niox_scan_devices(long durationMs, int nioxOnly);
```

**Parameters**:
- `durationMs`: Scan duration in milliseconds (e.g., 10000 for 10 seconds)
- `nioxOnly`:
  - `1` = Scan only for NIOX PRO devices
  - `0` = Scan for all Bluetooth devices

**Returns**: JSON string with discovered devices (must be freed with `niox_free_string`)

**JSON Format**:
```json
[
  {
    "name": "NIOX PRO 070401992",
    "address": "AA:BB:CC:DD:EE:FF",
    "rssi": -65,
    "isNioxDevice": true,
    "serialNumber": "070401992"
  }
]
```

---

#### 4. Free String

```c
void niox_free_string(char* str);
```

**Parameters**:
- `str`: String pointer returned by `niox_scan_devices`

**Description**: Frees memory allocated by the DLL. **Important**: Always call this after using the scan results.

---

#### 5. Cleanup

```c
void niox_cleanup();
```

**Description**: Stops any ongoing scans and releases resources. Call before exiting your application.

---

#### 6. Get Version

```c
const char* niox_version();
```

**Returns**: Version string (e.g., "1.1.0-winrt")

**Note**: Do NOT free this string - it's statically allocated.

---

#### 7. Get Implementation Type

```c
const char* niox_implementation();
```

**Returns**: Implementation type string (e.g., "winrt-ble")

**Note**: Do NOT free this string - it's statically allocated.

---

### C# Integration

#### Basic Usage

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
        Console.WriteLine($"Bluetooth state: {state}");

        if (state == 0) // ENABLED
        {
            // Scan for NIOX devices (10 seconds)
            IntPtr resultPtr = niox_scan_devices(10000, 1);

            if (resultPtr != IntPtr.Zero)
            {
                string json = Marshal.PtrToStringAnsi(resultPtr);
                Console.WriteLine($"Results: {json}");

                // IMPORTANT: Free the string
                niox_free_string(resultPtr);
            }
        }

        // Cleanup
        niox_cleanup();
    }
}
```

#### Complete Example

See [example/Windows/CSharpExample.cs](example/Windows/CSharpExample.cs) for a complete C# wrapper with:
- Bluetooth state checking
- Device scanning
- JSON parsing
- Error handling
- Resource management

### C++ Integration

```cpp
#include <windows.h>
#include <iostream>
#include <string>

typedef int (*niox_init_t)();
typedef int (*niox_check_bluetooth_t)();
typedef char* (*niox_scan_devices_t)(long, int);
typedef void (*niox_free_string_t)(char*);
typedef void (*niox_cleanup_t)();

int main() {
    // Load DLL
    HMODULE hDll = LoadLibrary(L"NioxCommunicationPluginWinRT.dll");
    if (!hDll) {
        std::cerr << "Failed to load DLL" << std::endl;
        return 1;
    }

    // Get function pointers
    auto init = (niox_init_t)GetProcAddress(hDll, "niox_init");
    auto check_bt = (niox_check_bluetooth_t)GetProcAddress(hDll, "niox_check_bluetooth");
    auto scan = (niox_scan_devices_t)GetProcAddress(hDll, "niox_scan_devices");
    auto free_str = (niox_free_string_t)GetProcAddress(hDll, "niox_free_string");
    auto cleanup = (niox_cleanup_t)GetProcAddress(hDll, "niox_cleanup");

    // Initialize
    if (init() != 1) {
        std::cerr << "Failed to initialize" << std::endl;
        FreeLibrary(hDll);
        return 1;
    }

    // Check Bluetooth
    int state = check_bt();
    std::cout << "Bluetooth state: " << state << std::endl;

    if (state == 0) { // ENABLED
        // Scan
        char* result = scan(10000, 1);
        if (result) {
            std::cout << "Results: " << result << std::endl;
            free_str(result);
        }
    }

    // Cleanup
    cleanup();
    FreeLibrary(hDll);

    return 0;
}
```

### Python Integration (ctypes)

```python
import ctypes
import json

# Load DLL
dll = ctypes.CDLL('NioxCommunicationPluginWinRT.dll')

# Define function signatures
dll.niox_init.restype = ctypes.c_int
dll.niox_check_bluetooth.restype = ctypes.c_int
dll.niox_scan_devices.argtypes = [ctypes.c_longlong, ctypes.c_int]
dll.niox_scan_devices.restype = ctypes.c_char_p
dll.niox_free_string.argtypes = [ctypes.c_char_p]
dll.niox_cleanup.restype = None

# Initialize
if dll.niox_init() != 1:
    print("Failed to initialize")
    exit(1)

# Check Bluetooth
state = dll.niox_check_bluetooth()
print(f"Bluetooth state: {state}")

if state == 0:  # ENABLED
    # Scan for devices
    result_ptr = dll.niox_scan_devices(10000, 1)

    if result_ptr:
        # Decode JSON
        json_str = result_ptr.decode('utf-8')
        devices = json.loads(json_str)

        print(f"Found {len(devices)} device(s):")
        for device in devices:
            print(f"  {device['name']} - RSSI: {device['rssi']} dBm")

        # Free string
        dll.niox_free_string(result_ptr)

# Cleanup
dll.niox_cleanup()
```

## Deployment

### Including DLL in Your Application

1. **Copy the DLL** to your application's directory:
   ```
   YourApp/
   ├── YourApp.exe
   └── NioxCommunicationPluginWinRT.dll  ← Copy here
   ```

2. **Or add to PATH**: Place the DLL in a directory that's in the system PATH

3. **For .NET apps**: Set "Copy to Output Directory" to "Copy if newer" in Visual Studio

### Distributing Your Application

When distributing your application, include:
- `NioxCommunicationPluginWinRT.dll`
- Visual C++ Redistributable (if not already installed on target systems)

### System Requirements

Your end users need:
- **Windows 10 build 1809+** or **Windows 11**
- **Bluetooth adapter** with BLE support
- **No additional runtime** (JRE, .NET Framework, etc.) required for the DLL itself

## Performance Characteristics

- **Load Time**: < 50ms
- **Bluetooth State Check**: < 100ms
- **Scan Duration**: Configurable (typically 10 seconds)
- **Memory Usage**: < 10 MB
- **DLL Size**: ~2-5 MB

## Comparison: DLL vs JAR

| Feature | WinRT Native DLL | WinRT JAR |
|---------|------------------|-----------|
| JVM Required | ❌ No | ✅ Yes |
| Startup Time | < 50ms | ~500ms |
| Memory | < 10 MB | ~50 MB |
| File Size | ~5 MB | ~15 MB |
| BLE Support | ✅ Full | ✅ Full |
| RSSI Values | ✅ Yes | ✅ Yes |
| Best For | Native apps (C#, C++) | JVM apps (Java, Kotlin) |

## Known Limitations

1. **Windows 10/11 Only**: Does not work on Windows 7/8 (use WinRT APIs)
2. **BLE Only**: Does not support Bluetooth Classic
3. **Scan Duration**: Fixed duration, cannot stream results in real-time
4. **Thread Safety**: Not designed for concurrent scans from multiple threads

## Troubleshooting Runtime Issues

### DLL Not Found

**Error**: "Unable to load DLL 'NioxCommunicationPluginWinRT.dll'"

**Solutions**:
- Ensure DLL is in the same directory as your executable
- Check if DLL is in PATH
- Verify DLL architecture matches your app (x64)

### Access Denied / Bluetooth Errors

**Error**: State returns DISABLED or UNSUPPORTED

**Solutions**:
- Enable Bluetooth in Windows Settings
- Grant Bluetooth permissions to your app
- Check if Bluetooth adapter is BLE-capable

### No Devices Found

**Possible Causes**:
- No NIOX devices nearby (if scanning with `nioxOnly = 1`)
- Bluetooth disabled on devices
- Devices not advertising
- Scan duration too short

**Solutions**:
- Increase scan duration (try 20-30 seconds)
- Try scanning all devices (`nioxOnly = 0`)
- Ensure NIOX device is powered on and in pairing mode
- Check if other Bluetooth apps can see devices

## Advanced Topics

### Async Scanning in C#

```csharp
using System.Threading.Tasks;

public async Task<BluetoothDevice[]> ScanAsync(long durationMs, bool nioxOnly)
{
    return await Task.Run(() => {
        return ScanForDevices(durationMs, nioxOnly);
    });
}

// Usage
var devices = await ScanAsync(10000, true);
```

### Custom JSON Parsing

Use a proper JSON library like `System.Text.Json` or `Newtonsoft.Json`:

```csharp
using System.Text.Json;

var devices = JsonSerializer.Deserialize<BluetoothDevice[]>(jsonResult);
```

### Error Handling Best Practices

```csharp
try
{
    if (niox_init() != 1)
        throw new Exception("Failed to initialize NIOX plugin");

    IntPtr resultPtr = niox_scan_devices(10000, 1);

    if (resultPtr == IntPtr.Zero)
        throw new Exception("Scan failed");

    try
    {
        string json = Marshal.PtrToStringAnsi(resultPtr);
        // Process results...
    }
    finally
    {
        // Always free the string
        niox_free_string(resultPtr);
    }
}
finally
{
    // Always cleanup
    niox_cleanup();
}
```

## FAQ

### Q: Does this require .NET Framework or .NET Core?

**A**: No. The DLL is native code and can be used from any language that supports P/Invoke or native DLL loading (C#, C++, Python, etc.). Your application can be .NET Framework, .NET Core, .NET 5+, or even non-.NET.

### Q: Can I use this in a WinUI 3 or MAUI app?

**A**: Yes! This DLL works great in modern Windows apps. Use P/Invoke as shown in the C# examples.

### Q: Is the source code available?

**A**: Yes, see:
- [nioxplugin/src/windowsWinRtNativeMain/kotlin/](nioxplugin/src/windowsWinRtNativeMain/kotlin/) - Kotlin/Native code
- [nioxplugin/src/nativeInterop/cpp/](nioxplugin/src/nativeInterop/cpp/) - C++ WinRT wrapper

### Q: How do I update to a new version?

**A**: Replace the DLL file with the new version. The API is stable across versions.

### Q: Can I redistribute this DLL?

**A**: Check the [LICENSE](LICENSE) file for distribution terms.

## Support

For issues, questions, or contributions:
- See [README.md](README.md) for general information
- Check [GitHub Issues](https://github.com/your-repo/issues) for known issues
- Contact the NIOX development team

## Version History

### v1.0.0 (Current)
- Full BLE scanning with RSSI
- NIOX device filtering
- C API exports
- Windows 10/11 support
- C++/WinRT implementation

---

**Last Updated**: 2024-10-28
**Platform**: Windows 10/11 (x64)
**License**: See [LICENSE](LICENSE)
