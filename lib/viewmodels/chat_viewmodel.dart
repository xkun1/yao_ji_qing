import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import '../core/exceptions.dart';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/gemini_service.dart';
import '../services/local_asr_service.dart';

class AIChatMessage {
  final String text;
  final bool isUser;
  final Uint8List? imageBytes;

  AIChatMessage({required this.text, required this.isUser, this.imageBytes});
}

class ChatViewModel extends ChangeNotifier {
  final GeminiService _aiService;
  final LocalAsrService _localAsrService;

  static const Duration _modelIdleReleaseDelay = Duration(minutes: 3);

  ChatViewModel(this._aiService, this._localAsrService) {
    _messages.add(
      AIChatMessage(
        text: '您好，我是您的智能药师。您可以直接输入文字、通过语音咨询，或者发送药品图片让我帮您看看。',
        isUser: false,
      ),
    );
    _checkEngineStatus();
    _listenToDownloads();
  }

  final List<AIChatMessage> _messages = [];
  List<AIChatMessage> get messages => _messages;

  ModelState _modelState = ModelState.checking;
  ModelState get modelState => _modelState;

  bool _isDownloading = false;
  bool get isDownloading => _isDownloading;

  bool _isGemmaMissing = false;
  bool get isGemmaMissing => _isGemmaMissing;

  bool _isAsrMissing = false;
  bool get isAsrMissing => _isAsrMissing;

  bool _isTtsMissing = false;
  bool get isTtsMissing => _isTtsMissing;

  double _downloadProgress = 0.0;
  double get downloadProgress => _downloadProgress;

  bool _isTyping = false;
  bool get isTyping => _isTyping;

  bool _isStartingListening = false;
  bool get isStartingListening => _isStartingListening;

  String _currentAiResponse = '';
  String get currentAiResponse => _currentAiResponse;

  StreamSubscription? _downloadSubscription;
  Timer? _liveRestartTimer;
  Timer? _modelReleaseTimer;

  bool _isListening = false;
  bool get isListening => _isListening;

  Uint8List? _selectedImageBytes;
  Uint8List? get selectedImageBytes => _selectedImageBytes;

  String? _selectedImagePath;
  String? get selectedImagePath => _selectedImagePath;

  bool _speechEnabled = false;
  bool get speechEnabled => _speechEnabled;

  String? _selectedImageOcrText;
  String? get selectedImageOcrText => _selectedImageOcrText;

  bool _isLiveMode = false;
  bool get isLiveMode => _isLiveMode;

  String _liveStatus = '聆听中...';
  String get liveStatus => _liveStatus;

  String _liveLastUserText = '';
  String get liveLastUserText => _liveLastUserText;

  String _liveAiResponse = '';
  String get liveAiResponse => _liveAiResponse;

  bool _isProcessingLiveInput = false;
  bool get isProcessingLiveInput => _isProcessingLiveInput;

  double _currentVolume = 0.0;
  double get currentVolume => _currentVolume;

  StreamSubscription? _volumeSubscription;

  final List<String> _ttsTextQueue = [];
  final List<String> _ttsAudioQueue = [];
  int _spokenIndex = 0;
  bool _isGenerating = false;
  bool _isPlaying = false;
  bool _isAiStreamingFinished = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  final Set<String> _longTermKeywords = {};

  String? _lastError;
  String? get lastError => _lastError;

  void clearLastError() {
    _lastError = null;
    notifyListeners();
  }

  void _setError(String error) {
    _lastError = error;
    notifyListeners();
  }

  Future<void> handleLostData(ImagePicker picker) async {
    if (!Platform.isAndroid) return;
    try {
      final LostDataResponse response = await picker.retrieveLostData();
      if (response.isEmpty || response.file == null) return;
      final bytes = await response.file!.readAsBytes();
      _selectedImageBytes = bytes;
      _selectedImagePath = response.file!.path;
      notifyListeners();
    } catch (e) {
      debugPrint('恢复丢失的图片数据失败: $e');
    }
  }

