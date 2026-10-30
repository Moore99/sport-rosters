# Preserve source file names and line numbers for Crashlytics stack traces
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Flutter, Firebase, Play Services, Play Billing and uCrop ship their own
# consumer R8 rules. Blanket -keep rules for them here stopped R8 from shrinking
# or optimizing most of the app's Java code (Play Console flagged ~18%).

# WorkManager / Room: WorkDatabase is instantiated via reflection at runtime.
# R8 once stripped it, causing a startup crash: "Failed to create an instance
# of androidx.work.impl.WorkDatabase". Keep the generated database classes
# and their constructors only.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
