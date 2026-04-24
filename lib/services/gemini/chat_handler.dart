import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';
import '../../core/exceptions.dart';

/// 聊天消息（用于历史记录）
class ChatMessage {
  ChatMessage({
    required this.text,
    required this.isUser,
    this.imageBytes,
  });

  factory ChatMessage.text(String text, {bool isUser = true}) {
    return ChatMessage(text: text, isUser: isUser);
  }

  factory ChatMessage.withImage({
    required String text,
    required Uint8List imageBytes,
    bool isUser = true,
  }) {
    return ChatMessage(
      text: text,
      isUser: isUser,
      imageBytes: imageBytes,
    );
  }

  final String text;
  final bool isUser;
  final Uint8List? imageBytes;
}

/// 药物信息
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

/// 模型状态枚举
enum ModelState { ready, fileDetected, none, checking }

/// 对话处理器
class ChatHandler {
  ChatHandler._internal();

  static final ChatHandler _instance = ChatHandler._internal();

  factory ChatHandler() => _instance;

  // 测试用依赖注入
  @visibleForTesting
  static Future<void> Function() initializationRunner = FlutterGemma.initialize;

  @visibleForTesting
  static Future<bool> Function(String modelId) modelInstalledChecker =
      FlutterGemma.isModelInstalled;

  @visibleForTesting
  static Future<String?> Function()? existingModelPathFinderOverride;

  @visibleForTesting
  static Future<InferenceModel> Function({
    required int maxTokens,
    PreferredBackend? preferredBackend,
    bool supportImage,
  }) activeModelGetter = ({
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

  Future<void>? _initialization;
  PreferredBackend? _cachedBackend;
  InferenceModel? _cachedInferenceModel;
  PreferredBackend? _cachedInferenceModelBackend;
  bool _cachedInferenceModelSupportsImage = false;

  bool get supportsImageConsultation => !Platform.isIOS;

  /// 确保初始化
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

  /// 重置初始化状态
  @visibleForTesting
  void resetInitializationState() {
    _initialization = null;
    _cachedBackend = null;
  }

  /// 重置测试覆盖
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

  /// 检测最佳后端
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
      _cachedBackend = PreferredBackend.cpu;
    }
    return _cachedBackend!;
  }

  /// 查找现有模型路径
  Future<String?> findExistingModelPath() async {
    final override = existingModelPathFinderOverride;
    if (override != null) return override();

    final possiblePaths = <String>[];
    final extDir = Platform.isAndroid ? await getExternalStorageDirectory() : null;
    if (extDir != null) {
      possiblePaths.add('${extDir.path}/${AppConstants.gemmaModelId}');
      possiblePaths.add('${extDir.path}/${AppConstants.modelsDirName}/${AppConstants.gemmaModelId}');
      possiblePaths.add('${extDir.path}/files/${AppConstants.gemmaModelId}');
    }
    final intDir = await getApplicationDocumentsDirectory();
    possiblePaths.add('${intDir.path}/${AppConstants.gemmaModelId}');
    possiblePaths.add('${intDir.path}/${AppConstants.modelsDirName}/${AppConstants.gemmaModelId}');

    for (final path in possiblePaths) {
      final file = File(path);
      if (await file.exists() && await file.length() >= AppConstants.minGemmaModelBytes) {
        return path;
      }
    }
    return null;
  }

  /// 获取模型状态
  Future<ModelState> getModelState() async {
    await ensureInitialized();
    if (await modelInstalledChecker(AppConstants.gemmaModelId)) return ModelState.ready;
    if ((await findExistingModelPath()) != null) return ModelState.fileDetected;
    return ModelState.none;
  }

  /// 检查模型是否就绪
  Future<bool> isModelReady() async {
    return (await getModelState()) == ModelState.ready;
  }

  /// 检查文件是否存在
  Future<bool> isFilePresent() async {
    return (await findExistingModelPath()) != null;
  }

  /// 确保活动模型已安装
  Future<void> _ensureActiveModelInstalled() async {
    if (FlutterGemma.hasActiveModel()) return;

    final path = await findExistingModelPath();
    if (path == null) {
      throw ModelException.notReady();
    }

    await FlutterGemma.installModel(
      modelType: ModelType.gemmaIt,
      fileType: ModelFileType.litertlm,
    ).fromFile(path).install();
  }

