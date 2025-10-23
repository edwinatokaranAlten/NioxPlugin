# WinUI 3 Integration - Using JAR Directly
## Running NIOX JAR as a Process from WinUI 3

This guide shows you how to use the JAR file **directly** in your WinUI 3 app without converting to DLL.

---

## When to Use This Method

Use this approach if:
- ❌ IKVM installation fails or doesn't work
- ❌ DLL conversion has issues
- ✅ You want a simpler setup without DLL conversion
- ✅ You're okay with requiring Java Runtime on user machines

---

## Prerequisites

- ✅ Windows 10/11
- ✅ .NET SDK 8.0+
- ✅ Visual Studio 2022
- ✅ **Java Runtime 11+** (must be installed on target machines)
- ✅ Your built JAR: `niox-communication-plugin-windows-1.0.0.jar`

---

## Part 1: Verify Java is Installed

```powershell
# Check Java version
java -version

# Should show Java 11 or higher
# Example output:
# java version "11.0.x" or "17.0.x" or "21.0.x"
```

If Java is not installed:
- Download from: https://adoptium.net/
- Install **Temurin JDK 17** (LTS recommended)

---

## Part 2: Create WinUI 3 Project

### Step 1: Create Project in Visual Studio

1. Open **Visual Studio 2022**
2. Create new project → **"Blank App, Packaged (WinUI 3 in Desktop)"**
3. Name: `NioxBluetoothApp`
4. Framework: **.NET 8.0**

### Step 2: Create Assets Folder

1. Right-click project → Add → **New Folder** → Name: `Assets`
2. Create subfolder: `Assets/Java`

### Step 3: Add JAR to Project

1. Copy your JAR file to: `Assets/Java/niox-communication-plugin-windows-1.0.0.jar`
2. In Visual Studio:
   - Right-click `Assets/Java` folder
   - Add → Existing Item
   - Select the JAR file
3. Set JAR properties:
   - **Build Action:** `Content`
   - **Copy to Output Directory:** `Copy always`

---

## Part 3: Create Java Process Service

### Step 1: Create Services Folder

Right-click project → Add → New Folder → Name: `Services`

### Step 2: Create NioxJavaService.cs

Right-click `Services` → Add → Class → Name: `NioxJavaService.cs`

Replace content with:

