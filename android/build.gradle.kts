plugins {
    id("com.android.library")
    id("kotlin-android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.dartnative.bottom_sheet"
    compileSdk = 35
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 24
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    buildFeatures { compose = true }
}

dependencies {
    compileOnly(project(":dartnative_android"))
    // Compose BOM — aligns all Compose library versions
    // NOTE: newest stable BOM is 2026.08.00, but it pulls Compose 1.12.0 which
    // requires compileSdk 37 + AGP 9.1.0. Stay on 2026.06.00 until the host
    // app toolchain moves to 37. Still ships material3 1.4.0 (has every API
    // used here except rememberBottomSheetState, which needs 1.5.0+).
    implementation(platform("androidx.compose:compose-bom:2026.06.00"))
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-viewbinding")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.7.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel:2.7.0")
    implementation("androidx.savedstate:savedstate:1.2.1")
}
