import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 应用常量定义
class AppConstants {
  AppConstants._();

  // ==================== 模型相关常量 ====================

  /// Gemma 模型相关
  static const String gemmaModelId = 'gemma-4-E2B-it.litertlm';
  static const int minGemmaModelBytes = 2500000000; // 2.5GB

  /// ASR 模型相关
  static const String asrDirName =
      'sherpa-onnx-streaming-paraformer-bilingual-zh-en';
  static const String asrArchiveId =
      'sherpa-onnx-streaming-paraformer-bilingual-zh-en-int8.tar.gz';
  static const int minAsrArchiveBytes = 200 * 1024 * 1024; // 200MB
  static const int minAsrEncoderBytes = 100 * 1024 * 1024; // 100MB
  static const int minAsrDecoderBytes = 40 * 1024 * 1024; // 40MB

  /// TTS 模型相关
  static const String ttsDirName = 'kokoro-int8-multi-lang-v1_1';
  static const String ttsArchiveId = 'kokoro-int8-multi-lang-v1_1-tts.tar.gz';
  static const int minTtsArchiveBytes = 130 * 1024 * 1024; // 130MB
  static const String ttsModelId = 'model.int8.onnx';
  static const String ttsVoicesId = 'voices.bin';
  static const String ttsTokensId = 'tokens.txt';
  static const String ttsLexiconId = 'lexicon-zh.txt';
  static const String ttsDataDirId = 'espeak-ng-data';
  static const String ttsPhoneRuleId = 'phone-zh.fst';
  static const String ttsDateRuleId = 'date-zh.fst';
  static const String ttsNumberRuleId = 'number-zh.fst';
  static const String ttsPhondataId = 'espeak-ng-data/phondata';
  static const int minTtsModelBytes = 100 * 1024 * 1024; // 100MB
  static const int minTtsVoicesBytes = 40 * 1024 * 1024; // 40MB
  static const int minTtsLexiconBytes = 1024 * 1024; // 1MB
  static const int minTtsPhondataBytes = 100 * 1024; // 100KB
  static const int sweetFemaleVoiceSid = 47;

  // ==================== 下载相关常量 ====================

  /// 下载超时时间
  static const Duration downloadProgressTimeout = Duration(seconds: 90);
  static const Duration downloadElapsedInterval = Duration(seconds: 10);

  /// 下载配置
  static const int gemmaDownloadChunks = 16;
  static const int gemmaDownloadRetries = 5;
  static const int defaultDownloadChunks = 8;
  static const int defaultDownloadRetries = 3;

  // ==================== 网络相关常量 ====================

  /// HuggingFace 镜像地址
  static const String hfMirrorBaseUrl =
      'https://hf-mirror.com/kun110/yao-ji-qing-models/resolve/main';
  static const String huggingFaceBaseUrl =
      'https://huggingface.co/kun110/yao-ji-qing-models/resolve/main';
  static const String hfMirrorGemmaUrl =
      'https://hf-mirror.com/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/$gemmaModelId';
  static const String huggingFaceGemmaUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/$gemmaModelId';

  // ==================== AI 相关常量 ====================

  /// 对话参数
  static const double chatTemperature = 0.7;
  static const int chatTopK = 40;
  static const int chatMaxTokens = 2048;

  /// TTS 参数
  static const double ttsLengthScale = 1.15; // 语速调节
  static const int ttsNumThreads = 2;

  // ==================== 文件系统常量 ====================

  /// 目录名称
  static const String modelsDirName = 'models';
  static const String asrModelsDirName = 'models/asr';
  static const String ttsModelsDirName = 'models/tts';

  /// 文件大小格式化
  static const int bytesPerKB = 1024;
  static const int bytesPerMB = 1024 * 1024;
  static const int bytesPerGB = 1024 * 1024 * 1024;

  // ==================== UI 相关常量 ====================

  /// 颜色
  static const Color primaryColor = Color(0xFF3B82F6);
  static const Color secondaryColor = Color(0xFF10B981);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color backgroundColor = Color(0xFFF9FAFB);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color textPrimaryColor = Color(0xFF1F2937);
  static const Color textSecondaryColor = Color(0xFF6B7280);
  static const Color textTertiaryColor = Color(0xFF9CA3AF);

  /// 圆角
  static const double smallBorderRadius = 8.0;
  static const double mediumBorderRadius = 12.0;
  static const double largeBorderRadius = 16.0;
  static const double extraLargeBorderRadius = 24.0;

  /// 间距
  static const double tinySpacing = 4.0;
  static const double smallSpacing = 8.0;
  static const double mediumSpacing = 16.0;
  static const double largeSpacing = 24.0;
  static const double extraLargeSpacing = 32.0;

  // ==================== 提醒相关常量 ====================

  /// 默认提醒时间
  static const List<String> defaultReminderTimes = [
    '08:00',
    '12:00',
    '18:00',
  ];

  /// 提醒渠道ID
  static const String medicationReminderChannelId = 'medication_reminders';
  static const String medicationReminderChannelName = '用药提醒';
  static const String medicationReminderChannelDescription = '按时服药提醒通知';

  // ==================== 存储相关常量 ====================

  /// SharedPreferences 键名
  static const String autoSpeakKey = 'auto_speak';
  static const String firstLaunchKey = 'first_launch';
  static const String themeModeKey = 'theme_mode';
  static const String languageKey = 'language';

  /// Isar 数据库配置
  static const String isarDatabaseName = 'yao_ji_qing';
  static const int isarSchemaVersion = 1;

  // ==================== 平台相关常量 ====================

  /// iOS 限制
  static const bool iosSupportsImageConsultation = false;
  static const String iosRestartMessage =
      '安装完成。iOS 不允许应用自行重启，请从多任务界面关闭药记清后重新打开。';

  /// Android 最小 SDK
  static const int androidMinSdk = 21;

  // ==================== 调试相关常量 ====================

  static bool get isDebugMode => kDebugMode;

  static bool get isProfileMode => kProfileMode;

  static bool get isReleaseMode => kReleaseMode;
}
