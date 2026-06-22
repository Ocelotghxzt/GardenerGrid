import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  bool _localReady = false;

  Future<void> init() async {
    if (!kIsWeb) {
      try {
        const android = AndroidInitializationSettings('@mipmap/ic_launcher');
        const ios = DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
        await _local.initialize(
          settings: const InitializationSettings(android: android, iOS: ios),
        );
        _localReady = true;
      } catch (_) {
        _localReady = false;
      }
    }

    // Firebase Cloud Messaging for push notifications
    try {
      await FirebaseMessaging.instance.requestPermission();
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    } catch (_) {
      // FCM can be unavailable in some web contexts; continue without crash.
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    showLocalNotification(
      title: notification.title ?? 'GardenerGrid',
      body: notification.body ?? '',
    );
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_localReady) {
      return;
    }
    const androidDetails = AndroidNotificationDetails(
      'gardenergrid_channel',
      'GardenerGrid Alerts',
      channelDescription: 'Soil, crop, and market alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    await _local.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails:
          const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  Future<void> scheduleTaskReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    // TODO: add timezone-aware scheduling with timezone package
    await showLocalNotification(title: title, body: body);
  }
}
