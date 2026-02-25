import org.gradle.api.GradleException
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

val requiredSigningKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val hasReleaseKeystoreConfig = requiredSigningKeys.all {
    !keystoreProperties.getProperty(it).isNullOrBlank()
}

val isReleaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}

val isAndroidBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("assemble", ignoreCase = true) ||
        it.contains("bundle", ignoreCase = true) ||
        it.contains("install", ignoreCase = true)
}

fun firstNonBlank(vararg values: String?): String {
    return values
        .asSequence()
        .mapNotNull { value ->
            value
                ?.trim()
                ?.trim('"', '\'')
                ?.takeIf { it.isNotBlank() }
        }
        .firstOrNull()
        ?: ""
}

val envProperties = Properties()
val envFile = rootProject.file("../.env")
if (envFile.exists()) {
    FileInputStream(envFile).use { envProperties.load(it) }
}

val mapsApiKey =
    firstNonBlank(
        project.findProperty("GOOGLE_MAPS_API_KEY") as String?,
        System.getenv("GOOGLE_MAPS_API_KEY"),
        envProperties.getProperty("GOOGLE_MAPS_API_KEY"),
    )


if (isReleaseBuildRequested && !hasReleaseKeystoreConfig) {
    throw GradleException(
        "Missing android/key.properties for release signing. " +
            "Copy android/key.properties.example and fill real keystore values before building release.",
    )
}

if (isAndroidBuildRequested && mapsApiKey.isBlank()) {
    throw GradleException(
        "Missing GOOGLE_MAPS_API_KEY for Android build. " +
            "Provide it via Gradle property or environment variable.",
    )
}

android {
    namespace = "com.jedechai.delivery"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystoreConfig) {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    defaultConfig {
        applicationId = "com.jedechai.delivery"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = mapsApiKey
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
        debug {
            isDebuggable = true
            isShrinkResources = false
        }
    }

    // Simplified packaging configuration
    packaging {
        resources {
            // Exclude problematic duplicate files
            excludes += "META-INF/DEPENDENCIES"
            excludes += "META-INF/LICENSE"
            excludes += "META-INF/LICENSE.txt"
            excludes += "META-INF/NOTICE"
            excludes += "META-INF/NOTICE.txt"
            excludes += "META-INF/gradle/**"
            excludes += "META-INF/gradle-wrapper/**"
            excludes += "META-INF/gradle-plugins/**"
            excludes += "META-INF/INDEX.LIST"
            excludes += "META-INF/io.netty.versions.properties"
            excludes += "**/module-info.class"
            excludes += "META-INF/versions/**"
            excludes += "META-INF/proguard/**"
            excludes += "META-INF/maven/**"
            excludes += "META-INF/error_prone/**"
            excludes += "google/protobuf/**"
            excludes += "META-INF/com.google.guava/**"
            excludes += "META-INF/*.kotlin_module"
            excludes += "**/*.kotlin_builtins"
            excludes += "**/*.kotlin_metadata"
            excludes += "META-INF/AL2.0"
            excludes += "META-INF/LGPL2.1"
            
            // Keep essential files
            pickFirsts += "META-INF/services/**"
            pickFirsts += "**/libc++_shared.so"
            pickFirsts += "**/libcrypto.so"
            pickFirsts += "**/libssl.so"
        }
    }
}

flutter {
    source = "../.."
}

// Force-replace Google Maps API key in merged manifests AFTER google-services plugin
// The google-services plugin overrides com.google.android.geo.API_KEY with a wrong key
afterEvaluate {
    android.applicationVariants.all {
        val variantName = name.replaceFirstChar { it.uppercase() }
        
        // Hook into processManifest task (runs after google-services)
        tasks.findByName("process${variantName}Manifest")?.doLast {
            val manifestDir = layout.buildDirectory.dir(
                "intermediates/merged_manifests/$name/process${variantName}Manifest"
            ).get().asFile
            
            manifestDir.listFiles()?.filter { it.name == "AndroidManifest.xml" }?.forEach { manifest ->
                val content = manifest.readText()
                val fixed = content.replace(
                    Regex("""(android:name="com\.google\.android\.geo\.API_KEY"\s+android:value=")([^"]+)(")"""),
                    "\${1}${mapsApiKey}\${3}"
                )
                if (content != fixed) {
                    manifest.writeText(fixed)
                    println(">>> [FIX] Replaced Maps API key in ${manifest.path}")
                }
            }
        }

        // Also fix packaged manifests
        tasks.findByName("process${variantName}ManifestForPackage")?.doLast {
            val manifestDir = layout.buildDirectory.dir(
                "intermediates/packaged_manifests/$name/process${variantName}ManifestForPackage"
            ).get().asFile
            
            manifestDir.listFiles()?.filter { it.name == "AndroidManifest.xml" }?.forEach { manifest ->
                val content = manifest.readText()
                val fixed = content.replace(
                    Regex("""(android:name="com\.google\.android\.geo\.API_KEY"\s+android:value=")([^"]+)(")"""),
                    "\${1}${mapsApiKey}\${3}"
                )
                if (content != fixed) {
                    manifest.writeText(fixed)
                    println(">>> [FIX] Replaced Maps API key in ${manifest.path}")
                }
            }
        }
    }
}

dependencies {
    // Core dependencies
    implementation("com.google.guava:listenablefuture:1.0")
    
    // แก้ไขปัญหา NoClassDefFoundError: AbstractResolvableFuture
    implementation("androidx.concurrent:concurrent-futures:1.2.0")
    implementation("com.google.guava:guava:32.1.2-android")
    
    // Google Maps Play Services
    implementation("com.google.android.gms:play-services-maps:18.2.0")
    
    // Core library desugaring for flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
