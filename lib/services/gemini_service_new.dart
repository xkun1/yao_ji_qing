import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:background_downloader/background_downloader.dart';

import '../core/constants.dart';
import '../core/exceptions.dart';
import '../utils/compression_utils.dart';
import '../utils/file_utils.dart';
import 'gemini/asr_handler.dart';
import 'gemini/chat_handler.dart';
import 'gemini/model_downloader.dart';
import 'gemini/tts_handler.dart';

/// Gemini 服务 - 重构后的主服务类
class GeminiService {
  GeminiService._internal() {
    _downloader.init();
  }

  static final GeminiService _instance = GeminiService._internal();

  factory GeminiService() => _instance;

  // 子模块
  final ModelDownloader _downloader = ModelDownloader();
  final ChatHandler _chatHandler = ChatHandler();
  final TtsHandler _ttsHandler = TtsHandler();
  final AsrHandler _asrHandler = AsrHandler();

  // 振动通道
  final _vibrationChannel = const MethodChannel('yao_ji_qing/medication_vibration');

  // 下载更新流
  Stream get downloadUpdates => _downloader.downloadUpdates;
  ModelDownloadSnapshot get modelDownloadSnapshot => _downloader.downloadSnapshot;

  // TTS 相关
  bool get autoSpeak => _ttsHandler.autoSpeak;

  set autoSpeak(bool value) {
    _ttsHandler.autoSpeak = value;
  }

  // 聊天相关
  bool get supportsImageConsultation => _chatHandler.supportsImageConsultation;

  /// 初始化服务
  Future<void> init() async {
    await loadSettings();
    await _chatHandler.ensureInitialized();
  }

