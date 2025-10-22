# C# .NET MAUI Integration Guide
## Niox Communication Plugin for Windows

This comprehensive guide demonstrates how to integrate the Niox Communication Plugin Windows JAR library into .NET MAUI C# applications for Bluetooth device communication.

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Method 1: IKVM.NET Integration (Recommended)](#method-1-using-ikvmnet-recommended)
4. [Method 2: Process Execution (Alternative)](#method-2-using-process-execution-alternative)
5. [Building the Windows JAR](#building-the-windows-jar)
6. [Platform Configuration](#platform-specific-configuration)
7. [API Reference](#api-reference)
8. [Troubleshooting](#troubleshooting)
9. [Performance & Best Practices](#performance-notes)

---

## Overview

The Niox Communication Plugin provides Windows Bluetooth functionality through a compiled JAR artifact that can be integrated into .NET MAUI applications using two approaches:

- **IKVM.NET**: Direct Java-to-.NET bytecode translation (recommended for production)
- **Process Execution**: CLI-based communication via standard I/O (fallback option)

### Architecture

```
.NET MAUI App (C#)
    ↓
IKVM.NET / Process Bridge
    ↓
Niox Plugin JAR (Kotlin/JVM)
    ↓
Windows Bluetooth Classic API (Bthprops.cpl)
```

---

## Prerequisites

### Required Software
- **.NET SDK:** 8.0 or higher
- **MAUI Workload:** `dotnet workload install maui`
- **JDK:** Version 11 or higher (required on target Windows machines)
- **Niox Plugin JAR:** `niox-communication-plugin-windows-1.0.0.jar`

### Verify Installation
```bash
# Check .NET version
dotnet --version

# Check MAUI workload
dotnet workload list

# Check Java version
java -version
```

---

---

## Method 1: Using IKVM.NET (Recommended)

IKVM.NET translates Java bytecode to .NET IL (Intermediate Language), allowing seamless integration of Java libraries into .NET applications without requiring a JVM at runtime.

### Benefits
- ✅ No JVM required at runtime
- ✅ Native .NET performance
- ✅ Type-safe API access
- ✅ Full IntelliSense support in Visual Studio
- ✅ Easier debugging and error handling

### Step 1: Install IKVM.NET Packages

Add IKVM.NET to your MAUI project via NuGet:

```bash
# Install IKVM packages
dotnet add package IKVM --version 8.7.5
dotnet add package IKVM.Maven.Sdk --version 1.6.9
```

Or add directly to your `.csproj`:

```xml
<ItemGroup>
  <PackageReference Include="IKVM" Version="8.7.5" />
  <PackageReference Include="IKVM.Maven.Sdk" Version="1.6.9" />
</ItemGroup>
```

### Step 2: Configure JAR Reference

Add the Niox Plugin JAR as an IKVM reference in your `.csproj`:

```xml
<ItemGroup>
  <!-- Method A: Using IkvmReference (Automatic at build time) -->
  <IkvmReference Include="Libraries\niox-communication-plugin-windows-1.0.0.jar">
    <AssemblyName>NioxPlugin</AssemblyName>
    <AssemblyVersion>1.0.0.0</AssemblyVersion>
    <DisableAutoAssemblyName>true</DisableAutoAssemblyName>
  </IkvmReference>
</ItemGroup>
```

**Alternative:** Manual conversion using ikvmc command:

```bash
# Download ikvmc tool
dotnet tool install -g ikvm

# Convert JAR to DLL
ikvmc -target:library \
      -out:NioxPlugin.dll \
      -version:1.0.0.0 \
      niox-communication-plugin-windows-1.0.0.jar

# Add DLL reference to project
# Then add to .csproj:
# <Reference Include="NioxPlugin">
#   <HintPath>Libraries\NioxPlugin.dll</HintPath>
# </Reference>
```

### Step 3: Create C# Wrapper Service

```csharp
using com.niox.nioxplugin;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace YourMauiApp.Services
{
    /// <summary>
    /// Service wrapper for Niox Bluetooth communication plugin.
    /// Provides async/await-friendly methods for Bluetooth operations.
    /// </summary>
    public class NioxBluetoothService : IDisposable
    {
        private readonly NioxCommunicationPlugin _plugin;
        private bool _disposed = false;

        public NioxBluetoothService()
        {
            // Initialize the Kotlin Multiplatform plugin
            _plugin = NioxCommunicationPluginKt.createNioxCommunicationPlugin();
        }

        /// <summary>
        /// Checks the current Bluetooth adapter state.
        /// </summary>
        /// <returns>Bluetooth state (ENABLED, DISABLED, UNSUPPORTED, UNKNOWN)</returns>
        public async Task<BluetoothState> CheckBluetoothStateAsync()
        {
            return await Task.Run(() =>
            {
                var continuation = new KotlinContinuation<BluetoothState>();
                _plugin.checkBluetoothState(continuation);
                return continuation.GetResult();
            });
        }

        /// <summary>
        /// Scans for Bluetooth devices with optional filtering.
        /// </summary>
        /// <param name="scanDurationMs">Scan duration in milliseconds (default: 10 seconds)</param>
        /// <param name="serviceUuidFilter">Optional service UUID filter (null for all devices)</param>
        /// <returns>List of discovered Bluetooth devices</returns>
        public async Task<List<BluetoothDeviceInfo>> ScanForDevicesAsync(
            long scanDurationMs = 10000,
            string serviceUuidFilter = null)
        {
            return await Task.Run(() =>
            {
                var continuation = new KotlinContinuation<java.util.List>();

                // Call the plugin's scan method with optional filter
                if (serviceUuidFilter != null)
                {
                    _plugin.scanForDevices(scanDurationMs, serviceUuidFilter, continuation);
                }
                else
                {
                    // Scan for all devices (no filter)
                    _plugin.scanForDevices(scanDurationMs, null, continuation);
                }

                var javaList = continuation.GetResult();
                return ConvertJavaListToDeviceInfo(javaList);
            });
        }

        /// <summary>
        /// Scans specifically for Niox devices using the Niox service UUID.
        /// </summary>
        public async Task<List<BluetoothDeviceInfo>> ScanForNioxDevicesAsync(
            long scanDurationMs = 10000)
        {
            var allDevices = await ScanForDevicesAsync(scanDurationMs, serviceUuidFilter: null);
            return allDevices.Where(d => d.IsNioxDevice).ToList();
        }

        /// <summary>
        /// Stops an ongoing Bluetooth scan operation.
        /// </summary>
        public void StopScan()
        {
            _plugin.stopScan();
        }

        /// <summary>
        /// Converts Java List of BluetoothDevice to C# List of BluetoothDeviceInfo
        /// </summary>
        private List<BluetoothDeviceInfo> ConvertJavaListToDeviceInfo(java.util.List javaList)
        {
            var deviceList = new List<BluetoothDeviceInfo>();
            var iterator = javaList.iterator();

            while (iterator.hasNext())
            {
                var device = (BluetoothDevice)iterator.next();
                deviceList.Add(new BluetoothDeviceInfo
                {
                    Name = device.getName() ?? "Unknown Device",
                    Address = device.getAddress(),
                    Rssi = device.getRssi()?.intValue(), // Null on Windows (Classic API limitation)
                    IsNioxDevice = device.isNioxDevice(),
                    SerialNumber = device.getNioxSerialNumber()
                });
            }

            return deviceList;
        }

        public void Dispose()
        {
            if (!_disposed)
            {
                StopScan();
                _disposed = true;
            }
        }
    }

    /// <summary>
    /// C# representation of a Bluetooth device with Niox-specific properties.
    /// </summary>
    public class BluetoothDeviceInfo
    {
        public string Name { get; set; } = string.Empty;
        public string Address { get; set; } = string.Empty;
        public int? Rssi { get; set; } // Signal strength (null on Windows)
        public bool IsNioxDevice { get; set; }
        public string? SerialNumber { get; set; }

        public override string ToString() =>
            $"{Name} ({Address}){(IsNioxDevice ? $" [Niox: {SerialNumber}]" : "")}";
    }

    /// <summary>
    /// Bridges Kotlin suspend functions to C# async/await.
    /// Implements kotlin.coroutines.Continuation for interop.
    /// </summary>
    internal class KotlinContinuation<T> : kotlin.coroutines.Continuation
    {
        private T? _result;
        private Exception? _exception;
        private bool _completed = false;
        private readonly object _lockObj = new object();

        public kotlin.coroutines.CoroutineContext getContext()
        {
            return kotlin.coroutines.EmptyCoroutineContext.INSTANCE;
        }

        public void resumeWith(object result)
        {
            lock (_lockObj)
            {
                try
                {
                    if (result is kotlin.Result kotlinResult)
                    {
                        if (kotlinResult.isSuccess())
                        {
                            _result = (T)kotlinResult.value;
                        }
                        else
                        {
                            var exception = kotlinResult.exceptionOrNull();
                            _exception = new Exception(
                                "Kotlin coroutine failed",
                                exception as Exception);
                        }
                    }
                    else
                    {
                        _result = (T)result;
                    }
                }
                catch (Exception ex)
                {
                    _exception = ex;
                }
                finally
                {
                    _completed = true;
                    System.Threading.Monitor.PulseAll(_lockObj);
                }
            }
        }

        public T GetResult()
        {
            lock (_lockObj)
            {
                while (!_completed)
                {
                    System.Threading.Monitor.Wait(_lockObj);
                }

                if (_exception != null)
                {
                    throw _exception;
                }

                return _result!;
            }
        }
    }
}
```

### Step 4: Use in MAUI Page

```csharp
using Microsoft.Maui.Controls;
using System;
using System.Threading.Tasks;

namespace YourMauiApp
{
    public partial class MainPage : ContentPage
    {
        private readonly BluetoothService bluetoothService;

        public MainPage()
        {
            InitializeComponent();
            bluetoothService = new BluetoothService();
        }

        private async void OnCheckBluetoothClicked(object sender, EventArgs e)
        {
            try
            {
                StatusLabel.Text = "Checking Bluetooth...";
                var state = await bluetoothService.CheckBluetoothStateAsync();
                StatusLabel.Text = $"Bluetooth State: {state}";
            }
            catch (Exception ex)
            {
                StatusLabel.Text = $"Error: {ex.Message}";
            }
        }

        private async void OnScanDevicesClicked(object sender, EventArgs e)
        {
            try
            {
                StatusLabel.Text = "Scanning for devices...";
                DevicesListView.ItemsSource = null;

                // Scan for NIOX devices only (default)
                var devices = await bluetoothService.ScanForDevicesAsync(
                    scanDurationMs: 10000
                );

                DevicesListView.ItemsSource = devices;
                StatusLabel.Text = $"Found {devices.Count} devices";
            }
            catch (Exception ex)
            {
                StatusLabel.Text = $"Error: {ex.Message}";
            }
        }

        private async void OnScanAllDevicesClicked(object sender, EventArgs e)
        {
            try
            {
                StatusLabel.Text = "Scanning for all devices...";
                DevicesListView.ItemsSource = null;

                // Scan for ALL Bluetooth devices (set filter to null)
                var devices = await bluetoothService.ScanForDevicesAsync(
                    scanDurationMs: 10000,
                    serviceUuidFilter: null
                );

                // Filter for NIOX devices
                var nioxDevices = devices.Where(d => d.IsNioxDevice).ToList();

                DevicesListView.ItemsSource = devices;
                StatusLabel.Text = $"Found {devices.Count} total devices ({nioxDevices.Count} NIOX)";
            }
            catch (Exception ex)
            {
                StatusLabel.Text = $"Error: {ex.Message}";
            }
        }

        private void OnStopScanClicked(object sender, EventArgs e)
        {
            bluetoothService.StopScan();
            StatusLabel.Text = "Scan stopped";
        }
    }
}
```

### XAML Layout Example

```xml
<?xml version="1.0" encoding="utf-8" ?>
<ContentPage xmlns="http://schemas.microsoft.com/dotnet/2021/maui"
             xmlns:x="http://schemas.microsoft.com/winfx/2009/xaml"
             x:Class="YourMauiApp.MainPage"
             Title="NIOX Bluetooth Scanner">

    <ScrollView>
        <VerticalStackLayout Padding="20" Spacing="10">

            <Label Text="NIOX Bluetooth Device Scanner"
                   FontSize="24"
                   FontAttributes="Bold"
                   HorizontalOptions="Center" />

            <Button Text="Check Bluetooth State"
                    Clicked="OnCheckBluetoothClicked"
                    BackgroundColor="#0078D4"
                    TextColor="White" />

            <Button Text="Scan for NIOX Devices"
                    Clicked="OnScanDevicesClicked"
                    BackgroundColor="#107C10"
                    TextColor="White" />

            <Button Text="Scan for All Devices"
                    Clicked="OnScanAllDevicesClicked"
                    BackgroundColor="#5E5E5E"
                    TextColor="White" />

            <Button Text="Stop Scan"
                    Clicked="OnStopScanClicked"
                    BackgroundColor="#D83B01"
                    TextColor="White" />

            <Label x:Name="StatusLabel"
                   Text="Ready"
                   FontSize="16"
                   HorizontalOptions="Center"
                   Margin="0,10,0,0" />

            <ListView x:Name="DevicesListView"
                      HeightRequest="400"
                      Margin="0,10,0,0">
                <ListView.ItemTemplate>
                    <DataTemplate>
                        <ViewCell>
                            <StackLayout Padding="10">
                                <Label Text="{Binding Name}"
                                       FontSize="18"
                                       FontAttributes="Bold" />
                                <Label Text="{Binding Address}"
                                       FontSize="14"
                                       TextColor="Gray" />
                                <Label Text="{Binding SerialNumber, StringFormat='Serial: {0}'}"
                                       FontSize="14"
                                       TextColor="Blue"
                                       IsVisible="{Binding IsNioxDevice}" />
                                <Label Text="NIOX Device"
                                       FontSize="12"
                                       TextColor="Green"
                                       FontAttributes="Bold"
                                       IsVisible="{Binding IsNioxDevice}" />
                            </StackLayout>
                        </ViewCell>
                    </DataTemplate>
                </ListView.ItemTemplate>
            </ListView>

        </VerticalStackLayout>
    </ScrollView>

</ContentPage>
```

---

## Method 2: Using Process Execution (Alternative)

If IKVM doesn't work for your use case, you can execute the JAR via process and communicate through standard I/O.

### Step 1: Create Java Wrapper

Create a simple Java wrapper that provides CLI interface:

```java
// NioxCli.java
import com.niox.nioxplugin.*;
import kotlinx.coroutines.*;
import java.util.List;

public class NioxCli {
    public static void main(String[] args) throws Exception {
        if (args.length == 0) {
            System.err.println("Usage: java -jar niox-cli.jar [command]");
            System.exit(1);
        }

        NioxCommunicationPlugin plugin = NioxCommunicationPluginKt.createNioxCommunicationPlugin();

        String command = args[0];

        if ("check".equals(command)) {
            BluetoothState state = (BluetoothState) CoroutinesKt.runBlocking(
                EmptyCoroutineContext.INSTANCE,
                (scope, continuation) -> plugin.checkBluetoothState(continuation)
            );
            System.out.println(state.name());
        }
        else if ("scan".equals(command)) {
            long duration = args.length > 1 ? Long.parseLong(args[1]) : 10000;
            String filter = args.length > 2 ? args[2] : NioxConstants.INSTANCE.getNIOX_SERVICE_UUID();

            List<BluetoothDevice> devices = (List<BluetoothDevice>) CoroutinesKt.runBlocking(
                EmptyCoroutineContext.INSTANCE,
                (scope, continuation) -> plugin.scanForDevices(duration, filter, continuation)
            );

            System.out.println("DEVICE_COUNT:" + devices.size());
            for (BluetoothDevice device : devices) {
                System.out.println(String.format(
                    "DEVICE|%s|%s|%b|%s",
                    device.getName(),
                    device.getAddress(),
                    device.isNioxDevice(),
                    device.getNioxSerialNumber()
                ));
            }
        }
    }
}
```

### Step 2: C# Process Wrapper

```csharp
using System;
using System.Diagnostics;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Linq;

namespace YourMauiApp
{
    public class NioxProcessService
    {
        private readonly string jarPath;
        private readonly string javaPath;

        public NioxProcessService(string jarPath, string javaPath = "java")
        {
            this.jarPath = jarPath;
            this.javaPath = javaPath;
        }

        public async Task<string> CheckBluetoothStateAsync()
        {
            var output = await RunJavaCommandAsync("check");
            return output.Trim();
        }

        public async Task<List<DeviceInfo>> ScanForDevicesAsync(
            long scanDurationMs = 10000,
            string serviceUuidFilter = null)
        {
            var args = serviceUuidFilter != null
                ? $"scan {scanDurationMs} {serviceUuidFilter}"
                : $"scan {scanDurationMs}";

            var output = await RunJavaCommandAsync(args);
            return ParseDevices(output);
        }

        private async Task<string> RunJavaCommandAsync(string arguments)
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = javaPath,
                Arguments = $"-jar \"{jarPath}\" {arguments}",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            using var process = new Process { StartInfo = startInfo };
            process.Start();

            var output = await process.StandardOutput.ReadToEndAsync();
            var error = await process.StandardError.ReadToEndAsync();

            await process.WaitForExitAsync();

            if (process.ExitCode != 0)
            {
                throw new Exception($"Java process failed: {error}");
            }

            return output;
        }

        private List<DeviceInfo> ParseDevices(string output)
        {
            var devices = new List<DeviceInfo>();
            var lines = output.Split('\n');

            foreach (var line in lines)
            {
                if (line.StartsWith("DEVICE|"))
                {
                    var parts = line.Split('|');
                    if (parts.Length >= 5)
                    {
                        devices.Add(new DeviceInfo
                        {
                            Name = parts[1],
                            Address = parts[2],
                            IsNioxDevice = bool.Parse(parts[3]),
                            SerialNumber = parts[4] == "null" ? null : parts[4]
                        });
                    }
                }
            }

            return devices;
        }
    }
}
```

---

## Building the Windows JAR

### Step 1: Build the Project

```bash
./gradlew :nioxplugin:buildWindowsJar
```

### Step 2: Locate the JAR

The JAR will be located at:
```
nioxplugin/build/outputs/windows/niox-communication-plugin-windows-1.0.0.jar
```

### Step 3: Include Required Dependencies

The JAR requires these runtime dependencies:
- `kotlinx-coroutines-core-jvm-1.7.3.jar`
- `jna-5.13.0.jar`
- `jna-platform-5.13.0.jar`

You can create a fat JAR with all dependencies using Shadow plugin, or distribute them separately.

---

## Platform-Specific Configuration

### MAUI Project Configuration

Add to your `.csproj` for Windows:

```xml
<ItemGroup Condition="$([MSBuild]::GetTargetPlatformIdentifier('$(TargetFramework)')) == 'windows'">
    <None Update="niox-communication-plugin-windows-1.0.0.jar">
        <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    </None>
</ItemGroup>
```

### Required Capabilities

No special capabilities needed for Windows Bluetooth Classic API access.

---

## API Reference

### BluetoothState Enum

- `ENABLED` - Bluetooth is enabled
- `DISABLED` - Bluetooth is disabled
- `UNSUPPORTED` - Bluetooth not supported
- `UNKNOWN` - State unknown

### DeviceInfo Properties

- `Name` (string) - Device name (may be null)
- `Address` (string) - MAC address
- `Rssi` (int?) - Signal strength (always null on Windows)
- `IsNioxDevice` (bool) - True if NIOX device
- `SerialNumber` (string) - NIOX device serial (if available)

---

## Troubleshooting

### Issue: JNA Native Library Not Found

**Solution**: Ensure JNA DLLs are in the same directory as the JAR or in system PATH.

### Issue: Bluetooth Adapter Not Found

**Solution**: Check that:
1. Bluetooth is enabled in Windows Settings
2. Bluetooth drivers are installed
3. Application has necessary permissions

### Issue: IKVM Conversion Fails

**Solution**: Use the process execution method as a fallback.

### Issue: No Devices Found

**Solution**:
1. Ensure Bluetooth devices are in pairing mode
2. Increase scan duration: `scanDurationMs: 30000`
3. Remove service UUID filter to scan all devices

---

## Example: Complete MAUI App

See the example project structure:

```
YourMauiApp/
├── Platforms/
│   └── Windows/
│       └── NioxPlugin/
│           └── niox-communication-plugin-windows-1.0.0.jar
├── Services/
│   └── BluetoothService.cs
├── Models/
│   └── DeviceInfo.cs
├── Pages/
│   ├── MainPage.xaml
│   └── MainPage.xaml.cs
└── YourMauiApp.csproj
```

---

## Performance Notes & Best Practices

### Performance Characteristics
- **Scan Duration:** Typically 5-10 seconds on Windows depending on device density
- **RSSI Limitation:** Windows Bluetooth Classic API does not provide signal strength (always `null`)
- **Resource Usage:** Low CPU/memory footprint (~15 MB JAR + IKVM overhead)
- **Thread Safety:** All operations are thread-safe with proper locking

### Best Practices

#### 1. Resource Management
```csharp
// Always dispose the service when done
using var bluetoothService = new NioxBluetoothService();
var devices = await bluetoothService.ScanForDevicesAsync();
// Service automatically disposed and scan stopped
```

#### 2. Error Handling
```csharp
try
{
    var state = await bluetoothService.CheckBluetoothStateAsync();
    if (state == BluetoothState.ENABLED)
    {
        var devices = await bluetoothService.ScanForDevicesAsync();
    }
}
catch (Exception ex)
{
    // Handle Bluetooth errors gracefully
    await DisplayAlert("Error", $"Bluetooth error: {ex.Message}", "OK");
}
```

#### 3. UI Responsiveness
```csharp
// Use CancellationToken for long-running operations
private CancellationTokenSource _cts;

private async void OnScanClicked(object sender, EventArgs e)
{
    _cts = new CancellationTokenSource();
    try
    {
        await Task.Run(async () =>
        {
            var devices = await bluetoothService.ScanForDevicesAsync(10000);
            return devices;
        }, _cts.Token);
    }
    catch (OperationCanceledException)
    {
        // User cancelled the operation
    }
}

private void OnCancelClicked(object sender, EventArgs e)
{
    _cts?.Cancel();
    bluetoothService.StopScan();
}
```

#### 4. Avoid Rapid Scanning
```csharp
// Implement cooldown between scans
private DateTime _lastScanTime = DateTime.MinValue;
private readonly TimeSpan _scanCooldown = TimeSpan.FromSeconds(3);

private async Task ScanWithCooldownAsync()
{
    var timeSinceLastScan = DateTime.Now - _lastScanTime;
    if (timeSinceLastScan < _scanCooldown)
    {
        await Task.Delay(_scanCooldown - timeSinceLastScan);
    }

    var devices = await bluetoothService.ScanForDevicesAsync();
    _lastScanTime = DateTime.Now;
}
```

#### 5. Dependency Injection (Recommended)
```csharp
// In MauiProgram.cs
builder.Services.AddSingleton<NioxBluetoothService>();

// In your page/view model
public partial class MainPage : ContentPage
{
    private readonly NioxBluetoothService _bluetoothService;

    public MainPage(NioxBluetoothService bluetoothService)
    {
        _bluetoothService = bluetoothService;
        InitializeComponent();
    }
}
```

### Optimization Tips
- ✅ **Cache results:** Don't re-scan unnecessarily
- ✅ **Filter early:** Use service UUID filters to reduce processing
- ✅ **Stop when done:** Always call `StopScan()` to free resources
- ✅ **Async all the way:** Keep UI responsive with async/await
- ❌ **Avoid blocking:** Don't use `.Result` or `.Wait()` on UI thread

---

## Deployment Checklist

### Development Environment
- [ ] .NET 8.0 SDK installed
- [ ] MAUI workload installed
- [ ] JDK 11+ installed (for IKVM compilation)
- [ ] IKVM packages added to project
- [ ] Niox Plugin JAR referenced correctly

### Production Build
- [ ] JAR converted to DLL via IKVM
- [ ] All dependencies included in build output
- [ ] Windows platform target configured in `.csproj`
- [ ] App tested on clean Windows installation
- [ ] Bluetooth adapter availability checked

### Runtime Requirements (End User)
- [ ] Windows 10/11 with Bluetooth support
- [ ] .NET Runtime 8.0+ installed (included in MAUI app)
- [ ] **No JVM required** (when using IKVM method)
- [ ] Bluetooth adapter enabled in system settings

---

## Additional Resources

### Documentation
- [Niox Plugin README](README.md) - General plugin documentation
- [Windows Build Setup](WINDOWS_BUILD_SETUP.md) - Building the JAR from source
- [Usage Examples](USAGE_EXAMPLES.md) - Cross-platform code samples

### External References
- [IKVM.NET Documentation](https://ikvm.net/) - Java to .NET translation
- [.NET MAUI Documentation](https://learn.microsoft.com/en-us/dotnet/maui/) - MAUI development guide
- [Windows Bluetooth API](https://learn.microsoft.com/en-us/windows/uwp/devices-sensors/bluetooth) - Platform reference

---

## Support & Contributing

For issues, feature requests, or contributions:
- **Repository:** github.com/edwinatokaranAlten/NioxPlugin
- **Issues:** Submit via GitHub Issues
- **Contact:** edwin-thomas.atokaran@alten.se

---

**Document Version:** 1.0.0
**Last Updated:** October 22, 2024
**Compatibility:** .NET 8.0+, Windows 10/11
