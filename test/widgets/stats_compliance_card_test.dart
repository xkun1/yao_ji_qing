import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:yao_ji_qing/viewmodels/stats_viewmodel.dart';
import 'package:yao_ji_qing/widgets/stats/compliance_card.dart';

class MockStatsViewModel extends Mock implements StatsViewModel {}

void main() {
  late MockStatsViewModel mockViewModel;

  setUp(() {
    mockViewModel = MockStatsViewModel();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<StatsViewModel>.value(
          value: mockViewModel,
          child: const ComplianceCard(),
        ),
      ),
    );
  }

  testWidgets('ComplianceCard 显示正确的遵从率和次数', (WidgetTester tester) async {
    when(() => mockViewModel.complianceRate).thenReturn(0.85);
    when(() => mockViewModel.totalTaken).thenReturn(12);

    await tester.pumpWidget(createWidgetUnderTest());

    // 验证显示文本
    expect(find.text('7 天服药遵从率'), findsOneWidget);
    expect(find.text('85%'), findsOneWidget);
    expect(find.text('近 7 天共坚持服药 12 次'), findsOneWidget);
    
    // 验证圆环进度条是否按正确比例渲染
    final progressFinder = find.byType(CircularProgressIndicator);
    expect(progressFinder, findsOneWidget);
    final CircularProgressIndicator indicator = tester.widget(progressFinder);
    expect(indicator.value, 0.85);
  });

  testWidgets('ComplianceCard 边界测试: 0% 遵从率', (WidgetTester tester) async {
    when(() => mockViewModel.complianceRate).thenReturn(0.0);
    when(() => mockViewModel.totalTaken).thenReturn(0);

    await tester.pumpWidget(createWidgetUnderTest());

    expect(find.text('0%'), findsOneWidget);
    expect(find.text('近 7 天共坚持服药 0 次'), findsOneWidget);
    
    final progressFinder = find.byType(CircularProgressIndicator);
    final CircularProgressIndicator indicator = tester.widget(progressFinder);
    expect(indicator.value, 0.0);
  });
}
