# MAUI DLL Integration Guide
## Complete Step-by-Step Guide for Using NIOX Plugin DLL in .NET MAUI

This guide shows you exactly how to use the NIOX Plugin DLL in your .NET MAUI project.

---

## Table of Contents
1. [Understanding the Two DLL Types](#understanding-the-two-dll-types)
2. [Quick Start: IKVM Method (Recommended)](#quick-start-ikvm-method-recommended)
3. [Alternative: Native DLL Method](#alternative-native-dll-method)
4. [Complete MAUI Integration Example](#complete-maui-integration-example)
5. [Troubleshooting](#troubleshooting)

---

## Understanding the Two DLL Types

Your NIOX project has **two different Windows implementations**:

| Type | Source File | Build Output | Features | Recommended? |
|------|-------------|--------------|----------|--------------|
| **IKVM DLL (FULL FEATURES)** | `windowsMain/` (JVM+JNA) | JAR → DLL | ✅ **Complete Bluetooth API with Windows Bluetooth Classic** | ✅ **YES - USE THIS!** |
| **Native DLL (STUB ONLY)** | `windowsNativeMain/` (Kotlin/Native) | mingwX64 DLL | ❌ Stub only - Always returns UNSUPPORTED | ❌ NO - Don't use |

### Key Difference:
- **Windows JVM (IKVM)**: Uses JNA to call Windows Bluetooth APIs (`Bthprops.cpl`) - **FULL FUNCTIONALITY**
- **Windows Native**: Just a buildable stub - returns empty devices and UNSUPPORTED state

**You MUST use the IKVM method to get actual Bluetooth functionality!**

---

## Quick Start: IKVM Method (Recommended)

This method converts your **Windows JVM JAR** (which contains the full Bluetooth implementation using JNA) to a .NET DLL that works seamlessly with MAUI.

### Why This Works:
1. Your `windowsMain/` source contains the **real Bluetooth implementation** using JNA to call Windows APIs
2. This compiles to a **JAR file** with full Bluetooth functionality
3. IKVM converts the JAR (Java bytecode) → .NET DLL (MSIL bytecode)
4. Your MAUI app can now use the full Bluetooth features as a native .NET library!

### Prerequisites

- .NET SDK 8.0+
- MAUI workload installed
- Java JDK 11+ (for building the JAR)

### Step 1: Build the JAR

```bash
# From your NIOXSDKPlugin directory
./gradlew :nioxplugin:buildWindowsJar
```

This creates: `nioxplugin/build/outputs/windows/niox-communication-plugin-windows-1.0.0.jar`

### Step 2: Install IKVM

```bash
dotnet tool install -g ikvm
```

Verify installation:
```bash
ikvmc -version
```

### Step 3: Convert JAR to DLL

```bash
cd nioxplugin/build/outputs/windows

ikvmc -target:library \
     -out:NioxPlugin.dll \
     -version:1.0.0.0 \
     niox-communication-plugin-windows-1.0.0.jar
```

This creates `NioxPlugin.dll` - this is your .NET DLL!

### Step 4: Create Your MAUI Project

```bash
dotnet new maui -n MyNioxApp
cd MyNioxApp
```

### Step 5: Add the DLL to Your Project

1. Create a `Libraries` folder in your project:
```bash
mkdir Libraries
```

2. Copy the DLL:
```bash
cp /path/to/NioxPlugin.dll Libraries/
```

3. Edit `MyNioxApp.csproj` and add:

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFrameworks>net8.0-android;net8.0-ios;net8.0-windows10.0.19041.0</TargetFrameworks>
    <UseMaui>true</UseMaui>
    <!-- ... other properties ... -->
  </PropertyGroup>

  <ItemGroup>
    <!-- Add IKVM package -->
    <PackageReference Include="IKVM" Version="8.7.5" />
  </ItemGroup>

  <!-- Reference the DLL only for Windows -->
  <ItemGroup Condition="$([MSBuild]::GetTargetPlatformIdentifier('$(TargetFramework)')) == 'windows'">
    <Reference Include="NioxPlugin">
      <HintPath>Libraries\NioxPlugin.dll</HintPath>
      <Private>true</Private>
    </Reference>

    <!-- Copy DLL to output directory -->
    <None Update="Libraries\NioxPlugin.dll">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    </None>
  </ItemGroup>

</Project>
```

### Step 6: Create Bluetooth Service Wrapper

Create `Services/NioxBluetoothService.cs`:

```csharp
using com.niox.nioxplugin;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

#if WINDOWS
namespace MyNioxApp.Services
{
    /// <summary>
    /// Wrapper service for NIOX Bluetooth Plugin (Windows only)
    /// </summary>
    public class NioxBluetoothService
    {
        private readonly NioxCommunicationPlugin _plugin;

        public NioxBluetoothService()
        {
            // Initialize the plugin
            _plugin = NioxCommunicationPluginKt.createNioxCommunicationPlugin();
        }

        /// <summary>
        /// Check if Bluetooth is enabled
        /// </summary>
        public async Task<string> CheckBluetoothStateAsync()
        {
            return await Task.Run(() =>
            {
                try
                {
                    var continuation = new KotlinContinuation<BluetoothState>();
                    _plugin.checkBluetoothState(continuation);
                    var state = continuation.GetResult();
                    return state.ToString();
                }
                catch (Exception ex)
                {
                    return $"ERROR: {ex.Message}";
                }
            });
        }

        /// <summary>
        /// Scan for Bluetooth devices
        /// </summary>
        public async Task<List<DeviceInfo>> ScanForDevicesAsync(int durationMs = 10000)
        {
            return await Task.Run(() =>
            {
                try
                {
                    var continuation = new KotlinContinuation<java.util.List>();
                    _plugin.scanForDevices(durationMs, null, continuation);

                    var javaList = continuation.GetResult();
                    return ConvertToDeviceList(javaList);
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Scan error: {ex.Message}");
                    return new List<DeviceInfo>();
                }
            });
        }

        /// <summary>
        /// Scan for NIOX devices only
        /// </summary>
        public async Task<List<DeviceInfo>> ScanForNioxDevicesAsync(int durationMs = 10000)
        {
            var allDevices = await ScanForDevicesAsync(durationMs);
            return allDevices.Where(d => d.IsNioxDevice).ToList();
        }

        /// <summary>
        /// Stop ongoing scan
        /// </summary>
        public void StopScan()
        {
            _plugin.stopScan();
        }

        private List<DeviceInfo> ConvertToDeviceList(java.util.List javaList)
        {
            var devices = new List<DeviceInfo>();
            var iterator = javaList.iterator();

            while (iterator.hasNext())
            {
                var device = (BluetoothDevice)iterator.next();
                devices.Add(new DeviceInfo
                {
                    Name = device.getName() ?? "Unknown",
                    Address = device.getAddress() ?? "N/A",
                    Rssi = device.getRssi()?.intValue(),
                    IsNioxDevice = device.isNioxDevice(),
                    SerialNumber = device.getNioxSerialNumber()
                });
            }

            return devices;
        }
    }

    /// <summary>
    /// Device information class
    /// </summary>
    public class DeviceInfo
    {
        public string Name { get; set; } = string.Empty;
        public string Address { get; set; } = string.Empty;
        public int? Rssi { get; set; }
        public bool IsNioxDevice { get; set; }
        public string? SerialNumber { get; set; }

        public override string ToString()
        {
            var rssiStr = Rssi.HasValue ? $" ({Rssi}dBm)" : "";
            var nioxStr = IsNioxDevice ? $" [NIOX: {SerialNumber}]" : "";
            return $"{Name} - {Address}{rssiStr}{nioxStr}";
        }
    }

    /// <summary>
    /// Kotlin Continuation bridge for async interop
    /// </summary>
    internal class KotlinContinuation<T> : kotlin.coroutines.Continuation
    {
        private T? _result;
        private Exception? _exception;
        private bool _completed = false;
        private readonly object _lock = new object();

        public kotlin.coroutines.CoroutineContext getContext()
        {
            return kotlin.coroutines.EmptyCoroutineContext.INSTANCE;
        }

        public void resumeWith(object result)
        {
            lock (_lock)
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
                            var ex = kotlinResult.exceptionOrNull();
                            _exception = new Exception($"Kotlin error: {ex?.Message ?? "Unknown"}", ex as Exception);
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
                    System.Threading.Monitor.PulseAll(_lock);
                }
            }
        }

        public T GetResult()
        {
            lock (_lock)
            {
                while (!_completed)
                {
                    System.Threading.Monitor.Wait(_lock);
                }

                if (_exception != null)
                    throw _exception;

                return _result!;
            }
        }
    }
}
#endif
```

### Step 7: Use in MainPage

Edit `MainPage.xaml.cs`:

```csharp
using Microsoft.Maui.Controls;
using System;
using System.Collections.ObjectModel;

#if WINDOWS
using MyNioxApp.Services;
#endif

namespace MyNioxApp
{
    public partial class MainPage : ContentPage
    {
#if WINDOWS
        private NioxBluetoothService? _bluetoothService;
        public ObservableCollection<string> Devices { get; set; } = new();
#endif

        public MainPage()
        {
            InitializeComponent();

#if WINDOWS
            _bluetoothService = new NioxBluetoothService();
            DevicesListView.ItemsSource = Devices;
#endif
        }

        private async void OnCheckBluetoothClicked(object sender, EventArgs e)
        {
#if WINDOWS
            try
            {
                StatusLabel.Text = "Checking Bluetooth...";
                var state = await _bluetoothService!.CheckBluetoothStateAsync();
                StatusLabel.Text = $"Bluetooth State: {state}";
            }
            catch (Exception ex)
            {
                StatusLabel.Text = $"Error: {ex.Message}";
            }
#else
            await DisplayAlert("Platform", "This feature is Windows-only", "OK");
#endif
        }

        private async void OnScanDevicesClicked(object sender, EventArgs e)
        {
#if WINDOWS
            try
            {
                StatusLabel.Text = "Scanning...";
                Devices.Clear();

                var devices = await _bluetoothService!.ScanForDevicesAsync(10000);

                foreach (var device in devices)
                {
                    Devices.Add(device.ToString());
                }

                StatusLabel.Text = $"Found {devices.Count} devices";
            }
            catch (Exception ex)
            {
                StatusLabel.Text = $"Error: {ex.Message}";
            }
#else
            await DisplayAlert("Platform", "This feature is Windows-only", "OK");
#endif
        }

        private async void OnScanNioxClicked(object sender, EventArgs e)
        {
#if WINDOWS
            try
            {
                StatusLabel.Text = "Scanning for NIOX devices...";
                Devices.Clear();

                var devices = await _bluetoothService!.ScanForNioxDevicesAsync(15000);

                foreach (var device in devices)
                {
                    Devices.Add(device.ToString());
                }

                var nioxCount = devices.Count(d => d.IsNioxDevice);
                StatusLabel.Text = $"Found {devices.Count} devices ({nioxCount} NIOX)";
            }
            catch (Exception ex)
            {
                StatusLabel.Text = $"Error: {ex.Message}";
            }
#else
            await DisplayAlert("Platform", "This feature is Windows-only", "OK");
#endif
        }

        private void OnStopScanClicked(object sender, EventArgs e)
        {
#if WINDOWS
            _bluetoothService?.StopScan();
            StatusLabel.Text = "Scan stopped";
#endif
        }
    }
}
```

### Step 8: Update XAML

Edit `MainPage.xaml`:

```xml
<?xml version="1.0" encoding="utf-8" ?>
<ContentPage xmlns="http://schemas.microsoft.com/dotnet/2021/maui"
             xmlns:x="http://schemas.microsoft.com/winfx/2009/xaml"
             x:Class="MyNioxApp.MainPage"
             Title="NIOX Bluetooth Scanner">

    <ScrollView>
        <VerticalStackLayout Padding="30" Spacing="15">

            <Label Text="NIOX Bluetooth Scanner"
                   FontSize="28"
                   FontAttributes="Bold"
                   HorizontalOptions="Center"
                   Margin="0,0,0,20" />

            <Button Text="Check Bluetooth State"
                    Clicked="OnCheckBluetoothClicked"
                    BackgroundColor="#0078D4"
                    TextColor="White"
                    HeightRequest="50" />

            <Button Text="Scan All Devices"
                    Clicked="OnScanDevicesClicked"
                    BackgroundColor="#107C10"
                    TextColor="White"
                    HeightRequest="50" />

            <Button Text="Scan NIOX Devices Only"
                    Clicked="OnScanNioxClicked"
                    BackgroundColor="#5E5E5E"
                    TextColor="White"
                    HeightRequest="50" />

            <Button Text="Stop Scan"
                    Clicked="OnStopScanClicked"
                    BackgroundColor="#D83B01"
                    TextColor="White"
                    HeightRequest="50" />

            <Label x:Name="StatusLabel"
                   Text="Ready"
                   FontSize="18"
                   HorizontalOptions="Center"
                   Margin="0,20,0,10"
                   FontAttributes="Bold" />

            <Label Text="Discovered Devices:"
                   FontSize="16"
                   FontAttributes="Bold"
                   Margin="0,10,0,5" />

            <ListView x:Name="DevicesListView"
                      HeightRequest="300"
                      BackgroundColor="#F0F0F0">
                <ListView.ItemTemplate>
                    <DataTemplate>
                        <TextCell Text="{Binding .}"
                                  TextColor="Black" />
                    </DataTemplate>
                </ListView.ItemTemplate>
            </ListView>

        </VerticalStackLayout>
    </ScrollView>

</ContentPage>
```

### Step 9: Build and Run

```bash
# Build for Windows
dotnet build -f net8.0-windows10.0.19041.0

# Run on Windows
dotnet run -f net8.0-windows10.0.19041.0
```

---

## Alternative: Native DLL Method

⚠️ **Warning:** The native DLL is a stub implementation with limited functionality. Use IKVM method instead.

If you still want to try the native DLL:

### Build Native DLL

```bash
# Must be run on Windows
./gradlew :nioxplugin:buildWindowsNativeDll
```

Output: `nioxplugin/build/outputs/windows/NioxCommunicationPlugin.dll`

### Use with P/Invoke

```csharp
using System.Runtime.InteropServices;

public class NioxNativeWrapper
{
    [DllImport("NioxCommunicationPlugin.dll", CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr checkBluetoothState();

    [DllImport("NioxCommunicationPlugin.dll", CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr scanForDevices(int durationMs);

    // ... wrapper methods
}
```

⚠️ **Note:** This requires you to define the C API exports in the Kotlin/Native code, which are not implemented yet.

---

## Complete MAUI Integration Example

### Project Structure

```
MyNioxApp/
├── Libraries/
│   └── NioxPlugin.dll          ← IKVM-converted DLL
├── Platforms/
│   └── Windows/
│       └── app.manifest        ← (optional) for permissions
├── Services/
│   └── NioxBluetoothService.cs ← Bluetooth wrapper
├── MainPage.xaml               ← UI
├── MainPage.xaml.cs            ← Code-behind
└── MyNioxApp.csproj            ← Project file
```

### Testing Your Integration

1. **Check DLL is copied:**
   ```bash
   ls -la bin/Debug/net8.0-windows10.0.19041.0/win10-x64/
   # Should see NioxPlugin.dll
   ```

2. **Verify Bluetooth is working:**
   - Click "Check Bluetooth State" → should show ENABLED/DISABLED
   - Click "Scan All Devices" → should discover Bluetooth devices
   - Click "Scan NIOX Devices Only" → filters for NIOX devices

3. **Common issues:**
   - DLL not found → Check `<CopyToOutputDirectory>` in `.csproj`
   - Bluetooth not working → Check Windows Bluetooth is enabled
   - Scan returns 0 devices → Increase scan duration to 15000ms

---

## Troubleshooting

### Issue: "Could not load file or assembly 'NioxPlugin'"

**Solution:**
```xml
<!-- Add to .csproj -->
<ItemGroup>
  <None Update="Libraries\NioxPlugin.dll">
    <CopyToOutputDirectory>Always</CopyToOutputDirectory>
  </None>
</ItemGroup>
```

### Issue: "Java types not recognized (com.niox.nioxplugin)"

**Solution:** Ensure IKVM package is installed:
```bash
dotnet add package IKVM --version 8.7.5
```

### Issue: "No devices found during scan"

**Solutions:**
1. Increase scan duration: `ScanForDevicesAsync(30000)`
2. Ensure Bluetooth devices are discoverable
3. Check Windows Bluetooth is enabled
4. Try removing service UUID filter

### Issue: "Bluetooth state returns UNSUPPORTED"

**Solutions:**
1. Verify Windows has Bluetooth adapter
2. Check Device Manager → Bluetooth
3. Update Bluetooth drivers
4. Run app as Administrator (test only)

### Issue: "KotlinContinuation throws exceptions"

**Solution:** Wrap all plugin calls in try-catch:
```csharp
try
{
    var state = await _bluetoothService.CheckBluetoothStateAsync();
}
catch (Exception ex)
{
    Console.WriteLine($"Error: {ex.Message}");
}
```

---

## Performance Tips

1. **Scan Duration:** Start with 10 seconds, increase if needed
2. **Background Scanning:** Use `Task.Run()` to avoid UI blocking
3. **Resource Cleanup:** Always call `StopScan()` when done
4. **Caching:** Store scan results to avoid repeated scans

---

## Platform-Specific Notes

### Windows Limitations
- Uses **Bluetooth Classic API** (not BLE)
- RSSI (signal strength) always returns `null`
- UUID filtering done in software (scans all devices first)

### MAUI Cross-Platform
- Use `#if WINDOWS` directives for Windows-only code
- Android/iOS need separate implementations
- Consider platform abstractions/interfaces

---

## Next Steps

1. ✅ Convert JAR to DLL using IKVM
2. ✅ Add DLL reference to MAUI project
3. ✅ Create wrapper service
4. ✅ Implement UI
5. ✅ Test Bluetooth functionality
6. 📱 Add Android/iOS implementations (use separate native libraries)

---

## Additional Resources

- [CSHARP_MAUI_INTEGRATION.md](CSHARP_MAUI_INTEGRATION.md) - Detailed integration guide
- [IKVM.NET Documentation](https://ikvm.net/) - JAR to DLL conversion
- [.NET MAUI Docs](https://learn.microsoft.com/en-us/dotnet/maui/) - MAUI framework
- [Windows Bluetooth API](https://learn.microsoft.com/en-us/windows/uwp/devices-sensors/bluetooth) - Platform reference

---

**Version:** 1.0.0
**Last Updated:** October 23, 2024
**Tested With:** .NET 8.0, MAUI, Windows 11
