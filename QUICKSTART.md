# Quick Start Guide

## Build the Library

### Option 1: Build All Targets (Recommended)

```bash
./build-all.sh
```

This will generate:
- Android AAR: `nioxplugin/build/outputs/aar/nioxplugin-release.aar`
- iOS XCFramework: `nioxplugin/build/XCFrameworks/release/NioxCommunicationPlugin.xcframework`
- Windows JAR: `nioxplugin/build/outputs/windows/niox-communication-plugin-windows.jar`

### Option 2: Build Individual Targets

**Android AAR:**
```bash
./gradlew :nioxplugin:assembleRelease
```

**iOS XCFramework (macOS only):**
```bash
./gradlew :nioxplugin:assembleNioxCommunicationPluginXCFramework
```

**Windows JAR:**
```bash
./gradlew :nioxplugin:buildWindowsDll
```

## Integration

### Android Integration

1. Copy `nioxplugin-release.aar` to your Android project's `libs/` folder
2. Add to your app's `build.gradle`:
   ```gradle
   dependencies {
       implementation files('libs/nioxplugin-release.aar')
   }
   ```
3. Add permissions to `AndroidManifest.xml` (see README.md)
4. Use the plugin:
   ```kotlin
   val plugin = createNioxCommunicationPlugin(context)
   ```

### iOS Integration

1. Drag `NioxCommunicationPlugin.xcframework` into your Xcode project
2. In Target Settings → Frameworks → Set to "Embed & Sign"
3. Add Bluetooth permissions to `Info.plist` (see README.md)
4. Use the plugin:
   ```swift
   let plugin = NioxCommunicationPluginKt.createNioxCommunicationPlugin()
   ```

### Windows Integration

1. Add the JAR to your project's classpath
2. Use the plugin:
   ```kotlin
   val plugin = createNioxCommunicationPlugin()
   ```

## Basic Usage

```kotlin
// Check Bluetooth state
val state = plugin.checkBluetoothState()

// Scan for devices
plugin.startBluetoothScan(
    onDeviceFound = { device ->
        println("Found: ${device.name} - ${device.address}")
    },
    onScanComplete = {
        println("Scan complete")
    }
)

// Stop scanning
plugin.stopBluetoothScan()
```

## Next Steps

- See [README.md](README.md) for full API documentation
- See [USAGE_EXAMPLES.md](USAGE_EXAMPLES.md) for platform-specific examples
- Check `nioxplugin/src/commonMain/kotlin/` for the complete API

## Troubleshooting

### Build fails with "Android SDK not found"
Install Android SDK and set `ANDROID_HOME` environment variable.

### iOS build fails
Ensure you're on macOS with Xcode 14.0+ installed.

### Permissions errors on Android
Make sure you've added all required permissions and requested them at runtime (Android 6.0+).

## Support

For issues, refer to the main [README.md](README.md) or contact the Niox development team.
