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
