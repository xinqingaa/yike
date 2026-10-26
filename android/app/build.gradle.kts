import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val previewBuild = System.getenv("YIKE_ANDROID_PREVIEW") == "true"
val keyProperties = Properties()
val keyPropertiesFile = file(System.getenv("YIKE_ANDROID_KEY_PROPERTIES") ?: "../key.properties")
if (keyPropertiesFile.isFile) {
    keyPropertiesFile.inputStream().use { keyProperties.load(it) }
}
fun signingValue(property: String, environment: String): String? =
    System.getenv(environment)?.takeIf { it.isNotBlank() }
        ?: keyProperties.getProperty(property)?.takeIf { it.isNotBlank() }

val releaseStoreFile = signingValue("storeFile", "YIKE_ANDROID_STORE_FILE")
val releaseStorePassword = signingValue("storePassword", "YIKE_ANDROID_STORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "YIKE_ANDROID_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "YIKE_ANDROID_KEY_PASSWORD")
val hasReleaseSigning = listOf(
    releaseStoreFile, releaseStorePassword, releaseKeyAlias, releaseKeyPassword,
).all { it != null }

android {
    namespace = "com.protobridge.yike"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.protobridge.yike"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning && !previewBuild) {
            create("release") {
                // Relative store paths are resolved from android/, as in key.properties.
                storeFile = rootProject.file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (previewBuild) signingConfigs.getByName("debug")
                else signingConfigs.findByName("release")
        }
    }
}

tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    doFirst {
        check(previewBuild || hasReleaseSigning) {
            "Release signing is missing. Configure android/key.properties or YIKE_ANDROID_*; " +
                "use node tool/build-android.mjs --preview for a debug-signed preview."
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
