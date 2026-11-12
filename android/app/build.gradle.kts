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

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.feiyu.feiyu"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = (project.findProperty("versionCode") as String?)?.toInt() ?: flutter.versionCode
        versionName = (project.findProperty("versionName") as String?) ?: flutter.versionName
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
