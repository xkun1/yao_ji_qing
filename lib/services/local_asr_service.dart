import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'sherpa_runtime.dart';

class LocalAsrService {
  LocalAsrService._internal();
  static final LocalAsrService _instance = LocalAsrService._internal();
  factory LocalAsrService() => _instance;

  static const MethodChannel _audioChannel =
      MethodChannel('yao_ji_qing/direct_audio');
  static const EventChannel _audioEvents =
      EventChannel('yao_ji_qing/direct_audio_stream');
  static const int _sampleRate = 16000;

  sherpa.OnlineRecognizer? _recognizer;
  sherpa.OnlineStream? _stream;
  StreamSubscription? _audioSubscription;
  String? _lastPartialText;

  // 新增：音量反馈流
  final _volumeController = StreamController<double>.broadcast();
  Stream<double> get volumeStream => _volumeController.stream;

  bool _isRecording = false;
  bool _isReady = false;
  String? _lastError;

  bool get isRecording => _isRecording;

  bool get isReady => _isReady;

  String? get lastError => _lastError;

  Future<bool> initialize() async {
    if (_isReady) return true;

    try {
      final modelPaths = await _findAsrModelPaths();
      if (modelPaths == null) {
        _lastError = '本地 ASR 模型未找到，请放到 models/asr 目录';
        debugPrint(_lastError);
        return false;
      }

      SherpaRuntime.ensureInitialized();
      _recognizer = sherpa.OnlineRecognizer(
        sherpa.OnlineRecognizerConfig(
          feat: const sherpa.FeatureConfig(sampleRate: _sampleRate),
          model: modelPaths.toOnlineModelConfig(),
          decodingMethod: 'greedy_search',
          enableEndpoint: true,
          // 极致优化：只有当我真正不说话（长停顿）的时候才结束
          rule1MinTrailingSilence: 5.0, // 未检测到语音时，等待 5 秒再自动停止
          rule2MinTrailingSilence: 2.2, // 检测到语音后，停顿超过 2.2 秒才判定为结束
          rule3MinUtteranceLength: 60.0, // 最大录音时长提升到 60 秒
        ),
      );
      _isReady = true;
      _lastError = null;
      debugPrint('Sherpa ASR 初始化成功: ${modelPaths.modelDir}');
      return true;
    } catch (e) {
      _lastError = 'Sherpa ASR 初始化失败: $e';
      debugPrint(_lastError);
      _recognizer?.free();
      _recognizer = null;
      _isReady = false;
      return false;
    }
  }

  Future<void> start({
    required ValueChanged<String> onPartial,
    required ValueChanged<String> onFinal,
    ValueChanged<Object>? onError,
  }) async {
    if (_isRecording) return;
    if (!await initialize()) {
      onError?.call(_lastError ?? '本地 ASR 未就绪');
      return;
    }

    final recognizer = _recognizer;
    if (recognizer == null) {
      onError?.call('本地 ASR 未就绪');
      return;
    }

    _stream?.free();
    _stream = recognizer.createStream();
    _lastPartialText = null;

    _audioSubscription = _audioEvents.receiveBroadcastStream().listen(
      (event) {
        if (event is Uint8List) {
          _acceptAudio(event, onPartial: onPartial, onFinal: onFinal);
        }
      },
      onError: (error) {
        _isRecording = false;
        onError?.call(error);
      },
      cancelOnError: false,
    );

    try {
      await _audioChannel.invokeMethod<void>('start', {
        'sampleRate': _sampleRate,
      });
      _isRecording = true;
    } catch (e) {
      try {
        await _audioSubscription?.cancel();
      } catch (_) {}
      _audioSubscription = null;
      _isRecording = false;
      onError?.call(e);
    }
  }

