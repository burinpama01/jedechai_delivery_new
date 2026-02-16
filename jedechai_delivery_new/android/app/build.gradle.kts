plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.jedechai_delivery_new"
    compileSdk = 34
    ndkVersion = flutter.ndkVersion
	
	buildToolsVersion = "34.0.0"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.jedechai_delivery_new"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        multiDexEnabled = true
    }

    packaging {
        resources {
            pickFirsts += "META-INF/DEPENDENCIES"
            pickFirsts += "META-INF/LICENSE"
            pickFirsts += "META-INF/LICENSE.txt"
            pickFirsts += "META-INF/license.txt"
            pickFirsts += "META-INF/NOTICE"
            pickFirsts += "META-INF/NOTICE.txt"
            pickFirsts += "META-INF/notice.txt"
            pickFirsts += "META-INF/ASL2.0"
            pickFirsts += "META-INF/*.kotlin_module"
            pickFirsts += "**/kotlin-stdlib-common-*.jar"
            pickFirsts += "**/libc++_shared.so"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Workaround for VerifyException in mergeDebugJavaResource/mergeReleaseJavaResource
// This ensures files have valid MS-DOS timestamps (1980-2099) before merging
tasks.configureEach {
    if (name.contains("merge") && (name.contains("JavaResource") || name.contains("GlobalSynthetics") || name.contains("Resources"))) {
        doFirst {
            try {
                // Use a safe timestamp (January 1, 2000 00:00:00 UTC) to ensure MS-DOS compatibility
                val safeTimestamp = 946684800000L
                
                val buildDir = project.buildDir
                val mergeDirs = listOf(
                    buildDir.resolve("intermediates/merge_java_res"),
                    buildDir.resolve("intermediates/merged_java_res"),
                    buildDir.resolve("intermediates/incremental/mergeDebugJavaResource"),
                    buildDir.resolve("intermediates/incremental/mergeReleaseJavaResource"),
                    buildDir.resolve("intermediates/processed_res"),
                    buildDir.resolve("intermediates/merged_res"),
                    file("${rootProject.projectDir}/../build"),
                    file("${rootProject.projectDir}/build")
                )
                
                // Fix timestamps in all merge directories
                mergeDirs.forEach { baseDir ->
                    if (baseDir.exists()) {
                        try {
                            baseDir.walkTopDown().forEach { file ->
                                if (file.isFile) {
                                    try {
                                        file.setLastModified(safeTimestamp)
                                    } catch (e: Exception) {
                                        // Ignore individual file errors
                                    }
                                }
                            }
                        } catch (e: Exception) {
                            // Ignore directory errors
                        }
                    }
                }
                
                // Try to fix timestamps in dependency JARs/AARs
                try {
                    val dependencyJars = configurations
                        .filter { it.isCanBeResolved }
                        .flatMap { config ->
                            try {
                                config.resolvedConfiguration.resolvedArtifacts.mapNotNull { it.file }
                            } catch (e: Exception) {
                                emptyList()
                            }
                        }
                        .filter { it.extension == "jar" || it.extension == "aar" }
                        .distinct()
                    
                    dependencyJars.forEach { jarFile ->
                        try {
                            if (jarFile.exists()) {
                                jarFile.setLastModified(safeTimestamp)
                            }
                        } catch (e: Exception) {
                            // Ignore errors
                        }
                    }
                } catch (e: Exception) {
                    // Ignore if configurations are not resolved yet
                }
            } catch (e: Exception) {
                // Ignore all errors - let task continue
            }
        }
    }
}

// ✅ ส่วนที่เพิ่มมาเพื่อแก้ Error ล่าสุด
configurations.all {
    resolutionStrategy {
        // ของเดิมที่คุณใส่ไว้ (ถูกต้องแล้ว เก็บไว้ครับ)
        force("androidx.browser:browser:1.8.0")
        force("androidx.core:core:1.13.1")
        force("androidx.core:core-ktx:1.13.1")

        // 🚩 แก้ตรงนี้: เปลี่ยนเป็น 2.0.21 ให้หมดครับ
        force("org.jetbrains.kotlin:kotlin-stdlib:2.0.21")
        force("org.jetbrains.kotlin:kotlin-stdlib-jdk7:2.0.21")
        force("org.jetbrains.kotlin:kotlin-stdlib-jdk8:2.0.21")
        force("org.jetbrains.kotlin:kotlin-stdlib-common:2.0.21")
    }
}