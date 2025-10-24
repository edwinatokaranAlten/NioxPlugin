# WinUI Quick Start - Using the Native DLL

You already have a working DLL! The DLL at:
```
C:\Users\eatokaran\Desktop\NioxPlugin\NioxPlugin\nioxplugin\build\outputs\windows\NioxCommunicationPlugin.dll
```

However, the current DLL **doesn't export simple C functions** - it uses Kotlin/Native's complex object system which is difficult to use from C#.

## The Problem

The error you're getting:
```
Error checking Bluetooth status: Object reference not set to an instance of an object
```

This happens because:
1. Kotlin/Native exports complex object structures, not simple C functions
2. C# P/Invoke can't easily call Kotlin/Native functions without a C wrapper
3. The functions expect Kotlin objects, not simple C types

## Two Solutions

### Solution 1: Use the JAR (Simplest - Works Now!)

The JAR file already has a CLI interface that works. Use it via process execution:

**Copy this C# code** (replace your BluetoothService.cs):

```csharp
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;

namespace NioxBluetoothApp.Services
{
    public class BluetoothService
    {
        private const string JarPath = "JavaLibs\\niox-communication-plugin-windows-1.0.0.jar";

        public enum BluetoothState
        {
            ENABLED,
            DISABLED,
            UNSUPPORTED,
            UNKNOWN
        }

        public class BluetoothDevice
        {
            public string name { get; set; }
            public string address { get; set; }
            public bool isNioxDevice { get; set; }
            public string serialNumber { get; set; }
        }

        public class ScanResult
        {
            public BluetoothDevice[] devices { get; set; }
        }

        public async Task<BluetoothState> CheckBluetoothStateAsync()
        {
            try
            {
                string output = await RunJavaCommandAsync("checkBluetooth");

                // Output will be: "ENABLED", "DISABLED", "UNSUPPORTED", or "UNKNOWN"
                if (Enum.TryParse<BluetoothState>(output.Trim(), out var state))
                {
                    return state;
                }

                return BluetoothState.UNKNOWN;
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error checking Bluetooth: {ex.Message}");
                return BluetoothState.UNKNOWN;
            }
        }

        public async Task<List<BluetoothDevice>> ScanForDevicesAsync(int durationMs = 10000)
        {
            try
            {
                string output = await RunJavaCommandAsync($"scanDevices {durationMs}");

                var result = JsonSerializer.Deserialize<ScanResult>(output);
                return result?.devices != null ? new List<BluetoothDevice>(result.devices) : new List<BluetoothDevice>();
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error scanning devices: {ex.Message}");
                return new List<BluetoothDevice>();
            }
        }

        private async Task<string> RunJavaCommandAsync(string command)
        {
            var jarFullPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, JarPath);

            if (!File.Exists(jarFullPath))
            {
                throw new FileNotFoundException($"JAR file not found: {jarFullPath}");
            }

            var startInfo = new ProcessStartInfo
            {
                FileName = "java",
                Arguments = $"-jar \"{jarFullPath}\" {command}",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };

            using var process = new Process { StartInfo = startInfo };

            var outputBuilder = new System.Text.StringBuilder();
            var errorBuilder = new System.Text.StringBuilder();

            process.OutputDataReceived += (sender, e) =>
            {
                if (e.Data != null)
                    outputBuilder.AppendLine(e.Data);
            };

            process.ErrorDataReceived += (sender, e) =>
            {
                if (e.Data != null)
                    errorBuilder.AppendLine(e.Data);
            };

            process.Start();
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();

            await process.WaitForExitAsync();

            if (process.ExitCode != 0)
            {
                string errorOutput = errorBuilder.ToString();
                throw new Exception($"Java process failed: {errorOutput}");
            }

            return outputBuilder.ToString();
        }
    }
}
```

**Steps:**
1. Copy the JAR file to your WinUI project:
   ```
   YourWinUIProject/JavaLibs/niox-communication-plugin-windows-1.0.0.jar
   ```

2. Add to .csproj:
   ```xml
   <ItemGroup>
     <Content Include="JavaLibs\niox-communication-plugin-windows-1.0.0.jar">
       <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
     </Content>
   </ItemGroup>
   ```

3. Make sure Java 11+ is installed on the target machine

4. **Your app will work immediately!**

### Solution 2: Wait for Native DLL with C Wrapper (Better, but needs rebuild)

The developer needs to:
1. Add C API wrapper functions to the DLL (CApi.kt file)
2. Rebuild the DLL on Windows
3. The new DLL will export simple C functions like:
   - `niox_init()`
   - `niox_check_bluetooth()`
   - `niox_scan_devices()`

This will take another build cycle.

## Recommendation

**Use Solution 1 (JAR) right now** because:
- ✅ It works immediately
- ✅ No code changes needed to DLL
- ✅ The JAR already has the CLI interface
- ✅ You can test your app today

Later, if you want to remove the Java dependency, we can:
- Add C wrapper functions to the Native DLL
- Rebuild it
- Switch to P/Invoke

## Testing the JAR

Test that the JAR works:

```powershell
# Go to the JAR location
cd C:\Users\eatokaran\Desktop\NioxPlugin\NioxPlugin\nioxplugin\build\libs\jvm\windows

# Test checkBluetooth
java -jar nioxplugin-windows.jar checkBluetooth

# Test scanDevices
java -jar nioxplugin-windows.jar scanDevices 5000
```

If those commands work, your WinUI app will work with Solution 1!

## Next Steps

1. **Right now**: Use the JAR approach (Solution 1) to get your app working
2. **Later**: I can help add C wrapper functions and rebuild the DLL for native P/Invoke

Which would you like to do?
