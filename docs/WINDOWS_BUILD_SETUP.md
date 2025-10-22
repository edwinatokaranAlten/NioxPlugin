# Windows Build Setup Guide

## Prerequisites

Before building the Niox Communication Plugin on Windows, you need to install and configure the following:

### 1. Java Development Kit (JDK)

**Required:** JDK 11 or higher (JDK 17 or 21 recommended)

**Download:** https://adoptium.net/

**Verify installation:**
```powershell
java -version
```

### 2. Android SDK

**Required for building Android AAR**

#### Option A: Android Studio (Recommended)
1. Download and install [Android Studio](https://developer.android.com/studio)
2. Open Android Studio
3. Go to **Tools** → **SDK Manager**
4. Install:
   - Android SDK Platform 34 (API Level 34)
   - Android SDK Build-Tools 34.0.0 or higher
   - Android SDK Platform-Tools
   - Android SDK Tools

#### Option B: Command Line Tools Only
1. Download [Android Command Line Tools](https://developer.android.com/studio#command-line-tools-only)
2. Extract to `C:\Android\cmdline-tools`
3. Install required packages:
```powershell
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
```

### 3. Configure Android SDK Path

Create a file named `local.properties` in the project root directory:

```properties
sdk.dir=C\:\\Users\\YourUsername\\AppData\\Local\\Android\\Sdk
```

**Common SDK Locations:**
- Android Studio: `C:\Users\{YourUsername}\AppData\Local\Android\Sdk`
- Manual Installation: `C:\Android\Sdk`

**To find your SDK path in Android Studio:**
1. Open Android Studio
2. Go to **File** → **Project Structure** → **SDK Location**
3. Copy the **Android SDK location** path

### 4. Windows SDK (For Windows DLL Build)

**Required for building Windows Native DLL**

1. Download and install [Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022)
2. During installation, select:
   - **Desktop development with C++**
   - **Windows 10 SDK** or **Windows 11 SDK**

## Building the Project

Once everything is set up, you can build the project:

```powershell
.\build-all.ps1
```

This will build:
- ✅ **Android AAR** → `nioxplugin/build/outputs/aar/nioxplugin-release.aar`
- ✅ **Windows DLL** → `nioxplugin/build/outputs/windows/NioxCommunicationPlugin.dll`

## Troubleshooting

### Error: "SDK location not found"

**Problem:** `local.properties` file is missing or has incorrect path

**Solution:**
1. Copy `local.properties.template` to `local.properties`
2. Update the `sdk.dir` path to your Android SDK location
3. Use double backslashes (`\\`) or forward slashes (`/`) in the path

**Example:**
```properties
# Correct (double backslashes)
sdk.dir=C\:\\Users\\John\\AppData\\Local\\Android\\Sdk

# Also correct (forward slashes)
sdk.dir=C:/Users/John/AppData/Local/Android/Sdk
```

### Error: "compileSdkVersion 34 not found"

**Problem:** Android SDK Platform 34 is not installed

**Solution:**
1. Open Android Studio
2. Go to **Tools** → **SDK Manager**
3. Check **Android 14.0 (API 34)**
4. Click **Apply** to install

### Error: "Build failed with exit code 25"

**Problem:** This usually indicates a Gradle configuration issue

**Solution:**
1. Make sure `local.properties` exists and has the correct SDK path
2. Run with more details:
```powershell
.\gradlew.bat clean --stacktrace
```
3. Check the full error message for more details

### Java Version Warnings

If you see warnings about restricted methods in Java, you can suppress them by adding this to `gradle.properties`:

```properties
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8 --add-opens=java.base/java.lang=ALL-UNNAMED
```

## Building Individual Targets

### Build only Android AAR:
```powershell
.\gradlew.bat :nioxplugin:assembleRelease
```

### Build only Windows DLL:
```powershell
.\gradlew.bat :nioxplugin:buildWindowsNativeDll
```

### Clean build:
```powershell
.\gradlew.bat clean
```

## Next Steps

After building successfully:

1. **Android AAR:** Import the AAR file into your Android project
2. **Windows DLL:** Use the DLL in your Windows desktop application

See [README.md](README.md) for usage instructions.
