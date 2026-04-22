import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';
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
  
  // 统计数据
  double _complianceRate = 0.0;
  int _totalPlanned = 0;
  int _totalTaken = 0;
  
  // 按时间段分类的数据
  Map<String, int> _timeBucketStats = {
    "早晨 (05-11)": 0,
    "中午 (11-16)": 0,
    "晚上 (16-21)": 0,
    "深夜 (21-05)": 0,
  };

  List<IntakeLog> _recentLogs = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final isar = _dbService.isar;
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    // 1. 获取近 7 天的所有服药记录
    final logs = await isar.intakeLogs
        .filter()
        .planTimeBetween(sevenDaysAgo, now)
        .sortByPlanTimeDesc()
        .findAll();

    // 2. 计算服药遵从率
    // 注意：这里的 totalPlanned 我们暂时根据 logs 数量推算，或者从 Reminder 逻辑推导
    // 为简单直观，我们统计近 7 天“已标记服用”的数量与“总记录”的比例
    int takenCount = logs.where((l) => l.isTaken).length;
    int totalCount = logs.length;

    // 3. 按时间段分类
    Map<String, int> buckets = {"早晨 (05-11)": 0, "中午 (11-16)": 0, "晚上 (16-21)": 0, "深夜 (21-05)": 0};
    for (var log in logs.where((l) => l.isTaken)) {
      int hour = log.planTime.hour;
      if (hour >= 5 && hour < 11) {
        buckets["早晨 (05-11)"] = buckets["早晨 (05-11)"]! + 1;
      } else if (hour >= 11 && hour < 16) {
        buckets["中午 (11-16)"] = buckets["中午 (11-16)"]! + 1;
      } else if (hour >= 16 && hour < 21) {
        buckets["晚上 (16-21)"] = buckets["晚上 (16-21)"]! + 1;
      } else {
        buckets["深夜 (21-05)"] = buckets["深夜 (21-05)"]! + 1;
      }
    }

    if (mounted) {
      setState(() {
        _totalPlanned = totalCount;
        _totalTaken = takenCount;
        _complianceRate = totalCount == 0 ? 0 : takenCount / totalCount;
        _timeBucketStats = buckets;
        _recentLogs = logs.take(15).toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text("健康统计"),
        backgroundColor: Colors.white,
        elevation: 0,
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
                  _buildTimeDistributionCard(),
                  const SizedBox(height: 24),
                  _buildRecentHistoryHeader(),
                  const SizedBox(height: 12),
                  _buildHistoryList(),
                  const SizedBox(height: 100), // 底部占位
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("服药遵从率", style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                const SizedBox(height: 4),
                Text("近 7 天共坚持服药 $_totalTaken 次", 
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                Text("保持这种节奏，坤哥棒棒哒！✨", style: TextStyle(color: const Color(0xFF10B981), fontSize: 12)),
              ],
            ),
          )
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
          const Text("分时段统计", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ..._timeBucketStats.entries.map((e) {
            double percent = _totalTaken == 0 ? 0 : e.value / _totalTaken;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                      Text("${e.value}次", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
    return const Text("近期服用记录", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
  }

  Widget _buildHistoryList() {
    if (_recentLogs.isEmpty) {
      return const Center(child: Text("暂无服用记录", style: TextStyle(color: Color(0xFF9CA3AF))));
    }
    return Column(
      children: _recentLogs.map((log) {
        String dateStr = DateFormat('MM-dd').format(log.planTime);
        String timeStr = DateFormat('HH:mm').format(log.planTime);
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
                decoration: BoxDecoration(color: const Color(0xFFF0FDF4), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 18),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log.medicineName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text("计划时间: $dateStr $timeStr", style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
              if (log.actualTime != null)
                Text("已服", style: const TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
