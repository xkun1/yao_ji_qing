import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'dart:io';
import 'dart:typed_data';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static const MethodChannel _vibrationChannel =
      MethodChannel('yao_ji_qing/medication_vibration');
  static const String _reminderChannelId = 'med_reminders_alarm_v4';
  static const String _reminderChannelName = '用药提醒通道';
  static final Int64List _vibrationPattern =
      Int64List.fromList(<int>[0, 1200, 400, 1200, 400, 1800]);

  Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _stopActiveVibration();
      },
    );

    if (Platform.isAndroid) {
      final androidPlugin =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
      await androidPlugin?.requestFullScreenIntentPermission();
      await androidPlugin?.createNotificationChannel(
        AndroidNotificationChannel(
          _reminderChannelId,
          _reminderChannelName,
          description: '系统会按时提醒用户吃药，并震动提示。',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: _vibrationPattern,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      );
    }
  }

  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final now = DateTime.now();
    var scheduleDate = DateTime(now.year, now.month, now.day, hour, minute);

    if (scheduleDate.isBefore(now)) {
      scheduleDate = scheduleDate.add(const Duration(days: 1));
    }

    final tzScheduleDate = tz.TZDateTime.from(scheduleDate, tz.local);

    if (Platform.isIOS) {
      // 1. 基础通知 (ID 为原始 id)
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduleDate,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'default',
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      // 2. iOS 连环提醒：接下来的 5 分钟内 (ID 偏移 20000 避免冲突)
      for (int i = 1; i <= 9; i++) {
        final repeatDate = tzScheduleDate.add(Duration(seconds: i * 30));
        await _notificationsPlugin.zonedSchedule(
          id + i * 20000,
          "🔔 再次提醒：$title",
          body,
          repeatDate,
          const NotificationDetails(
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
              sound: 'default',
              interruptionLevel: InterruptionLevel.timeSensitive,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    }

    if (Platform.isAndroid) {
      await _scheduleDailyNativeVibration(
        id: id,
        title: title,
        body: body,
        hour: hour,
        minute: minute,
      );
    }
  }

  Future<void> cancelReminder(int id) async {
    if (Platform.isIOS) {
      // 彻底清理 iOS 连环提醒组
      await _notificationsPlugin.cancel(id);
      for (int i = 1; i <= 9; i++) {
        await _notificationsPlugin.cancel(id + i * 20000);
      }
    }

    // Android 提醒由原生闹钟/震动链路负责，避免 release 混淆后
    // flutter_local_notifications 读取旧排期缓存时抛 Missing type parameter。
    await _stopActiveVibration();
    await _cancelNativeVibration(id);
  }

  Future<void> cancelAllReminders() async {
    await _notificationsPlugin.cancelAll();
    await stopForegroundService();
    if (Platform.isAndroid) {
      await _vibrationChannel.invokeMethod<void>('stopActiveVibration');
    }
  }

  Future<void> _scheduleDailyNativeVibration({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    if (!Platform.isAndroid) return;

    try {
      await _vibrationChannel
          .invokeMethod<void>('scheduleDailyVibration', <String, dynamic>{
        'id': id,
        'title': title,
        'body': body,
        'hour': hour,
        'minute': minute,
      });
    } catch (_) {}
  }

  Future<void> _cancelNativeVibration(int id) async {
    if (!Platform.isAndroid) return;

    try {
      await _vibrationChannel
          .invokeMethod<void>('cancelDailyVibration', <String, int>{
        'id': id,
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _stopActiveVibration() async {
    if (!Platform.isAndroid) return;

    try {
      await _vibrationChannel.invokeMethod<void>('stopActiveVibration');
    } catch (_) {}
  }

  Future<void> startForegroundService() async {
    if (!Platform.isAndroid) return;
    try {
      await _vibrationChannel.invokeMethod<void>('startForegroundService');
    } catch (_) {}
  }

  Future<void> updateForegroundService({
    required String title,
    required String body,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _vibrationChannel.invokeMethod<void>('updateForegroundService', {
        'title': title,
        'body': body,
      });
    } catch (_) {}
  }

  Future<void> stopForegroundService() async {
    if (!Platform.isAndroid) return;
    try {
      await _vibrationChannel.invokeMethod<void>('stopForegroundService');
    } catch (_) {}
  }
}
