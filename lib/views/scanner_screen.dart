import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/gemini_service.dart';
import '../services/database_service.dart';

class ScannerScreen extends StatefulWidget {
  final XFile? initialImage; // 接收从外部传入的图片

  const ScannerScreen({super.key, this.initialImage});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final GeminiService _geminiService = GeminiService();
  final DatabaseService _dbService = DatabaseService();
  final ImagePicker _picker = ImagePicker();
  
  bool _isProcessing = false;
  MedicationInfo? _result;

  @override
  void initState() {
    super.initState();
    if (widget.initialImage != null) {
      _processImage(widget.initialImage!);
    }
  }

  Future<void> _processImage(XFile image) async {
    setState(() {
      _isProcessing = true;
      _result = null;
    });

    final bytes = await image.readAsBytes();
    final info = await _geminiService.extractMedicationInfo(bytes);

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
        child: _isProcessing 
          ? _buildLoading() 
          : (_result != null ? _buildResult() : _buildPicker()),
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
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(strokeWidth: 6),
        SizedBox(height: 24),
        Text("AI 正在精读医嘱...", style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
      ],
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
                Text("AI 识别成功！", style: TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoTile("药名", _result!.name),
          _buildInfoTile("剂量", _result!.dosage),
          _buildInfoTile("频次", "每天 ${_result!.frequency} 次"),
          _buildInfoTile("时间点", _result!.times.join(", ")),
          _buildInfoTile("时机", _result!.timingNote),
          _buildInfoTile("注意事项", _result!.precautions, isWarning: true),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _confirmAndSave,
            child: const Text("确定，开启提醒"),
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
