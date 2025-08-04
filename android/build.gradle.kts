plugins {
 
  id("com.google.gms.google-services") version "4.4.2" apply false

}
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Add resolution strategy to force single versions of annotation libraries
subprojects {
    configurations.all {
        resolutionStrategy {
            force("androidx.annotation:annotation:1.7.1")
            force("androidx.annotation:annotation-experimental:1.3.1")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
