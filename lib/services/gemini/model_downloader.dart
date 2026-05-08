import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';
import '../../core/exceptions.dart';

/// 模型下载状态快照
class ModelDownloadSnapshot {
  const ModelDownloadSnapshot({
    required this.isActive,
    this.type,
    this.progress = 0,
    this.status = '',
  });

  final bool isActive;
  final String? type;
  final double progress;
  final String status;
}

/// 模型下载器
class ModelDownloader {
  ModelDownloader._internal();

  static final ModelDownloader _instance = ModelDownloader._internal();

  factory ModelDownloader() => _instance;

  final _progressController = StreamController<TaskUpdate>.broadcast();
  ModelDownloadSnapshot _downloadSnapshot =
      const ModelDownloadSnapshot(isActive: false);

  Stream<TaskUpdate> get downloadUpdates => _progressController.stream;
  ModelDownloadSnapshot get downloadSnapshot => _downloadSnapshot;

  /// 初始化下载监听
  void init() {
    FileDownloader().updates.listen((update) {
      if (update is TaskProgressUpdate) {
        _updateProgress(update);
      } else if (update is TaskStatusUpdate) {
        _updateStatus(update);
      }
      _progressController.add(update);
    });
  }

  /// 取消所有残留的后台下载任务
  Future<void> cancelResidualTasks() async {
    try {
      final tasks = await FileDownloader().allTasks(allGroups: true);
      for (final task in tasks) {
        await FileDownloader().cancelTaskWithId(task.taskId);
      }
    } catch (_) {
      // 查询或取消失败不影响正常流程
    }
    clearDownloadSnapshot();
  }

  /// 下载模型
  Future<void> downloadModel({
    required String type,
    required String filename,
    required String directory,
    required List<String> urls,
    required int minBytes,
    required String modelName,
  }) async {
    try {
      _setDownloadSnapshot(filename, 0);

      TaskStatusUpdate? lastResult;
      for (var index = 0; index < urls.length; index++) {
        final url = urls[index];
        setDownloadStage(
          type,
          -1,
          '正在连接下载源 ${index + 1}/${urls.length}',
        );

        debugPrint('正在启动$modelName下载: $url');

        final task = _createDownloadTask(
          url: url,
          filename: filename,
          directory: directory,
        );

        var lastProgressAt = DateTime.now();
        var lastProgress = -1.0;
        var cancelRequested = false;

        final isGemma = filename == AppConstants.gemmaModelId;
        final stallTimeout = isGemma
            ? AppConstants.gemmaDownloadTimeout
            : AppConstants.downloadProgressTimeout;

        final result = await FileDownloader().download(
          task,
          onStatus: (status) {
            _updateStatus(TaskStatusUpdate(task, status));
            _progressController.add(TaskStatusUpdate(task, status));
            debugPrint('$modelName下载状态: $status');
          },
          onProgress: (progress) {
            if (progress >= 0 && progress > lastProgress + 0.0001) {
              lastProgress = progress;
              lastProgressAt = DateTime.now();
            }
            _setDownloadSnapshot(filename, progress);
            _progressController.add(TaskProgressUpdate(task, progress));
          },
          onElapsedTime: (_) {
            if (cancelRequested) return;
            final stalledFor = DateTime.now().difference(lastProgressAt);
            if (stalledFor < stallTimeout) return;

            cancelRequested = true;
            setDownloadStage(
              type,
              lastProgress >= 0 ? lastProgress : -1,
              '下载源无进度，正在切换备用源',
            );
            FileDownloader().cancelTaskWithId(task.taskId);
          },
          elapsedTimeInterval: AppConstants.downloadElapsedInterval,
        );

        if (result.status == TaskStatus.complete) {
          final docsDir = await getApplicationDocumentsDirectory();
          final file = File('${docsDir.path}/$directory/$filename');
          if (!await file.exists() || await file.length() < minBytes) {
            lastResult = result;
            debugPrint('$modelName下载文件不完整，尝试备用地址: ${file.path}');
            if (await file.exists()) await file.delete();
            continue;
          }
          _setDownloadSnapshot(filename, 1);
          return;
        }
        lastResult = result;
        debugPrint(
            '$modelName下载失败，尝试备用地址: ${result.status}, ${result.exception}');
      }

      if (lastResult == null) {
        throw DownloadException('$modelName下载地址为空，请检查配置。');
      }
      _ensureDownloadComplete(lastResult, modelName);
    } catch (e) {
      clearDownloadSnapshot();
      rethrow;
    }
  }

