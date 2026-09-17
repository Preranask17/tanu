import org.gradle.api.Project

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
}

fun Project.forceCompileSdk36() {
    val androidExt = extensions.findByName("android") ?: return
    try {
        val current = try {
            androidExt.javaClass.getMethod("getCompileSdkVersion").invoke(androidExt) as? Int ?: 0
        } catch (e: Exception) {
            0
        }
        if (current < 36) {
            androidExt.javaClass
                .getMethod("setCompileSdkVersion", Integer.TYPE)
                .invoke(androidExt, 36)
        }
    } catch (e: Exception) {
        logger.warn("tanu: could not force compileSdk for ${project.name}: ${e.message}")
    }
}

// Force every Android plugin subproject to compile against SDK 36. Several
// plugins (opus_flutter_android, speech_to_text) ship stale compileSdk values
// that their own androidx dependencies no longer accept.
subprojects {
    if (state.executed) {
        forceCompileSdk36()
    } else {
        afterEvaluate { forceCompileSdk36() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
