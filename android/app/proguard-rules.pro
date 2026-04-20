# Preserve source file names and line numbers for Crashlytics stack traces
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase / Google Play Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# In-app purchases (Google Play Billing)
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }

# Image picker / cropper
-keep class com.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**
