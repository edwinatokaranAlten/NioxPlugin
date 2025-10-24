# Step-by-Step: Build a WinUI App Using NIOX Bluetooth DLL

This guide walks you through creating a WinUI 3 application that uses the `NioxCommunicationPlugin.dll` for Bluetooth functionality.

## Prerequisites

- Visual Studio 2022 (17.0 or later)
- Windows 10 SDK (10.0.19041.0 or later)
- Windows App SDK
- The built `NioxCommunicationPlugin.dll`

---

## Step 1: Create a New WinUI 3 Project

### 1.1 Open Visual Studio 2022

### 1.2 Create New Project
1. Click **File → New → Project**
2. Search for **"Blank App, Packaged (WinUI 3 in Desktop)"**
3. Click **Next**

### 1.3 Configure Project
- **Project name**: `NioxBluetoothApp`
- **Location**: Choose your preferred location
- **Solution name**: `NioxBluetoothApp`
- Click **Create**

### 1.4 Select Framework
- Target version: **Windows 10, version 2004 (build 19041)**
- Minimum version: **Windows 10, version 2004 (build 19041)**
- Click **OK**

Visual Studio will create your WinUI project with the following structure:
```
NioxBluetoothApp/
├── App.xaml
├── App.xaml.cs
├── MainWindow.xaml
├── MainWindow.xaml.cs
├── Package.appxmanifest
└── NioxBluetoothApp.csproj
```

---

## Step 2: Add the NIOX DLL to Your Project

### 2.1 Create Native Libraries Folder
1. In **Solution Explorer**, right-click on your project
2. Select **Add → New Folder**
3. Name it: `NativeLibs`

### 2.2 Copy the DLL
Copy your built DLL to the NativeLibs folder:
```powershell
Copy-Item "C:\Users\eatokaran\Desktop\NioxPlugin\NioxPlugin\nioxplugin\build\outputs\windows\NioxCommunicationPlugin.dll" -Destination "NioxBluetoothApp\NativeLibs\"
```

### 2.3 Add DLL to Project
1. In **Solution Explorer**, right-click **NativeLibs** folder
2. Select **Add → Existing Item**
3. Browse to `NativeLibs\NioxCommunicationPlugin.dll`
4. Click **Add**

### 2.4 Set DLL Properties
1. Right-click on **NioxCommunicationPlugin.dll** in Solution Explorer
2. Select **Properties**
3. Set the following:
   - **Build Action**: `Content`
   - **Copy to Output Directory**: `Copy if newer`

### 2.5 Update .csproj File
Open `NioxBluetoothApp.csproj` and add this inside the `<Project>` tag:

```xml
<ItemGroup>
  <Content Include="NativeLibs\NioxCommunicationPlugin.dll">
    <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
  </Content>
</ItemGroup>
```

---

## Step 3: Create the Bluetooth Service Class

### 3.1 Create Services Folder
1. Right-click project → **Add → New Folder**
2. Name it: `Services`

### 3.2 Create BluetoothService.cs
1. Right-click **Services** folder → **Add → Class**
2. Name: `BluetoothService.cs`
3. Replace the content with:

