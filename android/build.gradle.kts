allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Force all plugin subprojects to compile against SDK 36
// This is required because flutter_plugin_android_lifecycle needs compileSdk >= 36
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            (project.extensions.getByName("android") as com.android.build.gradle.BaseExtension).apply {
                compileSdkVersion(36)
            }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
