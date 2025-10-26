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
            var hWnd = WinRT.Interop.WindowNative.GetWindowHandle(this);
            var windowId = Microsoft.UI.Win32Interop.GetWindowIdFromWindow(hWnd);
            var appWindow = Microsoft.UI.Windowing.AppWindow.GetFromWindowId(windowId);

            appWindow.Resize(new Windows.Graphics.SizeInt32(800, 600));
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

        private async void DiagnosticsButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                StatusBarText.Text = "Running DLL diagnostics...";

                // Run diagnostics on background thread
                string diagnosticsReport = await System.Threading.Tasks.Task.Run(() =>
                {
                    string basicDiag = DllDiagnostics.RunDiagnostics();

                    // Add export analysis
                    string appDir = AppDomain.CurrentDomain.BaseDirectory;
                    string dllPath = System.IO.Path.Combine(appDir, "NioxCommunicationPlugin.dll");

                    if (System.IO.File.Exists(dllPath))
                    {
                        basicDiag += "\n\n" + DllExportChecker.ListExports(dllPath);
                    }

                    return basicDiag;
                });

                // Show results in a dialog
                var dialog = new ContentDialog
                {
                    Title = "DLL Diagnostics Report",
                    Content = new ScrollViewer
                    {
                        Content = new TextBlock
                        {
                            Text = diagnosticsReport,
                            FontFamily = new Microsoft.UI.Xaml.Media.FontFamily("Consolas"),
                            FontSize = 12,
                            TextWrapping = TextWrapping.Wrap,
                            IsTextSelectionEnabled = true
                        },
                        MaxHeight = 500
                    },
                    CloseButtonText = "Close",
                    XamlRoot = this.Content.XamlRoot
                };

                await dialog.ShowAsync();
                StatusBarText.Text = "Diagnostics complete";
            }
            catch (Exception ex)
            {
                ShowError($"Diagnostics failed: {ex.Message}");
            }
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
