allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
    
    // Apply VerifyException workaround to all subprojects (plugins)
    tasks.configureEach {
        if (name.contains("merge") && (name.contains("JavaResource") || name.contains("GlobalSynthetics") || name.contains("Resources"))) {
            doFirst {
                try {
                    val safeTimestamp = 946684800000L
                    val buildDir = project.buildDir
                    val mergeDirs = listOf(
                        buildDir.resolve("intermediates/merge_java_res"),
                        buildDir.resolve("intermediates/merged_java_res"),
                        buildDir.resolve("intermediates/incremental/mergeDebugJavaResource"),
                        buildDir.resolve("intermediates/incremental/mergeReleaseJavaResource"),
                        buildDir.resolve("intermediates/processed_res"),
                        buildDir.resolve("intermediates/merged_res")
                    )
                    
                    mergeDirs.forEach { baseDir ->
                        if (baseDir.exists()) {
                            try {
                                baseDir.walkTopDown().forEach { file ->
                                    if (file.isFile) {
                                        try {
                                            file.setLastModified(safeTimestamp)
                                        } catch (e: Exception) {}
                                    }
                                }
                            } catch (e: Exception) {}
                        }
                    }
                    
                    // Fix dependency JARs/AARs
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
                            } catch (e: Exception) {}
                        }
                    } catch (e: Exception) {}
                } catch (e: Exception) {}
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