  Future<void> initSpeech() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _speechEnabled = false;
        notifyListeners();
        return;
      }
      final ready = await _localAsrService.initialize();
      _speechEnabled = ready;
      notifyListeners();
    } catch (e) {
      debugPrint('语音识别初始化异常: $e');
      _speechEnabled = false;
      notifyListeners();
    }
  }

  void listenToVolume() {
    _volumeSubscription?.cancel();
    _volumeSubscription = _localAsrService.volumeStream.listen((volume) {
      if (_isLiveMode && _liveStatus == '聆听中...') {
        _currentVolume = volume;
        notifyListeners();
      }
    });
  }

  Future<void> _checkEngineStatus() async {
    try {
      final gemmaState = await _aiService.getModelState();

      _isGemmaMissing = gemmaState == ModelState.none;

      if (gemmaState == ModelState.ready) {
        _modelState = ModelState.ready;
      } else if (gemmaState == ModelState.fileDetected) {
        _modelState = ModelState.fileDetected;
      } else {
        _modelState = ModelState.none;
      }
      notifyListeners();
    } catch (e) {
      _modelState = ModelState.none;
      notifyListeners();
    }
  }

  void _listenToDownloads() {
    _downloadSubscription = _aiService.downloadUpdates.listen((update) {
      if (update is TaskProgressUpdate) {
        _isDownloading = true;
        _downloadProgress = update.progress;
        notifyListeners();
      } else if (update is TaskStatusUpdate) {
        if (update.status == TaskStatus.complete) {
          _checkEngineStatus();
          _isDownloading = false;
          notifyListeners();
        } else {
          _isDownloading = false;
          notifyListeners();
        }
      }
    });
  }

  Future<void> handleInitializeModel(
      Function(String) onInstallationComplete) async {
    _isDownloading = true;
    notifyListeners();
    try {
      final asrReady = await _aiService.checkAsrFilesExist();
      if (!asrReady) {
        await _aiService.downloadAsrModel();
        return;
      }
      await _aiService.downloadModel();
    } catch (e) {
      _isDownloading = false;
      notifyListeners();
      final errorMsg = e is ModelException ? e.userMessage : e.toString();
      if (errorMsg.contains('安装完成')) {
        onInstallationComplete(errorMsg);
      }
    }
  }

  Function()? _onLiveScroll;

  Future<bool> enterLiveMode(
      Function(String) onModelMissing, Function() onAsrUnavailable,
      {Function()? onLiveScroll}) async {
    _onLiveScroll = onLiveScroll;
    if (_modelState != ModelState.ready) {
      onModelMissing('对话引擎');
      return false;
    }

    final asrExist = await _aiService.checkAsrFilesExist();
    if (!asrExist) {
      _isAsrMissing = true;
      notifyListeners();
      onModelMissing('语音识别引擎');
      return false;
    }

    if (_aiService.autoSpeak) {
      final ttsExist = await _aiService.checkTtsFilesExist();
      if (!ttsExist) {
        _isTtsMissing = true;
        notifyListeners();
        onModelMissing('语音合成引擎');
        return false;
      }
    }

    if (!_speechEnabled) {
      await initSpeech();
      if (!_speechEnabled) {
        onAsrUnavailable();
        return false;
      }
    }

    cancelModelReleaseTimer();
    _isLiveMode = true;
    _liveStatus = '聆听中...';
    _liveLastUserText = '';
    _liveAiResponse = '';
    _isProcessingLiveInput = false;
    _currentVolume = 0.0;
    notifyListeners();

    _startLiveListening();
    return true;
  }

  void exitLiveMode() {
    _liveRestartTimer?.cancel();
    _localAsrService.stop();
    _audioPlayer.stop();
    _isLiveMode = false;
    _liveAiResponse = '';
    _isProcessingLiveInput = false;
    notifyListeners();
    scheduleModelRelease();
  }

  void _startLiveListening() async {
    if (!_isLiveMode ||
        _isProcessingLiveInput ||
        _isStartingListening ||
        _isListening) {
      return;
    }
    _isStartingListening = true;
    _liveRestartTimer?.cancel();
    _liveStatus = '聆听中...';
    _isListening = true;
    notifyListeners();

    try {
      if (_audioPlayer.state == PlayerState.playing) await _audioPlayer.stop();
      await _localAsrService.start(
        onPartial: (text) {
          if (!_isLiveMode) return;
          _liveStatus = '聆听中...';
          _liveLastUserText = text;
          notifyListeners();
          _onLiveScroll?.call();
        },
        onFinal: (text) {
          if (!_isLiveMode) return;
          final recognizedWords = text.trim();
          if (recognizedWords.isEmpty) return;
          _liveLastUserText = recognizedWords;
          notifyListeners();
          _onLiveScroll?.call();
          _submitLiveInput(recognizedWords);
        },
        onError: (error) {
          if (!_isLiveMode) return;
          _isListening = false;
          _liveStatus = '语音故障';
          notifyListeners();
          _restartLiveListening(delay: const Duration(milliseconds: 2000));
        },
      );
    } catch (e) {
      _isListening = false;
      _isStartingListening = false;
      notifyListeners();
      if (_isLiveMode) {
        _restartLiveListening(delay: const Duration(milliseconds: 2000));
      }
    } finally {
      _isStartingListening = false;
      _isListening = _localAsrService.isRecording;
      notifyListeners();
    }
  }

  void _restartLiveListening(
      {Duration delay = const Duration(milliseconds: 1500)}) {
    _liveRestartTimer?.cancel();
    _liveRestartTimer = Timer(delay, () async {
      if (_isLiveMode && !_isProcessingLiveInput && !_isStartingListening) {
        _startLiveListening();
      }
    });
  }

  void _submitLiveInput(String text) {
    if (!_isLiveMode || _isProcessingLiveInput) return;
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) return;
    _processLiveInput(normalizedText);
  }

  Future<void> _processLiveInput(String text) async {
    if (_isProcessingLiveInput) return;
    cancelModelReleaseTimer();
    _isProcessingLiveInput = true;
    await _localAsrService.stop();
    _ttsTextQueue.clear();
    _ttsAudioQueue.clear();
    _spokenIndex = 0;
    _isAiStreamingFinished = false;

    _isListening = false;
    _liveStatus = '思考中...';
    _liveLastUserText = text;
    _liveAiResponse = '';
    _messages.add(AIChatMessage(text: text, isUser: true));
    _currentVolume = 0.0;
    notifyListeners();
    _onLiveScroll?.call();

    try {
      final history = _getOptimizedHistory();
      _updateLongTermMemory(text);
      final answer = await _aiService.askPharmacist(
        text,
        history: history,
        keywords: _longTermKeywords.toList(),
        onStream: (partial) {
          if (!_isLiveMode) return;
          _liveStatus = '回复中...';
          _liveAiResponse = partial;
          notifyListeners();
          _onLiveScroll?.call();
          _handleStreamingTts(partial);
        },
      );
      if (!_isLiveMode) return;

      _messages.add(AIChatMessage(text: answer, isUser: false));
      _liveAiResponse = answer;
      if (_aiService.autoSpeak) {
        _liveStatus = '播报中...';
      } else {
        _liveStatus = '回复完成';
      }
      notifyListeners();

      _isAiStreamingFinished = true;
      final remaining = answer.substring(_spokenIndex).trim();
      if (_aiService.autoSpeak) {
        if (remaining.isNotEmpty) {
          _ttsTextQueue.add(remaining);
          _runGenerationLoop();
        } else if (_ttsTextQueue.isEmpty && _ttsAudioQueue.isEmpty) {
          _restartLiveListening(delay: const Duration(milliseconds: 1000));
        }
      } else {
        _restartLiveListening(delay: const Duration(milliseconds: 1200));
      }
    } catch (e) {
      if (_isLiveMode) {
        final errorMsg =
            e is ModelException ? e.userMessage : '本地药师暂时忙不过来，请稍后再试。';
        _liveStatus = '出现错误，重试中...';
        _liveAiResponse = errorMsg;
        _setError(errorMsg);
        _restartLiveListening(delay: const Duration(seconds: 1));
      }
    } finally {
      _isProcessingLiveInput = false;
      if (!_isLiveMode) {
        scheduleModelRelease();
      }
      notifyListeners();
    }
  }

  Future<void> handleSend(String text, {Function()? scrollToBottom}) async {
    final image = _selectedImageBytes;
    final imageOcrText = _selectedImageOcrText?.trim() ?? '';
    if ((text.isEmpty && image == null) || _isTyping) return;

    cancelModelReleaseTimer();
    _ttsTextQueue.clear();
    _ttsAudioQueue.clear();
    _spokenIndex = 0;
    _isAiStreamingFinished = false;

    _messages.add(AIChatMessage(text: text, isUser: true, imageBytes: image));
    _isTyping = true;
    _currentAiResponse = '';
    _selectedImageBytes = null;
    _selectedImagePath = null;
    _selectedImageOcrText = null;
    notifyListeners();
    scrollToBottom?.call();

    try {
      final history = _getOptimizedHistory();
      final promptText = _buildImageSafePrompt(text, imageOcrText);
      _updateLongTermMemory(promptText);
      final answer = await _aiService.askPharmacist(
        promptText,
        history: history,
        keywords: _longTermKeywords.toList(),
        onStream: (partial) {
          _currentAiResponse = partial;
          notifyListeners();
          scrollToBottom?.call();
          _handleStreamingTts(partial);
        },
      );

      _messages.add(AIChatMessage(text: answer, isUser: false));
      _currentAiResponse = '';
      _isTyping = false;
      notifyListeners();
      scrollToBottom?.call();

      _isAiStreamingFinished = true;
      final remaining = answer.substring(_spokenIndex).trim();
      if (remaining.isNotEmpty && _aiService.autoSpeak) {
        _ttsTextQueue.add(remaining);
        _runGenerationLoop();
      }
      scheduleModelRelease();
    } catch (e) {
      _isTyping = false;
      _currentAiResponse = '';
      final errorMsg =
          e is ModelException ? e.userMessage : '本地药师暂时忙不过来，请稍后再试。';
      _setError(errorMsg);
      notifyListeners();
      scheduleModelRelease();
    }
  }

  String _buildImageSafePrompt(String text, String imageOcrText) {
    if (imageOcrText.isEmpty) {
      return text.isEmpty
          ? '我发送了一张药品或医嘱图片，但本机未能从图片中识别出文字。请提示我重新拍摄清晰的药盒、说明书或医嘱文字区域。'
          : text;
    }

    final buffer = StringBuffer();
    if (text.isNotEmpty) {
      buffer.writeln(text);
      buffer.writeln();
    } else {
      buffer.writeln('请根据下面从药品或医嘱图片中识别到的文字，进行用药咨询。');
      buffer.writeln();
    }
    buffer.writeln('【图片 OCR 文字】');
    buffer.write(imageOcrText);
    return buffer.toString();
  }

  void _updateLongTermMemory(String text) {
    if (text.isEmpty) return;
    final medicineRegex = RegExp(r'([^\s，。？！；：]+(?:片|胶囊|颗粒|栓|液|滴|膏|丸|喷雾|散))');
    final symptomKeywords = [
      '头痛',
      '发烧',
      '感冒',
      '过敏',
      '咳嗽',
      '腹泻',
      '肚子疼',
      '心慌',
      '胸闷',
      '失眠',
      '胃痛'
    ];
    final medicineMatches = medicineRegex.allMatches(text);
    for (final m in medicineMatches) {
      final found = m.group(1);
      if (found != null) _longTermKeywords.add('提到药品：$found');
    }
    for (final symptom in symptomKeywords) {
      if (text.contains(symptom)) _longTermKeywords.add('相关症状：$symptom');
    }
    if (_longTermKeywords.length > 15) {
      final List<String> list = _longTermKeywords.toList();
      _longTermKeywords.clear();
      _longTermKeywords.addAll(list.sublist(list.length - 15));
    }
  }

  List<ChatMessage> _getOptimizedHistory() {
    if (_messages.length <= 1) return [];
    final int start = _messages.length > 6 ? _messages.length - 6 : 1;
    final List<AIChatMessage> recentOnes = _messages.sublist(start);
    if (recentOnes.isNotEmpty && recentOnes.last.isUser) {
      recentOnes.removeLast();
    }
    final List<ChatMessage> optimized = [];
    int totalChars = 0;
    for (var i = recentOnes.length - 1; i >= 0; i--) {
      final msg = recentOnes[i];
      if (totalChars + msg.text.length > 800) break;
      optimized.insert(0, ChatMessage(text: msg.text, isUser: msg.isUser));
      totalChars += msg.text.length;
    }
    return optimized;
  }

  Future<void> pickImage(ImageSource source, ImagePicker picker) async {
    try {
      scheduleModelRelease();
      final XFile? image = await picker.pickImage(
          source: source, maxWidth: 768, maxHeight: 768, imageQuality: 70);
      if (image != null) {
        await Future.delayed(const Duration(milliseconds: 200));
        final bytes = await image.readAsBytes();
        final ocrText = await _extractTextFromImage(image.path);

        _selectedImageBytes = bytes;
        _selectedImagePath = image.path;
        _selectedImageOcrText = ocrText;
        notifyListeners();
        scheduleModelRelease();
      }
    } catch (e) {
      debugPrint('图片选择失败: $e');
    }
  }

  Future<String> _extractTextFromImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
    try {
      final recognizedText = await recognizer.processImage(inputImage);
      return recognizedText.text.trim();
    } catch (e) {
      debugPrint('咨询图片 OCR 失败: $e');
      return '';
    } finally {
      await recognizer.close();
    }
  }

  void _handleStreamingTts(String partialText) {
    if (!_aiService.autoSpeak) return;
    if (!_isLiveMode && !_isTyping) return;
    final String newText = partialText.substring(_spokenIndex);
    final int puncIndex = newText.indexOf(RegExp(r'[。！？，；：.!?\n]'));
    if (puncIndex == -1) {
      if (newText.length > 18) {
        final String sentence = newText.substring(0, 18);
        _ttsTextQueue.add(sentence.trim());
        _spokenIndex += 18;
        _runGenerationLoop();
      }
      return;
    }
    final String sentence = newText.substring(0, puncIndex + 1);
    final String trimmed = sentence.trim();
    if (trimmed.isNotEmpty) {
      _ttsTextQueue.add(trimmed);
      _spokenIndex += (puncIndex + 1);
      _runGenerationLoop();
    }
  }

  Future<void> _runGenerationLoop() async {
    if (_isGenerating || _ttsTextQueue.isEmpty) return;
    _isGenerating = true;
    while (_ttsTextQueue.isNotEmpty) {
      final String textToSpeak = _ttsTextQueue.removeAt(0);
      final tts = _aiService.tts;
      if (tts == null) break;
      try {
        String sanitized = textToSpeak
            .replaceAll('？', '?')
            .replaceAll('！', '!')
            .replaceAll('，', ',')
            .replaceAll('。', '.')
            .replaceAll('；', ';')
            .replaceAll('：', ':');
        sanitized = sanitized
            .replaceAll(RegExp(r'[^a-zA-Z0-9\u4e00-\u9fa5\s,.!?;:()]'), '')
            .trim();
        if (sanitized.isEmpty) continue;
        await Future.delayed(Duration.zero);
        final String fileName =
            'chunk_${DateTime.now().microsecondsSinceEpoch}.wav';
        final audio = tts.generate(text: sanitized, sid: 47, speed: 1.02);
        final path =
            await _aiService.saveWav(audio.samples, audio.sampleRate, fileName);
        _ttsAudioQueue.add(path);
        _runPlaybackLoop();
      } catch (e) {
        debugPrint('后台合成失败: $e');
      }
    }
    _isGenerating = false;
  }

  Future<void> _runPlaybackLoop() async {
    if (_isPlaying || _ttsAudioQueue.isEmpty) return;
    _isPlaying = true;
    while (_ttsAudioQueue.isNotEmpty) {
      final String audioPath = _ttsAudioQueue.removeAt(0);
      try {
        await _audioPlayer.play(DeviceFileSource(audioPath));
        await _audioPlayer.onPlayerComplete.first;
        try {
          File(audioPath).delete();
        } catch (_) {}
      } catch (e) {
        debugPrint('播放失败: $e');
      }
    }
    _isPlaying = false;
    if (_isAiStreamingFinished &&
        _ttsTextQueue.isEmpty &&
        _ttsAudioQueue.isEmpty &&
        _isLiveMode) {
      _restartLiveListening(delay: const Duration(milliseconds: 800));
    }
  }

  void clearSelectedImage() {
    _selectedImageBytes = null;
    _selectedImagePath = null;
    _selectedImageOcrText = null;
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    _messages.add(
      AIChatMessage(
        text: '您好，对话已重置。我是您的智能药师，请问有什么可以帮您？',
        isUser: false,
      ),
    );
    notifyListeners();
  }

  void scheduleModelRelease() {
    cancelModelReleaseTimer();
    if (_isTyping || _isLiveMode || _isListening || _isProcessingLiveInput) {
      return;
    }
    _modelReleaseTimer =
        Timer(_modelIdleReleaseDelay, releaseCachedModelIfIdle);
  }

  void cancelModelReleaseTimer() {
    _modelReleaseTimer?.cancel();
    _modelReleaseTimer = null;
  }

  void releaseCachedModelIfIdle() {
    if (_isTyping ||
        _isLiveMode ||
        _isListening ||
        _isProcessingLiveInput ||
        _isGenerating ||
        _isPlaying) {
      scheduleModelRelease();
      return;
    }
    unawaited(_aiService.releaseCachedInferenceModel());
  }

  bool get supportsImageConsultation => _aiService.supportsImageConsultation;

  @override
  void dispose() {
    cancelModelReleaseTimer();
    unawaited(_aiService.releaseCachedInferenceModel());
    _downloadSubscription?.cancel();
    _volumeSubscription?.cancel();
    _liveRestartTimer?.cancel();
    _localAsrService.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}
