import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/gemini_service.dart';
import '../services/database_service.dart';
import 'package:background_downloader/background_downloader.dart';

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
        } else if (update.status == TaskStatus.failed || update.status == TaskStatus.canceled) {
          setState(() => _isDownloading = false);
        }
      }
    });
  }

  Future<void> _processImage(XFile image) async {
    // 1. 检查模型状态
    final isReady = await _geminiService.isModelReady();
    if (!isReady) {
      final hasFile = await _geminiService.isFilePresent(); 
      setState(() {
        _isDownloading = true;
        _downloadProgress = hasFile ? 0.5 : 0.0;
      });
      try {
        await _geminiService.downloadModel();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("引擎初始化失败: $e")));
        }
        setState(() => _isDownloading = false);
        return;
      }
      return; 
    }

    // 2. 正式识别
    setState(() {
      _isProcessing = true;
      _streamingText = "";
      _result = null;
    });

    final bytes = await image.readAsBytes();
    final info = await _geminiService.extractMedicationInfo(
      bytes,
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

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _result = info;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;
    _processImage(image);
  }

  Future<void> _confirmAndSave() async {
    if (_result != null) {
      await _dbService.saveMedicationFromAI(_result!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("药剂已保存并开启提醒！")),
        );
        Navigator.pop(context, true);
      }
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
          const Icon(Icons.cloud_download_rounded, size: 64, color: Color(0xFF3B82F6)),
          const SizedBox(height: 24),
          const Text("首次使用需初始化 AI 引擎", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("正在下载本地大模型(约2.4GB)\n建议在 WiFi 环境下进行", textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
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
          Text("${(_downloadProgress * 100).toStringAsFixed(1)}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
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
        const Text("没有检测到图片", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
          const CircularProgressIndicator(strokeWidth: 6),
          const SizedBox(height: 32),
          const Text("本地 AI 正在精读医嘱...",
              style: TextStyle(
                  color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          // 坤哥，这里设为固定高度 250 并支持自动滚动
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(16)),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF22C55E)),
                SizedBox(width: 12),
                Text("本地识别成功！", style: TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoTile("药名", _result!.name),
          _buildInfoTile("剂量", _result!.dosage),
          _buildInfoTile("频次", "每天 ${_result!.frequency} 次"),
          _buildInfoTile("时间点", _result!.times.join(", ")),
          _buildInfoTile("注意事项", _result!.precautions, isWarning: true),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _confirmAndSave,
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text("确定，开启提醒", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.bold,
            color: isWarning ? Colors.orange[800] : const Color(0xFF1F2937),
          )),
          const Divider(color: Color(0xFFF3F4F6)),
        ],
      ),
    );
  }
}
