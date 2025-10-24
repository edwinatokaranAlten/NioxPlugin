# Using Windows JAR in WinUI App via Process Execution

## Prerequisites

1. Build the JAR:
   ```powershell
   .\build-windows-jar.ps1
   ```

2. Ensure JRE 11+ is installed on target machines

## Setup in WinUI Project

1. Copy JAR to your project:
   ```
   YourWinUIProject/
   ├── JavaLibs/
   │   └── niox-communication-plugin-windows-1.0.0.jar
   ```

2. Add to project file (.csproj):
   ```xml
   <ItemGroup>
     <Content Include="JavaLibs\niox-communication-plugin-windows-1.0.0.jar">
       <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
     </Content>
   </ItemGroup>
   ```

## C# Wrapper Class

Create a wrapper to execute Java commands:

```csharp
using System;
using System.Diagnostics;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;

namespace YourApp.Bluetooth
{
    public class NioxBluetoothPlugin
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
            public string Name { get; set; }
            public string Address { get; set; }
            public bool IsNioxDevice { get; set; }
            public string SerialNumber { get; set; }
        }

        public class ScanResult
        {
            public BluetoothDevice[] Devices { get; set; }
        }

        /// <summary>
        /// Check Bluetooth adapter state
        /// </summary>
        public static async Task<BluetoothState> CheckBluetoothStateAsync()
        {
            try
            {
                string output = await RunJavaCommandAsync("checkBluetooth");

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

        /// <summary>
        /// Scan for Bluetooth devices
        /// </summary>
        /// <param name="durationMs">Scan duration in milliseconds (default: 10000)</param>
        public static async Task<BluetoothDevice[]> ScanDevicesAsync(int durationMs = 10000)
        {
            try
            {
                string output = await RunJavaCommandAsync($"scanDevices {durationMs}");

                var result = JsonSerializer.Deserialize<ScanResult>(output);
                return result?.Devices ?? Array.Empty<BluetoothDevice>();
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error scanning devices: {ex.Message}");
                return Array.Empty<BluetoothDevice>();
            }
        }

        /// <summary>
        /// Execute Java JAR command and return output
        /// </summary>
        private static async Task<string> RunJavaCommandAsync(string command)
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

## Usage in WinUI

```csharp
using YourApp.Bluetooth;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

public sealed partial class MainPage : Page
{
    public MainPage()
    {
        this.InitializeComponent();
        _ = CheckBluetoothAsync();
    }

    private async Task CheckBluetoothAsync()
    {
        try
        {
            // Check Bluetooth state
            var state = await NioxBluetoothPlugin.CheckBluetoothStateAsync();

            switch (state)
            {
                case NioxBluetoothPlugin.BluetoothState.ENABLED:
                    StatusTextBlock.Text = "✅ Bluetooth is enabled";
                    await ScanForDevicesAsync();
                    break;

                case NioxBluetoothPlugin.BluetoothState.DISABLED:
                    StatusTextBlock.Text = "❌ Bluetooth is disabled";
                    break;

                case NioxBluetoothPlugin.BluetoothState.UNSUPPORTED:
                    StatusTextBlock.Text = "⚠️ Bluetooth not supported";
                    break;

                default:
                    StatusTextBlock.Text = "❓ Bluetooth state unknown";
                    break;
            }
        }
        catch (Exception ex)
        {
            StatusTextBlock.Text = $"Error: {ex.Message}";
        }
    }

    private async Task ScanForDevicesAsync()
    {
        try
        {
            StatusTextBlock.Text = "🔍 Scanning for devices...";

            var devices = await NioxBluetoothPlugin.ScanDevicesAsync(10000);

            StatusTextBlock.Text = $"Found {devices.Length} device(s)";

            DeviceListView.Items.Clear();
            foreach (var device in devices)
            {
                string deviceInfo = $"{device.Name} - {device.Address}";
                if (device.IsNioxDevice)
                {
                    deviceInfo += $" [NIOX: {device.SerialNumber}]";
                }
                DeviceListView.Items.Add(deviceInfo);
            }
        }
        catch (Exception ex)
        {
            StatusTextBlock.Text = $"Scan error: {ex.Message}";
        }
    }

    private async void ScanButton_Click(object sender, RoutedEventArgs e)
    {
        await ScanForDevicesAsync();
    }
}
```

## XAML Example

```xml
<Page
    x:Class="YourApp.MainPage"
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">

    <StackPanel Padding="20" Spacing="10">
        <TextBlock
            x:Name="StatusTextBlock"
            Text="Checking Bluetooth..."
            FontSize="16"/>

        <Button
            x:Name="ScanButton"
            Content="Scan for Devices"
            Click="ScanButton_Click"/>

        <ListView
            x:Name="DeviceListView"
            Header="Devices Found"
            Height="400"/>
    </StackPanel>
</Page>
```

## Rebuild JAR

After adding the Main class, rebuild the JAR:

```powershell
.\build-windows-jar.ps1
```

Now the JAR will have the Main-Class manifest and can be executed as:
```bash
java -jar niox-communication-plugin-windows-1.0.0.jar checkBluetooth
java -jar niox-communication-plugin-windows-1.0.0.jar scanDevices 10000
```

## Comparison: JAR vs Native DLL

| Feature | JAR (Process Execution) | Native DLL (P/Invoke) |
|---------|-------------------------|------------------------|
| JVM Required | ✅ Yes (JRE 11+) | ❌ No |
| Size | ~2MB + JRE | ~500KB |
| Startup Time | Slower (JVM startup) | Instant |
| Integration | Process execution | Direct P/Invoke |
| Complexity | Higher | Lower |
| **Recommendation** | Use if JRE already installed | **Better for WinUI apps** |

## Recommendation

**For WinUI apps, use the Native DLL** (see [WINUI_NATIVE_DLL_USAGE.md](WINUI_NATIVE_DLL_USAGE.md))
- No JVM dependency
- Faster startup
- Simpler integration
- Smaller footprint

Use JAR only if:
- JRE is already bundled with your app
- You need cross-platform JVM compatibility
- You prefer not to use P/Invoke
