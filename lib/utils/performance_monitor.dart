import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'cache_manager.dart';

/// 性能监控工具
class PerformanceMonitor {
  PerformanceMonitor._internal();

  static final PerformanceMonitor _instance = PerformanceMonitor._internal();

  factory PerformanceMonitor() => _instance;

  // 性能指标
  final Map<String, _PerformanceMetric> _metrics = {};
  final List<_PerformanceEvent> _events = [];

  // 监控配置
  static const int _maxEvents = 1000;
  static const Duration _metricUpdateInterval = Duration(seconds: 1);

  Timer? _updateTimer;
  bool _isMonitoring = false;

  bool get isMonitoring => _isMonitoring;

  /// 开始监控
  void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _updateTimer = Timer.periodic(_metricUpdateInterval, (_) {
      _updateMetrics();
    });

    if (kDebugMode) {
      debugPrint('🚀 [Performance] 监控已启动');
    }
  }

  /// 停止监控
  void stopMonitoring() {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    _updateTimer?.cancel();
    _updateTimer = null;

    if (kDebugMode) {
      debugPrint('⏸️ [Performance] 监控已停止');
    }
  }

  /// 记录事件
  void recordEvent(String name, {Map<String, dynamic>? data}) {
    final event = _PerformanceEvent(
      name: name,
      timestamp: DateTime.now(),
      data: data,
    );

    _events.add(event);

    // 限制事件数量
    if (_events.length > _maxEvents) {
      _events.removeAt(0);
    }

    if (kDebugMode) {
      debugPrint('📝 [Performance] 事件记录: $name');
    }
  }

  /// 开始计时
  String startTiming(String operation) {
    final timingId = '${operation}_${DateTime.now().millisecondsSinceEpoch}';
    _metrics[timingId] = _PerformanceMetric(
      name: operation,
      startTime: DateTime.now(),
    );

    if (kDebugMode) {
      debugPrint('⏱️ [Performance] 开始计时: $operation');
    }

    return timingId;
  }

  /// 结束计时
  void endTiming(String timingId) {
    final metric = _metrics[timingId];
    if (metric == null) return;

    final duration = DateTime.now().difference(metric.startTime);
    _metrics[timingId] = metric.copyWith(
      endTime: DateTime.now(),
      duration: duration,
    );

    if (kDebugMode) {
      debugPrint(
          '⏱️ [Performance] 结束计时: ${metric.name} (${duration.inMilliseconds}ms)');
    }
  }

  /// 测量函数执行时间
  T measure<T>(String operation, T Function() function) {
    final timingId = startTiming(operation);
    try {
      final result = function();
      endTiming(timingId);
      return result;
    } catch (e) {
      endTiming(timingId);
      rethrow;
    }
  }

  /// 异步测量函数执行时间
  Future<T> measureAsync<T>(
      String operation, Future<T> Function() function) async {
    final timingId = startTiming(operation);
    try {
      final result = await function();
      endTiming(timingId);
      return result;
    } catch (e) {
      endTiming(timingId);
      rethrow;
    }
  }

  /// 获取性能统计
  Map<String, dynamic> getPerformanceStats() {
    final completedMetrics =
        _metrics.values.where((m) => m.duration != null).toList();

    if (completedMetrics.isEmpty) {
      return {
        'isMonitoring': _isMonitoring,
        'totalEvents': _events.length,
        'totalMetrics': _metrics.length,
        'completedMetrics': 0,
      };
    }

    final durations =
        completedMetrics.map((m) => m.duration!.inMilliseconds).toList();
    durations.sort();

    return {
      'isMonitoring': _isMonitoring,
      'totalEvents': _events.length,
      'totalMetrics': _metrics.length,
      'completedMetrics': completedMetrics.length,
      'avgDuration': durations.reduce((a, b) => a + b) / durations.length,
      'minDuration': durations.first,
      'maxDuration': durations.last,
      'medianDuration': durations[durations.length ~/ 2],
    };
  }

  /// 获取内存使用情况
  Future<Map<String, dynamic>> getMemoryUsage() async {
    try {
      // 这里可以集成 platform-specific 的内存监控
      // 目前返回基本信息
      return {
        'cacheSize': CacheManager().getFormattedCacheSize(),
        'metricsCount': _metrics.length,
        'eventsCount': _events.length,
      };
    } catch (e) {
      debugPrint('获取内存使用情况失败: $e');
      return {};
    }
  }

  /// 获取最近的性能事件
  List<Map<String, dynamic>> getRecentEvents({int limit = 10}) {
    return _events
        .take(limit)
        .map((e) => {
              'name': e.name,
              'timestamp': e.timestamp.toIso8601String(),
              'data': e.data,
            })
        .toList();
  }

  /// 获取操作性能统计
  Map<String, dynamic> getOperationStats(String operation) {
    final operationMetrics = _metrics.values
        .where((m) => m.name == operation && m.duration != null)
        .toList();

    if (operationMetrics.isEmpty) {
      return {'operation': operation, 'count': 0};
    }

    final durations =
        operationMetrics.map((m) => m.duration!.inMilliseconds).toList();
    durations.sort();

    return {
      'operation': operation,
      'count': operationMetrics.length,
      'avgDuration': durations.reduce((a, b) => a + b) / durations.length,
      'minDuration': durations.first,
      'maxDuration': durations.last,
      'medianDuration': durations[durations.length ~/ 2],
    };
  }

  /// 清除所有指标
  void clearMetrics() {
    _metrics.clear();
    _events.clear();

    if (kDebugMode) {
      debugPrint('🗑️ [Performance] 性能指标已清除');
    }
  }

  /// 导出性能报告
  Map<String, dynamic> exportReport() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'stats': getPerformanceStats(),
      'recentEvents': getRecentEvents(limit: 50),
      'memoryUsage': getMemoryUsage(),
    };
  }

  /// 更新指标
  void _updateMetrics() {
    // 定期更新指标，可以添加更多系统级别的监控
    if (kDebugMode) {
      final stats = getPerformanceStats();
      if (stats['completedMetrics'] > 0) {
        debugPrint(
            '📊 [Performance] 平均执行时间: ${stats['avgDuration']?.toStringAsFixed(2)}ms');
      }
    }
  }

  /// 显示性能监控面板（仅调试模式）
  void showPerformancePanel(BuildContext context) {
    if (!kDebugMode) return;

    showDialog(
      context: context,
      builder: (context) => _PerformanceMonitorDialog(this),
    );
  }
}

