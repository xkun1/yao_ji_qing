import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/medicine.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class HomeViewModel extends ChangeNotifier {
  final DatabaseService _dbService;
  final NotificationService _notifService;

  static const List<String> _quotes = [
    "药到病除，心宽体健。☀️",
    "规律服药，是康复的基石。💪",
    "身体是革命的本钱，按时吃药哦。🌱",
    "但愿世间人无病，哪怕架上药生尘。✨",
    "早睡早起，适度运动，记得吃药。🏃‍♂️",
    "健康不是一切，但没有健康就没有一切。⚖️",
    "养生之道，莫先于食，莫急于药。🥣",
    "按时服药，爱惜自己，就是给家人最好的礼物。🧡",
    "每一粒药都是健康的种子，请按时播种。🌾",
    "心态平和，药效翻倍。🧘‍♂️",
  ];

  late String currentQuote;
  List<TodayMedicationTask> tasks = [];
  TodayMedicationTask? guideTask;
  final Set<String> markingTaskKeys = {};
  final Set<String> optimisticTakenTaskKeys = {};
  bool isGuiding = false;
  bool isLoading = true;
  int currentIndex = 0;

  HomeViewModel({DatabaseService? dbService, NotificationService? notifService}) 
      : _dbService = dbService ?? DatabaseService(),
        _notifService = notifService ?? NotificationService() {
    currentQuote = _quotes[math.Random().nextInt(_quotes.length)];
  }

  Future<void> initData() async {
    await _dbService.init();
    await loadTodayTasks();
  }

  void setCurrentIndex(int index) {
    currentIndex = index;
    notifyListeners();
  }

  void startGuide() {
    isGuiding = true;
    guideTask = TodayMedicationTask(
      medicine: Medicine()
        ..name = "示例药品"
        ..dosage = "1粒",
      reminder: Reminder()
        ..hour = 12
        ..minute = 0,
      planTime: DateTime.now().copyWith(hour: 12, minute: 0),
      isTaken: false,
    );
    notifyListeners();
  }

  void endGuide() {
    isGuiding = false;
    guideTask = null;
    loadTodayTasks();
  }

  Future<void> loadTodayTasks() async {
    final fetchedTasks = await _dbService.getTodayMedicationTasks();
    final mergedTasks = fetchedTasks
        .map((task) => optimisticTakenTaskKeys.contains(task.occurrenceKey)
            ? task.copyWith(isTaken: true)
            : task)
        .toList();
    
    tasks = mergedTasks;
    if (isGuiding && guideTask != null) {
      tasks = [guideTask!, ...mergedTasks];
    }
    isLoading = false;
    notifyListeners();

    final hasPending = mergedTasks.any((t) => !t.isTaken);
    if (fetchedTasks.isEmpty || !hasPending) {
      await _notifService.stopForegroundService();
    } else {
      await _notifService.startForegroundService();
      final nextTask = mergedTasks.firstWhere((t) => !t.isTaken);
      await _notifService.updateForegroundService(
        title: "下一顿用药提醒",
        body: "${nextTask.medicine.name} ${nextTask.medicine.dosage ?? ''} (${nextTask.timeLabel})",
      );
    }
  }

  int get totalTaskCount => tasks.length;
  int get takenTaskCount => tasks.where((task) => task.isTaken).length;
  double get progressValue => totalTaskCount == 0 ? 0 : takenTaskCount / totalTaskCount;
  bool get isTodayCompleted => totalTaskCount > 0 && takenTaskCount == totalTaskCount;

  TodayMedicationTask? get nextTask {
    for (final task in tasks) {
      if (!task.isTaken) return task;
    }
    return null;
  }

  Future<void> deleteMedication(TodayMedicationTask task) async {
    if (isGuiding) return;
    
    final deleteId = task.medicine.id;
    tasks.removeWhere((t) => t.medicine.id == deleteId);
    if (guideTask?.medicine.id == deleteId) {
      guideTask = null;
    }
    notifyListeners();

    try {
      await _dbService.deleteMedication(task.medicine);
    } catch (e) {
      debugPrint('删除药品失败: $e');
    }

    await Future.delayed(const Duration(milliseconds: 50));
    await loadTodayTasks();
  }

  Future<void> markTaskTaken(TodayMedicationTask task, VoidCallback onCompleted) async {
    if (isGuiding || task.isTaken) return;

    final taskKey = task.occurrenceKey;
    if (markingTaskKeys.contains(taskKey)) return;

    final pendingCount = tasks.where((t) => !t.isTaken).length;
    markingTaskKeys.add(taskKey);
    optimisticTakenTaskKeys.add(taskKey);

    tasks = tasks.map((t) => t.occurrenceKey == taskKey ? t.copyWith(isTaken: true) : t).toList();
    notifyListeners();

    try {
      await _dbService.markTaskTaken(task);
      if (pendingCount == 1) {
        onCompleted();
      }

      await Future.delayed(const Duration(milliseconds: 50));
      await loadTodayTasks();
    } catch (e) {
      debugPrint('标记服药失败: $e');
      optimisticTakenTaskKeys.remove(taskKey);
      await loadTodayTasks();
    } finally {
      markingTaskKeys.remove(taskKey);
    }
  }
}
