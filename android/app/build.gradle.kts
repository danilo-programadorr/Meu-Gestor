import java.util.Base64
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "br.com.hellenfaro.meugestorfinanceiro"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "br.com.hellenfaro.meugestorfinanceiro"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

fun decodedDartDefines(): Map<String, String> {
    val encodedDefines = project.findProperty("dart-defines")?.toString().orEmpty()
    if (encodedDefines.isBlank()) {
        return emptyMap()
    }
    return encodedDefines
        .split(",")
        .mapNotNull { encoded ->
            runCatching {
                String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
            }.getOrNull()
        }
        .mapNotNull { define ->
            val separator = define.indexOf("=")
            if (separator <= 0) {
                null
            } else {
                define.substring(0, separator) to define.substring(separator + 1)
            }
        }
        .toMap()
}

tasks.configureEach {
    if (name.contains("Release", ignoreCase = true)) {
        doFirst {
            val defines = decodedDartDefines()
            if (defines["APP_ENV"] == "production" &&
                defines["LEGAL_DOCUMENTS_STATUS"] != "official") {
                throw GradleException(
                    "Build de produção bloqueado: documentos jurídicos oficiais pendentes.",
                )
            }
        }
    }
}
