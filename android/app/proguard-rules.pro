# flutter_local_notifications restaura notificações agendadas após reboot via
# reflexão + serializa os detalhes agendados com Gson — sem manter essas
# classes o R8 remove/renomeia código que só é referenciado dinamicamente.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn com.google.gson.**

# workmanager reinvoca a callback Dart registrada (_bgCallback) num isolate
# separado a partir de um Worker do Android; precisa manter essas classes.
-keep class dev.fluttercommunity.workmanager.** { *; }
-keep class androidx.work.** { *; }
