import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  /// Pass a callback that gets triggered when the notification is tapped.
  Future<void> initialize(Function(String?) onSelectNotification) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    // Use named parameter settings
    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        onSelectNotification(response.payload);
      },
    );

    // Request permissions for Android 13+
    _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> showBingoPersistentNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'bingo_assistant_channel',
      'Bingo Assistant',
      channelDescription: 'Quick access to Ask Bingo',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true, // Makes it persistent in the notification drawer
      autoCancel: false,
    );

    await _notificationsPlugin.show(
      id: 888,
      title: 'Ask Bingo 🎙️',
      body: 'Tap to issue a voice command',
      notificationDetails: const NotificationDetails(android: androidDetails),
      payload: 'bingo_voice',
    );
  }
}
