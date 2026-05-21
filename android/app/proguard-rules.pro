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

# Play Core (Flutter deferred components — not used but referenced by Flutter engine)
-dontwarn com.google.android.play.core.**

# Javax annotation processing (AutoValue / annotation tools)
-dontwarn javax.lang.model.**
-dontwarn javax.annotation.processing.**
-dontwarn autovalue.shaded.**

# MapLibre / MapTiler
-keep class com.mapbox.** { *; }
-keep class org.maplibre.** { *; }
-dontwarn org.maplibre.**

# Sensors / Camera
-keep class dev.fluttercommunity.plus.sensors.** { *; }
-keep class io.flutter.plugins.camera.** { *; }
