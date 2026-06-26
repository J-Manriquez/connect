# MediaPipe / flutter_gemma rules
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

# Protocol Buffers rules
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# Missing classes reported by R8 in release
-dontwarn com.google.auto.value.extension.memoized.Memoized
-dontwarn com.google.mediapipe.proto.CalculatorProfileProto$CalculatorProfile
-dontwarn com.google.mediapipe.proto.GraphTemplateProto$CalculatorGraphTemplate