  /// 加载活动模型（带回退）
  Future<_ResolvedActiveModel> _loadActiveModelWithFallback({
    required int maxTokens,
    required bool supportImage,
  }) async {
    final detectedBackend = await _detectBestBackend();
    final attempts = <({PreferredBackend? backend, bool supportImage})>[
      (backend: detectedBackend, supportImage: supportImage),
      if (detectedBackend != PreferredBackend.cpu)
        (backend: PreferredBackend.cpu, supportImage: supportImage),
      if (supportImage) (backend: PreferredBackend.cpu, supportImage: false),
    ];

    Object? lastError;
    for (final attempt in attempts) {
      if (_cachedInferenceModel != null &&
          _cachedInferenceModelBackend == attempt.backend &&
          (!attempt.supportImage || _cachedInferenceModelSupportsImage)) {
        return _ResolvedActiveModel(
          model: _cachedInferenceModel!,
          usesImageInput: attempt.supportImage,
          backend: attempt.backend,
        );
      }

      try {
        final model = await activeModelGetter(
          maxTokens: maxTokens,
          preferredBackend: attempt.backend,
          supportImage: attempt.supportImage,
        );
        await _disposeCachedInferenceModel();
        _cachedInferenceModel = model;
        _cachedInferenceModelBackend = attempt.backend;
        _cachedInferenceModelSupportsImage = attempt.supportImage;
        return _ResolvedActiveModel(
          model: model,
          usesImageInput: attempt.supportImage,
          backend: attempt.backend,
        );
      } catch (error) {
        lastError = error;
        debugPrint(
          '⚠️ [Gemma] 模型加载失败: backend=${attempt.backend}, '
          'supportImage=${attempt.supportImage}, error=$error',
        );
      }
    }

    throw ModelException.loadFailed(cause: lastError);
  }

  /// 释放缓存的推理模型
  Future<void> _disposeCachedInferenceModel() async {
    final existingModel = _cachedInferenceModel;
    _cachedInferenceModel = null;
    _cachedInferenceModelBackend = null;
    _cachedInferenceModelSupportsImage = false;
    try {
      await existingModel?.close();
    } catch (_) {}
  }

  /// 描述聊天错误
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
    if (message.contains('litertresourcecalculator') ||
        message.contains('validatedgraphconfig')) {
      return '当前 iOS 推理引擎与模型不兼容，请在模型管理里重新安装当前设备支持的引擎。';
    }
    return '本地药师暂时忙不过来，请稍后再试。';
  }

  /// 关闭会话和模型
  Future<void> _closeSessionAndModel({
    InferenceModelSession? session,
    InferenceModel? model,
    bool closeModel = true,
  }) async {
    try {
      await session?.close();
    } catch (_) {}
    if (closeModel) {
      try {
        await model?.close();
      } catch (_) {}
    }
  }

  /// 咨询药师
  Future<String> askPharmacist(
    String userText, {
    List<ChatMessage> history = const [],
    List<String> keywords = const [],
    Uint8List? imageBytes,
    Function(String)? onStream,
  }) async {
    InferenceModel? model;
    InferenceModelSession? session;
    try {
      if (imageBytes != null && !supportsImageConsultation) {
        throw ModelException.incompatible();
      }
      await ensureInitialized();
      await _ensureActiveModelInstalled();
      final resolvedModel = await _loadActiveModelWithFallback(
        maxTokens: AppConstants.chatMaxTokens,
        supportImage: imageBytes != null,
      );
      model = resolvedModel.model;
      if (!resolvedModel.usesImageInput) {
        imageBytes = null;
      }

      session = await model.createSession(
        temperature: AppConstants.chatTemperature,
        topK: AppConstants.chatTopK,
      );

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
          Message(text: promptBuffer.toString(), isUser: true),
        );
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
        throw ModelException.loadFailed();
      }
      return answer;
    } on ModelException {
      rethrow;
    } catch (error) {
      throw ModelException.loadFailed(cause: error);
    } finally {
      await _closeSessionAndModel(
        session: session,
        model: model,
        closeModel: false,
      );
    }
  }

  /// 提取药物信息
  Future<MedicationInfo?> extractMedicationInfo(
    Uint8List imageBytes, {
    Function(String)? onStream,
  }) async {
    InferenceModel? model;
    InferenceModelSession? session;
    try {
      if (!supportsImageConsultation) {
        throw ModelException.incompatible();
      }
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
  - 数值字段 → null
- 不得根据药名推断剂量、频次或注意事项
- 不得生成图片中未出现的任何内容

---

## 字段规则

- **medicine_name**:
  药品通用名（非商品名）。
  - 必须来自图片原文
  - 若仅能识别部分，保留并在末尾加"?"
  - 无法识别时输出 null

- **dosage_per_time**:
  单次剂量（必须包含单位，如"1片"、"2粒"、"5ml"）。
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
  - 多条用"；"分隔
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

      final resolvedModel = await _loadActiveModelWithFallback(
        maxTokens: AppConstants.chatMaxTokens,
        supportImage: true,
      );
      model = resolvedModel.model;
      if (!resolvedModel.usesImageInput) {
        throw ModelException.loadFailed();
      }
      session = await model.createSession(
        temperature: AppConstants.chatTemperature,
        topK: AppConstants.chatTopK,
      );

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
      await _closeSessionAndModel(
        session: session,
        model: model,
        closeModel: false,
      );
    }
  }

  /// 获取模型路径用于删除
  Future<String> getModelPathForDeletion() async {
    final path = await findExistingModelPath();
    if (path != null) return path;
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/${AppConstants.gemmaModelId}';
  }

  /// 清理资源
  Future<void> dispose() async {
    await _disposeCachedInferenceModel();
  }
}

/// 解析的活动模型
class _ResolvedActiveModel {
  const _ResolvedActiveModel({
    required this.model,
    required this.usesImageInput,
    required this.backend,
  });

  final InferenceModel model;
  final bool usesImageInput;
  final PreferredBackend? backend;
}