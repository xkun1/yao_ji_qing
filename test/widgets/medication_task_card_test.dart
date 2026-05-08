import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yao_ji_qing/models/medicine.dart';
import 'package:yao_ji_qing/services/database_service.dart';
import 'package:yao_ji_qing/widgets/medication_task_card.dart';

void main() {
  group('MedicationTaskCard', () {
    late TodayMedicationTask testTask;

    setUp(() {
      testTask = TodayMedicationTask(
        medicine: Medicine()
          ..name = '阿莫西林'
          ..dosage = '2粒',
        reminder: Reminder()
          ..hour = 8
          ..minute = 30,
        planTime: DateTime(2026, 5, 8, 8, 30),
        isTaken: false,
      );
    });

    testWidgets('显示药品名称和剂量', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicationTaskCard(
              task: testTask,
              onMarkTaken: () {},
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.text('阿莫西林'), findsOneWidget);
      expect(find.text('2粒'), findsOneWidget);
    });

    testWidgets('显示提醒时间', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicationTaskCard(
              task: testTask,
              onMarkTaken: () {},
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.text('08:30'), findsOneWidget);
    });

    testWidgets('已服用时显示"已服用"标签', (WidgetTester tester) async {
      final takenTask = TodayMedicationTask(
        medicine: Medicine()
          ..name = '阿莫西林'
          ..dosage = '2粒',
        reminder: Reminder()
          ..hour = 8
          ..minute = 30,
        planTime: DateTime(2026, 5, 8, 8, 30),
        isTaken: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicationTaskCard(
              task: takenTask,
              onMarkTaken: () {},
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.text('已服用'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('调用编辑和删除回调', (WidgetTester tester) async {
      bool editCalled = false;
      bool deleteCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicationTaskCard(
              task: testTask,
              onMarkTaken: () {},
              onEdit: () => editCalled = true,
              onDelete: () => deleteCalled = true,
            ),
          ),
        ),
      );

      final editButton = find.byIcon(Icons.edit_note_rounded);
      final deleteButton = find.byIcon(Icons.delete_outline_rounded);

      expect(editButton, findsOneWidget);
      expect(deleteButton, findsOneWidget);

      await tester.tap(editButton);
      expect(editCalled, isTrue);

      await tester.tap(deleteButton);
      expect(deleteCalled, isTrue);
    });

    testWidgets('已服用时点击卡片不触发 onMarkTaken', (WidgetTester tester) async {
      bool markTakenCalled = false;
      final takenTask = TodayMedicationTask(
        medicine: Medicine()
          ..name = '阿莫西林'
          ..dosage = '2粒',
        reminder: Reminder()
          ..hour = 8
          ..minute = 30,
        planTime: DateTime(2026, 5, 8, 8, 30),
        isTaken: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicationTaskCard(
              task: takenTask,
              onMarkTaken: () => markTakenCalled = true,
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      // 点击卡片内容区域
      await tester.tap(find.text('阿莫西林'));
      expect(markTakenCalled, isFalse);
    });
  });
}
