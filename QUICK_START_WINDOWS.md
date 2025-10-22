# Quick Start Guide - Windows Implementation

## Build the Windows JAR

```bash
./gradlew :nioxplugin:buildWindowsJar
```

**Output**: `nioxplugin/build/outputs/windows/niox-communication-plugin-windows-1.0.0.jar`

## Using from Kotlin/JVM

### 1. Add the JAR to your project

Copy the JAR and add to your project dependencies:

```kotlin
// build.gradle.kts
dependencies {
    implementation(files("libs/niox-communication-plugin-windows-1.0.0.jar"))
    implementation("net.java.dev.jna:jna:5.13.0")
    implementation("net.java.dev.jna:jna-platform:5.13.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
}
```

### 2. Use in your code

```kotlin
import com.niox.nioxplugin.*
import kotlinx.coroutines.runBlocking

fun main() = runBlocking {
    val plugin = createNioxCommunicationPlugin()

    // Check Bluetooth
    when (plugin.checkBluetoothState()) {
        BluetoothState.ENABLED -> println("✓ Bluetooth is ready")
        BluetoothState.DISABLED -> println("✗ Bluetooth is disabled")
        BluetoothState.UNSUPPORTED -> println("✗ Bluetooth not supported")
        BluetoothState.UNKNOWN -> println("? Bluetooth state unknown")
    }

    // Scan for NIOX devices
    val devices = plugin.scanForDevices(scanDurationMs = 10000)

    devices.forEach { device ->
        println("${device.name} - ${device.address}")
        if (device.isNioxDevice()) {
            println("  NIOX Serial: ${device.getNioxSerialNumber()}")
        }
    }
}
```

## Using from C# MAUI

### Method 1: IKVM.NET (Recommended)

#### 1. Install IKVM

```bash
dotnet add package IKVM
dotnet add package IKVM.Maven.Sdk
```

#### 2. Add JAR Reference

```xml
<!-- YourProject.csproj -->
<ItemGroup>
  <IkvmReference Include="path\to\niox-communication-plugin-windows-1.0.0.jar" />
</ItemGroup>
```

#### 3. Use in C#

```csharp
using com.niox.nioxplugin;

public class BluetoothService
{
    private readonly NioxCommunicationPlugin plugin;

    public BluetoothService()
    {
        plugin = NioxCommunicationPluginKt.createNioxCommunicationPlugin();
    }

    public async Task<List<DeviceInfo>> ScanAsync()
    {
        var devices = await Task.Run(() =>
        {
            var continuation = new SimpleContinuation();
            plugin.scanForDevices(10000, null, continuation);
            return continuation.GetResult();
        });

        // Convert to C# list
        return ConvertDevices(devices);
    }
}
```

See [CSHARP_MAUI_INTEGRATION.md](CSHARP_MAUI_INTEGRATION.md) for complete examples.

### Method 2: Process Execution (Simpler)

Run the JAR as a process and parse output:

```csharp
var startInfo = new ProcessStartInfo
{
    FileName = "java",
    Arguments = "-jar niox-plugin.jar scan 10000",
    RedirectStandardOutput = true
};

using var process = Process.Start(startInfo);
var output = await process.StandardOutput.ReadToEndAsync();
// Parse output
```

## API Quick Reference

### Check Bluetooth State

```kotlin
suspend fun checkBluetoothState(): BluetoothState
```

Returns: `ENABLED`, `DISABLED`, `UNSUPPORTED`, or `UNKNOWN`

### Scan for Devices

```kotlin
suspend fun scanForDevices(
    scanDurationMs: Long = 10000,
    serviceUuidFilter: String? = NioxConstants.NIOX_SERVICE_UUID
): List<BluetoothDevice>
```

Parameters:
- `scanDurationMs`: Scan duration in milliseconds (default: 10 seconds)
- `serviceUuidFilter`: UUID filter (default: NIOX UUID, set to `null` for all devices)

Returns: List of discovered Bluetooth devices

### Stop Scanning

```kotlin
fun stopScan()
```

Immediately stops an ongoing scan.

### Device Information

```kotlin
data class BluetoothDevice(
    val name: String?,           // Device name
    val address: String,         // MAC address (XX:XX:XX:XX:XX:XX)
    val rssi: Int? = null,       // Always null on Windows
    val serviceUuids: List<String>? = null,
    val advertisingData: Map<String, Any>? = null
)
```

Helper methods:
- `device.isNioxDevice()` - Check if device is a NIOX PRO device
- `device.getNioxSerialNumber()` - Extract serial number from NIOX device

## Example: Scan for All Devices

```kotlin
import com.niox.nioxplugin.*
import kotlinx.coroutines.runBlocking

fun main() = runBlocking {
    val plugin = createNioxCommunicationPlugin()

    // Scan for ALL devices (not just NIOX)
    val allDevices = plugin.scanForDevices(
        scanDurationMs = 15000,
        serviceUuidFilter = null  // Remove filter
    )

    println("Total devices: ${allDevices.size}")

    // Filter NIOX devices
    val nioxDevices = allDevices.filter { it.isNioxDevice() }
    println("NIOX devices: ${nioxDevices.size}")

    nioxDevices.forEach { device ->
        println("NIOX: ${device.name} - Serial: ${device.getNioxSerialNumber()}")
    }
}
```

## Troubleshooting

### "UnsatisfiedLinkError: Unable to load library 'Bthprops.cpl'"

**Cause**: Bluetooth drivers not installed or Bluetooth not available

**Solution**:
1. Check Device Manager for Bluetooth adapter
2. Install/update Bluetooth drivers
3. Ensure Bluetooth is enabled in Windows Settings

### "No devices found"

**Solutions**:
1. Increase scan duration: `scanDurationMs = 30000`
2. Remove service filter: `serviceUuidFilter = null`
3. Ensure devices are in discoverable/pairing mode
4. Check Bluetooth is enabled: `checkBluetoothState()`

### "Java class not found" (C# MAUI)

**Solution**:
1. Verify IKVM is installed correctly
2. Check JAR is in correct location
3. Clean and rebuild project
4. Use fully qualified class names

## System Requirements

- **OS**: Windows 10 or Windows 11
- **Hardware**: Bluetooth adapter (built-in or USB)
- **Runtime**: JRE 11 or higher
- **Drivers**: Bluetooth drivers installed and working

## Performance Notes

- Typical scan time: 5-10 seconds
- Longer scans find more devices but impact UX
- Windows API discovery is slower than BLE
- Cancel scans early with `stopScan()` if needed

## Next Steps

- See [CSHARP_MAUI_INTEGRATION.md](CSHARP_MAUI_INTEGRATION.md) for C# integration
- See [USAGE_EXAMPLES.md](USAGE_EXAMPLES.md) for more examples
- See [README.md](README.md) for complete API documentation
- See [WINDOWS_IMPLEMENTATION_SUMMARY.md](WINDOWS_IMPLEMENTATION_SUMMARY.md) for technical details

## Support

For issues specific to Windows implementation:
1. Check that Bluetooth is enabled and working in Windows
2. Verify JRE 11+ is installed
3. Check that Bthprops.cpl exists (should be in System32)
4. Review logs for JNA-specific errors

---

**Quick Build & Test**:
```bash
# Build
./gradlew :nioxplugin:buildWindowsJar

# Test build output
ls -lh nioxplugin/build/outputs/windows/

# Run simple test (if you have Kotlin script runner)
kotlin -classpath "nioxplugin/build/outputs/windows/niox-communication-plugin-windows-1.0.0.jar" YourTestScript.kts
```
