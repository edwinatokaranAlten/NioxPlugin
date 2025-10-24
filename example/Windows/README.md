# NIOX Bluetooth WinUI Example App

A WinUI 3 desktop application demonstrating how to use the NIOX Communication Plugin on Windows.

## 🚀 Quick Start (If DLL Loading Works)

1. Open `NioxBluetoothApp.sln` in Visual Studio 2022
2. Set build configuration to **x64** (not x86 or ARM64)
3. Build and run (F5)
4. Click "Run DLL Diagnostics" to verify the DLL is loading correctly
5. Click "Scan for Devices" to find NIOX Bluetooth devices

## ⚠️ Troubleshooting DLL Loading Issues

If you see the error: **"Unable to load DLL 'NioxCommunicationPlugin.dll'"**

### Solution 1: Run Diagnostics (Easiest)

1. Run the app
2. Click the **"Run DLL Diagnostics"** button (red button)
3. Read the diagnostic report to see what's wrong

The diagnostics will tell you:
- ✅ Whether the DLL file exists
- ✅ Whether Windows can load it
- ✅ What error code you're getting
- ✅ Which functions are exported
- ✅ Specific solutions for your error

### Solution 2: Check Architecture

**The DLL is 64-bit (x64) only!**

In Visual Studio:
1. Go to **Build → Configuration Manager**
2. Set "Active solution platform" to **x64**
3. Ensure the project is also set to **x64**
4. Rebuild and run

### Solution 3: Rebuild DLL on Windows

The current DLL was cross-compiled on macOS. For best results:

```bash
# On a Windows machine with MinGW or MSVC
cd /path/to/NIOXSDKPlugin
./gradlew linkReleaseSharedWindowsNative

# Copy the DLL
cp nioxplugin/build/bin/windowsNative/releaseShared/NioxCommunicationPlugin.dll \
   example/Windows/NioxBluetoothApp/Libraries/
```

### Solution 4: Check for Missing Dependencies

The DLL might need MinGW runtime libraries:
- `libgcc_s_seh-1.dll`
- `libstdc++-6.dll`
- `libwinpthread-1.dll`

