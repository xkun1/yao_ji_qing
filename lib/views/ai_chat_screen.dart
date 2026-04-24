import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/gemini_service.dart';
import '../services/local_asr_service.dart';
import 'model_manager_screen.dart';

class AIChatMessage {
  final String text;
  final bool isUser;
  final Uint8List? imageBytes;

  AIChatMessage({required this.text, required this.isUser, this.imageBytes});
}

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen>
    with SingleTickerProviderStateMixin {
  final GeminiService _aiService = GeminiService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _liveScrollController = ScrollController();
  final List<AIChatMessage> _messages = [];
  final ImagePicker _picker = ImagePicker();
  final LocalAsrService _localAsrService = LocalAsrService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  ModelState _modelState = ModelState.checking; // 默认为检查中，防止 UI 闪烁
  bool _isDownloading = false;

  // 精细化模型缺失标记
  bool _isGemmaMissing = false;
  bool _isAsrMissing = false;
  bool _isTtsMissing = false;

  double _downloadProgress = 0.0;
  bool _isTyping = false;
  bool _isStartingListening = false;
  String _currentAiResponse = '';
  StreamSubscription? _downloadSubscription;
  Timer? _liveRestartTimer;

  // 语音与图片状态
  bool _isListening = false;
  Uint8List? _selectedImageBytes;
  String? _selectedImagePath;
  bool _speechEnabled = false;

  // 实时对话 (Live Mode) 状态
  bool _isLiveMode = false;
  String _liveStatus = '聆听中...'; // 聆听中, 思考中, 播报中
  String _liveLastUserText = '';
  String _liveAiResponse = '';
  bool _isProcessingLiveInput = false;
  double _currentVolume = 0.0;
  StreamSubscription? _volumeSubscription;
  late AnimationController _waveController;

  // 流式 TTS 状态
  final List<String> _ttsTextQueue = [];
  final List<String> _ttsAudioQueue = [];
  int _spokenIndex = 0;
  bool _isGenerating = false;
  bool _isPlaying = false;
  bool _isAiStreamingFinished = false;

  // 长时记忆：存储对话中提取的关键字和核心事实
  final Set<String> _longTermKeywords = {};

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _messages.add(
      AIChatMessage(
        text: '您好，我是您的智能药师。您可以直接输入文字、通过语音咨询，或者发送药品图片让我帮您看看。',
        isUser: false,
      ),
    );
    _checkEngineStatus();
    _listenToDownloads();
    _handleLostData();

    // 终极性能优化：避开页面转场动画的黄金 800ms
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _initSpeech(); // ASR 始终尝试初始化（基础功能）

        // 只有开启了播报，才去加载重型 TTS 模型
        if (_aiService.autoSpeak) {
          _aiService.initTts();
        }

        // 监听实时音量
        _volumeSubscription = _localAsrService.volumeStream.listen((volume) {
          if (mounted && _isLiveMode && _liveStatus == '聆听中...') {
            setState(() => _currentVolume = volume);
          }
        });
      }
    });
  }

  Future<void> _handleLostData() async {
    if (!Platform.isAndroid) return;
    try {
      final LostDataResponse response = await _picker.retrieveLostData();
      if (response.isEmpty || response.file == null) return;
      final bytes = await response.file!.readAsBytes();
      if (mounted) {
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImagePath = response.file!.path;
        });
      }
    } catch (e) {
      debugPrint('恢复丢失的图片数据失败: $e');
    }
  }

  Future<void> _initSpeech() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (mounted) setState(() => _speechEnabled = false);
        return;
      }
      final ready = await _localAsrService.initialize();
      if (mounted) setState(() => _speechEnabled = ready);
    } catch (e) {
      debugPrint('语音识别初始化异常: $e');
      if (mounted) setState(() => _speechEnabled = false);
    }
  }

  void _showAsrUnavailableMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(_localAsrService.lastError ?? '语音识别未就绪'),
          backgroundColor: Colors.redAccent),
    );
  }

  void _showChatError(Object error) {
    if (!mounted) return;
    final errorMsg =
        error is GeminiChatException ? error.userMessage : '本地药师暂时忙不过来，请稍后再试。';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMsg),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // --- Live Mode 核心逻辑 ---

  void _enterLiveMode() async {
    // 1. 检查对话模型状态 (兜底)
    if (_modelState != ModelState.ready) {
      _showModelMissingDialog('对话引擎');
      return;
    }

    // 2. 检查语音识别 (ASR) 模型
    final asrExist = await _aiService.checkAsrFilesExist();
    if (!asrExist) {
      setState(() => _isAsrMissing = true);
      _showModelMissingDialog('语音识别引擎');
      return;
    }

    // 3. 检查语音合成 (TTS) 模型 (如果开启了播报)
    if (_aiService.autoSpeak) {
      final ttsExist = await _aiService.checkTtsFilesExist();
      if (!ttsExist) {
        setState(() => _isTtsMissing = true);
        _showModelMissingDialog('语音合成引擎');
        return;
      }
    }

    if (!_speechEnabled) {
      await _initSpeech();
      if (!_speechEnabled) {
        _showAsrUnavailableMessage();
        return;
      }
    }
    setState(() {
      _isLiveMode = true;
      _liveStatus = '聆听中...';
      _liveLastUserText = '';
      _liveAiResponse = '';
      _isProcessingLiveInput = false;
      _currentVolume = 0.0;
    });
    _startLiveListening();
  }

  void _showModelMissingDialog(String modelName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$modelName尚未就绪"),
        content: Text("使用该功能需要先下载并安装相应的本地模型。是否现在前往管理页面？"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("取消")),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ModelManagerScreen()));
            },
            child: const Text("前往管理"),
          ),
        ],
      ),
    );
  }

  void _exitLiveMode() {
    _liveRestartTimer?.cancel();
    _localAsrService.stop();
    _audioPlayer.stop();
    setState(() {
      _isLiveMode = false;
      _liveAiResponse = '';
      _isProcessingLiveInput = false;
    });
  }

  void _startLiveListening() async {
    if (!_isLiveMode ||
        _isProcessingLiveInput ||
        _isStartingListening ||
        _isListening) return;
    _isStartingListening = true;
    _liveRestartTimer?.cancel();
    setState(() {
      _liveStatus = '聆听中...';
      _isListening = true;
    });
    try {
      if (_audioPlayer.state == PlayerState.playing) await _audioPlayer.stop();
      await _localAsrService.start(
        onPartial: (text) {
          if (!mounted || !_isLiveMode) return;
          setState(() {
            _liveStatus = '聆听中...';
            _liveLastUserText = text;
          });
          _scrollToBottomLive();
        },
        onFinal: (text) {
          if (!mounted || !_isLiveMode) return;
          final recognizedWords = text.trim();
          if (recognizedWords.isEmpty) return;
          setState(() => _liveLastUserText = recognizedWords);
          _scrollToBottomLive();
          _submitLiveInput(recognizedWords);
        },
        onError: (error) {
          if (!mounted || !_isLiveMode) return;
          setState(() {
            _isListening = false;
            _liveStatus = '语音故障';
          });
          _restartLiveListening(delay: const Duration(milliseconds: 2000));
        },
      );
    } catch (e) {
      if (mounted)
        setState(() {
          _isListening = false;
          _isStartingListening = false;
        });
      if (_isLiveMode)
        _restartLiveListening(delay: const Duration(milliseconds: 2000));
    } finally {
      if (mounted)
        setState(() {
          _isStartingListening = false;
          _isListening = _localAsrService.isRecording;
        });
    }
  }

  void _restartLiveListening(
      {Duration delay = const Duration(milliseconds: 1500)}) {
    _liveRestartTimer?.cancel();
    _liveRestartTimer = Timer(delay, () async {
      if (mounted &&
          _isLiveMode &&
          !_isProcessingLiveInput &&
          !_isStartingListening) _startLiveListening();
    });
  }

  void _submitLiveInput(String text) {
    if (!_isLiveMode || _isProcessingLiveInput) return;
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) return;
    _processLiveInput(normalizedText);
  }

  void _scrollToBottomLive() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_liveScrollController.hasClients) {
        _liveScrollController.animateTo(
          _liveScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _processLiveInput(String text) async {
    if (_isProcessingLiveInput) return;
    _isProcessingLiveInput = true;
    await _localAsrService.stop();
    _ttsTextQueue.clear();
    _ttsAudioQueue.clear();
    _spokenIndex = 0;
    _isAiStreamingFinished = false;
    setState(() {
      _isListening = false;
      _liveStatus = '思考中...';
      _liveLastUserText = text;
      _liveAiResponse = '';
      _messages.add(AIChatMessage(text: text, isUser: true));
      _currentVolume = 0.0;
    });
    _scrollToBottomLive();
    try {
      final history = _getOptimizedHistory();
      _updateLongTermMemory(text);
      final answer = await _aiService.askPharmacist(
        text,
        history: history,
        keywords: _longTermKeywords.toList(),
        onStream: (partial) {
          if (!mounted || !_isLiveMode) return;
          setState(() {
            _liveStatus = '回复中...';
            _liveAiResponse = partial;
          });
          _scrollToBottomLive();
          _handleStreamingTts(partial);
        },
      );
      if (!mounted || !_isLiveMode) return;
      setState(() {
        _messages.add(AIChatMessage(text: answer, isUser: false));
        _liveAiResponse = answer;
        if (_aiService.autoSpeak) {
          _liveStatus = '播报中...';
        } else {
          _liveStatus = '回复完成';
        }
      });
      _scrollToBottomLive();
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
      if (mounted && _isLiveMode) {
        final errorMsg =
            e is GeminiChatException ? e.userMessage : '本地药师暂时忙不过来，请稍后再试。';
        setState(() {
          _liveStatus = '出现错误，重试中...';
          _liveAiResponse = errorMsg;
        });
        _showChatError(e);
        _restartLiveListening(delay: const Duration(seconds: 1));
      }
    } finally {
      _isProcessingLiveInput = false;
    }
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

  List<Message> _getOptimizedHistory() {
    if (_messages.length <= 1) return [];
    final int start = _messages.length > 6 ? _messages.length - 6 : 1;
    final List<AIChatMessage> recentOnes = _messages.sublist(start);
    if (recentOnes.isNotEmpty && recentOnes.last.isUser)
      recentOnes.removeLast();
    final List<Message> optimized = [];
    int totalChars = 0;
    for (var i = recentOnes.length - 1; i >= 0; i--) {
      final msg = recentOnes[i];
      if (totalChars + msg.text.length > 800) break;
      optimized.insert(0, Message(text: msg.text, isUser: msg.isUser));
      totalChars += msg.text.length;
    }
    return optimized;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (!mounted) return;
      final XFile? image = await _picker.pickImage(
          source: source, maxWidth: 1280, maxHeight: 1280, imageQuality: 85);
      if (image != null) {
        await Future.delayed(const Duration(milliseconds: 200));
        final bytes = await image.readAsBytes();
        if (mounted) {
          setState(() {
            _selectedImageBytes = bytes;
            _selectedImagePath = image.path;
          });
          FocusScope.of(context).unfocus();
        }
      }
    } catch (e) {
      debugPrint('图片选择失败: $e');
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
        final audio = tts.generate(
            text: sanitized,
            sid: GeminiService.sweetFemaleVoiceSid,
            speed: 1.02);
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

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _liveScrollController.dispose();
    _waveController.dispose();
    _downloadSubscription?.cancel();
    _volumeSubscription?.cancel();
    _liveRestartTimer?.cancel();
    _localAsrService.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _checkEngineStatus() async {
    try {
      final gemmaState = await _aiService.getModelState();

      if (!mounted) return;

      setState(() {
        _isGemmaMissing = gemmaState == ModelState.none;

        // 核心改变：只要 Gemma 准备好了（或者是已探测），就允许进入聊天界面
        if (gemmaState == ModelState.ready) {
          _modelState = ModelState.ready;
        } else if (gemmaState == ModelState.fileDetected) {
          _modelState = ModelState.fileDetected;
        } else {
          _modelState = ModelState.none;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _modelState = ModelState.none);
    }
  }

  void _listenToDownloads() {
    _downloadSubscription = _aiService.downloadUpdates.listen((update) {
      if (!mounted) return;
      if (update is TaskProgressUpdate) {
        setState(() {
          _isDownloading = true;
          _downloadProgress = update.progress;
        });
      } else if (update is TaskStatusUpdate) {
        if (update.status == TaskStatus.complete) {
          _checkEngineStatus();
          setState(() => _isDownloading = false);
        } else {
          setState(() => _isDownloading = false);
        }
      }
    });
  }

  Future<void> _handleInitializeModel() async {
    setState(() => _isDownloading = true);
    try {
      final asrReady = await _aiService.checkAsrFilesExist();
      if (!asrReady) {
        await _aiService.downloadAsrModel();
        return;
      }
      await _aiService.downloadModel();
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        final errorMsg =
            e is GeminiChatException ? e.userMessage : e.toString();
        if (errorMsg.contains('安装完成')) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("安装完成"),
              content: Text(errorMsg),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("我知道了"),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _inputController.text.trim();
    final image = _selectedImageBytes;
    if ((text.isEmpty && image == null) || _isTyping) return;
    _inputController.clear();
    _ttsTextQueue.clear();
    _ttsAudioQueue.clear();
    _spokenIndex = 0;
    _isAiStreamingFinished = false;
    setState(() {
      _messages.add(AIChatMessage(text: text, isUser: true, imageBytes: image));
      _isTyping = true;
      _currentAiResponse = '';
      _selectedImageBytes = null;
      _selectedImagePath = null;
    });
    _scrollToBottom();
    try {
      final history = _getOptimizedHistory();
      _updateLongTermMemory(text);
      final answer = await _aiService.askPharmacist(
        text.isEmpty ? "请看这张图片内容" : text,
        history: history,
        keywords: _longTermKeywords.toList(),
        imageBytes: image,
        onStream: (partial) {
          if (!mounted) return;
          setState(() => _currentAiResponse = partial);
          _scrollToBottom();
          _handleStreamingTts(partial);
        },
      );
      if (!mounted) return;
      setState(() {
        _messages.add(AIChatMessage(text: answer, isUser: false));
        _currentAiResponse = '';
        _isTyping = false;
      });
      _scrollToBottom();
      _isAiStreamingFinished = true;
      final remaining = answer.substring(_spokenIndex).trim();
      if (remaining.isNotEmpty && _aiService.autoSpeak) {
        _ttsTextQueue.add(remaining);
        _runGenerationLoop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _currentAiResponse = '';
        });
        _showChatError(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: _isLiveMode
          ? null
          : AppBar(
              title: const Text('咨询药师'),
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              actions: [
                if (_modelState == ModelState.ready)
                  IconButton(
                      onPressed: _enterLiveMode,
                      icon: const Icon(Icons.record_voice_over_rounded,
                          color: Color(0xFF3B82F6)),
                      tooltip: '实时对话'),
                if (_modelState == ModelState.ready && _messages.length > 1)
                  IconButton(
                      onPressed: () {
                        setState(() {
                          _messages.clear();
                          _messages.add(AIChatMessage(
                              text: '您好，对话已重置。我是您的智能药师，请问有什么可以帮您？',
                              isUser: false));
                        });
                      },
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.grey),
                      tooltip: '清空对话'),
              ],
            ),
      body: Stack(
        children: [
          _modelState == ModelState.ready
              ? _buildChatUI()
              : (_modelState == ModelState.checking
                  ? const Center(child: CircularProgressIndicator())
                  : _buildInitUI()),
          if (_isLiveMode) _buildLiveOverlay(),
        ],
      ),
    );
  }

  Widget _buildLiveOverlay() {
    return Container(
      decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1E40AF), Color(0xFF0F172A)])),
      width: double.infinity,
      height: double.infinity,
      child: SafeArea(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
            child: Row(children: [
              const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('实时语音对话',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    Text('离线药师正在为您服务',
                        style: TextStyle(fontSize: 12, color: Colors.white38))
                  ])),
              IconButton(
                  onPressed: _exitLiveMode,
                  icon: const Icon(Icons.close_fullscreen_rounded,
                      color: Colors.white70, size: 28))
            ])),
        const Spacer(),
        Text(_liveStatus,
            style: const TextStyle(
                fontSize: 20,
                color: Color(0xFF60A5FA),
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 40),
        Center(
          child: _liveStatus == '聆听中...'
              ? _buildVolumeWave()
              : const SizedBox(
                  height: 300,
                  child: Center(
                    child: Icon(Icons.auto_awesome_rounded,
                        color: Colors.white10, size: 40),
                  )),
        ),
        const Spacer(),
        _buildLiveTranscript(),
        const Spacer(),
        const Padding(
            padding: EdgeInsets.only(bottom: 40),
            child:
                Text('药师正在聆听，请直接说话', style: TextStyle(color: Colors.white38))),
      ])),
    );
  }

  Widget _buildVolumeWave() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(double.infinity, 300),
          painter: CircularVoiceWavePainter(
              animationValue: _waveController.value,
              volume: _currentVolume,
              isListening: _liveStatus == '聆听中...'),
        );
      },
    );
  }

  Widget _buildLiveTranscript() {
    final hasUserText = _liveLastUserText.isNotEmpty;
    final hasAiText = _liveAiResponse.isNotEmpty;
    if (!hasUserText && !hasAiText) return const SizedBox(height: 240);
    return SizedBox(
        height: 240,
        child: SingleChildScrollView(
            controller: _liveScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasUserText)
                    _buildLiveTextPanel(
                        label: '我说', text: _liveLastUserText, isUser: true),
                  if (hasAiText)
                    _buildLiveTextPanel(
                        label: '药师', text: _liveAiResponse, isUser: false),
                  const SizedBox(height: 20)
                ])));
  }

  Widget _buildLiveTextPanel(
      {required String label, required String text, required bool isUser}) {
    final textColor = Colors.white;
    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: isUser
                ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isUser
                    ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                    : Colors.white12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: textColor.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          MarkdownBody(
              data: text,
              styleSheet: MarkdownStyleSheet(
                  p: TextStyle(color: textColor, fontSize: 15, height: 1.45),
                  listBullet: TextStyle(color: textColor),
                  strong: const TextStyle(
                      color: Color(0xFF60A5FA), fontWeight: FontWeight.bold)))
        ]));
  }

  Widget _buildChatUI() {
    return Column(children: [
      Expanded(
          child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length)
                  return _buildMessageBubble(_currentAiResponse, false,
                      isStreaming: true);
                final msg = _messages[index];
                return _buildMessageBubble(msg.text, msg.isUser,
                    imageBytes: msg.imageBytes);
              })),
      _buildInputArea()
    ]);
  }

  Widget _buildInitUI() {
    // 动态决定话术
    String title = 'AI 咨询引擎尚未就绪';
    String subtitle = '使用该功能需要下载本地模型组件。';
    String buttonLabel = '立即初始化';
    IconData icon = Icons.psychology_rounded;

    if (_isGemmaMissing) {
      title = '核心对话引擎缺失';
      subtitle = '本地大模型是药师的大脑，约 2.4GB。\n建议在 WiFi 环境下初始化。';
      buttonLabel = '初始化 AI 智慧大脑 (2.41 GB)';
      icon = Icons.psychology_rounded;
    } else if (_isAsrMissing) {
      title = '语音识别组件未就绪';
      subtitle = '为了听懂您的话，需要安装语音引擎。\n约 230MB。';
      buttonLabel = '安装语音识别组件 (230 MB)';
      icon = Icons.mic_rounded;
    } else if (_isTtsMissing) {
      title = '语音播报组件未就绪';
      subtitle = '开启自动播报需要安装合成引擎。\n约 170MB。';
      buttonLabel = '安装语音播报组件 (170 MB)';
      icon = Icons.record_voice_over_rounded;
    }

    if (_modelState == ModelState.fileDetected) {
      title = '检测到模型文件';
      subtitle = '模型文件已在本机，点击下方按钮完成极速安装。';
      buttonLabel = '立即激活本地模型';
      icon = Icons.flash_on_rounded;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isDownloading ? Icons.cloud_download_rounded : icon,
              size: 80,
              color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
            ),
            const SizedBox(height: 24),
            Text(
              _isDownloading ? '正在准备 AI 模型...' : title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _isDownloading ? '正在处理中，请稍候...' : subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 40),
            if (_isDownloading)
              Column(
                children: [
                  LinearProgressIndicator(
                    value: _downloadProgress >= 0 ? _downloadProgress : 0,
                    backgroundColor: const Color(0xFFF3F4F6),
                    color: const Color(0xFF3B82F6),
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _handleInitializeModel,
                  icon: Icon(_isDownloading
                      ? Icons.download_rounded
                      : Icons.flash_on_rounded),
                  label: Text(
                    buttonLabel,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _modelState == ModelState.fileDetected
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF3B82F6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser,
      {bool isStreaming = false, Uint8List? imageBytes}) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser)
                _buildAvatar(Icons.psychology_rounded, const Color(0xFF8B5CF6)),
              const SizedBox(width: 12),
              Flexible(
                  child: Column(
                      crossAxisAlignment: isUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                    if (imageBytes != null)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(imageBytes,
                                  width: 200, fit: BoxFit.cover))),
                    Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color:
                                isUser ? const Color(0xFF3B82F6) : Colors.white,
                            borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(20),
                                topRight: const Radius.circular(20),
                                bottomLeft: Radius.circular(isUser ? 20 : 4),
                                bottomRight: Radius.circular(isUser ? 4 : 20)),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 10)
                            ]),
                        child: MarkdownBody(
                            data:
                                isStreaming && text.isEmpty ? '正在思考中...' : text,
                            styleSheet: MarkdownStyleSheet(
                                p: TextStyle(
                                    color: isUser
                                        ? Colors.white
                                        : const Color(0xFF1F2937),
                                    fontSize: 15,
                                    height: 1.5),
                                listBullet: TextStyle(
                                    color: isUser
                                        ? Colors.white
                                        : const Color(0xFF1F2937)),
                                strong: TextStyle(fontWeight: FontWeight.bold, color: isUser ? Colors.white : const Color(0xFF1F2937)))))
                  ])),
              const SizedBox(width: 12),
              if (isUser)
                _buildAvatar(Icons.person_rounded, const Color(0xFF3B82F6))
            ]));
  }

  Widget _buildAvatar(IconData icon, Color color) {
    return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20));
  }

  Widget _buildInputArea() {
    final bool hasContent =
        _inputController.text.isNotEmpty || _selectedImageBytes != null;
    return Container(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -4),
              blurRadius: 10)
        ]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_selectedImageBytes != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Stack(clipBehavior: Clip.none, children: [
                      Container(
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2))
                              ]),
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _buildSelectedImagePreview())),
                      Positioned(
                          top: -8,
                          right: -8,
                          child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedImageBytes = null;
                                  _selectedImagePath = null;
                                });
                              },
                              child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                      color: Color(0xFFEF4444),
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.close_rounded,
                                      size: 14, color: Colors.white))))
                    ]))),
          Row(children: [
            _buildActionButton(
                icon: Icons.add_photo_alternate_rounded,
                onPressed: () => _showImageSourceSheet(),
                color: const Color(0xFF6B7280),
                backgroundColor: const Color(0xFFF3F4F6)),
            const SizedBox(width: 12),
            Expanded(
                child: TextField(
                    controller: _inputController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                        hintText: '输入问题...',
                        hintStyle: const TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 14),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10)),
                    onSubmitted: (_) => _handleSend())),
            const SizedBox(width: 12),
            GestureDetector(
                onTap: _handleSend,
                child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: hasContent && !_isTyping
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFFE5E7EB),
                        shape: BoxShape.circle),
                    child: Icon(Icons.arrow_upward_rounded,
                        color: hasContent && !_isTyping
                            ? Colors.white
                            : const Color(0xFF9CA3AF),
                        size: 24)))
          ])
        ]));
  }

  Widget _buildActionButton(
      {required IconData icon,
      required VoidCallback onPressed,
      required Color color,
      required Color backgroundColor}) {
    return GestureDetector(
        onTap: onPressed,
        child: Container(
            padding: const EdgeInsets.all(10),
            decoration:
                BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24)));
  }

  Widget _buildSelectedImagePreview() {
    const size = 80.0;
    final imagePath = _selectedImagePath;
    if (imagePath != null && imagePath.isNotEmpty)
      return Image.file(File(imagePath),
          height: size,
          width: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildSelectedImageBytesPreview(size));
    return _buildSelectedImageBytesPreview(size);
  }

  Widget _buildSelectedImageBytesPreview(double size) {
    final imageBytes = _selectedImageBytes;
    if (imageBytes == null) return SizedBox.square(dimension: size);
    return Image.memory(imageBytes,
        height: size,
        width: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => SizedBox.square(
            dimension: size,
            child: const ColoredBox(
                color: Color(0xFFF3F4F6),
                child: Icon(Icons.image_not_supported_rounded,
                    color: Color(0xFF9CA3AF)))));
  }

  Future<void> _showImageSourceSheet() async {
    if (!_aiService.supportsImageConsultation) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('当前 iPhone 本地 Gemma 4 仅支持文字咨询，请直接输入问题。'),
          ),
        );
      }
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  leading: const Icon(Icons.camera_alt_rounded),
                  title: const Text('拍照咨询'),
                  onTap: () {
                    Navigator.pop(context, ImageSource.camera);
                  }),
              ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: const Text('从相册选择'),
                  onTap: () {
                    Navigator.pop(context, ImageSource.gallery);
                  })
            ])));
    if (!mounted || source == null) return;
    await _pickImage(source);
  }
}

