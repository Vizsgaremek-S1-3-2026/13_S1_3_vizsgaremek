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
    
    // Add namespace to subprojects (plugins) if not specified (needed for AGP 8.0+)
    project.plugins.withId("com.android.library") {
        val extension = project.extensions.getByType(com.android.build.gradle.LibraryExtension::class.java)
        if (extension.namespace == null) {
            extension.namespace = if (project.name == "flutter_windowmanager") {
                "io.adaptant.labs.flutter_windowmanager"
            } else {
                "com.cquizy.plugins.${project.name.replace("-", ".")}"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
