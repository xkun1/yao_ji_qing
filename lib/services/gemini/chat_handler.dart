import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
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
      maxNumImages: supportImage ? 1 : null,
    );
  };

  Future<void>? _initialization;
  PreferredBackend? _cachedBackend;
  InferenceModel? _cachedInferenceModel;
  PreferredBackend? _cachedInferenceModelBackend;
  bool _cachedInferenceModelSupportsImage = false;

  bool get supportsImageConsultation => true;
  bool get supportsNativeImageConsultation => !Platform.isIOS;

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
        maxNumImages: supportImage ? 1 : null,
      );
    };
  }

  /// 检测最佳后端
  ///
  /// Android 根据 SoC 自动选择（麒麟→CPU，骁龙/天玑/Tensor→NPU，其它→GPU）。
  /// iOS 使用 Metal GPU 加速（flutter_gemma 0.14.0+ 正式支持）。
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

  /// 查找现有模型路径
  Future<String?> findExistingModelPath() async {
    final override = existingModelPathFinderOverride;
    if (override != null) return override();

    final possiblePaths = <String>[];
    final extDir =
        Platform.isAndroid ? await getExternalStorageDirectory() : null;
    if (extDir != null) {
      possiblePaths.add('${extDir.path}/${AppConstants.gemmaModelId}');
      possiblePaths.add(
          '${extDir.path}/${AppConstants.modelsDirName}/${AppConstants.gemmaModelId}');
      possiblePaths.add('${extDir.path}/files/${AppConstants.gemmaModelId}');
    }
    final intDir = await getApplicationDocumentsDirectory();
    possiblePaths.add('${intDir.path}/${AppConstants.gemmaModelId}');
    possiblePaths.add(
        '${intDir.path}/${AppConstants.modelsDirName}/${AppConstants.gemmaModelId}');

    for (final path in possiblePaths) {
      final file = File(path);
      if (await file.exists() &&
          await file.length() >= AppConstants.minGemmaModelBytes) {
        return path;
      }
    }
    return null;
  }

  /// 获取模型状态
  Future<ModelState> getModelState() async {
    await ensureInitialized();
    if (await modelInstalledChecker(AppConstants.gemmaModelId)) {
      return ModelState.ready;
    }
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
  ///
  /// [preferredBackend] 可强制指定后端，为 null 时自动检测。
  Future<_ResolvedActiveModel> _loadActiveModelWithFallback({
    required int maxTokens,
    required bool supportImage,
    PreferredBackend? preferredBackend,
  }) async {
    final detectedBackend = preferredBackend ?? await _detectBestBackend();
    final attempts = <({PreferredBackend? backend, bool supportImage})>[
      (backend: detectedBackend, supportImage: supportImage),
      if (detectedBackend != PreferredBackend.cpu)
        (backend: PreferredBackend.cpu, supportImage: supportImage),
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
        await _disposeModelBeforeReloadIfNeeded(
          backend: attempt.backend,
          supportImage: attempt.supportImage,
        );
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

  Future<void> _disposeModelBeforeReloadIfNeeded({
    required PreferredBackend? backend,
    required bool supportImage,
  }) async {
    if (_cachedInferenceModel != null) {
      await _disposeCachedInferenceModel();
      return;
    }

    if (supportImage || backend != _cachedInferenceModelBackend) {
      try {
        await FlutterGemmaPlugin.instance.initializedModel?.close();
      } catch (_) {}
    }
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
      if (imageBytes != null && !supportsNativeImageConsultation) {
        imageBytes = null;
      }
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
        enableVisionModality: imageBytes != null,
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

  /// 从图片中提取文字（ML Kit OCR）
  Future<String> _extractTextFromImage(Uint8List imageBytes) async {
    File? tempFile;
    try {
      final tempDir = await getTemporaryDirectory();
      tempFile = File(
          '${tempDir.path}/ocr_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(imageBytes);
      final inputImage = InputImage.fromFilePath(tempFile.path);
      final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
      try {
        final recognizedText = await recognizer.processImage(inputImage);
        return recognizedText.text.trim();
      } finally {
        await recognizer.close();
      }
    } catch (e) {
      debugPrint('OCR 提取失败: $e');
      return '';
    } finally {
      if (tempFile != null) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  /// 构建识药提示词（OCR 文字 + 视觉参考）
  String _buildExtractionPrompt({required String ocrText}) {
    final hasOcr = ocrText.trim().isNotEmpty;
    final buffer = StringBuffer();

    if (hasOcr) {
      buffer.writeln('【本地 OCR 已识别的文字 — 优先以此为准】');
      buffer.writeln(ocrText);
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();
    }

    buffer.writeln('你是一位执业药师，擅长从药盒标签或医嘱图片中提取用药信息。**所有输出必须为中文。**');
    buffer.writeln();
    buffer.writeln('## 任务');
    if (hasOcr) {
      buffer.writeln('以上方 OCR 识别文字为主要依据，图片为辅助验证，提取用药信息。');
    } else {
      buffer.writeln('仅根据图片中**清晰可见的文字信息**提取用药信息。');
    }
    buffer.writeln('输出严格符合格式要求的 JSON。');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln('## 强约束（必须遵守）');
    buffer.writeln();
    buffer.writeln('- **严禁推测、补全或基于常识猜测**');
    buffer.writeln('- **仅允许提取 OCR 文字和图片中明确出现的信息**');
    buffer.writeln('- 信息不完整或不确定时，必须使用：');
    buffer.writeln('  - 字符串字段 → null 或 ""（按规则）');
    buffer.writeln('  - 数值字段 → null');
    buffer.writeln('- 不得根据药名推断剂量、频次或注意事项');
    buffer.writeln('- 不得生成未出现的任何内容');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln('## 字段规则');
    buffer.writeln();
    buffer.writeln('- **medicine_name**:');
    buffer.writeln('  药品通用名（非商品名）。');
    buffer.writeln('  - 必须来自 OCR 文字或图片原文');
    buffer.writeln('  - 若仅能识别部分，保留并在末尾加"?"');
    buffer.writeln('  - 无法识别时输出 null');
    buffer.writeln();
    buffer.writeln('- **dosage_per_time**:');
    buffer.writeln('  单次剂量（必须包含单位，如"1片"、"2粒"、"5ml"）。');
    buffer.writeln('  - 仅提取明确剂量');
    buffer.writeln('  - 无法识别时输出 null');
    buffer.writeln();
    buffer.writeln('- **frequency_daily**:');
    buffer.writeln('  每日服药次数，按以下规则转换：');
    buffer.writeln('  - QD / 每日一次 → 1');
    buffer.writeln('  - BID / 每日两次 → 2');
    buffer.writeln('  - TID / 每日三次 → 3');
    buffer.writeln('  - QID / 每日四次 → 4');
    buffer.writeln('  - Q8H → 3');
    buffer.writeln('  - Q6H → 4');
    buffer.writeln('  - 必须有明确标注才可转换');
    buffer.writeln('  - 否则输出 null');
    buffer.writeln();
    buffer.writeln('- **recommended_times**:');
    buffer.writeln('  - 仅当 frequency_daily 有值时才生成');
    buffer.writeln('  - 按固定规则映射（不得推断）：');
    buffer.writeln('    - 1 → ["08:00"]');
    buffer.writeln('    - 2 → ["08:00","18:00"]');
    buffer.writeln('    - 3 → ["08:00","12:00","18:00"]');
    buffer.writeln('    - 4 → ["08:00","12:00","16:00","20:00"]');
    buffer.writeln('  - frequency_daily 为 null 时输出 []');
    buffer.writeln();
    buffer.writeln('- **precautions**:');
    buffer.writeln('  仅提取 OCR 文字或图片中明确出现的注意事项，按顺序拼接：');
    buffer.writeln('  ① 服用时机');
    buffer.writeln('  ② 禁忌');
    buffer.writeln('  ③ 储存条件');
    buffer.writeln('  ④ 副作用');
    buffer.writeln('  - 多条用"；"分隔');
    buffer.writeln('  - 不得补充常识性内容');
    buffer.writeln('  - 无相关信息时输出 ""');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln('## 输出要求');
    buffer.writeln();
    buffer.writeln('- 仅输出 JSON');
    buffer.writeln('- 不得包含任何解释、说明或多余文本');
    buffer.writeln('- 所有字段必须存在');
    buffer.writeln();
    buffer.write('{"medicine_name":"...","dosage_per_time":"...","frequency_daily":3,"recommended_times":["08:00","12:00","18:00"],"precautions":"..."}');

    return buffer.toString();
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
      debugPrint('🚀 [识药] 开始两阶段识别流程...');

      // 阶段 1：本地 OCR 提取文字
      onStream?.call('正在进行本地 OCR 文字识别...\n');
      final ocrText = await _extractTextFromImage(imageBytes);
      final hasOcrText = ocrText.trim().isNotEmpty;

      if (hasOcrText) {
        debugPrint('📝 [OCR] 提取 ${ocrText.length} 字');
        onStream?.call('本地 OCR 已提取 ${ocrText.length} 个字符\n正在交由 AI 大模型进行结构化分析...\n\n---\n【OCR 识别原文】\n$ocrText\n---\n\n');
      } else {
        debugPrint('⚠️ [OCR] 未提取到文字，回退纯视觉识别');
        onStream?.call('OCR 未提取到文字，正在通过视觉模型直接分析图片...\n');
      }

      await _ensureActiveModelInstalled();

      final prompt = _buildExtractionPrompt(ocrText: ocrText);
      bool modelReady = false;

      // 尝试 1：多模态模式（图片 + OCR 增强提示词）
      try {
        final resolvedModel = await _loadActiveModelWithFallback(
          maxTokens: AppConstants.extractionMaxTokens,
          supportImage: true,
        );
        model = resolvedModel.model;
        if (resolvedModel.usesImageInput) {
          session = await model.createSession(
            temperature: AppConstants.extractionTemperature,
            topK: AppConstants.chatTopK,
          );
          await session.addQueryChunk(
            Message.withImage(
                text: prompt, imageBytes: imageBytes, isUser: true),
          );
          modelReady = true;
          debugPrint('✅ 多模态模式就绪');
        }
      } catch (e) {
        debugPrint('⚠️ 多模态加载失败: $e');
        await _closeSessionAndModel(session: session, model: model);
        session = null;
        model = null;
      }

      // 尝试 2：纯文本回退（仅当有 OCR 文字时）
      if (!modelReady && hasOcrText) {
        debugPrint('🔄 回退纯文本模式（OCR 文字）');
        try {
          await _disposeCachedInferenceModel();
          final resolvedModel = await _loadActiveModelWithFallback(
            maxTokens: AppConstants.extractionMaxTokens,
            supportImage: false,
          );
          model = resolvedModel.model;
          session = await model.createSession(
            temperature: AppConstants.extractionTemperature,
            topK: AppConstants.chatTopK,
          );
          await session.addQueryChunk(
            Message(text: prompt, isUser: true),
          );
          modelReady = true;
          debugPrint('✅ 纯文本模式就绪');
        } catch (e) {
          debugPrint('❌ 纯文本回退也失败: $e');
        }
      }

      if (!modelReady) {
        // 恢复机制：flutter_gemma 版本升级后旧模型注册可能失效
        // 找出磁盘上已存在的模型文件，重新注册并重试
        final existingPath = await findExistingModelPath();
        if (existingPath != null) {
          debugPrint('🔄 检测到旧模型注册失效，尝试从文件重新注册...');
          onStream?.call('检测到引擎版本更新，正在重新激活本地模型...\n');
          try {
            await FlutterGemma.installModel(
              modelType: ModelType.gemmaIt,
              fileType: ModelFileType.litertlm,
            ).fromFile(existingPath).install();
            debugPrint('✅ 模型重新注册成功，重试加载...');

            final resolvedModel = await _loadActiveModelWithFallback(
              maxTokens: AppConstants.extractionMaxTokens,
              supportImage: hasOcrText,
            );
            model = resolvedModel.model;
            session = await model.createSession(
              temperature: AppConstants.extractionTemperature,
              topK: AppConstants.chatTopK,
            );
            await session.addQueryChunk(
              resolvedModel.usesImageInput
                  ? Message.withImage(
                      text: prompt, imageBytes: imageBytes, isUser: true)
                  : Message(text: prompt, isUser: true),
            );
            modelReady = true;
            debugPrint('✅ 恢复后模型就绪');
          } catch (recoveryError) {
            debugPrint('❌ 恢复重试也失败: $recoveryError');
            onStream?.call('模型激活失败，请前往模型管理页面删除旧模型并重新下载。\n');
          }
        }

        if (!modelReady) {
          throw ModelException.incompatible(
            cause: Exception(
              '引擎版本更新，请删除旧模型文件后重新下载',
            ),
          );
        }
      }

      final responseStream = session!.getResponseAsync();
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
        closeModel: true,
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

  Future<void> releaseCachedInferenceModel() async {
    await _disposeCachedInferenceModel();
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
