package com.niox.nioxplugin

import com.sun.jna.Native
import com.sun.jna.Pointer
import com.sun.jna.Structure
import com.sun.jna.Memory
import com.sun.jna.Platform
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Windows implementation of NioxCommunicationPlugin using Windows Bluetooth APIs via JNA
 */
class WindowsNioxCommunicationPlugin : NioxCommunicationPlugin {

    private val executor = Executors.newSingleThreadExecutor()
    private val isScanning = AtomicBoolean(false)

    override suspend fun checkBluetoothState(): BluetoothState {
        return try {
            if (!Platform.isWindows()) {
                return BluetoothState.UNSUPPORTED
            }

            // Try to find Bluetooth radio
            val findParams = BLUETOOTH_FIND_RADIO_PARAMS()
            findParams.dwSize = findParams.size()

            val radioHandle = Memory(Native.POINTER_SIZE.toLong())
            val findHandle = BluetoothAPI.BluetoothFindFirstRadio(findParams, radioHandle)

            if (findHandle == null || findHandle == Pointer.NULL) {
                return BluetoothState.UNSUPPORTED
            }

            try {
                BluetoothAPI.BluetoothFindRadioClose(findHandle)
                return BluetoothState.ENABLED
            } catch (e: Exception) {
                return BluetoothState.UNKNOWN
            }
        } catch (e: Exception) {
            // If we can't load the library or access APIs, assume Bluetooth is unsupported
            BluetoothState.UNSUPPORTED
        }
    }

    override suspend fun scanForDevices(
        scanDurationMs: Long,
        serviceUuidFilter: String?
    ): List<BluetoothDevice> {
        if (!Platform.isWindows()) {
            return emptyList()
        }

        val discoveredDevices = ConcurrentHashMap<String, BluetoothDevice>()
        isScanning.set(true)

        return try {
            val future = executor.submit<List<BluetoothDevice>> {
                try {
                    val startTime = System.currentTimeMillis()

                    while (isScanning.get() && (System.currentTimeMillis() - startTime) < scanDurationMs) {
                        try {
                            scanForBluetoothDevices(discoveredDevices, serviceUuidFilter)
                        } catch (e: Exception) {
                            // Error during scanning, log and continue
                            System.err.println("Bluetooth scan error: ${e.message}")
                        }

                        // Don't scan too frequently to avoid resource exhaustion
                        Thread.sleep(2000)
                    }

                    discoveredDevices.values.toList()
                } finally {
                    isScanning.set(false)
                }
            }

            future.get()
        } catch (e: Exception) {
            isScanning.set(false)
            emptyList()
        }
    }

    private fun scanForBluetoothDevices(
        discoveredDevices: ConcurrentHashMap<String, BluetoothDevice>,
        serviceUuidFilter: String?
    ) {
        // Get first Bluetooth radio
        val findRadioParams = BLUETOOTH_FIND_RADIO_PARAMS()
        findRadioParams.dwSize = findRadioParams.size()
        val radioHandle = Memory(Native.POINTER_SIZE.toLong())
        val radioFindHandle = BluetoothAPI.BluetoothFindFirstRadio(findRadioParams, radioHandle)

        if (radioFindHandle == null || radioFindHandle == Pointer.NULL) {
            return
        }

        try {
            val radio = radioHandle.getPointer(0)

            // Set up device search parameters
            val deviceSearchParams = BLUETOOTH_DEVICE_SEARCH_PARAMS()
            deviceSearchParams.dwSize = deviceSearchParams.size()
            deviceSearchParams.fReturnAuthenticated = 1
            deviceSearchParams.fReturnRemembered = 1
            deviceSearchParams.fReturnUnknown = 1
            deviceSearchParams.fReturnConnected = 1
            deviceSearchParams.fIssueInquiry = 1
            deviceSearchParams.cTimeoutMultiplier = 2
            deviceSearchParams.hRadio = radio

            // Find Bluetooth devices
            val deviceInfo = BLUETOOTH_DEVICE_INFO()
            deviceInfo.dwSize = deviceInfo.size()

            val deviceFindHandle = BluetoothAPI.BluetoothFindFirstDevice(deviceSearchParams, deviceInfo)

            if (deviceFindHandle != null && deviceFindHandle != Pointer.NULL) {
                try {
                    do {
                        val address = formatBluetoothAddress(deviceInfo.Address)

                        if (!discoveredDevices.containsKey(address)) {
                            val deviceName = String(deviceInfo.szName, Charsets.UTF_16LE).trim('\u0000')

                            // Apply service UUID filter if specified (software filtering for Windows)
                            val shouldInclude = if (serviceUuidFilter != null) {
                                // For Windows, we can only filter by device name since
                                // Windows Bluetooth Classic API doesn't expose service UUIDs easily
                                // Check if device name indicates it's a NIOX device
                                deviceName.startsWith("NIOX PRO", ignoreCase = true)
                            } else {
                                true
                            }

                            if (shouldInclude) {
                                val device = BluetoothDevice(
                                    name = if (deviceName.isNotEmpty()) deviceName else null,
                                    address = address,
                                    rssi = null, // RSSI not easily available in Windows Bluetooth Classic API
                                    serviceUuids = null, // Service UUIDs not easily available in Windows Bluetooth Classic API
                                    advertisingData = null // Limited advertising data in Windows Bluetooth Classic API
                                )

                                discoveredDevices[address] = device
                            }
                        }

                        // Reset struct for next iteration
                        deviceInfo.dwSize = deviceInfo.size()

                    } while (isScanning.get() && BluetoothAPI.BluetoothFindNextDevice(deviceFindHandle, deviceInfo))

                } finally {
                    BluetoothAPI.BluetoothFindDeviceClose(deviceFindHandle)
                }
            }
        } finally {
            BluetoothAPI.BluetoothFindRadioClose(radioFindHandle)
        }
    }

