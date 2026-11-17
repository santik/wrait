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

    project.plugins.whenPluginAdded {
        if (this is com.android.build.gradle.BasePlugin) {
            project.extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }
        if (this is org.jetbrains.kotlin.gradle.plugin.KotlinBasePluginWrapper) {
            // The home_widget plugin pins BOTH its Java and Kotlin targets to
            // 1.8 (consistent on its own). Forcing only its Kotlin to 17 here
            // would leave Java at 1.8 and fail AGP 9's JVM-target validation,
            // so leave that module at its own consistent 1.8 target.
            if (project.name != "home_widget") {
                project.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                    compilerOptions {
                        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
