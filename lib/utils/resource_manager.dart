import 'dart:async';

import 'package:flutter/foundation.dart';

/// 资源管理器 - 防止内存泄漏
class ResourceManager {
  ResourceManager._internal();

  static final ResourceManager _instance = ResourceManager._internal();

  factory ResourceManager() => _instance;

  // 资源跟踪
  final Map<String, _ResourceEntry> _resources = {};
  final List<DisposeCallback> _disposeCallbacks = [];

  // 资源统计
  int _totalResources = 0;
  int _disposedResources = 0;

  int get totalResources => _totalResources;
  int get disposedResources => _disposedResources;
  int get activeResources => _totalResources - _disposedResources;

  /// 注册资源
  String registerResource({
    required String type,
    required String name,
    required DisposeCallback disposeCallback,
    Map<String, dynamic>? metadata,
  }) {
    final resourceId =
        '${type}_${name}_${DateTime.now().millisecondsSinceEpoch}';
    _resources[resourceId] = _ResourceEntry(
      type: type,
      name: name,
      disposeCallback: disposeCallback,
      metadata: metadata,
      createdAt: DateTime.now(),
    );
    _totalResources++;

    if (kDebugMode) {
      debugPrint('✅ [Resource] 资源已注册: $type/$name (ID: $resourceId)');
    }

    return resourceId;
  }

  /// 注销资源
  void unregisterResource(String resourceId) {
    final entry = _resources.remove(resourceId);
    if (entry != null) {
      try {
        entry.disposeCallback();
        _disposedResources++;
        if (kDebugMode) {
          debugPrint('🗑️ [Resource] 资源已释放: ${entry.type}/${entry.name}');
        }
      } catch (e) {
        debugPrint('❌ [Resource] 释放资源失败: ${entry.type}/${entry.name} - $e');
      }
    }
  }

  /// 添加释放回调
  void addDisposeCallback(DisposeCallback callback) {
    _disposeCallbacks.add(callback);
  }

  /// 移除释放回调
  void removeDisposeCallback(DisposeCallback callback) {
    _disposeCallbacks.remove(callback);
  }

  /// 释放所有资源
  void disposeAll() {
    // 释放所有注册的资源
    for (final entry in _resources.values) {
      try {
        entry.disposeCallback();
        _disposedResources++;
        if (kDebugMode) {
          debugPrint('🗑️ [Resource] 资源已释放: ${entry.type}/${entry.name}');
        }
      } catch (e) {
        debugPrint('❌ [Resource] 释放资源失败: ${entry.type}/${entry.name} - $e');
      }
    }
    _resources.clear();

    // 执行所有释放回调
    for (final callback in _disposeCallbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('❌ [Resource] 执行释放回调失败: $e');
      }
    }
    _disposeCallbacks.clear();

    if (kDebugMode) {
      debugPrint('🧹 [Resource] 所有资源已释放');
    }
  }

  /// 释放指定类型的资源
  void disposeByType(String type) {
    final toRemove = <String>[];
    for (final entry in _resources.entries) {
      if (entry.value.type == type) {
        toRemove.add(entry.key);
      }
    }

    for (final resourceId in toRemove) {
      unregisterResource(resourceId);
    }

    if (kDebugMode) {
      debugPrint('🧹 [Resource] 已释放 $type 类型的资源 (${toRemove.length}个)');
    }
  }

  /// 检查资源泄漏
  void checkLeaks() {
    final now = DateTime.now();
    final leakedResources = <String>[];

    for (final entry in _resources.entries) {
      final age = now.difference(entry.value.createdAt);
      // 超过 10 分钟未释放的资源视为可能泄漏
      if (age.inMinutes > 10) {
        leakedResources.add(
          '${entry.value.type}/${entry.value.name} (存在 ${age.inMinutes} 分钟)',
        );
      }
    }

    if (leakedResources.isNotEmpty && kDebugMode) {
      debugPrint('⚠️ [Resource] 检测到可能泄漏的资源:');
      for (final leak in leakedResources) {
        debugPrint('  - $leak');
      }
    } else if (kDebugMode) {
      debugPrint('✅ [Resource] 未检测到资源泄漏');
    }
  }

  /// 获取资源统计
  Map<String, dynamic> getResourceStats() {
    final typeStats = <String, int>{};
    for (final entry in _resources.values) {
      typeStats[entry.type] = (typeStats[entry.type] ?? 0) + 1;
    }

    return {
      'totalResources': _totalResources,
      'disposedResources': _disposedResources,
      'activeResources': activeResources,
      'typeStats': typeStats,
    };
  }

  /// 清理过期资源
  void cleanupExpiredResources({Duration maxAge = const Duration(hours: 1)}) {
    final now = DateTime.now();
    final toRemove = <String>[];

    for (final entry in _resources.entries) {
      final age = now.difference(entry.value.createdAt);
      if (age > maxAge) {
        toRemove.add(entry.key);
      }
    }

    for (final resourceId in toRemove) {
      unregisterResource(resourceId);
    }

    if (toRemove.isNotEmpty && kDebugMode) {
      debugPrint('🧹 [Resource] 已清理过期资源 (${toRemove.length}个)');
    }
  }
}

