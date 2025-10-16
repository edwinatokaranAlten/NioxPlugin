import org.jetbrains.kotlin.gradle.plugin.mpp.apple.XCFramework

plugins {
    kotlin("multiplatform")
    id("com.android.library")
}

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

    // iOS Targets
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

    // Windows Target (JVM-based for now, native Windows support is limited)
    jvm("windows") {
        compilations.all {
            kotlinOptions.jvmTarget = "11"
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

        val iosArm64Main by getting
        val iosMain by creating {
            dependsOn(commonMain)
            iosArm64Main.dependsOn(this)
        }

        val windowsMain by getting {
            dependencies {
                implementation("net.java.dev.jna:jna:5.13.0")
                implementation("net.java.dev.jna:jna-platform:5.13.0")
            }
        }
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

// Task to build Windows DLL (JAR-based library)
tasks.register<Jar>("buildWindowsDll") {
    dependsOn("windowsJar")
    archiveBaseName.set("niox-communication-plugin-windows")
    archiveExtension.set("jar")
    from(tasks.getByName<Jar>("windowsJar").archiveFile)
    destinationDirectory.set(file("$buildDir/outputs/windows"))
}
