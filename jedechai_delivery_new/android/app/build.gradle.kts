plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.jedechai_delivery"
    compileSdk = 34
    ndkVersion = flutter.ndkVersion
	
	buildToolsVersion = "34.0.0"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.jedechai_delivery"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        multiDexEnabled = true
    }

    packaging {
        resources {
            pickFirsts += "META-INF/DEPENDENCIES"
            pickFirsts += "META-INF/LICENSE"
            pickFirsts += "META-INF/LICENSE.txt"
            pickFirsts += "META-INF/license.txt"
            pickFirsts += "META-INF/NOTICE"
            pickFirsts += "META-INF/NOTICE.txt"
            pickFirsts += "META-INF/notice.txt"
            pickFirsts += "META-INF/ASL2.0"
            pickFirsts += "META-INF/*.kotlin_module"
            pickFirsts += "**/kotlin-stdlib-common-*.jar"
            pickFirsts += "**/libc++_shared.so"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// ✅ ส่วนที่เพิ่มมาเพื่อแก้ Error ล่าสุด
configurations.all {
    resolutionStrategy {
        // ของเดิมที่คุณใส่ไว้ (ถูกต้องแล้ว เก็บไว้ครับ)
        force("androidx.browser:browser:1.8.0")
        force("androidx.core:core:1.13.1")
        force("androidx.core:core-ktx:1.13.1")

        // 🚩 แก้ตรงนี้: เปลี่ยนเป็น 2.0.21 ให้หมดครับ
        force("org.jetbrains.kotlin:kotlin-stdlib:2.0.21")
        force("org.jetbrains.kotlin:kotlin-stdlib-jdk7:2.0.21")
        force("org.jetbrains.kotlin:kotlin-stdlib-jdk8:2.0.21")
        force("org.jetbrains.kotlin:kotlin-stdlib-common:2.0.21")
    }
}