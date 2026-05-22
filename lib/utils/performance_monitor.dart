import 'package:flutter/foundation.dart';

class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  bool _isMonitoring = false;
  final Map<String, Stopwatch> _stopwatches = {};

  void startMonitoring() {
    _isMonitoring = true;
  }

  void stopMonitoring() {
    _isMonitoring = false;
    _stopwatches.clear();
  }

  String startTiming(String operation) {
    if (!_isMonitoring) return '';
    final id = '${operation}_${DateTime.now().millisecondsSinceEpoch}';
    final stopwatch = Stopwatch()..start();
    _stopwatches[id] = stopwatch;
    return id;
  }

  void endTiming(String id) {
    if (!_isMonitoring) return;
    final stopwatch = _stopwatches.remove(id);
    if (stopwatch != null) {
      stopwatch.stop();
      debugPrint('⏱️ [Performance] $id took ${stopwatch.elapsedMilliseconds}ms');
    }
  }

  T measure<T>(String operationName, T Function() operation) {
    if (!_isMonitoring) return operation();
    
    final id = startTiming(operationName);
    final result = operation();
    endTiming(id);
    return result;
  }
  
  Future<T> measureAsync<T>(String operationName, Future<T> Function() operation) async {
    if (!_isMonitoring) return await operation();
    
    final id = startTiming(operationName);
    final result = await operation();
    endTiming(id);
    return result;
  }
}
