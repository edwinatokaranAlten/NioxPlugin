<#
.SYNOPSIS
    Build script for Windows WinRT Native DLL with full BLE support

.DESCRIPTION
    This script builds the NioxCommunicationPluginWinRT.dll which provides:
    - Full Bluetooth LE scanning with RSSI values
    - Windows 10/11 WinRT API integration
    - C API exports for P/Invoke from C#/C++
    - No JVM dependency

.PARAMETER Clean
    Perform a clean build by deleting all build artifacts first

.EXAMPLE
    .\build-winrt-native-dll.ps1
    Normal build (uses cache)

.EXAMPLE
    .\build-winrt-native-dll.ps1 -Clean
    Clean build (deletes all build artifacts first)
#>

param(
    [Parameter(Mandatory=$false)]
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

# Script configuration
$ProjectRoot = $PSScriptRoot
$CppSourceDir = Join-Path $ProjectRoot "nioxplugin\src\nativeInterop\cpp"
$BuildDir = Join-Path $ProjectRoot "nioxplugin\build"
$OutputDir = Join-Path $BuildDir "outputs\windows"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Windows WinRT Native DLL Builder" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running on Windows
if (-not $IsWindows -and -not ($env:OS -like "Windows*")) {
    Write-Host "❌ Error: This build script must run on Windows" -ForegroundColor Red
    Write-Host "   The WinRT Native DLL requires Windows 10/11 and Visual Studio" -ForegroundColor Yellow
    exit 1
}

# Find Visual Studio installation
Write-Host "[1/7] Checking for Visual Studio..." -ForegroundColor Yellow

$VsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $VsWhere)) {
    Write-Host "❌ Error: Visual Studio not found" -ForegroundColor Red
    Write-Host "   Please install Visual Studio 2019 or 2022 with C++ development tools" -ForegroundColor Yellow
    Write-Host "   Required components:" -ForegroundColor Yellow
    Write-Host "   - Desktop development with C++" -ForegroundColor Yellow
    Write-Host "   - C++/WinRT" -ForegroundColor Yellow
    exit 1
}

