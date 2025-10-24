package com.niox.nioxplugin

import kotlinx.coroutines.*
import kotlinx.cinterop.*
import platform.windows.bluetooth.*
import platform.windows.*
import platform.windows.GetTickCount64

/**
 * Windows Native (mingwX64) implementation using C interop to call Windows Bluetooth APIs directly.
 * This implementation provides full Bluetooth functionality without requiring a JVM runtime.
 */
@OptIn(ExperimentalForeignApi::class, UnsafeNumber::class)
class WindowsNativeNioxCommunicationPlugin : NioxCommunicationPlugin {

    private var isScanning = false
    private var currentScanJob: Job? = null

    override suspend fun checkBluetoothState(): BluetoothState {
        return withContext(Dispatchers.Default) {
            memScoped {
                try {
                    // Allocate BLUETOOTH_FIND_RADIO_PARAMS structure
                    val radioParams = alloc<BLUETOOTH_FIND_RADIO_PARAMS>()
                    radioParams.dwSize = sizeOf<BLUETOOTH_FIND_RADIO_PARAMS>().convert()

                    // Allocate HANDLE variable
                    val radioHandle = alloc<HANDLEVar>()

                    // Try to find first Bluetooth radio
                    val findHandle = BluetoothFindFirstRadio(radioParams.ptr, radioHandle.ptr)

                    if (findHandle == null || findHandle == INVALID_HANDLE_VALUE) {
                        return@withContext BluetoothState.UNSUPPORTED
                    }

                    // Clean up: close find handle
                    BluetoothFindRadioClose(findHandle)

                    // Clean up: close radio handle
                    val radio = radioHandle.value
                    if (radio != null && radio != INVALID_HANDLE_VALUE) {
                        CloseHandle(radio)
                    }

                    BluetoothState.ENABLED
                } catch (e: Exception) {
                    BluetoothState.UNKNOWN
                }
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
                            performBluetoothScan(discoveredDevices, scanDurationMs, serviceUuidFilter)
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
    }

    private suspend fun performBluetoothScan(
        discoveredDevices: MutableMap<String, BluetoothDevice>,
        scanDurationMs: Long,
        serviceUuidFilter: String?
    ) {
        withContext(Dispatchers.Default) {
            memScoped {
                try {
                    // Find first Bluetooth radio
                    val radioParams = alloc<BLUETOOTH_FIND_RADIO_PARAMS>()
                    radioParams.dwSize = sizeOf<BLUETOOTH_FIND_RADIO_PARAMS>().convert()

                    val radioHandleVar = alloc<HANDLEVar>()
                    val radioFindHandle = BluetoothFindFirstRadio(radioParams.ptr, radioHandleVar.ptr)

                    if (radioFindHandle == null || radioFindHandle == INVALID_HANDLE_VALUE) {
                        return@withContext
                    }

                    val radioHandle = radioHandleVar.value

                    try {
                        // Set up device search parameters
                        val searchParams = alloc<BLUETOOTH_DEVICE_SEARCH_PARAMS>()
                        searchParams.dwSize = sizeOf<BLUETOOTH_DEVICE_SEARCH_PARAMS>().convert()
                        searchParams.fReturnAuthenticated = 1
                        searchParams.fReturnRemembered = 1
                        searchParams.fReturnUnknown = 1
                        searchParams.fReturnConnected = 1
                        searchParams.fIssueInquiry = 1
                        searchParams.cTimeoutMultiplier = 2u.convert()
                        searchParams.hRadio = radioHandle

                        // Allocate device info structure
                        val deviceInfo = alloc<BLUETOOTH_DEVICE_INFO>()
                        deviceInfo.dwSize = sizeOf<BLUETOOTH_DEVICE_INFO>().convert()

                        // Start device enumeration
                        val deviceFindHandle = BluetoothFindFirstDevice(searchParams.ptr, deviceInfo.ptr)

                        if (deviceFindHandle != null && deviceFindHandle != INVALID_HANDLE_VALUE) {
                            val startTime = GetTickCount64()?.toLong() ?: 0L

                            try {
                                do {
                                    // Check if scan duration expired
                                    val currentTime = GetTickCount64()?.toLong() ?: 0L
                                    if (currentTime - startTime >= scanDurationMs) {
                                        break
                                    }

                                    // Check if scan was cancelled
                                    if (!isScanning) {
                                        break
                                    }

                                    // Extract device information
                                    val address = formatBluetoothAddress(deviceInfo.Address)
                                    val name = extractDeviceName(deviceInfo.szName)

                                    // Apply NIOX service UUID filter if provided
                                    val shouldInclude = if (serviceUuidFilter != null) {
                                        // For NIOX devices, check by name prefix
                                        name?.startsWith(NioxConstants.NIOX_DEVICE_NAME_PREFIX, ignoreCase = true) == true
                                    } else {
                                        true
                                    }

                                    if (shouldInclude && !discoveredDevices.containsKey(address)) {
                                        val device = BluetoothDevice(
                                            name = name,
                                            address = address,
                                            rssi = null, // RSSI not available in Windows Bluetooth Classic API
                                            serviceUuids = null,
                                            advertisingData = mapOf(
                                                "classOfDevice" to deviceInfo.ulClassofDevice.toInt(),
                                                "connected" to (deviceInfo.fConnected != 0),
                                                "remembered" to (deviceInfo.fRemembered != 0),
                                                "authenticated" to (deviceInfo.fAuthenticated != 0)
                                            )
                                        )

                                        discoveredDevices[address] = device
                                    }

                                    // Reset size for next device
                                    deviceInfo.dwSize = sizeOf<BLUETOOTH_DEVICE_INFO>().convert()

                                } while (BluetoothFindNextDevice(deviceFindHandle, deviceInfo.ptr) != 0)

                            } finally {
                                BluetoothFindDeviceClose(deviceFindHandle)
                            }
                        }
                    } finally {
                        BluetoothFindRadioClose(radioFindHandle)
                        if (radioHandle != null && radioHandle != INVALID_HANDLE_VALUE) {
                            CloseHandle(radioHandle)
                        }
                    }
                } catch (e: Exception) {
                    // Silently handle errors
                }
            }
        }
    }

    @OptIn(ExperimentalForeignApi::class)
    private fun formatBluetoothAddress(address: BLUETOOTH_ADDRESS): String {
        // BLUETOOTH_ADDRESS is a structure with a byte array
        // Access the byte array (ullLong or rgBytes depending on Windows SDK version)
        return try {
            // Try to format as MAC address from the structure
            val bytes = ByteArray(6)
            // The address is stored in the ullLong field as a 48-bit value
            // We need to extract bytes in reverse order (little-endian)
            val addrValue = address.ullLong.toLong()
            for (i in 0..5) {
                bytes[5 - i] = ((addrValue shr (i * 8)) and 0xFF).toByte()
            }

            bytes.joinToString(":") { byte ->
                val hex = byte.toUByte().toInt().toString(16).uppercase()
                if (hex.length == 1) "0$hex" else hex
            }
        } catch (e: Exception) {
            "00:00:00:00:00:00"
        }
    }

    @OptIn(ExperimentalForeignApi::class)
    private fun extractDeviceName(nameBytes: CArrayPointer<WCHARVar>): String? {
        return try {
            // Convert wide character string to Kotlin String
            val name = nameBytes.toKString()
            name.takeIf { it.isNotEmpty() }
        } catch (e: Exception) {
            null
        }
    }
}

/**
 * Factory function for Windows Native platform
 */
actual fun createNioxCommunicationPlugin(): NioxCommunicationPlugin {
    return WindowsNativeNioxCommunicationPlugin()
}
