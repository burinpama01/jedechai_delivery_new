// android/verify_exception_fix.gradle.kts
// [COMPREHENSIVE FIX] แก้ไข VerifyException ที่รากเหง้า

allprojects {
    // 1. Force ให้ใช้ Guava และ dependencies ที่เสถียร
    configurations.all {
        resolutionStrategy {
            force("com.google.guava:guava:31.1-android")
            force("com.google.guava:listenablefuture:9999.0-empty-to-avoid-conflict-with-guava")
            force("org.jetbrains.kotlin:kotlin-stdlib:1.9.24")
        }
        exclude(group = "com.google.guava", module = "listenablefuture")
    }

    // 2. แก้ไขปัญหา VerifyException โดยการ override task
    afterEvaluate {
        tasks.matching { 
            it.name.contains("merge", ignoreCase = true) && 
            it.name.contains("JavaResource", ignoreCase = true) 
        }.configureEach {
            // Force clean build ทุกครั้ง
            outputs.upToDateWhen { false }
            
            doFirst {
                println("🛡️ Comprehensive fix for ${name}")
                
                // แก้ไข timestamp ของทุกไฟล์ใน input
                val minTimestamp = 315532800000L // 1980-01-01
                val maxTimestamp = 4354819200000L // 2107-12-31
                val currentTimestamp = System.currentTimeMillis()
                
                inputs.files.filter { it.exists() }.forEach { rootFile ->
                    rootFile.walkTopDown().forEach { file ->
                        if (file.isFile) {
                            val current = file.lastModified()
                            if (current < minTimestamp || current > maxTimestamp) {
                                file.setLastModified(currentTimestamp)
                            }
                        }
                    }
                }
            }
        }
    }

    // 3. แก้ไข packaging options ให้ครอบคลุมทุกโมดูล
    afterEvaluate {
        val android = extensions.findByName("android")
        if (android != null) {
            val base = android as? com.android.build.gradle.BaseExtension
            base?.packagingOptions {
                resources {
                    excludes += listOf(
                        "META-INF/DEPENDENCIES",
                        "META-INF/LICENSE*",
                        "META-INF/NOTICE*",
                        "META-INF/*.kotlin_module",
                        "**/module-info.class",
                        "META-INF/versions/**",
                        "META-INF/INDEX.LIST",
                        "META-INF/com.google.guava/**",
                        "google/protobuf/**",
                        "META-INF/gradle/**",
                        "META-INF/gradle-wrapper/**",
                        "META-INF/gradle-plugins/**"
                    )
                    pickFirsts += "META-INF/services/**"
                    pickFirsts += "**/libc++_shared.so"
                    pickFirsts += "**/libcrypto.so"
                    pickFirsts += "**/libssl.so"
                }
            }
        }
    }
}
