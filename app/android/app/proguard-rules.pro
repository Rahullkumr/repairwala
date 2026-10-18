# Release builds are shrunk by R8. Some Flutter plugins (shared_preferences, path_provider)
# call their Kotlin code from Dart through JNI, which R8 can't see, so it strips those methods
# and the app crashes at start with NoSuchMethodError. Keep the plugin and JNI bridge classes,
# and don't rename anything: the JNI lookups name parameter types too (kotlin.coroutines.Continuation).
-dontobfuscate
-keep class io.flutter.plugins.** { *; }
-keep class dev.flutter.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
