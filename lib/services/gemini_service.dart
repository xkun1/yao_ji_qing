import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:background_downloader/background_downloader.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

enum ModelState { ready, fileDetected, none, checking }

typedef ActiveModelGetter = Future<InferenceModel> Function({
  required int maxTokens,
  PreferredBackend? preferredBackend,
  bool supportImage,
});

class GeminiChatException implements Exception {
  GeminiChatException(this.userMessage, {this.cause});

  final String userMessage;
  final Object? cause;

  @override
  String toString() =>
      'GeminiChatException(userMessage: $userMessage, cause: $cause)';
}

class MedicationInfo {
  final String name;
  final String dosage;
  final int frequency;
  final List<String> times;
  final String precautions;

  MedicationInfo({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.times,
    required this.precautions,
  });

  factory MedicationInfo.fromJson(Map<String, dynamic> json) {
    int parseFreq(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return MedicationInfo(
      name: json['medicine_name']?.toString() ?? '',
      dosage: json['dosage_per_time']?.toString() ?? '',
      frequency: parseFreq(json['frequency_daily']),
      times: List<String>.from(json['recommended_times'] ?? []),
      precautions: json['precautions']?.toString() ?? '',
    );
  }
}

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

class _ByteStreamReader {
  _ByteStreamReader(Stream<List<int>> stream)
      : _iterator = StreamIterator(stream);

  final StreamIterator<List<int>> _iterator;
  Uint8List _buffer = Uint8List(0);
  int _offset = 0;
  bool _isDone = false;

  Future<Uint8List?> readExactly(int byteCount) async {
    if (byteCount == 0) return Uint8List(0);

    var remaining = byteCount;
    final output = BytesBuilder(copy: false);
    while (remaining > 0) {
      if (!await _ensureBuffer()) {
        if (output.isEmpty) return null;
        throw GeminiChatException('模型压缩包数据不完整。');
      }

      final available = _buffer.length - _offset;
      final take = remaining < available ? remaining : available;
      output.add(Uint8List.sublistView(_buffer, _offset, _offset + take));
      _offset += take;
      remaining -= take;
    }
    return output.takeBytes();
  }

  Future<void> pipeBytes(int byteCount, IOSink sink) async {
    var remaining = byteCount;
    while (remaining > 0) {
      if (!await _ensureBuffer()) {
        throw GeminiChatException('模型压缩包数据不完整。');
      }

      final available = _buffer.length - _offset;
      final take = remaining < available ? remaining : available;
      sink.add(Uint8List.sublistView(_buffer, _offset, _offset + take));
      _offset += take;
      remaining -= take;
    }
  }

  Future<void> skip(int byteCount) async {
    var remaining = byteCount;
    while (remaining > 0) {
      if (!await _ensureBuffer()) {
        throw GeminiChatException('模型压缩包数据不完整。');
      }

      final available = _buffer.length - _offset;
      final take = remaining < available ? remaining : available;
      _offset += take;
      remaining -= take;
    }
  }

  Future<bool> _ensureBuffer() async {
    while (_offset >= _buffer.length) {
      if (_isDone) return false;
      if (!await _iterator.moveNext()) {
        _isDone = true;
        return false;
      }
      _buffer = Uint8List.fromList(_iterator.current);
      _offset = 0;
    }
    return true;
  }
}

class GeminiService {
  GeminiService._internal() {
    _initDownloaderListener();
  }

  static final GeminiService _instance = GeminiService._internal();

  factory GeminiService() => _instance;

  static const String _hfMirrorModelBaseUrl =
      'https://hf-mirror.com/kun110/yao-ji-qing-models/resolve/main';
  static const String _huggingFaceModelBaseUrl =
      'https://huggingface.co/kun110/yao-ji-qing-models/resolve/main';

  static const String _modelId = 'gemma-4-E2B-it.litertlm';
  static const int _minGemmaModelBytes = 2500000000;
  static const String _hfMirrorGemmaModelUrl =
      'https://hf-mirror.com/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/$_modelId';
  static const String _huggingFaceGemmaModelUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/$_modelId';

  // ASR 模型相关 (Paraformer 流式)
  static const String _asrDirName =
      'sherpa-onnx-streaming-paraformer-bilingual-zh-en';
  static const String _asrArchiveId =
      'sherpa-onnx-streaming-paraformer-bilingual-zh-en-int8.tar.gz';
  static const int _minAsrArchiveBytes = 200 * 1024 * 1024;
  static const int _minAsrEncoderBytes = 100 * 1024 * 1024;
  static const int _minAsrDecoderBytes = 40 * 1024 * 1024;

