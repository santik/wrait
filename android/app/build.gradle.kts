import java.io.File
import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use(localProperties::load)
}

fun localProperty(name: String): String? =
    localProperties.getProperty(name)?.trim()?.takeIf { it.isNotEmpty() }

fun environmentVariable(name: String): String? =
    System.getenv(name)?.trim()?.takeIf { it.isNotEmpty() }

val releaseKeystorePath = localProperty("KEYSTORE_PATH")
val releaseKeystoreFile =
    releaseKeystorePath?.let { configuredPath ->
        val candidate = File(configuredPath)
        if (candidate.isAbsolute) candidate else rootProject.file(configuredPath)
    }
val releaseKeystorePassword = environmentVariable("WRAIT_RELEASE_KEYSTORE_PASSWORD")
val releaseKeyAlias = localProperty("KEY_ALIAS")
val releaseKeyPassword = environmentVariable("WRAIT_RELEASE_KEY_PASSWORD")
val hasReleaseSigning =
    releaseKeystoreFile != null &&
        releaseKeystorePassword != null &&
        releaseKeyAlias != null &&
        releaseKeyPassword != null
val requiresReleaseSigning =
    gradle.startParameter.taskNames.any { taskName ->
        taskName.contains("release", ignoreCase = true)
    }

if (requiresReleaseSigning && !hasReleaseSigning) {
    throw GradleException(
        "Release signing is required for release builds. " +
            "Configure KEYSTORE_PATH and KEY_ALIAS in android/local.properties " +
            "and provide WRAIT_RELEASE_KEYSTORE_PASSWORD and " +
            "WRAIT_RELEASE_KEY_PASSWORD in the environment.",
    )
}

android {
    namespace = "com.wrait.flutter"
    // permission_handler_android 14 requires API 37 at compile time.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.wrait.flutter"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = releaseKeystoreFile
                storePassword = releaseKeystorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        getByName("debug") {
            applicationIdSuffix = ".dev"
        }

        getByName("profile") {
            applicationIdSuffix = ".dev"
        }

        getByName("release") {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
