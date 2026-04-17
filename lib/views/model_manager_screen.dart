import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import 'package:background_downloader/background_downloader.dart';

class ModelManagerScreen extends StatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  State<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends State<ModelManagerScreen> {
  final GeminiService _aiService = GeminiService();
  ModelState _state = ModelState.none;
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusText = "正在检查状态...";
  String _fileSizeText = "0 GB";
  StreamSubscription? _downloadSubscription;

  static const String _constModelSize = "2.41 GB";

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _listenToDownloads();
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final state = await _aiService.getModelState();
    String sizeText = "0 GB";
    
    // 如果文件在磁盘上（不管是 ready 还是 fileDetected），都显示真实大小
    if (state != ModelState.none) {
      try {
        final path = await _aiService.getModelPathForDeletion();
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.length();
          sizeText = "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
        } else {
          sizeText = _constModelSize;
        }
      } catch (_) {
        sizeText = _constModelSize;
      }
    }

    if (mounted) {
      setState(() {
        _state = state;
        _fileSizeText = sizeText;
        switch (state) {
          case ModelState.ready:
            _statusText = "引擎已就绪";
            break;
          case ModelState.fileDetected:
            _statusText = "模型文件已检测到 (待初始化)";
            break;
          case ModelState.none:
            _statusText = "未安装";
            break;
        }
      });
    }
  }

  void _listenToDownloads() {
    _downloadSubscription = _aiService.downloadUpdates.listen((update) {
      if (!mounted) return;
      if (update is TaskProgressUpdate) {
        setState(() {
          _isDownloading = true;
          _progress = update.progress;
          _statusText = "正在下载 AI 引擎...";
        });
      } else if (update is TaskStatusUpdate) {
        if (update.status == TaskStatus.complete) {
          _checkStatus();
          setState(() => _isDownloading = false);
        } else if (update.status == TaskStatus.failed || update.status == TaskStatus.canceled) {
          setState(() => _isDownloading = false);
          _checkStatus();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(title: const Text("AI 引擎管理"), backgroundColor: Colors.white, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 32),
            const Text("关于 Gemma 4 引擎", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              "这是 Google 开发的高性能端侧大语言模型。开启后，您的用药识别将在手机本地 100% 离线完成，确保极致的隐私与响应速度。",
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14, height: 1.6),
            ),
            const Spacer(),
            _buildMainButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMainButton() {
    if (_isDownloading) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          onPressed: null,
          style: FilledButton.styleFrom(disabledBackgroundColor: const Color(0xFFE5E7EB)),
          child: const Text("正在处理中...", style: TextStyle(color: Colors.white)),
        ),
      );
    }

    if (_state == ModelState.ready) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: OutlinedButton.icon(
          onPressed: _handleDelete,
          icon: const Icon(Icons.delete_sweep_rounded),
          label: const Text("删除模型，释放空间"),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFEF4444),
            side: const BorderSide(color: Color(0xFFFCA5A5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
    }

    if (_state == ModelState.fileDetected) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton.icon(
          onPressed: () => _aiService.downloadModel(),
          icon: const Icon(Icons.flash_on_rounded),
          label: const Text("立即初始化本地模型"),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B), // 橙色醒目提示
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: () => _aiService.downloadModel(),
        icon: const Icon(Icons.download_rounded),
        label: const Text("立即安装 (2.41 GB)"),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    Color statusColor = const Color(0xFF3B82F6);
    IconData statusIcon = Icons.memory_rounded;
    
    if (_state == ModelState.ready) {
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.verified_rounded;
    } else if (_state == ModelState.fileDetected) {
      statusColor = const Color(0xFFF59E0B);
      statusIcon = Icons.folder_shared_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("引擎状态", style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                    Text(_statusText, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: statusColor)),
                    if (_state != ModelState.none)
                      Text("占用空间: $_fileSizeText", style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                  ],
                ),
              ),
              if (_state == ModelState.ready)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981))
            ],
          ),
          if (_isDownloading) ...[
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _progress >= 0 ? _progress : 0,
                minHeight: 8,
                backgroundColor: const Color(0xFFF3F4F6),
                color: const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 8),
            Text("${(_progress * 100).toStringAsFixed(1)}%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ]
        ],
      ),
    );
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("释放空间？"),
        content: const Text("确定要删除本地 AI 模型吗？删除后将无法使用拍照识药功能。"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("取消")),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text("确定删除"),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final path = await _aiService.getModelPathForDeletion();
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("模型已删除，空间已释放")));
          _checkStatus();
        }
      }
    }
  }
}
