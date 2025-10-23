package com.niox.nioxplugin.cli

import com.niox.nioxplugin.createNioxCommunicationPlugin
import kotlinx.coroutines.runBlocking
import kotlin.system.exitProcess

/**
 * Command-line interface for the NIOX Communication Plugin
 * Allows the JAR to be executed from C# via process execution
 */
fun main(args: Array<String>) {
    if (args.isEmpty()) {
        printUsage()
        exitProcess(1)
    }

    val command = args[0]
    val plugin = createNioxCommunicationPlugin()

    try {
        when (command) {
            "checkBluetooth" -> {
                val state = runBlocking { plugin.checkBluetoothState() }
                println(state.name)
            }

            "scanDevices" -> {
                val duration = if (args.size > 1) args[1].toLongOrNull() ?: 10000L else 10000L
                val devices = runBlocking { plugin.scanForDevices(duration, null) }

                // Output as JSON
                println("""{"devices":[""")
                devices.forEachIndexed { index, device ->
                    val comma = if (index < devices.size - 1) "," else ""
                    println("""
                        {
                            "name":"${device.name?.replace("\"", "\\\"")}",
                            "address":"${device.address}",
                            "isNioxDevice":${device.isNioxDevice()},
                            "serialNumber":"${device.getNioxSerialNumber()}"
                        }$comma
                    """.trimIndent())
                }
                println("]}")
            }

            else -> {
                System.err.println("Unknown command: $command")
                printUsage()
                exitProcess(1)
            }
        }
    } catch (e: Exception) {
        System.err.println("Error: ${e.message}")
        e.printStackTrace()
        exitProcess(1)
    }
}

private fun printUsage() {
    println("""
        NIOX Communication Plugin CLI

        Usage:
          java -jar niox-communication-plugin-windows-1.0.0.jar <command> [args]

        Commands:
          checkBluetooth           - Check Bluetooth adapter state
          scanDevices [duration]   - Scan for devices (duration in ms, default: 10000)

        Examples:
          java -jar niox-plugin.jar checkBluetooth
          java -jar niox-plugin.jar scanDevices 15000
    """.trimIndent())
}