plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.monicard.super_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Play / sideload identity. Do not rename without a migration plan.
        applicationId = "dev.monicard.super_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
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

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

val repoRoot = rootProject.projectDir.parentFile
val localProperties = java.util.Properties()
rootProject.file("local.properties").takeIf { it.exists() }?.inputStream()?.use {
    localProperties.load(it)
}
val flutterSdkPath =
    localProperties.getProperty("flutter.sdk")
        ?: System.getenv("FLUTTER_ROOT")
        ?: System.getenv("FLUTTER_SDK")
val flutterCli =
    if (flutterSdkPath.isNullOrBlank()) {
        null
    } else if (System.getProperty("os.name").lowercase().contains("win")) {
        java.io.File(flutterSdkPath, "bin/flutter.bat")
    } else {
        java.io.File(flutterSdkPath, "bin/flutter")
    }

tasks.register<Exec>("ensureFlutterPubGet") {
    group = "flutter"
    description = "Runs flutter pub get when .dart_tool/package_config.json is missing"
    workingDir = repoRoot
    val cli = flutterCli
    require(cli != null && cli.isFile) {
        "flutter executable not found. Set flutter.sdk in android/local.properties, then sync."
    }
    commandLine(cli.absolutePath, "pub", "get")
    onlyIf {
        val packageConfig = java.io.File(repoRoot, ".dart_tool/package_config.json")
        val lock = java.io.File(repoRoot, "pubspec.lock")
        !packageConfig.exists() || (lock.exists() && packageConfig.lastModified() < lock.lastModified())
    }
}

afterEvaluate {
    tasks.matching { it.name.startsWith("compileFlutterBuild") }.configureEach {
        dependsOn("ensureFlutterPubGet")
    }
}

