plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.ksp)
    alias(libs.plugins.hilt)
    alias(libs.plugins.roborazzi)
}

// --- Auto-version: read from version.properties ---
import java.util.Properties

val versionFile = rootProject.file("version.properties")
fun loadVersionProps(): Properties {
    val props = Properties()
    if (versionFile.exists()) {
        versionFile.inputStream().use { props.load(it) }
    } else {
        props.setProperty("VERSION_CODE", "1")
        props.setProperty("VERSION_MAJOR", "0")
        props.setProperty("VERSION_MINOR", "1")
        props.setProperty("VERSION_PATCH", "0")
        versionFile.outputStream().use { props.store(it, "Savia Mobile version (auto-managed)") }
    }
    return props
}
val versionProps = loadVersionProps()
val appVersionCode = versionProps.getProperty("VERSION_CODE").toInt()
val appVersionName = "${versionProps.getProperty("VERSION_MAJOR")}.${versionProps.getProperty("VERSION_MINOR")}.${versionProps.getProperty("VERSION_PATCH")}"

// Task: increment versionCode + patch for debug builds
tasks.register("incrementVersion") {
    val file = rootProject.file("version.properties")
    doLast {
        val props = Properties()
        file.inputStream().use { props.load(it) }
        val newCode = props.getProperty("VERSION_CODE").toInt() + 1
        val newPatch = props.getProperty("VERSION_PATCH").toInt() + 1
        props.setProperty("VERSION_CODE", newCode.toString())
        props.setProperty("VERSION_PATCH", newPatch.toString())
        file.outputStream().use { props.store(it, "Savia Mobile version (auto-managed)") }
        logger.lifecycle("Version incremented: versionCode=$newCode, patch=$newPatch")
    }
}

// Only assembleDebug auto-increments
tasks.whenTaskAdded {
    if (name == "assembleDebug") {
        dependsOn("incrementVersion")
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

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
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
    debugImplementation(libs.compose.ui.test.manifest)
}
