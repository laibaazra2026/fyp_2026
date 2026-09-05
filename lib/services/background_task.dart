import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await Firebase.initializeApp();

    // Listen for FCM messages while the foreground service runs
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print("📩 Foreground service message received: ${message.data}");
      String type = message.data['type'] ?? '';

      if (type == 'LOCK') {
        const platform = MethodChannel('device_protection/admin');
        try {
          await platform.invokeMethod('lockDevice');
          print("🔒 Phone locked successfully from foreground service!");
        } catch (e) {
          print("❌ Failed to lock phone: $e");
        }
      }
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {}

  @override
  void onNotificationDismissed() {}
}

Future<void> startService() async {
  if (await FlutterForegroundTask.isRunningService) {
    await FlutterForegroundTask.restartService();
    return;
  }

  final NotificationPermission permission =
      await FlutterForegroundTask.checkNotificationPermission();
  if (permission != NotificationPermission.granted) {
    await FlutterForegroundTask.requestNotificationPermission();
  }

  await FlutterForegroundTask.startService(
    serviceId: 256,
    notificationTitle: 'Device Protection Active',
    notificationText: 'Securing device in background...',
    callback: startCallback,
  );
}
