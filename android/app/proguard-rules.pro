# ==============================================================================
# GearLease Android ProGuard / R8 Obfuscation & Shrinking Rules
# ==============================================================================

# 1. Flutter Engine & Embedding
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# 2. Retain Line Numbers & Stack Attributes for Deobfuscation
# Needed for symbol splitting and mapping crash logs back to source lines
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# 3. Flutter Secure Storage & AndroidX Security Crypto
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# 4. Biometric Authentication (FaceID / Fingerprint)
-keep class androidx.biometric.** { *; }
-keep class io.flutter.plugins.localauth.** { *; }
-dontwarn androidx.biometric.**

# 5. SQLite / Sqflite Local Database
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**

# 6. Workmanager Background Sync Worker
-keep class androidx.work.** { *; }
-keep class dev.fluttercommunity.workmanager.** { *; }
-dontwarn androidx.work.**

# 7. Networking (Dio, OkHttp3, WebSockets)
-keepattributes EnclosingMethod
-keepclassmembers enum * { *; }
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# 8. Mobile Scanner / ML Kit Vision
-keep class com.google.mlkit.** { *; }
-keep class dev.steenbakker.mobile_scanner.** { *; }
-dontwarn com.google.mlkit.**

# 9. Image Compression & Camera Pipeline
-keep class io.flutter.plugins.camera.** { *; }
-keep class com.example.flutter_image_compress.** { *; }
-dontwarn io.flutter.plugins.camera.**
-dontwarn com.example.flutter_image_compress.**
