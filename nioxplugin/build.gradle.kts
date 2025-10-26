import org.jetbrains.kotlin.gradle.plugin.mpp.apple.XCFramework

plugins {
    kotlin("multiplatform")
    id("com.android.library")
}

// Check if running on Windows
val isWindows = System.getProperty("os.name").lowercase().contains("windows")

kotlin {
    // Android Target
    androidTarget {
        compilations.all {
            kotlinOptions {
                jvmTarget = "1.8"
            }
        }
        publishLibraryVariants("release")
    }

    // iOS Targets (only on macOS, not on Windows)
    if (!isWindows) {
        val xcf = XCFramework("NioxCommunicationPlugin")
        listOf(
            iosArm64(),
        ).forEach {
            it.binaries.framework {
                baseName = "NioxCommunicationPlugin"
                xcf.add(this)
                isStatic = true
            }
        }
    }

    // Windows JVM Target removed - using WinRT implementation only

    // Windows WinRT Target (builds a JAR with WinRT for full BLE support)
    jvm("windowsWinRt") {
        compilations.all {
            kotlinOptions {
                jvmTarget = "11"
            }
        }
        attributes {
            attribute(Attribute.of("com.niox.bluetooth.type", String::class.java), "winrt")
        }
    }

    // Windows Native Target removed - using WinRT Native implementation only

    // Windows WinRT Native Target - BLE Support (builds a DLL with WinRT BLE APIs)
    mingwX64("windowsWinRtNative") {
        compilations.getByName("main") {
            cinterops {
                val winrtBle by creating {
                    defFile(project.file("src/nativeInterop/cinterop/winrtBle.def"))
                    packageName("platform.winrt.ble")

                    // Include path for C++ headers
                    includeDirs.headerFilterOnly(
                        project.file("src/nativeInterop/cpp")
                    )
                }
            }

            // Compile C++ WinRT wrapper
            val compileCpp by tasks.creating(Exec::class) {
                workingDir = project.file("src/nativeInterop/cpp")
                commandLine("cl.exe",
                    "/EHsc", "/std:c++17", "/MD",
                    "/I.",
                    "/c", "winrt_ble_wrapper.cpp",
                    "/Fo:winrt_ble_wrapper.obj")
            }

            // Make compilation depend on C++ compilation
            tasks.named("compileKotlinWindowsWinRtNative") {
                dependsOn(compileCpp)
            }
        }

        binaries {
            sharedLib {
                baseName = "NioxCommunicationPluginWinRT"
                // Link against WinRT libraries and the C++ object file
                linkerOpts(
                    "-L${project.file("src/nativeInterop/cpp")}",
                    "-lwindowsapp",
                    "-lole32",
                    "-loleaut32",
                    "-lruntimeobject"
                )
            }
        }

        // Export @CName functions
        compilations.getByName("main") {
            kotlinOptions {
                freeCompilerArgs += listOf(
                    "-Xexport-kdoc"
                )
            }
        }
    }

    sourceSets {
        val commonMain by getting {
            dependencies {
                implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
            }
        }

        val commonTest by getting {
            dependencies {
                implementation(kotlin("test"))
            }
        }

        val androidMain by getting {
            dependencies {
                implementation("androidx.core:core-ktx:1.12.0")
            }
        }

        // iOS source sets (only on macOS, not on Windows)
        if (!isWindows) {
            val iosArm64Main by getting
            val iosMain by creating {
                dependsOn(commonMain)
                iosArm64Main.dependsOn(this)
            }
        }

        // JVM Windows Classic source set removed - using WinRT only

        // WinRT Windows source set (with JNA for BLE support via WinRT)
        val windowsWinRtMain by getting {
            dependencies {
                implementation("net.java.dev.jna:jna:5.13.0")
                implementation("net.java.dev.jna:jna-platform:5.13.0")
            }
        }

        // Native Windows Classic source set removed - using WinRT Native only

        // WinRT Native Windows source set (BLE support)
        val windowsWinRtNativeMain by getting
    }
}

android {
    namespace = "com.niox.nioxplugin"
    compileSdk = 34

    defaultConfig {
        minSdk = 21
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }
}

// Task removed - Windows Classic JAR no longer built

// Task to build Windows WinRT JAR with BLE support
tasks.register<Jar>("buildWindowsWinRtJar") {
    dependsOn("windowsWinRtJar")
    archiveBaseName.set("niox-communication-plugin-windows-winrt")
    archiveVersion.set(version.toString())
    from(tasks.named("windowsWinRtJar"))

    // Copy to outputs directory
    doLast {
        val buildDir = layout.buildDirectory.get().asFile
        val outputDir = file("$buildDir/outputs/windows")
        outputDir.mkdirs()
        copy {
            from(archiveFile.get().asFile)
            into(outputDir)
        }
    }
}

// Task removed - Windows Classic Native DLL no longer built

// Task to copy WinRT native Windows DLL into outputs directory (BLE Support)
tasks.register<Copy>("buildWindowsWinRtNativeDll") {
    // Build must run on Windows host; link task name for mingwX64 shared
    dependsOn("linkReleaseSharedWindowsWinRtNative")
    val dllName = "NioxCommunicationPluginWinRT.dll"
    val buildDir = layout.buildDirectory.get().asFile
    from(file("$buildDir/bin/windowsWinRtNative/releaseShared/$dllName"))
    into(file("$buildDir/outputs/windows"))
}