  // TTS 模型相关（Kokoro 中文甜美女声）
  static const String _ttsDirName = 'kokoro-int8-multi-lang-v1_1';
  static const String _ttsArchiveId = 'kokoro-int8-multi-lang-v1_1-tts.tar.gz';
  static const int _minTtsArchiveBytes = 130 * 1024 * 1024;
  static const String _ttsModelId = 'model.int8.onnx';
  static const String _ttsVoicesId = 'voices.bin';
  static const String _ttsTokensId = 'tokens.txt';
  static const String _ttsLexiconId = 'lexicon-zh.txt';
  static const String _ttsDataDirId = 'espeak-ng-data';
  static const String _ttsPhoneRuleId = 'phone-zh.fst';
  static const String _ttsDateRuleId = 'date-zh.fst';
  static const String _ttsNumberRuleId = 'number-zh.fst';
  static const String _ttsPhondataId = 'espeak-ng-data/phondata';
  static const int _minTtsModelBytes = 100 * 1024 * 1024;
  static const int _minTtsVoicesBytes = 40 * 1024 * 1024;
  static const int _minTtsLexiconBytes = 1024 * 1024;
  static const int _minTtsPhondataBytes = 100 * 1024;

  static const int sweetFemaleVoiceSid = 47;
  sherpa.OfflineTts? _sherpaTts;
  bool _sherpaBindingsInitialized = false;
  bool _autoSpeak = false;

  sherpa.OfflineTts? get tts => _sherpaTts;
  bool get autoSpeak => _autoSpeak;

  set autoSpeak(bool value) {
    _autoSpeak = value;
    _saveSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _autoSpeak = prefs.getBool('auto_speak') ?? false;
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_speak', _autoSpeak);
  }

  Future<void> initTts() async {
    if (_sherpaTts != null) return;

    try {
      final modelPath = await findTtsModelPath();
      final voicesPath = await findTtsVoicesPath();
      final tokensPath = await findTtsTokensPath();
      final lexiconPath = await findTtsLexiconPath();
      final dataDirPath = await findTtsDataDirPath();
      final ruleFstPaths = await findTtsRuleFstPaths();

      if (modelPath == null ||
          voicesPath == null ||
          tokensPath == null ||
          lexiconPath == null ||
          dataDirPath == null) {
        debugPrint('Kokoro TTS 关键文件未找到，将无法使用语音播报。');
        return;
      }

      // 核心修正：dataDir 必须指向包含 espeak-ng-data 的父目录
      final dataDirParentPath = Directory(dataDirPath).parent.path;

      final config = sherpa.OfflineTtsKokoroModelConfig(
        model: modelPath,
        voices: voicesPath,
        tokens: tokensPath,
        dataDir: dataDirParentPath,
        lexicon: lexiconPath,
        lang: 'zh',
        lengthScale: 1.15, // 稍微放慢语速，更甜美
      );

      final ttsConfig = sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(
          kokoro: config,
          numThreads: 2,
          debug: false, // 关闭调试日志，极大提升 FFI 调用速度
        ),
        ruleFsts: ruleFstPaths.join(','),
      );

      if (!_sherpaBindingsInitialized) {
        sherpa.initBindings();
        _sherpaBindingsInitialized = true;
      }
      _sherpaTts = sherpa.OfflineTts(ttsConfig);
      debugPrint('Kokoro TTS 全局初始化成功');
    } catch (e) {
      debugPrint('Sherpa TTS 初始化异常: $e');
    }
  }

  @visibleForTesting
  static Future<void> Function() initializationRunner = FlutterGemma.initialize;

  @visibleForTesting
  static Future<bool> Function(String modelId) modelInstalledChecker =
      FlutterGemma.isModelInstalled;

  @visibleForTesting
  static Future<String?> Function()? existingModelPathFinderOverride;

  @visibleForTesting
  static ActiveModelGetter activeModelGetter = ({
    required int maxTokens,
    PreferredBackend? preferredBackend,
    bool supportImage = false,
  }) {
    return FlutterGemma.getActiveModel(
      maxTokens: maxTokens,
      preferredBackend: preferredBackend,
      supportImage: supportImage,
    );
  };

  final _vibrationChannel =
      const MethodChannel('yao_ji_qing/medication_vibration');
  final _progressController = StreamController<TaskUpdate>.broadcast();
  ModelDownloadSnapshot _modelDownloadSnapshot =
      const ModelDownloadSnapshot(isActive: false);

  Stream<TaskUpdate> get downloadUpdates => _progressController.stream;
  ModelDownloadSnapshot get modelDownloadSnapshot => _modelDownloadSnapshot;

  ModelDownloadSnapshot? downloadSnapshotForFilename(
    String filename, {
    double progress = -1,
  }) {
    final type = _modelDownloadTypeFromFilename(filename);
    if (type == null) return null;
    return ModelDownloadSnapshot(
      isActive: true,
      type: type,
      progress: _normalizeModelDownloadProgress(type, filename, progress),
      status: _modelDownloadStatusText(type, filename),
    );
  }

  PreferredBackend? _cachedBackend;
  Future<void>? _initialization;

  List<String> _releaseAssetUrls(String filename) {
    return [
      '$_hfMirrorModelBaseUrl/$filename',
      '$_huggingFaceModelBaseUrl/$filename',
    ];
  }

  List<String> _gemmaModelUrls() {
    return [
      '$_hfMirrorModelBaseUrl/$_modelId',
      _hfMirrorGemmaModelUrl,
      '$_huggingFaceModelBaseUrl/$_modelId',
      _huggingFaceGemmaModelUrl,
    ];
  }

