using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading.Tasks;

namespace NioxBluetoothApp.Services
{
    public class BluetoothService
    {
        // Use full path or relative path to DLL
        // The DLL should be in the same directory as the executable
        private const string DllName = "NioxCommunicationPlugin.dll";
        private static bool _initialized = false;

        // Add DLL directory to search path
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool SetDllDirectory(string lpPathName);

        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr LoadLibrary(string lpFileName);

        #region P/Invoke Declarations

        // Initialize plugin (call once at startup)
        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, EntryPoint = "niox_init")]
        private static extern int NioxInit();

        // Check Bluetooth state
        // Returns: 0=ENABLED, 1=DISABLED, 2=UNSUPPORTED, 3=UNKNOWN
        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, EntryPoint = "niox_check_bluetooth")]
        private static extern int NioxCheckBluetooth();

        // Scan for devices
        // Parameters: durationMs (long), nioxOnly (1 or 0)
        // Returns: JSON string pointer (must be freed)
        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, EntryPoint = "niox_scan_devices")]
        private static extern IntPtr NioxScanDevices(long durationMs, int nioxOnly);

        // Free string memory
        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, EntryPoint = "niox_free_string")]
        private static extern void NioxFreeString(IntPtr ptr);

        // Cleanup resources
        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, EntryPoint = "niox_cleanup")]
        private static extern void NioxCleanup();

        // Get version
        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, EntryPoint = "niox_version")]
        private static extern IntPtr NioxGetVersion();

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
            EnsureInitialized();
        }

        ~BluetoothService()
        {
            Cleanup();
        }

        private static void EnsureInitialized()
        {
            if (!_initialized)
            {
                // Try to preload the DLL to get better error messages
                try
                {
                    // Get the application directory
                    string appDir = AppDomain.CurrentDomain.BaseDirectory;
                    string dllPath = System.IO.Path.Combine(appDir, DllName);

                    System.Diagnostics.Debug.WriteLine($"Looking for DLL at: {dllPath}");
                    System.Diagnostics.Debug.WriteLine($"DLL exists: {System.IO.File.Exists(dllPath)}");

                    // Try to load the DLL explicitly
                    IntPtr handle = LoadLibrary(dllPath);
                    if (handle == IntPtr.Zero)
                    {
                        int errorCode = Marshal.GetLastWin32Error();
                        throw new Exception($"Failed to load DLL. Error code: 0x{errorCode:X}. " +
                            $"Make sure the DLL and its dependencies are in: {appDir}");
                    }
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"DLL preload failed: {ex.Message}");
                    // Continue anyway, let P/Invoke try
                }

                int result = NioxInit();
                if (result == 0)
                {
                    throw new Exception("Failed to initialize NIOX Bluetooth plugin");
                }
                _initialized = true;
            }
        }

        public static void Cleanup()
        {
            if (_initialized)
            {
                NioxCleanup();
                _initialized = false;
            }
        }

        #endregion

        #region Public Methods

        /// <summary>
        /// Get the DLL version
        /// </summary>
        public static string GetVersion()
        {
            try
            {
                IntPtr versionPtr = NioxGetVersion();
                if (versionPtr != IntPtr.Zero)
                {
                    return Marshal.PtrToStringAnsi(versionPtr) ?? "Unknown";
                }
                return "Unknown";
            }
            catch
            {
                return "Unknown";
            }
        }

        /// <summary>
        /// Check the Bluetooth adapter state
        /// </summary>
        public async Task<BluetoothState> CheckBluetoothStateAsync()
        {
            return await Task.Run(() =>
            {
                try
                {
                    EnsureInitialized();
                    int state = NioxCheckBluetooth();
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
                    EnsureInitialized();

                    // Call native function
                    IntPtr resultPtr = NioxScanDevices(durationMs, nioxOnly ? 1 : 0);

                    if (resultPtr != IntPtr.Zero)
                    {
                        // Convert native string to managed string
                        string jsonResult = Marshal.PtrToStringAnsi(resultPtr);

                        // Free native memory
                        NioxFreeString(resultPtr);

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
                // Parse JSON using System.Text.Json
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
