import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Initialize the notification service
  static Future<void> init() async {
    if (_initialized) return;

    // Initialize time zones
    tz_data.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
    debugPrint('NotificationService initialized');
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // You can navigate to weight tracker page here if needed
  }

  /// Request notification permissions (required for Android 13+)
  static Future<bool> requestPermissions() async {
    final android = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    final ios = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  /// Schedule the weekly Sunday 12 PM weight reminder
  static Future<void> scheduleWeeklySundayReminder() async {
    await _notificationsPlugin.zonedSchedule(
      1, // Unique ID for weekly weight reminder
      '⚖️ Weekly Weigh-In Reminder',
      "It's Sunday! Time to log your weekly weight and track your progress.",
      _nextInstanceOfSundayNoon(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_weight_reminder',
          'Weekly Weight Reminders',
          channelDescription:
              'Reminds you to log your weight every Sunday at noon',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF00E676),
          enableVibration: true,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents:
          DateTimeComponents.dayOfWeekAndTime, // Repeats weekly!
    );

    debugPrint('Weekly Sunday reminder scheduled for 12:00 PM');
  }

  /// Calculate the next Sunday at 12:00 PM
  static tz.TZDateTime _nextInstanceOfSundayNoon() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    // Create a date for today at 12:00 PM (noon)
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      12,
      0,
    );

    // Move to next Sunday
    while (scheduledDate.weekday != DateTime.sunday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // If it's already past Sunday noon, add 7 days
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    debugPrint('Next Sunday reminder scheduled for: $scheduledDate');
    return scheduledDate;
  }

  /// Cancel the weekly reminder
  static Future<void> cancelWeeklySundayReminder() async {
    await _notificationsPlugin.cancel(1);
    debugPrint('Weekly Sunday reminder cancelled');
  }

  /// Check if weekly reminder is scheduled
  static Future<bool> isWeeklyReminderScheduled() async {
    final pendingNotifications = await _notificationsPlugin
        .pendingNotificationRequests();
    return pendingNotifications.any((n) => n.id == 1);
  }

  /// Show an immediate test notification
  static Future<void> showTestNotification() async {
    await _notificationsPlugin.show(
      999,
      '🎉 Notifications Working!',
      'You will receive weekly weight reminders every Sunday at 12 PM.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test Notifications',
          channelDescription: 'Used for testing notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF00E676),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Cancel all notifications
  static Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
