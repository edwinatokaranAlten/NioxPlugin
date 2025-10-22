# Usage Examples
## Niox Communication Plugin - Cross-Platform Implementation Guide

This document provides comprehensive, production-ready code examples for integrating the Niox Communication Plugin across Android, iOS, and Windows platforms.

---

## Table of Contents

1. [Android Integration](#android-example)
2. [iOS Integration](#ios-example)
3. [Windows Integration](#windows-example)
4. [Error Handling Patterns](#error-handling)
5. [Best Practices](#best-practices)

---

## Android Example

### Overview
Android integration uses the AAR (Android Archive) format and requires runtime permissions for Bluetooth operations. The implementation supports both legacy (API < 31) and modern (API 31+) permission models.

### 1. Add the AAR to your project

Copy `nioxplugin-release.aar` to your Android project's `libs` folder.

In your app's `build.gradle`:

```gradle
dependencies {
    implementation files('libs/nioxplugin-release.aar')
    implementation 'org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3'
}
```

### 2. Request Permissions

```kotlin
// In your Activity or Fragment
private val bluetoothPermissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
    arrayOf(
        Manifest.permission.BLUETOOTH_SCAN,
        Manifest.permission.BLUETOOTH_CONNECT
    )
} else {
    arrayOf(
        Manifest.permission.BLUETOOTH,
        Manifest.permission.BLUETOOTH_ADMIN,
        Manifest.permission.ACCESS_FINE_LOCATION
    )
}

private val requestPermissionLauncher = registerForActivityResult(
    ActivityResultContracts.RequestMultiplePermissions()
) { permissions ->
    if (permissions.all { it.value }) {
        startBluetoothOperations()
    }
}

// Request permissions
requestPermissionLauncher.launch(bluetoothPermissions)
```

### 3. Use the Plugin

#### Basic Implementation (Activity)

```kotlin
import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.niox.nioxplugin.*
import kotlinx.coroutines.launch

class MainActivity : AppCompatActivity() {

    private lateinit var plugin: NioxCommunicationPlugin

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        // Initialize plugin with context
        plugin = createNioxCommunicationPlugin(this)

        // Request permissions first (see step 2)
        requestPermissionLauncher.launch(bluetoothPermissions)
    }

    private fun startBluetoothOperations() {
        // Check Bluetooth state
        lifecycleScope.launch {
            val state = plugin.checkBluetoothState()
            Log.d(TAG, "Bluetooth state: $state")

            when (state) {
                BluetoothState.ENABLED -> scanForDevices()
                BluetoothState.DISABLED -> showEnableBluetoothDialog()
                BluetoothState.UNSUPPORTED -> showUnsupportedMessage()
                BluetoothState.UNKNOWN -> Log.w(TAG, "Bluetooth state unknown")
            }
        }
    }

    private suspend fun scanForDevices() {
        try {
            Log.d(TAG, "Starting Bluetooth scan...")

            // Scan for all devices (10 second scan)
            val devices = plugin.scanForDevices(
                scanDurationMs = 10_000,
                serviceUuidFilter = null // null = scan all devices
            )

            Log.d(TAG, "Scan complete. Found ${devices.size} devices")

            // Process discovered devices
            devices.forEach { device ->
                Log.d(TAG, """
                    Device Found:
                      Name: ${device.name ?: "Unknown"}
                      Address: ${device.address}
                      RSSI: ${device.rssi ?: "N/A"}
                      Is Niox: ${device.isNioxDevice()}
                      Serial: ${device.nioxSerialNumber ?: "N/A"}
                """.trimIndent())
            }

            // Filter for Niox devices only
            val nioxDevices = devices.filter { it.isNioxDevice() }
            Log.d(TAG, "Found ${nioxDevices.size} Niox devices")

        } catch (e: SecurityException) {
            Log.e(TAG, "Missing Bluetooth permissions", e)
        } catch (e: Exception) {
            Log.e(TAG, "Scan failed", e)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        plugin.stopScan()
    }

    companion object {
        private const val TAG = "NioxBluetooth"
    }
}
```

#### ViewModel Implementation (MVVM Architecture)

```kotlin
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.niox.nioxplugin.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class BluetoothUiState(
    val isScanning: Boolean = false,
    val devices: List<BluetoothDevice> = emptyList(),
    val bluetoothState: BluetoothState = BluetoothState.UNKNOWN,
    val error: String? = null
)

class BluetoothViewModel(
    private val plugin: NioxCommunicationPlugin
) : ViewModel() {

    private val _uiState = MutableStateFlow(BluetoothUiState())
    val uiState: StateFlow<BluetoothUiState> = _uiState.asStateFlow()

    init {
        checkBluetoothState()
    }

    fun checkBluetoothState() {
        viewModelScope.launch {
            try {
                val state = plugin.checkBluetoothState()
                _uiState.value = _uiState.value.copy(
                    bluetoothState = state,
                    error = null
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    error = "Failed to check Bluetooth state: ${e.message}"
                )
            }
        }
    }

    fun startScan(durationMs: Long = 10_000) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(
                isScanning = true,
                devices = emptyList(),
                error = null
            )

            try {
                val devices = plugin.scanForDevices(
                    scanDurationMs = durationMs,
                    serviceUuidFilter = null
                )

                _uiState.value = _uiState.value.copy(
                    isScanning = false,
                    devices = devices
                )
            } catch (e: SecurityException) {
                _uiState.value = _uiState.value.copy(
                    isScanning = false,
                    error = "Bluetooth permissions not granted"
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isScanning = false,
                    error = "Scan failed: ${e.message}"
                )
            }
        }
    }

    fun stopScan() {
        plugin.stopScan()
        _uiState.value = _uiState.value.copy(isScanning = false)
    }

    override fun onCleared() {
        super.onCleared()
        plugin.stopScan()
    }
}
```

#### Jetpack Compose UI

```kotlin
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun BluetoothScanScreen(
    viewModel: BluetoothViewModel
) {
    val uiState by viewModel.uiState.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        // Header
        Text(
            text = "Niox Bluetooth Scanner",
            style = MaterialTheme.typography.headlineMedium
        )

        Spacer(modifier = Modifier.height(16.dp))

        // Bluetooth State
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("Bluetooth State: ${uiState.bluetoothState}")
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Scan Button
        Button(
            onClick = {
                if (uiState.isScanning) {
                    viewModel.stopScan()
                } else {
                    viewModel.startScan()
                }
            },
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(if (uiState.isScanning) "Stop Scan" else "Start Scan")
        }

        // Error Display
        uiState.error?.let { error ->
            Spacer(modifier = Modifier.height(8.dp))
            Card(
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.errorContainer
                )
            ) {
                Text(
                    text = error,
                    modifier = Modifier.padding(16.dp),
                    color = MaterialTheme.colorScheme.onErrorContainer
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Devices List
        Text(
            text = "Devices Found: ${uiState.devices.size}",
            style = MaterialTheme.typography.titleMedium
        )

        Spacer(modifier = Modifier.height(8.dp))

        LazyColumn {
            items(uiState.devices) { device ->
                DeviceCard(device = device)
                Spacer(modifier = Modifier.height(8.dp))
            }
        }
    }
}

@Composable
fun DeviceCard(device: BluetoothDevice) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = if (device.isNioxDevice()) {
            CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.primaryContainer
            )
        } else {
            CardDefaults.cardColors()
        }
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = device.name ?: "Unknown Device",
                style = MaterialTheme.typography.titleMedium
            )
            Text(
                text = "Address: ${device.address}",
                style = MaterialTheme.typography.bodyMedium
            )
            device.rssi?.let { rssi ->
                Text(
                    text = "RSSI: $rssi dBm",
                    style = MaterialTheme.typography.bodySmall
                )
            }
            if (device.isNioxDevice()) {
                Text(
                    text = "✓ Niox Device - Serial: ${device.nioxSerialNumber}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.primary
                )
            }
        }
    }
}
```

---

## iOS Example

### 1. Add XCFramework to Xcode Project

1. Drag `NioxCommunicationPlugin.xcframework` into your Xcode project
2. In Target Settings → General → Frameworks, Libraries, and Embedded Content
3. Set the framework to "Embed & Sign"

### 2. Add Privacy Permissions

In `Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>We need Bluetooth to scan for nearby devices</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>We need Bluetooth to communicate with devices</string>
```

### 3. Use the Plugin in Swift

```swift
import UIKit
import NioxCommunicationPlugin

class ViewController: UIViewController {

    var plugin: NioxCommunicationPlugin?
    var discoveredDevices: [BluetoothDevice] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize plugin
        plugin = NioxCommunicationPluginKt.createNioxCommunicationPlugin()

        // Check Bluetooth state
        Task {
            if let state = await plugin?.checkBluetoothState() {
                print("Bluetooth state: \(state)")
            }
        }
    }

    func startScanning() {
        Task {
            if let devices = await plugin?.scanForDevices(scanDurationMs: 10000) {
                DispatchQueue.main.async {
                    self.discoveredDevices.append(contentsOf: devices)
                    print("Scan completed. Found \(devices.count) devices")
                }
            }
        }
    }

    func stopScanning() {
        plugin?.stopScan()
    }

    deinit {
        plugin?.stopScan()
    }
}
```

### 4. SwiftUI Example

```swift
import SwiftUI
import NioxCommunicationPlugin

struct ContentView: View {
    @StateObject private var bluetoothManager = BluetoothManager()

    var body: some View {
        VStack {
            Text("Bluetooth State: \(bluetoothManager.stateText)")
                .padding()

            Button(bluetoothManager.isScanning ? "Stop Scanning" : "Start Scanning") {
                if bluetoothManager.isScanning {
                    bluetoothManager.stopScan()
                } else {
                    bluetoothManager.startScan()
                }
            }
            .padding()

            List(bluetoothManager.devices, id: \.address) { device in
                VStack(alignment: .leading) {
                    Text(device.name ?? "Unknown Device")
                        .font(.headline)
                    Text(device.address)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            bluetoothManager.checkState()
        }
    }
}

class BluetoothManager: ObservableObject {
    @Published var devices: [BluetoothDevice] = []
    @Published var stateText: String = "Unknown"
    @Published var isScanning: Bool = false

    private var plugin: NioxCommunicationPlugin?

    init() {
        plugin = NioxCommunicationPluginKt.createNioxCommunicationPlugin()
    }

    func checkState() {
        Task {
            if let state = await plugin?.checkBluetoothState() {
                DispatchQueue.main.async {
                    self.stateText = "\(state)"
                }
            }
        }
    }

    func startScan() {
        isScanning = true
        devices.removeAll()

        Task {
            if let result = await plugin?.scanForDevices(scanDurationMs: 10000) {
                DispatchQueue.main.async {
                    self.devices = result
                    self.isScanning = false
                }
            } else {
                DispatchQueue.main.async { self.isScanning = false }
            }
        }
    }

    func stopScan() {
        plugin?.stopScan()
        isScanning = false
    }
}
```

---

## Windows Example

### 1. Add JAR to your JVM project

Add the JAR to your project's classpath:

```gradle
dependencies {
    implementation files('libs/niox-communication-plugin-windows.jar')
    implementation 'net.java.dev.jna:jna:5.13.0'
    implementation 'net.java.dev.jna:jna-platform:5.13.0'
    implementation 'org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3'
}
```

### 2. Use the Plugin

```kotlin
import com.niox.nioxplugin.*
import kotlinx.coroutines.runBlocking

fun main() = runBlocking {
    val plugin = createNioxCommunicationPlugin()

    // Check Bluetooth state
    val state = plugin.checkBluetoothState()
    println("Bluetooth state: $state")

    // Scan for devices
    println("Starting Bluetooth scan...")
    val devices = plugin.scanForDevices(scanDurationMs = 10_000)
    devices.forEach { device ->
        println("Found device: ${device.name} - ${device.address} (RSSI: ${device.rssi})")
    }
}
```

---

## Error Handling

### Platform-Specific Error Handling

#### Android: SecurityException

```kotlin
try {
    val devices = plugin.scanForDevices()
    // Process devices
} catch (e: SecurityException) {
    Log.e("Bluetooth", "Missing Bluetooth permissions", e)
    // Request permissions from user
    requestPermissions()
} catch (e: IllegalStateException) {
    Log.e("Bluetooth", "Bluetooth adapter not initialized", e)
} catch (e: Exception) {
    Log.e("Bluetooth", "Scan failed: ${e.message}", e)
}
```

#### iOS: Authorization Status

```swift
let state = await plugin?.checkBluetoothState()

switch state {
case .enabled:
    // Proceed with scanning
    await startScanning()
case .disabled:
    // Show alert to enable Bluetooth
    showBluetoothDisabledAlert()
case .unsupported:
    // Device doesn't support Bluetooth
    showUnsupportedAlert()
default:
    print("Unknown Bluetooth state")
}
```

#### Windows: Adapter Availability

```kotlin
try {
    val state = plugin.checkBluetoothState()
    when (state) {
        BluetoothState.ENABLED -> {
            val devices = plugin.scanForDevices(10_000)
            // Process devices
        }
        BluetoothState.DISABLED -> {
            println("Please enable Bluetooth in Windows Settings")
        }
        BluetoothState.UNSUPPORTED -> {
            println("No Bluetooth adapter found")
        }
        else -> println("Bluetooth state unknown")
    }
} catch (e: Exception) {
    println("Bluetooth operation failed: ${e.message}")
}
```

### Recommended Error Handling Pattern (All Platforms)

```kotlin
sealed class BluetoothResult<out T> {
    data class Success<T>(val data: T) : BluetoothResult<T>()
    data class Error(val message: String, val exception: Exception? = null) : BluetoothResult<Nothing>()
}

suspend fun scanForDevicesSafely(): BluetoothResult<List<BluetoothDevice>> {
    return try {
        // Check state first
        when (plugin.checkBluetoothState()) {
            BluetoothState.ENABLED -> {
                val devices = plugin.scanForDevices(10_000)
                BluetoothResult.Success(devices)
            }
            BluetoothState.DISABLED -> {
                BluetoothResult.Error("Bluetooth is disabled")
            }
            BluetoothState.UNSUPPORTED -> {
                BluetoothResult.Error("Bluetooth is not supported on this device")
            }
            BluetoothState.UNKNOWN -> {
                BluetoothResult.Error("Bluetooth state is unknown")
            }
        }
    } catch (e: SecurityException) {
        BluetoothResult.Error("Missing permissions", e)
    } catch (e: Exception) {
        BluetoothResult.Error("Scan failed: ${e.message}", e)
    }
}

// Usage
when (val result = scanForDevicesSafely()) {
    is BluetoothResult.Success -> {
        // Handle devices
        processDevices(result.data)
    }
    is BluetoothResult.Error -> {
        // Handle error
        showError(result.message)
    }
}
```

---

## Best Practices

### 1. Always Check Bluetooth State Before Scanning

```kotlin
// ✅ Good
val state = plugin.checkBluetoothState()
if (state == BluetoothState.ENABLED) {
    val devices = plugin.scanForDevices()
}

// ❌ Bad
val devices = plugin.scanForDevices() // May fail if Bluetooth is off
```

### 2. Clean Up Resources

```kotlin
// Android - Use lifecycle-aware components
class MyActivity : AppCompatActivity() {
    override fun onDestroy() {
        super.onDestroy()
        plugin.stopScan() // Always stop scanning
    }
}

// iOS - Use deinit
deinit {
    plugin?.stopScan()
}

// Windows - Implement IDisposable in C#
public void Dispose() {
    bluetoothService.StopScan();
}
```

### 3. Handle Permissions Correctly

```kotlin
// Android: Request permissions before scanning
if (hasBluetoothPermissions()) {
    startScan()
} else {
    requestPermissions()
}

// iOS: Check authorization in Info.plist
// Add required keys before using Bluetooth
```

### 4. Use Appropriate Scan Durations

```kotlin
// ✅ Reasonable scan duration
plugin.scanForDevices(10_000) // 10 seconds

// ❌ Too short - may miss devices
plugin.scanForDevices(1_000) // 1 second

// ❌ Too long - wastes battery
plugin.scanForDevices(60_000) // 60 seconds
```

### 5. Filter Devices Appropriately

```kotlin
// Scan for specific service UUID (more efficient)
val nioxDevices = plugin.scanForDevices(
    scanDurationMs = 10_000,
    serviceUuidFilter = "YOUR_SERVICE_UUID"
)

// Or filter in code
val allDevices = plugin.scanForDevices(10_000, null)
val nioxOnly = allDevices.filter { it.isNioxDevice() }
```

### 6. Implement Proper UI Feedback

```kotlin
// Show loading state during scan
_uiState.value = UiState(isScanning = true)

try {
    val devices = plugin.scanForDevices(10_000)
    _uiState.value = UiState(isScanning = false, devices = devices)
} catch (e: Exception) {
    _uiState.value = UiState(isScanning = false, error = e.message)
}
```

### 7. Test on Multiple Devices and OS Versions

- **Android:** Test on API 21, 31+ (permission model changes)
- **iOS:** Test on iOS 13, 14, 15+ (privacy changes)
- **Windows:** Test on Windows 10, 11 (Bluetooth stack differences)

### 8. Handle Background/Foreground Transitions

```kotlin
// Android
override fun onResume() {
    super.onResume()
    // Re-check Bluetooth state
    checkBluetoothState()
}

override fun onPause() {
    super.onPause()
    // Stop scanning to save battery
    plugin.stopScan()
}
```

### 9. Log Appropriately

```kotlin
// Use structured logging
Log.d(TAG, "Starting Bluetooth scan (duration: ${scanDurationMs}ms)")
Log.d(TAG, "Found ${devices.size} devices")
Log.d(TAG, "Niox devices: ${nioxDevices.size}")

// Don't log sensitive data
// ❌ Bad: Log.d(TAG, "Device address: ${device.address}")
```

### 10. Provide User Guidance

```kotlin
// Show clear error messages
when (state) {
    BluetoothState.DISABLED -> {
        showMessage("Please enable Bluetooth in Settings")
    }
    BluetoothState.UNSUPPORTED -> {
        showMessage("This device doesn't support Bluetooth")
    }
}
```

---

## Additional Resources

- **API Documentation:** [README.md](README.md)
- **C# Integration:** [CSHARP_MAUI_INTEGRATION.md](CSHARP_MAUI_INTEGRATION.md)
- **Windows Setup:** [WINDOWS_BUILD_SETUP.md](WINDOWS_BUILD_SETUP.md)
- **Quick Start:** [QUICKSTART.md](QUICKSTART.md)

---

**Document Version:** 1.0.0
**Last Updated:** October 22, 2024
**Platforms:** Android 5.0+, iOS 13.0+, Windows 10/11
