import java.io.File
import java.util.Properties

fun File.isFlutterSdk(): Boolean = File(this, "packages/flutter_tools/gradle").isDirectory

fun validSdk(path: String?): File? {
    if (path.isNullOrBlank()) return null
    val f = File(path.trim())
    return if (f.isFlutterSdk()) f.canonicalFile else null
}

fun locateFlutterSdk(androidDir: File, props: Properties): String? {
    validSdk(props.getProperty("flutter.sdk"))?.let { return it.absolutePath }
    validSdk(System.getenv("FLUTTER_ROOT"))?.let { return it.absolutePath }
    validSdk(System.getenv("FLUTTER_SDK"))?.let { return it.absolutePath }

    val repo = androidDir.parentFile
    listOf(".fvm/flutter_sdk", ".fvm/flutter_sdk/bin/..", ".flutter").forEach { rel ->
        validSdk(File(repo, rel).absolutePath)?.let { return it.absolutePath }
    }

    val names = listOf("flutter.bat", "flutter.cmd", "flutter")
    (System.getenv("PATH") ?: "").split(File.pathSeparator).forEach { dir ->
        names.forEach { name ->
            val bin = File(dir, name)
            if (bin.isFile) {
                validSdk(bin.parentFile?.parentFile?.absolutePath)?.let { return it.absolutePath }
            }
        }
    }

    try {
        val windows = System.getProperty("os.name").lowercase().contains("win")
        val cmd = if (windows) listOf("cmd.exe", "/c", "where", "flutter") else listOf("which", "flutter")
        val proc = ProcessBuilder(cmd).redirectErrorStream(true).start()
        val out = proc.inputStream.bufferedReader().readText()
        proc.waitFor()
        out.lineSequence().map { it.trim() }.filter { it.isNotEmpty() }.forEach { line ->
            validSdk(File(line).parentFile?.parentFile?.absolutePath)?.let { return it.absolutePath }
        }
    } catch (_: Exception) {
        // PATH in the Gradle daemon is often empty on Windows.
    }

    val home = System.getProperty("user.home")
    val localApp = System.getenv("LOCALAPPDATA")
    val guesses = mutableListOf<File>()
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
    ).forEach { guesses += File(it) }
    if (!home.isNullOrBlank()) {
        listOf(
            "flutter",
            "src/flutter",
            "development/flutter",
            "sdk/flutter",
            "fvm/default",
            "scoop/apps/flutter/current",
        ).forEach { guesses += File(home, it) }
    }
    if (!localApp.isNullOrBlank()) {
        guesses += File(localApp, "flutter")
    }
    File("C:/Develop").listFiles()?.forEach { child ->
        if (child.isDirectory) {
            guesses += child
            child.listFiles()?.firstOrNull { it.isDirectory && it.name.equals("flutter", true) }?.let { guesses += it }
        }
    }

    guesses.forEach { validSdk(it.absolutePath)?.let { sdk -> return sdk.absolutePath } }
    return null
}

fun locateAndroidSdk(props: Properties): String? {
    val fromProp = props.getProperty("sdk.dir")
    if (!fromProp.isNullOrBlank() && File(fromProp).isDirectory) return fromProp
    listOf("ANDROID_SDK_ROOT", "ANDROID_HOME").forEach { key ->
        val v = System.getenv(key)
        if (!v.isNullOrBlank() && File(v).isDirectory) return v
    }
    val localApp = System.getenv("LOCALAPPDATA")
    if (!localApp.isNullOrBlank()) {
        val sdk = File(localApp, "Android/Sdk")
        if (sdk.isDirectory) return sdk.absolutePath
    }
    val home = System.getProperty("user.home")
    if (!home.isNullOrBlank()) {
        listOf("AppData/Local/Android/Sdk", "Android/Sdk", "Library/Android/sdk").forEach { rel ->
            val sdk = File(home, rel)
            if (sdk.isDirectory) return sdk.absolutePath
        }
    }
    return null
}

pluginManagement {
    val flutterSdkPath =
        run {
            val localFile = file("local.properties")
            val properties = Properties()
            if (localFile.exists()) {
                localFile.inputStream().use { properties.load(it) }
            }

            val sdk = locateFlutterSdk(localFile.parentFile, properties)
            require(!sdk.isNullOrBlank()) {
                """
                Flutter SDK를 찾지 못했습니다. android/local.properties 에 flutter.sdk 가 없습니다.

                저장소 루트에서 한 번 실행하세요:
                  flutter pub get

                그래도 Android Studio가 android 폴더만 열면 다음 한 줄을
                android/local.properties 에 넣으세요 (경로는 본인 PC 기준):
                  flutter.sdk=C:\\src\\flutter

                Flutter 설치 경로를 모르면 터미널에서 `where flutter` 를 실행한 뒤,
                나온 경로의 위 두 단계 폴더가 SDK 입니다.
                예: C:\src\flutter\bin\flutter.bat  →  flutter.sdk=C:\\src\\flutter
                """.trimIndent()
            }

            var dirty = false
            if (properties.getProperty("flutter.sdk").isNullOrBlank()) {
                properties.setProperty("flutter.sdk", sdk.replace("\\", "/"))
                dirty = true
            }
            val androidSdk = locateAndroidSdk(properties)
            if (androidSdk != null && properties.getProperty("sdk.dir").isNullOrBlank()) {
                properties.setProperty("sdk.dir", androidSdk.replace("\\", "/"))
                dirty = true
            }
            if (dirty) {
                localFile.writer(Charsets.ISO_8859_1).use {
                    properties.store(it, "Generated so Android Studio can find Flutter / Android SDKs")
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