class CircularVoiceWavePainter extends CustomPainter {
  final double animationValue;
  final double volume;
  final bool isListening;
  CircularVoiceWavePainter(
      {required this.animationValue,
      required this.volume,
      required this.isListening});
  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double baseRadius = 35.0 + (volume * 25.0);
    final double maxRadius = size.width * 0.4;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    for (int i = 0; i < 3; i++) {
      double progress = (animationValue + (i / 3.0)) % 1.0;
      double radius = baseRadius + (maxRadius - baseRadius) * progress;
      if (isListening) radius += volume * 60.0 * progress;
      double opacity = (1.0 - progress).clamp(0.0, 1.0);
      paint.color = const Color(0xFF60A5FA).withValues(alpha: opacity * 0.5);
      paint.strokeWidth = 3.0 * (1.0 - progress) + 0.5;
      canvas.drawCircle(center, radius, paint);
    }
    final centerPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(colors: [
        const Color(0xFF60A5FA).withValues(alpha: 0.9),
        const Color(0xFF3B82F6).withValues(alpha: 0.4),
        Colors.transparent
      ]).createShader(Rect.fromCircle(center: center, radius: baseRadius));
    canvas.drawCircle(center, baseRadius, centerPaint);
    if (isListening && volume > 0.05) {
      final glowPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF60A5FA).withValues(alpha: volume * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
      canvas.drawCircle(center, baseRadius + (volume * 20), glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CircularVoiceWavePainter oldDelegate) => true;
}
