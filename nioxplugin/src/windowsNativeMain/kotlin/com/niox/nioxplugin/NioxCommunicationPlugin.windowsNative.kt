package com.niox.nioxplugin

import kotlinx.coroutines.*
import kotlinx.cinterop.*
import platform.windows.bluetooth.*
import platform.windows.*

/**
 * Windows Native (mingwX64) implementation using C interop to call Windows Bluetooth APIs directly.
 * This implementation provides full Bluetooth functionality without requiring a JVM runtime.
 */
@OptIn(ExperimentalForeignApi::class)
class WindowsNativeNioxCommunicationPlugin : NioxCommunicationPlugin {

    private var isScanning = false
    private var currentScanJob: Job? = null

    override suspend fun checkBluetoothState(): BluetoothState {
        return withContext(Dispatchers.Default) {
            memScoped {
                try {
                    // Allocate BLUETOOTH_FIND_RADIO_PARAMS structure
                    val radioParams = alloc<BLUETOOTH_FIND_RADIO_PARAMS>()
                    radioParams.dwSize = sizeOf<BLUETOOTH_FIND_RADIO_PARAMS>().toUInt()

                    // Allocate HANDLE pointer
                    val radioHandle = allocPointerTo<HANDLE>()

                    // Try to find first Bluetooth radio
                    val findHandle = BluetoothFindFirstRadio(radioParams.ptr, radioHandle.ptr)

                    if (findHandle == null || findHandle == INVALID_HANDLE_VALUE) {
                        return@withContext BluetoothState.UNSUPPORTED
                    }

                    // Clean up: close find handle
                    BluetoothFindRadioClose(findHandle)

                    // Clean up: close radio handle
                    val radio = radioHandle.pointed.value
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
                    radioParams.dwSize = sizeOf<BLUETOOTH_FIND_RADIO_PARAMS>().toUInt()

                    val radioHandlePtr = allocPointerTo<HANDLE>()
                    val radioFindHandle = BluetoothFindFirstRadio(radioParams.ptr, radioHandlePtr.ptr)

                    if (radioFindHandle == null || radioFindHandle == INVALID_HANDLE_VALUE) {
                        return@withContext
                    }

                    val radioHandle = radioHandlePtr.pointed.value

                    try {
                        // Set up device search parameters
                        val searchParams = alloc<BLUETOOTH_DEVICE_SEARCH_PARAMS>()
                        searchParams.dwSize = sizeOf<BLUETOOTH_DEVICE_SEARCH_PARAMS>().toUInt()
                        searchParams.fReturnAuthenticated = 1u
                        searchParams.fReturnRemembered = 1u
                        searchParams.fReturnUnknown = 1u
                        searchParams.fReturnConnected = 1u
                        searchParams.fIssueInquiry = 1u
                        searchParams.cTimeoutMultiplier = 2u.toUByte()
                        searchParams.hRadio = radioHandle

                        // Allocate device info structure
                        val deviceInfo = alloc<BLUETOOTH_DEVICE_INFO>()
                        deviceInfo.dwSize = sizeOf<BLUETOOTH_DEVICE_INFO>().toUInt()

                        // Start device enumeration
                        val deviceFindHandle = BluetoothFindFirstDevice(searchParams.ptr, deviceInfo.ptr)

                        if (deviceFindHandle != null && deviceFindHandle != INVALID_HANDLE_VALUE) {
                            val startTime = kotlin.system.getTimeMillis()

                            try {
                                do {
                                    // Check if scan duration expired
                                    if (kotlin.system.getTimeMillis() - startTime >= scanDurationMs) {
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
                                                "connected" to (deviceInfo.fConnected != 0u),
                                                "remembered" to (deviceInfo.fRemembered != 0u),
                                                "authenticated" to (deviceInfo.fAuthenticated != 0u)
                                            )
                                        )

                                        discoveredDevices[address] = device
                                    }

                                    // Reset size for next device
                                    deviceInfo.dwSize = sizeOf<BLUETOOTH_DEVICE_INFO>().toUInt()

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
    private fun formatBluetoothAddress(addressBytes: CArrayPointer<UByteVar>): String {
        return buildString {
            for (i in 5 downTo 0) {
                if (i < 5) append(":")
                append(addressBytes[i].toString(16).padStart(2, '0').uppercase())
            }
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
