import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 缓存管理器
class CacheManager {
  CacheManager._internal();

  static final CacheManager _instance = CacheManager._internal();

  factory CacheManager() => _instance;

  // 缓存存储
  final Map<String, _CacheEntry> _memoryCache = {};
  final Map<String, DateTime> _fileCacheTimestamps = {};

  // 缓存配置
  static const Duration _defaultCacheDuration = Duration(minutes: 30);
  static const int _maxMemoryCacheSize = 100; // 最大内存缓存条目数
  static const int _maxMemoryCacheBytes = 50 * 1024 * 1024; // 50MB

  int _currentMemoryCacheBytes = 0;

  /// 获取内存缓存
  T? getMemoryCache<T>(String key) {
    final entry = _memoryCache[key];
    if (entry == null) return null;

    // 检查是否过期
    if (DateTime.now().isAfter(entry.expiryTime)) {
      _removeMemoryCache(key);
      return null;
    }

    return entry.value as T;
  }

  /// 设置内存缓存
  void setMemoryCache<T>(String key, T value, {Duration? duration}) {
    // 计算值的大致大小
    final valueSize = _estimateSize(value);

    // 检查缓存大小限制
    if (_currentMemoryCacheBytes + valueSize > _maxMemoryCacheBytes) {
      _evictMemoryCache(_maxMemoryCacheBytes - valueSize);
    }

    // 检查缓存条目数量限制
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      _evictOldestEntries();
    }

    final expiryTime = DateTime.now().add(duration ?? _defaultCacheDuration);
    _memoryCache[key] = _CacheEntry(value, expiryTime);
    _currentMemoryCacheBytes += valueSize;

    if (kDebugMode) {
      debugPrint('✅ [Cache] 内存缓存设置: $key (大小: $valueSize bytes)');
    }
  }

  /// 移除内存缓存
  void removeMemoryCache(String key) {
    _removeMemoryCache(key);
  }

  /// 清空内存缓存
  void clearMemoryCache() {
    _memoryCache.clear();
    _currentMemoryCacheBytes = 0;
    if (kDebugMode) {
      debugPrint('🗑️ [Cache] 内存缓存已清空');
    }
  }

  /// 获取文件缓存路径
  Future<String?> getFileCachePath(String key) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final file = File('${cacheDir.path}/cache/$key');

      // 检查文件是否存在
      if (!await file.exists()) return null;

      // 检查是否过期
      final timestamp = _fileCacheTimestamps[key];
      if (timestamp != null && DateTime.now().isAfter(timestamp)) {
        await file.delete();
        _fileCacheTimestamps.remove(key);
        return null;
      }

      return file.path;
    } catch (e) {
      debugPrint('获取文件缓存失败: $e');
      return null;
    }
  }

  /// 设置文件缓存
  Future<void> setFileCache(String key, List<int> bytes,
      {Duration? duration}) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final cacheSubDir = Directory('${cacheDir.path}/cache');
      if (!await cacheSubDir.exists()) {
        await cacheSubDir.create(recursive: true);
      }

      final file = File('${cacheSubDir.path}/$key');
      await file.writeAsBytes(bytes);

      final expiryTime = DateTime.now().add(duration ?? _defaultCacheDuration);
      _fileCacheTimestamps[key] = expiryTime;

      if (kDebugMode) {
        debugPrint('✅ [Cache] 文件缓存设置: $key (大小: ${bytes.length} bytes)');
      }
    } catch (e) {
      debugPrint('设置文件缓存失败: $e');
    }
  }

  /// 移除文件缓存
  Future<void> removeFileCache(String key) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final file = File('${cacheDir.path}/cache/$key');
      if (await file.exists()) {
        await file.delete();
      }
      _fileCacheTimestamps.remove(key);
    } catch (e) {
      debugPrint('移除文件缓存失败: $e');
    }
  }

  /// 清空文件缓存
  Future<void> clearFileCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final cacheSubDir = Directory('${cacheDir.path}/cache');
      if (await cacheSubDir.exists()) {
        await cacheSubDir.delete(recursive: true);
      }
      _fileCacheTimestamps.clear();
      if (kDebugMode) {
        debugPrint('🗑️ [Cache] 文件缓存已清空');
      }
    } catch (e) {
      debugPrint('清空文件缓存失败: $e');
    }
  }

  /// 清空所有缓存
  Future<void> clearAllCache() async {
    clearMemoryCache();
    await clearFileCache();
  }

  /// 清理过期缓存
  Future<void> cleanupExpiredCache() async {
    // 清理内存缓存
    final now = DateTime.now();
    _memoryCache.removeWhere((key, entry) {
      if (now.isAfter(entry.expiryTime)) {
        _currentMemoryCacheBytes -= _estimateSize(entry.value);
        return true;
      }
      return false;
    });

    // 清理文件缓存
    try {
      final cacheDir = await getTemporaryDirectory();
      final cacheSubDir = Directory('${cacheDir.path}/cache');
      if (await cacheSubDir.exists()) {
        await for (final entity in cacheSubDir.list()) {
          if (entity is File) {
            final key = entity.path.split('/').last;
            final timestamp = _fileCacheTimestamps[key];
            if (timestamp == null || now.isAfter(timestamp)) {
              await entity.delete();
              _fileCacheTimestamps.remove(key);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('清理过期文件缓存失败: $e');
    }

    if (kDebugMode) {
      debugPrint('🧹 [Cache] 过期缓存已清理');
    }
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getCacheStats() {
    return {
      'memoryCacheSize': _memoryCache.length,
      'memoryCacheBytes': _currentMemoryCacheBytes,
      'fileCacheSize': _fileCacheTimestamps.length,
    };
  }

  /// 移除内存缓存（内部方法）
  void _removeMemoryCache(String key) {
    final entry = _memoryCache.remove(key);
    if (entry != null) {
      _currentMemoryCacheBytes -= _estimateSize(entry.value);
    }
  }

  /// 驱逐内存缓存
  void _evictMemoryCache(int targetBytes) {
    final entries = _memoryCache.entries.toList()
      ..sort((a, b) => a.value.createdAt.compareTo(b.value.createdAt));

    for (final entry in entries) {
      if (_currentMemoryCacheBytes <= targetBytes) break;
      _removeMemoryCache(entry.key);
    }
  }

  /// 驱逐最旧的条目
  void _evictOldestEntries() {
    final entries = _memoryCache.entries.toList()
      ..sort((a, b) => a.value.createdAt.compareTo(b.value.createdAt));

    final toRemove =
        entries.take(_memoryCache.length - _maxMemoryCacheSize + 1);
    for (final entry in toRemove) {
      _removeMemoryCache(entry.key);
    }
  }

  /// 估算对象大小
  int _estimateSize(dynamic value) {
    if (value is String) {
      return value.length * 2; // UTF-16 编码
    } else if (value is List<int>) {
      return value.length;
    } else if (value is Map) {
      return value.toString().length * 2;
    } else {
      return 100; // 默认估算
    }
  }

  /// 获取缓存大小（格式化）
  String getFormattedCacheSize() {
    final totalBytes = _currentMemoryCacheBytes;
    if (totalBytes < 1024) {
      return '$totalBytes B';
    } else if (totalBytes < 1024 * 1024) {
      return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}

/// 缓存条目
class _CacheEntry {
  _CacheEntry(this.value, this.expiryTime) : createdAt = DateTime.now();

  final dynamic value;
  final DateTime expiryTime;
  final DateTime createdAt;
}
