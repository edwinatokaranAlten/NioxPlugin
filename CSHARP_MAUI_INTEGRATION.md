# C# MAUI Integration Guide for Niox Communication Plugin

This guide explains how to use the Niox Communication Plugin Windows JAR library from a .NET MAUI C# application.

## Overview

The Windows implementation generates a JAR file that can be called from C# using the IKVM.NET library or by launching a JVM process. This guide covers both approaches.

## Prerequisites

- .NET 8.0 or higher
- MAUI workload installed
- JDK 11 or higher installed on target Windows machine
- Built Niox Plugin JAR file: `niox-communication-plugin-windows-1.0.0.jar`

---

## Method 1: Using IKVM.NET (Recommended)

IKVM.NET allows you to use Java libraries directly in .NET by converting JAR files to .NET assemblies.

### Step 1: Install IKVM.NET

Add IKVM.NET to your MAUI project:

```bash
dotnet add package IKVM
dotnet add package IKVM.Maven.Sdk
```

### Step 2: Convert JAR to DLL

Use the IKVM compiler to convert the JAR to a .NET assembly:

```bash
ikvmc -target:library -out:NioxPlugin.dll niox-communication-plugin-windows-1.0.0.jar
```

Or add to your `.csproj`:

```xml
<ItemGroup>
  <IkvmReference Include="path\to\niox-communication-plugin-windows-1.0.0.jar" />
</ItemGroup>
```

### Step 3: Use in C# Code

```csharp
using com.niox.nioxplugin;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Linq;

namespace YourMauiApp
{
    public class BluetoothService
    {
        private readonly NioxCommunicationPlugin plugin;

        public BluetoothService()
        {
            plugin = NioxCommunicationPluginKt.createNioxCommunicationPlugin();
        }

        public async Task<string> CheckBluetoothStateAsync()
        {
            // Call the suspend function using continuation
            var state = await Task.Run(() =>
            {
                var continuation = new SimpleContinuation<BluetoothState>();
                plugin.checkBluetoothState(continuation);
                return continuation.GetResult();
            });

            return state.ToString();
        }

        public async Task<List<DeviceInfo>> ScanForDevicesAsync(
            long scanDurationMs = 10000,
            string serviceUuidFilter = null)
        {
            var devices = await Task.Run(() =>
            {
                var continuation = new SimpleContinuation<java.util.List>();

                if (serviceUuidFilter != null)
                {
                    plugin.scanForDevices(scanDurationMs, serviceUuidFilter, continuation);
                }
                else
                {
                    plugin.scanForDevices(scanDurationMs, null, continuation);
                }

                return continuation.GetResult();
            });

            // Convert Java list to C# list
            var deviceList = new List<DeviceInfo>();
            var iterator = devices.iterator();

            while (iterator.hasNext())
            {
                var device = (BluetoothDevice)iterator.next();
                deviceList.Add(new DeviceInfo
                {
                    Name = device.getName(),
                    Address = device.getAddress(),
                    Rssi = device.getRssi()?.intValue(),
                    IsNioxDevice = device.isNioxDevice(),
                    SerialNumber = device.getNioxSerialNumber()
                });
            }

            return deviceList;
        }

        public void StopScan()
        {
            plugin.stopScan();
        }
    }

    // Helper class for device information
    public class DeviceInfo
    {
        public string Name { get; set; }
        public string Address { get; set; }
        public int? Rssi { get; set; }
        public bool IsNioxDevice { get; set; }
        public string SerialNumber { get; set; }
    }

    // Helper class for Kotlin coroutines
    public class SimpleContinuation<T> : kotlin.coroutines.Continuation
    {
        private T result;
        private bool completed = false;
        private readonly object lockObj = new object();

        public kotlin.coroutines.CoroutineContext getContext()
        {
            return kotlin.coroutines.EmptyCoroutineContext.INSTANCE;
        }

        public void resumeWith(object result)
        {
            lock (lockObj)
            {
                if (result is kotlin.Result)
                {
                    var kotlinResult = (kotlin.Result)result;
                    if (kotlinResult.isSuccess())
                    {
                        this.result = (T)kotlinResult.value;
                    }
                    else
                    {
                        throw new Exception("Kotlin operation failed",
                            kotlinResult.exceptionOrNull() as Exception);
                    }
                }
                else
                {
                    this.result = (T)result;
                }
                completed = true;
                System.Threading.Monitor.PulseAll(lockObj);
            }
        }

        public T GetResult()
        {
            lock (lockObj)
            {
                while (!completed)
                {
                    System.Threading.Monitor.Wait(lockObj);
                }
                return result;
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

## Performance Notes

- Scanning typically takes 5-10 seconds on Windows
- Windows Bluetooth Classic API doesn't provide RSSI
- Multiple rapid scans may cause performance degradation
- Always call `StopScan()` when canceling operations

---

## License

Copyright (c) 2024 Niox. All rights reserved.
