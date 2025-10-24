// WinRT BLE Wrapper - C++/WinRT implementation for Bluetooth LE scanning
// This provides a C API wrapper around Windows Runtime Bluetooth APIs

#include "winrt_ble_wrapper.h"
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Devices.Bluetooth.h>
#include <winrt/Windows.Devices.Bluetooth.Advertisement.h>
#include <winrt/Windows.Devices.Radios.h>
#include <string>
#include <vector>
#include <memory>
#include <chrono>
#include <thread>

using namespace winrt;
using namespace Windows::Devices::Bluetooth;
using namespace Windows::Devices::Bluetooth::Advertisement;
using namespace Windows::Devices::Radios;
using namespace Windows::Foundation;

// Global state
static bool g_initialized = false;
static std::unique_ptr<BluetoothLEAdvertisementWatcher> g_watcher;
static std::vector<BLEDevice> g_discovered_devices;
static DeviceFoundCallback g_callback = nullptr;
static void* g_user_data = nullptr;
static bool g_niox_only = false;
static const char* NIOX_PREFIX = "NIOX PRO";

// Helper: Convert wide string to allocated char*
char* wstring_to_cstring(const std::wstring& wstr) {
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), (int)wstr.length(), nullptr, 0, nullptr, nullptr);
    char* str = new char[size_needed + 1];
    WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), (int)wstr.length(), str, size_needed, nullptr, nullptr);
    str[size_needed] = '\0';
    return str;
}

// Helper: Convert hstring to allocated char*
char* hstring_to_cstring(const hstring& hstr) {
    std::wstring wstr(hstr.c_str());
    return wstring_to_cstring(wstr);
}

// Helper: Format Bluetooth address
char* format_bluetooth_address(uint64_t address) {
    char* addr_str = new char[18]; // XX:XX:XX:XX:XX:XX + null
    sprintf_s(addr_str, 18, "%02X:%02X:%02X:%02X:%02X:%02X",
        (address >> 40) & 0xFF,
        (address >> 32) & 0xFF,
        (address >> 24) & 0xFF,
        (address >> 16) & 0xFF,
        (address >> 8) & 0xFF,
        address & 0xFF);
    return addr_str;
}

// Helper: Check if device name starts with NIOX PRO
bool is_niox_device(const char* name) {
    if (name == nullptr) return false;
    size_t prefix_len = strlen(NIOX_PREFIX);
    return strncmp(name, NIOX_PREFIX, prefix_len) == 0;
}

// Initialize WinRT
int winrt_initialize() {
    if (g_initialized) return 0;

    try {
        init_apartment();
        g_initialized = true;
        return 0;
    }
    catch (...) {
        return -1;
    }
}

// Cleanup WinRT
void winrt_cleanup() {
    if (g_watcher) {
        try {
            g_watcher->Stop();
        }
        catch (...) {}
        g_watcher.reset();
    }

    // Free discovered devices
    for (auto& device : g_discovered_devices) {
        if (device.name) delete[] device.name;
        if (device.address) delete[] device.address;
    }
    g_discovered_devices.clear();

    g_callback = nullptr;
    g_user_data = nullptr;
    g_initialized = false;

    uninit_apartment();
}

// Check Bluetooth state
int winrt_check_bluetooth_state() {
    if (!g_initialized) {
        if (winrt_initialize() != 0) {
            return 3; // UNKNOWN
        }
    }

    try {
        // Get default Bluetooth adapter
        auto adapter = Bluetooth::BluetoothAdapter::GetDefaultAsync().get();

        if (adapter == nullptr) {
            return 2; // UNSUPPORTED
        }

        // Get radio
        auto radio = adapter.GetRadioAsync().get();

        if (radio == nullptr) {
            return 2; // UNSUPPORTED
        }

        // Check radio state
        auto state = radio.State();

        switch (state) {
            case RadioState::On:
                return 0; // ENABLED
            case RadioState::Off:
                return 1; // DISABLED
            case RadioState::Disabled:
                return 1; // DISABLED
            default:
                return 3; // UNKNOWN
        }
    }
    catch (...) {
        return 3; // UNKNOWN
    }
}

// Start BLE scan
int winrt_start_scan(int durationMs, int nioxOnly, DeviceFoundCallback callback, void* userData) {
    if (!g_initialized) {
        if (winrt_initialize() != 0) {
            return -1;
        }
    }

    if (g_watcher) {
        return -1; // Already scanning
    }

    try {
        g_callback = callback;
        g_user_data = userData;
        g_niox_only = (nioxOnly != 0);
        g_discovered_devices.clear();

        // Create watcher
        g_watcher = std::make_unique<BluetoothLEAdvertisementWatcher>();

        // Configure watcher
        g_watcher->ScanningMode(BluetoothLEScanningMode::Active);

        // Set up advertisement received handler
        g_watcher->Received([](BluetoothLEAdvertisementWatcher const& watcher,
                              BluetoothLEAdvertisementReceivedEventArgs const& args) {
            try {
                // Get device info
                uint64_t address = args.BluetoothAddress();
                int16_t rssi = args.RawSignalStrengthInDBm();
                auto advertisement = args.Advertisement();

                // Get local name
                char* name = nullptr;
                auto localName = advertisement.LocalName();
                if (!localName.empty()) {
                    name = hstring_to_cstring(localName);
                }

                // Apply NIOX filter if needed
                bool should_report = true;
                if (g_niox_only && !is_niox_device(name)) {
                    should_report = false;
                }

                if (should_report) {
                    // Create device structure
                    BLEDevice device;
                    device.name = name;
                    device.address = format_bluetooth_address(address);
                    device.rssi = rssi;
                    device.hasRssi = 1;

                    // Store in discovered devices
                    g_discovered_devices.push_back(device);

                    // Call callback if provided
                    if (g_callback) {
                        g_callback(device, g_user_data);
                    }
                }
                else {
                    // Free name if not reporting
                    if (name) delete[] name;
                }
            }
            catch (...) {
                // Ignore errors in handler
            }
        });

        // Start watching
        g_watcher->Start();

        // Wait for scan duration in a separate thread
        std::thread([durationMs]() {
            std::this_thread::sleep_for(std::chrono::milliseconds(durationMs));
            winrt_stop_scan();
        }).detach();

        return 0;
    }
    catch (...) {
        g_watcher.reset();
        return -1;
    }
}

// Stop scan
void winrt_stop_scan() {
    if (g_watcher) {
        try {
            g_watcher->Stop();
        }
        catch (...) {}
        g_watcher.reset();
    }
}

// Free string
void winrt_free_string(char* str) {
    if (str) {
        delete[] str;
    }
}