/// 资源条目
class _ResourceEntry {
  _ResourceEntry({
    required this.type,
    required this.name,
    required this.disposeCallback,
    this.metadata,
    required this.createdAt,
  });

  final String type;
  final String name;
  final DisposeCallback disposeCallback;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
}

/// 释放回调类型
typedef DisposeCallback = void Function();

/// Stream 订阅管理器
class StreamSubscriptionManager {
  StreamSubscriptionManager._internal();

  static final StreamSubscriptionManager _instance =
      StreamSubscriptionManager._internal();

  factory StreamSubscriptionManager() => _instance;

  final Map<String, StreamSubscription> _subscriptions = {};

  /// 注册订阅
  String registerSubscription(
    String name,
    StreamSubscription subscription, {
    void Function()? onError,
    void Function()? onDone,
    bool cancelOnError = false,
  }) {
    final subscriptionId = '${name}_${DateTime.now().millisecondsSinceEpoch}';

    _subscriptions[subscriptionId] = subscription;

    if (kDebugMode) {
      debugPrint('✅ [Stream] 订阅已注册: $name (ID: $subscriptionId)');
    }

    return subscriptionId;
  }

  /// 取消订阅
  void cancelSubscription(String subscriptionId) {
    final subscription = _subscriptions.remove(subscriptionId);
    if (subscription != null) {
      subscription.cancel();
      if (kDebugMode) {
        debugPrint('🗑️ [Stream] 订阅已取消: $subscriptionId');
      }
    }
  }

  /// 取消所有订阅
  void cancelAll() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();

    if (kDebugMode) {
      debugPrint('🧹 [Stream] 所有订阅已取消');
    }
  }

  /// 取消指定名称的订阅
  void cancelByName(String name) {
    final toRemove = <String>[];
    for (final entry in _subscriptions.entries) {
      if (entry.key.startsWith(name)) {
        toRemove.add(entry.key);
      }
    }

    for (final subscriptionId in toRemove) {
      cancelSubscription(subscriptionId);
    }

    if (kDebugMode) {
      debugPrint('🧹 [Stream] 已取消 $name 的订阅 (${toRemove.length}个)');
    }
  }

  /// 获取订阅统计
  Map<String, dynamic> getSubscriptionStats() {
    return {
      'totalSubscriptions': _subscriptions.length,
    };
  }
}

/// Timer 管理器
class TimerManager {
  TimerManager._internal();

  static final TimerManager _instance = TimerManager._internal();

  factory TimerManager() => _instance;

  final Map<String, Timer> _timers = {};

  /// 创建定时器
  String createTimer(
    String name,
    Duration duration,
    VoidCallback callback, {
    bool repeat = false,
  }) {
    final timerId = '${name}_${DateTime.now().millisecondsSinceEpoch}';

    Timer timer;
    if (repeat) {
      timer = Timer.periodic(duration, (_) => callback());
    } else {
      timer = Timer(duration, callback);
    }

    _timers[timerId] = timer;

    if (kDebugMode) {
      debugPrint('✅ [Timer] 定时器已创建: $name (ID: $timerId)');
    }

    return timerId;
  }

  /// 取消定时器
  void cancelTimer(String timerId) {
    final timer = _timers.remove(timerId);
    if (timer != null) {
      timer.cancel();
      if (kDebugMode) {
        debugPrint('🗑️ [Timer] 定时器已取消: $timerId');
      }
    }
  }

  /// 取消所有定时器
  void cancelAll() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();

    if (kDebugMode) {
      debugPrint('🧹 [Timer] 所有定时器已取消');
    }
  }

  /// 取消指定名称的定时器
  void cancelByName(String name) {
    final toRemove = <String>[];
    for (final entry in _timers.entries) {
      if (entry.key.startsWith(name)) {
        toRemove.add(entry.key);
      }
    }

    for (final timerId in toRemove) {
      cancelTimer(timerId);
    }

    if (kDebugMode) {
      debugPrint('🧹 [Timer] 已取消 $name 的定时器 (${toRemove.length}个)');
    }
  }

  /// 获取定时器统计
  Map<String, dynamic> getTimerStats() {
    return {
      'totalTimers': _timers.length,
    };
  }
}
