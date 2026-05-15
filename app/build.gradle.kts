import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.hilt)
    alias(libs.plugins.ksp)
    alias(libs.plugins.openapi.generator)
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(localPropertiesFile.inputStream())
}
val privacyMode: String = localProperties.getProperty("PRIVACY_MODE", "MODE_BEST")
val backendUrl: String = localProperties.getProperty("BACKEND_URL", "https://wrait-backend.vercel.app")
val proxySecret: String = localProperties.getProperty("PROXY_SECRET", "")
val devRaw: String = localProperties.getProperty("DEV", "false").trim().lowercase()
val posthogApiKey: String = localProperties.getProperty("POSTHOG_API_KEY", "")
val posthogHost: String = localProperties.getProperty("POSTHOG_HOST", "https://us.i.posthog.com")
val posthogEnabledRaw: String = localProperties.getProperty("POSTHOG_ENABLED", "false").trim().lowercase()
require(devRaw == "true" || devRaw == "false") {
    "DEV in local.properties must be true or false, got: \"$devRaw\""
}
require(posthogEnabledRaw == "true" || posthogEnabledRaw == "false") {
    "POSTHOG_ENABLED in local.properties must be true or false, got: \"$posthogEnabledRaw\""
}
val keystorePath: String? = localProperties.getProperty("KEYSTORE_PATH")
val releaseKeystorePassword: String? = localProperties.getProperty("KEYSTORE_PASSWORD")
val releaseKeyAlias: String? = localProperties.getProperty("KEY_ALIAS")
val releaseKeyPassword: String? = localProperties.getProperty("KEY_PASSWORD")
val generatedOpenApiRoot = layout.buildDirectory.dir("generated/openapi/wrait-backend").get().asFile
val generatedOpenApiSourcesDir = generatedOpenApiRoot.resolve("src/main/kotlin")
val hasReleaseSigning: Boolean = !keystorePath.isNullOrBlank() &&
    !releaseKeystorePassword.isNullOrBlank() &&
    !releaseKeyAlias.isNullOrBlank() &&
    !releaseKeyPassword.isNullOrBlank()

android {
    namespace = "com.wrait.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.wrait.app"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "com.wrait.app.test.HiltTestRunner"

        buildConfigField("String", "PRIVACY_MODE", "\"$privacyMode\"")
        buildConfigField("String", "BACKEND_URL", "\"$backendUrl\"")
        buildConfigField("String", "PROXY_SECRET", "\"$proxySecret\"")
        buildConfigField("boolean", "DEV", devRaw)
        buildConfigField("String", "POSTHOG_API_KEY", "\"$posthogApiKey\"")
        buildConfigField("String", "POSTHOG_HOST", "\"$posthogHost\"")
        buildConfigField("boolean", "POSTHOG_ENABLED", posthogEnabledRaw)
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keystorePath!!)
                storePassword = releaseKeystorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        debug {
            // Separate package ID so the debug/test APK installs alongside the release app
            // without a signature conflict, and never touches the release app's data.
            applicationIdSuffix = ".debug"
        }
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    testOptions {
        unitTests {
            isReturnDefaultValues = true
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    sourceSets {
        getByName("main").kotlin.directories.add(generatedOpenApiSourcesDir.path)
    }
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    // Core
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.process)
    implementation(libs.androidx.activity.compose)

    // Compose
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.core)
    implementation(libs.androidx.compose.material.icons.extended)

    // Navigation
    implementation(libs.androidx.navigation.compose)
    implementation(libs.hilt.navigation.compose)

    // Hilt
    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)

    // Room
    implementation(libs.room.runtime)
    implementation(libs.room.ktx)
    ksp(libs.room.compiler)

    // SQLCipher
    implementation(libs.sqlcipher)
    implementation(libs.androidx.sqlite)

    implementation(libs.retrofit)
    implementation(libs.retrofit.converter.scalars)
    implementation(libs.retrofit.kotlinx.serialization.converter)
    implementation(libs.okhttp)
    implementation(libs.okhttp.logging.interceptor)
    implementation(libs.kotlinx.serialization.json)

    // Coroutines
    implementation(libs.kotlinx.coroutines.android)

    // DataStore
    implementation(libs.androidx.datastore.preferences)

    // Security
    implementation(libs.tink.android)
    implementation(libs.posthog.android)
    implementation(libs.androidx.biometric)

    // Testing
    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.mockwebserver)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.androidx.test.rules)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.kotlinx.coroutines.test)
    androidTestImplementation(libs.hilt.android.testing)
    androidTestImplementation(libs.room.testing)
    androidTestImplementation(libs.mockwebserver)
    kspAndroidTest(libs.hilt.compiler)
    debugImplementation(libs.androidx.compose.ui.tooling)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
    }
}

openApiValidate {
    inputSpec.set("$rootDir/openapi/wrait-backend.yaml")
}

openApiGenerate {
    generatorName.set("kotlin")
    inputSpec.set("$rootDir/openapi/wrait-backend.yaml")
    outputDir.set(generatedOpenApiRoot.absolutePath)
    packageName.set("com.wrait.app.data.api.generated")
    apiPackage.set("com.wrait.app.data.api.generated.api")
    modelPackage.set("com.wrait.app.data.api.generated.model")
    globalProperties.set(
        mapOf(
            "apiDocs" to "false",
            "apiTests" to "false",
            "modelDocs" to "false",
            "modelTests" to "false",
        )
    )
    configOptions.set(
        mapOf(
            "library" to "jvm-retrofit2",
            "serializationLibrary" to "kotlinx_serialization",
            "useCoroutines" to "true",
            "useResponseAsReturnType" to "true",
            "withSeparateModelsAndApi" to "true",
            "mapFileBinaryToByteArray" to "true",
            "sourceFolder" to "src/main/kotlin",
        )
    )
}

tasks.named("openApiGenerate") {
    dependsOn("openApiValidate")
}

tasks.named("preBuild") {
    dependsOn("openApiGenerate")
}

ksp {
    arg("room.schemaLocation", "$projectDir/schemas")
}
