package com.niox.nioxplugin

import kotlinx.cinterop.*
import kotlinx.coroutines.runBlocking
import kotlin.experimental.ExperimentalNativeApi

/**
 * C API wrapper functions for calling from C#/C++
 * These functions are exported with simple C signatures for P/Invoke
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
                append("\"rssi\":${device.rssi ?: "null"},")
                append("\"isNioxDevice\":${device.isNioxDevice()},")
                append("\"serialNumber\":\"${device.getNioxSerialNumber()}\"")
                append("}")
            }
            append("]")
        }

        // Return as C string (allocated in native memory)
        // Allocate stable pointer to keep string alive
        return memScoped {
            json.cstr.ptr
        }
    } catch (e: Exception) {
        null
    }
}

/**
 * Free string memory allocated by scan_devices
 */
@OptIn(ExperimentalForeignApi::class, ExperimentalNativeApi::class)
@CName("niox_free_string")
fun freeString(ptr: CPointer<ByteVar>?) {
    // In Kotlin/Native, strings created with .cstr.ptr are managed
    // This is a no-op but provided for API compatibility
}

/**
 * Cleanup and release resources
 */
@OptIn(ExperimentalNativeApi::class)
@CName("niox_cleanup")
fun cleanup() {
    globalPlugin = null
}

/**
 * Get version string
 */
@OptIn(ExperimentalForeignApi::class, ExperimentalNativeApi::class)
@CName("niox_version")
fun getVersion(): CPointer<ByteVar>? {
    return memScoped {
        "1.0.0".cstr.ptr
    }
}
