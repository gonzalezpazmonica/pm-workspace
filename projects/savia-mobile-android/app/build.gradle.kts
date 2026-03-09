plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.ksp)
    alias(libs.plugins.hilt)
    alias(libs.plugins.roborazzi)
}

// --- Auto-version: increment + read at configuration time ---
// This ensures the APK always embeds the NEW version, not the old one.
import java.util.Properties

val versionFile = rootProject.file("version.properties")
val isDebugBuild = gradle.startParameter.taskNames.any { it.contains("Debug", ignoreCase = true) }

fun loadAndIncrementVersionProps(): Properties {
    val props = Properties()
    if (versionFile.exists()) {
        versionFile.inputStream().use { props.load(it) }
    } else {
        props.setProperty("VERSION_CODE", "0")
        props.setProperty("VERSION_MAJOR", "0")
        props.setProperty("VERSION_MINOR", "1")
        props.setProperty("VERSION_PATCH", "0")
    }
    // Auto-increment on debug builds at configuration time
    if (isDebugBuild) {
        val newCode = props.getProperty("VERSION_CODE").toInt() + 1
        val newPatch = props.getProperty("VERSION_PATCH").toInt() + 1
        props.setProperty("VERSION_CODE", newCode.toString())
        props.setProperty("VERSION_PATCH", newPatch.toString())
        versionFile.outputStream().use { props.store(it, "Savia Mobile version (auto-managed)") }
        logger.lifecycle("Version incremented: versionCode=$newCode, patch=$newPatch")
    }
    return props
}
val versionProps = loadAndIncrementVersionProps()
val appVersionCode = versionProps.getProperty("VERSION_CODE").toInt()
val appVersionName = "${versionProps.getProperty("VERSION_MAJOR")}.${versionProps.getProperty("VERSION_MINOR")}.${versionProps.getProperty("VERSION_PATCH")}"

// Task: copy debug APK to Bridge distribution folder and scripts/dist
// Uses Exec to avoid configuration-cache serialization issues
val bridgeApkPath = "${System.getProperty("user.home")}/.savia/bridge/apk/savia-mobile.apk"
val distApkPath = "${System.getProperty("user.home")}/savia/scripts/dist/app-debug.apk"
val apkSourcePath = layout.buildDirectory.file("outputs/apk/debug/app-debug.apk").map { it.asFile.absolutePath }

tasks.register<Exec>("publishToBridge") {
    description = "Copies debug APK to ~/.savia/bridge/apk/ for distribution"
    commandLine("cp", "-f", apkSourcePath.get(), bridgeApkPath)
    isIgnoreExitValue = true
}

tasks.register<Exec>("publishToDist") {
    description = "Copies debug APK to scripts/dist/ for integration tests"
    commandLine("cp", "-f", apkSourcePath.get(), distApkPath)
    isIgnoreExitValue = true
}

// assembleDebug: run unit tests first, then publish to Bridge + dist
// Flow: testDebugUnitTest → assembleDebug → publishToBridge + publishToDist
// If tests fail, assembleDebug won't run, so no broken APK gets published.
tasks.whenTaskAdded {
    if (name == "assembleDebug") {
        dependsOn("testDebugUnitTest")
        finalizedBy("publishToBridge", "publishToDist")
    }
}

android {
    namespace = "com.savia.mobile"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.savia.mobile"
        minSdk = 26
        targetSdk = 35
        versionCode = appVersionCode
        versionName = appVersionName

        testInstrumentationRunner = "com.savia.mobile.HiltTestRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            isMinifyEnabled = false
            versionNameSuffix = "-debug"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.systemProperty("robolectric.graphicsMode", "NATIVE")
                // Exclude screenshot tests from release builds (Roborazzi only works with debug)
                if (it.name.contains("Release")) {
                    it.exclude("**/screenshot/**")
                }
            }
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    // Modules
    implementation(project(":domain"))
    implementation(project(":data"))

    // Compose
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons)
    implementation(libs.compose.runtime)
    debugImplementation(libs.compose.ui.tooling)

    // AndroidX
    implementation(libs.core.ktx)
    implementation(libs.splashscreen)
    implementation(libs.activity.compose)
    implementation(libs.lifecycle.runtime)
    implementation(libs.lifecycle.viewmodel)
    implementation(libs.navigation.compose)

    // Hilt
    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
    implementation(libs.hilt.navigation.compose)

    // Google Sign-In (Credential Manager)
    implementation(libs.credentials)
    implementation(libs.credentials.play)
    implementation(libs.google.id)

    // Network (needed by NetworkModule DI provider)
    implementation(libs.retrofit)
    implementation(libs.retrofit.serialization)
    implementation(libs.okhttp)
    implementation(libs.okhttp.logging)

    // Serialization
    implementation(libs.kotlinx.serialization)
    implementation(libs.kotlinx.coroutines)

    // Markdown rendering
    implementation(libs.markwon.core)
    implementation(libs.markwon.strikethrough)
    implementation(libs.markwon.tables)

    // Testing
    testImplementation(libs.junit)
    testImplementation(libs.mockk)
    testImplementation(libs.turbine)
    testImplementation(libs.truth)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.mockwebserver)
    testImplementation(libs.robolectric)
    testImplementation(libs.roborazzi.core)
    testImplementation(libs.roborazzi.compose)
    testImplementation(libs.roborazzi.junit)
    testImplementation(platform(libs.compose.bom))
    testImplementation(libs.compose.ui.test)
    testImplementation(libs.room.testing)
    testImplementation(libs.arch.core.testing)
    testImplementation(libs.test.core)
    androidTestImplementation(libs.junit.ext)
    androidTestImplementation(platform(libs.compose.bom))
    androidTestImplementation(libs.compose.ui.test)
    androidTestImplementation(libs.uiautomator)
    androidTestImplementation(libs.hilt.android.testing)
    androidTestImplementation(libs.test.runner)
    androidTestImplementation(libs.test.rules)
    androidTestImplementation(libs.okhttp)
    kspAndroidTest(libs.hilt.compiler)
    debugImplementation(libs.compose.ui.test.manifest)
}
