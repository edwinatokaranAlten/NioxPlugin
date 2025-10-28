package com.niox.nioxplugin

import kotlinx.coroutines.*
import kotlinx.cinterop.*
import platform.winrt.ble.*

/**
 * Windows Native WinRT implementation using C++ WinRT wrapper for Bluetooth LE.
 * This implementation provides full BLE functionality with RSSI values.
 */
@OptIn(ExperimentalForeignApi::class)
class WindowsWinRtNativeNioxCommunicationPlugin : NioxCommunicationPlugin {

    private var isScanning = false
    private var currentScanJob: Job? = null

    init {
        // Initialize WinRT
        winrt_initialize()
    }

    override suspend fun checkBluetoothState(): BluetoothState {
        return withContext(Dispatchers.Default) {
            try {
                val state = winrt_check_bluetooth_state()
                when (state) {
                    0 -> BluetoothState.ENABLED
                    1 -> BluetoothState.DISABLED
                    2 -> BluetoothState.UNSUPPORTED
                    else -> BluetoothState.UNKNOWN
                }
            } catch (e: Exception) {
                BluetoothState.UNKNOWN
            }
        }
    }

    override suspend fun scanForDevices(
        scanDurationMs: Long,
        serviceUuidFilter: String?
    ): List<BluetoothDevice> {
        if (isScanning) {
            return emptyList()
        }

        isScanning = true
        val discoveredDevices = mutableMapOf<String, BluetoothDevice>()

        return withContext(Dispatchers.Default) {
            try {
                currentScanJob = coroutineScope {
                    launch {
                        try {
                            performBLEScan(discoveredDevices, scanDurationMs, serviceUuidFilter)
                        } finally {
                            isScanning = false
                        }
                    }
                }

                currentScanJob?.join()
                discoveredDevices.values.toList()
            } catch (e: Exception) {
                isScanning = false
                emptyList()
            }
        }
    }

    override fun stopScan() {
        currentScanJob?.cancel()
        isScanning = false
        winrt_stop_scan()
    }

    private suspend fun performBLEScan(
        discoveredDevices: MutableMap<String, BluetoothDevice>,
        scanDurationMs: Long,
        serviceUuidFilter: String?
    ) {
        withContext(Dispatchers.Default) {
            memScoped {
                try {
                    // Determine if we should filter for NIOX devices only
                    val nioxOnly = if (serviceUuidFilter == NioxConstants.NIOX_SERVICE_UUID) 1 else 0

                    // Define callback for device discovery
                    val callback = staticCFunction<BLEDevice, COpaquePointer?, Unit> { device, userData ->
                        try {
                            // Extract device information
                            val name = device.name?.toKString()
                            val address = device.address?.toKString()
                            val rssi = if (device.hasRssi != 0) device.rssi else null

                            if (address != null) {
                                // Create BluetoothDevice object
                                val btDevice = BluetoothDevice(
                                    name = name,
                                    address = address,
                                    rssi = rssi,
                                    serviceUuids = null, // Not available from C API
                                    advertisingData = mapOf(
                                        "isConnectable" to true
                                    )
                                )

                                // Store in discovered devices map
                                userData?.asStableRef<MutableMap<String, BluetoothDevice>>()?.get()?.let { map ->
                                    map[address] = btDevice
                                }
                            }
                        } catch (e: Exception) {
                            // Ignore callback errors
                        }
                    }

                    // Create stable reference to devices map
                    val mapRef = StableRef.create(discoveredDevices)

                    try {
                        // Start scan with callback
                        val result = winrt_start_scan(
                            scanDurationMs.toInt(),
                            nioxOnly,
                            callback,
                            mapRef.asCPointer()
                        )

                        if (result != 0) {
                            // Scan failed
                            return@withContext
                        }

                        // Wait for scan to complete
                        delay(scanDurationMs + 1000) // Extra second for safety

                    } finally {
                        // Cleanup stable reference
                        mapRef.dispose()
                    }

                } catch (e: Exception) {
                    // Handle errors silently
                }
            }
        }
    }
}

/**
 * Factory function for Windows WinRT Native platform
 */
actual fun createNioxCommunicationPlugin(): NioxCommunicationPlugin {
    return WindowsWinRtNativeNioxCommunicationPlugin()
}
