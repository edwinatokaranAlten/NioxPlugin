package com.niox.nioxplugin

/**
 * Represents the Bluetooth adapter state
 */
enum class BluetoothState {
    /** Bluetooth is enabled and ready to use */
    ENABLED,

    /** Bluetooth is disabled */
    DISABLED,

    /** Bluetooth is not supported on this device */
    UNSUPPORTED,

    /** Bluetooth state is unknown */
    UNKNOWN
}