```csharp
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading.Tasks;

namespace NioxBluetoothApp.Services
{
    public class BluetoothService
    {
        private const string DllName = "NioxCommunicationPlugin.dll";

        #region P/Invoke Declarations

        // Opaque pointer to plugin instance
        private IntPtr _pluginHandle = IntPtr.Zero;

        // Create plugin instance
        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        private static extern IntPtr createNioxCommunicationPlugin();

        // Check Bluetooth state
        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        private static extern int checkBluetoothState(IntPtr plugin);

        // Scan for devices (returns JSON string)
        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        private static extern IntPtr scanForDevices(IntPtr plugin, long durationMs, string serviceUuid);

        // Free string memory allocated by DLL
        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        private static extern void freeString(IntPtr str);

        // Free plugin instance
        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        private static extern void disposePlugin(IntPtr plugin);

        #endregion

        #region Enums and Models

        public enum BluetoothState
        {
            Enabled = 0,
            Disabled = 1,
            Unsupported = 2,
            Unknown = 3
        }

        public class BluetoothDevice
        {
            public string Name { get; set; }
            public string Address { get; set; }
            public int? Rssi { get; set; }
            public bool IsNioxDevice { get; set; }
            public string SerialNumber { get; set; }
        }

        #endregion

        #region Constructor and Initialization

        public BluetoothService()
        {
            // Create plugin instance
            _pluginHandle = createNioxCommunicationPlugin();
            if (_pluginHandle == IntPtr.Zero)
            {
                throw new Exception("Failed to create Bluetooth plugin instance");
            }
        }

        ~BluetoothService()
        {
            Dispose();
        }

        public void Dispose()
        {
            if (_pluginHandle != IntPtr.Zero)
            {
                disposePlugin(_pluginHandle);
                _pluginHandle = IntPtr.Zero;
            }
        }

        #endregion

        #region Public Methods

        /// <summary>
        /// Check the Bluetooth adapter state
        /// </summary>
        public async Task<BluetoothState> CheckBluetoothStateAsync()
        {
            return await Task.Run(() =>
            {
                try
                {
                    if (_pluginHandle == IntPtr.Zero)
                        return BluetoothState.Unknown;

                    int state = checkBluetoothState(_pluginHandle);
                    return (BluetoothState)state;
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"Error checking Bluetooth state: {ex.Message}");
                    return BluetoothState.Unknown;
                }
            });
        }

        /// <summary>
        /// Scan for Bluetooth devices
        /// </summary>
        /// <param name="durationMs">Scan duration in milliseconds</param>
        /// <param name="nioxOnly">If true, only scan for NIOX devices</param>
        public async Task<List<BluetoothDevice>> ScanForDevicesAsync(int durationMs = 10000, bool nioxOnly = true)
        {
            return await Task.Run(() =>
            {
                var devices = new List<BluetoothDevice>();

                try
                {
                    if (_pluginHandle == IntPtr.Zero)
                        return devices;

                    // NIOX service UUID (or null for all devices)
                    string serviceUuid = nioxOnly ? "000fc00b-8a4-4078-874c-14efbd4b510a" : null;

                    // Call native DLL
                    IntPtr resultPtr = scanForDevices(_pluginHandle, durationMs, serviceUuid);

                    if (resultPtr != IntPtr.Zero)
                    {
                        // Convert native string to managed string
                        string jsonResult = Marshal.PtrToStringAnsi(resultPtr);

                        // Free native memory
                        freeString(resultPtr);

                        // Parse JSON result
                        if (!string.IsNullOrEmpty(jsonResult))
                        {
                            devices = ParseDevicesFromJson(jsonResult);
                        }
                    }
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"Error scanning devices: {ex.Message}");
                }

                return devices;
            });
        }

        #endregion

        #region Helper Methods

        private List<BluetoothDevice> ParseDevicesFromJson(string json)
        {
            var devices = new List<BluetoothDevice>();

            try
            {
                // Simple JSON parsing (you can use System.Text.Json or Newtonsoft.Json for production)
                // Expected format: [{"name":"NIOX-12345","address":"00:11:22:33:44:55","rssi":null}]

                // For now, return a simple parsed result
                // TODO: Implement proper JSON parsing with System.Text.Json

                var jsonDoc = System.Text.Json.JsonDocument.Parse(json);
                var root = jsonDoc.RootElement;

                if (root.ValueKind == System.Text.Json.JsonValueKind.Array)
                {
                    foreach (var element in root.EnumerateArray())
                    {
                        var device = new BluetoothDevice
                        {
                            Name = element.TryGetProperty("name", out var nameEl) ? nameEl.GetString() : "Unknown",
                            Address = element.TryGetProperty("address", out var addrEl) ? addrEl.GetString() : "",
                            Rssi = element.TryGetProperty("rssi", out var rssiEl) && rssiEl.ValueKind == System.Text.Json.JsonValueKind.Number
                                ? rssiEl.GetInt32()
                                : (int?)null,
                            IsNioxDevice = element.TryGetProperty("isNioxDevice", out var isNioxEl) && isNioxEl.GetBoolean(),
                            SerialNumber = element.TryGetProperty("serialNumber", out var serialEl) ? serialEl.GetString() : ""
                        };

                        devices.Add(device);
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Error parsing JSON: {ex.Message}");
            }

            return devices;
        }

        #endregion
    }
}
```

