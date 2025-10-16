package com.niox.nioxplugin

/**
 * Represents a discovered Bluetooth device
 */
data class BluetoothDevice(
    /** Device name (may be null if name is not available) */
    val name: String?,

    /** Device MAC address or unique identifier */
    val address: String,

    /** Signal strength indicator (RSSI) in dBm */
    val rssi: Int? = null,

    /** List of advertised service UUIDs (BLE devices only) */
    val serviceUuids: List<String>? = null,

    /** Raw advertising data (platform-specific, may be null) */
    val advertisingData: Map<String, Any>? = null
) {
    /**
     * Check if this device is a NIOX PRO device based on:
     * - Service UUID: 000fc00b-8a4-4078-874c-14efbd4b510a
     * - Device name starting with "NIOX PRO"
     */
    fun isNioxDevice(): Boolean {
        // Check if device name matches NIOX pattern
        val hasNioxName = name?.startsWith("NIOX PRO", ignoreCase = true) == true

        // Check if device advertises the NIOX FDC service UUID
        val hasNioxService = serviceUuids?.any { uuid ->
            uuid.equals("000fc00b-8a4-4078-874c-14efbd4b510a", ignoreCase = true) ||
            uuid.equals("000fc00b8a440788741c14efbd4b510a", ignoreCase = true)
        } == true

        return hasNioxName || hasNioxService
    }

    /**
     * Extract NIOX device serial number from device name
     * Format: "NIOX PRO [serial_number]" (e.g., "NIOX PRO 070401992")
     */
    fun getNioxSerialNumber(): String? {
        return name?.let { deviceName ->
            if (deviceName.startsWith("NIOX PRO", ignoreCase = true)) {
                deviceName.substring(8).trim().takeIf { it.isNotEmpty() }
            } else {
                null
            }
        }
    }
}

/**
 * NIOX device identification constants
 */
object NioxConstants {
    /** NIOX FDC Service UUID (128-bit) */
    const val NIOX_SERVICE_UUID = "000fc00-b8a4-4078-874c-14efbd4b510a"

    /** Tx Power Service UUID (16-bit) */
    const val TX_POWER_SERVICE_UUID = "1804"

    /** NIOX device name prefix */
    const val NIOX_DEVICE_NAME_PREFIX = "NIOX PRO"
}
