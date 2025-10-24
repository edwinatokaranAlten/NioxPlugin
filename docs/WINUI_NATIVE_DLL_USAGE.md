# Using Windows Native DLL in WinUI App

The Windows Native DLL (`NioxCommunicationPlugin.dll`) is the recommended approach for WinUI apps.

## Setup

1. Build the Native DLL:
   ```powershell
   .\build-native-dll.ps1
   ```

2. Copy DLL to your WinUI project:
   ```
   YourWinUIProject/
   ├── NativeLibs/
   │   └── NioxCommunicationPlugin.dll
   ```

3. Add DLL to your project file (.csproj):
   ```xml
   <ItemGroup>
     <Content Include="NativeLibs\NioxCommunicationPlugin.dll">
       <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
     </Content>
   </ItemGroup>
   ```

## C# P/Invoke Wrapper

Create a C# wrapper class:

```csharp
using System.Runtime.InteropServices;

namespace YourApp.Bluetooth
{
    public class NioxBluetoothPlugin
    {
        private const string DllName = "NioxCommunicationPlugin.dll";

        // Check Bluetooth state
        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        private static extern int CheckBluetoothState();

        // Scan for devices
        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        private static extern IntPtr ScanForDevices(int scanDurationMs,
            [MarshalAs(UnmanagedType.LPStr)] string serviceUuid);

        // Free device list memory
        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        private static extern void FreeDeviceList(IntPtr deviceList);

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
        }

        public static BluetoothState GetBluetoothState()
        {
            try
            {
                int state = CheckBluetoothState();
                return (BluetoothState)state;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Error checking Bluetooth: {ex.Message}");
                return BluetoothState.Unknown;
            }
        }

        public static List<BluetoothDevice> ScanDevices(int durationMs = 10000)
        {
            var devices = new List<BluetoothDevice>();

            try
            {
                // NIOX service UUID
                string serviceUuid = "000fc00b-8a4-4078-874c-14efbd4b510a";
                IntPtr deviceListPtr = ScanForDevices(durationMs, serviceUuid);

                if (deviceListPtr != IntPtr.Zero)
                {
                    // Parse device list (format depends on DLL implementation)
                    // You'll need to implement this based on the DLL's return format

                    FreeDeviceList(deviceListPtr);
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Error scanning: {ex.Message}");
            }

            return devices;
        }
    }
}
```

## Usage in WinUI

```csharp
using YourApp.Bluetooth;

public sealed partial class MainWindow : Window
{
    public MainWindow()
    {
        this.InitializeComponent();
        CheckBluetooth();
    }

    private async void CheckBluetooth()
    {
        // Check Bluetooth state
        var state = NioxBluetoothPlugin.GetBluetoothState();

        switch (state)
        {
            case NioxBluetoothPlugin.BluetoothState.Enabled:
                StatusText.Text = "Bluetooth is enabled";
                await ScanForDevices();
                break;
            case NioxBluetoothPlugin.BluetoothState.Disabled:
                StatusText.Text = "Bluetooth is disabled";
                break;
            case NioxBluetoothPlugin.BluetoothState.Unsupported:
                StatusText.Text = "Bluetooth not supported";
                break;
            default:
                StatusText.Text = "Bluetooth state unknown";
                break;
        }
    }

    private async Task ScanForDevices()
    {
        StatusText.Text = "Scanning for devices...";

        var devices = await Task.Run(() =>
            NioxBluetoothPlugin.ScanDevices(10000));

        StatusText.Text = $"Found {devices.Count} devices";

        foreach (var device in devices)
        {
            DeviceList.Items.Add($"{device.Name} - {device.Address}");
        }
    }
}
```

## Notes

- Native DLL has **no JVM dependency**
- Smallest footprint (~500KB)
- Direct P/Invoke - no Java process needed
- Best performance for WinUI apps
