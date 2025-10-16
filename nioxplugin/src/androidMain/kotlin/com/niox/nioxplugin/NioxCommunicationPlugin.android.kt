package com.niox.nioxplugin

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice as AndroidBluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import kotlinx.coroutines.delay
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

/**
 * Android implementation of NioxCommunicationPlugin
 */
class AndroidNioxCommunicationPlugin(private val context: Context) : NioxCommunicationPlugin {

    private val bluetoothManager: BluetoothManager? =
        context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager

    private val bluetoothAdapter: BluetoothAdapter? = bluetoothManager?.adapter

    private var bluetoothLeScanner: BluetoothLeScanner? = bluetoothAdapter?.bluetoothLeScanner

    private var currentScanCallback: ScanCallback? = null

    override suspend fun checkBluetoothState(): BluetoothState {
        return when {
            bluetoothAdapter == null -> BluetoothState.UNSUPPORTED
            bluetoothAdapter.isEnabled -> BluetoothState.ENABLED
            else -> BluetoothState.DISABLED
        }
    }

    override suspend fun scanForDevices(
        scanDurationMs: Long,
        serviceUuidFilter: String?
    ): List<BluetoothDevice> {
        // Check if Bluetooth is available and enabled
        if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled) {
            return emptyList()
        }

        // Check permissions
        if (!hasBluetoothPermissions()) {
            return emptyList()
        }

        val scanner = bluetoothLeScanner ?: return emptyList()

        val discoveredDevices = mutableMapOf<String, BluetoothDevice>()

        return suspendCancellableCoroutine { continuation ->
            val scanCallback = object : ScanCallback() {
                override fun onScanResult(callbackType: Int, result: ScanResult?) {
                    result?.let { scanResult ->
                        val device = scanResult.device
                        val address = device.address

                        // Avoid duplicates
                        if (address !in discoveredDevices) {
                            // Extract service UUIDs from scan record
                            val serviceUuids = scanResult.scanRecord?.serviceUuids?.map { uuid ->
                                uuid.toString()
                            }

                            // Extract advertising data
                            val advertisingData = mutableMapOf<String, Any>()
                            scanResult.scanRecord?.let { record ->
                                record.txPowerLevel.let { if (it != Int.MIN_VALUE) advertisingData["txPowerLevel"] = it }
                                record.advertiseFlags.let { if (it != -1) advertisingData["flags"] = it }
                                record.deviceName?.let { advertisingData["localName"] = it }
                            }

                            val bluetoothDevice = BluetoothDevice(
                                name = try {
                                    if (hasBluetoothConnectPermission()) {
                                        device.name ?: scanResult.scanRecord?.deviceName
                                    } else {
                                        scanResult.scanRecord?.deviceName
                                    }
                                } catch (e: SecurityException) {
                                    scanResult.scanRecord?.deviceName
                                },
                                address = address,
                                rssi = scanResult.rssi,
                                serviceUuids = serviceUuids,
                                advertisingData = advertisingData.takeIf { it.isNotEmpty() }
                            )

                            discoveredDevices[address] = bluetoothDevice
                        }
                    }
                }

                override fun onScanFailed(errorCode: Int) {
                    super.onScanFailed(errorCode)
                    currentScanCallback?.let { scanner.stopScan(it) }
                    currentScanCallback = null
                    continuation.resume(discoveredDevices.values.toList())
                }
            }

            currentScanCallback = scanCallback

            try {
                // If service UUID filter is provided, use it
                if (serviceUuidFilter != null) {
                    val scanFilters = listOf(
                        android.bluetooth.le.ScanFilter.Builder()
                            .setServiceUuid(android.os.ParcelUuid.fromString(serviceUuidFilter))
                            .build()
                    )
                    val scanSettings = android.bluetooth.le.ScanSettings.Builder()
                        .setScanMode(android.bluetooth.le.ScanSettings.SCAN_MODE_LOW_LATENCY)
                        .build()
                    scanner.startScan(scanFilters, scanSettings, scanCallback)
                } else {
                    scanner.startScan(scanCallback)
                }

                // Schedule scan stop after duration
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    try {
                        if (hasBluetoothScanPermission()) {
                            scanner.stopScan(scanCallback)
                        }
                    } catch (e: SecurityException) {
                        // Ignore
                    } finally {
                        currentScanCallback = null
                        continuation.resume(discoveredDevices.values.toList())
                    }
                }, scanDurationMs)

                continuation.invokeOnCancellation {
                    try {
                        if (hasBluetoothScanPermission()) {
                            scanner.stopScan(scanCallback)
                        }
                    } catch (e: SecurityException) {
                        // Ignore
                    }
                    currentScanCallback = null
                }
            } catch (e: SecurityException) {
                currentScanCallback = null
                continuation.resume(emptyList())
            }
        }
    }

    private fun hasBluetoothPermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            hasBluetoothScanPermission() && hasBluetoothConnectPermission()
        } else {
            hasLocationPermission()
        }
    }

    private fun hasBluetoothScanPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.BLUETOOTH_SCAN
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun hasBluetoothConnectPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.BLUETOOTH_CONNECT
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }
}

actual fun createNioxCommunicationPlugin(): NioxCommunicationPlugin {
    throw IllegalStateException(
        "Android implementation requires Context. " +
        "Use createNioxCommunicationPlugin(context: Context) instead"
    )
}

/**
 * Android-specific factory function that requires Context
 */
fun createNioxCommunicationPlugin(context: Context): NioxCommunicationPlugin {
    return AndroidNioxCommunicationPlugin(context)
}