---

## Step 4: Design the User Interface

### 4.1 Open MainWindow.xaml

Replace the contents with:

```xml
<?xml version="1.0" encoding="utf-8"?>
<Window
    x:Class="NioxBluetoothApp.MainWindow"
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
    xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    mc:Ignorable="d"
    Title="NIOX Bluetooth Scanner"
    Width="800"
    Height="600">

    <Grid Padding="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Title -->
        <TextBlock
            Grid.Row="0"
            Text="NIOX Bluetooth Device Scanner"
            FontSize="24"
            FontWeight="Bold"
            Margin="0,0,0,20"/>

        <!-- Bluetooth Status -->
        <StackPanel
            Grid.Row="1"
            Orientation="Horizontal"
            Spacing="10"
            Margin="0,0,0,20">
            <TextBlock
                Text="Bluetooth Status:"
                FontSize="16"
                VerticalAlignment="Center"/>
            <TextBlock
                x:Name="BluetoothStatusText"
                Text="Checking..."
                FontSize="16"
                FontWeight="SemiBold"
                Foreground="Gray"
                VerticalAlignment="Center"/>
        </StackPanel>

        <!-- Scan Controls -->
        <StackPanel
            Grid.Row="2"
            Orientation="Horizontal"
            Spacing="10"
            Margin="0,0,0,20">
            <Button
                x:Name="ScanButton"
                Content="Scan for Devices"
                Click="ScanButton_Click"
                MinWidth="150"
                Style="{StaticResource AccentButtonStyle}"/>
            <Button
                x:Name="RefreshStatusButton"
                Content="Refresh Status"
                Click="RefreshStatusButton_Click"
                MinWidth="150"/>
            <CheckBox
                x:Name="NioxOnlyCheckBox"
                Content="NIOX Devices Only"
                IsChecked="True"
                VerticalAlignment="Center"/>
        </StackPanel>

        <!-- Device List -->
        <Grid Grid.Row="3">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>

            <TextBlock
                Grid.Row="0"
                Text="Discovered Devices:"
                FontSize="16"
                FontWeight="SemiBold"
                Margin="0,0,0,10"/>

            <ListView
                x:Name="DeviceListView"
                Grid.Row="1"
                SelectionMode="Single">
                <ListView.ItemTemplate>
                    <DataTemplate>
                        <StackPanel Padding="10" Spacing="5">
                            <TextBlock
                                Text="{Binding Name}"
                                FontSize="16"
                                FontWeight="SemiBold"/>
                            <StackPanel Orientation="Horizontal" Spacing="15">
                                <TextBlock
                                    Text="{Binding Address}"
                                    Foreground="Gray"/>
                                <TextBlock
                                    Text="{Binding IsNioxDevice}"
                                    Foreground="Green"
                                    Visibility="{Binding IsNioxDevice}"/>
                            </StackPanel>
                            <TextBlock
                                Text="{Binding SerialNumber}"
                                Foreground="Blue"
                                FontSize="12"
                                Visibility="{Binding HasSerialNumber}"/>
                        </StackPanel>
                    </DataTemplate>
                </ListView.ItemTemplate>
            </ListView>
        </Grid>

        <!-- Status Bar -->
        <Border
            Grid.Row="4"
            Background="{ThemeResource CardBackgroundFillColorDefaultBrush}"
            CornerRadius="4"
            Padding="15,10"
            Margin="0,20,0,0">
            <TextBlock
                x:Name="StatusBarText"
                Text="Ready"
                FontSize="14"/>
        </Border>
    </Grid>
</Window>
```

---

## Step 5: Implement the Code-Behind

### 5.1 Open MainWindow.xaml.cs

Replace the contents with:

