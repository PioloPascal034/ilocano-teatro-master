import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingProperties = Properties()
val signingPropertiesFile = rootProject.file("key.properties")
if (signingPropertiesFile.isFile) {
    FileInputStream(signingPropertiesFile).use(signingProperties::load)
}

fun signingValue(propertyName: String, environmentName: String): String? =
    signingProperties.getProperty(propertyName)?.trim()?.takeIf { it.isNotEmpty() }
        ?: providers.environmentVariable(environmentName).orNull?.trim()?.takeIf { it.isNotEmpty() }

val releaseStoreFile = signingValue("storeFile", "ANDROID_KEYSTORE_FILE")
val releaseStorePassword = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
val releaseKeystoreFile = releaseStoreFile?.let { rootProject.file(it) }
val missingSigningValues = buildList {
    if (releaseStoreFile == null) add("storeFile/ANDROID_KEYSTORE_FILE")
    if (releaseStorePassword == null) add("storePassword/ANDROID_KEYSTORE_PASSWORD")
    if (releaseKeyAlias == null) add("keyAlias/ANDROID_KEY_ALIAS")
    if (releaseKeyPassword == null) add("keyPassword/ANDROID_KEY_PASSWORD")
    if (releaseKeystoreFile != null && !releaseKeystoreFile.isFile) {
        add("an existing keystore at ${releaseKeystoreFile.absolutePath}")
    }
}
val releaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}

if (releaseTaskRequested && missingSigningValues.isNotEmpty()) {
    throw GradleException(
        "Release signing is not configured. Provide ${missingSigningValues.joinToString()} " +
            "in android/key.properties or environment variables before building a release."
    )
}

android {
    namespace = "com.mrbisacstudios.ilocanoteatromaster"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mrbisacstudios.ilocanoteatromaster"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (missingSigningValues.isEmpty()) {
                storeFile = releaseKeystoreFile!!
                storePassword = releaseStorePassword!!
                keyAlias = releaseKeyAlias!!
                keyPassword = releaseKeyPassword!!
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
