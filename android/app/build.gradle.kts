import java.util.Properties
import java.io.FileInputStream


plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val releaseSigningProperties = listOf(
    "keyAlias",
    "keyPassword",
    "storeFile",
    "storePassword",
).associateWith { key ->
    keystoreProperties.getProperty(key)?.takeIf { it.isNotBlank() }
}.takeIf { properties ->
    properties.values.all { it != null }
}?.mapValues { (_, value) ->
    value.orEmpty()
}

android {
    namespace = "com.byteshark.aphidex"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.byteshark.aphidex"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        releaseSigningProperties?.let { properties ->
            create("release") {
                keyAlias = properties.getValue("keyAlias")
                keyPassword = properties.getValue("keyPassword")
                storeFile = file(properties.getValue("storeFile"))
                storePassword = properties.getValue("storePassword")
            }
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = releaseSigningProperties?.let {
                signingConfigs.getByName("release")
            } ?: signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}


flutter {
    source = "../.."
}
