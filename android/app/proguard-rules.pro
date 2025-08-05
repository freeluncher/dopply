# Keep Google errorprone and javax.annotation classes
-keep class com.google.errorprone.annotations.** { *; }
-keep class javax.annotation.** { *; }

# Suppress warnings for missing rules
-dontwarn javax.annotation.Nullable
-dontwarn javax.annotation.concurrent.GuardedBy
-dontwarn javax.lang.model.element.Modifier
