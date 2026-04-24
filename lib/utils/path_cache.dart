import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 文件路径缓存器 - 优化重复的文件系统操作
class PathCache {
  PathCache._internal();

  static final PathCache _instance = PathCache._internal();

  factory PathCache() => _instance;

  // 路径缓存
  String? _applicationDocumentsPath;
  String? _applicationSupportPath;
  String? _applicationLibraryPath;
  String? _temporaryDirectoryPath;
  String? _externalStoragePath;

  // 缓存时间戳
  DateTime? _cacheTimestamp;
  static const Duration _cacheValidity = Duration(minutes: 5);

  /// 获取应用文档目录路径
  Future<String> getApplicationDocumentsPath() async {
    if (_isCacheValid() && _applicationDocumentsPath != null) {
      return _applicationDocumentsPath!;
    }

    await _refreshCache();
    return _applicationDocumentsPath!;
  }

  /// 获取应用支持目录路径
  Future<String> getApplicationSupportPath() async {
    if (_isCacheValid() && _applicationSupportPath != null) {
      return _applicationSupportPath!;
    }

    await _refreshCache();
    return _applicationSupportPath!;
  }

  /// 获取应用库目录路径
  Future<String> getApplicationLibraryPath() async {
    if (_isCacheValid() && _applicationLibraryPath != null) {
      return _applicationLibraryPath!;
    }

    await _refreshCache();
    return _applicationLibraryPath!;
  }

  /// 获取临时目录路径
  Future<String> getTemporaryDirectoryPath() async {
    if (_isCacheValid() && _temporaryDirectoryPath != null) {
      return _temporaryDirectoryPath!;
    }

    await _refreshCache();
    return _temporaryDirectoryPath!;
  }

  /// 获取外部存储目录路径（仅 Android）
  Future<String?> getExternalStoragePath() async {
    if (_isCacheValid() && _externalStoragePath != null) {
      return _externalStoragePath;
    }

    await _refreshCache();
    return _externalStoragePath;
  }

  /// 构建缓存路径
  Future<String> buildCachePath(String relativePath) async {
    final tempDir = await getTemporaryDirectoryPath();
    return '$tempDir/cache/$relativePath';
  }

  /// 构建模型路径
  Future<String> buildModelPath(String modelName) async {
    final docsDir = await getApplicationDocumentsPath();
    return '$docsDir/models/$modelName';
  }

  /// 构建数据路径
  Future<String> buildDataPath(String dataName) async {
    final docsDir = await getApplicationDocumentsPath();
    return '$docsDir/data/$dataName';
  }

  /// 构建日志路径
  Future<String> buildLogPath(String logName) async {
    final supportDir = await getApplicationSupportPath();
    return '$supportDir/logs/$logName';
  }

  /// 刷新缓存
  Future<void> _refreshCache() async {
    try {
      _applicationDocumentsPath = (await getApplicationDocumentsDirectory()).path;
      _applicationSupportPath = (await getApplicationSupportDirectory()).path;
      _temporaryDirectoryPath = (await getTemporaryDirectory()).path;

      // iOS 特定路径
      if (Platform.isIOS) {
        _applicationLibraryPath = (await getLibraryDirectory()).path;
      }

      // Android 特定路径
      if (Platform.isAndroid) {
        final externalDir = await getExternalStorageDirectory();
        _externalStoragePath = externalDir?.path;
      }

      _cacheTimestamp = DateTime.now();

      if (kDebugMode) {
        debugPrint('🔄 [PathCache] 路径缓存已刷新');
      }
    } catch (e) {
      debugPrint('刷新路径缓存失败: $e');
      // 如果刷新失败，至少返回当前缓存值
    }
  }

  /// 检查缓存是否有效
  bool _isCacheValid() {
    if (_cacheTimestamp == null) return false;
    final now = DateTime.now();
    return now.difference(_cacheTimestamp!) < _cacheValidity;
  }

  /// 清除缓存
  void clearCache() {
    _applicationDocumentsPath = null;
    _applicationSupportPath = null;
    _applicationLibraryPath = null;
    _temporaryDirectoryPath = null;
    _externalStoragePath = null;
    _cacheTimestamp = null;

    if (kDebugMode) {
      debugPrint('🗑️ [PathCache] 路径缓存已清除');
    }
  }

  /// 获取缓存统计
  Map<String, dynamic> getCacheStats() {
    return {
      'isCacheValid': _isCacheValid(),
      'cacheTimestamp': _cacheTimestamp?.toIso8601String(),
      'hasDocumentsPath': _applicationDocumentsPath != null,
      'hasSupportPath': _applicationSupportPath != null,
      'hasLibraryPath': _applicationLibraryPath != null,
      'hasTempPath': _temporaryDirectoryPath != null,
      'hasExternalPath': _externalStoragePath != null,
    };
  }
}

