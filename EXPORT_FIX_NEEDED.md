# 🔧 DLL Export Issue - Functions Not Found

## Current Status

✅ DLL loads successfully
❌ **Exported functions not found** (name mangling issue)

## The Problem

The Kotlin/Native compiler is NOT exporting the functions with their C names. Even though we use `@CName("niox_init")`, the actual export names in the DLL are mangled or not exported at all.

### Diagnostic Output:
```
✅ LoadLibrary SUCCESS!
❌ niox_init - NOT FOUND
❌ niox_check_bluetooth - NOT FOUND
❌ niox_scan_devices - NOT FOUND
...
```

## Root Cause

Kotlin/Native's `@CName` annotation **doesn't automatically create C-linkage exports** for DLLs. It only affects the function name within Kotlin's internal symbol table.

To properly export C functions from a Kotlin/Native DLL, we need:
1. `@CName` annotation (already have this ✅)
2. **Module export configuration** (missing ❌)
3. **Proper linker flags** (partially added)

## Solutions (Choose One)

### **Solution 1: Rebuild DLL on Windows (Recommended)**

This ensures you get a native Windows build with proper exports.

**Steps:**

1. **On Windows machine**, install MinGW-w64:
   ```bash
   # Download from: https://www.mingw-w64.org/
   # Or use MSYS2: https://www.msys2.org/
   ```

2. **Set environment variables:**
   ```bash
   set MINGW_HOME=C:\msys64\mingw64
   set PATH=%MINGW_HOME%\bin;%PATH%
   ```

3. **Rebuild the DLL:**
   ```bash
   cd C:\path\to\NIOXSDKPlugin
   gradlew.bat clean
   gradlew.bat linkReleaseSharedWindowsNative
   ```

4. **Copy the new DLL:**
   ```bash
   copy nioxplugin\build\bin\windowsNative\releaseShared\NioxCommunicationPlugin.dll ^
        example\Windows\NioxBluetoothApp\Libraries\
   ```

5. **Verify exports with dumpbin:**
   ```bash
   dumpbin /EXPORTS Libraries\NioxCommunicationPlugin.dll
   ```

   You should see:
   ```
   niox_init
   niox_check_bluetooth
   niox_scan_devices
   niox_free_string
   niox_cleanup
   niox_version
   ```

---

### **Solution 2: Add .def File for Exports**

Create a module definition file to explicitly export functions.

**Create: `nioxplugin/src/windowsNativeMain/NioxCommunicationPlugin.def`**
```def
LIBRARY NioxCommunicationPlugin
EXPORTS
    niox_init
    niox_check_bluetooth
    niox_scan_devices
    niox_free_string
    niox_cleanup
    niox_version
```

**Update `build.gradle.kts`:**
```kotlin
binaries {
    sharedLib {
        baseName = "NioxCommunicationPlugin"
        linkerOpts(
            "-lBthprops",
            "-lKernel32",
            "-Wl,--output-def,NioxCommunicationPlugin.def"  // Add this
        )
    }
}
```

Then rebuild.

---

### **Solution 3: Use JNA/JVM Implementation Instead**

**Alternative approach:** Use the JVM-based implementation which uses JNA for Bluetooth access.

**Advantages:**
- No C export issues
- Already built and working
- Uses standard Windows Bluetooth API via JNA

**Steps:**

1. **Copy the JAR instead of DLL:**
   ```bash
   copy nioxplugin\build\libs\niox-communication-plugin-windows-1.0.0.jar ^
        example\Windows\NioxBluetoothApp\Libraries\
   ```

2. **Update C# code to use IKVM:**

   Instead of P/Invoke, call Java classes directly:

   ```csharp
   // Add IKVM references
   using IKVM.Runtime;
   using java.lang;

   // Load Java class
   var pluginClass = Class.forName("com.niox.nioxplugin.WindowsNioxCommunicationPlugin");
   var plugin = pluginClass.newInstance();

   // Call methods
   var method = pluginClass.getMethod("checkBluetoothState");
   var result = method.invoke(plugin);
   ```