**How to find them:**
1. Download [Dependencies.exe](https://github.com/lucasg/Dependencies) (free tool)
2. Open `NioxCommunicationPlugin.dll` in Dependencies
3. Check for any DLLs shown in red (missing)
4. Copy those DLLs to the app's output directory

### Solution 5: Use IKVM/JVM Implementation (Alternative)

Instead of the native DLL, you can use the Java-based implementation:

1. Copy the JAR instead:
   ```bash
   cp nioxplugin/build/libs/niox-communication-plugin-windows-1.0.0.jar \
      example/Windows/NioxBluetoothApp/Libraries/
   ```

2. Modify the C# code to use IKVM (call Java classes directly)

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed steps.

---

## 📁 Project Structure

```
NioxBluetoothApp/
├── App.xaml                    # Application entry point
├── App.xaml.cs
├── MainWindow.xaml             # Main UI layout
├── MainWindow.xaml.cs          # UI logic
├── DllDiagnostics.cs          # 🆕 DLL troubleshooting utility
├── Services/
│   └── BluetoothService.cs    # Native DLL wrapper (P/Invoke)
├── Libraries/
│   └── NioxCommunicationPlugin.dll  # Native Bluetooth plugin
└── Package.appxmanifest       # App manifest
```

---

## 🔧 What's New

### Added in Latest Update:

1. **DLL Diagnostics Tool** ([DllDiagnostics.cs](NioxBluetoothApp/DllDiagnostics.cs))
   - Comprehensive DLL loading checks
   - Error code descriptions
   - Function export verification
   - Version testing

2. **Diagnostic Button** in UI
   - Red "Run DLL Diagnostics" button
   - Shows detailed report in a dialog
   - Helps identify DLL loading issues

3. **Enhanced Error Handling** ([BluetoothService.cs](NioxBluetoothApp/Services/BluetoothService.cs))
   - Better error messages
   - Debug logging
   - Explicit DLL loading with error codes

---

## 📋 Requirements

- **Windows 10** version 1809 (build 17763) or later
- **Windows 11** (recommended)
- **.NET 8.0 SDK**
- **Visual Studio 2022** with:
  - Windows App SDK
  - C# Desktop Development workload
- **x64 architecture** (the DLL is 64-bit only)

---

## 🎯 Features

### Current Features:
- ✅ Check Bluetooth adapter status
- ✅ Scan for Bluetooth devices
- ✅ Filter NIOX devices only
- ✅ Display device name, address, and serial number
- ✅ Real-time status updates
- ✅ DLL diagnostics tool

### Bluetooth Operations:
- `checkBluetoothState()` - Detects if Bluetooth is enabled/disabled/unsupported
- `scanForDevices()` - Scans for devices with configurable duration
- NIOX device filtering - Shows only devices matching NIOX pattern

---

## 🐛 Known Issues

1. **DLL Cross-Compilation**: The DLL was built on macOS using MinGW. For best results, rebuild on Windows.

2. **Missing RSSI**: The Windows Bluetooth Classic API doesn't provide RSSI values. This is a Windows limitation.

3. **Bluetooth LE vs Classic**: The current implementation uses Bluetooth Classic API. For BLE devices, a different API would be needed.

---

## 📖 API Usage

### C# P/Invoke Signatures:

```csharp
// Initialize plugin (call once)
[DllImport("NioxCommunicationPlugin.dll", CallingConvention = CallingConvention.Cdecl)]
private static extern int niox_init();

// Check Bluetooth state (0=Enabled, 1=Disabled, 2=Unsupported, 3=Unknown)
[DllImport("NioxCommunicationPlugin.dll", CallingConvention = CallingConvention.Cdecl)]
private static extern int niox_check_bluetooth();

// Scan for devices (returns JSON string)
[DllImport("NioxCommunicationPlugin.dll", CallingConvention = CallingConvention.Cdecl)]
private static extern IntPtr niox_scan_devices(long durationMs, int nioxOnly);

// Free string memory
[DllImport("NioxCommunicationPlugin.dll", CallingConvention = CallingConvention.Cdecl)]
private static extern void niox_free_string(IntPtr ptr);

// Cleanup
[DllImport("NioxCommunicationPlugin.dll", CallingConvention = CallingConvention.Cdecl)]
private static extern void niox_cleanup();

// Get version
[DllImport("NioxCommunicationPlugin.dll", CallingConvention = CallingConvention.Cdecl)]
private static extern IntPtr niox_version();
```

---

## 🔍 Debug Tips

### View Debug Output:
1. Run app from Visual Studio (F5)
2. Open **View → Output**
3. Select "Debug" from the dropdown
4. Look for messages from `BluetoothService`

### Check DLL Location:
```csharp
string appDir = AppDomain.CurrentDomain.BaseDirectory;
// DLL should be at: {appDir}\NioxCommunicationPlugin.dll
```

### Common Error Codes:
- `0x7E` (126) - Module not found (missing dependencies)
- `0xC1` (193) - Bad EXE format (x86 vs x64 mismatch)
- `0x2` (2) - File not found

---

## 📚 Additional Resources

- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Detailed troubleshooting guide
- [WinUI 3 Documentation](https://learn.microsoft.com/en-us/windows/apps/winui/winui3/)
- [P/Invoke Tutorial](https://learn.microsoft.com/en-us/dotnet/standard/native-interop/pinvoke)
- [Dependencies Tool](https://github.com/lucasg/Dependencies) - DLL dependency checker

---

## 🤝 Support

If you're still having issues:
1. Click "Run DLL Diagnostics" and save the report
2. Check the Visual Studio Output window
3. Try rebuilding the DLL on Windows
4. Consider using the JVM/IKVM implementation

---

## ✅ Checklist for Deployment

Before deploying your app:

- [ ] DLL is in the Libraries folder
- [ ] Building for x64 architecture
- [ ] Tested on target Windows version
- [ ] All dependencies included
- [ ] Bluetooth permissions in manifest
- [ ] MSIX package builds successfully
- [ ] DLL diagnostics report shows success

---

**Last Updated:** October 2025
