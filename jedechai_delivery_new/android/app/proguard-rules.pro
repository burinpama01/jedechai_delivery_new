# R8 rules สำหรับ release build (เปิด minify เพื่อผ่านเกณฑ์ DEX optimization ของ Play)
# Flutter engine/embedding มี consumer rules ของตัวเองอยู่แล้ว — ที่นี่เพิ่มเฉพาะ plugin ที่ไม่มี

# Flutter deferred components อ้าง Play Core แต่แอปไม่ได้ใช้
-dontwarn com.google.android.play.core.**

# flutter_local_notifications — serialize การตั้งเวลาแจ้งเตือนด้วย Gson (ใช้ reflection)
-keep class com.dexterous.** { *; }

# Gson — TypeToken/generic signature ต้องคงไว้ ไม่งั้นแครชตอนอ่านแจ้งเตือนที่ตั้งเวลาไว้
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-dontwarn sun.misc.**
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# flutter_foreground_task — service/receiver ของคนขับออนไลน์เบื้องหลัง
-keep class com.pravera.flutter_foreground_task.** { *; }