```csharp
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;

namespace NioxBluetoothApp.Services
{
    /// <summary>
    /// Service that executes the NIOX JAR file as a Java process
    /// </summary>
    public class NioxJavaService
    {
        private readonly string _jarPath;
        private readonly string _javaPath;

        public NioxJavaService()
        {
            // Find the JAR file in the application directory
            var appDir = AppContext.BaseDirectory;
            _jarPath = Path.Combine(appDir, "Assets", "Java", "niox-communication-plugin-windows-1.0.0.jar");

            // Use system Java
            _javaPath = "java";

            // Verify JAR exists
            if (!File.Exists(_jarPath))
            {
                throw new FileNotFoundException($"JAR file not found: {_jarPath}");
            }
        }

        /// <summary>
        /// Check Bluetooth adapter state
        /// </summary>
        public async Task<string> CheckBluetoothStateAsync()
        {
            try
            {
                // Run: java -cp niox-plugin.jar com.niox.nioxplugin.Main checkBluetooth
                var output = await RunJavaCommandAsync("checkBluetooth");
                return output.Trim();
            }
            catch (Exception ex)
            {
                return $"ERROR: {ex.Message}";
            }
        }

        /// <summary>
        /// Scan for all Bluetooth devices
        /// </summary>
        public async Task<List<DeviceInfo>> ScanForDevicesAsync(int durationMs = 10000)
        {
            try
            {
                // Run: java -cp niox-plugin.jar com.niox.nioxplugin.Main scanDevices <duration>
                var output = await RunJavaCommandAsync($"scanDevices {durationMs}");
                return ParseDevicesFromJson(output);
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Scan error: {ex.Message}");
                return new List<DeviceInfo>();
            }
        }

        /// <summary>
        /// Scan for NIOX devices only
        /// </summary>
        public async Task<List<DeviceInfo>> ScanForNioxDevicesAsync(int durationMs = 10000)
        {
            var allDevices = await ScanForDevicesAsync(durationMs);
            return allDevices.Where(d => d.IsNioxDevice).ToList();
        }

        private async Task<string> RunJavaCommandAsync(string command)
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = _javaPath,
                Arguments = $"-cp \"{_jarPath}\" com.niox.nioxplugin.cli.Main {command}",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true,
                WorkingDirectory = Path.GetDirectoryName(_jarPath)
            };

            using var process = new Process { StartInfo = startInfo };

            process.Start();

            var outputTask = process.StandardOutput.ReadToEndAsync();
            var errorTask = process.StandardError.ReadToEndAsync();

            await process.WaitForExitAsync();

            var output = await outputTask;
            var error = await errorTask;

            if (process.ExitCode != 0)
            {
                throw new Exception($"Java process failed: {error}");
            }

            return output;
        }

        private List<DeviceInfo> ParseDevicesFromJson(string jsonOutput)
        {
            var devices = new List<DeviceInfo>();

            try
            {
                using var doc = JsonDocument.Parse(jsonOutput);
                var root = doc.RootElement;

                if (root.TryGetProperty("devices", out var devicesArray))
                {
                    foreach (var deviceElement in devicesArray.EnumerateArray())
                    {
                        devices.Add(new DeviceInfo
                        {
                            Name = deviceElement.GetProperty("name").GetString() ?? "Unknown",
                            Address = deviceElement.GetProperty("address").GetString() ?? "N/A",
                            IsNioxDevice = deviceElement.GetProperty("isNioxDevice").GetBoolean(),
                            SerialNumber = deviceElement.TryGetProperty("serialNumber", out var serial)
                                ? serial.GetString()
                                : null
                        });
                    }
                }
            }
            catch (JsonException ex)
            {
                Debug.WriteLine($"JSON parse error: {ex.Message}");
            }

            return devices;
        }
    }

    /// <summary>
    /// Device information model
    /// </summary>
    public class DeviceInfo
    {
        public string Name { get; set; } = string.Empty;
        public string Address { get; set; } = string.Empty;
        public bool IsNioxDevice { get; set; }
        public string? SerialNumber { get; set; }

        public override string ToString()
        {
            var nioxStr = IsNioxDevice ? $" [NIOX: {SerialNumber}]" : "";
            return $"{Name} - {Address}{nioxStr}";
        }
    }
}
```

---

## Part 4: Create Java CLI Wrapper (Required!)

The JAR needs a command-line interface. You need to add this to your NIOX project.

### Step 1: Create CLI Package in NIOX Project

In your NIOX project, create:
`nioxplugin/src/windowsMain/kotlin/com/niox/nioxplugin/cli/Main.kt`

