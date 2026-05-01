import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'settings_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  NotificationService._init();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();

    // Android initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels
    await _createNotificationChannels();

    _initialized = true;
  }

  Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel streakChannel = AndroidNotificationChannel(
      'streak_reminders',
      'Streak Reminders',
      description: 'Reminders to maintain your daily scanning streak',
      importance: Importance.high,
    );

    const AndroidNotificationChannel goalsChannel = AndroidNotificationChannel(
      'daily_goals',
      'Daily Goals',
      description: 'Notifications about your daily nutrition goals',
      importance: Importance.medium,
    );

    const AndroidNotificationChannel achievementsChannel = AndroidNotificationChannel(
      'achievements',
      'Achievements',
      description: 'Unlock new badges and milestones',
      importance: Importance.high,
    );

    const AndroidNotificationChannel socialChannel = AndroidNotificationChannel(
      'social',
      'Social',
      description: 'Friend activities and challenges',
      importance: Importance.low,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(streakChannel);

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(goalsChannel);

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(achievementsChannel);

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(socialChannel);
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    print('Notification tapped: ${response.payload}');
  }

  // Schedule daily streak reminder
  Future<void> scheduleStreakReminder() async {
    if (!_initialized) await initialize();

    await _notifications.zonedSchedule(
      1,
      'Keep your streak alive!',
      'You haven\'t scanned any desserts today. Don\'t lose your streak!',
      _nextInstanceOfTime(19, 0), // 7 PM
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_reminders',
          'Streak Reminders',
          channelDescription: 'Reminders to maintain your daily scanning streak',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'streak_reminders',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // Schedule goal check notifications
  Future<void> scheduleGoalChecks() async {
    if (!_initialized) await initialize();

    // Check calories at 8 PM
    await _notifications.zonedSchedule(
      2,
      'Daily Calorie Check',
      'You\'ve consumed X calories today. Y calories remaining.',
      _nextInstanceOfTime(20, 0), // 8 PM
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_goals',
          'Daily Goals',
          channelDescription: 'Notifications about your daily nutrition goals',
          importance: Importance.medium,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // Show achievement notification
  Future<void> showAchievement(String title, String description) async {
    if (!_initialized) await initialize();

    await _notifications.show(
      3,
      'Achievement Unlocked! $title',
      description,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'achievements',
          'Achievements',
          channelDescription: 'Unlock new badges and milestones',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF2196F3),
          enableVibration: true,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'achievements',
        ),
      ),
    );
  }

  // Show social notification
  Future<void> showSocialNotification(String title, String message) async {
    if (!_initialized) await initialize();

    await _notifications.show(
      4,
      title,
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'social',
          'Social',
          channelDescription: 'Friend activities and challenges',
          importance: Importance.low,
          priority: Priority.low,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'social',
        ),
      ),
    );
  }

  // Show daily summary
  Future<void> showDailySummary(int scans, int calories, int streak) async {
    if (!_initialized) await initialize();

    await _notifications.show(
      5,
      'Daily Summary',
      'Today: $scans scans, $calories calories. Streak: $streak days! $streakEmoji',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_goals',
          'Daily Goals',
          channelDescription: 'Notifications about your daily nutrition goals',
          importance: Importance.medium,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  // Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  // Helper to get next instance of specific time
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    return scheduledDate;
  }

  String get streakEmoji {
    final streak = SettingsService.instance.scanStreak;
    if (streak >= 30) return 'Fire! ';
    if (streak >= 7) return '';
    if (streak >= 3) return '';
    return '';
  }

  // Update scheduled notifications based on settings
  Future<void> updateScheduledNotifications() async {
    if (!SettingsService.instance.notificationsEnabled) {
      await cancelAllNotifications();
      return;
    }

    // Reschedule based on user preferences
    await scheduleStreakReminder();
    await scheduleGoalChecks();
  }

  // Show immediate notification (for testing)
  Future<void> showTestNotification() async {
    if (!_initialized) await initialize();

    await _notifications.show(
      999,
      'Test Notification',
      'Smart Tracker notifications are working!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_goals',
          'Daily Goals',
          channelDescription: 'Test notification',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }
}
