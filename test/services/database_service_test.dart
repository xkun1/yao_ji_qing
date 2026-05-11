import 'package:flutter_test/flutter_test.dart';
import 'package:yao_ji_qing/services/database_service.dart';
import 'package:yao_ji_qing/models/medicine.dart';

void main() {
  group('DatabaseService Logic Tests', () {
    test('TodayMedicationTask timeLabel format', () {
      final task = TodayMedicationTask(
        medicine: Medicine()..name = 'Test Pill',
        reminder: Reminder()
          ..hour = 9
          ..minute = 5,
        planTime: DateTime(2026, 4, 30, 9, 5),
        isTaken: false,
      );

      expect(task.timeLabel, '09:05');
    });

    test('TodayMedicationTask timeLabel format double digits', () {
      final task = TodayMedicationTask(
        medicine: Medicine()..name = 'Test Pill',
        reminder: Reminder()
          ..hour = 14
          ..minute = 30,
        planTime: DateTime(2026, 4, 30, 14, 30),
        isTaken: true,
      );

      expect(task.timeLabel, '14:30');
    });

    test('ReminderTime basic', () {
      const time = ReminderTime(8, 0);
      expect(time.hour, 8);
      expect(time.minute, 0);
    });

    test('TodayMedicationTask occurrenceKey 稳定且 copyWith 仅更新服药状态', () {
      final medicine = Medicine()
        ..id = 101
        ..name = 'Test Pill';
      final reminder = Reminder()
        ..id = 202
        ..hour = 9
        ..minute = 5;
      final planTime = DateTime(2026, 4, 30, 9, 5);
      final task = TodayMedicationTask(
        medicine: medicine,
        reminder: reminder,
        planTime: planTime,
        isTaken: false,
      );

      final updated = task.copyWith(isTaken: true);

      expect(task.occurrenceKey, '101_202_${planTime.millisecondsSinceEpoch}');
      expect(updated.occurrenceKey, task.occurrenceKey);
      expect(updated.isTaken, isTrue);
      expect(task.isTaken, isFalse);
      expect(identical(updated.medicine, medicine), isTrue);
      expect(identical(updated.reminder, reminder), isTrue);
    });
  });
}
