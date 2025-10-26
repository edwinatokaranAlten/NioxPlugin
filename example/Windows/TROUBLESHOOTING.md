# Windows WinUI App - DLL Loading Troubleshooting Guide

## Error: "Unable to load DLL 'NioxCommunicationPlugin.dll'"

This guide will help you resolve DLL loading issues in the NIOX Bluetooth WinUI application.

---

## Quick Checklist

✅ **Step 1: Verify DLL is copied to output directory**
- The DLL should be in: `bin/x64/Debug/net8.0-windows10.0.19041.0/win-x64/`
- Check that the `.csproj` file has the correct `<Content>` entry

✅ **Step 2: Ensure you're building for x64 architecture**
- The DLL is 64-bit (x64)
- Your app must also be built for x64, not x86 or ARM64

✅ **Step 3: Check for missing runtime dependencies**
- MinGW DLLs might be required
- Visual C++ Redistributable might be needed

---

## Detailed Solutions

### Solution 1: Rebuild on Windows (Recommended)

The DLL was cross-compiled on macOS using MinGW. For best results, rebuild it on Windows:

**Option A: Use Windows with MinGW**
```bash
# On Windows with MinGW installed
./gradlew linkReleaseSharedWindowsNative
```

**Option B: Use Visual Studio (if you convert to C++/CLI)**
This would require rewriting the native code, but gives better Windows integration.

### Solution 2: Add Missing MinGW Runtime DLLs

If using the cross-compiled DLL, you may need MinGW runtime libraries:

1. Download MinGW-w64 runtime DLLs:
   - `libgcc_s_seh-1.dll`
   - `libstdc++-6.dll`
   - `libwinpthread-1.dll`

2. Place them in the same directory as your app executable

### Solution 3: Use Dependency Walker (Windows Only)

On Windows, use a tool to check DLL dependencies:

1. Download [Dependencies](https://github.com/lucasg/Dependencies) (modern alternative to Dependency Walker)
2. Open `NioxCommunicationPlugin.dll` in the tool
3. Check for any missing dependencies (shown in red)
4. Install/copy the missing DLLs

### Solution 4: Verify Project Configuration

Check your `NioxBluetoothApp.csproj`:

```xml
<ItemGroup>
    <Content Include="Libraries\NioxCommunicationPlugin.dll">
        <CopyToOutputDirectory>Always</CopyToOutputDirectory>
    </Content>
</ItemGroup>
```

### Solution 5: Build Configuration

Ensure you're building for the correct platform:

1. Open Solution in Visual Studio
2. Go to Build > Configuration Manager
3. Set "Active solution platform" to **x64**
4. Ensure the project is checked and also set to **x64**

---

## Alternative: Use Windows JVM Implementation

Instead of the native DLL, you can use the JVM-based implementation:

### Benefits:
- No native DLL dependencies
- Cross-platform Java code
- Uses IKVM to run on .NET

### Steps:

1. **Copy the JAR file instead:**
   ```bash
   cp nioxplugin/build/libs/niox-communication-plugin-windows-1.0.0.jar \
      example/Windows/NioxBluetoothApp/Libraries/
   ```

2. **Update the C# code to use IKVM** (already included in your project)

3. **Modify BluetoothService.cs** to call Java classes via IKVM instead of P/Invoke

---

## Testing DLL Loading

Add this test code to check DLL loading before initializing the Bluetooth service:

```csharp
// In MainWindow.xaml.cs, before InitializeBluetoothService()
private void TestDllLoading()
{
    try
    {
        string appDir = AppDomain.CurrentDomain.BaseDirectory;
        string dllPath = System.IO.Path.Combine(appDir, "NioxCommunicationPlugin.dll");

        StatusBarText.Text = $"Checking DLL at: {dllPath}";

        if (!System.IO.File.Exists(dllPath))
        {
            StatusBarText.Text = "ERROR: DLL not found!";
            return;
        }

        // Try to load it
        IntPtr handle = LoadLibrary(dllPath);
        if (handle == IntPtr.Zero)
        {
            int errorCode = Marshal.GetLastWin32Error();
            StatusBarText.Text = $"ERROR: LoadLibrary failed with code 0x{errorCode:X}";
        }
        else
        {
            StatusBarText.Text = "DLL loaded successfully!";
        }
    }
    catch (Exception ex)
    {
        StatusBarText.Text = $"ERROR: {ex.Message}";
    }
}

[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
private static extern IntPtr LoadLibrary(string lpFileName);
```

---

## Common Error Codes

| Error Code | Meaning | Solution |
|------------|---------|----------|
| 0x8007007E | Module not found | DLL or its dependencies are missing |
| 0x800700C1 | Not a valid Win32 application | Architecture mismatch (x86 vs x64) |
| 0x80070002 | File not found | DLL path is incorrect |

---

## Debug Output

The updated `BluetoothService.cs` now includes debug output. To view it:

1. Run the app from Visual Studio (F5)
2. Check the **Output** window
3. Look for messages like:
   - "Looking for DLL at: ..."
   - "DLL exists: True/False"
   - "DLL preload failed: ..."

---

## Best Practice: Deploy DLL Correctly

For final deployment:

1. **For development:** Keep DLL in `Libraries/` folder with `<CopyToOutputDirectory>Always</CopyToOutputDirectory>`

2. **For MSIX package:** The DLL will be automatically included in the app package

3. **For standalone EXE:** Ensure DLL is in the same folder as the .exe

---

## Need More Help?

1. Check Visual Studio Output window for detailed error messages
2. Use Process Monitor to see which DLLs Windows is trying to load
3. Try building on an actual Windows machine (not macOS)
4. Consider using the JVM/IKVM approach instead of native DLL

---

## Current Status

✅ DLL copied to `Libraries/` folder
✅ Project configured to copy DLL to output
✅ Debug logging added to BluetoothService
⚠️ **Next:** Test on Windows machine to check for runtime dependencies
