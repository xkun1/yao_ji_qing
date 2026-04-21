import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yao_ji_qing/main.dart';

void main() {
  testWidgets('app shows splash branding on launch',
      (WidgetTester tester) async {
    await tester.pumpWidget(const YaoJiQingApp());

    expect(find.text('药 记 清'), findsOneWidget);
    expect(find.text('准时服药'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 2300));
  });
}
