package com.niox.nioxplugin

/**
 * Main interface for the Niox Communication Plugin
 * Provides Bluetooth functionality across Android, iOS, and Windows platforms
 */
interface NioxCommunicationPlugin {
    /**
     * Check the current Bluetooth adapter state
     * @return Current BluetoothState
     */
    suspend fun checkBluetoothState(): BluetoothState

    /**
     * Scan for nearby NIOX Bluetooth devices and return all discovered devices
     * @param scanDurationMs Duration of the scan in milliseconds (default: 10000ms)
     * @param serviceUuidFilter Service UUID to filter devices (default: NIOX_SERVICE_UUID = "000fc00b-8a4-4078-874c-14efbd4b510a", set to null to scan all devices)
     * @return List of discovered BluetoothDevice objects
     */
    suspend fun scanForDevices(
        scanDurationMs: Long = 10000,
        serviceUuidFilter: String? = NioxConstants.NIOX_SERVICE_UUID
    ): List<BluetoothDevice>

    /**
     * Stop an ongoing Bluetooth scan
     * Call this to cancel a scan before it completes naturally
     */
    fun stopScan()
}

/**
 * Factory function to create platform-specific implementation
 */
expect fun createNioxCommunicationPlugin(): NioxCommunicationPlugin