```csharp
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using NioxBluetoothApp.Services;
using System;
using System.Collections.Generic;
using System.Linq;

namespace NioxBluetoothApp
{
    public sealed partial class MainWindow : Window
    {
        private BluetoothService _bluetoothService;

        public MainWindow()
        {
            this.InitializeComponent();
            InitializeBluetoothService();
        }

        private async void InitializeBluetoothService()
        {
            try
            {
                // Create Bluetooth service instance
                _bluetoothService = new BluetoothService();

                // Check initial Bluetooth state
                await CheckBluetoothStatusAsync();
            }
            catch (Exception ex)
            {
                ShowError($"Failed to initialize Bluetooth: {ex.Message}");
            }
        }

        private async System.Threading.Tasks.Task CheckBluetoothStatusAsync()
        {
            try
            {
                StatusBarText.Text = "Checking Bluetooth status...";

                var state = await _bluetoothService.CheckBluetoothStateAsync();

                switch (state)
                {
                    case BluetoothService.BluetoothState.Enabled:
                        BluetoothStatusText.Text = "✅ Enabled";
                        BluetoothStatusText.Foreground = new Microsoft.UI.Xaml.Media.SolidColorBrush(
                            Microsoft.UI.Colors.Green);
                        ScanButton.IsEnabled = true;
                        StatusBarText.Text = "Bluetooth is ready";
                        break;

                    case BluetoothService.BluetoothState.Disabled:
                        BluetoothStatusText.Text = "❌ Disabled";
                        BluetoothStatusText.Foreground = new Microsoft.UI.Xaml.Media.SolidColorBrush(
                            Microsoft.UI.Colors.Red);
                        ScanButton.IsEnabled = false;
                        StatusBarText.Text = "Please enable Bluetooth";
                        break;

                    case BluetoothService.BluetoothState.Unsupported:
                        BluetoothStatusText.Text = "⚠️ Not Supported";
                        BluetoothStatusText.Foreground = new Microsoft.UI.Xaml.Media.SolidColorBrush(
                            Microsoft.UI.Colors.Orange);
                        ScanButton.IsEnabled = false;
                        StatusBarText.Text = "Bluetooth not supported on this device";
                        break;

                    default:
                        BluetoothStatusText.Text = "❓ Unknown";
                        BluetoothStatusText.Foreground = new Microsoft.UI.Xaml.Media.SolidColorBrush(
                            Microsoft.UI.Colors.Gray);
                        ScanButton.IsEnabled = false;
                        StatusBarText.Text = "Could not determine Bluetooth status";
                        break;
                }
            }
            catch (Exception ex)
            {
                ShowError($"Error checking Bluetooth status: {ex.Message}");
            }
        }

        private async void ScanButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                // Disable button during scan
                ScanButton.IsEnabled = false;
                StatusBarText.Text = "Scanning for devices...";
                DeviceListView.Items.Clear();

                // Get scan settings
                bool nioxOnly = NioxOnlyCheckBox.IsChecked ?? true;
                int scanDuration = 10000; // 10 seconds

                // Perform scan
                var devices = await _bluetoothService.ScanForDevicesAsync(scanDuration, nioxOnly);

                // Display results
                if (devices.Count > 0)
                {
                    foreach (var device in devices)
                    {
                        DeviceListView.Items.Add(new DeviceViewModel
                        {
                            Name = device.Name ?? "Unknown Device",
                            Address = device.Address,
                            IsNioxDevice = device.IsNioxDevice,
                            SerialNumber = device.SerialNumber,
                            HasSerialNumber = !string.IsNullOrEmpty(device.SerialNumber)
                        });
                    }

                    StatusBarText.Text = $"Found {devices.Count} device(s)";
                }
                else
                {
                    StatusBarText.Text = "No devices found";
                }
            }
            catch (Exception ex)
            {
                ShowError($"Error scanning devices: {ex.Message}");
            }
            finally
            {
                // Re-enable button
                ScanButton.IsEnabled = true;
            }
        }

        private async void RefreshStatusButton_Click(object sender, RoutedEventArgs e)
        {
            await CheckBluetoothStatusAsync();
        }

        private void ShowError(string message)
        {
            StatusBarText.Text = message;
            BluetoothStatusText.Text = "❌ Error";
            BluetoothStatusText.Foreground = new Microsoft.UI.Xaml.Media.SolidColorBrush(
                Microsoft.UI.Colors.Red);
        }

        // ViewModel for device list items
        private class DeviceViewModel
        {
            public string Name { get; set; }
            public string Address { get; set; }
            public bool IsNioxDevice { get; set; }
            public string SerialNumber { get; set; }
            public bool HasSerialNumber { get; set; }
        }
    }
}
```

