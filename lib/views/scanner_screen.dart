import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/gemini_service.dart';
import '../services/database_service.dart';
import 'package:background_downloader/background_downloader.dart';
import '../widgets/scanner_result_editor.dart';
import '../widgets/animations.dart';
import 'model_manager_screen.dart';

class ScannerScreen extends StatefulWidget {
  final XFile? initialImage;

  const ScannerScreen({super.key, this.initialImage});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final GeminiService _geminiService = GeminiService();
  final DatabaseService _dbService = DatabaseService();
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();

  bool _isProcessing = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _streamingText = "";
  MedicationInfo? _result;
  StreamSubscription? _downloadSubscription;

  @override
  void initState() {
    super.initState();
    _listenToDownloads();
    if (widget.initialImage != null) {
      _processImage(widget.initialImage!);
    }
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _listenToDownloads() {
    _downloadSubscription = _geminiService.downloadUpdates.listen((update) {
      if (!mounted) return;
      if (update is TaskProgressUpdate) {
        setState(() {
          _isDownloading = true;
          _downloadProgress = update.progress;
        });
      } else if (update is TaskStatusUpdate) {
        if (update.status == TaskStatus.complete) {
          setState(() => _isDownloading = false);
        } else if (update.status == TaskStatus.failed ||
            update.status == TaskStatus.canceled) {
          setState(() => _isDownloading = false);
        }
      }
    });
  }

  Future<void> _processImage(XFile image) async {
    // 1. 强性模型校验
    final isGemmaReady = await _geminiService.isModelReady();
    if (!isGemmaReady) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("AI 识别引擎尚未就绪"),
            content: const Text("药品识别需在本地运行 AI 模型。是否现在前往模型管理页面进行下载安装？"),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("取消")),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ModelManagerScreen()));
                },
                child: const Text("前往管理"),
              ),
            ],
          ),
        );
      }
      return;
    }

    // 2. 正式识别
    if (mounted) {
      setState(() {
        _isProcessing = true;
        _streamingText = "正在启动本地 OCR 文字识别...";
        _result = null;
      });
    }

    final Uint8List imageBytes;
    try {
      imageBytes = await image.readAsBytes();
    } catch (e) {
      debugPrint("读取图片失败: $e");
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("未能读取图片数据，请重试。")),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _streamingText = "正在唤醒智慧药师提取核心信息...\n\n正在分析原图...";
      });
    }

    MedicationInfo? info;
    try {
      info = await _geminiService.extractMedicationInfo(
        imageBytes,
        onStream: (text) {
          if (mounted) {
            setState(() => _streamingText = text);
            // 坤哥，这里实现自动滚动到底部
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              }
            });
          }
        },
      );
    } catch (e) {
      debugPrint('识药流程异常: $e');
      info = null;
    }

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _result = info;
      });

      if (info == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('识别失败，请确认模型已正确安装。\n如持续失败，请前往「模型管理」删除旧模型并重新下载。'),
            duration: Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;
    _processImage(image);
  }

  Future<void> _confirmAndSave(MedicationInfo info) async {
    await _dbService.saveMedicationFromAI(info);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("药剂已保存并开启提醒！")),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI 识药结果")),
      body: Center(
        child: _isDownloading
            ? _buildDownloadUI()
            : (_isProcessing
                ? _buildLoading()
                : (_result != null ? _buildResult() : _buildPicker())),
      ),
    );
  }

  Widget _buildDownloadUI() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_download_rounded,
              size: 64, color: Color(0xFF3B82F6)),
          const SizedBox(height: 24),
          const Text("首次使用需初始化 AI 引擎",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("正在下载本地大模型(约2.4GB)\n建议在 WiFi 环境下进行",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(height: 32),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _downloadProgress >= 0 ? _downloadProgress : 0,
              minHeight: 12,
              backgroundColor: const Color(0xFFF3F4F6),
              color: const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(height: 12),
          Text("${(_downloadProgress * 100).toStringAsFixed(1)}%",
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
        ],
      ),
    );
  }

  Widget _buildPicker() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.camera_alt, size: 80, color: Colors.blue[100]),
        const SizedBox(height: 24),
        const Text("没有检测到图片",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: () => _pickImage(ImageSource.camera),
          icon: const Icon(Icons.photo_camera),
          label: const Text("重新拍照"),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MedicinePulseLoader(
            message: 'AI 正在解析药方',
            size: 100,
          ),
          const SizedBox(height: 24),
          // 流式文字显示区域
          Container(
            width: double.infinity,
            height: 250,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Text(
                _streamingText.isEmpty ? "正在唤醒智慧药师..." : _streamingText,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4B5563),
                  height: 1.5,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    return ScannerResultEditor(
      result: _result!,
      onSave: _confirmAndSave,
    );
  }
}
