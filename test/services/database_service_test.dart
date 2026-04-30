import 'package:flutter_test/flutter_test.dart';
import 'package:yao_ji_qing/services/database_service.dart';
import 'package:yao_ji_qing/models/medicine.dart';

void main() {
  group('DatabaseService Logic Tests', () {
    test('TodayMedicationTask timeLabel format', () {
      final task = TodayMedicationTask(
        medicine: Medicine()..name = 'Test Pill',
        reminder: Reminder()..hour = 9..minute = 5,
        planTime: DateTime(2026, 4, 30, 9, 5),
        isTaken: false,
      );

      expect(task.timeLabel, '09:05');
    });

    test('TodayMedicationTask timeLabel format double digits', () {
      final task = TodayMedicationTask(
        medicine: Medicine()..name = 'Test Pill',
        reminder: Reminder()..hour = 14..minute = 30,
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
  });
}
