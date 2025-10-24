using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

namespace NioxBluetoothApp
{
    /// <summary>
    /// Diagnostic utility to help troubleshoot DLL loading issues
    /// </summary>
    public static class DllDiagnostics
    {
        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr LoadLibrary(string lpFileName);

        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern bool FreeLibrary(IntPtr hModule);

        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr GetProcAddress(IntPtr hModule, string lpProcName);

        /// <summary>
        /// Run comprehensive DLL diagnostics
        /// </summary>
        public static string RunDiagnostics(string dllName = "NioxCommunicationPlugin.dll")
        {
            var result = new StringBuilder();
            result.AppendLine("=== DLL Diagnostics Report ===\n");

            // 1. Check application directory
            string appDir = AppDomain.CurrentDomain.BaseDirectory;
            result.AppendLine($"Application Directory: {appDir}");

            // 2. Check if DLL exists
            string dllPath = Path.Combine(appDir, dllName);
            result.AppendLine($"DLL Path: {dllPath}");
            bool exists = File.Exists(dllPath);
            result.AppendLine($"DLL Exists: {exists}\n");

            if (!exists)
            {
                result.AppendLine("ERROR: DLL file not found!");
                result.AppendLine("Solution: Ensure the DLL is copied to the output directory.");
                return result.ToString();
            }

            // 3. Check DLL file info
            try
            {
                FileInfo fileInfo = new FileInfo(dllPath);
                result.AppendLine($"DLL Size: {fileInfo.Length:N0} bytes");
                result.AppendLine($"Last Modified: {fileInfo.LastWriteTime}\n");
            }
            catch (Exception ex)
            {
                result.AppendLine($"Could not read file info: {ex.Message}\n");
            }

            // 4. Try to load the DLL
            result.AppendLine("Attempting to load DLL...");
            IntPtr handle = LoadLibrary(dllPath);

            if (handle == IntPtr.Zero)
            {
                int errorCode = Marshal.GetLastWin32Error();
                result.AppendLine($"❌ LoadLibrary FAILED!");
                result.AppendLine($"Error Code: 0x{errorCode:X8} (decimal: {errorCode})");
                result.AppendLine($"\n{GetErrorCodeDescription(errorCode)}");
                return result.ToString();
            }

            result.AppendLine("✅ LoadLibrary SUCCESS!");
            result.AppendLine($"Handle: 0x{handle.ToInt64():X}\n");

            // 5. Check for exported functions
            result.AppendLine("Checking exported functions:");
            string[] expectedFunctions = new[]
            {
                "niox_init",
                "niox_check_bluetooth",
                "niox_scan_devices",
                "niox_free_string",
                "niox_cleanup",
                "niox_version"
            };

            foreach (var funcName in expectedFunctions)
            {
                IntPtr funcPtr = GetProcAddress(handle, funcName);
                if (funcPtr != IntPtr.Zero)
                {
                    result.AppendLine($"  ✅ {funcName} - Found (0x{funcPtr.ToInt64():X})");
                }
                else
                {
                    result.AppendLine($"  ❌ {funcName} - NOT FOUND");
                }
            }

            // 6. Try to call niox_version
            result.AppendLine("\nTesting niox_version() call:");
            try
            {
                IntPtr versionFunc = GetProcAddress(handle, "niox_version");
                if (versionFunc != IntPtr.Zero)
                {
                    // Create delegate for the function
                    var versionDelegate = Marshal.GetDelegateForFunctionPointer<GetVersionDelegate>(versionFunc);
                    IntPtr versionPtr = versionDelegate();

                    if (versionPtr != IntPtr.Zero)
                    {
                        string version = Marshal.PtrToStringAnsi(versionPtr);
                        result.AppendLine($"  ✅ Version: {version}");
                    }
                    else
                    {
                        result.AppendLine($"  ⚠️ Version function returned null");
                    }
                }
            }
            catch (Exception ex)
            {
                result.AppendLine($"  ⚠️ Could not test version: {ex.Message}");
            }

            // 7. Cleanup
            FreeLibrary(handle);
            result.AppendLine("\n✅ DLL unloaded successfully");

            result.AppendLine("\n=== Diagnostics Complete ===");
            result.AppendLine("The DLL appears to be working correctly!");

            return result.ToString();
        }

        private static string GetErrorCodeDescription(int errorCode)
        {
            return errorCode switch
            {
                126 => "ERROR_MOD_NOT_FOUND (0x7E)\n" +
                       "The specified module could not be found.\n" +
                       "Possible causes:\n" +
                       "  - Missing dependency DLLs (e.g., MinGW runtime DLLs)\n" +
                       "  - Missing Visual C++ Redistributable\n" +
                       "  - Missing Windows system DLLs\n" +
                       "Solution:\n" +
                       "  - Use Dependencies.exe to check for missing DLLs\n" +
                       "  - Install Visual C++ Redistributable\n" +
                       "  - Copy MinGW runtime DLLs to app directory",

                193 => "ERROR_BAD_EXE_FORMAT (0xC1)\n" +
                       "The application cannot run in Win32 mode.\n" +
                       "Possible causes:\n" +
                       "  - Architecture mismatch (x86 vs x64)\n" +
                       "  - Corrupted DLL file\n" +
                       "Solution:\n" +
                       "  - Ensure both app and DLL are x64\n" +
                       "  - Rebuild the DLL on Windows",

                2 => "ERROR_FILE_NOT_FOUND (0x2)\n" +
                     "The system cannot find the file specified.\n" +
                     "This shouldn't happen since we checked file existence.\n" +
                     "Check file permissions and antivirus.",

                _ => $"Unknown error code. See: https://learn.microsoft.com/en-us/windows/win32/debug/system-error-codes"
            };
        }

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate IntPtr GetVersionDelegate();
    }
}
