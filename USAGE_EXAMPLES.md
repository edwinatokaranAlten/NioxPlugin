# Usage Examples

## Android Example

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

```kotlin
import com.niox.nioxplugin.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity : AppCompatActivity() {

    private lateinit var plugin: NioxCommunicationPlugin

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize plugin
        plugin = createNioxCommunicationPlugin(this)

        // Check Bluetooth state
        CoroutineScope(Dispatchers.Main).launch {
            val state = plugin.checkBluetoothState()
            Log.d("Bluetooth", "State: $state")
        }

        // Scan for devices
        CoroutineScope(Dispatchers.Main).launch {
            plugin.startBluetoothScan(
                onDeviceFound = { device ->
                    Log.d("Bluetooth", "Found: ${device.name} (${device.address})")
                },
                onScanComplete = {
                    Log.d("Bluetooth", "Scan complete")
                },
                scanDurationMs = 10000
            )
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        plugin.stopBluetoothScan()
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
            await plugin?.startBluetoothScan(
                onDeviceFound: { [weak self] device in
                    DispatchQueue.main.async {
                        self?.discoveredDevices.append(device)
                        print("Found device: \(device.name ?? "Unknown") - \(device.address)")
                    }
                },
                onScanComplete: {
                    print("Scan completed. Found \(self.discoveredDevices.count) devices")
                },
                scanDurationMs: 10000
            )
        }
    }

    func stopScanning() {
        plugin?.stopBluetoothScan()
    }

    deinit {
        plugin?.stopBluetoothScan()
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
            await plugin?.startBluetoothScan(
                onDeviceFound: { [weak self] device in
                    DispatchQueue.main.async {
                        self?.devices.append(device)
                    }
                },
                onScanComplete: { [weak self] in
                    DispatchQueue.main.async {
                        self?.isScanning = false
                    }
                },
                scanDurationMs: 10000
            )
        }
    }

    func stopScan() {
        plugin?.stopBluetoothScan()
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
    plugin.startBluetoothScan(
        onDeviceFound = { device ->
            println("Found device: ${device.name} - ${device.address} (RSSI: ${device.rssi})")
        },
        onScanComplete = {
            println("Scan completed")
        },
        scanDurationMs = 10000
    )
}
```

---

## Error Handling

### Common Issues

#### Android: SecurityException

```kotlin
try {
    plugin.startBluetoothScan(
        onDeviceFound = { device -> /* ... */ },
        onScanComplete = { /* ... */ }
    )
} catch (e: SecurityException) {
    Log.e("Bluetooth", "Missing permissions", e)
    // Request permissions
}
```

#### iOS: Unauthorized

```swift
let state = await plugin?.checkBluetoothState()
if state == .disabled {
    // Show alert to enable Bluetooth
    showBluetoothDisabledAlert()
}
```

#### All Platforms: Check State Before Scanning

```kotlin
val state = plugin.checkBluetoothState()
if (state == BluetoothState.ENABLED) {
    // Safe to scan
    plugin.startBluetoothScan(...)
} else {
    // Handle disabled/unsupported state
}
```
