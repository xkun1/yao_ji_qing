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

class DemoMedication {
  const DemoMedication({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.note,
    required this.hour,
    required this.minute,
  });

  final String name;
  final String dosage;
  final String frequency;
  final String note;
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
    await _removeLegacySeedData();
    await _ensureDemoMedicines();
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
            .medicineNameEqualTo(medicine.name)
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
        .medicineNameEqualTo(task.medicine.name)
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

      await isar.intakeLogs.put(log);
    });
  }

  Future<void> rescheduleAllActiveReminders() async {
    final medicines = await getAllMedicines();
    for (final medicine in medicines) {
      for (final reminder in medicine.reminders) {
        if (!reminder.isActive) continue;
        await _notifService.scheduleDailyReminder(
          id: reminder.id,
          title: "💊 吃药时间到了：${medicine.name}",
          body: "剂量：${medicine.dosage ?? '按医嘱'} | 注意：${medicine.note ?? '按时吃药'}",
          hour: reminder.hour,
          minute: reminder.minute,
        );
      }
    }
  }

  Future<void> _removeLegacySeedData() async {
    final demoMedicine = await isar.medicines
        .filter()
        .nameEqualTo('阿莫西林胶囊')
        .dosageEqualTo('2粒')
        .frequencyEqualTo('3')
        .noteEqualTo('饭后吃，忌酒')
        .findFirst();

    if (demoMedicine == null) return;

    await demoMedicine.reminders.load();
    final reminderTimes = demoMedicine.reminders
        .map((reminder) => '${reminder.hour}:${reminder.minute}')
        .toList()
      ..sort();

    if (reminderTimes.join(',') != '12:30,18:30,8:30') return;

    final reminderIds = demoMedicine.reminders.map((reminder) => reminder.id).toList();
    await isar.writeTxn(() async {
      await isar.medicines.delete(demoMedicine.id);
      await isar.reminders.deleteAll(reminderIds);
    });
  }

  Future<void> _ensureDemoMedicines() async {
    const demoItems = [
      DemoMedication(
        name: '维生素D滴剂',
        dosage: '1粒',
        frequency: '1',
        note: '早餐后服用',
        hour: 8,
        minute: 30,
      ),
      DemoMedication(
        name: '鱼油软胶囊',
        dosage: '2粒',
        frequency: '1',
        note: '午餐后服用',
        hour: 12,
        minute: 30,
      ),
      DemoMedication(
        name: '钙片',
        dosage: '1片',
        frequency: '1',
        note: '晚餐后服用',
        hour: 19,
        minute: 30,
      ),
    ];

    for (final item in demoItems) {
      final existing = await isar.medicines
          .filter()
          .nameEqualTo(item.name)
          .noteEqualTo(item.note)
          .findFirst();
      if (existing != null) continue;

      final medicine = Medicine()
        ..name = item.name
        ..dosage = item.dosage
        ..frequency = item.frequency
        ..instruction = '演示数据'
        ..note = item.note;

      final reminder = Reminder()
        ..hour = item.hour
        ..minute = item.minute;

      await isar.writeTxn(() async {
        await isar.medicines.put(medicine);
        await isar.reminders.put(reminder);
        medicine.reminders.add(reminder);
        await medicine.reminders.save();
      });
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
    await medicine.reminders.load();
    final oldReminderIds = medicine.reminders.map((reminder) => reminder.id).toList();

    for (final reminderId in oldReminderIds) {
      await _notifService.cancelReminder(reminderId);
    }

    final remindersToSchedule = <Reminder>[];
    await isar.writeTxn(() async {
      medicine
        ..name = name
        ..dosage = dosage
        ..frequency = times.length.toString()
        ..instruction = medicine.instruction ?? '手动输入'
        ..note = note;

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
    await medicine.reminders.load();
    final reminderIds = medicine.reminders.map((reminder) => reminder.id).toList();
    for (final reminderId in reminderIds) {
      await _notifService.cancelReminder(reminderId);
    }

    await isar.writeTxn(() async {
      await isar.medicines.delete(medicine.id);
      await isar.reminders.deleteAll(reminderIds);
      final relatedLogs = await isar.intakeLogs
          .filter()
          .medicineNameEqualTo(medicine.name)
          .findAll();
      await isar.intakeLogs.deleteAll(relatedLogs.map((log) => log.id).toList());
    });
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
