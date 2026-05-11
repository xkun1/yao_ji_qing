# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# MediaPipe / Google AI (Gemma)
-keep class com.google.mediapipe.** { *; }
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.mediapipe.**

# Google Play Core (Missing classes fix)
-dontwarn com.google.android.play.core.**

# Isar
-keep class io.isar.** { *; }

# Background Downloader
-keep class com.bb_can_fly.background_downloader.** { *; }

# Google ML Kit Text Recognition - 忽略可选语言脚本缺失的类
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# flutter_local_notifications 使用 Gson TypeToken 反序列化已排期通知。
# Release 混淆若移除泛型 Signature，会触发 RuntimeException: Missing type parameter.
-keepattributes Signature
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**