    private fun formatBluetoothAddress(address: ByteArray): String {
        return address.joinToString(":") { byte ->
            "%02X".format(byte.toInt() and 0xFF)
        }
    }

    /**
     * JNA structures for Windows Bluetooth API
     */
    @Structure.FieldOrder("dwSize")
    class BLUETOOTH_FIND_RADIO_PARAMS : Structure() {
        @JvmField var dwSize: Int = 0
    }

    @Structure.FieldOrder(
        "dwSize", "fReturnAuthenticated", "fReturnRemembered", "fReturnUnknown",
        "fReturnConnected", "fIssueInquiry", "cTimeoutMultiplier", "hRadio"
    )
    class BLUETOOTH_DEVICE_SEARCH_PARAMS : Structure() {
        @JvmField var dwSize: Int = 0
        @JvmField var fReturnAuthenticated: Int = 0
        @JvmField var fReturnRemembered: Int = 0
        @JvmField var fReturnUnknown: Int = 0
        @JvmField var fReturnConnected: Int = 0
        @JvmField var fIssueInquiry: Int = 0
        @JvmField var cTimeoutMultiplier: Byte = 0
        @JvmField var hRadio: Pointer? = null
    }

    @Structure.FieldOrder(
        "dwSize", "Address", "ulClassofDevice", "fConnected", "fRemembered",
        "fAuthenticated", "stLastSeen", "stLastUsed", "szName"
    )
    class BLUETOOTH_DEVICE_INFO : Structure() {
        @JvmField var dwSize: Int = 0
        @JvmField var Address: ByteArray = ByteArray(6)
        @JvmField var ulClassofDevice: Int = 0
        @JvmField var fConnected: Int = 0
        @JvmField var fRemembered: Int = 0
        @JvmField var fAuthenticated: Int = 0
        @JvmField var stLastSeen: SYSTEMTIME = SYSTEMTIME()
        @JvmField var stLastUsed: SYSTEMTIME = SYSTEMTIME()
        @JvmField var szName: ByteArray = ByteArray(248 * 2) // WCHAR[248]
    }

    @Structure.FieldOrder("wYear", "wMonth", "wDayOfWeek", "wDay", "wHour", "wMinute", "wSecond", "wMilliseconds")
    class SYSTEMTIME : Structure() {
        @JvmField var wYear: Short = 0
        @JvmField var wMonth: Short = 0
        @JvmField var wDayOfWeek: Short = 0
        @JvmField var wDay: Short = 0
        @JvmField var wHour: Short = 0
        @JvmField var wMinute: Short = 0
        @JvmField var wSecond: Short = 0
        @JvmField var wMilliseconds: Short = 0
    }

    /**
     * JNA interface for Windows Bluetooth API
     */
    private object BluetoothAPI {
        init {
            try {
                Native.register("Bthprops.cpl")
            } catch (e: Exception) {
                System.err.println("Warning: Could not load Windows Bluetooth library (Bthprops.cpl): ${e.message}")
            }
        }

        external fun BluetoothFindFirstRadio(
            pbtfrp: BLUETOOTH_FIND_RADIO_PARAMS,
            phRadio: Pointer
        ): Pointer?

        external fun BluetoothFindRadioClose(hFind: Pointer): Boolean

        external fun BluetoothFindFirstDevice(
            pbtsp: BLUETOOTH_DEVICE_SEARCH_PARAMS,
            pbtdi: BLUETOOTH_DEVICE_INFO
        ): Pointer?

        external fun BluetoothFindNextDevice(
            hFind: Pointer,
            pbtdi: BLUETOOTH_DEVICE_INFO
        ): Boolean

        external fun BluetoothFindDeviceClose(hFind: Pointer): Boolean
    }
}

actual fun createNioxCommunicationPlugin(): NioxCommunicationPlugin {
    return WindowsNioxCommunicationPlugin()
}
