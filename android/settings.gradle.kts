pluginManagement {
    val flutterSdkPath =
        run {
            fun isFlutterSdk(dir: java.io.File): Boolean =
                java.io.File(dir, "packages/flutter_tools/gradle").isDirectory

            fun validSdk(path: String?): java.io.File? {
                if (path.isNullOrBlank()) return null
                val dir = java.io.File(path.trim())
                return if (isFlutterSdk(dir)) dir.canonicalFile else null
            }

            val localFile = file("local.properties")
            val properties = java.util.Properties()
            if (localFile.exists()) {
                localFile.inputStream().use { properties.load(it) }
            }

            var found: java.io.File? = validSdk(properties.getProperty("flutter.sdk"))
            if (found == null) found = validSdk(System.getenv("FLUTTER_ROOT"))
            if (found == null) found = validSdk(System.getenv("FLUTTER_SDK"))

            if (found == null) {
                val repo = localFile.parentFile.parentFile
                listOf(".fvm/flutter_sdk", ".flutter").forEach { rel ->
                    if (found == null) found = validSdk(java.io.File(repo, rel).absolutePath)
                }
            }

            if (found == null) {
                val names = listOf("flutter.bat", "flutter.cmd", "flutter")
                val path = System.getenv("PATH") ?: ""
                path.split(java.io.File.pathSeparator).forEach { dir ->
                    names.forEach { name ->
                        if (found == null) {
                            val bin = java.io.File(dir, name)
                            if (bin.isFile) {
                                found = validSdk(bin.parentFile?.parentFile?.absolutePath)
                            }
                        }
                    }
                }
            }

            if (found == null) {
                try {
                    val windows = System.getProperty("os.name").lowercase().contains("win")
                    val cmd =
                        if (windows) {
                            listOf("cmd.exe", "/c", "where", "flutter")
                        } else {
                            listOf("which", "flutter")
                        }
                    val proc = ProcessBuilder(cmd).redirectErrorStream(true).start()
                    val out = proc.inputStream.bufferedReader().readText()
                    proc.waitFor()
                    out.lineSequence().map { it.trim() }.filter { it.isNotEmpty() }.forEach { line ->
                        if (found == null) {
                            found = validSdk(java.io.File(line).parentFile?.parentFile?.absolutePath)
                        }
                    }
                } catch (_: Exception) {
                }
            }

            if (found == null) {
                val home = System.getProperty("user.home")
                val localApp = System.getenv("LOCALAPPDATA")
                val guesses = mutableListOf<java.io.File>()
                listOf(
                    "C:/flutter",
                    "C:/src/flutter",
                    "C:/tools/flutter",
                    "C:/dev/flutter",
                    "C:/Develop/flutter",
                    "C:/Develop/sdk/flutter",
                    "C:/Develop/tools/flutter",
                    "D:/flutter",
                    "D:/src/flutter",
                ).forEach { guesses += java.io.File(it) }
                if (!home.isNullOrBlank()) {
                    listOf(
                        "flutter",
                        "src/flutter",
                        "development/flutter",
                        "sdk/flutter",
                        "fvm/default",
                        "scoop/apps/flutter/current",
                    ).forEach { guesses += java.io.File(home, it) }
                }
                if (!localApp.isNullOrBlank()) {
                    guesses += java.io.File(localApp, "flutter")
                }
                java.io.File("C:/Develop").listFiles()?.forEach { child ->
                    if (child.isDirectory) {
                        guesses += child
                        child.listFiles()?.firstOrNull { it.isDirectory && it.name.equals("flutter", true) }?.let {
                            guesses += it
                        }
                    }
                }
                guesses.forEach { candidate ->
                    if (found == null) found = validSdk(candidate.absolutePath)
                }
            }

            val sdkPath: String =
                found?.absolutePath
                    ?: error(
                        """
                        Flutter SDK를 찾지 못했습니다. android/local.properties 에 flutter.sdk 가 없습니다.

                        저장소 루트에서 한 번 실행하세요:
                          flutter pub get

                        그래도 Android Studio가 android 폴더만 열면 다음 한 줄을
                        android/local.properties 에 넣으세요 (경로는 본인 PC 기준):
                          flutter.sdk=C:\\src\\flutter

                        Flutter 설치 경로를 모르면 터미널에서 where flutter 를 실행한 뒤,
                        나온 경로의 위 두 단계 폴더가 SDK 입니다.
                        예: C:\src\flutter\bin\flutter.bat  →  flutter.sdk=C:\\src\\flutter
                        """.trimIndent(),
                    )

            var dirty = false
            if (properties.getProperty("flutter.sdk").isNullOrBlank()) {
                properties.setProperty("flutter.sdk", sdkPath.replace('\\', '/'))
                dirty = true
            }

            fun androidSdkDir(): String? {
                val fromProp = properties.getProperty("sdk.dir")
                if (!fromProp.isNullOrBlank() && java.io.File(fromProp).isDirectory) return fromProp
                listOf("ANDROID_SDK_ROOT", "ANDROID_HOME").forEach { key ->
                    val v = System.getenv(key)
                    if (!v.isNullOrBlank() && java.io.File(v).isDirectory) return v
                }
                val localApp = System.getenv("LOCALAPPDATA")
                if (!localApp.isNullOrBlank()) {
                    val dir = java.io.File(localApp, "Android/Sdk")
                    if (dir.isDirectory) return dir.absolutePath
                }
                val home = System.getProperty("user.home")
                if (!home.isNullOrBlank()) {
                    listOf("AppData/Local/Android/Sdk", "Android/Sdk", "Library/Android/sdk").forEach { rel ->
                        val dir = java.io.File(home, rel)
                        if (dir.isDirectory) return dir.absolutePath
                    }
                }
                return null
            }

            val androidSdk = androidSdkDir()
            if (androidSdk != null && properties.getProperty("sdk.dir").isNullOrBlank()) {
                properties.setProperty("sdk.dir", androidSdk.replace('\\', '/'))
                dirty = true
            }
            if (dirty) {
                localFile.writer(java.nio.charset.StandardCharsets.ISO_8859_1).use { writer ->
                    properties.store(writer, "Generated so Android Studio can find Flutter / Android SDKs")
                }
            }
            sdkPath
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
