# Flutter rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Desugar JDK libs
-dontwarn java.time.**
-dontwarn org.threeten.bp.**

# Play Core / In-App Update
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Secure Storage
-keep class androidx.security.crypto.** { *; }