```kotlin
package com.niox.nioxplugin.cli

import com.niox.nioxplugin.createNioxCommunicationPlugin
import kotlinx.coroutines.runBlocking
import kotlin.system.exitProcess

/**
 * Command-line interface for the NIOX Communication Plugin
 * Allows the JAR to be executed from C# via process execution
 */
fun main(args: Array<String>) {
    if (args.isEmpty()) {
        printUsage()
        exitProcess(1)
    }

    val command = args[0]
    val plugin = createNioxCommunicationPlugin()

    try {
        when (command) {
            "checkBluetooth" -> {
                val state = runBlocking { plugin.checkBluetoothState() }
                println(state.name)
            }

            "scanDevices" -> {
                val duration = if (args.size > 1) args[1].toLongOrNull() ?: 10000L else 10000L
                val devices = runBlocking { plugin.scanForDevices(duration, null) }

                // Output as JSON
                println("""{"devices":[""")
                devices.forEachIndexed { index, device ->
                    val comma = if (index < devices.size - 1) "," else ""
                    println("""
                        {
                            "name":"${device.name?.replace("\"", "\\\"")}",
                            "address":"${device.address}",
                            "isNioxDevice":${device.isNioxDevice()},
                            "serialNumber":"${device.getNioxSerialNumber()}"
                        }$comma
                    """.trimIndent())
                }
                println("]}")
            }

            else -> {
                System.err.println("Unknown command: $command")
                printUsage()
                exitProcess(1)
            }
        }
    } catch (e: Exception) {
        System.err.println("Error: ${e.message}")
        e.printStackTrace()
        exitProcess(1)
    }
}

private fun printUsage() {
    println("""
        NIOX Communication Plugin CLI

        Usage:
          java -jar niox-communication-plugin-windows-1.0.0.jar <command> [args]

        Commands:
          checkBluetooth           - Check Bluetooth adapter state
          scanDevices [duration]   - Scan for devices (duration in ms, default: 10000)

        Examples:
          java -jar niox-plugin.jar checkBluetooth
          java -jar niox-plugin.jar scanDevices 15000
    """.trimIndent())
}
```

### Step 2: Rebuild the JAR

```powershell
# In your NIOX project directory
./gradlew :nioxplugin:buildWindowsJar
```

### Step 3: Copy Updated JAR to WinUI Project

Copy the newly built JAR to your WinUI project's `Assets/Java/` folder.

---

## Part 5: Create UI

### MainWindow.xaml

```xml
<?xml version="1.0" encoding="utf-8"?>
<Window
    x:Class="NioxBluetoothApp.MainWindow"
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="NIOX Bluetooth Scanner (JAR)"
    Width="800"
    Height="600">

    <Grid Padding="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <TextBlock
            Grid.Row="0"
            Text="NIOX Bluetooth Scanner (using JAR)"
            FontSize="28"
            FontWeight="Bold"
            HorizontalAlignment="Center"
            Margin="0,0,0,20"/>

        <StackPanel Grid.Row="1" Spacing="10" Margin="0,0,0,20">
            <Button
                x:Name="CheckButton"
                Content="Check Bluetooth State"
                Click="CheckButton_Click"
                Height="50"
                Background="#0078D4"/>

            <Button
                x:Name="ScanButton"
                Content="Scan All Devices"
                Click="ScanButton_Click"
                Height="50"
                Background="#107C10"/>

            <Button
                x:Name="ScanNioxButton"
                Content="Scan NIOX Devices"
                Click="ScanNioxButton_Click"
                Height="50"
                Background="#5E5E5E"/>
        </StackPanel>

        <TextBlock
            Grid.Row="2"
            x:Name="StatusLabel"
            Text="Ready"
            FontSize="18"
            HorizontalAlignment="Center"
            Margin="0,10"/>

        <ListView
            Grid.Row="3"
            x:Name="DevicesListView"
            Background="#F0F0F0">
            <ListView.ItemTemplate>
                <DataTemplate>
                    <StackLayout Padding="10">
                        <TextBlock Text="{Binding Name}" FontSize="16" FontWeight="Bold"/>
                        <TextBlock Text="{Binding Address}" FontSize="14" Foreground="Gray"/>
                        <TextBlock Text="{Binding SerialNumber, StringFormat='Serial: {0}'}"
                                   FontSize="14"
                                   Foreground="Green"
                                   Visibility="{Binding IsNioxDevice}"/>
                    </StackLayout>
                </DataTemplate>
            </ListView.ItemTemplate>
        </ListView>
    </Grid>
</Window>
```

### MainWindow.xaml.cs

