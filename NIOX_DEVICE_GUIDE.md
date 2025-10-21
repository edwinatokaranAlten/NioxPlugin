# NIOX Device Scanning Guide

This guide explains how to use the Niox Communication Plugin to scan for and identify NIOX PRO devices.

## Default Behavior

**By default, the plugin scans ONLY for NIOX PRO devices** using the NIOX FDC Service UUID filter. To scan for all Bluetooth devices, explicitly set `serviceUuidFilter = null`.

## NIOX PRO Device Identification

NIOX PRO devices can be identified by:
1. **Service UUID**: `000fc00b-8a4-4078-874c-14efbd4b510a` (FDC Service)
2. **Device Name**: Starts with `"NIOX PRO"` followed by a 9-digit serial number
3. **Example**: `"NIOX PRO 070401992"`

## Advertising Data Specification

### Passive Scanning (Advertising Packet)

| Structure | Field | Value | Description |
|-----------|-------|-------|-------------|
| 1 | Flags | 0x06 | LE General Discoverable, BR/EDR Not Supported |
| 2 | Tx Power Level | 0xNN | -127 to +127 dBm |
| 3 | 16-bit Service UUID | 0x1804 | Tx Power Service |
| 4 | 128-bit Service UUID | 0a514bbdef144c877840a4b800fc0000 | FDC Service |

### Active Scanning (Scan Response)

| Structure | Field | Value | Description |
|-----------|-------|-------|-------------|
| 1 | Appearance | 0x0000 | None |
| 2 | Complete Local Name | NIOX PRO xxxxxxxxx | Device name with serial number |

## Usage Examples

### Option 1: Default NIOX Scan (Recommended)

**The simplest way** - just call `scanForDevices()` without parameters. It automatically scans for NIOX devices only.

#### Android Example

```kotlin
import com.niox.nioxplugin.*

val plugin = createNioxCommunicationPlugin(context)

// Scan for NIOX devices - UUID filter applied by default!
val devices = plugin.scanForDevices()
devices.forEach { device ->
    println("Found NIOX device: ${device.name}")
    println("Serial number: ${device.getNioxSerialNumber()}")
    println("Address: ${device.address}")
    println("RSSI: ${device.rssi} dBm")
    println("Service UUIDs: ${device.serviceUuids}")
}

// Or explicitly specify the UUID (same as default)
val nioxDevices = plugin.scanForDevices(
    scanDurationMs = 10000,
    serviceUuidFilter = NioxConstants.NIOX_SERVICE_UUID
)

// To scan for ALL devices, set filter to null
val allDevices = plugin.scanForDevices(
    scanDurationMs = 10000,
    serviceUuidFilter = null  // Scan all Bluetooth devices
)
```

#### iOS Example (Swift)

```swift
import NioxCommunicationPlugin

let plugin = NioxCommunicationPluginKt.createNioxCommunicationPlugin()

// Default scan - NIOX devices only (UUID filter applied automatically)
Task {
    let devices = await plugin.scanForDevices()
    devices.forEach { device in
        print("Found NIOX device: \(device.name ?? \"Unknown\")")
        if let serialNumber = device.getNioxSerialNumber() {
            print("Serial number: \(serialNumber)")
        }
        print("Address: \(device.address)")
        print("RSSI: \(device.rssi ?? 0) dBm")
    }
}
```

#### Windows Example

```kotlin
import com.niox.nioxplugin.*

val plugin = createNioxCommunicationPlugin()

// Default scan - automatically filters for NIOX devices
// Note: Windows uses software filtering by device name
val devicesWin = plugin.scanForDevices()
devicesWin.forEach { device ->
    println("Found NIOX device: ${device.name}")
    device.getNioxSerialNumber()?.let { serial ->
        println("Serial number: $serial")
    }
}
```

### Option 2: Scan All Devices with Software Filtering

To scan for ALL Bluetooth devices (not just NIOX), set `serviceUuidFilter = null` and use software filtering.

```kotlin
import com.niox.nioxplugin.*

val plugin = createNioxCommunicationPlugin(context)  // Android requires context

val nioxDevices = mutableListOf<BluetoothDevice>()

// Scan ALL devices by setting serviceUuidFilter to null
val allFound = plugin.scanForDevices(
    scanDurationMs = 15000,
    serviceUuidFilter = null  // ← Scan ALL devices
)
allFound.forEach { device ->
    if (device.isNioxDevice()) {
        nioxDevices.add(device)

        println("✓ NIOX Device Found!")
        println("  Name: ${device.name}")
        println("  Serial: ${device.getNioxSerialNumber()}")
        println("  Address: ${device.address}")
        println("  RSSI: ${device.rssi} dBm")

        device.serviceUuids?.let { uuids ->
            println("  Services: ${uuids.joinToString()}")
        }

        device.advertisingData?.let { data ->
            println("  Tx Power: ${data["txPowerLevel"]}")
            println("  Flags: ${data["flags"]}")
        }
    } else {
        println("Non-NIOX device: ${device.name}")
    }
}

println("\n=== Scan Complete ===")
println("Found ${nioxDevices.size} NIOX devices")

nioxDevices.forEach { device ->
    println("- ${device.name} (${device.getNioxSerialNumber()})")
}
```

