import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

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
    return;
  }

  await FlutterForegroundTask.saveData(
    key: 'customData',
    value: 'device_protection',
  );

  NotificationPermission permission =
      await FlutterForegroundTask.checkNotificationPermission();
  if (permission != NotificationPermission.granted) {
    await FlutterForegroundTask.requestNotificationPermission();
  }

  await FlutterForegroundTask.startService(
    notificationTitle: 'Device Protection Active',
    notificationText: 'Securing device in background...',
    callback: startCallback,
  );
}