3. **Benefits:**
   - No DLL export issues
   - Pure managed code
   - Cross-platform friendly

---

### **Solution 4: Quick Test - Try Mangled Names**

**Before rebuilding**, let's test if the functions ARE exported but with different names.

**Run the enhanced diagnostics:**
1. Rebuild the C# app with the new `DllExportChecker.cs`
2. Run "DLL Diagnostics" button again
3. Look for any exports containing "niox", "init", "bluetooth", etc.

The export checker will test many possible name patterns:
- `niox_init`
- `_niox_init` (MinGW prefix)
- `Kotlin_com_niox_nioxplugin_initPlugin`
- `kfun:com.niox.nioxplugin#initPlugin`
- etc.

If it finds any, we can update `BluetoothService.cs` to use the actual names.

---

## Immediate Next Steps

### On Your Windows Machine:

1. **Rebuild the C# app** (to get the new `DllExportChecker`)
   ```
   Build → Rebuild Solution
   ```

2. **Run Diagnostics Again**
   - Click "Run DLL Diagnostics"
   - Look for "=== DLL Export Analysis ===" section
   - See if it finds ANY exports

3. **Based on results:**

   **If exports ARE found with different names:**
   - Update `BluetoothService.cs` with the actual names

   **If NO exports found:**
   - Need to rebuild DLL on Windows (Solution 1)
   - Or switch to JVM/IKVM approach (Solution 3)

---

## Understanding the Issue

### What `@CName` Does:
```kotlin
@CName("niox_init")
fun initPlugin(): Int { }
```

This tells Kotlin/Native:
✅ "Internal symbol should be named `niox_init`"
❌ Does NOT guarantee C linkage export to DLL

### What We Need:
```c
extern "C" __declspec(dllexport) int niox_init();
```

This requires either:
1. Building on Windows with proper toolchain
2. Using `.def` file for exports
3. Using different Kotlin/Native compiler flags

---

## Verification Commands (Windows)

Once DLL is rebuilt, verify exports:

```bash
# Using Visual Studio's dumpbin
dumpbin /EXPORTS NioxCommunicationPlugin.dll

# Using Dependencies.exe (free tool)
Dependencies.exe NioxCommunicationPlugin.dll

# Using PowerShell
dumpbin /EXPORTS NioxCommunicationPlugin.dll | Select-String "niox"
```

Expected output:
```
ordinal hint RVA      name
      1    0 00001000 niox_init
      2    1 00001100 niox_check_bluetooth
      3    2 00001200 niox_scan_devices
      4    3 00001300 niox_free_string
      5    4 00001400 niox_cleanup
      6    5 00001500 niox_version
```

---

## Files Modified

I've already made these improvements:

1. ✅ **DllExportChecker.cs** - Tests many name patterns to find actual exports
2. ✅ **MainWindow.xaml.cs** - Updated diagnostics to include export analysis
3. ✅ **build.gradle.kts** - Added `--export-all-symbols` flag
4. ⏳ **Needs rebuild on Windows** to take effect

---

## Current State Summary

| Item | Status | Next Action |
|------|--------|-------------|
| DLL copies to output | ✅ Fixed | None |
| DLL loads successfully | ✅ Working | None |
| Functions exported | ❌ **Not found** | **Rebuild on Windows** |
| Alternative ready | ✅ JVM/IKVM available | Can switch if needed |

---

## Decision Point

**Choose your path:**

🔨 **Path A:** Rebuild DLL on Windows with proper exports (native performance)
☕ **Path B:** Switch to JVM/IKVM implementation (easier, no export issues)

Both will work for your NIOX Bluetooth scanning needs!

---

**Next Step:** Run the updated diagnostics to see the export analysis results!
