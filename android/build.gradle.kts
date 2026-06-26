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

// ↓ MUST be registered BEFORE evaluationDependsOn triggers evaluation
subprojects {
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library")) {
            extensions.findByType<com.android.build.gradle.LibraryExtension>()?.apply {
                // Fix 1: namespace missing (previous fix — keep this)
                if (namespace == null) {
                    namespace = group.toString().ifEmpty {
                        "com.${project.name.replace("-", "_")}"
                    }
                }
                // Fix 2: lStar not found — force compileSdk ≥ 31 for all libraries
                compileSdk = 34
            }
        }
    }
}

// ↓ This forces evaluation — must come AFTER afterEvaluate is registered
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}