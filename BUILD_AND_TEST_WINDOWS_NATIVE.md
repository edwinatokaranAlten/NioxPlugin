# Building and Testing Windows Native DLL

This guide walks you through building and testing the fully functional Windows Native DLL.

## Prerequisites

### Required Software
- ✅ Windows 10 or Windows 11
- ✅ JDK 11 or higher
- ✅ Gradle 8.5+ (included via wrapper)
- ✅ Git (for version control)

### Optional (Auto-installed by Kotlin/Native)
- MinGW-w64 toolchain
- Windows SDK headers

## Build Steps

### 1. Verify Configuration

```bash
# Check that Gradle recognizes the project
.\gradlew tasks --group=build

# You should see:
# - compileKotlinWindowsNative
# - cinteropWindowsBluetoothWindowsNative
# - linkReleaseSharedWindowsNative
# - buildWindowsNativeDll
```

### 2. Build the Native DLL

```bash
# Full build with dependencies
.\gradlew :nioxplugin:buildWindowsNativeDll

# Or just link the DLL
.\gradlew :nioxplugin:linkReleaseSharedWindowsNative
```

### 3. Locate the Output

```bash
# Primary output location
nioxplugin\build\outputs\windows\NioxCommunicationPlugin.dll

# Alternative location (before copy task)
nioxplugin\build\bin\windowsNative\releaseShared\NioxCommunicationPlugin.dll
```

### 4. Verify the DLL

```bash
# Check DLL info (PowerShell)
Get-Item nioxplugin\build\outputs\windows\NioxCommunicationPlugin.dll | Select-Object Name, Length, LastWriteTime

# Check DLL exports (requires Visual Studio tools)
dumpbin /EXPORTS nioxplugin\build\outputs\windows\NioxCommunicationPlugin.dll

# Or use objdump from MinGW
objdump -p nioxplugin\build\outputs\windows\NioxCommunicationPlugin.dll | Select-String "export"
```

## Expected Build Output

### Successful Build
```
> Task :nioxplugin:cinteropWindowsBluetoothWindowsNative
> Task :nioxplugin:compileKotlinWindowsNative
> Task :nioxplugin:linkReleaseSharedWindowsNative
> Task :nioxplugin:buildWindowsNativeDll

BUILD SUCCESSFUL in 45s
```

### Expected File Size
- **DLL Size:** ~500KB - 1MB (depending on optimizations)
- **Debug DLL:** Larger (~2-3MB with debug symbols)

## Testing the DLL

### Test 1: Load Test (C#)

Create a simple C# console app to test DLL loading:

```csharp
// LoadTest.cs
using System;
using System.Runtime.InteropServices;

class Program
{
    [DllImport("NioxCommunicationPlugin.dll", CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr createNioxCommunicationPlugin();

    static void Main()
    {
        try
        {
            Console.WriteLine("Attempting to load DLL...");
            var plugin = createNioxCommunicationPlugin();

            if (plugin != IntPtr.Zero)
            {
                Console.WriteLine("✅ SUCCESS: DLL loaded and plugin created!");
                Console.WriteLine($"Plugin handle: 0x{plugin:X}");
            }
            else
            {
                Console.WriteLine("❌ FAIL: Plugin creation returned null");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"❌ ERROR: {ex.Message}");
        }
    }
}

// Compile and run:
// csc LoadTest.cs
// LoadTest.exe
```

### Test 2: Bluetooth State Test (C++)

Create a C++ test application:

```cpp
// BluetoothTest.cpp
#include <windows.h>
#include <iostream>

typedef void* (*CreatePluginFunc)();
typedef int (*CheckBluetoothStateFunc)(void*);

int main() {
    HMODULE dll = LoadLibraryA("NioxCommunicationPlugin.dll");
    if (!dll) {
        std::cerr << "Failed to load DLL. Error: " << GetLastError() << std::endl;
        return 1;
    }

    std::cout << "✅ DLL loaded successfully" << std::endl;

    auto createPlugin = (CreatePluginFunc)GetProcAddress(dll, "createNioxCommunicationPlugin");
    auto checkState = (CheckBluetoothStateFunc)GetProcAddress(dll, "checkBluetoothState");

    if (!createPlugin || !checkState) {
        std::cerr << "Failed to get function addresses" << std::endl;
        FreeLibrary(dll);
        return 1;
    }

    std::cout << "✅ Functions found" << std::endl;

    void* plugin = createPlugin();
    if (!plugin) {
        std::cerr << "Failed to create plugin" << std::endl;
        FreeLibrary(dll);
        return 1;
    }

    std::cout << "✅ Plugin created" << std::endl;

    // Note: This won't work directly because checkBluetoothState is a suspend function
    // You'll need to export a blocking wrapper function
    // int state = checkState(plugin);
    // std::cout << "Bluetooth State: " << state << std::endl;

    FreeLibrary(dll);
    return 0;
}

// Compile:
// g++ BluetoothTest.cpp -o BluetoothTest.exe
```

### Test 3: Dependency Check

```bash
# Check DLL dependencies (PowerShell with Visual Studio tools)
dumpbin /DEPENDENTS nioxplugin\build\outputs\windows\NioxCommunicationPlugin.dll

# Should show:
# - KERNEL32.dll
# - Bthprops.cpl (or similar Bluetooth DLLs)
# - msvcrt.dll (C runtime)
```

### Test 4: Symbol Check

```bash
# Check exported symbols
objdump -T nioxplugin\build\outputs\windows\NioxCommunicationPlugin.dll

# Should show symbols like:
# - createNioxCommunicationPlugin
# - (Kotlin runtime symbols)
```

## Troubleshooting

### Build Errors

#### Error: "Cannot find bluetoothapis.h"

**Cause:** Windows SDK headers not found

**Solutions:**
1. Install Visual Studio Build Tools with Windows SDK
2. Install Windows SDK standalone
3. Set environment variable:
   ```bash
   set INCLUDE=C:\Program Files (x86)\Windows Kits\10\Include\10.0.xxxxx.0\um;%INCLUDE%
   ```

#### Error: "Undefined reference to BluetoothFindFirstRadio"

**Cause:** Linker cannot find Bluetooth libraries

**Solution:** Verify linkerOpts in [build.gradle.kts](nioxplugin/build.gradle.kts:59):
```kotlin
linkerOpts("-lBthprops", "-lKernel32")
```

#### Error: "cinterop task failed"

**Cause:** C interop configuration issue

**Solution:** Check [windowsBluetooth.def](nioxplugin/src/nativeInterop/cinterop/windowsBluetooth.def):
```
headers = windows.h bluetoothapis.h
headerFilter = bluetoothapis.h
compilerOpts.mingw = -DUNICODE -D_UNICODE
linkerOpts.mingw = -lBthprops -lKernel32
```

### Runtime Errors

#### Error: "DLL not found"

**Cause:** DLL not in PATH or same directory as executable

**Solutions:**
1. Copy DLL to same directory as your app
2. Add DLL directory to PATH
3. Use absolute path in DllImport

#### Error: "Entry point not found"

**Cause:** Function name mismatch or calling convention wrong

**Solutions:**
1. Check function name is exact: `createNioxCommunicationPlugin`
2. Verify calling convention: `CallingConvention.Cdecl`
3. Check DLL exports: `dumpbin /EXPORTS NioxCommunicationPlugin.dll`

#### Error: "Access violation" or crash

**Cause:** Incorrect P/Invoke signature or calling suspended function directly

**Solutions:**
1. Suspend functions cannot be called directly from C/C++
2. Need to export blocking wrapper functions
3. Check pointer handling and memory management

## Verifying Bluetooth Functionality

### Manual Test on Windows

1. **Check Bluetooth Adapter:**
   - Open Settings > Bluetooth & devices
   - Ensure Bluetooth is ON
   - Make devices discoverable

2. **Expected Behavior:**
   - `checkBluetoothState()` should return `ENABLED` (0)
   - `scanForDevices()` should find nearby devices
   - NIOX PRO devices should be identified by name

