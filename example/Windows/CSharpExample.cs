// C# Example: Using NIOX Communication Plugin WinRT DLL
// This demonstrates how to use the native DLL from a C# application

using System;
using System.Runtime.InteropServices;
using System.Text;

namespace NioxExample
{
    /// <summary>
    /// C# wrapper for NIOX Communication Plugin WinRT DLL
    /// </summary>
    public class NioxBluetoothScanner
    {
        // DLL imports - make sure NioxCommunicationPluginWinRT.dll is in your application directory
        [DllImport("NioxCommunicationPluginWinRT.dll", CallingConvention = CallingConvention.Cdecl)]
        private static extern int niox_init();

        [DllImport("NioxCommunicationPluginWinRT.dll", CallingConvention = CallingConvention.Cdecl)]
        private static extern int niox_check_bluetooth();

        [DllImport("NioxCommunicationPluginWinRT.dll", CallingConvention = CallingConvention.Cdecl)]
        private static extern IntPtr niox_scan_devices(long durationMs, int nioxOnly);

        [DllImport("NioxCommunicationPluginWinRT.dll", CallingConvention = CallingConvention.Cdecl)]
        private static extern void niox_free_string(IntPtr ptr);

        [DllImport("NioxCommunicationPluginWinRT.dll", CallingConvention = CallingConvention.Cdecl)]
        private static extern void niox_cleanup();

        [DllImport("NioxCommunicationPluginWinRT.dll", CallingConvention = CallingConvention.Cdecl)]
        private static extern IntPtr niox_version();

        [DllImport("NioxCommunicationPluginWinRT.dll", CallingConvention = CallingConvention.Cdecl)]
        private static extern IntPtr niox_implementation();

        /// <summary>
        /// Bluetooth state enumeration
        /// </summary>
        public enum BluetoothState
        {
            Enabled = 0,
            Disabled = 1,
            Unsupported = 2,
            Unknown = 3
        }

        /// <summary>
        /// Represents a discovered Bluetooth device
        /// </summary>
        public class BluetoothDevice
        {
            public string Name { get; set; }
            public string Address { get; set; }
            public int? Rssi { get; set; }
            public bool IsNioxDevice { get; set; }
            public string SerialNumber { get; set; }
        }

        private bool isInitialized = false;

        /// <summary>
        /// Initialize the NIOX plugin
        /// </summary>
        public bool Initialize()
        {
            if (isInitialized)
                return true;

            int result = niox_init();
            isInitialized = (result == 1);
            return isInitialized;
        }

        /// <summary>
        /// Check the current Bluetooth adapter state
        /// </summary>
        public BluetoothState CheckBluetoothState()
        {
            if (!isInitialized && !Initialize())
                return BluetoothState.Unknown;

            int state = niox_check_bluetooth();
            return (BluetoothState)state;
        }

        /// <summary>
        /// Scan for Bluetooth devices
        /// </summary>
        /// <param name="durationMs">Scan duration in milliseconds (default: 10000)</param>
        /// <param name="nioxOnly">True to scan only for NIOX devices, false for all devices</param>
        /// <returns>Array of discovered devices</returns>
        public BluetoothDevice[] ScanForDevices(long durationMs = 10000, bool nioxOnly = true)
        {
            if (!isInitialized && !Initialize())
                return new BluetoothDevice[0];

            // Call native function
            IntPtr resultPtr = niox_scan_devices(durationMs, nioxOnly ? 1 : 0);

            if (resultPtr == IntPtr.Zero)
                return new BluetoothDevice[0];

            try
            {
                // Convert JSON result to string
                string jsonResult = Marshal.PtrToStringAnsi(resultPtr);

                // Free the native string
                niox_free_string(resultPtr);

                if (string.IsNullOrEmpty(jsonResult))
                    return new BluetoothDevice[0];

                // Parse JSON (using System.Text.Json or Newtonsoft.Json)
                return ParseDevicesFromJson(jsonResult);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error parsing scan results: {ex.Message}");
                return new BluetoothDevice[0];
            }
        }

        /// <summary>
        /// Get the plugin version
        /// </summary>
        public string GetVersion()
        {
            IntPtr versionPtr = niox_version();
            if (versionPtr == IntPtr.Zero)
                return "Unknown";

            return Marshal.PtrToStringAnsi(versionPtr);
        }

        /// <summary>
        /// Get the implementation type
        /// </summary>
        public string GetImplementation()
        {
            IntPtr implPtr = niox_implementation();
            if (implPtr == IntPtr.Zero)
                return "Unknown";

            return Marshal.PtrToStringAnsi(implPtr);
        }

        /// <summary>
        /// Cleanup and release resources
        /// </summary>
        public void Cleanup()
        {
            if (isInitialized)
            {
                niox_cleanup();
                isInitialized = false;
            }
        }

