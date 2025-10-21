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

    // Windows Native Target (builds a DLL via Kotlin/Native)
    mingwX64("windowsNative") {
        binaries {
            sharedLib {
                baseName = "NioxCommunicationPlugin"
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

// Task to copy native Windows DLL into outputs directory
tasks.register<Copy>("buildWindowsNativeDll") {
    // Build must run on Windows host; link task name for mingwX64 shared
    dependsOn("linkReleaseSharedWindowsNative")
    val dllName = "NioxCommunicationPlugin.dll"
    from(file("$buildDir/bin/windowsNative/releaseShared/$dllName"))
    into(file("$buildDir/outputs/windows"))
}
