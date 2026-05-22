import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yao_ji_qing/models/medicine.dart';
import 'package:yao_ji_qing/services/database_service.dart';
import 'package:yao_ji_qing/services/notification_service.dart';
import 'package:yao_ji_qing/viewmodels/home_viewmodel.dart';

class MockDatabaseService extends Mock implements DatabaseService {}
class MockNotificationService extends Mock implements NotificationService {}

void main() {
  late HomeViewModel viewModel;
  late MockDatabaseService mockDbService;
  late MockNotificationService mockNotifService;

  setUpAll(() {
    registerFallbackValue(Medicine());
    registerFallbackValue(TodayMedicationTask(
      medicine: Medicine(),
      reminder: Reminder(),
      planTime: DateTime.now(),
      isTaken: false,
    ));
  });

  setUp(() {
    mockDbService = MockDatabaseService();
    mockNotifService = MockNotificationService();

    when(() => mockDbService.init()).thenAnswer((_) async {});
    when(() => mockNotifService.stopForegroundService()).thenAnswer((_) async {});
    when(() => mockNotifService.startForegroundService()).thenAnswer((_) async {});
    when(() => mockNotifService.updateForegroundService(
        title: any(named: 'title'), body: any(named: 'body'))).thenAnswer((_) async {});

    viewModel = HomeViewModel(
      dbService: mockDbService,
      notifService: mockNotifService,
    );
  });

  test('初始状态下任务列表为空，isLoading 为 true', () {
    expect(viewModel.tasks.isEmpty, true);
    expect(viewModel.isLoading, true);
  });

  test('loadTodayTasks 获取数据后更新状态', () async {
    final task1 = TodayMedicationTask(
      medicine: Medicine()..name = '阿司匹林',
      reminder: Reminder()..id = 1..hour = 8..minute = 0,
      planTime: DateTime.now(),
      isTaken: false,
    );

    when(() => mockDbService.getTodayMedicationTasks()).thenAnswer((_) async => [task1]);

    await viewModel.loadTodayTasks();

    expect(viewModel.tasks.length, 1);
    expect(viewModel.tasks.first.medicine.name, '阿司匹林');
    expect(viewModel.isLoading, false);
    expect(viewModel.progressValue, 0.0);
  });

  test('markTaskTaken 正确更新状态并调用数据库', () async {
    final task = TodayMedicationTask(
      medicine: Medicine()..name = '阿司匹林',
      reminder: Reminder()..id = 1..hour = 8..minute = 0,
      planTime: DateTime.now(),
      isTaken: false,
    );

    when(() => mockDbService.getTodayMedicationTasks()).thenAnswer((_) async => [task]);
    when(() => mockDbService.markTaskTaken(any())).thenAnswer((_) async {});

    await viewModel.loadTodayTasks();
    expect(viewModel.takenTaskCount, 0);

    bool callbackCalled = false;
    await viewModel.markTaskTaken(viewModel.tasks.first, () {
      callbackCalled = true;
    });

    // 这里有个延迟 Future.delayed(50ms) 在代码中
    await Future.delayed(const Duration(milliseconds: 100));

    verify(() => mockDbService.markTaskTaken(any())).called(1);
    // 因为乐观更新，会变成 taken
    expect(viewModel.takenTaskCount, 1);
    expect(callbackCalled, true);
  });
}