3. **Test Scenarios:**
   - ✅ Bluetooth ON → Returns ENABLED
   - ✅ Bluetooth OFF → Returns DISABLED
   - ✅ No adapter → Returns UNSUPPORTED
   - ✅ Scan with devices → Returns device list
   - ✅ Scan without devices → Returns empty list

## Build Script

### Complete Build Script (PowerShell)

Create `build-and-test-dll.ps1`:

```powershell
# Build and Test Windows Native DLL
Write-Host "Building Windows Native DLL..." -ForegroundColor Cyan

# Clean previous build
.\gradlew clean

# Build DLL
.\gradlew :nioxplugin:buildWindowsNativeDll

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Build successful!" -ForegroundColor Green

    # Check output
    $dllPath = "nioxplugin\build\outputs\windows\NioxCommunicationPlugin.dll"
    if (Test-Path $dllPath) {
        $dllInfo = Get-Item $dllPath
        Write-Host "📦 DLL Info:" -ForegroundColor Yellow
        Write-Host "   Location: $($dllInfo.FullName)"
        Write-Host "   Size: $([math]::Round($dllInfo.Length / 1KB, 2)) KB"
        Write-Host "   Modified: $($dllInfo.LastWriteTime)"

        # Try to load DLL (basic test)
        try {
            [System.Reflection.Assembly]::LoadFile($dllInfo.FullName) | Out-Null
            Write-Host "✅ DLL loads successfully (basic test)" -ForegroundColor Green
        } catch {
            Write-Host "⚠️  DLL load test: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "   (This is expected for native DLLs without .NET metadata)" -ForegroundColor Gray
        }
    } else {
        Write-Host "❌ DLL not found at expected location" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Build failed!" -ForegroundColor Red
}
```

## Comparison Test

### Compare JAR vs Native DLL

```powershell
# Build both implementations
.\gradlew :nioxplugin:buildWindowsJar
.\gradlew :nioxplugin:buildWindowsNativeDll

# Compare sizes
$jarSize = (Get-Item "nioxplugin\build\outputs\windows\niox-communication-plugin-windows-1.0.0.jar").Length
$dllSize = (Get-Item "nioxplugin\build\outputs\windows\NioxCommunicationPlugin.dll").Length

Write-Host "Size Comparison:"
Write-Host "  JAR:        $([math]::Round($jarSize / 1KB, 2)) KB"
Write-Host "  Native DLL: $([math]::Round($dllSize / 1KB, 2)) KB"
Write-Host "  Difference: $([math]::Round(($jarSize - $dllSize) / 1KB, 2)) KB"
```

## Next Steps

After successful build and testing:

1. ✅ **Integrate into your application**
   - Copy DLL to your app's directory
   - Add P/Invoke declarations (C#) or LoadLibrary calls (C++)

2. ✅ **Test with real Bluetooth devices**
   - Test with NIOX PRO devices
   - Verify device filtering works
   - Check device information accuracy

3. ✅ **Deploy to production**
   - Include DLL in installer/package
   - Add error handling for missing Bluetooth
   - Handle permissions and security

4. ✅ **Monitor and optimize**
   - Track scan performance
   - Monitor memory usage
   - Collect error reports

## Success Criteria

Your Windows Native DLL implementation is successful when:

- ✅ DLL builds without errors
- ✅ DLL loads in test applications
- ✅ Bluetooth state detection works
- ✅ Device scanning returns results
- ✅ NIOX device filtering works
- ✅ Memory management is clean (no leaks)
- ✅ No crashes or access violations
- ✅ Performance is acceptable (< 15s scans)

---

**Need Help?**
- See [WINDOWS_NATIVE_DLL_GUIDE.md](docs/WINDOWS_NATIVE_DLL_GUIDE.md) for detailed usage
- See [WINDOWS_NATIVE_DLL_IMPLEMENTATION_SUMMARY.md](docs/WINDOWS_NATIVE_DLL_IMPLEMENTATION_SUMMARY.md) for technical details
- Check GitHub issues or contact the Niox development team
