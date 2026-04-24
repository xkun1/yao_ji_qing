import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../core/constants.dart';
import '../../core/exceptions.dart';

/// TTS 处理器
class TtsHandler {
  TtsHandler._internal();

  static final TtsHandler _instance = TtsHandler._internal();

  factory TtsHandler() => _instance;

  sherpa.OfflineTts? _sherpaTts;
  bool _bindingsInitialized = false;
  bool _autoSpeak = false;

  sherpa.OfflineTts? get tts => _sherpaTts;
  bool get autoSpeak => _autoSpeak;

  set autoSpeak(bool value) {
    _autoSpeak = value;
    _saveSettings();
  }

  /// 初始化 TTS
  Future<void> init() async {
    if (_sherpaTts != null) return;

    try {
      final modelPath = await findModelPath();
      final voicesPath = await findVoicesPath();
      final tokensPath = await findTokensPath();
      final lexiconPath = await findLexiconPath();
      final dataDirPath = await findDataDirPath();
      final ruleFstPaths = await findRuleFstPaths();

      if (modelPath == null ||
          voicesPath == null ||
          tokensPath == null ||
          lexiconPath == null ||
          dataDirPath == null) {
        debugPrint('Kokoro TTS 关键文件未找到，将无法使用语音播报。');
        return;
      }

      // dataDir 必须指向包含 espeak-ng-data 的父目录
      final dataDirParentPath = Directory(dataDirPath).parent.path;

      final config = sherpa.OfflineTtsKokoroModelConfig(
        model: modelPath,
        voices: voicesPath,
        tokens: tokensPath,
        dataDir: dataDirParentPath,
        lexicon: lexiconPath,
        lang: 'zh',
        lengthScale: AppConstants.ttsLengthScale,
      );

      final ttsConfig = sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(
          kokoro: config,
          numThreads: AppConstants.ttsNumThreads,
          debug: false,
        ),
        ruleFsts: ruleFstPaths.join(','),
      );

      if (!_bindingsInitialized) {
        sherpa.initBindings();
        _bindingsInitialized = true;
      }
      _sherpaTts = sherpa.OfflineTts(ttsConfig);
      debugPrint('Kokoro TTS 全局初始化成功');
    } catch (e) {
      debugPrint('Sherpa TTS 初始化异常: $e');
      throw ModelException.loadFailed(cause: e);
    }
  }

  /// 查找 TTS 模型路径
  Future<String?> findModelPath() => _findTtsPath(AppConstants.ttsModelId);

  /// 查找 TTS 语音路径
  Future<String?> findVoicesPath() => _findTtsPath(AppConstants.ttsVoicesId);

  /// 查找 TTS tokens 路径
  Future<String?> findTokensPath() => _findTtsPath(AppConstants.ttsTokensId);

  /// 查找 TTS lexicon 路径
  Future<String?> findLexiconPath() => _findTtsPath(AppConstants.ttsLexiconId);

  /// 查找 TTS 数据目录路径
  Future<String?> findDataDirPath() => _findTtsPath(AppConstants.ttsDataDirId);

  /// 查找 TTS 规则 FST 路径
  Future<List<String>> findRuleFstPaths() async {
    final paths = await Future.wait([
      _findTtsPath(AppConstants.ttsPhoneRuleId),
      _findTtsPath(AppConstants.ttsDateRuleId),
      _findTtsPath(AppConstants.ttsNumberRuleId),
    ]);
    return paths.nonNulls.toList();
  }

  /// 检查 TTS 文件是否存在
  Future<bool> checkFilesExist() async {
    final modelPath = await findModelPath();
    final voicesPath = await findVoicesPath();
    final tokensPath = await findTokensPath();
    final lexiconPath = await findLexiconPath();
    final dataDirPath = await findDataDirPath();
    final phondataPath = await _findTtsPath(AppConstants.ttsPhondataId);

    return await _fileExistsWithMinBytes(modelPath, AppConstants.minTtsModelBytes) &&
        await _fileExistsWithMinBytes(voicesPath, AppConstants.minTtsVoicesBytes) &&
        await _fileExistsWithMinBytes(tokensPath, 1) &&
        await _fileExistsWithMinBytes(lexiconPath, AppConstants.minTtsLexiconBytes) &&
        dataDirPath != null &&
        await _fileExistsWithMinBytes(phondataPath, AppConstants.minTtsPhondataBytes);
  }

  /// 查找 TTS 路径
  Future<String?> _findTtsPath(String relativePath) async {
    final extDir = Platform.isAndroid ? await getExternalStorageDirectory() : null;
    final intDir = await getApplicationDocumentsDirectory();
    final possiblePaths = <String>[];

    if (extDir != null) {
      possiblePaths.add('${extDir.path}/${AppConstants.ttsDirName}/$relativePath');
      possiblePaths.add('${extDir.path}/${AppConstants.ttsModelsDirName}/${AppConstants.ttsDirName}/$relativePath');
      possiblePaths.add('${extDir.path}/${AppConstants.modelsDirName}/${AppConstants.ttsDirName}/$relativePath');
      possiblePaths.add('${extDir.path}/files/${AppConstants.ttsDirName}/$relativePath');
    }
    possiblePaths.add('${intDir.path}/${AppConstants.ttsDirName}/$relativePath');
    possiblePaths.add('${intDir.path}/${AppConstants.ttsModelsDirName}/${AppConstants.ttsDirName}/$relativePath');
    possiblePaths.add('${intDir.path}/${AppConstants.modelsDirName}/${AppConstants.ttsDirName}/$relativePath');

    for (final path in possiblePaths) {
      if (await FileSystemEntity.type(path) != FileSystemEntityType.notFound) {
        return path;
      }
    }
    return null;
  }

  /// 检查文件是否存在且达到最小字节数
  Future<bool> _fileExistsWithMinBytes(String? path, int minBytes) async {
    if (path == null) return false;
    final file = File(path);
    return await file.exists() && await file.length() >= minBytes;
  }

  /// 删除 TTS 模型
  Future<void> deleteModel() async {
    final path = await findModelPath();
    if (path != null) {
      final dir = Directory(path).parent;
      if (await dir.exists() && dir.path.contains(AppConstants.ttsDirName)) {
        await dir.delete(recursive: true);
      }
    }
    _sherpaTts = null;
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    // 这里需要使用 SharedPreferences
    // 暂时留空，后续在主服务中实现
  }

  /// 清理资源
  void dispose() {
    _sherpaTts = null;
  }
}