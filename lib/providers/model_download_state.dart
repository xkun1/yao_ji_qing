import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
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
  ModelState _gemmaState = ModelState.none;
  bool _asrReady = false;
  bool _ttsReady = false;

  // 模型大小
  String _gemmaSize = '';
  String _asrSize = '';
  String _ttsSize = '';

  bool get isDownloading => _isDownloading;
  String? get downloadingType => _downloadingType;
  double get downloadProgress => _downloadProgress;
  String get downloadStatus => _downloadStatus;

  bool get gemmaReady => _gemmaReady;
  ModelState get gemmaState => _gemmaState;
  bool get asrReady => _asrReady;
  bool get ttsReady => _ttsReady;

  String get gemmaSize => _gemmaSize;
  String get asrSize => _asrSize;
  String get ttsSize => _ttsSize;

  /// 初始化
  void init() {
    _listenDownloadProgress();
    _restoreDownloadSnapshot();
    unawaited(refreshStatus());
  }

  /// 监听下载进度
  void _listenDownloadProgress() {
    _downloadSubscription = _geminiService.downloadUpdates.listen((update) {
      final snapshot = _geminiService.modelDownloadSnapshot;
      if (!snapshot.isActive) return;
      _applyDownloadSnapshot(snapshot);
    });
  }

  /// 恢复下载快照（含残留下载任务清理）
  void _restoreDownloadSnapshot() {
    final snapshot = _geminiService.modelDownloadSnapshot;
    if (snapshot.isActive) {
      _applyDownloadSnapshot(snapshot);
      return;
    }
    unawaited(_restoreNativeActiveDownload());
  }

  /// 恢复/清理原生后台下载任务
  Future<void> _restoreNativeActiveDownload() async {
    try {
      final tasks = await FileDownloader().allTasks(allGroups: true);
      for (final task in tasks) {
        if (task.filename == AppConstants.gemmaModelId) {
          final modelPath = await _geminiService.findExistingModelPath();
          if (modelPath != null) {
            await FileDownloader().cancelTaskWithId(task.taskId);
            continue;
          }
        }
        if (task.filename == AppConstants.asrArchiveId &&
            await _geminiService.checkAsrFilesExist()) {
          await FileDownloader().cancelTaskWithId(task.taskId);
          continue;
        }
        if (task.filename == AppConstants.ttsArchiveId &&
            await _geminiService.checkTtsFilesExist()) {
          await FileDownloader().cancelTaskWithId(task.taskId);
          continue;
        }
        final snapshot =
            _geminiService.downloadSnapshotForFilename(task.filename);
        if (snapshot != null) {
          _applyDownloadSnapshot(snapshot);
          return;
        }
      }
    } catch (_) {}
  }

  /// 应用下载快照
  void _applyDownloadSnapshot(ModelDownloadSnapshot snapshot) {
    _isDownloading = true;
    _downloadingType = snapshot.type;
    _downloadProgress = snapshot.progress;
    _downloadStatus = snapshot.status;
    notifyListeners();
  }

  /// 刷新模型状态
  Future<void> refreshStatus() async {
    try {
      _gemmaState = await _geminiService.getModelState();
      final gModelPath = await _geminiService.findExistingModelPath();
      _gemmaReady = _gemmaState == ModelState.ready && gModelPath != null;
      _asrReady = await _geminiService.checkAsrFilesExist();
      _ttsReady = await _geminiService.checkTtsFilesExist();

      _gemmaSize = gModelPath != null ? await _getFileSize(gModelPath) : '未下载';

      if (_asrReady) {
        final asrPath = await _geminiService.getAsrModelPathForDeletion();
        _asrSize = await _getDirSize(asrPath);
      } else {
        _asrSize = '未下载';
      }

      if (_ttsReady) {
        final ttsPath = await _geminiService.findTtsModelPath();
        if (ttsPath != null) {
          _ttsSize = await _getDirSize(Directory(ttsPath).parent.path);
        } else {
          _ttsSize = '未下载';
        }
      } else {
        _ttsSize = '未下载';
      }

      notifyListeners();
    } catch (e) {
      debugPrint('刷新模型状态失败: $e');
    }
  }

  /// 获取文件大小
  Future<String> _getFileSize(String path) async {
    final file = File(path);
    if (await file.exists()) {
      final bytes = await file.length();
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '未下载';
  }

  /// 获取目录大小
  Future<String> _getDirSize(String path) async {
    final dir = Directory(path);
    if (await dir.exists()) {
      int totalSize = 0;
      try {
        await for (var file in dir.list(recursive: true, followLinks: false)) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
      } catch (_) {}
      return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
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
        case 'asr':
          await _geminiService.downloadAsrModel();
        case 'tts':
          await _geminiService.downloadTtsModel();
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
        case 'asr':
          await _geminiService.deleteAsrModel();
        case 'tts':
          await _geminiService.deleteTtsModel();
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

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
  }
}