  /// 加载设置
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _ttsHandler.autoSpeak = prefs.getBool(AppConstants.autoSpeakKey) ?? false;
  }

  /// 保存设置
  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.autoSpeakKey, _ttsHandler.autoSpeak);
  }

  /// 初始化 TTS
  Future<void> initTts() async {
    await _ttsHandler.init();
  }

  /// 获取 TTS 实例
  dynamic get tts => _ttsHandler.tts;

  /// 下载 Gemma 模型
  Future<void> downloadModel() async {
    try {
      await _chatHandler.ensureInitialized();

      final existingPath = await _chatHandler.findExistingModelPath();
      if (existingPath != null) {
        _downloader.setDownloadStage('gemma', 1, '正在激活本地模型');
        await FlutterGemma.installModel(
          modelType: ModelType.gemmaIt,
          fileType: ModelFileType.litertlm,
        ).fromFile(existingPath).install();
        _downloader.setDownloadStage('gemma', 1, '下载完成，正在重启...');
        await restartApp();
        _downloader.clearDownloadSnapshot();
        return;
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final modelRoot = Directory('${docsDir.path}/${AppConstants.modelsDirName}');
      await modelRoot.create(recursive: true);
      final targetFile = File('${modelRoot.path}/${AppConstants.gemmaModelId}');
      if (await targetFile.exists() &&
          await targetFile.length() < AppConstants.minGemmaModelBytes) {
        await targetFile.delete();
      }

      FileDownloader().configureNotification(
        running: const TaskNotification('正在下载 AI 引擎', '已完成 {progress}'),
        complete: const TaskNotification('下载完成', '正在重启...'),
        progressBar: true,
      );

      await _downloader.downloadModel(
        type: 'gemma',
        filename: AppConstants.gemmaModelId,
        directory: AppConstants.modelsDirName,
        urls: _getGemmaModelUrls(),
        minBytes: AppConstants.minGemmaModelBytes,
        modelName: 'Gemma4 模型',
      );
      _downloader.setDownloadStage('gemma', 1, '下载完成，正在重启...');
      await restartApp();
      _downloader.clearDownloadSnapshot();
    } catch (_) {
      _downloader.clearDownloadSnapshot();
      rethrow;
    }
  }

  /// 下载 ASR 模型
  Future<void> downloadAsrModel() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final modelRoot = Directory('${docsDir.path}/${AppConstants.asrModelsDirName}');
      final targetDir = Directory('${modelRoot.path}/${AppConstants.asrDirName}');
      await targetDir.create(recursive: true);

      FileDownloader().configureNotification(
        running: const TaskNotification('正在下载语音识别引擎', '已完成 {progress}'),
        complete: const TaskNotification('下载完成', '正在解压并准备...'),
        progressBar: true,
      );

      await _downloader.downloadModel(
        type: 'asr',
        filename: AppConstants.asrArchiveId,
        directory: AppConstants.asrModelsDirName,
        urls: _getReleaseAssetUrls(AppConstants.asrArchiveId),
        minBytes: AppConstants.minAsrArchiveBytes,
        modelName: 'ASR 模型',
      );
      _downloader.setDownloadStage('asr', 1, '正在解压语音识别模型');
      await CompressionUtils.extractTarGz(
        File('${modelRoot.path}/${AppConstants.asrArchiveId}'),
        targetDir,
      );
      await FileUtils.deleteFile('${modelRoot.path}/${AppConstants.asrArchiveId}');
      _downloader.setDownloadStage('asr', 1, '下载完成，正在重启...');
      await restartApp();
      _downloader.clearDownloadSnapshot();
    } catch (_) {
      _downloader.clearDownloadSnapshot();
      rethrow;
    }
  }

  /// 下载 TTS 模型
  Future<void> downloadTtsModel() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final modelRoot = Directory('${docsDir.path}/${AppConstants.ttsModelsDirName}');
      final targetDir = Directory('${modelRoot.path}/${AppConstants.ttsDirName}');
      await targetDir.create(recursive: true);

      FileDownloader().configureNotification(
        running: const TaskNotification('正在下载语音合成引擎', '已完成 {progress}'),
        complete: const TaskNotification('下载完成', '正在解压并准备...'),
        progressBar: true,
      );

      await _downloader.downloadModel(
        type: 'tts',
        filename: AppConstants.ttsArchiveId,
        directory: AppConstants.ttsModelsDirName,
        urls: _getReleaseAssetUrls(AppConstants.ttsArchiveId),
        minBytes: AppConstants.minTtsArchiveBytes,
        modelName: 'TTS 模型',
      );
      _downloader.setDownloadStage('tts', 1, '正在解压语音合成模型');
      await CompressionUtils.extractTarGz(
        File('${modelRoot.path}/${AppConstants.ttsArchiveId}'),
        targetDir,
        stripFirstPathComponent: true,
      );
      await FileUtils.deleteFile('${modelRoot.path}/${AppConstants.ttsArchiveId}');
      _downloader.setDownloadStage('tts', 1, '下载完成，正在重启...');
      await restartApp();
      _downloader.clearDownloadSnapshot();
    } catch (_) {
      _downloader.clearDownloadSnapshot();
      rethrow;
    }
  }

  /// 删除 Gemma 模型
  Future<void> deleteModel() async {
    final path = await _chatHandler.getModelPathForDeletion();
    await FileUtils.deleteFile(path);
  }

  /// 删除 ASR 模型
  Future<void> deleteAsrModel() async {
    await _asrHandler.deleteModel();
  }

  /// 删除 TTS 模型
  Future<void> deleteTtsModel() async {
    await _ttsHandler.deleteModel();
  }

  /// 获取模型状态
  Future<ModelState> getModelState() async {
    return await _chatHandler.getModelState();
  }

  /// 检查模型是否就绪
  Future<bool> isModelReady() async {
    return await _chatHandler.isModelReady();
  }

  /// 检查文件是否存在
  Future<bool> isFilePresent() async {
    return await _chatHandler.isFilePresent();
  }

  /// 检查 ASR 文件是否存在
  Future<bool> checkAsrFilesExist() async {
    return await _asrHandler.checkFilesExist();
  }

  /// 检查 TTS 文件是否存在
  Future<bool> checkTtsFilesExist() async {
    return await _ttsHandler.checkFilesExist();
  }

  /// 咨询药师
  Future<String> askPharmacist(
    String userText, {
    List<ChatMessage> history = const [],
    List<String> keywords = const [],
    Uint8List? imageBytes,
    Function(String)? onStream,
  }) async {
    return await _chatHandler.askPharmacist(
      userText,
      history: history,
      keywords: keywords,
      imageBytes: imageBytes,
      onStream: onStream,
    );
  }

  /// 提取药物信息
  Future<MedicationInfo?> extractMedicationInfo(
    Uint8List imageBytes, {
    Function(String)? onStream,
  }) async {
    return await _chatHandler.extractMedicationInfo(
      imageBytes,
      onStream: onStream,
    );
  }

  /// 获取下载快照
  ModelDownloadSnapshot? downloadSnapshotForFilename(String filename, {double progress = -1}) {
    return _downloader.getSnapshotForFilename(filename, progress: progress);
  }

  /// 获取 Gemma 模型 URL
  List<String> _getGemmaModelUrls() {
    return [
      '${AppConstants.hfMirrorBaseUrl}/${AppConstants.gemmaModelId}',
      AppConstants.hfMirrorGemmaUrl,
      '${AppConstants.huggingFaceBaseUrl}/${AppConstants.gemmaModelId}',
      AppConstants.huggingFaceGemmaUrl,
    ];
  }

  /// 获取资源 URL
  List<String> _getReleaseAssetUrls(String filename) {
    return [
      '${AppConstants.hfMirrorBaseUrl}/$filename',
      '${AppConstants.huggingFaceBaseUrl}/$filename',
    ];
  }

  /// 重启应用
  Future<void> restartApp() async {
    try {
      if (Platform.isAndroid) {
        await _vibrationChannel.invokeMethod('restartApp');
      } else {
        throw ModelException.incompatible();
      }
    } catch (e) {
      if (e is ModelException) rethrow;
      debugPrint('重启指令发送失败: $e');
    }
  }

  /// 获取模型路径用于删除
  Future<String> getModelPathForDeletion() async {
    return await _chatHandler.getModelPathForDeletion();
  }

  /// 获取 ASR 模型路径用于删除
  Future<String> getAsrModelPathForDeletion() async {
    return await _asrHandler.getModelPathForDeletion();
  }

  /// 保存 WAV 文件
  Future<String> saveWav(Float32List samples, int sampleRate, String fileName) async {
    return await FileUtils.saveWav(samples, sampleRate, fileName);
  }

  /// 清理资源
  void dispose() {
    _downloader.dispose();
    _ttsHandler.dispose();
    _chatHandler.dispose();
  }
}

// 导出类型别名（需要在类外部定义）
typedef ChatHandlerMessage = ChatMessage;
typedef MedicationInfoAlias = MedicationInfo;
typedef ModelStateAlias = ModelState;
typedef ModelDownloadSnapshotAlias = ModelDownloadSnapshot;