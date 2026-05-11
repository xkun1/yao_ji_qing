import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/strings.dart';
import '../models/medicine.dart';
import '../services/database_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = true;
  bool _isExporting = false;

  // 7 天统计
  double _complianceRate = 0.0;
  int _totalTaken = 0;

  Map<String, int> _timeBucketStats = {
    AppStrings.statsMorning: 0,
    AppStrings.statsNoon: 0,
    AppStrings.statsEvening: 0,
    AppStrings.statsNight: 0,
  };

  List<IntakeLog> _recentLogs = [];

  // 30 天趋势
  List<_DailyStat> _dailyStats = [];

  // 漏服分析
  Map<String, int> _missedTimeSlots = {};
  int _totalMissed = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
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

    // 30 天趋势
    final dailyStats = <_DailyStat>[];
    final missedSlots = <String, int>{};
    var totalMissed = 0;

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
      totalMissed += dayMissed;

      // 统计漏服时段
      for (final log in dayLogs.where((l) => !l.isTaken)) {
        final nearestSlot = _nearestTimeSlot(log.planTime.hour);
        final key = '${DateFormat('MM-dd').format(day)} $nearestSlot';
        missedSlots[key] = (missedSlots[key] ?? 0) + 1;
      }

      dailyStats.add(_DailyStat(
        date: day,
        taken: dayTaken,
        missed: dayMissed,
        total: dayLogs.length,
      ));
    }

    if (mounted) {
      setState(() {
        _totalTaken = takenCount;
        _complianceRate = totalCount == 0 ? 0 : takenCount / totalCount;
        _timeBucketStats = buckets;
        _recentLogs = weekLogs.take(15).toList();
        _dailyStats = dailyStats;
        _missedTimeSlots = missedSlots;
        _totalMissed = totalMissed;
        _isLoading = false;
      });
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

  Future<void> _exportCsv(BuildContext context) async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
    });

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

      // iOS 设备上使用 share_plus 需要指定 sharePositionOrigin
      final box = context.findRenderObject() as RenderBox?;
      final rect =
          box != null ? box.localToGlobal(Offset.zero) & box.size : null;

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '药记清 - 服药记录导出',
        sharePositionOrigin: rect,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(AppStrings.statsTitle),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Builder(builder: (context) {
                return GestureDetector(
                  onTap: () => _exportCsv(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF3B82F6),
                              ),
                            )
                          : SvgPicture.asset(
                              'assets/icons/share.svg',
                              colorFilter: const ColorFilter.mode(
                                  Color(0xFF3B82F6), BlendMode.srcIn),
                              width: 22,
                              height: 22,
                            ),
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildComplianceCard(),
                  const SizedBox(height: 24),
                  _buildTrendChart(),
                  const SizedBox(height: 24),
                  _buildTimeDistributionCard(),
                  const SizedBox(height: 24),
                  _buildMissedAnalysisCard(),
                  const SizedBox(height: 24),
                  _buildRecentHistoryHeader(),
                  const SizedBox(height: 12),
                  _buildHistoryList(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  Widget _buildComplianceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: CircularProgressIndicator(
                  value: _complianceRate,
                  strokeWidth: 8,
                  backgroundColor: const Color(0xFFF3F4F6),
                  color: const Color(0xFF10B981),
                ),
              ),
              Text("${(_complianceRate * 100).round()}%",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("7 天服药遵从率",
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                const SizedBox(height: 4),
                Text("近 7 天共坚持服药 $_totalTaken 次",
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937))),
                const Text("保持这种节奏，坤哥棒棒哒！✨",
                    style: TextStyle(color: Color(0xFF10B981), fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTrendChart() {
    if (_dailyStats.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxVal =
        _dailyStats.fold<int>(0, (m, s) => s.total > m ? s.total : m);
    final displayMax = maxVal < 1 ? 1 : maxVal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("30 天服药趋势",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  _legendDot(const Color(0xFF10B981), '已服'),
                  const SizedBox(width: 12),
                  _legendDot(const Color(0xFFFCA5A5), '漏服'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _dailyStats.length,
              itemBuilder: (context, index) {
                final stat = _dailyStats[index];
                final takenHeight =
                    stat.total == 0 ? 0.0 : (stat.taken / displayMax * 80);
                final missedHeight =
                    stat.total == 0 ? 0.0 : (stat.missed / displayMax * 80);
                final isToday = index == _dailyStats.length - 1;

                return Padding(
                  padding: EdgeInsets.only(
                      right: index < _dailyStats.length - 1 ? 4 : 0),
                  child: SizedBox(
                    width: 16,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (stat.total > 0) ...[
                          if (stat.missed > 0)
                            Container(
                              height: missedHeight + takenHeight,
                              width: 14,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFCA5A5),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              alignment: Alignment.topCenter,
                              child: Container(
                                height: takenHeight,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            )
                          else
                            Container(
                              height: takenHeight,
                              width: 14,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                        ] else
                          Container(
                            height: 2,
                            width: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        const Spacer(),
                        Text(
                          DateFormat('d').format(stat.date),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
      ],
    );
  }

  Widget _buildMissedAnalysisCard() {
    if (_totalMissed == 0) return const SizedBox.shrink();

    final topMissed = _missedTimeSlots.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final displaySlots = topMissed.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 18, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Text("近 30 天共漏服 $_totalMissed 次",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          if (displaySlots.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text("高频漏服时段：",
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: displaySlots.map((e) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${e.key}（${e.value}次）",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFD97706),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeDistributionCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("分时段统计",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ..._timeBucketStats.entries.map((e) {
            final double percent = _totalTaken == 0 ? 0 : e.value / _totalTaken;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF6B7280))),
                      Text("${e.value}次",
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: percent,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                    backgroundColor: const Color(0xFFF3F4F6),
                    color: const Color(0xFF3B82F6),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentHistoryHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("近期服用记录",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Builder(builder: (context) {
          return GestureDetector(
            onTap: () => _exportCsv(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isExporting)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF3B82F6),
                      ),
                    )
                  else
                    SvgPicture.asset(
                      'assets/icons/share.svg',
                      width: 16,
                      height: 16,
                      colorFilter: const ColorFilter.mode(
                          Color(0xFF3B82F6), BlendMode.srcIn),
                    ),
                  const SizedBox(width: 6),
                  Text(_isExporting ? "导出中..." : "导出CSV",
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildHistoryList() {
    if (_recentLogs.isEmpty) {
      return const Center(
          child: Text("暂无服用记录", style: TextStyle(color: Color(0xFF9CA3AF))));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentLogs.length,
      itemBuilder: (context, index) {
        final log = _recentLogs[index];
        final String dateStr = DateFormat('MM-dd').format(log.planTime);
        final String timeStr = DateFormat('HH:mm').format(log.planTime);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: log.isTaken
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  log.isTaken ? Icons.check_rounded : Icons.close_rounded,
                  color: log.isTaken
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                  size: 18,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log.medicineName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text("计划: $dateStr $timeStr",
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
              Text(
                log.isTaken ? "已服" : "漏服",
                style: TextStyle(
                  color: log.isTaken
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DailyStat {
  final DateTime date;
  final int taken;
  final int missed;
  final int total;

  const _DailyStat({
    required this.date,
    required this.taken,
    required this.missed,
    required this.total,
  });
}
