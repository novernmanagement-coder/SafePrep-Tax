import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing config, read from key.properties (gitignored — never committed).
// See android/key.properties.example for the expected format.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasKeystoreProperties = keystorePropertiesFile.exists()
if (hasKeystoreProperties) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.geraldmiller.safepreptax"
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
        applicationId = "com.geraldmiller.safepreptax"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Two product flavors sharing this one module/repo, per the "one repo,
    // build flavors" direction for spinning off the interview-prep app
    // without a second codebase. Each flavor gets its own applicationId
    // (so both can be installed side by side on the same device/Play
    // account) and its own app_name resource (referenced from
    // AndroidManifest.xml as @string/app_name instead of a hardcoded
    // label). The flavor only controls the Android identity/branding —
    // which Dart entry point actually runs is still selected separately
    // via `flutter run/build --flavor <name> -t lib/<entry>.dart`.
    //
    // Neither flavor has its own launcher icon yet (no interview-specific
    // artwork exists) — both currently fall back to the shared
    // src/main/res mipmap/ic_launcher, so they'll look identical in the
    // app drawer until real icon assets are dropped into
    // src/interview/res/mipmap-*/ic_launcher.png.
    flavorDimensions += "app"

    productFlavors {
        create("taxStarter") {
            dimension = "app"
            // Matches today's un-flavored applicationId exactly, so this
            // flavor is a drop-in replacement for the current build --
            // same Play Store listing, same signing, same upgrade path
            // for existing installs.
            applicationId = "com.geraldmiller.safepreptax"
            resValue("string", "app_name", "Tax Starter")
        }
        create("interview") {
            dimension = "app"
            // Separate applicationId so this installs as its own app
            // next to Tax Starter rather than overwriting it. Rename
            // before shipping if a different bundle id gets decided on.
            applicationId = "com.geraldmiller.interviewace"
            resValue("string", "app_name", "How To Ace The Interview")
        }
    }

    signingConfigs {
        if (hasKeystoreProperties) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Uses the real release keystore once key.properties exists
            // (see android/key.properties.example). Falls back to debug
            // signing only so `flutter build`/`flutter run --release`
            // still work in an environment that hasn't set up the
            // release keystore yet — a Play Store upload always needs
            // the real signingConfigs.release, not this fallback.
            signingConfig = if (hasKeystoreProperties) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
