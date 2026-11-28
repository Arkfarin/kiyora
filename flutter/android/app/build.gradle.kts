import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load the private key and credentials from outside the checkout.
val signingPropertiesPath = providers.environmentVariable("KIYORA_ANDROID_SIGNING_PROPERTIES")
val signingPropertiesFile = file(signingPropertiesPath.orElse(
    "${System.getProperty("user.home")}/.local/share/kiyora/android-signing/keystore.properties"
).get())
check(!signingPropertiesPath.isPresent || signingPropertiesFile.isFile) {
    "KIYORA_ANDROID_SIGNING_PROPERTIES must point to an existing keystore.properties file"
}
val releaseSigningProperties = Properties().apply {
    if (signingPropertiesFile.isFile) {
        signingPropertiesFile.inputStream().use { load(it) }
    }
}
fun signingProperty(name: String): String =
    requireNotNull(releaseSigningProperties.getProperty(name)?.takeIf { it.isNotBlank() }) {
        "Missing Android release signing property: $name"
    }


val supportedNativeAbis = setOf("arm64-v8a", "x86_64")
val nativeAbis = providers.environmentVariable("KIYORA_ANDROID_ABIS").orElse("arm64-v8a").get().split(',')
require(nativeAbis.isNotEmpty() && nativeAbis.size == nativeAbis.toSet().size &&
    nativeAbis.all { it in supportedNativeAbis })

android {
    namespace = "io.github.arkfarin.kiyora"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.arkfarin.kiyora"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        ndk { abiFilters.addAll(nativeAbis) }
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signingPropertiesFile.isFile) {
            create("release") {
                storeFile = signingPropertiesFile.parentFile.resolve(signingProperty("storeFile"))
                storePassword = signingProperty("storePassword")
                keyAlias = signingProperty("keyAlias")
                keyPassword = signingProperty("keyPassword")
                storeType = releaseSigningProperties.getProperty("storeType", "PKCS12")
            }
        }
    }
    sourceSets.getByName("main") {
        jniLibs.srcDir(file("../../../rust/target/native/flutter-jni"))
        jniLibs.srcDir(file("../../../rust/target/native/android-jni"))
        assets.srcDir(file("../../../rust/target/native/android-assets"))
    }
    packaging.jniLibs.useLegacyPackaging = true
    // AGP merges all ABI folders from explicitly registered jniLibs source
    // directories even when ndk.abiFilters is set. Without this exclusion,
    // an ARM64-only APK can accidentally contain the x86_64 TDLib binary.
    packaging.jniLibs.excludes.addAll(
        (supportedNativeAbis - nativeAbis.toSet()).map { "**/$it/**" }
    )
    buildTypes {
        release {
            // Keep the existing application signing identity.
            // Without it the output is unsigned; never silently use a debug key.
            signingConfigs.findByName("release")?.let { signingConfig = it }
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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

val buildRustBackend = tasks.register<Exec>("buildRustBackend") {
    workingDir(file("../../.."))
    commandLine("python3", "flutter/tool/build_android_native.py", "--abis", nativeAbis.joinToString(","))
}
tasks.named("preBuild") { dependsOn(buildRustBackend) }
