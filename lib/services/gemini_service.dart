import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

enum ModelState { ready, fileDetected, none }

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

class GeminiService {
  GeminiService._internal() {
    _initDownloaderListener();
  }

  static final GeminiService _instance = GeminiService._internal();

  factory GeminiService() => _instance;

  static const String _modelId = 'gemma-4-E2B-it.litertlm';
  static const String _modelUrl =
      'https://hf-mirror.com/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

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

  Stream<TaskUpdate> get downloadUpdates => _progressController.stream;

  PreferredBackend? _cachedBackend;
  Future<void>? _initialization;

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
      _progressController.add(update);
      if (update is TaskStatusUpdate && update.status == TaskStatus.complete) {
        _restartApp();
      }
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
    if (override != null) {
      return override();
    }

    final possiblePaths = <String>[];
    final extDir = await getExternalStorageDirectory();
    if (extDir != null) {
      possiblePaths.add('${extDir.path}/$_modelId');
      possiblePaths.add('${extDir.path}/models/$_modelId');
    }
    final intDir = await getApplicationDocumentsDirectory();
    possiblePaths.add('${intDir.path}/$_modelId');
    possiblePaths.add('${intDir.path}/models/$_modelId');

    for (final path in possiblePaths) {
      final file = File(path);
      if (await file.exists() && await file.length() > 100 * 1024 * 1024) {
        return path;
      }
    }
    return null;
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
    await ensureInitialized();

    final existingPath = await findExistingModelPath();
    if (existingPath != null) {
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.litertlm,
      ).fromFile(existingPath).install();
      _restartApp();
      return;
    }

    final task = DownloadTask(
      url: _modelUrl,
      filename: _modelId,
      directory: 'models',
      baseDirectory: BaseDirectory.applicationDocuments,
      updates: Updates.statusAndProgress,
    );
    FileDownloader().configureNotification(
      running: const TaskNotification('正在下载 AI 引擎', '已完成 {progress}'),
      complete: const TaskNotification('下载完成', '正在重启...'),
      progressBar: true,
    );
    await FileDownloader().enqueue(task);
  }

  Future<String> askPharmacist(
    String userText, {
    Function(String)? onStream,
  }) async {
    InferenceModel? model;
    InferenceModelSession? session;
    try {
      await ensureInitialized();
      await _ensureActiveModelInstalled();
      final backend = await _detectBestBackend();
      model = await activeModelGetter(
        maxTokens: 2048,
        preferredBackend: backend,
        supportImage: false,
      );
      session = await model.createSession(temperature: 0.1, topK: 1);
      final prompt = '你是一位极简主义的专业药师。请言简意赅地回答，直接呈现结果，不要有任何客套话：$userText';
      await session.addQueryChunk(Message(text: prompt, isUser: true));

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

  Future<void> _restartApp() async {
    try {
      await _vibrationChannel.invokeMethod('restartApp');
    } catch (_) {}
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
- 不得包含任何解释、说明或多余文本  
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
}
