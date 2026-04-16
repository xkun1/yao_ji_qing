import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../utils/config.dart';

class MedicationInfo {
  final String name;
  final String dosage;
  final int frequency;
  final List<String> times;
  final String timingNote;
  final String precautions;

  MedicationInfo({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.times,
    required this.timingNote,
    required this.precautions,
  });

  factory MedicationInfo.fromJson(Map<String, dynamic> json) {
    return MedicationInfo(
      name: json['medicine_name'] ?? '',
      dosage: json['dosage_per_time'] ?? '',
      frequency: json['frequency_daily'] ?? 0,
      times: List<String>.from(json['recommended_times'] ?? []),
      timingNote: json['timing_tag'] ?? '',
      precautions: json['precautions'] ?? '',
    );
  }
}

class GeminiService {
  final GenerativeModel _model;

  GeminiService()
      : _model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: AppConfig.geminiApiKey,
        );

  Future<MedicationInfo?> extractMedicationInfo(Uint8List imageBytes) async {
    try {
      final prompt = TextPart('''
你是一个专业的医疗助手。请分析这张包含药品说明或医嘱的照片。
请提取以下信息并严格以 JSON 格式返回，不要包含任何额外的解释文字：
{
  "medicine_name": "药品名称",
  "dosage_per_time": "每次剂量（如：2粒）",
  "frequency_daily": 每日服用次数（数字）,
  "recommended_times": ["建议服用时间点1（24小时制，如08:00）", "..."],
  "timing_tag": "服用时机（如：饭后、空腹）",
  "precautions": "注意事项或禁忌"
}
''');

      final content = [
        Content.multi([
          prompt,
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      final response = await _model.generateContent(content);
      final text = response.text;

      if (text != null) {
        // 简单的 JSON 提取逻辑
        final jsonStart = text.indexOf('{');
        final jsonEnd = text.lastIndexOf('}') + 1;
        if (jsonStart != -1 && jsonEnd != -1) {
          final jsonString = text.substring(jsonStart, jsonEnd);
          final Map<String, dynamic> data = jsonDecode(jsonString);
          return MedicationInfo.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      debugPrint('AI 识别出错: $e');
      return null;
    }
  }
}