  Future<void> ensureInitialized() {
    final existing = _initialization;
    if (existing != null) return existing;

    late final Future<void> future;
    future = initializationRunner().catchError((error, stackTrace) {
      if (identical(_initialization, future)) {
        _initialization = null;
      }
      Error.throwWithStackTrace(error, stackTrace);
    });
    _initialization = future;
    return future;
  }

  @visibleForTesting
  void resetInitializationState() {
    _initialization = null;
    _cachedBackend = null;
  }

  @visibleForTesting
  void resetTestingOverrides() {
    initializationRunner = FlutterGemma.initialize;
    modelInstalledChecker = FlutterGemma.isModelInstalled;
    existingModelPathFinderOverride = null;
    activeModelGetter = ({
      required int maxTokens,
      PreferredBackend? preferredBackend,
      bool supportImage = false,
    }) {
      return FlutterGemma.getActiveModel(
        maxTokens: maxTokens,
        preferredBackend: preferredBackend,
        supportImage: supportImage,
      );
    };
  }

  void _initDownloaderListener() {
    FileDownloader().updates.listen((update) {
      if (update is TaskProgressUpdate) {
        _updateModelDownloadProgress(update);
      }
      _progressController.add(update);
    });
  }

  Future<PreferredBackend> _detectBestBackend() async {
    if (_cachedBackend != null) return _cachedBackend!;

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final hardware = androidInfo.hardware.toLowerCase();
      final manufacturer = androidInfo.manufacturer.toLowerCase();
      if (manufacturer.contains('huawei') || hardware.contains('kirin')) {
        _cachedBackend = PreferredBackend.cpu;
      } else if (hardware.contains('qcom') ||
          hardware.contains('mt') ||
          hardware.contains('tensor')) {
        _cachedBackend = PreferredBackend.npu;
      } else {
        _cachedBackend = PreferredBackend.gpu;
      }
    } else {
      _cachedBackend = PreferredBackend.gpu;
    }
    return _cachedBackend!;
  }

  Future<String?> findExistingModelPath() async {
    final override = existingModelPathFinderOverride;
    if (override != null) return override();

    final possiblePaths = <String>[];
    final extDir =
        Platform.isAndroid ? await getExternalStorageDirectory() : null;
    if (extDir != null) {
      possiblePaths.add('${extDir.path}/$_modelId');
      possiblePaths.add('${extDir.path}/models/$_modelId');
      possiblePaths.add('${extDir.path}/files/$_modelId');
    }
    final intDir = await getApplicationDocumentsDirectory();
    possiblePaths.add('${intDir.path}/$_modelId');
    possiblePaths.add('${intDir.path}/models/$_modelId');

    for (final path in possiblePaths) {
      final file = File(path);
      if (await file.exists() && await file.length() >= _minGemmaModelBytes) {
        return path;
      }
    }
    return null;
  }

  Future<String?> _findTtsPath(String relativePath) async {
    final extDir =
        Platform.isAndroid ? await getExternalStorageDirectory() : null;
    final intDir = await getApplicationDocumentsDirectory();
    final possiblePaths = <String>[];

    if (extDir != null) {
      possiblePaths.add('${extDir.path}/$_ttsDirName/$relativePath');
      possiblePaths.add('${extDir.path}/models/tts/$_ttsDirName/$relativePath');
      possiblePaths.add('${extDir.path}/models/$_ttsDirName/$relativePath');
      possiblePaths.add('${extDir.path}/files/$_ttsDirName/$relativePath');
    }
    possiblePaths.add('${intDir.path}/$_ttsDirName/$relativePath');
    possiblePaths.add('${intDir.path}/models/tts/$_ttsDirName/$relativePath');
    possiblePaths.add('${intDir.path}/models/$_ttsDirName/$relativePath');

    for (final path in possiblePaths) {
      if (await FileSystemEntity.type(path) != FileSystemEntityType.notFound) {
        return path;
      }
    }
    return null;
  }

  Future<String?> findTtsModelPath() => _findTtsPath(_ttsModelId);

  Future<String?> findTtsVoicesPath() => _findTtsPath(_ttsVoicesId);

  Future<String?> findTtsTokensPath() async {
    return _findTtsPath(_ttsTokensId);
  }

  Future<String?> findTtsLexiconPath() async {
    return _findTtsPath(_ttsLexiconId);
  }

  Future<String?> findTtsDataDirPath() => _findTtsPath(_ttsDataDirId);

  Future<List<String>> findTtsRuleFstPaths() async {
    final paths = await Future.wait([
      _findTtsPath(_ttsPhoneRuleId),
      _findTtsPath(_ttsDateRuleId),
      _findTtsPath(_ttsNumberRuleId),
    ]);
    return paths.nonNulls.toList();
  }

  Future<bool> checkTtsFilesExist() async {
    final modelPath = await findTtsModelPath();
    final voicesPath = await findTtsVoicesPath();
    final tokensPath = await findTtsTokensPath();
    final lexiconPath = await findTtsLexiconPath();
    final dataDirPath = await findTtsDataDirPath();
    final phondataPath = await _findTtsPath(_ttsPhondataId);

    return await _fileExistsWithMinBytes(modelPath, _minTtsModelBytes) &&
        await _fileExistsWithMinBytes(voicesPath, _minTtsVoicesBytes) &&
        await _fileExistsWithMinBytes(tokensPath, 1) &&
        await _fileExistsWithMinBytes(lexiconPath, _minTtsLexiconBytes) &&
        dataDirPath != null &&
        await _fileExistsWithMinBytes(phondataPath, _minTtsPhondataBytes);
  }

  Future<String?> findAsrModelPath() async {
    final extDir =
        Platform.isAndroid ? await getExternalStorageDirectory() : null;
    final intDir = await getApplicationDocumentsDirectory();
    final possiblePaths = <String>[];

    if (extDir != null) {
      possiblePaths.add('${extDir.path}/models/asr/$_asrDirName');
      possiblePaths.add('${extDir.path}/$_asrDirName');
    }
    possiblePaths.add('${intDir.path}/models/asr/$_asrDirName');
    possiblePaths.add('${intDir.path}/$_asrDirName');

    for (final path in possiblePaths) {
      final dir = Directory(path);
      if (await _hasAsrModelFiles(dir)) return path;
    }
    return null;
  }

  Future<bool> checkAsrFilesExist() async {
    return (await findAsrModelPath()) != null;
  }

  Future<bool> _hasAsrModelFiles(Directory dir) async {
    if (!await dir.exists()) return false;

    var hasTokens = false;
    var hasEncoder = false;
    var hasDecoder = false;

    try {
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.path.split(RegExp(r'[/\\]')).last.toLowerCase();
        final size = await entity.length();
        if (name == 'tokens.txt' && size > 0) hasTokens = true;
        if (name.endsWith('.onnx') &&
            name.contains('encoder') &&
            size >= _minAsrEncoderBytes) {
          hasEncoder = true;
        }
        if (name.endsWith('.onnx') &&
            name.contains('decoder') &&
            size >= _minAsrDecoderBytes) {
          hasDecoder = true;
        }
        if (hasTokens && hasEncoder && hasDecoder) return true;
      }
    } catch (_) {
      return false;
    }

    return false;
  }

  Future<bool> _fileExistsWithMinBytes(String? path, int minBytes) async {
    if (path == null) return false;
    final file = File(path);
    return await file.exists() && await file.length() >= minBytes;
  }

  Future<void> downloadAsrModel() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final modelRoot = Directory('${docsDir.path}/models/asr');
      final targetDir = Directory('${modelRoot.path}/$_asrDirName');
      await targetDir.create(recursive: true);

      FileDownloader().configureNotification(
        running: const TaskNotification('正在下载语音识别引擎', '已完成 {progress}'),
        complete: const TaskNotification('下载完成', '正在解压并准备...'),
        progressBar: true,
      );

      await _downloadReleaseAsset(
        urls: _releaseAssetUrls(_asrArchiveId),
        filename: _asrArchiveId,
        directory: 'models/asr',
        modelName: 'ASR 模型',
        minBytes: _minAsrArchiveBytes,
      );
      _setModelDownloadStage('asr', 1, '正在解压语音识别模型');
      await _extractTarGz(
        File('${modelRoot.path}/$_asrArchiveId'),
        targetDir,
      );
      await _deleteFiles([File('${modelRoot.path}/$_asrArchiveId')]);
      _setModelDownloadStage('asr', 1, '下载完成，正在重启...');
      await restartApp();
      _clearModelDownloadSnapshot();
    } catch (_) {
      _clearModelDownloadSnapshot();
      rethrow;
    }
  }

  Future<void> downloadTtsModel() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final modelRoot = Directory('${docsDir.path}/models/tts');
      final targetDir = Directory('${modelRoot.path}/$_ttsDirName');
      await targetDir.create(recursive: true);

      FileDownloader().configureNotification(
        running: const TaskNotification('正在下载语音合成引擎', '已完成 {progress}'),
        complete: const TaskNotification('下载完成', '正在解压并准备...'),
        progressBar: true,
      );

      await _downloadReleaseAsset(
        urls: _releaseAssetUrls(_ttsArchiveId),
        filename: _ttsArchiveId,
        directory: 'models/tts',
        modelName: 'TTS 模型',
        minBytes: _minTtsArchiveBytes,
      );
      _setModelDownloadStage('tts', 1, '正在解压语音合成模型');
      await _extractTarGz(
        File('${modelRoot.path}/$_ttsArchiveId'),
        targetDir,
        stripFirstPathComponent: true,
      );
      await _deleteFiles([File('${modelRoot.path}/$_ttsArchiveId')]);
      _setModelDownloadStage('tts', 1, '下载完成，正在重启...');
      await restartApp();
      _clearModelDownloadSnapshot();
    } catch (_) {
      _clearModelDownloadSnapshot();
      rethrow;
    }
  }

  Future<void> deleteAsrModel() async {
    final path = await findAsrModelPath();
    if (path != null) {
      final dir = Directory(path);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }
  }

  Future<void> deleteTtsModel() async {
    final path = await findTtsModelPath();
    if (path != null) {
      // TTS 路径通常指向文件，我们需要删除其所在的整个模型文件夹
      final dir = Directory(path).parent;
      if (await dir.exists() && dir.path.contains(_ttsDirName)) {
        await dir.delete(recursive: true);
      }
    }
    _sherpaTts = null; // 清空内存实例
  }

  Future<String> getAsrModelPathForDeletion() async {
    final path = await findAsrModelPath();
    if (path != null) return path;
    final intDir = await getApplicationDocumentsDirectory();
    return '${intDir.path}/models/asr/$_asrDirName';
  }

  Future<ModelState> getModelState() async {
    await ensureInitialized();
    if (await modelInstalledChecker(_modelId)) return ModelState.ready;
    if ((await findExistingModelPath()) != null) return ModelState.fileDetected;
    return ModelState.none;
  }

  Future<bool> isModelReady() async {
    return (await getModelState()) == ModelState.ready;
  }

  Future<bool> isFilePresent() async {
    return (await findExistingModelPath()) != null;
  }

  Future<void> downloadModel() async {
    try {
      await ensureInitialized();

      final existingPath = await findExistingModelPath();
      if (existingPath != null) {
        _setModelDownloadStage('gemma', 1, '正在激活本地模型');
        await FlutterGemma.installModel(
          modelType: ModelType.gemmaIt,
          fileType: ModelFileType.litertlm,
        ).fromFile(existingPath).install();
        _setModelDownloadStage('gemma', 1, '下载完成，正在重启...');
        await restartApp();
        _clearModelDownloadSnapshot();
        return;
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final modelRoot = Directory('${docsDir.path}/models');
      await modelRoot.create(recursive: true);
      final targetFile = File('${modelRoot.path}/$_modelId');
      if (await targetFile.exists() &&
          await targetFile.length() < _minGemmaModelBytes) {
        await targetFile.delete();
      }

      FileDownloader().configureNotification(
        running: const TaskNotification('正在下载 AI 引擎', '已完成 {progress}'),
        complete: const TaskNotification('下载完成', '正在重启...'),
        progressBar: true,
      );

      await _downloadReleaseAsset(
        urls: _gemmaModelUrls(),
        filename: _modelId,
        directory: 'models',
        modelName: 'Gemma4 模型',
        minBytes: _minGemmaModelBytes,
      );
      _setModelDownloadStage('gemma', 1, '下载完成，正在重启...');
      await restartApp();
      _clearModelDownloadSnapshot();
    } catch (_) {
      _clearModelDownloadSnapshot();
      rethrow;
    }
  }

  Future<void> _downloadReleaseAsset({
    required List<String> urls,
    required String filename,
    required String directory,
    required String modelName,
    required int minBytes,
  }) async {
    _setModelDownloadSnapshot(filename, 0);
    TaskStatusUpdate? lastResult;
    for (final url in urls) {
      debugPrint('正在启动$modelName下载: $url');
      final task = _createModelDownloadTask(
        url: url,
        filename: filename,
        directory: directory,
      );
      final result = await FileDownloader().download(
        task,
        onStatus: (status) {
          debugPrint('$modelName下载状态: $status');
        },
        onProgress: (progress) {
          _setModelDownloadSnapshot(filename, progress);
          _progressController.add(TaskProgressUpdate(task, progress));
        },
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
        _setModelDownloadSnapshot(filename, 1);
        return;
      }
      lastResult = result;
      debugPrint(
        '$modelName下载失败，尝试备用地址: ${result.status}, ${result.exception}',
      );
    }

    if (lastResult == null) {
      throw GeminiChatException('$modelName下载地址为空，请检查配置。');
    }
    _ensureDownloadComplete(lastResult, modelName);
  }

  DownloadTask _createModelDownloadTask({
    required String url,
    required String filename,
    required String directory,
  }) {
    if (filename == _modelId) {
      return ParallelDownloadTask(
        url: url,
        filename: filename,
        directory: directory,
        baseDirectory: BaseDirectory.applicationDocuments,
        updates: Updates.statusAndProgress,
        chunks: 16,
        retries: 5,
        allowPause: false,
      );
    }

    return DownloadTask(
      url: url,
      filename: filename,
      directory: directory,
      baseDirectory: BaseDirectory.applicationDocuments,
      updates: Updates.statusAndProgress,
      retries: 3,
      allowPause: true,
    );
  }

  void _updateModelDownloadProgress(TaskProgressUpdate update) {
    _setModelDownloadSnapshot(update.task.filename, update.progress);
  }

  void _setModelDownloadSnapshot(String filename, double progress) {
    final type = _modelDownloadTypeFromFilename(filename);
    if (type == null) return;

    _setModelDownloadStage(
      type,
      _normalizeModelDownloadProgress(type, filename, progress),
      _modelDownloadStatusText(type, filename),
    );
  }

  void _setModelDownloadStage(String type, double progress, String status) {
    _modelDownloadSnapshot = ModelDownloadSnapshot(
      isActive: true,
      type: type,
      progress: progress,
      status: status,
    );
  }

  void _clearModelDownloadSnapshot() {
    _modelDownloadSnapshot = const ModelDownloadSnapshot(isActive: false);
  }

  String? _modelDownloadTypeFromFilename(String filename) {
    if (filename == _modelId) return 'gemma';
    if (filename == _asrArchiveId) return 'asr';
    if (filename == _ttsArchiveId) return 'tts';
    return null;
  }

  double _normalizeModelDownloadProgress(
    String type,
    String filename,
    double progress,
  ) {
    if (progress < 0) return -1;
    return progress.clamp(0, 1);
  }

  String _modelDownloadStatusText(String type, String filename) {
    if (type == 'gemma') {
      return '正在下载 Gemma4 模型';
    }
    if (type == 'asr') return '正在下载语音识别模型';
    if (type == 'tts') return '正在下载语音合成模型';
    return '正在下载安装';
  }

  void _ensureDownloadComplete(TaskStatusUpdate result, String modelName) {
    if (result.status == TaskStatus.complete) return;
    throw GeminiChatException(
      '$modelName下载失败，请检查网络后重试。',
      cause: result.exception ?? result.status,
    );
  }

  Future<void> _extractTarGz(
    File archiveFile,
    Directory outputDir, {
    bool stripFirstPathComponent = false,
  }) async {
    if (!await archiveFile.exists()) {
      throw GeminiChatException('模型压缩包不存在：${archiveFile.path}');
    }
    await outputDir.create(recursive: true);

    final reader = _ByteStreamReader(
      gzip.decoder.bind(archiveFile.openRead()),
    );
    while (true) {
      final header = await reader.readExactly(512);
      if (header == null || _isEmptyTarBlock(header)) break;

      final name = _readTarName(header);
      final size = _readTarSize(header);
      final typeFlag = header[156];
      if (name.isEmpty) {
        await reader.skip(size + _tarPaddingSize(size));
        continue;
      }

      final outputPath = _safeTarOutputPath(
        outputDir,
        name,
        stripFirstPathComponent: stripFirstPathComponent,
      );
      final isDirectory = typeFlag == 53; // '5'
      if (isDirectory) {
        if (outputPath != null) {
          await Directory(outputPath).create(recursive: true);
        }
      } else if (outputPath != null) {
        final outputFile = File(outputPath);
        await outputFile.parent.create(recursive: true);
        final sink = outputFile.openWrite();
        try {
          await reader.pipeBytes(size, sink);
        } finally {
          await sink.close();
        }
      } else {
        await reader.skip(size);
      }

      await reader.skip(_tarPaddingSize(size));
    }
  }

  Future<void> _deleteFiles(List<File> files) async {
    for (final file in files) {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  bool _isEmptyTarBlock(Uint8List block) {
    for (final byte in block) {
      if (byte != 0) return false;
    }
    return true;
  }

  String _readTarName(Uint8List header) {
    final name = _readNullTerminatedAscii(header, 0, 100);
    final prefix = _readNullTerminatedAscii(header, 345, 155);
    return prefix.isEmpty ? name : '$prefix/$name';
  }

  String _readNullTerminatedAscii(Uint8List bytes, int start, int length) {
    var end = start;
    final maxEnd = start + length;
    while (end < maxEnd && bytes[end] != 0) {
      end++;
    }
    return ascii.decode(bytes.sublist(start, end)).trim();
  }

  int _readTarSize(Uint8List header) {
    final value = _readNullTerminatedAscii(header, 124, 12).trim();
    if (value.isEmpty) return 0;
    return int.parse(value, radix: 8);
  }

  int _tarPaddingSize(int fileSize) {
    final remainder = fileSize % 512;
    return remainder == 0 ? 0 : 512 - remainder;
  }

  String? _safeTarOutputPath(
    Directory outputDir,
    String tarPath, {
    required bool stripFirstPathComponent,
  }) {
    final segments = tarPath
        .replaceAll('\\', '/')
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (stripFirstPathComponent && segments.isNotEmpty) {
      segments.removeAt(0);
    }
    if (segments.isEmpty ||
        segments.any((segment) => segment == '.' || segment == '..')) {
      return null;
    }
    return '${outputDir.path}/${segments.join('/')}';
  }

  Future<String> askPharmacist(
    String userText, {
    List<Message> history = const [],
    List<String> keywords = const [], // 新增关键字参数
    Uint8List? imageBytes,
    Function(String)? onStream,
  }) async {
    InferenceModel? model;
    InferenceModelSession? session;
    try {
      await ensureInitialized();
      await _ensureActiveModelInstalled();
      final backend = await _detectBestBackend();

      try {
        model = await activeModelGetter(
          maxTokens: 2048,
          preferredBackend: backend,
          supportImage: imageBytes != null,
        );
      } catch (e) {
        debugPrint('多模态模型加载失败，尝试回退到纯文本模式: $e');
        // 如果带图加载失败，尝试纯文本加载
        model = await activeModelGetter(
          maxTokens: 2048,
          preferredBackend: backend,
          supportImage: false,
        );
        // 如果是因为不支持图片，清空图片参数避免后续 Message.withImage 报错
        imageBytes = null;
      }

      session = await model.createSession(temperature: 0.2, topK: 5);

      final promptBuffer = StringBuffer();
      promptBuffer.writeln('你是一位严谨的执业药师。请参考背景与上下文，专业精炼地回答问题。');

      // 注入长时记忆（关键字）
      if (keywords.isNotEmpty) {
        promptBuffer.writeln('【已知背景】：${keywords.join("；")}');
      }

      promptBuffer.writeln('');

      // 注入历史原文
      for (final msg in history) {
        promptBuffer.writeln('${msg.isUser ? '问' : '答'}: ${msg.text}');
      }

      // 注入当前问题
      promptBuffer.writeln('问: $userText');
      promptBuffer.write('答:');

      if (imageBytes != null) {
        await session.addQueryChunk(
          Message.withImage(
            text: promptBuffer.toString(),
            imageBytes: imageBytes,
            isUser: true,
          ),
        );
      } else {
        await session.addQueryChunk(
            Message(text: promptBuffer.toString(), isUser: true));
      }

      final responseStream = session.getResponseAsync();
      final responseBuffer = StringBuffer();
      await for (final chunk in responseStream) {
        responseBuffer.write(chunk);
        if (onStream != null) {
          onStream(responseBuffer.toString());
        }
      }

      final answer = responseBuffer.toString().trim();
      if (answer.isEmpty) {
        throw GeminiChatException('本地药师暂时没有生成回复，请稍后重试。');
      }
      return answer;
    } on GeminiChatException {
      rethrow;
    } catch (error) {
      throw GeminiChatException(_describeChatError(error), cause: error);
    } finally {
      await _closeSessionAndModel(session: session, model: model);
    }
  }

  Future<void> _ensureActiveModelInstalled() async {
    if (FlutterGemma.hasActiveModel()) return;

    final path = await findExistingModelPath();
    if (path == null) {
      throw GeminiChatException('AI 引擎还没准备好，请先完成模型初始化。');
    }

    await FlutterGemma.installModel(
      modelType: ModelType.gemmaIt,
      fileType: ModelFileType.litertlm,
    ).fromFile(path).install();
  }

  String _describeChatError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('not ready') ||
        message.contains('not initialized') ||
        message.contains('not installed') ||
        message.contains('no active model')) {
      return 'AI 引擎还没准备好，请先完成模型初始化。';
    }
    if (message.contains('gpu') ||
        message.contains('npu') ||
        message.contains('backend') ||
        message.contains('delegate')) {
      return '当前设备暂时无法稳定运行药师咨询，请稍后重试。';
    }
    return '本地药师暂时忙不过来，请稍后再试。';
  }

  Future<void> restartApp() async {
    try {
      if (Platform.isAndroid) {
        await _vibrationChannel.invokeMethod('restartApp');
      } else {
        // iOS 逻辑
        if (kDebugMode) {
          // Debug 模式下如果 exit(0)，用户手动点击图标会触发 iOS 14+ 限制报错
          // 抛出异常让 UI 层捕获并显示友好提示
          throw GeminiChatException('iOS 调试模式限制：请在 Android Studio 中重新点击运行按钮以加载新模型。');
        } else {
          exit(0);
        }
      }
    } catch (e) {
      if (e is GeminiChatException) rethrow;
      debugPrint('重启指令发送失败: $e');
      if (!kDebugMode) exit(0);
    }
  }

  Future<MedicationInfo?> extractMedicationInfo(
    Uint8List imageBytes, {
    Function(String)? onStream,
  }) async {
    InferenceModel? model;
    InferenceModelSession? session;
    try {
      await ensureInitialized();
      debugPrint('🚀 [Gemma 4] 开始识别流程...');

      await _ensureActiveModelInstalled();

      const String prompt = '''
      你是一位执业药师，擅长从药盒标签或医嘱图片中提取用药信息。**所有输出必须为中文。**

## 任务
仅根据图片中**清晰可见的文字信息**提取用药信息，输出严格符合格式要求的 JSON。

---

## 强约束（必须遵守）

- **严禁推测、补全或基于常识猜测**
- **仅允许提取图片中明确出现的信息**
- 信息不完整或不确定时，必须使用：
  - 字符串字段 → null 或 ""（按规则）
  - 数值字段 → nul
- 不得根据药名推断剂量、频次或注意事项
- 不得生成图片中未出现的任何内容

---

## 字段规则

- **medicine_name**:  
  药品通用名（非商品名）。  
  - 必须来自图片原文  
  - 若仅能识别部分，保留并在末尾加“?”  
  - 无法识别时输出 null  

- **dosage_per_time**:  
  单次剂量（必须包含单位，如“1片”、“2粒”、“5ml”）。  
  - 仅提取图片中明确剂量  
  - 无法识别时输出 null  

- **frequency_daily**:  
  每日服药次数，按以下规则转换：  
  - QD / 每日一次 → 1  
  - BID / 每日两次 → 2  
  - TID / 每日三次 → 3  
  - QID / 每日四次 → 4  
  - Q8H → 3  
  - Q6H → 4  
  - 必须有明确标注才可转换  
  - 否则输出 null  

- **recommended_times**:  
  - 仅当 frequency_daily 有值时才生成  
  - 按固定规则映射（不得推断）：  
    - 1 → ["08:00"]  
    - 2 → ["08:00","18:00"]  
    - 3 → ["08:00","12:00","18:00"]  
    - 4 → ["08:00","12:00","16:00","20:00"]  
  - frequency_daily 为 null 时输出 []  

- **precautions**:  
  仅提取图片中明确出现的注意事项，按顺序拼接：  
  ① 服用时机  
  ② 禁忌  
  ③ 储存条件  
  ④ 副作用  
  - 多条用“；”分隔  
  - 不得补充常识性内容  
  - 无相关信息时输出 ""  

---

## 输出要求

- 仅输出 JSON  
- 不得包含任何解释、说明 or 多余文本  
- 所有字段必须存在  

输出格式如下：

{"medicine_name":"...","dosage_per_time":"...","frequency_daily":3,"recommended_times":["08:00","12:00","18:00"],"precautions":"..."}
''';

      final backend = await _detectBestBackend();
      model = await activeModelGetter(
        maxTokens: 2048,
        preferredBackend: backend,
        supportImage: true,
      );
      session = await model.createSession(temperature: 0.1, topK: 1);

      await session.addQueryChunk(
        Message.withImage(text: prompt, imageBytes: imageBytes, isUser: true),
      );

      final responseStream = session.getResponseAsync();
      var fullResult = '';
      await for (final chunk in responseStream) {
        fullResult += chunk;
        if (onStream != null) onStream(fullResult);
      }

      if (fullResult.contains('{')) {
        final jsonStart = fullResult.indexOf('{');
        final jsonEnd = fullResult.lastIndexOf('}') + 1;
        final jsonString = fullResult.substring(jsonStart, jsonEnd);
        return MedicationInfo.fromJson(jsonDecode(jsonString));
      }
      return null;
    } catch (e) {
      debugPrint('识别异常: $e');
      return null;
    } finally {
      await _closeSessionAndModel(session: session, model: model);
    }
  }

  Future<void> _closeSessionAndModel({
    InferenceModelSession? session,
    InferenceModel? model,
  }) async {
    try {
      await session?.close();
    } catch (_) {}
    try {
      await model?.close();
    } catch (_) {}
  }

  Future<String> getModelPathForDeletion() async {
    final path = await findExistingModelPath();
    if (path != null) return path;
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_modelId';
  }

  void dispose() {
    _progressController.close();
  }

  /// 将 Sherpa 生成的原始采样保存为 WAV 文件
  Future<String> saveWav(
      Float32List samples, int sampleRate, String fileName) async {
    final int numSamples = samples.length;
    const int numChannels = 1;
    const int bitsPerSample = 16;
    final int byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    const int blockAlign = numChannels * bitsPerSample ~/ 8;
    final int dataSize = numSamples * numChannels * bitsPerSample ~/ 8;
    final int fileSize = 36 + dataSize;

    final Uint8List header = Uint8List(44);
    final ByteData bd = ByteData.view(header.buffer);

    bd.setUint8(0, 0x52); // R
    bd.setUint8(1, 0x49); // I
    bd.setUint8(2, 0x46); // F
    bd.setUint8(3, 0x46); // F
    bd.setUint32(4, fileSize, Endian.little);
    bd.setUint8(8, 0x57); // W
    bd.setUint8(9, 0x41); // A
    bd.setUint8(10, 0x56); // V
    bd.setUint8(11, 0x45); // E
    bd.setUint8(12, 0x66); // f
    bd.setUint8(13, 0x6d); // m
    bd.setUint8(14, 0x74); // t
    bd.setUint8(15, 0x20); // space
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little); // PCM
    bd.setUint16(22, numChannels, Endian.little);
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, byteRate, Endian.little);
    bd.setUint16(32, blockAlign, Endian.little);
    bd.setUint16(34, bitsPerSample, Endian.little);
    bd.setUint8(36, 0x64); // d
    bd.setUint8(37, 0x61); // a
    bd.setUint8(38, 0x74); // t
    bd.setUint8(39, 0x61); // a
    bd.setUint32(40, dataSize, Endian.little);

    final Int16List pcmSamples = Int16List(numSamples);
    final ByteData bdSamples = ByteData.view(pcmSamples.buffer);
    for (int i = 0; i < numSamples; i++) {
      double val = samples[i];
      if (val > 1.0) val = 1.0;
      if (val < -1.0) val = -1.0;
      // 批量写入字节，避开 Dart 的慢速循环赋值
      bdSamples.setInt16(i * 2, (val * 32767).toInt(), Endian.little);
    }

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');

    // 快速写入磁盘
    final output = BytesBuilder(copy: false);
    output.add(header);
    output.add(Uint8List.view(pcmSamples.buffer));
    await file.writeAsBytes(output.takeBytes());
    return file.path;
  }
}
