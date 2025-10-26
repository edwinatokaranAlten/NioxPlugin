# Build Scripts Reference

This document provides a quick reference for all build scripts in the project.

## 📋 Individual Platform Build Scripts

Each platform has its own dedicated build script for granular control:

### 1. **build-native-dll.ps1** (Windows PowerShell)
**Purpose:** Build Windows Native DLL with full Bluetooth functionality

**Requirements:**
- Windows 10/11
- JDK 11+
- MinGW-w64 (auto-installed by Kotlin/Native)
- Windows SDK headers

**Usage:**
```powershell
# Normal build (uses cache for speed)
.\build-native-dll.ps1

# Clean build (force rebuild, cleans all caches)
.\build-native-dll.ps1 -Clean

# Get help
.\build-native-dll.ps1 -Help
```

**Output:**
- `nioxplugin\build\outputs\windows\NioxCommunicationPlugin.dll`

**Features:**
- ✅ Step-by-step build progress
- ✅ Source file verification
- ✅ C interop binding generation
- ✅ Kotlin/Native compilation
- ✅ Native DLL linking
- ✅ Automatic verification
- ✅ Detailed output information
- ✅ Smart cache management (normal vs clean mode)
- ✅ Build mode help system

**What it builds:**
- Native Windows DLL (no JVM required)
- Full Bluetooth functionality via C interop
- ~500KB-1MB size

**Build Modes:**
- **Normal Mode** (default): Uses Gradle cache, fast builds (~30-60s)
- **Clean Mode** (`-Clean` flag): Deep cleans all caches, fresh build (~60-90s), use when encountering cache issues

---

### 2. **build-windows-jar.ps1** (Windows PowerShell)
**Purpose:** Build Windows JAR (JVM implementation)

**Requirements:**
- Windows 10/11 (can also build on macOS/Linux)
- JDK 11+

**Usage:**
```powershell
.\build-windows-jar.ps1
```

**Output:**
- `nioxplugin\build\outputs\windows\niox-communication-plugin-windows-1.0.0.jar`

**Features:**
- ✅ Clean build process
- ✅ JVM + JNA implementation
- ✅ Automatic verification
- ✅ Usage recommendations
- ✅ Next steps guidance

**What it builds:**
- Windows JAR (requires JRE 11+)
- Full Bluetooth functionality via JNA
- ~2MB size

**Use for:**
- JVM-based applications (Kotlin, Java)
- Cross-platform JVM apps
- When JRE is bundled with your app

---

### 3. **build-android.sh** (Bash)
**Purpose:** Build Android AAR

**Requirements:**
- JDK 11+
- Android SDK with API level 34

**Usage:**
```bash
./build-android.sh
```

**Output:**
- `nioxplugin/build/outputs/aar/nioxplugin-release.aar`

**Features:**
- ✅ Clean build process
- ✅ Automatic verification
- ✅ Size reporting
- ✅ Integration instructions

**Use for:**
- Android applications
- Android libraries

---

### 4. **build-ios.sh** (Bash)
**Purpose:** Build iOS XCFramework

**Requirements:**
- macOS with Xcode 14.0+
- JDK 11+

**Usage:**
```bash
./build-ios.sh
```

**Output:**
- `nioxplugin/build/XCFrameworks/release/NioxCommunicationPlugin.xcframework`

**Features:**
- ✅ macOS platform check
- ✅ Clean build process
- ✅ Automatic verification
- ✅ Xcode integration instructions

**Use for:**
- iOS applications
- iOS frameworks

---

## 📋 Aggregate Build Scripts

These scripts call the individual platform scripts to build multiple targets:

### 5. **build-all-windows.ps1** (Windows PowerShell)
**Purpose:** Build ALL Windows implementations by calling individual scripts

**Requirements:**
- Windows 10/11
- JDK 11+
- MinGW-w64 (for Native DLL)

**Usage:**
```powershell
.\build-all-windows.ps1
```

**What it does:**
- Calls `build-native-dll.ps1` for Native DLL
- Calls `build-windows-jar.ps1` for JAR
- Provides comprehensive build summary
- Tracks success/failure of each

**Output:**
- `nioxplugin\build\outputs\windows\NioxCommunicationPlugin.dll` (Native DLL)
- `nioxplugin\build\outputs\windows\niox-communication-plugin-windows-1.0.0.jar` (JAR)

**Features:**
- ✅ Builds both Windows implementations
- ✅ Comprehensive build summary
- ✅ Success/failure tracking
- ✅ Usage recommendations
- ✅ Next steps guidance

---

### 6. **build-all.sh** (Bash)
**Purpose:** Build ALL mobile platforms by calling individual scripts

**Requirements:**
- macOS (for iOS builds)
- JDK 11+
- Android SDK
- Xcode 14.0+ (for iOS)

**Usage:**
```bash
./build-all.sh
```

**What it does:**
- Calls `build-android.sh` for Android AAR
- Calls `build-ios.sh` for iOS XCFramework (macOS only)
- Provides comprehensive build summary
- Tracks success/failure of each

**Output:**
- `nioxplugin/build/outputs/aar/nioxplugin-release.aar` (Android)
- `nioxplugin/build/XCFrameworks/release/NioxCommunicationPlugin.xcframework` (iOS)

**Note:** iOS build requires macOS. On other platforms, only Android will be built.

---

## 🎯 Which Script Should I Use?

### For Individual Platforms:

**Windows Native DLL:**
```powershell
.\build-native-dll.ps1           # Normal build
.\build-native-dll.ps1 -Clean    # Clean build
```

