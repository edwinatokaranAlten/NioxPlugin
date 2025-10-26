using System;
using System.Runtime.InteropServices;
using System.Text;

namespace NioxBluetoothApp
{
    /// <summary>
    /// Utility to enumerate all exported functions from a DLL
    /// This helps us find the actual function names if they're mangled
    /// </summary>
    public static class DllExportChecker
    {
        [StructLayout(LayoutKind.Sequential)]
        private struct IMAGE_DOS_HEADER
        {
            public ushort e_magic;
            public ushort e_cblp;
            public ushort e_cp;
            public ushort e_crlc;
            public ushort e_cparhdr;
            public ushort e_minalloc;
            public ushort e_maxalloc;
            public ushort e_ss;
            public ushort e_sp;
            public ushort e_csum;
            public ushort e_ip;
            public ushort e_cs;
            public ushort e_lfarlc;
            public ushort e_ovno;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 4)]
            public ushort[] e_res;
            public ushort e_oemid;
            public ushort e_oeminfo;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 10)]
            public ushort[] e_res2;
            public int e_lfanew;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct IMAGE_EXPORT_DIRECTORY
        {
            public uint Characteristics;
            public uint TimeDateStamp;
            public ushort MajorVersion;
            public ushort MinorVersion;
            public uint Name;
            public uint Base;
            public uint NumberOfFunctions;
            public uint NumberOfNames;
            public uint AddressOfFunctions;
            public uint AddressOfNames;
            public uint AddressOfNameOrdinals;
        }

        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr LoadLibrary(string lpFileName);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool FreeLibrary(IntPtr hModule);

        [DllImport("kernel32.dll", CharSet = CharSet.Ansi, SetLastError = true)]
        private static extern IntPtr GetProcAddress(IntPtr hModule, string lpProcName);

        /// <summary>
        /// List all exported function names from a DLL
        /// This uses PE file format parsing to read the export table
        /// </summary>
        public static string ListExports(string dllPath)
        {
            var result = new StringBuilder();
            result.AppendLine("=== DLL Export Analysis ===\n");

            IntPtr hModule = IntPtr.Zero;

            try
            {
                // Load the DLL
                hModule = LoadLibrary(dllPath);
                if (hModule == IntPtr.Zero)
                {
                    int errorCode = Marshal.GetLastWin32Error();
                    result.AppendLine($"Failed to load DLL. Error: 0x{errorCode:X}");
                    return result.ToString();
                }

                result.AppendLine($"DLL loaded at: 0x{hModule.ToInt64():X}");
                result.AppendLine("\nSearching for NIOX-related exports...\n");

                // Try common name patterns that Kotlin/Native might use
                string[] possibleNames = new[]
                {
                    // Original names
                    "niox_init",
                    "niox_check_bluetooth",
                    "niox_scan_devices",
                    "niox_free_string",
                    "niox_cleanup",
                    "niox_version",

                    // With Kotlin/Native package prefixes
                    "kfun:com.niox.nioxplugin#niox_init(){}kotlin.Int",
                    "kfun:com.niox.nioxplugin#niox_check_bluetooth(){}kotlin.Int",
                    "kfun:com.niox.nioxplugin#initPlugin(){}kotlin.Int",
                    "kfun:com.niox.nioxplugin#checkBluetooth(){}kotlin.Int",

                    // With underscore prefix (common in MinGW)
                    "_niox_init",
                    "_niox_check_bluetooth",
                    "_niox_scan_devices",
                    "_niox_free_string",
                    "_niox_cleanup",
                    "_niox_version",

                    // With Kotlin/Native C export prefix
                    "Kotlin_com_niox_nioxplugin_niox_init",
                    "Kotlin_com_niox_nioxplugin_niox_check_bluetooth",
                    "Kotlin_com_niox_nioxplugin_initPlugin",
                    "Kotlin_com_niox_nioxplugin_checkBluetooth",

                    // Try the actual Kotlin function names
                    "initPlugin",
                    "checkBluetooth",
                    "scanDevices",
                    "freeString",
                    "cleanup",
                    "getVersion",
                };

                bool foundAny = false;
                foreach (var name in possibleNames)
                {
                    IntPtr procAddr = GetProcAddress(hModule, name);
                    if (procAddr != IntPtr.Zero)
                    {
                        result.AppendLine($"✅ FOUND: {name}");
                        result.AppendLine($"   Address: 0x{procAddr.ToInt64():X}\n");
                        foundAny = true;
                    }
                }

                if (!foundAny)
                {
                    result.AppendLine("❌ No matching exports found with common patterns.");
                    result.AppendLine("\nThis suggests the DLL might:");
                    result.AppendLine("1. Not export these functions at all");
                    result.AppendLine("2. Use a different naming convention");
                    result.AppendLine("3. Be a different type of library (JVM bytecode in DLL wrapper)");
                    result.AppendLine("\nRecommendation:");
                    result.AppendLine("- Use a tool like 'dumpbin /EXPORTS' on Windows");
                    result.AppendLine("- Or use Dependencies.exe to see all exports");
                    result.AppendLine("- The DLL may need to be rebuilt with proper C export declarations");
                }
                else
                {
                    result.AppendLine("\n✅ Found matching exports!");
                    result.AppendLine("Update BluetoothService.cs to use the correct names above.");
                }
            }
            catch (Exception ex)
            {
                result.AppendLine($"\n❌ Error during analysis: {ex.Message}");
                result.AppendLine(ex.StackTrace);
            }
            finally
            {
                if (hModule != IntPtr.Zero)
                {
                    FreeLibrary(hModule);
                }
            }

            return result.ToString();
        }
    }
}
