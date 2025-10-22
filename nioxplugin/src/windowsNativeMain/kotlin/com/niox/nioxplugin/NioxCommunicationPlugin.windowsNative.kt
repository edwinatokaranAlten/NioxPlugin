package com.niox.nioxplugin

import kotlinx.coroutines.delay

/**
 * Windows Native (mingwX64) implementation stub.
 * Currently returns UNSUPPORTED state and no devices. Intended as a buildable DLL output.
 */
class WindowsNativeNioxCommunicationPlugin : NioxCommunicationPlugin {
    override suspend fun checkBluetoothState(): BluetoothState = BluetoothState.UNSUPPORTED

    override suspend fun scanForDevices(
        scanDurationMs: Long,
        serviceUuidFilter: String?
    ): List<BluetoothDevice> {
        // Stub: simulate scan duration and return no devices
        if (scanDurationMs > 0) delay(scanDurationMs)
        return emptyList()
    }

    override fun stopScan() {
        // No-op in stub
    }
}

actual fun createNioxCommunicationPlugin(): NioxCommunicationPlugin = WindowsNativeNioxCommunicationPlugin()