### Option 3: Name-Based Filtering

Filter by device name prefix only (less reliable if advertising data is truncated).

```kotlin
import com.niox.nioxplugin.*

val devicesByName = plugin.scanForDevices()
devicesByName.forEach { device ->
    if (device.name?.startsWith(NioxConstants.NIOX_DEVICE_NAME_PREFIX) == true) {
        val serialNumber = device.getNioxSerialNumber()
        println("NIOX PRO found: $serialNumber")
    }
}
```

## Utility Functions

The `BluetoothDevice` class provides helpful utility functions:

### `isNioxDevice(): Boolean`

Checks if a device is a NIOX PRO device based on:
- Service UUID matching `000fc00b-8a4-4078-874c-14efbd4b510a`
- Device name starting with `"NIOX PRO"`

```kotlin
if (device.isNioxDevice()) {
    // This is a NIOX device
}
```

### `getNioxSerialNumber(): String?`

Extracts the serial number from the device name.

```kotlin
val serialNumber = device.getNioxSerialNumber()
// Returns: "070401992" from "NIOX PRO 070401992"
```

## Constants

Use the `NioxConstants` object for NIOX-specific constants:

```kotlin
NioxConstants.NIOX_SERVICE_UUID           // "000fc00b-8a4-4078-874c-14efbd4b510a"
NioxConstants.TX_POWER_SERVICE_UUID       // "1804"
NioxConstants.NIOX_DEVICE_NAME_PREFIX     // "NIOX PRO"
```

## Best Practices

1. **Use Service UUID Filtering**: On Android and iOS, use the `serviceUuidFilter` parameter for better battery efficiency
2. **Handle Null Values**: Device name, RSSI, and service UUIDs may be null - always check before using
3. **Verify Multiple Criteria**: Check both service UUID and device name for most reliable identification
4. **Request Permissions**: Ensure proper Bluetooth permissions are granted before scanning
5. **Scan Duration**: Use appropriate scan duration (10-15 seconds) to balance discovery vs battery

## Platform-Specific Notes

### Android
- Hardware-level UUID filtering supported ✓
- Captures full advertising data including service UUIDs, tx power, and flags
- Requires `BLUETOOTH_SCAN` permission on Android 12+

### iOS
- Hardware-level UUID filtering supported ✓
- Captures service UUIDs from advertisement data
- Requires Bluetooth usage descriptions in Info.plist

### Windows
- UUID filtering in software only (scans all devices)
- Limited advertising data available
- Uses Bluetooth Classic API (not BLE)

## Complete Example: NIOX Device Manager

```kotlin
class NioxDeviceManager(context: Context) {
    private val plugin = createNioxCommunicationPlugin(context)

    suspend fun scanForNioxDevices(): List<BluetoothDevice> {
        val devices = plugin.scanForDevices(
            scanDurationMs = 10000,
            serviceUuidFilter = NioxConstants.NIOX_SERVICE_UUID
        )
        return devices.filter { it.isNioxDevice() }
    }

    fun stopScanning() {
        plugin.stopScan()
    }
}

// Usage (in a coroutine scope)
val manager = NioxDeviceManager(context)
val nioxDevices = manager.scanForNioxDevices()
println("Total NIOX devices found: ${nioxDevices.size}")
nioxDevices.forEach { device ->
    println("Discovered NIOX device: ${device.getNioxSerialNumber()} (RSSI: ${device.rssi} dBm)")
}
```

## Troubleshooting

**Q: No devices found?**
- Ensure Bluetooth is enabled on the device
- Check that Bluetooth permissions are granted
- Verify NIOX device is powered on and advertising
- Try scanning without UUID filter to see all devices

**Q: Device name is null?**
- On Android 12+, requires `BLUETOOTH_CONNECT` permission
- Check the `advertisingData` for "localName" field
- Some devices don't advertise name in all packets

**Q: Service UUIDs not showing?**
- Ensure active scanning is enabled (default on most platforms)
- Check that device is advertising the service UUID
- Windows may have limited UUID support

---

For more information, see [README.md](README.md) and [USAGE_EXAMPLES.md](USAGE_EXAMPLES.md).
