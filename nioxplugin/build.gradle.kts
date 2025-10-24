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

    // Windows JVM Target (builds a JAR with JNA for actual Bluetooth functionality)
    jvm("windows") {
        compilations.all {
            kotlinOptions {
                jvmTarget = "11"
            }
        }
    }

    // Windows Native Target (builds a DLL via Kotlin/Native with full Bluetooth functionality)
    mingwX64("windowsNative") {
        compilations.getByName("main") {
            cinterops {
                val windowsBluetooth by creating {
                    defFile(project.file("src/nativeInterop/cinterop/windowsBluetooth.def"))
                    packageName("platform.windows.bluetooth")
                }
            }
        }
        binaries {
            sharedLib {
                baseName = "NioxCommunicationPlugin"
                // Link against Windows Bluetooth libraries
                linkerOpts("-lBthprops", "-lKernel32")

                // Export symbols with C linkage (not mangled C++ names)
                export(project(":nioxplugin"))

                // Add compiler flags to ensure proper C exports
                freeCompilerArgs += listOf(
                    "-Xexport-kdoc",
                    "-linker-option", "--export-all-symbols"
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

        // JVM Windows source set (with JNA for Bluetooth)
        val windowsMain by getting {
            dependencies {
                implementation("net.java.dev.jna:jna:5.13.0")
                implementation("net.java.dev.jna:jna-platform:5.13.0")
            }
        }

        // Native Windows source set (no extra deps for stub)
        val windowsNativeMain by getting
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

// Task to build Windows JVM JAR with all dependencies
tasks.register<Jar>("buildWindowsJar") {
    dependsOn("windowsJar")
    archiveBaseName.set("niox-communication-plugin-windows")
    archiveVersion.set(version.toString())
    from(tasks.named("windowsJar"))

    // Add manifest with Main-Class for CLI usage
    manifest {
        attributes["Main-Class"] = "com.niox.nioxplugin.cli.MainKt"
    }

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

// Task to copy native Windows DLL into outputs directory (fully functional with Bluetooth)
tasks.register<Copy>("buildWindowsNativeDll") {
    // Build must run on Windows host; link task name for mingwX64 shared
    dependsOn("linkReleaseSharedWindowsNative")
    val dllName = "NioxCommunicationPlugin.dll"
    val buildDir = layout.buildDirectory.get().asFile
    from(file("$buildDir/bin/windowsNative/releaseShared/$dllName"))
    into(file("$buildDir/outputs/windows"))
}
