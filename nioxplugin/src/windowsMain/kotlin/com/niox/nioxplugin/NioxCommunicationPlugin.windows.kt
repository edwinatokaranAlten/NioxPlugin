package com.niox.nioxplugin

import com.sun.jna.Library
import com.sun.jna.Native
import com.sun.jna.Pointer
import com.sun.jna.Structure
import com.sun.jna.ptr.ByReference
import com.sun.jna.platform.win32.WinDef.DWORD
import com.sun.jna.platform.win32.WinNT.HANDLE
import kotlinx.coroutines.*
import java.nio.charset.StandardCharsets
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Windows JVM implementation of NioxCommunicationPlugin using JNA to access Windows Bluetooth APIs
 */
class WindowsNioxCommunicationPlugin : NioxCommunicationPlugin {

    private val isScanning = AtomicBoolean(false)
    private var currentScanJob: Job? = null

    override suspend fun checkBluetoothState(): BluetoothState {
        return withContext(Dispatchers.IO) {
            try {
                val params = BluetoothFindRadioParams()
                params.dwSize = params.size()

                val handleRef = HANDLEByReference()
                val findHandle = BluetoothLib.BluetoothFindFirstRadio(params, handleRef)

                if (findHandle == null || findHandle.pointer == Pointer.NULL) {
                    return@withContext BluetoothState.UNSUPPORTED
                }

                // Found at least one radio, close the find handle
                BluetoothLib.BluetoothFindRadioClose(findHandle)

                // Close the radio handle
                if (handleRef.value != null && handleRef.value.pointer != Pointer.NULL) {
                    Kernel32Lib.CloseHandle(handleRef.value)
                }

                BluetoothState.ENABLED
            } catch (e: UnsatisfiedLinkError) {
                // Bluetooth libraries not available
                BluetoothState.UNSUPPORTED
            } catch (e: Exception) {
                BluetoothState.UNKNOWN
            }
        }
    }

    override suspend fun scanForDevices(
        scanDurationMs: Long,
        serviceUuidFilter: String?
    ): List<BluetoothDevice> {
        if (!isScanning.compareAndSet(false, true)) {
            // Already scanning
            return emptyList()
        }

        val discoveredDevices = ConcurrentHashMap<String, BluetoothDevice>()

        return withContext(Dispatchers.IO) {
            try {
                currentScanJob = coroutineScope {
                    launch {
                        try {
                            performBluetoothScan(discoveredDevices, scanDurationMs, serviceUuidFilter)
                        } finally {
                            isScanning.set(false)
                        }
                    }
                }

                currentScanJob?.join()
                discoveredDevices.values.toList()
            } catch (e: Exception) {
                isScanning.set(false)
                emptyList()
            }
        }
    }

    override fun stopScan() {
        currentScanJob?.cancel()
        isScanning.set(false)
    }

    private suspend fun performBluetoothScan(
        discoveredDevices: ConcurrentHashMap<String, BluetoothDevice>,
        scanDurationMs: Long,
        serviceUuidFilter: String?
    ) {
        withContext(Dispatchers.IO) {
            try {
                // Get first Bluetooth radio
                val radioParams = BluetoothFindRadioParams()
                radioParams.dwSize = radioParams.size()

                val radioHandleRef = HANDLEByReference()
                val radioFindHandle = BluetoothLib.BluetoothFindFirstRadio(radioParams, radioHandleRef)

                if (radioFindHandle == null || radioFindHandle.pointer == Pointer.NULL) {
                    return@withContext
                }

                val radioHandle = radioHandleRef.value

                try {
                    // Set up device search parameters
                    val searchParams = BluetoothDeviceSearchParams()
                    searchParams.dwSize = searchParams.size()
                    searchParams.fReturnAuthenticated = 1
                    searchParams.fReturnRemembered = 1
                    searchParams.fReturnUnknown = 1
                    searchParams.fReturnConnected = 1
                    searchParams.fIssueInquiry = 1
                    searchParams.cTimeoutMultiplier = 2 // 2 * 1.28 seconds
                    searchParams.hRadio = radioHandle

                    val deviceInfo = BluetoothDeviceInfo()
                    deviceInfo.dwSize = deviceInfo.size()

                    // Start device enumeration
                    val deviceFindHandle = BluetoothLib.BluetoothFindFirstDevice(searchParams, deviceInfo)

                    if (deviceFindHandle != null && deviceFindHandle.pointer != Pointer.NULL) {
                        val startTime = System.currentTimeMillis()

                        try {
                            do {
                                // Check if scan duration expired
                                if (System.currentTimeMillis() - startTime >= scanDurationMs) {
                                    break
                                }

                                // Check if scan was cancelled
                                if (!isScanning.get()) {
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
                                        rssi = null, // Windows Bluetooth Classic API doesn't provide RSSI
                                        serviceUuids = null,
                                        advertisingData = mapOf(
                                            "classOfDevice" to deviceInfo.ulClassofDevice.toInt(),
                                            "connected" to deviceInfo.fConnected,
                                            "remembered" to deviceInfo.fRemembered,
                                            "authenticated" to deviceInfo.fAuthenticated
                                        )
                                    )

                                    discoveredDevices[address] = device
                                }

                                // Get next device
                                deviceInfo.dwSize = deviceInfo.size()
                            } while (BluetoothLib.BluetoothFindNextDevice(deviceFindHandle, deviceInfo))

                        } finally {
                            BluetoothLib.BluetoothFindDeviceClose(deviceFindHandle)
                        }
                    }
                } finally {
                    BluetoothLib.BluetoothFindRadioClose(radioFindHandle)
                    if (radioHandle.pointer != Pointer.NULL) {
                        Kernel32Lib.CloseHandle(radioHandle)
                    }
                }
            } catch (e: Exception) {
                // Silently handle errors
            }
        }
    }

    private fun formatBluetoothAddress(addressBytes: ByteArray): String {
        return addressBytes.take(6)
            .reversed()
            .joinToString(":") { byte ->
                String.format("%02X", byte)
            }
    }

    private fun extractDeviceName(nameBytes: ByteArray): String? {
        return try {
            val nullIndex = nameBytes.indexOf(0)
            val validBytes = if (nullIndex >= 0) {
                nameBytes.copyOfRange(0, nullIndex)
            } else {
                nameBytes
            }

            if (validBytes.isEmpty()) {
                null
            } else {
                String(validBytes, StandardCharsets.UTF_16LE).trim().takeIf { it.isNotEmpty() }
            }
        } catch (e: Exception) {
            null
        }
    }
}

