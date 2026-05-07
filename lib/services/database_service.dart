import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/medicine.dart';
import 'gemini_service.dart';
import 'notification_service.dart';

class TodayMedicationTask {
  const TodayMedicationTask({
    required this.medicine,
    required this.reminder,
    required this.planTime,
    required this.isTaken,
  });

  final Medicine medicine;
  final Reminder reminder;
  final DateTime planTime;
  final bool isTaken;

  String get timeLabel =>
      '${planTime.hour.toString().padLeft(2, '0')}:${planTime.minute.toString().padLeft(2, '0')}';
}

class ReminderTime {
  const ReminderTime(this.hour, this.minute);

  final int hour;
  final int minute;
}

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Isar? _isar;
  final NotificationService _notifService = NotificationService();

  Future<void> init() async {
    if (_isar != null) return; // 防止重复初始化

    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [MedicineSchema, ReminderSchema, IntakeLogSchema],
      directory: dir.path,
    );
    await rescheduleAllActiveReminders();
  }

  Isar get isar => _isar!;

  // 获取所有药品
  Future<List<Medicine>> getAllMedicines() async {
    final medicines = await isar.medicines.where().findAll();
    for (final medicine in medicines) {
      await medicine.reminders.load();
    }
    return medicines;
  }

  Future<List<TodayMedicationTask>> getTodayMedicationTasks() async {
    final today = DateTime.now();
    final medicines = await getAllMedicines();
    final tasks = <TodayMedicationTask>[];

    for (final medicine in medicines) {
      for (final reminder in medicine.reminders) {
        if (!reminder.isActive) continue;

        final planTime = DateTime(
          today.year,
          today.month,
          today.day,
          reminder.hour,
          reminder.minute,
        );
        final log = await isar.intakeLogs
            .filter()
            .medicine((q) => q.idEqualTo(medicine.id))
            .planTimeEqualTo(planTime)
            .findFirst();

        tasks.add(TodayMedicationTask(
          medicine: medicine,
          reminder: reminder,
          planTime: planTime,
          isTaken: log?.isTaken == true,
        ));
      }
    }

    tasks.sort((a, b) {
      if (a.isTaken != b.isTaken) return a.isTaken ? 1 : -1;
      return a.planTime.compareTo(b.planTime);
    });
    return tasks;
  }

  Future<void> markTaskTaken(TodayMedicationTask task) async {
    final existing = await isar.intakeLogs
        .filter()
        .medicine((q) => q.idEqualTo(task.medicine.id))
        .planTimeEqualTo(task.planTime)
        .findFirst();

    await isar.writeTxn(() async {
      final log = existing ??
          (IntakeLog()
            ..planTime = task.planTime
            ..medicineName = task.medicine.name);

      log
        ..actualTime = DateTime.now()
        ..isTaken = true;

      log.medicine.value = task.medicine;

      await isar.intakeLogs.put(log);
      await log.medicine.save();
    });

    // 核心优化：吃完药立刻清掉通知中心的所有残留提醒（特别是 iOS 的连环提醒）
    await _notifService.cancelReminder(task.reminder.id);

    // 注意：不再需要在此处调用 scheduleDailyReminder。
    // 因为最初在添加药品时已经通过 Daily 模式排期，系统会自动处理明天的提醒。
    // 手动调用反而可能触发 iOS 本分钟内的残留提醒复活。
  }

  Future<void> rescheduleAllActiveReminders() async {
    final medicines = await getAllMedicines();
    for (final medicine in medicines) {
      for (final reminder in medicine.reminders) {
        if (!reminder.isActive) continue;
        await _notifService.scheduleDailyReminder(
          id: reminder.id,
          title: "💊 吃药时间到了：${medicine.name}",
          body:
              "剂量：${medicine.dosage ?? '按医嘱'} | 注意：${medicine.note ?? '按时吃药'}",
          hour: reminder.hour,
          minute: reminder.minute,
        );
      }
    }
  }

  // 保存从 AI 提取的药品信息
  Future<void> saveMedicationFromAI(MedicationInfo info) async {
    await _saveMedicineWithReminderTimes(
      name: info.name,
      dosage: info.dosage,
      frequency: info.frequency.toString(),
      instruction: '',
      note: info.precautions,
      times: _resolveReminderTimes(info),
    );
  }

  Future<void> saveMedicationManual({
    required String name,
    String? dosage,
    String? note,
    required List<ReminderTime> times,
  }) async {
    await _saveMedicineWithReminderTimes(
      name: name,
      dosage: dosage,
      frequency: times.length.toString(),
      instruction: '手动输入',
      note: note,
      times: times,
    );
  }

  Future<void> updateMedicationManual({
    required Medicine medicine,
    required String name,
    String? dosage,
    String? note,
    required List<ReminderTime> times,
  }) async {
    final oldName = medicine.name;
    await medicine.reminders.load();
    final oldReminderIds =
        medicine.reminders.map((reminder) => reminder.id).toList();

    // 1. 核心修复：修改前，先彻底撤回所有旧通知（包含 iOS 连环提醒组）
    for (final reminderId in oldReminderIds) {
      await _notifService.cancelReminder(reminderId);
    }

    final remindersToSchedule = <Reminder>[];
    await isar.writeTxn(() async {
      // 2. 如果药名变了，同步更新服药历史中的冗余药名，确保统计页面名字一致
      if (oldName != name) {
        final logs = await isar.intakeLogs
            .filter()
            .medicine((q) => q.idEqualTo(medicine.id))
            .findAll();
        for (final log in logs) {
          log.medicineName = name;
          await isar.intakeLogs.put(log);
        }
      }

      // 3. 更新药品主体信息
      medicine
        ..name = name
        ..dosage = dosage
        ..frequency = times.length.toString()
        ..instruction = medicine.instruction ?? '手动输入'
        ..note = note;

      // 4. 清除旧提醒规则，创建新规则（这会产生全新的 ID，防止冲突）
      medicine.reminders.clear();
      await medicine.reminders.save();
      await isar.reminders.deleteAll(oldReminderIds);

      await isar.medicines.put(medicine);
      for (final time in times) {
        final reminder = Reminder()
          ..hour = time.hour
          ..minute = time.minute;
        await isar.reminders.put(reminder);
        medicine.reminders.add(reminder);
        remindersToSchedule.add(reminder);
      }
      await medicine.reminders.save();
    });

    // 5. 开启全新的守护排期
    for (final reminder in remindersToSchedule) {
      await _notifService.scheduleDailyReminder(
        id: reminder.id,
        title: "💊 吃药时间到了：${medicine.name}",
        body: "剂量：${medicine.dosage ?? '按医嘱'} | 注意：${medicine.note ?? '按时吃药'}",
        hour: reminder.hour,
        minute: reminder.minute,
      );
    }
  }

  Future<void> deleteMedication(Medicine medicine) async {
    final id = medicine.id;
    if (id == Isar.autoIncrement) return;

    // 1. 加载并获取所有关联的提醒 ID
    await medicine.reminders.load();
    final reminderIds = medicine.reminders.map((r) => r.id).toList();

    // 2. 彻底取消系统层面的通知（包含 iOS 的连环提醒组和 Android 震动）
    // 注意：必须在删除数据库前执行，否则后面可能拿不到 reminder 数据
    for (final rId in reminderIds) {
      await _notifService.cancelReminder(rId);
    }

    // 3. 执行核弹级数据库清理：删除历史记录、提醒设置和药品本体
    await isar.writeTxn(() async {
      // 彻底删除该药的所有服药历史 (IntakeLog)
      await isar.intakeLogs
          .filter()
          .medicine((q) => q.idEqualTo(id))
          .deleteAll();

      // 彻底删除关联的提醒规则 (Reminder)
      if (reminderIds.isNotEmpty) {
        await isar.reminders.deleteAll(reminderIds);
      }

      // 最后抹除药品对象
      await isar.medicines.delete(id);
    });

    // 4. 停止前台服务（如果这是最后一项任务）
    // 逻辑会自动在 HomeScreen 的 _loadTodayTasks 中触发，此处确保数据一致性即可
  }

  Future<void> _saveMedicineWithReminderTimes({
    required String name,
    String? dosage,
    required String frequency,
    String? instruction,
    String? note,
    required List<ReminderTime> times,
  }) async {
    final medicine = Medicine()
      ..name = name
      ..dosage = dosage
      ..frequency = frequency
      ..instruction = instruction
      ..note = note;

    final remindersToSchedule = <Reminder>[];

    await isar.writeTxn(() async {
      await isar.medicines.put(medicine);

      for (final time in times) {
        final reminder = Reminder()
          ..hour = time.hour
          ..minute = time.minute;
        await isar.reminders.put(reminder);
        medicine.reminders.add(reminder);
        remindersToSchedule.add(reminder);
      }
      await medicine.reminders.save();
    });

    for (final reminder in remindersToSchedule) {
      await _notifService.scheduleDailyReminder(
        id: reminder.id,
        title: "💊 吃药时间到了：${medicine.name}",
        body: "剂量：${medicine.dosage ?? '按医嘱'} | 注意：${medicine.note ?? '按时吃药'}",
        hour: reminder.hour,
        minute: reminder.minute,
      );
    }
  }

  List<ReminderTime> _resolveReminderTimes(MedicationInfo info) {
    final parsedTimes = <ReminderTime>[];
    final seen = <String>{};

    for (final timeStr in info.times) {
      final match = RegExp(r'(\d{1,2})[:：](\d{1,2})').firstMatch(timeStr);
      if (match == null) continue;

      final hour = int.tryParse(match.group(1)!);
      final minute = int.tryParse(match.group(2)!);
      if (hour == null || minute == null) continue;
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) continue;

      final key = '$hour:$minute';
      if (seen.add(key)) {
        parsedTimes.add(ReminderTime(hour, minute));
      }
    }

    if (parsedTimes.isNotEmpty) return parsedTimes;

    if (info.frequency == 1) {
      return const [ReminderTime(8, 0)];
    }
    if (info.frequency == 2) {
      return const [ReminderTime(8, 0), ReminderTime(20, 0)];
    }
    if (info.frequency == 3) {
      return const [
        ReminderTime(8, 0),
        ReminderTime(12, 0),
        ReminderTime(18, 0),
      ];
    }
    return const [
      ReminderTime(8, 0),
      ReminderTime(12, 0),
      ReminderTime(18, 0),
      ReminderTime(22, 0),
    ];
  }
}