  Future<String> stop() async {
    if (!_isRecording && _audioSubscription == null) {
      return _flushFinalResult();
    }

    try {
      await _audioChannel.invokeMethod<void>('stop');
    } catch (e) {
      debugPrint('停止原生录音失败: $e');
    }

    _isRecording = false;
    try {
      await _audioSubscription?.cancel();
    } catch (e) {
      // EventChannel cancel 在原生端 handler 已释放时会抛出 MissingPluginException，安全忽略
      debugPrint('取消音频流订阅失败（可忽略）: $e');
    }
    _audioSubscription = null;
    return _flushFinalResult();
  }

  Future<void> dispose() async {
    await stop();
    _stream?.free();
    _stream = null;
    _recognizer?.free();
    _recognizer = null;
    _isReady = false;
  }

  void _acceptAudio(
    Uint8List pcmBytes, {
    required ValueChanged<String> onPartial,
    required ValueChanged<String> onFinal,
  }) {
    final recognizer = _recognizer;
    final stream = _stream;
    if (recognizer == null || stream == null || pcmBytes.isEmpty) return;

    final samples = _pcm16ToFloat32(pcmBytes);

    // 实时计算音量 (真正的 RMS)
    double sum = 0;
    for (final s in samples) {
      sum += s * s;
    }
    // 均方根音量算法
    final double rms = math.sqrt(sum / samples.length);
    // 映射到 0.0 - 1.0 范围，并增加增益使其更灵敏
    final double volume = (rms * 12.0).clamp(0.0, 1.0);
    _volumeController.add(volume);

    stream.acceptWaveform(
      samples: samples,
      sampleRate: _sampleRate,
    );

    while (recognizer.isReady(stream)) {
      recognizer.decode(stream);
    }

    final text = recognizer.getResult(stream).text.trim();
    if (text.isNotEmpty && text != _lastPartialText) {
      _lastPartialText = text;
      onPartial(text);
    }

    if (recognizer.isEndpoint(stream)) {
      if (text.isNotEmpty) {
        onFinal(text);
      }
      recognizer.reset(stream);
      _lastPartialText = null;
    }
  }

  String _flushFinalResult() {
    final recognizer = _recognizer;
    final stream = _stream;
    if (recognizer == null || stream == null) return '';

    stream.inputFinished();
    while (recognizer.isReady(stream)) {
      recognizer.decode(stream);
    }

    final text = recognizer.getResult(stream).text.trim();
    recognizer.reset(stream);
    _lastPartialText = null;
    return text;
  }

  Float32List _pcm16ToFloat32(Uint8List bytes) {
    final sampleCount = bytes.length ~/ 2;
    final byteData = ByteData.sublistView(bytes);
    final samples = Float32List(sampleCount);
    for (var i = 0; i < sampleCount; i++) {
      samples[i] = byteData.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return samples;
  }

  Future<_AsrModelPaths?> _findAsrModelPaths() async {
    final searchRoots = <Directory>[];
    final extDir =
        Platform.isAndroid ? await getExternalStorageDirectory() : null;
    final docDir = await getApplicationDocumentsDirectory();

    if (extDir != null) {
      searchRoots.add(Directory('${extDir.path}/models/asr'));
      searchRoots.add(Directory('${extDir.path}/asr'));
    }
    searchRoots.add(Directory('${docDir.path}/models/asr'));
    searchRoots.add(Directory('${docDir.path}/asr'));

    for (final root in searchRoots) {
      final modelPaths = await _scanAsrRoot(root);
      if (modelPaths != null) return modelPaths;
    }
    return null;
  }

  Future<_AsrModelPaths?> _scanAsrRoot(Directory root) async {
    if (!await root.exists()) return null;

    final tokenFiles = <File>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (_baseName(entity.path) == 'tokens.txt') {
        tokenFiles.add(entity);
      }
    }

    for (final tokens in tokenFiles) {
      final dir = tokens.parent;
      final files = await dir
          .list(recursive: false, followLinks: false)
          .where((entity) => entity is File)
          .cast<File>()
          .toList();
      final onnxFiles = files
          .where((file) => _baseName(file.path).toLowerCase().endsWith('.onnx'))
          .toList();
      if (onnxFiles.isEmpty) continue;

      File? encoder;
      File? decoder;
      File? joiner;
      File? ctcModel;

      for (final file in onnxFiles) {
        final name = _baseName(file.path).toLowerCase();
        if (name.contains('encoder')) encoder ??= file;
        if (name.contains('decoder')) decoder ??= file;
        if (name.contains('joiner')) joiner ??= file;
        if (name.contains('ctc') || name == 'model.onnx') ctcModel ??= file;
      }

      if (encoder != null && decoder != null && joiner != null) {
        return _AsrModelPaths.transducer(
          modelDir: dir.path,
          tokens: tokens.path,
          encoder: encoder.path,
          decoder: decoder.path,
          joiner: joiner.path,
        );
      }

      if (encoder != null && decoder != null) {
        return _AsrModelPaths.paraformer(
          modelDir: dir.path,
          tokens: tokens.path,
          encoder: encoder.path,
          decoder: decoder.path,
        );
      }

      if (ctcModel != null) {
        return _AsrModelPaths.zipformerCtc(
          modelDir: dir.path,
          tokens: tokens.path,
          model: ctcModel.path,
        );
      }
    }

    return null;
  }

