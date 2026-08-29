pluginManagement {
    val flutterSdkPath =
        run {
            val localFile = file("local.properties")
            val properties = java.util.Properties()
            if (localFile.exists()) {
                localFile.inputStream().use { properties.load(it) }
            }

            val resolved =
                (
                    properties.getProperty("flutter.sdk")
                        ?: System.getenv("FLUTTER_ROOT")
                        ?: System.getenv("FLUTTER_SDK")
                )?.trim()

            require(!resolved.isNullOrBlank()) {
                """
                flutter.sdk is not set in android/local.properties.

                This file is machine-local and is created by Flutter. Do not open the
                android/ folder as a standalone Gradle project.

                From the repository root (monicard-super-app) run:
                  flutter pub get

                Then open the Flutter project root in Android Studio / VS Code
                (Flutter plugin), not android/.

                Or set the FLUTTER_ROOT environment variable to your Flutter SDK path
                and sync Gradle again.
                """.trimIndent()
            }

            val sdk = resolved
            if (!localFile.exists() || properties.getProperty("flutter.sdk").isNullOrBlank()) {
                properties.setProperty("flutter.sdk", sdk)
                localFile.writer(Charsets.ISO_8859_1).use {
                    properties.store(it, "Generated so Android Studio can find the Flutter SDK")
                }
            }
            sdk
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

include(":app")
