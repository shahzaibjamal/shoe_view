import java.util.Properties // FIX: Import Properties class for file loading

// --- Locate and load key.properties from the 'android' folder ---
val localProperties = Properties()
val localPropertiesFile = project.file("../key.properties") // Looks in android/key.properties

if (localPropertiesFile.exists()) {
    // Load the key.properties file if it exists
    localPropertiesFile.inputStream().use { localProperties.load(it) }
} else {
    // CRITICAL: Log a warning if the file is not found.
    logger.warn("WARNING: key.properties not found at: ${localPropertiesFile.absolutePath}")
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.shoe.view"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.shoe.view"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // --- RELEASE SIGNING CONFIGURATION ---
    signingConfigs {
        create("release") {
            // Check if properties were loaded before trying to get values
            val storeFileProperty = localProperties.getProperty("storeFile")
            if (storeFileProperty != null && storeFileProperty.isNotEmpty()) {
                // Since the key.properties file specifies 'app/...' (relative to android/), 
                // using project.file() correctly resolves the path to android/app/kickhive_keystore.jks
                storeFile = project.file(storeFileProperty) 
                storePassword = localProperties.getProperty("storePassword")
                keyAlias = localProperties.getProperty("keyAlias")
                keyPassword = localProperties.getProperty("keyPassword")
            } else {
                logger.error("ERROR: storeFile property missing or empty in key.properties.")
            }
        }
    }

    buildTypes {
        release {
            // Ensure release code is signed with your private key
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            
            // *** FIX for "failed to strip debug symbols from native libraries" error ***
            isJniDebuggable = false 
        }
    }
}

flutter {
    source = "../.."
}
// This line is needed if you are using Google services (like Firebase) in your app
apply(plugin = "com.google.gms.google-services")
