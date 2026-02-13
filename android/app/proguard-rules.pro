## Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

## Supabase & PostgREST
# Prevent R8 from renaming the models used for database communication
-keep class com.supabase.** { *; }
-dontwarn com.supabase.**

## JSON Serialization (Gson/Jackson)
# If Supabase or your plugins use Gson for JSON parsing
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class sun.misc.Unsafe { *; }

## Image Picker
-keep class com.baseflow.imagepicker.** { *; }

# Flutter Deferred Components / Play Core missing classes
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**