$VsPath = & $VsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $VsPath) {
    Write-Host "❌ Error: Visual Studio C++ tools not found" -ForegroundColor Red
    Write-Host "   Please install 'Desktop development with C++' workload" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Found Visual Studio at: $VsPath" -ForegroundColor Green

# Find vcvarsall.bat
$VcVarsAll = Join-Path $VsPath "VC\Auxiliary\Build\vcvarsall.bat"
if (-not (Test-Path $VcVarsAll)) {
    Write-Host "❌ Error: vcvarsall.bat not found" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Clean build if requested
if ($Clean) {
    Write-Host "[2/7] Performing clean build..." -ForegroundColor Yellow

    if (Test-Path $BuildDir) {
        Write-Host "  Deleting build directory..." -ForegroundColor Gray
        Remove-Item -Path $BuildDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Clean C++ object files
    $CppObjFiles = Get-ChildItem -Path $CppSourceDir -Filter "*.obj" -ErrorAction SilentlyContinue
    if ($CppObjFiles) {
        Write-Host "  Deleting C++ object files..." -ForegroundColor Gray
        $CppObjFiles | Remove-Item -Force
    }

    Write-Host "✓ Clean complete" -ForegroundColor Green
} else {
    Write-Host "[2/7] Using incremental build (use -Clean for full rebuild)" -ForegroundColor Yellow
}

Write-Host ""

# Compile C++ WinRT wrapper
Write-Host "[3/7] Compiling C++ WinRT wrapper..." -ForegroundColor Yellow

# Set up Visual Studio environment and compile
$CppSource = Join-Path $CppSourceDir "winrt_ble_wrapper.cpp"
$CppObj = Join-Path $CppSourceDir "winrt_ble_wrapper.obj"

if (-not (Test-Path $CppSource)) {
    Write-Host "❌ Error: C++ source file not found: $CppSource" -ForegroundColor Red
    exit 1
}

Write-Host "  Source: winrt_ble_wrapper.cpp" -ForegroundColor Gray
Write-Host "  Compiler: MSVC (Visual Studio)" -ForegroundColor Gray
Write-Host ""
Write-Host "  Compiling with C++/WinRT support..." -ForegroundColor Gray

# Create a temporary batch file to set up VS environment and compile
$TempBatchFile = [System.IO.Path]::GetTempFileName() + ".bat"
$BatchContent = @"
@echo off
call "$VcVarsAll" x64
cd /d "$CppSourceDir"
cl.exe /EHsc /std:c++17 /MD /await /W3 /c winrt_ble_wrapper.cpp /Fo:winrt_ble_wrapper.obj
exit /b %ERRORLEVEL%
"@

Set-Content -Path $TempBatchFile -Value $BatchContent

try {
    $result = & cmd.exe /c $TempBatchFile 2>&1
    $exitCode = $LASTEXITCODE

    # Show compilation output
    $result | ForEach-Object {
        if ($_ -match "error") {
            Write-Host "  $_" -ForegroundColor Red
        } elseif ($_ -match "warning") {
            Write-Host "  $_" -ForegroundColor Yellow
        }
    }

    if ($exitCode -ne 0) {
        Write-Host ""
        Write-Host "❌ C++ compilation failed with exit code: $exitCode" -ForegroundColor Red
        Write-Host ""
        Write-Host "Common issues:" -ForegroundColor Yellow
        Write-Host "  - Missing C++/WinRT: Install via Visual Studio Installer" -ForegroundColor Yellow
        Write-Host "  - Windows SDK not found: Install Windows 10/11 SDK" -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }

    if (-not (Test-Path $CppObj)) {
        Write-Host "❌ Error: Object file was not created" -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "✓ C++ compilation successful" -ForegroundColor Green
} finally {
    Remove-Item -Path $TempBatchFile -Force -ErrorAction SilentlyContinue
}

Write-Host ""

# Check for Gradle
Write-Host "[4/7] Checking build tools..." -ForegroundColor Yellow

$GradleCmd = $null
if (Test-Path ".\gradlew.bat") {
    $GradleCmd = ".\gradlew.bat"
    Write-Host "✓ Using Gradle wrapper" -ForegroundColor Green
} elseif (Get-Command gradle -ErrorAction SilentlyContinue) {
    $GradleCmd = "gradle"
    Write-Host "✓ Using system Gradle" -ForegroundColor Green
} else {
    Write-Host "❌ Error: Gradle not found" -ForegroundColor Red
    Write-Host "   Please install Gradle or use the Gradle wrapper" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Build Kotlin/Native DLL
Write-Host "[5/7] Building Kotlin/Native DLL..." -ForegroundColor Yellow
Write-Host "  This may take several minutes..." -ForegroundColor Gray
Write-Host ""

try {
    $gradleArgs = @(
        ":nioxplugin:linkReleaseSharedWindowsWinRtNative",
        "--info"
    )

    if ($Clean) {
        $gradleArgs = @("clean") + $gradleArgs
    }

    & $GradleCmd $gradleArgs

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "❌ Gradle build failed" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host ""
    Write-Host "❌ Build failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✓ Kotlin/Native DLL build complete" -ForegroundColor Green
Write-Host ""

# Copy DLL to output directory
Write-Host "[6/7] Copying DLL to output directory..." -ForegroundColor Yellow

$DllSource = Join-Path $BuildDir "bin\windowsWinRtNative\releaseShared\NioxCommunicationPluginWinRT.dll"

if (-not (Test-Path $DllSource)) {
    Write-Host "❌ Error: DLL not found at: $DllSource" -ForegroundColor Red
    Write-Host "   The build may have failed silently" -ForegroundColor Yellow
    exit 1
}

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
}

# Copy DLL
$DllDest = Join-Path $OutputDir "NioxCommunicationPluginWinRT.dll"
Copy-Item -Path $DllSource -Destination $DllDest -Force

Write-Host "✓ DLL copied to: $DllDest" -ForegroundColor Green
Write-Host ""

# Verify DLL exports
Write-Host "[7/7] Verifying DLL exports..." -ForegroundColor Yellow

try {
    # Use dumpbin to check exports (if available)
    $DumpBin = Get-Command dumpbin.exe -ErrorAction SilentlyContinue

    if ($DumpBin) {
        $exports = & dumpbin.exe /EXPORTS $DllDest 2>&1 | Select-String "niox_"

        if ($exports) {
            Write-Host "✓ Found exported functions:" -ForegroundColor Green
            $exports | ForEach-Object {
                Write-Host "  $_" -ForegroundColor Gray
            }
        } else {
            Write-Host "⚠️  Warning: No niox_ exports found" -ForegroundColor Yellow
            Write-Host "   The DLL may not have exported the C API functions" -ForegroundColor Yellow
        }
    } else {
        Write-Host "⚠️  dumpbin not available, skipping export verification" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  Could not verify exports: $_" -ForegroundColor Yellow
}

Write-Host ""

# Get file info
$DllInfo = Get-Item $DllDest
$DllSizeMB = [math]::Round($DllInfo.Length / 1MB, 2)

Write-Host "=========================================" -ForegroundColor Green
Write-Host "✅ BUILD SUCCESS" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "📦 Windows WinRT Native DLL Information:" -ForegroundColor Cyan
Write-Host "  Location: $DllDest" -ForegroundColor White
Write-Host "  Size: $DllSizeMB MB" -ForegroundColor White
Write-Host "  Type: Native DLL (No JVM required)" -ForegroundColor White
Write-Host "  Platform: Windows 10/11 (x64)" -ForegroundColor White
Write-Host ""
Write-Host "🎯 Features:" -ForegroundColor Cyan
Write-Host "  ✓ Full Bluetooth LE scanning" -ForegroundColor Green
Write-Host "  ✓ RSSI (signal strength) values" -ForegroundColor Green
Write-Host "  ✓ NIOX device filtering" -ForegroundColor Green
Write-Host "  ✓ C API exports for P/Invoke" -ForegroundColor Green
Write-Host "  ✓ No JVM dependency" -ForegroundColor Green
Write-Host ""
Write-Host "📝 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Copy DLL to your application directory" -ForegroundColor White
Write-Host "  2. Use P/Invoke from C# (see example below)" -ForegroundColor White
Write-Host "  3. Ensure your app targets Windows 10 build 1809+ or Windows 11" -ForegroundColor White
Write-Host ""
Write-Host "💡 C# Integration Example:" -ForegroundColor Cyan
Write-Host @"
  using System.Runtime.InteropServices;

  [DllImport("NioxCommunicationPluginWinRT.dll")]
  private static extern int niox_init();

  [DllImport("NioxCommunicationPluginWinRT.dll")]
  private static extern int niox_check_bluetooth();

  [DllImport("NioxCommunicationPluginWinRT.dll")]
  private static extern IntPtr niox_scan_devices(long durationMs, int nioxOnly);

  [DllImport("NioxCommunicationPluginWinRT.dll")]
  private static extern void niox_free_string(IntPtr ptr);

  [DllImport("NioxCommunicationPluginWinRT.dll")]
  private static extern void niox_cleanup();
"@ -ForegroundColor Gray
Write-Host ""
Write-Host "For more information, see:" -ForegroundColor Cyan
Write-Host "  - README.md (Usage examples)" -ForegroundColor White
Write-Host "  - example/Windows/ (Sample application)" -ForegroundColor White
Write-Host ""
