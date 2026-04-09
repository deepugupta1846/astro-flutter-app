plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.astro.pulse"
    compileSdk = flutter.compileSdkVersion
    // Use an installed NDK under Android/sdk/ndk/<version>/ with a valid source.properties (avoids CXX1101).
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.astro.pulse"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Flutter CLI expects APKs under `<project>/build/app/outputs/flutter-apk/`, but the Gradle
// plugin writes to `android/app/build/outputs/flutter-apk/`. Copy after assemble so
// `flutter run` / `flutter build apk` can find the artifact.
afterEvaluate {
    fun copyFlutterApkForTool() {
        val src = layout.buildDirectory.dir("outputs/flutter-apk").get().asFile
        if (!src.exists()) return
        val dest = rootProject.rootDir.resolve("../build/app/outputs/flutter-apk")
        dest.mkdirs()
        copy { 
            from(src)
            into(dest)
        }
    }
    listOf("assembleDebug", "assembleProfile", "assembleRelease").forEach { name ->
        tasks.findByName(name)?.doLast { copyFlutterApkForTool() }
    }
}
