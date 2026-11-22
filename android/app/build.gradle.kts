plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.feiyu.feiyu"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    androidResources {
        // sherpa_onnx ships a 14.5 MB web wasm; Android never loads it.
        ignoreAssetsPatterns += "*.wasm"
    }

    packaging {
        jniLibs {
            // ndk.abiFilters alone did not prune the AAR-provided .so files.
            excludes += setOf("lib/armeabi-v7a/**", "lib/x86_64/**")
        }
        resources {
            excludes += setOf("**/*.wasm")
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.feiyu.feiyu"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = (project.findProperty("versionCode") as String?)?.toInt() ?: flutter.versionCode
        versionName = (project.findProperty("versionName") as String?) ?: flutter.versionName
        // Ship only the ABI real phones use; armeabi-v7a + x86_64 add ~48 MB.
        ndk { abiFilters += listOf("arm64-v8a") }
    }

    // One fixed key for every build (local + CI). Otherwise each machine signs
    // with its own debug key and Android refuses to install the update.
    signingConfigs {
        create("feiyu") {
            val ks = file("../keystore/feiyu-release.jks")
            if (ks.exists()) {
                storeFile = ks
                storePassword = "feiyu2026"
                keyAlias = "feiyu"
                keyPassword = "feiyu2026"
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (file("../keystore/feiyu-release.jks").exists()) {
                signingConfigs.getByName("feiyu")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

// ignoreAssetsPatterns does not reach the flutter_assets tree, so drop the web
// wasm (14.5 MB raw) right before assets are merged. Android never loads it.
tasks.matching { it.name == "mergeReleaseAssets" }.configureEach {
    doFirst {
        delete(file("$buildDir/intermediates/flutter/release/flutter_assets/packages/sherpa_onnx_web"))
    }
}

