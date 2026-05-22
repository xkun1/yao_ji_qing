import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/strings.dart';
import '../models/medicine.dart';
import '../services/database_service.dart';

class DailyStat {
  final DateTime date;
  final int taken;
  final int missed;
  final int total;

  const DailyStat({
    required this.date,
    required this.taken,
    required this.missed,
    required this.total,
  });
}

class StatsViewModel extends ChangeNotifier {
  final DatabaseService _dbService;

  StatsViewModel({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isExporting = false;
  bool get isExporting => _isExporting;

  // 7 天统计
  double _complianceRate = 0.0;
  double get complianceRate => _complianceRate;

  int _totalTaken = 0;
  int get totalTaken => _totalTaken;

  Map<String, int> _timeBucketStats = {
    AppStrings.statsMorning: 0,
    AppStrings.statsNoon: 0,
    AppStrings.statsEvening: 0,
    AppStrings.statsNight: 0,
  };
  Map<String, int> get timeBucketStats => _timeBucketStats;

  List<IntakeLog> _recentLogs = [];
  List<IntakeLog> get recentLogs => _recentLogs;

  // 30 天趋势
  List<DailyStat> _dailyStats = [];
  List<DailyStat> get dailyStats => _dailyStats;

  // 漏服分析
  Map<String, int> _missedTimeSlots = {};
  Map<String, int> get missedTimeSlots => _missedTimeSlots;

  int _totalMissed = 0;
  int get totalMissed => _totalMissed;

  Future<void> loadStats() async {
    _isLoading = true;
    notifyListeners();

    try {
      final isar = _dbService.isar;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final sevenDaysAgo = today.subtract(const Duration(days: 7));
      final thirtyDaysAgo = today.subtract(const Duration(days: 30));

      // 近 30 天记录
      final allLogs = await isar.intakeLogs
          .filter()
          .planTimeBetween(thirtyDaysAgo, now)
          .sortByPlanTimeDesc()
          .findAll();

      // 近 7 天记录
      final weekLogs =
          allLogs.where((l) => l.planTime.isAfter(sevenDaysAgo)).toList();

      // 7 天遵从率
      final int takenCount = weekLogs.where((l) => l.isTaken).length;
      final int totalCount = weekLogs.length;
      _totalTaken = takenCount;
      _complianceRate = totalCount == 0 ? 0 : takenCount / totalCount;

      // 分时段统计
      final Map<String, int> buckets = {
        AppStrings.statsMorning: 0,
        AppStrings.statsNoon: 0,
        AppStrings.statsEvening: 0,
        AppStrings.statsNight: 0,
      };
      for (var log in weekLogs.where((l) => l.isTaken)) {
        final hour = log.planTime.hour;
        if (hour >= 5 && hour < 11) {
          buckets[AppStrings.statsMorning] =
              buckets[AppStrings.statsMorning]! + 1;
        } else if (hour >= 11 && hour < 16) {
          buckets[AppStrings.statsNoon] = buckets[AppStrings.statsNoon]! + 1;
        } else if (hour >= 16 && hour < 21) {
          buckets[AppStrings.statsEvening] =
              buckets[AppStrings.statsEvening]! + 1;
        } else {
          buckets[AppStrings.statsNight] = buckets[AppStrings.statsNight]! + 1;
        }
      }
      _timeBucketStats = buckets;

      // 30 天趋势
      final dailyStatsList = <DailyStat>[];
      final missedSlots = <String, int>{};
      var totalMissedCount = 0;

      for (var i = 29; i >= 0; i--) {
        final day = today.subtract(Duration(days: i));
        final dayStart = DateTime(day.year, day.month, day.day);
        final dayEnd = dayStart.add(const Duration(days: 1));

        final dayLogs = allLogs
            .where((l) =>
                !l.planTime.isBefore(dayStart) && l.planTime.isBefore(dayEnd))
            .toList();
        final dayTaken = dayLogs.where((l) => l.isTaken).length;
        final dayMissed = dayLogs.length - dayTaken;
        totalMissedCount += dayMissed;

        // 统计漏服时段
        for (final log in dayLogs.where((l) => !l.isTaken)) {
          final nearestSlot = _nearestTimeSlot(log.planTime.hour);
          final key = '${DateFormat('MM-dd').format(day)} $nearestSlot';
          missedSlots[key] = (missedSlots[key] ?? 0) + 1;
        }

        dailyStatsList.add(DailyStat(
          date: day,
          taken: dayTaken,
          missed: dayMissed,
          total: dayLogs.length,
        ));
      }

      _dailyStats = dailyStatsList;
      _missedTimeSlots = missedSlots;
      _totalMissed = totalMissedCount;
      _recentLogs = weekLogs.take(15).toList();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _nearestTimeSlot(int hour) {
    const slots = {'早': 8, '午': 12, '晚': 18, '夜': 20};
    var nearest = '早';
    var minDiff = 24;
    for (final entry in slots.entries) {
      final diff = (hour - entry.value).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearest = entry.key;
      }
    }
    return nearest;
  }

  Future<void> exportCsv(Rect? sharePositionOrigin) async {
    if (_isExporting) return;

    _isExporting = true;
    notifyListeners();

    try {
      final buffer = StringBuffer();
      buffer.writeln('日期,药品名称,计划时间,实际时间,状态');
      for (final log in _recentLogs) {
        final date = DateFormat('yyyy-MM-dd').format(log.planTime);
        final planTime = DateFormat('HH:mm').format(log.planTime);
        final actualTime = log.actualTime != null
            ? DateFormat('yyyy-MM-dd HH:mm').format(log.actualTime!)
            : '';
        final status = log.isTaken ? '已服' : '漏服';
        buffer
            .writeln('$date,${log.medicineName},$planTime,$actualTime,$status');
      }

      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/药记清_服药记录_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv');
      await file.writeAsString(buffer.toString());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '药记清 - 服药记录导出',
        sharePositionOrigin: sharePositionOrigin,
      );
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }
}