/// 文件操作缓存器
class FileOperationCache {
  FileOperationCache._internal();

  static final FileOperationCache _instance = FileOperationCache._internal();

  factory FileOperationCache() => _instance;

  // 文件存在性缓存
  final Map<String, bool> _existenceCache = {};
  final Map<String, DateTime> _existenceCacheTimestamps = {};

  // 文件大小缓存
  final Map<String, int> _sizeCache = {};
  final Map<String, DateTime> _sizeCacheTimestamps = {};

  // 缓存配置
  static const Duration _existenceCacheValidity = Duration(seconds: 30);
  static const Duration _sizeCacheValidity = Duration(minutes: 5);

  /// 检查文件是否存在（带缓存）
  Future<bool> fileExists(String path) async {
    // 检查缓存
    final cached = _existenceCache[path];
    final timestamp = _existenceCacheTimestamps[path];
    if (cached != null &&
        timestamp != null &&
        DateTime.now().difference(timestamp) < _existenceCacheValidity) {
      return cached;
    }

    // 实际检查
    final exists = await File(path).exists();

    // 更新缓存
    _existenceCache[path] = exists;
    _existenceCacheTimestamps[path] = DateTime.now();

    return exists;
  }

  /// 检查目录是否存在（带缓存）
  Future<bool> directoryExists(String path) async {
    // 检查缓存
    final cached = _existenceCache[path];
    final timestamp = _existenceCacheTimestamps[path];
    if (cached != null &&
        timestamp != null &&
        DateTime.now().difference(timestamp) < _existenceCacheValidity) {
      return cached;
    }

    // 实际检查
    final exists = await Directory(path).exists();

    // 更新缓存
    _existenceCache[path] = exists;
    _existenceCacheTimestamps[path] = DateTime.now();

    return exists;
  }

  /// 获取文件大小（带缓存）
  Future<int> getFileSize(String path) async {
    // 检查缓存
    final cached = _sizeCache[path];
    final timestamp = _sizeCacheTimestamps[path];
    if (cached != null &&
        timestamp != null &&
        DateTime.now().difference(timestamp) < _sizeCacheValidity) {
      return cached;
    }

    // 实际获取
    final file = File(path);
    if (!await file.exists()) {
      return 0;
    }

    final size = await file.length();

    // 更新缓存
    _sizeCache[path] = size;
    _sizeCacheTimestamps[path] = DateTime.now();

    return size;
  }

  /// 使缓存失效
  void invalidatePath(String path) {
    _existenceCache.remove(path);
    _existenceCacheTimestamps.remove(path);
    _sizeCache.remove(path);
    _sizeCacheTimestamps.remove(path);
  }

  /// 使目录下的所有缓存失效
  void invalidateDirectory(String directoryPath) {
    final prefix = directoryPath.endsWith(Platform.pathSeparator)
        ? directoryPath
        : '$directoryPath${Platform.pathSeparator}';

    _existenceCache.removeWhere((key, _) => key.startsWith(prefix));
    _existenceCacheTimestamps.removeWhere((key, _) => key.startsWith(prefix));
    _sizeCache.removeWhere((key, _) => key.startsWith(prefix));
    _sizeCacheTimestamps.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// 清除所有缓存
  void clearCache() {
    _existenceCache.clear();
    _existenceCacheTimestamps.clear();
    _sizeCache.clear();
    _sizeCacheTimestamps.clear();

    if (kDebugMode) {
      debugPrint('🗑️ [FileOperationCache] 文件操作缓存已清除');
    }
  }

  /// 清理过期缓存
  void cleanupExpiredCache() {
    final now = DateTime.now();

    // 清理存在性缓存
    final expiredExistenceKeys = <String>[];
    _existenceCacheTimestamps.forEach((key, timestamp) {
      final age = now.difference(timestamp);
      if (age > _existenceCacheValidity) {
        expiredExistenceKeys.add(key);
      }
    });

    for (final key in expiredExistenceKeys) {
      _existenceCache.remove(key);
      _existenceCacheTimestamps.remove(key);
    }

    // 清理大小缓存
    final expiredSizeKeys = <String>[];
    _sizeCacheTimestamps.forEach((key, timestamp) {
      final age = now.difference(timestamp);
      if (age > _sizeCacheValidity) {
        expiredSizeKeys.add(key);
      }
    });

    for (final key in expiredSizeKeys) {
      _sizeCache.remove(key);
      _sizeCacheTimestamps.remove(key);
    }

    if (kDebugMode) {
      debugPrint('🧹 [FileOperationCache] 过期缓存已清理');
    }
  }

  /// 获取缓存统计
  Map<String, dynamic> getCacheStats() {
    return {
      'existenceCacheSize': _existenceCache.length,
      'sizeCacheSize': _sizeCache.length,
    };
  }
}