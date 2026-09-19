runCatching {
    val pe = Class.forName("java.lang.ProcessEnvironment")
    val envField = pe.getDeclaredField("theCaseInsensitiveEnvironment").apply { isAccessible = true }
    (envField.get(null) as? MutableMap<String, String>)?.remove("ANDROID_PREFS_ROOT")
}
runCatching {
    val pe = Class.forName("java.lang.ProcessEnvironment")
    val envField = pe.getDeclaredField("theEnvironment").apply { isAccessible = true }
    (envField.get(null) as? MutableMap<String, String>)?.remove("ANDROID_PREFS_ROOT")
}
java.lang.System.clearProperty("ANDROID_PREFS_ROOT")

pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
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
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
