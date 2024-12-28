import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Здесь будет ваш API запрос
    // Пока просто симулируем некое условие
    bool needNotification = DateTime.now().second % 2 == 0;

    if (needNotification) {
      // Вибрация
      await Vibration.vibrate(duration: 500);

      // Показываем уведомление
      final FlutterLocalNotificationsPlugin notifications =
          FlutterLocalNotificationsPlugin();
      
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'crypto_watch_channel',
        'Crypto Watch Notifications',
        description: 'Channel for Crypto Watch notifications',
        importance: Importance.high,
      );

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'crypto_watch_channel',
        'Crypto Watch Notifications',
        channelDescription: 'Channel for Crypto Watch notifications',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );
      
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);
      
      await notifications.show(
        0,
        'Crypto Watch',
        'Фоновое обновление!',
        platformChannelSpecifics,
      );
    }

    return Future.value(true);
  });
} 