import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../services/gemini_service.dart';

/// 模型下载状态管理
class ModelDownloadState extends ChangeNotifier {
  ModelDownloadState._internal();

  static final ModelDownloadState _instance = ModelDownloadState._internal();

  factory ModelDownloadState() => _instance;

  final GeminiService _geminiService = GeminiService();
  StreamSubscription? _downloadSubscription;

  // 下载状态
  bool _isDownloading = false;
  String? _downloadingType;
  double _downloadProgress = 0;
  String _downloadStatus = '';

  // 模型状态
  bool _gemmaReady = false;
  bool _asrReady = false;
  bool _ttsReady = false;

  // 模型大小
  String _gemmaSize = '未下载';
  String _asrSize = '未下载';
  String _ttsSize = '未下载';

  bool get isDownloading => _isDownloading;
  String? get downloadingType => _downloadingType;
  double get downloadProgress => _downloadProgress;
  String get downloadStatus => _downloadStatus;

  bool get gemmaReady => _gemmaReady;
  bool get asrReady => _asrReady;
  bool get ttsReady => _ttsReady;

  String get gemmaSize => _gemmaSize;
  String get asrSize => _asrSize;
  String get ttsSize => _ttsSize;

  /// 初始化
  void init() {
    _listenDownloadProgress();
    _restoreDownloadSnapshot();
    refreshStatus();
  }

  /// 监听下载进度
  void _listenDownloadProgress() {
    _downloadSubscription = _geminiService.downloadUpdates.listen((update) {
      final snapshot = _geminiService.modelDownloadSnapshot;
      if (!snapshot.isActive) return;

      _applyDownloadSnapshot(snapshot);
    });
  }

  /// 恢复下载快照
  void _restoreDownloadSnapshot() {
    final snapshot = _geminiService.modelDownloadSnapshot;
    if (snapshot.isActive) {
      _applyDownloadSnapshot(snapshot);
      return;
    }
  }

  /// 应用下载快照
  void _applyDownloadSnapshot(ModelDownloadSnapshot snapshot) {
    _isDownloading = true;
    _downloadingType = snapshot.type;
    _downloadProgress = snapshot.progress;
    _downloadStatus = snapshot.status;
    notifyListeners();
  }

  /// 刷新状态
  Future<void> refreshStatus() async {
    try {
      _gemmaReady = await _geminiService.isModelReady();
      _asrReady = await _geminiService.checkAsrFilesExist();
      _ttsReady = await _geminiService.checkTtsFilesExist();

      // 更新模型大小
      if (_gemmaReady) {
        final path = await _geminiService.getModelPathForDeletion();
        _gemmaSize = await _getFileSize(path);
      } else {
        _gemmaSize = '未下载';
      }

      if (_asrReady) {
        final path = await _geminiService.getAsrModelPathForDeletion();
        _asrSize = await _getDirSize(path);
      } else {
        _asrSize = '未下载';
      }

      if (_ttsReady) {
        // TTS 大小计算
        _ttsSize = '已安装';
      } else {
        _ttsSize = '未下载';
      }

      notifyListeners();
    } catch (e) {
      debugPrint('刷新状态失败: $e');
    }
  }

  /// 获取文件大小
  Future<String> _getFileSize(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.length();
        if (bytes < AppConstants.bytesPerMB) {
          return '${(bytes / AppConstants.bytesPerKB).toStringAsFixed(1)} KB';
        } else if (bytes < AppConstants.bytesPerGB) {
          return '${(bytes / AppConstants.bytesPerMB).toStringAsFixed(1)} MB';
        } else {
          return '${(bytes / AppConstants.bytesPerGB).toStringAsFixed(2)} GB';
        }
      }
    } catch (e) {
      debugPrint('获取文件大小失败: $e');
    }
    return '未下载';
  }

  /// 获取目录大小
  Future<String> _getDirSize(String path) async {
    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        int totalSize = 0;
        await for (var file in dir.list(recursive: true, followLinks: false)) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
        if (totalSize < AppConstants.bytesPerMB) {
          return '${(totalSize / AppConstants.bytesPerKB).toStringAsFixed(1)} KB';
        } else {
          return '${(totalSize / AppConstants.bytesPerMB).toStringAsFixed(1)} MB';
        }
      }
    } catch (e) {
      debugPrint('获取目录大小失败: $e');
    }
    return '未下载';
  }

  /// 下载模型
  Future<void> downloadModel(String type) async {
    if (_isDownloading) return;

    _isDownloading = true;
    _downloadingType = type;
    _downloadProgress = 0;
    _downloadStatus = '正在准备下载...';
    notifyListeners();

    try {
      switch (type) {
        case 'gemma':
          await _geminiService.downloadModel();
          break;
        case 'asr':
          await _geminiService.downloadAsrModel();
          break;
        case 'tts':
          await _geminiService.downloadTtsModel();
          break;
      }
    } catch (e) {
      debugPrint('下载失败: $e');
      rethrow;
    } finally {
      _isDownloading = false;
      _downloadingType = null;
      _downloadProgress = 0;
      _downloadStatus = '';
      notifyListeners();
      await refreshStatus();
    }
  }

  /// 删除模型
  Future<void> deleteModel(String type) async {
    try {
      switch (type) {
        case 'gemma':
          await _geminiService.deleteModel();
          break;
        case 'asr':
          await _geminiService.deleteAsrModel();
          break;
        case 'tts':
          await _geminiService.deleteTtsModel();
          break;
      }
      await refreshStatus();
    } catch (e) {
      debugPrint('删除失败: $e');
      rethrow;
    }
  }

  /// 检查是否正在下载指定类型
  bool isDownloadingType(String type) {
    return _isDownloading && _downloadingType == type;
  }

  /// 获取下载进度百分比
  String get downloadProgressPercent {
    if (_downloadProgress < 0) return '准备中';
    return '${(_downloadProgress * 100).clamp(0, 100).toStringAsFixed(1)}%';
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
  }
}
