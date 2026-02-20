// android/fix_verify_error.gradle.kts
// [NUCLEAR FIX] แก้ไข VerifyException โดยการกวาดล้าง Metadata ทั่วทั้งระบบ

allprojects {
    // 1. จัดการ Resolution Strategy ให้ตรงกันทุุกโมดูล
    configurations.all {
        resolutionStrategy {
            force("com.google.guava:guava:31.1-android")
            force("com.google.guava:listenablefuture:9999.0-empty-to-avoid-conflict-with-guava")
            force("org.jetbrains.kotlin:kotlin-stdlib:1.9.24")
        }
        exclude(group = "com.google.guava", module = "listenablefuture")
    }

    // 2. ตั้งกฎการ Packaging ให้กับทุุกโมดูล (แอปและ Plugins)
    afterEvaluate {
        val android = extensions.findByName("android")
        if (android != null) {
            val base = android as? com.android.build.gradle.BaseExtension
            base?.packagingOptions {
                resources {
                    // กำจัดทุกอย่างที่ทำให้ Merger สำลัก
                    excludes += listOf(
                        "META-INF/DEPENDENCIES",
                        "META-INF/LICENSE*",
                        "META-INF/NOTICE*",
                        "META-INF/*.kotlin_module",
                        "**/module-info.class",
                        "META-INF/versions/**",
                        "META-INF/INDEX.LIST",
                        "META-INF/com.google.guava/**",
                        "google/protobuf/**"
                    )
                    pickFirsts += "META-INF/services/**"
                }
            }
        }
    }

    // 3. แก้ไข Timestamp ก่อนเข้ากระบวนการ Merge - แก้ VerifyException ที่ MsDosDateTimeUtils
    tasks.matching { 
        it.name.contains("merge", ignoreCase = true) && 
        it.name.contains("JavaResource", ignoreCase = true) 
    }.configureEach {
        // ต้องตั้งค่า outputs.upToDateWhen ก่อน execution
        outputs.upToDateWhen { false }
        
        doFirst {
            val minTimestamp = 315532800000L // 1980-01-01 00:00:00 UTC (MS-DOS minimum)
            val maxTimestamp = 4354819200000L // 2107-12-31 23:59:59 UTC (MS-DOS maximum)
            val currentTimestamp = System.currentTimeMillis()
            
            println("🔧 Fixing timestamps for ${name}...")
            
            inputs.files.filter { it.exists() }.forEach { rootFile ->
                rootFile.walkTopDown().forEach { file ->
                    if (file.isFile) {
                        val current = file.lastModified()
                        // แก้ไข timestamp ที่อยู่นอกช่วง MS-DOS
                        if (current < minTimestamp || current > maxTimestamp) {
                            file.setLastModified(currentTimestamp)
                            println("  ✅ Fixed timestamp: ${file.name} (${current} -> ${currentTimestamp})")
                        }
                    }
                }
            }
        }
    }
}
