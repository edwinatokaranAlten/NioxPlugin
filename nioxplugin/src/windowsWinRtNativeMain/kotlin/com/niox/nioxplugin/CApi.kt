package com.niox.nioxplugin

import kotlinx.cinterop.*
import kotlinx.coroutines.runBlocking
import kotlin.experimental.ExperimentalNativeApi

/**
 * C API wrapper functions for calling from C#/C++
 * These functions are exported with simple C signatures for P/Invoke
 * Compatible with the classic DLL API but uses WinRT BLE instead
 */

// Global plugin instance (singleton approach for simplicity)
private var globalPlugin: NioxCommunicationPlugin? = null

/**
 * Initialize the plugin
 * Returns 1 on success, 0 on failure
 */
@OptIn(ExperimentalNativeApi::class)
@CName("niox_init")
fun initPlugin(): Int {
    return try {
        if (globalPlugin == null) {
            globalPlugin = createNioxCommunicationPlugin()
        }
        1 // Success
    } catch (e: Exception) {
        0 // Failure
    }
}

/**
 * Check Bluetooth state
 * Returns: 0=ENABLED, 1=DISABLED, 2=UNSUPPORTED, 3=UNKNOWN
 */
@OptIn(ExperimentalNativeApi::class)
@CName("niox_check_bluetooth")
fun checkBluetooth(): Int {
    return try {
        val plugin = globalPlugin ?: return 3 // UNKNOWN
        val state = runBlocking {
            plugin.checkBluetoothState()
        }
        when (state) {
            BluetoothState.ENABLED -> 0
            BluetoothState.DISABLED -> 1
            BluetoothState.UNSUPPORTED -> 2
            BluetoothState.UNKNOWN -> 3
        }
    } catch (e: Exception) {
        3 // UNKNOWN on error
    }
}

/**
 * Scan for devices
 * Parameters:
 *   durationMs: scan duration in milliseconds
 *   nioxOnly: 1 for NIOX devices only, 0 for all devices
 * Returns: JSON string with device list (must be freed with niox_free_string)
 */
@OptIn(ExperimentalForeignApi::class, ExperimentalNativeApi::class)
@CName("niox_scan_devices")
fun scanDevices(durationMs: Long, nioxOnly: Int): CPointer<ByteVar>? {
    return try {
        val plugin = globalPlugin ?: return null

        val serviceUuid = if (nioxOnly == 1) {
            NioxConstants.NIOX_SERVICE_UUID
        } else {
            null
        }

        val devices = runBlocking {
            plugin.scanForDevices(durationMs, serviceUuid)
        }

        // Convert devices to JSON
        val json = buildString {
            append("[")
            devices.forEachIndexed { index, device ->
                if (index > 0) append(",")
                append("{")
                append("\"name\":\"${device.name?.replace("\"", "\\\"") ?: "Unknown"}\",")
                append("\"address\":\"${device.address}\",")
                append("\"rssi\":${device.rssi ?: "null"},") // NOW HAS RSSI!
                append("\"isNioxDevice\":${device.isNioxDevice()},")
                device.getNioxSerialNumber()?.let {
                    append("\"serialNumber\":\"$it\"")
                } ?: append("\"serialNumber\":null")
                append("}")
            }
            append("]")
        }

        // Allocate string in native memory and return pointer
        return memScoped {
            val bytes = json.encodeToByteArray()
            val ptr = nativeHeap.allocArray<ByteVar>(bytes.size + 1)
            bytes.forEachIndexed { index, byte ->
                ptr[index] = byte
            }
            ptr[bytes.size] = 0 // Null terminator
            ptr
        }
    } catch (e: Exception) {
        null
    }
}

/**
 * Free string memory allocated by niox_scan_devices
 */
@OptIn(ExperimentalForeignApi::class, ExperimentalNativeApi::class)
@CName("niox_free_string")
fun freeString(ptr: CPointer<ByteVar>?) {
    ptr?.let {
        nativeHeap.free(it)
    }
}

/**
 * Cleanup and release resources
 */
@OptIn(ExperimentalNativeApi::class)
@CName("niox_cleanup")
fun cleanup() {
    globalPlugin?.stopScan()
    globalPlugin = null
}

/**
 * Get version string
 * Returns: Version string "1.1.0-winrt" (must NOT be freed)
 */
@OptIn(ExperimentalForeignApi::class, ExperimentalNativeApi::class)
@CName("niox_version")
fun getVersion(): CPointer<ByteVar>? {
    return "1.1.0-winrt".cstr.ptr
}

/**
 * Get implementation type
 * Returns: "winrt-ble" to distinguish from classic implementation
 */
@OptIn(ExperimentalForeignApi::class, ExperimentalNativeApi::class)
@CName("niox_implementation")
fun getImplementation(): CPointer<ByteVar>? {
    return "winrt-ble".cstr.ptr
}