**Windows JAR:**
```powershell
.\build-windows-jar.ps1
```

**Android AAR:**
```bash
./build-android.sh
```

**iOS XCFramework:**
```bash
./build-ios.sh    # Requires macOS
```

### For Multiple Platforms:

**All Windows implementations:**
```powershell
.\build-all-windows.ps1    # Builds DLL + JAR
```

**All mobile platforms:**
```bash
./build-all.sh    # Builds Android + iOS (macOS only for iOS)
```

---

## 📊 Build Script Comparison

| Script | Platform | Output | Time | Type |
|--------|----------|--------|------|------|
| `build-native-dll.ps1` | Windows | Native DLL | ~30-60s | Individual |
| `build-windows-jar.ps1` | Windows | JAR | ~30-60s | Individual |
| `build-android.sh` | Any | AAR | ~1-2min | Individual |
| `build-ios.sh` | macOS | XCFramework | ~1-2min | Individual |
| `build-all-windows.ps1` | Windows | DLL + JAR | ~1-2min | Aggregate |
| `build-all.sh` | Any/macOS | AAR + XCF | ~2-4min | Aggregate |

---

## 🔧 Troubleshooting

### Common Issues

**Issue:** `gradlew not found`
**Solution:** Run from project root directory, or use `gradle` instead

**Issue:** `C interop failed`
**Solution:**
- Install Windows SDK
- Verify MinGW-w64 is installed
- Check `windowsBluetooth.def` configuration

**Issue:** `JDK not found`
**Solution:** Install JDK 11+ and ensure `java` is in PATH

**Issue:** `Build failed on WSL`
**Solution:** Use native Windows instead of WSL for best results

**Issue:** `Compilation errors don't match source code` or `Type mismatch errors after updating`
**Solution:** Use clean build to clear all caches:
```powershell
.\build-native-dll.ps1 -Clean
```

### Getting Help

1. Use built-in help:
   ```powershell
   .\build-native-dll.ps1 -Help
   ```

2. Check the specific build guide:
   - Native DLL: [BUILD_AND_TEST_WINDOWS_NATIVE.md](BUILD_AND_TEST_WINDOWS_NATIVE.md)
   - Windows DLL Guide: [docs/WINDOWS_NATIVE_DLL_GUIDE.md](docs/WINDOWS_NATIVE_DLL_GUIDE.md)

3. Verify prerequisites are installed

4. Try direct Gradle commands:
   ```bash
   .\gradlew :nioxplugin:tasks
   ```

---

## 🚀 Quick Start

### First Time Setup

1. **Clone the repository**

2. **Install prerequisites:**
   - JDK 11+
   - Windows SDK (for Windows native DLL)
   - Android SDK (for Android builds)
   - Xcode 14.0+ (for iOS builds on macOS)

3. **Choose your build script:**

   **Individual Platform Builds:**
   ```powershell
   .\build-native-dll.ps1      # Windows Native DLL
   .\build-windows-jar.ps1     # Windows JAR
   ./build-android.sh          # Android AAR
   ./build-ios.sh              # iOS XCFramework (macOS)
   ```

   **Multiple Platform Builds:**
   ```powershell
   .\build-all-windows.ps1     # All Windows (DLL + JAR)
   ./build-all.sh              # All Mobile (Android + iOS)
   ```

### Verify Build Success

After building, verify the outputs:

```powershell
# Check Native DLL
Get-Item nioxplugin\build\outputs\windows\NioxCommunicationPlugin.dll

# Check JAR
Get-Item nioxplugin\build\outputs\windows\niox-communication-plugin-windows-1.0.0.jar

# Check Android AAR
Get-Item nioxplugin\build\outputs\aar\nioxplugin-release.aar

# Check iOS XCFramework
Get-Item nioxplugin\build\XCFrameworks\release\NioxCommunicationPlugin.xcframework
```

---

## 📚 Related Documentation

- [README.md](README.md) - Main project documentation
- [BUILD_AND_TEST_WINDOWS_NATIVE.md](BUILD_AND_TEST_WINDOWS_NATIVE.md) - Native DLL testing
- [WINDOWS_NATIVE_DLL_GUIDE.md](docs/WINDOWS_NATIVE_DLL_GUIDE.md) - Complete DLL guide
- [WINDOWS_NATIVE_DLL_IMPLEMENTATION_SUMMARY.md](docs/WINDOWS_NATIVE_DLL_IMPLEMENTATION_SUMMARY.md) - Technical details
- [IMPLEMENTATION_CHANGES.md](IMPLEMENTATION_CHANGES.md) - What changed

---

## 💡 Tips

1. **First Build:** Use normal mode for initial builds
   ```bash
   .\build-native-dll.ps1
   ```

2. **Cache Issues:** Use `-Clean` flag to resolve compilation errors
   ```powershell
   .\build-native-dll.ps1 -Clean
   ```

3. **After Git Pull:** If build fails after pulling changes, use clean build
   ```powershell
   .\build-native-dll.ps1 -Clean
   ```

4. **Faster Builds:** Use Gradle daemon (auto-enabled) and normal mode

5. **Parallel Builds:** `build-all-windows.ps1` builds sequentially for stability

6. **Verify Output:** Scripts include automatic verification steps

7. **Keep Tools Updated:**
   - Update Gradle: `.\gradlew wrapper --gradle-version=8.5`
   - Update JDK: Install latest JDK 11+ version

---

**Last Updated:** 2025-10-23
**Project Version:** 1.0.0
