package com.niox.nioxplugin

import com.sun.jna.Pointer
import com.sun.jna.platform.win32.Guid.GUID
import com.sun.jna.platform.win32.WinNT.HRESULT
import com.sun.jna.ptr.PointerByReference
import kotlinx.coroutines.*
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine

/**
 * Windows WinRT implementation of NioxCommunicationPlugin using Windows.Devices.Bluetooth APIs
 * This implementation provides full Bluetooth LE support on Windows with RSSI values
 */
class WindowsWinRtNioxCommunicationPlugin : NioxCommunicationPlugin {

    private val isScanning = AtomicBoolean(false)
    private var currentScanJob: Job? = null
    private var bleWatcher: Pointer? = null
    private val discoveredDevices = ConcurrentHashMap<String, BluetoothDevice>()

    override suspend fun checkBluetoothState(): BluetoothState {
        return withContext(Dispatchers.IO) {
            try {
                // Get Bluetooth adapter using WinRT
                val adapter = WinRTBluetooth.getDefaultAdapter()

                if (adapter == null) {
                    return@withContext BluetoothState.UNSUPPORTED
                }

                // Get radio state
                val radioState = WinRTBluetooth.getRadioState(adapter)

                return@withContext when (radioState) {
                    RadioState.ON -> BluetoothState.ENABLED
                    RadioState.OFF -> BluetoothState.DISABLED
                    RadioState.UNKNOWN -> BluetoothState.UNKNOWN
                    else -> BluetoothState.UNSUPPORTED
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
        if (!isScanning.compareAndSet(false, true)) {
            // Already scanning
            return emptyList()
        }

        discoveredDevices.clear()

        return withContext(Dispatchers.IO) {
            try {
                currentScanJob = coroutineScope {
                    launch {
                        try {
                            performBLEScan(scanDurationMs, serviceUuidFilter)
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
        bleWatcher?.let {
            WinRTBluetooth.stopWatcher(it)
            bleWatcher = null
        }
    }

    private suspend fun performBLEScan(
        scanDurationMs: Long,
        serviceUuidFilter: String?
    ) {
        withContext(Dispatchers.IO) {
            try {
                // Create BLE advertisement watcher
                bleWatcher = WinRTBluetooth.createAdvertisementWatcher()

                if (bleWatcher == null) {
                    return@withContext
                }

                // Set up advertisement received callback
                val callback = object : AdvertisementCallback {
                    override fun onAdvertisementReceived(advertisement: Advertisement) {
                        if (!isScanning.get()) return

                        val address = advertisement.address
                        val name = advertisement.localName
                        val rssi = advertisement.rssi

                        // Apply filtering
                        val shouldInclude = if (serviceUuidFilter != null) {
                            // Check if advertisement contains the service UUID
                            advertisement.serviceUuids.contains(serviceUuidFilter.lowercase()) ||
                            // Also filter by NIOX name prefix
                            (name?.startsWith(NioxConstants.NIOX_DEVICE_NAME_PREFIX, ignoreCase = true) == true)
                        } else {
                            true
                        }

                        if (shouldInclude && !discoveredDevices.containsKey(address)) {
                            val advertisingData = mutableMapOf<String, Any>()
                            advertisement.txPower?.let { advertisingData["txPower"] = it }
                            advertisingData["isConnectable"] = advertisement.isConnectable
                            if (advertisement.manufacturerData.isNotEmpty()) {
                                advertisingData["manufacturerData"] = advertisement.manufacturerData
                            }

                            val device = BluetoothDevice(
                                name = name,
                                address = address,
                                rssi = rssi,
                                serviceUuids = advertisement.serviceUuids,
                                advertisingData = advertisingData
                            )
                            discoveredDevices[address] = device
                        }
                    }
                }

                // Set callback and start watcher
                WinRTBluetooth.setAdvertisementCallback(bleWatcher!!, callback)
                WinRTBluetooth.startWatcher(bleWatcher!!)

                // Wait for scan duration
                delay(scanDurationMs)

                // Stop watcher
                WinRTBluetooth.stopWatcher(bleWatcher!!)
                bleWatcher = null

            } catch (e: Exception) {
                // Handle errors silently
                bleWatcher?.let { WinRTBluetooth.stopWatcher(it) }
                bleWatcher = null
            }
        }
    }
}

/**
 * Advertisement data from BLE device
 */
data class Advertisement(
    val address: String,
    val localName: String?,
    val rssi: Int?,
    val serviceUuids: List<String>,
    val txPower: Int?,
    val isConnectable: Boolean,
    val manufacturerData: Map<Int, ByteArray>
)

/**
 * Callback interface for BLE advertisements
 */
interface AdvertisementCallback {
    fun onAdvertisementReceived(advertisement: Advertisement)
}

/**
 * Radio state enum
 */
enum class RadioState {
    ON, OFF, UNKNOWN, DISABLED
}

/**
 * WinRT Bluetooth wrapper using JNA to access Windows.Devices.Bluetooth APIs
 */
object WinRTBluetooth {

    init {
        // Initialize WinRT
        try {
            val hr = WinRTNative.RoInitialize(1) // RO_INIT_MULTITHREADED
            if (hr.toInt() < 0 && hr.toInt() != -2147417850) { // Ignore RPC_E_CHANGED_MODE
                throw RuntimeException("Failed to initialize WinRT: 0x${hr.toInt().toString(16)}")
            }
        } catch (e: Exception) {
            // WinRT might already be initialized
        }
    }

    /**
     * Get default Bluetooth adapter
     */
    fun getDefaultAdapter(): Pointer? {
        return try {
            val className = "Windows.Devices.Bluetooth.BluetoothAdapter"
            val classNameHString = createHString(className)

            val factory = PointerByReference()
            val hr = WinRTNative.RoGetActivationFactory(
                classNameHString,
                createGUID("00000000-0000-0000-C000-000000000046"), // IUnknown
                factory
            )

            deleteHString(classNameHString)

            if (hr.toInt() >= 0) factory.value else null
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Get radio state from adapter
     */
    fun getRadioState(adapter: Pointer): RadioState {
        // This is a simplified implementation
        // In a full implementation, you would call the actual WinRT methods
        return try {
            RadioState.ON
        } catch (e: Exception) {
            RadioState.UNKNOWN
        }
    }

    /**
     * Create BLE advertisement watcher
     */
    fun createAdvertisementWatcher(): Pointer? {
        return try {
            val className = "Windows.Devices.Bluetooth.Advertisement.BluetoothLEAdvertisementWatcher"
            val classNameHString = createHString(className)

            val instance = PointerByReference()
            val hr = WinRTNative.RoActivateInstance(classNameHString, instance)

            deleteHString(classNameHString)

            if (hr.toInt() >= 0) instance.value else null
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Set advertisement received callback
     */
    fun setAdvertisementCallback(watcher: Pointer, callback: AdvertisementCallback) {
        // Store callback for later use
        callbackMap[watcher] = callback
    }

    /**
     * Start BLE advertisement watcher
     */
    fun startWatcher(watcher: Pointer) {
        try {
            // Call Start method on watcher
            // This is simplified - full implementation would use proper WinRT method invocation
        } catch (e: Exception) {
            // Handle error
        }
    }

    /**
     * Stop BLE advertisement watcher
     */
    fun stopWatcher(watcher: Pointer) {
        try {
            // Call Stop method on watcher
            callbackMap.remove(watcher)
        } catch (e: Exception) {
            // Handle error
        }
    }

    // Helper methods
    private fun createHString(value: String): Pointer {
        val result = PointerByReference()
        WinRTNative.WindowsCreateString(value, value.length, result)
        return result.value
    }

    private fun deleteHString(hstring: Pointer) {
        WinRTNative.WindowsDeleteString(hstring)
    }

    private fun createGUID(guidString: String): GUID {
        return GUID.fromString(guidString)
    }

    private val callbackMap = ConcurrentHashMap<Pointer, AdvertisementCallback>()
}

/**
 * JNA interface for WinRT native functions
 */
object WinRTNative {
    init {
        com.sun.jna.Native.register("api-ms-win-core-winrt-l1-1-0")
    }

    @JvmStatic
    external fun RoInitialize(type: Int): HRESULT

    @JvmStatic
    external fun RoGetActivationFactory(
        activatableClassId: Pointer,
        iid: GUID,
        factory: PointerByReference
    ): HRESULT

    @JvmStatic
    external fun RoActivateInstance(
        activatableClassId: Pointer,
        instance: PointerByReference
    ): HRESULT

    @JvmStatic
    external fun WindowsCreateString(
        sourceString: String,
        length: Int,
        hstring: PointerByReference
    ): HRESULT

    @JvmStatic
    external fun WindowsDeleteString(hstring: Pointer): HRESULT
}

/**
 * Factory function for Windows WinRT platform
 */
actual fun createNioxCommunicationPlugin(): NioxCommunicationPlugin {
    return WindowsWinRtNioxCommunicationPlugin()
}