---

## Step 6: Build and Run

### 6.1 Build the Project
1. Press **F6** or select **Build → Build Solution**
2. Check the **Output** window for any errors
3. Ensure the build succeeds

### 6.2 Run the Application
1. Press **F5** or click **Debug → Start Debugging**
2. The WinUI app should launch

### 6.3 Test the App
1. **Check Bluetooth Status**: Should show "✅ Enabled" if Bluetooth is on
2. **Click "Scan for Devices"**: Will scan for 10 seconds
3. **View Results**: Devices appear in the list with name and address
4. **NIOX Filter**: Toggle checkbox to scan all devices or NIOX only

---

## Step 7: Troubleshooting

### Problem: DLL Not Found Error

**Error**: `System.DllNotFoundException: Unable to load DLL 'NioxCommunicationPlugin.dll'`

**Solution**:
1. Verify DLL is in `NativeLibs` folder
2. Check `.csproj` has correct `<Content Include>` entry
3. Verify DLL properties: `Copy to Output Directory = Copy if newer`
4. Check `bin\x64\Debug\net6.0-windows10.0.19041.0\` has the DLL

### Problem: P/Invoke Signature Mismatch

**Error**: `System.EntryPointNotFoundException`

**Solution**:
1. Verify function names match DLL exports
2. Check calling convention is `CallingConvention.Cdecl`
3. Use `dumpbin /exports NioxCommunicationPlugin.dll` to verify exports

### Problem: App Crashes on Startup

**Solution**:
1. Wrap service initialization in try-catch
2. Check Windows Event Viewer for crash details
3. Enable native debugging: Project Properties → Debug → Enable Native Code Debugging

### Problem: No Devices Found

**Solution**:
1. Ensure Bluetooth is enabled on your PC
2. Make sure Bluetooth devices are discoverable
3. Try increasing scan duration to 15000ms (15 seconds)
4. Uncheck "NIOX Devices Only" to scan all devices

---

## Step 8: Optional Enhancements

### 8.1 Add Progress Bar
Add to XAML before the Device List:
```xml
<ProgressBar
    x:Name="ScanProgressBar"
    IsIndeterminate="True"
    Visibility="Collapsed"
    Margin="0,0,0,10"/>
```

In code, show/hide during scan:
```csharp
ScanProgressBar.Visibility = Visibility.Visible; // Before scan
ScanProgressBar.Visibility = Visibility.Collapsed; // After scan
```

### 8.2 Add Device Details Panel
Show more information when a device is selected.

### 8.3 Add Connect Button
Implement connection functionality for NIOX devices.

### 8.4 Save Scan History
Store scan results in a database or JSON file.

---

## Complete Project Structure

```
NioxBluetoothApp/
├── NativeLibs/
│   └── NioxCommunicationPlugin.dll
├── Services/
│   └── BluetoothService.cs
├── App.xaml
├── App.xaml.cs
├── MainWindow.xaml
├── MainWindow.xaml.cs
├── Package.appxmanifest
└── NioxBluetoothApp.csproj
```

---

## Summary

You now have a complete WinUI 3 application that:
- ✅ Uses the native NIOX Bluetooth DLL
- ✅ Checks Bluetooth adapter state
- ✅ Scans for Bluetooth devices
- ✅ Filters NIOX PRO devices
- ✅ Displays device information in a list
- ✅ Has a clean, modern UI

The app uses **P/Invoke** to call the native DLL functions directly - no JVM required!

---

## Next Steps

1. **Test with real NIOX devices**
2. **Add device connection functionality**
3. **Implement data collection features**
4. **Add error logging and diagnostics**
5. **Package for distribution**

For more details on the DLL API, see [WINDOWS_NATIVE_DLL_GUIDE.md](WINDOWS_NATIVE_DLL_GUIDE.md)