        /// <summary>
        /// Parse JSON device array (simple implementation)
        /// For production, use System.Text.Json or Newtonsoft.Json
        /// </summary>
        private BluetoothDevice[] ParseDevicesFromJson(string json)
        {
            // This is a simplified parser - use a proper JSON library in production
            var devices = new System.Collections.Generic.List<BluetoothDevice>();

            try
            {
                // Remove brackets
                json = json.Trim('[', ']');

                if (string.IsNullOrWhiteSpace(json))
                    return new BluetoothDevice[0];

                // Split by device objects
                var deviceStrings = json.Split(new[] { "},{" }, StringSplitOptions.RemoveEmptyEntries);

                foreach (var deviceStr in deviceStrings)
                {
                    var device = new BluetoothDevice();
                    var cleanStr = deviceStr.Trim('{', '}');

                    // Parse fields (simplified - use JSON library for production)
                    var fields = cleanStr.Split(',');
                    foreach (var field in fields)
                    {
                        var parts = field.Split(new[] { ':' }, 2);
                        if (parts.Length != 2) continue;

                        var key = parts[0].Trim('"', ' ');
                        var value = parts[1].Trim('"', ' ');

                        switch (key)
                        {
                            case "name":
                                device.Name = value.Equals("Unknown", StringComparison.OrdinalIgnoreCase) ? null : value;
                                break;
                            case "address":
                                device.Address = value;
                                break;
                            case "rssi":
                                if (int.TryParse(value, out int rssi))
                                    device.Rssi = rssi;
                                break;
                            case "isNioxDevice":
                                device.IsNioxDevice = value.Equals("true", StringComparison.OrdinalIgnoreCase);
                                break;
                            case "serialNumber":
                                device.SerialNumber = value.Equals("null", StringComparison.OrdinalIgnoreCase) ? null : value;
                                break;
                        }
                    }

                    devices.Add(device);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error parsing JSON: {ex.Message}");
            }

            return devices.ToArray();
        }
    }

    /// <summary>
    /// Example usage
    /// </summary>
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("NIOX Bluetooth Scanner - C# Example");
            Console.WriteLine("=====================================\n");

            var scanner = new NioxBluetoothScanner();

            // Initialize
            Console.WriteLine("Initializing...");
            if (!scanner.Initialize())
            {
                Console.WriteLine("Failed to initialize NIOX plugin");
                return;
            }

            Console.WriteLine($"Plugin Version: {scanner.GetVersion()}");
            Console.WriteLine($"Implementation: {scanner.GetImplementation()}\n");

            // Check Bluetooth state
            Console.WriteLine("Checking Bluetooth state...");
            var state = scanner.CheckBluetoothState();
            Console.WriteLine($"Bluetooth State: {state}\n");

            if (state != NioxBluetoothScanner.BluetoothState.Enabled)
            {
                Console.WriteLine("Bluetooth is not enabled. Please enable Bluetooth and try again.");
                scanner.Cleanup();
                return;
            }

            // Scan for NIOX devices
            Console.WriteLine("Scanning for NIOX devices (10 seconds)...");
            var devices = scanner.ScanForDevices(durationMs: 10000, nioxOnly: true);

            Console.WriteLine($"\nFound {devices.Length} device(s):\n");

            foreach (var device in devices)
            {
                Console.WriteLine($"Device: {device.Name ?? "Unknown"}");
                Console.WriteLine($"  Address: {device.Address}");
                Console.WriteLine($"  RSSI: {device.Rssi ?? 0} dBm");
                Console.WriteLine($"  Is NIOX: {device.IsNioxDevice}");
                if (!string.IsNullOrEmpty(device.SerialNumber))
                {
                    Console.WriteLine($"  Serial: {device.SerialNumber}");
                }
                Console.WriteLine();
            }

            // Scan for all devices
            Console.WriteLine("\nScanning for ALL Bluetooth devices (10 seconds)...");
            var allDevices = scanner.ScanForDevices(durationMs: 10000, nioxOnly: false);

            Console.WriteLine($"\nFound {allDevices.Length} device(s) total\n");

            int nioxCount = 0;
            foreach (var device in allDevices)
            {
                if (device.IsNioxDevice)
                {
                    nioxCount++;
                    Console.WriteLine($"NIOX: {device.Name} ({device.Address}) - {device.Rssi} dBm");
                }
            }

            Console.WriteLine($"\n{nioxCount} NIOX devices out of {allDevices.Length} total");

            // Cleanup
            Console.WriteLine("\nCleaning up...");
            scanner.Cleanup();

            Console.WriteLine("Done!");
            Console.ReadKey();
        }
    }
}
