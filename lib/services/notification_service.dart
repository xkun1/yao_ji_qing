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
  static const int _insistentFlag = 4;
  static final Int64List _vibrationPattern =
      Int64List.fromList(<int>[0, 1200, 400, 1200, 400, 1800]);
  static final Int32List _alarmNotificationFlags =
      Int32List.fromList(<int>[_insistentFlag]);

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
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
    );

    if (Platform.isAndroid) {
      final androidPlugin =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // 1. 申请常规通知权限
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

    await _notificationsPlugin.cancel(999);
    if (Platform.isAndroid) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.deleteNotificationChannel('test_channel');
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.deleteNotificationChannel('med_reminders_v3');
    }
  }

  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    // 获取当前设备时区的时间
    final now = DateTime.now();
    var scheduleDate = DateTime(now.year, now.month, now.day, hour, minute);

    if (scheduleDate.isBefore(now)) {
      scheduleDate = scheduleDate.add(const Duration(days: 1));
    }

    // 转换成 TZDateTime
    final tzScheduleDate = tz.TZDateTime.from(scheduleDate, tz.local);

    // [变更点] 不再让插件发通知，让原生发通知（为了接管 DeleteIntent）
    // await _notificationsPlugin.zonedSchedule(
    //   id,
    //   title,
    //   body,
    //   ...
    // );

    await _scheduleDailyNativeVibration(
      id: id,
      title: title,
      body: body,
      hour: hour,
      minute: minute,
    );
  }

  Future<void> cancelReminder(int id) async {
    await _notificationsPlugin.cancel(id);
    await _cancelNativeVibration(id);
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
    } on PlatformException {
      // 原生震动兜底失败时，不影响系统通知本身的调度。
    } on MissingPluginException {
      // 兼容非标准启动场景，避免 MethodChannel 未注册导致提醒保存失败。
    }
  }

  Future<void> _cancelNativeVibration(int id) async {
    if (!Platform.isAndroid) return;

    try {
      await _vibrationChannel
          .invokeMethod<void>('cancelDailyVibration', <String, int>{
        'id': id,
      });
    } on PlatformException {
      // 系统通知取消成功即可，原生震动取消失败不阻断业务流程。
    } on MissingPluginException {
      // 兼容 MethodChannel 未注册场景。
    }
  }

  /// 用户交互通知时停止当前正在活跃的振动。
  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    _stopActiveVibration();
  }

  Future<void> _stopActiveVibration() async {
    if (!Platform.isAndroid) return;

    try {
      await _vibrationChannel.invokeMethod<void>('stopActiveVibration');
    } on PlatformException {
      // 停止失败不影响交互流程。
    } on MissingPluginException {
      // 兼容非标准启动场景。
    }
  }
}