  String _baseName(String path) {
    return path.split(Platform.pathSeparator).last;
  }
}

class _AsrModelPaths {
  const _AsrModelPaths._({
    required this.modelDir,
    required this.tokens,
    this.encoder,
    this.decoder,
    this.joiner,
    this.model,
    required this.kind,
  });

  factory _AsrModelPaths.transducer({
    required String modelDir,
    required String tokens,
    required String encoder,
    required String decoder,
    required String joiner,
  }) {
    return _AsrModelPaths._(
      modelDir: modelDir,
      tokens: tokens,
      encoder: encoder,
      decoder: decoder,
      joiner: joiner,
      kind: _AsrModelKind.transducer,
    );
  }

  factory _AsrModelPaths.paraformer({
    required String modelDir,
    required String tokens,
    required String encoder,
    required String decoder,
  }) {
    return _AsrModelPaths._(
      modelDir: modelDir,
      tokens: tokens,
      encoder: encoder,
      decoder: decoder,
      kind: _AsrModelKind.paraformer,
    );
  }

  factory _AsrModelPaths.zipformerCtc({
    required String modelDir,
    required String tokens,
    required String model,
  }) {
    return _AsrModelPaths._(
      modelDir: modelDir,
      tokens: tokens,
      model: model,
      kind: _AsrModelKind.zipformerCtc,
    );
  }

  final String modelDir;
  final String tokens;
  final String? encoder;
  final String? decoder;
  final String? joiner;
  final String? model;
  final _AsrModelKind kind;

  sherpa.OnlineModelConfig toOnlineModelConfig() {
    switch (kind) {
      case _AsrModelKind.transducer:
        return sherpa.OnlineModelConfig(
          transducer: sherpa.OnlineTransducerModelConfig(
            encoder: encoder!,
            decoder: decoder!,
            joiner: joiner!,
          ),
          tokens: tokens,
          numThreads: 2,
          provider: 'cpu',
          debug: false,
          modelType: 'zipformer2',
        );
      case _AsrModelKind.paraformer:
        return sherpa.OnlineModelConfig(
          paraformer: sherpa.OnlineParaformerModelConfig(
            encoder: encoder!,
            decoder: decoder!,
          ),
          tokens: tokens,
          numThreads: 2,
          provider: 'cpu',
          debug: false,
          modelType: 'paraformer',
        );
      case _AsrModelKind.zipformerCtc:
        return sherpa.OnlineModelConfig(
          zipformer2Ctc: sherpa.OnlineZipformer2CtcModelConfig(model: model!),
          tokens: tokens,
          numThreads: 2,
          provider: 'cpu',
          debug: false,
          modelType: 'zipformer2_ctc',
        );
    }
  }
}

enum _AsrModelKind {
  transducer,
  paraformer,
  zipformerCtc,
}
