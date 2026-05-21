## BushTrack ProGuard rules

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# SQLite
-keep class com.tekartik.sqflite.** { *; }

# Nearby Connections
-keep class com.google.android.gms.nearby.** { *; }

# Keep enums
-keepclassmembers enum * { *; }

# Keep Kotlin metadata
-keep class kotlin.Metadata { *; }