```csharp
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using NioxBluetoothApp.Services;
using System;
using System.Collections.ObjectModel;

namespace NioxBluetoothApp
{
    public sealed partial class MainWindow : Window
    {
        private readonly NioxJavaService _service;
        public ObservableCollection<DeviceInfo> Devices { get; set; }

        public MainWindow()
        {
            this.InitializeComponent();
            _service = new NioxJavaService();
            Devices = new ObservableCollection<DeviceInfo>();
            DevicesListView.ItemsSource = Devices;
        }

        private async void CheckButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                StatusLabel.Text = "Checking Bluetooth...";
                CheckButton.IsEnabled = false;

                var state = await _service.CheckBluetoothStateAsync();
                StatusLabel.Text = $"Bluetooth: {state}";
            }
            catch (Exception ex)
            {
                StatusLabel.Text = $"Error: {ex.Message}";
            }
            finally
            {
                CheckButton.IsEnabled = true;
            }
        }

        private async void ScanButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                StatusLabel.Text = "Scanning...";
                DisableButtons();
                Devices.Clear();

                var devices = await _service.ScanForDevicesAsync(10000);

                foreach (var device in devices)
                {
                    Devices.Add(device);
                }

                StatusLabel.Text = $"Found {devices.Count} devices";
            }
            catch (Exception ex)
            {
                StatusLabel.Text = $"Error: {ex.Message}";
            }
            finally
            {
                EnableButtons();
            }
        }

        private async void ScanNioxButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                StatusLabel.Text = "Scanning for NIOX...";
                DisableButtons();
                Devices.Clear();

                var devices = await _service.ScanForNioxDevicesAsync(15000);

                foreach (var device in devices)
                {
                    Devices.Add(device);
                }

                StatusLabel.Text = $"Found {devices.Count} NIOX devices";
            }
            catch (Exception ex)
            {
                StatusLabel.Text = $"Error: {ex.Message}";
            }
            finally
            {
                EnableButtons();
            }
        }

        private void DisableButtons()
        {
            CheckButton.IsEnabled = false;
            ScanButton.IsEnabled = false;
            ScanNioxButton.IsEnabled = false;
        }

        private void EnableButtons()
        {
            CheckButton.IsEnabled = true;
            ScanButton.IsEnabled = true;
            ScanNioxButton.IsEnabled = true;
        }
    }
}
```

---

## Part 6: Build and Test

### Step 1: Build Project

Press **Ctrl + Shift + B**

### Step 2: Test JAR Manually

```powershell
# Navigate to output directory
cd bin\x64\Debug\net8.0-windows10.0.19041.0\Assets\Java

# Test the JAR
java -jar niox-communication-plugin-windows-1.0.0.jar checkBluetooth
# Should output: ENABLED, DISABLED, or UNSUPPORTED

java -jar niox-communication-plugin-windows-1.0.0.jar scanDevices 5000
# Should output JSON with devices
```

### Step 3: Run WinUI App

Press **F5** and test the buttons!

---

## Comparison: JAR vs DLL

| Aspect | JAR (Process) | DLL (IKVM) |
|--------|---------------|------------|
| Setup complexity | More complex | Simpler |
| Java required at runtime | ✅ Yes | ❌ No |
| Performance | Slower (process overhead) | Faster (native .NET) |
| Error handling | More complex | Easier |
| Recommended | Only if IKVM fails | ✅ **Preferred** |

---

## Troubleshooting

### Issue: "java not found"

**Solution:**
```powershell
# Verify Java installation
java -version

# If not installed, download from:
# https://adoptium.net/
```

### Issue: "JAR file not found"

**Solution:**
- Check JAR is in `Assets/Java/` folder
- Verify JAR properties: `Copy to Output Directory = Copy always`
- Rebuild project

### Issue: "Unknown command"

**Solution:**
- You need to add the CLI Main.kt file to your NIOX project
- Rebuild the JAR with the CLI code
- Update the JAR in your WinUI project

---

## Summary

You can use the JAR directly, but it requires:
1. ✅ Java Runtime on user machines
2. ✅ CLI wrapper in your JAR
3. ✅ Process execution from C#

**Better option:** Use IKVM to convert JAR → DLL (no Java needed at runtime!)

---

**Recommendation: Try IKVM first!** It's much cleaner and doesn't require Java on end-user machines.

If IKVM doesn't work, use this JAR method as a fallback.
