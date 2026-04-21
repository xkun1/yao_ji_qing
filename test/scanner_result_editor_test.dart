import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yao_ji_qing/services/gemini_service.dart';
import 'package:yao_ji_qing/widgets/scanner_result_editor.dart';

void main() {
  testWidgets('scanner result editor allows editing recognition result before save', (
    WidgetTester tester,
  ) async {
    final original = MedicationInfo(
      name: '阿莫西林',
      dosage: '1片',
      frequency: 3,
      times: ['08:00', '14:00', '20:00'],
      precautions: '饭后服用',
    );

    MedicationInfo? saved;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScannerResultEditor(
            result: original,
            onSave: (value) => saved = value,
          ),
        ),
      ),
    );

    expect(find.widgetWithText(TextFormField, '阿莫西林'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '1片'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '08:00, 14:00, 20:00'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '饭后服用'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('scanner_name_field')), '布洛芬');
    await tester.enterText(find.byKey(const Key('scanner_dosage_field')), '2片');
    await tester.enterText(find.byKey(const Key('scanner_frequency_field')), '2');
    await tester.enterText(find.byKey(const Key('scanner_times_field')), '09:00,21:00');
    await tester.enterText(find.byKey(const Key('scanner_precautions_field')), '餐后服用');

    await tester.ensureVisible(find.byKey(const Key('scanner_save_button')));
    await tester.tap(find.byKey(const Key('scanner_save_button')));
    await tester.pump();

    expect(saved, isNotNull);
    expect(saved!.name, '布洛芬');
    expect(saved!.dosage, '2片');
    expect(saved!.frequency, 2);
    expect(saved!.times, ['09:00', '21:00']);
    expect(saved!.precautions, '餐后服用');
  });
}
