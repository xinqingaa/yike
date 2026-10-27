import org.gradle.api.JavaVersion
import org.gradle.api.tasks.compile.JavaCompile

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

// Library plugins that never set a language level still compile as Java 8.
gradle.projectsEvaluated {
    subprojects {
        tasks.withType<JavaCompile>().configureEach {
            if (sourceCompatibility == "1.8" || sourceCompatibility == "8") {
                sourceCompatibility = JavaVersion.VERSION_17.toString()
            }
            if (targetCompatibility == "1.8" || targetCompatibility == "8") {
                targetCompatibility = JavaVersion.VERSION_17.toString()
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
