# Build Scripts Reference

This document provides a quick reference for all build scripts in the project.

## 📋 Available Build Scripts

### 1. **build-native-dll.ps1** (Windows PowerShell)
**Purpose:** Build Windows Native DLL with full Bluetooth functionality

**Requirements:**
- Windows 10/11
- JDK 11+
- MinGW-w64 (auto-installed by Kotlin/Native)
- Windows SDK headers

**Usage:**
```powershell
.\build-native-dll.ps1
```

**Output:**
- `nioxplugin\build\outputs\windows\NioxCommunicationPlugin.dll`

**Features:**
- ✅ Step-by-step build progress
- ✅ C interop binding generation
- ✅ Kotlin/Native compilation
- ✅ Native DLL linking
- ✅ Automatic verification
- ✅ Detailed output information

**What it builds:**
- Native Windows DLL (no JVM required)
- Full Bluetooth functionality via C interop
- ~500KB-1MB size

---

### 2. **build-native-dll.sh** (Bash / WSL)
**Purpose:** Build Windows Native DLL (Unix-style script)

**Requirements:**
- Windows environment (Git Bash, WSL, or native)
- JDK 11+
- MinGW-w64 toolchain

**Usage:**
```bash
./build-native-dll.sh
```

**Output:**
- `nioxplugin/build/outputs/windows/NioxCommunicationPlugin.dll`

**Note:** This is primarily for reference. Native Windows build is preferred over WSL.

---

### 3. **build-all-windows.ps1** (Windows PowerShell)
**Purpose:** Build ALL Windows implementations in one command

**Requirements:**
- Windows 10/11
- JDK 11+
- MinGW-w64 (for Native DLL)

**Usage:**
```powershell
.\build-all-windows.ps1
```

**Output:**
- `nioxplugin\build\outputs\windows\NioxCommunicationPlugin.dll` (Native DLL)
- `nioxplugin\build\outputs\windows\niox-communication-plugin-windows-1.0.0.jar` (JAR)

**Features:**
- ✅ Builds both implementations
- ✅ Parallel build process
- ✅ Comprehensive build summary
- ✅ Success/failure tracking
- ✅ Usage recommendations
- ✅ Size comparisons

**What it builds:**
1. Native DLL (Kotlin/Native + C interop)
2. JAR (JVM + JNA)

---

### 4. **build-all.sh** (macOS / Linux)
**Purpose:** Build Android AAR and iOS XCFramework

**Requirements:**
- macOS (for iOS)
- JDK 11+
- Android SDK (for Android)
- Xcode 14.0+ (for iOS)

**Usage:**
```bash
./build-all.sh
```

**Output:**
- `nioxplugin/build/outputs/aar/nioxplugin-release.aar` (Android)
- `nioxplugin/build/XCFrameworks/release/NioxCommunicationPlugin.xcframework` (iOS)

**Note:** Windows builds are not included (requires Windows host)

---

### 5. **build-windows-full.ps1** (Windows PowerShell)
**Purpose:** Build Windows DLL via JAR + IKVM conversion

**Requirements:**
- Windows 10/11
- JDK 11+
- .NET SDK
- IKVM (auto-installed if needed)

**Usage:**
```powershell
.\build-windows-full.ps1
```

**Output:**
- `nioxplugin\build\outputs\windows\NioxPlugin.dll` (via IKVM)
- `nioxplugin\build\outputs\windows\niox-communication-plugin-windows-1.0.0.jar` (source JAR)

**What it builds:**
- Converts Java JAR to .NET DLL using IKVM
- For advanced .NET integration scenarios

**Note:** This is an alternative approach. For native apps, use `build-native-dll.ps1` instead.

---

## 🎯 Which Script Should I Use?

### For Windows Native Development (C#, C++, WinUI3):
```powershell
# Best choice - builds native DLL only
.\build-native-dll.ps1

# Or build everything
.\build-all-windows.ps1
```

### For JVM-Based Applications (Kotlin, Java):
```bash
# Build JAR only
.\gradlew :nioxplugin:buildWindowsJar
```

### For Mobile Development (Android + iOS):
```bash
# On macOS
./build-all.sh
```

### For Complete Project Build:
```powershell
# On Windows (all Windows implementations)
.\build-all-windows.ps1

# On macOS (Android + iOS)
./build-all.sh
```

---

## 📊 Build Script Comparison

| Script | Platform | Outputs | Time | Complexity |
|--------|----------|---------|------|------------|
| `build-native-dll.ps1` | Windows | Native DLL | ~30-60s | Medium |
| `build-all-windows.ps1` | Windows | DLL + JAR | ~60-90s | Medium |
| `build-all.sh` | macOS | AAR + XCF | ~2-3min | Medium |
| `build-windows-full.ps1` | Windows | IKVM DLL | ~2-3min | High |
| Direct Gradle | Any | Specific | ~30s | Low |

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

### Getting Help

1. Check the specific build guide:
   - Native DLL: [BUILD_AND_TEST_WINDOWS_NATIVE.md](BUILD_AND_TEST_WINDOWS_NATIVE.md)
   - Windows Full: [docs/WINDOWS_NATIVE_DLL_GUIDE.md](docs/WINDOWS_NATIVE_DLL_GUIDE.md)

2. Verify prerequisites are installed

3. Try direct Gradle commands first:
   ```bash
   .\gradlew :nioxplugin:tasks
   ```

---

## 🚀 Quick Start

### First Time Setup

1. **Clone the repository**
2. **Install prerequisites:**
   - JDK 11+
   - Windows SDK (for native DLL)
   - Android SDK (for Android builds)
   - Xcode (for iOS builds)

3. **Choose your target platform:**

   **For Windows Native Apps:**
   ```powershell
   .\build-native-dll.ps1
   ```

   **For Everything on Windows:**
   ```powershell
   .\build-all-windows.ps1
   ```

   **For Mobile (macOS):**
   ```bash
   ./build-all.sh
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

1. **First Build:** Always clean first
   ```bash
   .\gradlew clean
   ```

2. **Faster Builds:** Use Gradle daemon (auto-enabled)

3. **Parallel Builds:** `build-all-windows.ps1` builds sequentially for stability

4. **Verify Output:** Scripts include automatic verification steps

5. **Keep Tools Updated:**
   - Update Gradle: `.\gradlew wrapper --gradle-version=8.5`
   - Update JDK: Install latest JDK 11+ version

---

**Last Updated:** 2025-10-23
**Project Version:** 1.0.0