  /// 创建下载任务
  DownloadTask _createDownloadTask({
    required String url,
    required String filename,
    required String directory,
  }) {
    final isGemma = filename == AppConstants.gemmaModelId;
    return ParallelDownloadTask(
      url: url,
      filename: filename,
      directory: directory,
      baseDirectory: BaseDirectory.applicationDocuments,
      updates: Updates.statusAndProgress,
      chunks: isGemma
          ? AppConstants.gemmaDownloadChunks
          : AppConstants.defaultDownloadChunks,
      retries: isGemma
          ? AppConstants.gemmaDownloadRetries
          : AppConstants.defaultDownloadRetries,
      allowPause: false,
    );
  }

  /// 更新下载进度
  void _updateProgress(TaskProgressUpdate update) {
    _setDownloadSnapshot(update.task.filename, update.progress);
  }

  /// 更新下载状态
  void _updateStatus(TaskStatusUpdate update) {
    final type = _getTypeFromFilename(update.task.filename);
    if (type == null) return;

    final currentProgress =
        _downloadSnapshot.type == type ? _downloadSnapshot.progress : -1.0;
    final progress =
        update.status == TaskStatus.complete ? 1.0 : currentProgress;
    setDownloadStage(
      type,
      progress,
      _getStatusTextForStatus(type, update.status),
    );
  }

  /// 设置下载快照
  void _setDownloadSnapshot(String filename, double progress) {
    final type = _getTypeFromFilename(filename);
    if (type == null) return;

    setDownloadStage(
      type,
      _normalizeProgress(progress),
      _getStatusText(type, filename),
    );
  }

  /// 设置下载阶段
  void setDownloadStage(String type, double progress, String status) {
    _downloadSnapshot = ModelDownloadSnapshot(
      isActive: true,
      type: type,
      progress: progress,
      status: status,
    );
  }

  /// 清除下载快照
  void clearDownloadSnapshot() {
    _downloadSnapshot = const ModelDownloadSnapshot(isActive: false);
  }

  /// 从文件名获取类型
  String? _getTypeFromFilename(String filename) {
    if (filename == AppConstants.gemmaModelId) return 'gemma';
    if (filename == AppConstants.asrArchiveId) return 'asr';
    if (filename == AppConstants.ttsArchiveId) return 'tts';
    return null;
  }

  /// 规范化进度
  double _normalizeProgress(double progress) {
    if (progress < 0) return -1;
    return progress.clamp(0, 1);
  }

  /// 获取状态文本
  String _getStatusText(String type, String filename) {
    switch (type) {
      case 'gemma':
        return '正在下载 Gemma4 模型';
      case 'asr':
        return '正在下载语音识别模型';
      case 'tts':
        return '正在下载语音合成模型';
      default:
        return '正在下载安装';
    }
  }

  /// 获取状态对应的文本
  String _getStatusTextForStatus(String type, TaskStatus status) {
    final modelName = switch (type) {
      'gemma' => 'Gemma4 模型',
      'asr' => '语音识别模型',
      'tts' => '语音合成模型',
      _ => '模型',
    };

    return switch (status) {
      TaskStatus.enqueued => '已加入下载队列，等待系统开始',
      TaskStatus.running => '正在下载$modelName',
      TaskStatus.waitingToRetry => '网络波动，等待自动重试',
      TaskStatus.paused => '下载已暂停',
      TaskStatus.complete => '下载完成',
      TaskStatus.notFound => '下载地址不存在',
      TaskStatus.failed => '下载失败，正在尝试备用源',
      TaskStatus.canceled => '下载源无响应，正在切换备用源',
    };
  }

  /// 确保下载完成
  void _ensureDownloadComplete(TaskStatusUpdate result, String modelName) {
    if (result.status == TaskStatus.complete) return;
    throw DownloadException.failed(
      modelName: modelName,
      cause: result.exception ?? result.status,
    );
  }

  /// 获取文件名对应的下载快照
  ModelDownloadSnapshot? getSnapshotForFilename(String filename,
      {double progress = -1}) {
    final type = _getTypeFromFilename(filename);
    if (type == null) return null;
    return ModelDownloadSnapshot(
      isActive: true,
      type: type,
      progress: _normalizeProgress(progress),
      status: _getStatusText(type, filename),
    );
  }

  /// 清理资源
  void dispose() {
    _progressController.close();
  }
}
