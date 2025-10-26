#ifndef WINRT_BLE_WRAPPER_H
#define WINRT_BLE_WRAPPER_H

#ifdef __cplusplus
extern "C" {
#endif

// Device structure for passing data back
typedef struct {
    char* name;
    char* address;
    int rssi;
    int hasRssi;
} BLEDevice;

// Callback function type for device discovery
typedef void (*DeviceFoundCallback)(BLEDevice device, void* userData);

// Initialize WinRT
int winrt_initialize();

// Cleanup WinRT
void winrt_cleanup();

// Check if Bluetooth is available
// Returns: 0=ENABLED, 1=DISABLED, 2=UNSUPPORTED, 3=UNKNOWN
int winrt_check_bluetooth_state();

// Start BLE scan
// Parameters:
//   durationMs: scan duration in milliseconds
//   nioxOnly: 1 for NIOX devices only, 0 for all devices
//   callback: function to call for each discovered device
//   userData: user data to pass to callback
// Returns: 0 on success, -1 on error
int winrt_start_scan(int durationMs, int nioxOnly, DeviceFoundCallback callback, void* userData);

// Stop ongoing scan
void winrt_stop_scan();

// Free string allocated by this library
void winrt_free_string(char* str);

#ifdef __cplusplus
}
#endif

#endif // WINRT_BLE_WRAPPER_H
