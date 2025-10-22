package com.niox.nioxplugin

import kotlinx.coroutines.*
import platform.CoreBluetooth.*
import platform.Foundation.NSError
import platform.darwin.NSObject
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine

/**
 * iOS implementation of NioxCommunicationPlugin using CoreBluetooth
 */
class IosNioxCommunicationPlugin : NioxCommunicationPlugin {

    private var activeCentralManager: CBCentralManager? = null
    private var activeScanJob: Job? = null

    override suspend fun checkBluetoothState(): BluetoothState = suspendCoroutine { continuation ->
        var resumed = false

        fun mapState(state: CBManagerState): BluetoothState = when (state) {
            CBManagerStatePoweredOn -> BluetoothState.ENABLED
            CBManagerStatePoweredOff -> BluetoothState.DISABLED
            CBManagerStateUnsupported -> BluetoothState.UNSUPPORTED
            CBManagerStateUnauthorized -> BluetoothState.DISABLED
            else -> BluetoothState.UNKNOWN
        }

        val delegate = object : NSObject(), CBCentralManagerDelegateProtocol {
            override fun centralManagerDidUpdateState(central: CBCentralManager) {
                if (resumed) return
                resumed = true
                continuation.resume(mapState(central.state))
            }
        }

        val manager = CBCentralManager(delegate = delegate, queue = null)

        // If already initialized, return state immediately; otherwise wait for delegate callback
        val current = manager.state
        if (current != CBManagerStateUnknown && !resumed) {
            resumed = true
            continuation.resume(mapState(current))
        }
    }

    override suspend fun scanForDevices(
        scanDurationMs: Long,
        serviceUuidFilter: String?
    ): List<BluetoothDevice> {
        val discoveredDevices = mutableMapOf<String, BluetoothDevice>()

        return suspendCoroutine { continuation ->
            val bluetoothDelegate = BluetoothDelegate { device ->
                discoveredDevices[device.address] = device
            }

            var centralManager: CBCentralManager? = null
            var scanJob: Job? = null

            bluetoothDelegate.onReady = onReady@{
                // Check if Bluetooth is powered on
                if (centralManager?.state != CBManagerStatePoweredOn) {
                    continuation.resume(emptyList())
                    return@onReady
                }

                // Start scanning with optional service UUID filter
                val serviceUUIDs = serviceUuidFilter?.let {
                    listOf(platform.CoreBluetooth.CBUUID.UUIDWithString(it))
                }

                centralManager?.scanForPeripheralsWithServices(
                    serviceUUIDs = serviceUUIDs,
                    options = null
                )

                // Store references for potential stopping
                activeCentralManager = centralManager

                // Stop scan after duration
                scanJob = CoroutineScope(Dispatchers.Default).launch {
                    delay(scanDurationMs)
                    centralManager?.stopScan()
                    activeCentralManager = null
                    activeScanJob = null
                    continuation.resume(discoveredDevices.values.toList())
                }
                activeScanJob = scanJob
            }

            centralManager = CBCentralManager(delegate = bluetoothDelegate, queue = null)
        }
    }

    override fun stopScan() {
        activeScanJob?.cancel()
        activeCentralManager?.stopScan()
        activeCentralManager = null
        activeScanJob = null
    }

    private class BluetoothDelegate(
        private val onDeviceFound: (BluetoothDevice) -> Unit
    ) : NSObject(), CBCentralManagerDelegateProtocol {

        private val discoveredDevices = mutableSetOf<String>()
        var onReady: (() -> Unit)? = null

        override fun centralManagerDidUpdateState(central: CBCentralManager) {
            if (central.state == CBManagerStatePoweredOn) {
                onReady?.invoke()
            }
        }

        override fun centralManager(
            central: CBCentralManager,
            didDiscoverPeripheral: CBPeripheral,
            advertisementData: Map<Any?, *>,
            RSSI: platform.Foundation.NSNumber
        ) {
            val identifier = didDiscoverPeripheral.identifier.UUIDString

            // Avoid duplicates
            if (identifier !in discoveredDevices) {
                discoveredDevices.add(identifier)

                // Extract service UUIDs from advertisement data
                val serviceUuids = mutableListOf<String>()
                (advertisementData[platform.CoreBluetooth.CBAdvertisementDataServiceUUIDsKey] as? List<*>)?.forEach { uuid ->
                    (uuid as? platform.CoreBluetooth.CBUUID)?.let {
                        serviceUuids.add(it.UUIDString)
                    }
                }

                // Extract additional advertising data
                val advData = mutableMapOf<String, Any>()
                (advertisementData[platform.CoreBluetooth.CBAdvertisementDataLocalNameKey] as? String)?.let {
                    advData["localName"] = it
                }
                (advertisementData[platform.CoreBluetooth.CBAdvertisementDataTxPowerLevelKey] as? platform.Foundation.NSNumber)?.let {
                    advData["txPowerLevel"] = it.intValue
                }
                (advertisementData[platform.CoreBluetooth.CBAdvertisementDataIsConnectable] as? platform.Foundation.NSNumber)?.let {
                    advData["isConnectable"] = it.boolValue
                }

                val device = BluetoothDevice(
                    name = didDiscoverPeripheral.name,
                    address = identifier,
                    rssi = RSSI.intValue,
                    serviceUuids = serviceUuids.takeIf { it.isNotEmpty() },
                    advertisingData = advData.takeIf { it.isNotEmpty() }
                )

                onDeviceFound(device)
            }
        }

        override fun centralManager(
            central: CBCentralManager,
            didConnectPeripheral: CBPeripheral
        ) {
            // Not used for scanning
        }

        override fun centralManager(
            central: CBCentralManager,
            didFailToConnectPeripheral: CBPeripheral,
            error: NSError?
        ) {
            // Not used for scanning
        }
    }
}

actual fun createNioxCommunicationPlugin(): NioxCommunicationPlugin {
    return IosNioxCommunicationPlugin()
}