/// 性能指标
class _PerformanceMetric {
  _PerformanceMetric({
    required this.name,
    required this.startTime,
    this.endTime,
    this.duration,
  });

  final String name;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration? duration;

  _PerformanceMetric copyWith({
    DateTime? endTime,
    Duration? duration,
  }) {
    return _PerformanceMetric(
      name: name,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
    );
  }
}

/// 性能事件
class _PerformanceEvent {
  _PerformanceEvent({
    required this.name,
    required this.timestamp,
    this.data,
  });

  final String name;
  final DateTime timestamp;
  final Map<String, dynamic>? data;
}

/// 性能监控对话框
class _PerformanceMonitorDialog extends StatefulWidget {
  final PerformanceMonitor monitor;

  const _PerformanceMonitorDialog(this.monitor);

  @override
  State<_PerformanceMonitorDialog> createState() =>
      _PerformanceMonitorDialogState();
}

class _PerformanceMonitorDialogState extends State<_PerformanceMonitorDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('性能监控'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          children: [
            _buildStatSection('总体统计', widget.monitor.getPerformanceStats()),
            const SizedBox(height: 16),
            _buildEventSection(
                '最近事件', widget.monitor.getRecentEvents(limit: 5)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.monitor.clearMetrics();
            setState(() {});
          },
          child: const Text('清除指标'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _buildStatSection(String title, Map<String, dynamic> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...stats.entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key),
                  Text(e.value.toString()),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildEventSection(String title, List<Map<String, dynamic>> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (events.isEmpty)
          const Text('无事件')
        else
          ...events.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('${e['name']} - ${e['timestamp']}'),
              )),
      ],
    );
  }
}
