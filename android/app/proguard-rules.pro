# Flutter/R8 compatibility rules

# Suppress warnings for androidx.window extensions (not present on all devices)
-dontwarn androidx.window.extensions.**
-dontwarn androidx.window.sidecar.**
-dontwarn androidx.window.area.**
-dontwarn androidx.window.layout.adapter.**
-dontwarn androidx.window.core.**