// ===========================
// JNA Structures and Interfaces
// ===========================

/**
 * HANDLE by reference for JNA
 */
class HANDLEByReference : ByReference(Native.POINTER_SIZE) {
    var value: HANDLE
        get() = HANDLE(pointer.getPointer(0))
        set(value) = pointer.setPointer(0, value.pointer)
}

/**
 * BLUETOOTH_FIND_RADIO_PARAMS structure
 */
@Structure.FieldOrder("dwSize")
class BluetoothFindRadioParams : Structure() {
    @JvmField var dwSize: Int = 0
}

/**
 * BLUETOOTH_DEVICE_SEARCH_PARAMS structure
 */
@Structure.FieldOrder(
    "dwSize",
    "fReturnAuthenticated",
    "fReturnRemembered",
    "fReturnUnknown",
    "fReturnConnected",
    "fIssueInquiry",
    "cTimeoutMultiplier",
    "hRadio"
)
class BluetoothDeviceSearchParams : Structure() {
    @JvmField var dwSize: Int = 0
    @JvmField var fReturnAuthenticated: Int = 0
    @JvmField var fReturnRemembered: Int = 0
    @JvmField var fReturnUnknown: Int = 0
    @JvmField var fReturnConnected: Int = 0
    @JvmField var fIssueInquiry: Int = 0
    @JvmField var cTimeoutMultiplier: Byte = 0
    @JvmField var hRadio: HANDLE? = null
}

/**
 * BLUETOOTH_DEVICE_INFO structure
 */
@Structure.FieldOrder(
    "dwSize",
    "Address",
    "ulClassofDevice",
    "fConnected",
    "fRemembered",
    "fAuthenticated",
    "stLastSeen",
    "stLastUsed",
    "szName"
)
class BluetoothDeviceInfo : Structure() {
    @JvmField var dwSize: Int = 0
    @JvmField var Address: ByteArray = ByteArray(8) // BLUETOOTH_ADDRESS (6 bytes + 2 padding)
    @JvmField var ulClassofDevice: DWORD = DWORD(0)
    @JvmField var fConnected: Int = 0
    @JvmField var fRemembered: Int = 0
    @JvmField var fAuthenticated: Int = 0
    @JvmField var stLastSeen: SYSTEMTIME = SYSTEMTIME()
    @JvmField var stLastUsed: SYSTEMTIME = SYSTEMTIME()
    @JvmField var szName: ByteArray = ByteArray(248) // 248 bytes for device name (WCHAR[248])
}

/**
 * SYSTEMTIME structure
 */
@Structure.FieldOrder(
    "wYear",
    "wMonth",
    "wDayOfWeek",
    "wDay",
    "wHour",
    "wMinute",
    "wSecond",
    "wMilliseconds"
)
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
 * Windows Bluetooth API bindings
 */
interface BluetoothLibrary : Library {
    fun BluetoothFindFirstRadio(
        pbtfrp: BluetoothFindRadioParams,
        phRadio: HANDLEByReference
    ): HANDLE?

    fun BluetoothFindNextRadio(
        hFind: HANDLE,
        phRadio: HANDLEByReference
    ): Boolean

    fun BluetoothFindRadioClose(hFind: HANDLE): Boolean

    fun BluetoothFindFirstDevice(
        pbtsp: BluetoothDeviceSearchParams,
        pbtdi: BluetoothDeviceInfo
    ): HANDLE?

    fun BluetoothFindNextDevice(
        hFind: HANDLE,
        pbtdi: BluetoothDeviceInfo
    ): Boolean

    fun BluetoothFindDeviceClose(hFind: HANDLE): Boolean
}

/**
 * Kernel32 API bindings
 */
interface Kernel32Library : Library {
    fun CloseHandle(hObject: HANDLE): Boolean
}

// Singleton instances
private val BluetoothLib: BluetoothLibrary by lazy {
    Native.load("Bthprops.cpl", BluetoothLibrary::class.java) as BluetoothLibrary
}

private val Kernel32Lib: Kernel32Library by lazy {
    Native.load("kernel32", Kernel32Library::class.java) as Kernel32Library
}

/**
 * Factory function for Windows platform
 */
actual fun createNioxCommunicationPlugin(): NioxCommunicationPlugin {
    return WindowsNioxCommunicationPlugin()
}
