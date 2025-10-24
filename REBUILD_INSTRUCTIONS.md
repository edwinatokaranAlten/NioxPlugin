# Rebuild Instructions for Windows

## What Changed

The DLL now exports simple C functions that can be called directly from C# via P/Invoke:

### Exported C Functions:
- `niox_init()` - Initialize the plugin
- `niox_check_bluetooth()` - Check Bluetooth state
- `niox_scan_devices(durationMs, nioxOnly)` - Scan for devices
- `niox_free_string(ptr)` - Free returned JSON string
- `niox_cleanup()` - Cleanup resources
- `niox_version()` - Get version string

## Rebuild on Windows

Run this command on your Windows machine:

```powershell
.\build-native-dll.ps1 -Clean
```

The DLL will be output to:
```
nioxplugin\build\outputs\windows\NioxCommunicationPlugin.dll
```

## Verify the Exports

After rebuilding, verify the C functions are exported:

```powershell
# Install dumpbin (part of Visual Studio)
# Or use objdump from MinGW

# Check exports
dumpbin /exports nioxplugin\build\outputs\windows\NioxCommunicationPlugin.dll
```

You should see these exports:
```
niox_init
niox_check_bluetooth
niox_scan_devices
niox_free_string
niox_cleanup
niox_version
```

## Use the Corrected C# Code

Use the `BluetoothService_Corrected.cs` file from the docs folder.

The key changes:
1. ✅ Simple P/Invoke signatures
2. ✅ Calls `niox_init()` to initialize
3. ✅ Uses simple int return values
4. ✅ JSON string marshaling
5. ✅ Proper memory management

## Testing

After rebuilding and copying the DLL to your WinUI project:

1. Run your WinUI app
2. Check Bluetooth status
3. Scan for devices
4. Verify results display correctly

If you get errors, check:
- DLL is in the output folder
- DLL exports are present (use dumpbin)
- C# P/Invoke signatures match
- Java is NOT required (pure native!)

## Summary

The rebuilt DLL:
- ✅ Exports simple C functions
- ✅ No JVM required
- ✅ Direct P/Invoke from C#
- ✅ Smaller, faster
- ✅ Same Bluetooth functionality
