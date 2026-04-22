import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:background_downloader/background_downloader.dart';

import '../services/gemini_service.dart';

class ModelManagerScreen extends StatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  State<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends State<ModelManagerScreen> {
  final GeminiService _aiService = GeminiService();

  bool _gemmaReady = false;
  bool _asrReady = false;
  bool _ttsReady = false;

  String _gemmaSize = '检测中...';
  String _asrSize = '检测中...';
  String _ttsSize = '检测中...';

  bool _isProcessing = false;
  String? _downloadingType;
  double _downloadProgress = 0;
  String _downloadStatus = '';
  StreamSubscription<TaskUpdate>? _downloadSubscription;

  @override
  void initState() {
    super.initState();
    _listenDownloadProgress();
    _restoreDownloadSnapshot();
    _refreshStatus();
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
  }

  void _listenDownloadProgress() {
    _downloadSubscription = _aiService.downloadUpdates.listen((update) {
      if (!mounted || update is! TaskProgressUpdate) return;

      final snapshot = _aiService.modelDownloadSnapshot;
      if (!snapshot.isActive) return;

      _applyDownloadSnapshot(snapshot);
    });
  }

  void _restoreDownloadSnapshot() {
    final snapshot = _aiService.modelDownloadSnapshot;
    if (snapshot.isActive) {
      _applyDownloadSnapshot(snapshot);
      return;
    }

    unawaited(_restoreNativeActiveDownload());
  }

  void _applyDownloadSnapshot(ModelDownloadSnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      _isProcessing = true;
      _downloadingType = snapshot.type;
      _downloadProgress = snapshot.progress;
      _downloadStatus = snapshot.status;
    });
  }

  Future<void> _restoreNativeActiveDownload() async {
    try {
      final tasks = await FileDownloader().allTasks(allGroups: true);
      if (!mounted) return;

      for (final task in tasks) {
        final snapshot = _aiService.downloadSnapshotForFilename(task.filename);
        if (snapshot != null) {
          _applyDownloadSnapshot(snapshot);
          return;
        }
      }
    } catch (_) {
      // 后台任务查询失败不影响模型状态检测。
    }
  }

  Future<void> _refreshStatus() async {
    final gState = await _aiService.getModelState();
    final gReady = gState == ModelState.ready;
    final aReady = await _aiService.checkAsrFilesExist();
    final tReady = await _aiService.checkTtsFilesExist();

    String gSize = gState == ModelState.none
        ? '未下载'
        : await _getFileSize(await _aiService.getModelPathForDeletion());
    String aSize = aReady
        ? await _getDirSize(await _aiService.getAsrModelPathForDeletion())
        : '未下载';

    String tSize = '未下载';
    if (tReady) {
      final ttsPath = await _aiService.findTtsModelPath();
      if (ttsPath != null) {
        tSize = await _getDirSize(Directory(ttsPath).parent.path);
      }
    }

    if (mounted) {
      setState(() {
        _gemmaReady = gReady;
        _asrReady = aReady;
        _ttsReady = tReady;
        _gemmaSize = gSize;
        _asrSize = aSize;
        _ttsSize = tSize;
      });
    }
  }

  Future<String> _getFileSize(String path) async {
    final file = File(path);
    if (await file.exists()) {
      final bytes = await file.length();
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '未下载';
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text("模型管理"),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildModelCard(
            title: "对话引擎 (Gemma 4)",
            subtitle: "本地大语言模型，负责理解与回复",
            size: _gemmaSize,
            isReady: _gemmaReady,
            isDownloading: _downloadingType == 'gemma',
            downloadProgress: _downloadProgress,
            downloadStatus: _downloadStatus,
            icon: Icons.psychology_rounded,
            color: const Color(0xFF3B82F6),
            onDownload: () => _handleDownload('gemma'),
            onDelete: () => _handleDelete('gemma'),
          ),
          const SizedBox(height: 16),
          _buildModelCard(
            title: "语音识别 (ASR)",
            subtitle: "本地流式语音识别，负责听懂您的话",
            size: _asrSize,
            isReady: _asrReady,
            isDownloading: _downloadingType == 'asr',
            downloadProgress: _downloadProgress,
            downloadStatus: _downloadStatus,
            icon: Icons.mic_rounded,
            color: const Color(0xFF8B5CF6),
            onDownload: () => _handleDownload('asr'),
            onDelete: () => _handleDelete('asr'),
          ),
          const SizedBox(height: 16),
          _buildModelCard(
            title: "语音合成 (TTS)",
            subtitle: "本地甜美女声合成，负责为您播报",
            size: _ttsSize,
            isReady: _ttsReady,
            isDownloading: _downloadingType == 'tts',
            downloadProgress: _downloadProgress,
            downloadStatus: _downloadStatus,
            icon: Icons.record_voice_over_rounded,
            color: const Color(0xFF10B981),
            onDownload: () => _handleDownload('tts'),
            onDelete: () => _handleDelete('tts'),
          ),
          const SizedBox(height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "提示：删除模型后，对应的功能将暂时无法使用。建议在存储空间不足时再进行清理。",
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelCard({
    required String title,
    required String subtitle,
    required String size,
    required bool isReady,
    required bool isDownloading,
    required double downloadProgress,
    required String downloadStatus,
    required IconData icon,
    required Color color,
    required VoidCallback onDownload,
    required VoidCallback onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (isDownloading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: downloadProgress >= 0 ? downloadProgress : null,
                minHeight: 8,
                color: color,
                backgroundColor: color.withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  downloadStatus.isEmpty ? '正在下载安装...' : downloadStatus,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  downloadProgress >= 0
                      ? '${(downloadProgress * 100).clamp(0, 100).toStringAsFixed(1)}%'
                      : '准备中',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "占用空间",
                    style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    size,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (isReady)
                    TextButton.icon(
                      onPressed: _isProcessing ? null : onDelete,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFEF4444),
                      ),
                      label: const Text(
                        "删除",
                        style: TextStyle(color: Color(0xFFEF4444)),
                      ),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _isProcessing ? null : onDownload,
                      icon: Icon(
                        isDownloading
                            ? Icons.cloud_download_rounded
                            : Icons.download_rounded,
                        size: 18,
                      ),
                      label: Text(isDownloading ? "下载中" : "下载安装"),
                      style: FilledButton.styleFrom(
                        backgroundColor: color,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleDownload(String type) async {
    setState(() {
      _isProcessing = true;
      _downloadingType = type;
      _downloadProgress = 0;
      _downloadStatus = '正在准备下载...';
    });
    try {
      if (type == 'gemma') {
        await _aiService.downloadModel();
      } else if (type == 'asr') {
        await _aiService.downloadAsrModel();
      } else if (type == 'tts') {
        await _aiService.downloadTtsModel();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("模型下载安装完成")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("下载安装失败: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _downloadingType = null;
          _downloadProgress = 0;
          _downloadStatus = '';
        });
      }
      _refreshStatus();
    }
  }

  void _handleDelete(String type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("确认删除模型？"),
        content: const Text("您确定要删除该模型文件吗？删除后相关功能将无法工作，且重新使用需再次下载。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text("确认删除"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      if (type == 'gemma') {
        final path = await _aiService.getModelPathForDeletion();
        final file = File(path);
        if (await file.exists()) await file.delete();
      } else if (type == 'asr') {
        await _aiService.deleteAsrModel();
      } else if (type == 'tts') {
        await _aiService.deleteTtsModel();
      }

      await _refreshStatus();
      setState(() => _isProcessing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("模型已彻底清理")),
        );
      }
    }
  }
}
