plugins {
    id("com.android.library")
    id("kotlin-android")
}

android {
    namespace = "com.dartnative.bottom_sheet"
    compileSdk = 35

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    defaultConfig {
        minSdk = 26
        externalNativeBuild {
            cmake {
                path = file("src/main/cpp/CMakeLists.txt")
                version = "3.18.1"
            }
        }
    }

    buildFeatures { compose = true }
    composeOptions { kotlinCompilerExtensionVersion = "1.5.10" }
}

dependencies {
    compileOnly("com.dartnative:dartnative_android")
    // Compose BOM — aligns all Compose library versions
    implementation(platform("androidx.compose:compose-bom:2024.04.00"))
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-viewbinding")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.7.0")
}
