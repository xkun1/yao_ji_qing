import "../widgets/chat_message_bubble.dart";
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/gemini_service.dart';
import '../services/local_asr_service.dart';
import '../viewmodels/chat_viewmodel.dart';
import 'model_manager_screen.dart';

class AIChatScreen extends StatelessWidget {
  const AIChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatViewModel(GeminiService(), LocalAsrService()),
      child: const _AIChatScreenContent(),
    );
  }
}

class _AIChatScreenContent extends StatefulWidget {
  const _AIChatScreenContent();

  @override
  State<_AIChatScreenContent> createState() => _AIChatScreenContentState();
}

class _AIChatScreenContentState extends State<_AIChatScreenContent>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _liveScrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    final viewModel = context.read<ChatViewModel>();

    viewModel.handleLostData(_picker);

    // 监听 Provider 错误
    viewModel.addListener(_onViewModelError);

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        viewModel.initSpeech();
        // 如果需要 autoSpeak 初始化 TTS 等可以在 viewModel 里做
        // 或者是这里调用
        final aiService = GeminiService(); // viewModel 已经注入了，但有些是静态或单例
        if (aiService.autoSpeak) {
          aiService.initTts();
        }
        viewModel.listenToVolume();
      }
    });
  }

  void _onViewModelError() {
    final viewModel = context.read<ChatViewModel>();
    if (viewModel.lastError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(viewModel.lastError!),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      viewModel.clearLastError();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final viewModel = context.read<ChatViewModel>();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      viewModel.releaseCachedModelIfIdle();
    } else if (state == AppLifecycleState.resumed) {
      viewModel.scheduleModelRelease();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inputController.dispose();
    _scrollController.dispose();
    _liveScrollController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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

  void _showModelMissingDialog(String modelName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$modelName尚未就绪"),
        content: const Text("使用该功能需要先下载并安装相应的本地模型。是否现在前往管理页面？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ModelManagerScreen()),
              );
            },
            child: const Text("前往管理"),
          ),
        ],
      ),
    );
  }

  void _showAsrUnavailableMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('语音识别未就绪'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _handleEnterLiveMode() async {
    final viewModel = context.read<ChatViewModel>();
    await viewModel.enterLiveMode(
      (modelName) => _showModelMissingDialog(modelName),
      () => _showAsrUnavailableMessage(),
      onLiveScroll: _scrollToBottomLive,
    );
  }

  Future<void> _showImageSourceSheet() async {
    final viewModel = context.read<ChatViewModel>();
    if (!viewModel.supportsImageConsultation) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '受限于苹果设备统一内存限制，GPU加速的大模型暂不支持在聊天中发送图片。请直接输入文字或使用识药页面的OCR功能。'),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('拍照咨询'),
              onTap: () {
                Navigator.pop(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(context, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );

    if (!mounted || source == null) return;
    await viewModel.pickImage(source, _picker);
    if (!mounted) return;
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatViewModel>(
      builder: (context, viewModel, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          appBar: viewModel.isLiveMode
              ? null
              : AppBar(
                  title: const Text('咨询药师'),
                  backgroundColor: Colors.white,
                  elevation: 0,
                  centerTitle: true,
                  actions: [
                    if (viewModel.modelState == ModelState.ready)
                      IconButton(
                        onPressed: _handleEnterLiveMode,
                        icon: const Icon(Icons.record_voice_over_rounded,
                            color: Color(0xFF3B82F6)),
                        tooltip: '实时对话',
                      ),
                    if (viewModel.modelState == ModelState.ready &&
                        viewModel.messages.length > 1)
                      IconButton(
                        onPressed: () => viewModel.clearMessages(),
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: Colors.grey),
                        tooltip: '清空对话',
                      ),
                  ],
                ),
          body: Stack(
            children: [
              viewModel.modelState == ModelState.ready
                  ? _buildChatUI(viewModel)
                  : (viewModel.modelState == ModelState.checking
                      ? const Center(child: CircularProgressIndicator())
                      : _buildInitUI(viewModel)),
              if (viewModel.isLiveMode) _buildLiveOverlay(viewModel),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLiveOverlay(ChatViewModel viewModel) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E40AF), Color(0xFF0F172A)],
        ),
      ),
      width: double.infinity,
      height: double.infinity,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '实时语音对话',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '离线药师正在为您服务',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white38,
                          ),
                        )
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => viewModel.exitLiveMode(),
                    icon: const Icon(Icons.close_fullscreen_rounded,
                        color: Colors.white70, size: 28),
                  )
                ],
              ),
            ),
            const Spacer(),
            Text(
              viewModel.liveStatus,
              style: const TextStyle(
                fontSize: 20,
                color: Color(0xFF60A5FA),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: viewModel.liveStatus == '聆听中...'
                  ? _buildVolumeWave(viewModel)
                  : const SizedBox(
                      height: 300,
                      child: Center(
                        child: Icon(Icons.auto_awesome_rounded,
                            color: Colors.white10, size: 40),
                      ),
                    ),
            ),
            const Spacer(),
            _buildLiveTranscript(viewModel),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.only(bottom: 40),
              child:
                  Text('药师正在聆听，请直接说话', style: TextStyle(color: Colors.white38)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeWave(ChatViewModel viewModel) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(double.infinity, 300),
          painter: CircularVoiceWavePainter(
            animationValue: _waveController.value,
            volume: viewModel.currentVolume,
            isListening: viewModel.liveStatus == '聆听中...',
          ),
        );
      },
    );
  }

  Widget _buildLiveTranscript(ChatViewModel viewModel) {
    final hasUserText = viewModel.liveLastUserText.isNotEmpty;
    final hasAiText = viewModel.liveAiResponse.isNotEmpty;
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
                  label: '我说', text: viewModel.liveLastUserText, isUser: true),
            if (hasAiText)
              _buildLiveTextPanel(
                  label: '药师', text: viewModel.liveAiResponse, isUser: false),
            const SizedBox(height: 20)
          ],
        ),
      ),
    );
  }

  Widget _buildLiveTextPanel(
      {required String label, required String text, required bool isUser}) {
    const textColor = Colors.white;
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
                : Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          MarkdownBody(
            data: text,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(color: textColor, fontSize: 15, height: 1.45),
              listBullet: const TextStyle(color: textColor),
              strong: const TextStyle(
                  color: Color(0xFF60A5FA), fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChatUI(ChatViewModel viewModel) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            itemCount: viewModel.messages.length + (viewModel.isTyping ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == viewModel.messages.length) {
                return ChatMessageBubble(viewModel.currentAiResponse, false,
                    isStreaming: true);
              }
              final msg = viewModel.messages[index];
              return ChatMessageBubble(msg.text, msg.isUser,
                  imageBytes: msg.imageBytes);
            },
          ),
        ),
        _buildInputArea(viewModel)
      ],
    );
  }

  Widget _buildInitUI(ChatViewModel viewModel) {
    String title = 'AI 咨询引擎尚未就绪';
    String subtitle = '使用该功能需要下载本地模型组件。';
    String buttonLabel = '立即初始化';
    IconData icon = Icons.psychology_rounded;

    if (viewModel.isGemmaMissing) {
      title = '核心对话引擎缺失';
      subtitle = '本地大模型是药师的大脑，约 2.4GB。\n建议在 WiFi 环境下初始化。';
      buttonLabel = '初始化 AI 智慧大脑 (2.41 GB)';
      icon = Icons.psychology_rounded;
    } else if (viewModel.isAsrMissing) {
      title = '语音识别组件未就绪';
      subtitle = '为了听懂您的话，需要安装语音引擎。\n约 230MB。';
      buttonLabel = '安装语音识别组件 (230 MB)';
      icon = Icons.mic_rounded;
    } else if (viewModel.isTtsMissing) {
      title = '语音播报组件未就绪';
      subtitle = '开启自动播报需要安装合成引擎。\n约 170MB。';
      buttonLabel = '安装语音播报组件 (170 MB)';
      icon = Icons.record_voice_over_rounded;
    }

    if (viewModel.modelState == ModelState.fileDetected) {
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
              viewModel.isDownloading ? Icons.cloud_download_rounded : icon,
              size: 80,
              color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
            ),
            const SizedBox(height: 24),
            Text(
              viewModel.isDownloading ? '正在准备 AI 模型...' : title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              viewModel.isDownloading ? '正在处理中，请稍候...' : subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 40),
            if (viewModel.isDownloading)
              Column(
                children: [
                  LinearProgressIndicator(
                    value: viewModel.downloadProgress >= 0
                        ? viewModel.downloadProgress
                        : 0,
                    backgroundColor: const Color(0xFFF3F4F6),
                    color: const Color(0xFF3B82F6),
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${(viewModel.downloadProgress * 100).toStringAsFixed(1)}%',
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
                  onPressed: () => viewModel.handleInitializeModel((errorMsg) {
                    if (mounted) {
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
                  }),
                  icon: Icon(viewModel.isDownloading
                      ? Icons.download_rounded
                      : Icons.flash_on_rounded),
                  label: Text(
                    buttonLabel,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        viewModel.modelState == ModelState.fileDetected
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

  Widget _buildInputArea(ChatViewModel viewModel) {
    final bool hasContent = _inputController.text.isNotEmpty ||
        viewModel.selectedImageBytes != null;
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (viewModel.selectedImageBytes != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildSelectedImagePreview(viewModel),
                      ),
                    ),
                    Positioned(
                      top: -8,
                      right: -8,
                      child: GestureDetector(
                        onTap: () => viewModel.clearSelectedImage(),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              color: Color(0xFFEF4444), shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          Row(
            children: [
              if (viewModel.supportsImageConsultation) ...[
                _buildActionButton(
                    icon: Icons.add_photo_alternate_rounded,
                    onPressed: _showImageSourceSheet,
                    color: const Color(0xFF6B7280),
                    backgroundColor: const Color(0xFFF3F4F6)),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: TextField(
                  controller: _inputController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '输入问题...',
                    hintStyle:
                        const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) {
                    final text = _inputController.text;
                    _inputController.clear();
                    viewModel.handleSend(text, scrollToBottom: _scrollToBottom);
                  },
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  final text = _inputController.text;
                  _inputController.clear();
                  viewModel.handleSend(text, scrollToBottom: _scrollToBottom);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: hasContent && !viewModel.isTyping
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFFE5E7EB),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: hasContent && !viewModel.isTyping
                        ? Colors.white
                        : const Color(0xFF9CA3AF),
                    size: 24,
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
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
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  Widget _buildSelectedImagePreview(ChatViewModel viewModel) {
    const size = 80.0;
    final imagePath = viewModel.selectedImagePath;
    if (imagePath != null && imagePath.isNotEmpty) {
      return Image.file(
        File(imagePath),
        height: size,
        width: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _buildSelectedImageBytesPreview(viewModel, size),
      );
    }
    return _buildSelectedImageBytesPreview(viewModel, size);
  }

  Widget _buildSelectedImageBytesPreview(ChatViewModel viewModel, double size) {
    final imageBytes = viewModel.selectedImageBytes;
    if (imageBytes == null) return SizedBox.square(dimension: size);
    return Image.memory(
      imageBytes,
      height: size,
      width: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => SizedBox.square(
        dimension: size,
        child: const ColoredBox(
          color: Color(0xFFF3F4F6),
          child:
              Icon(Icons.image_not_supported_rounded, color: Color(0xFF9CA3AF)),
        ),
      ),
    );
  }
}

class CircularVoiceWavePainter extends CustomPainter {
  final double animationValue;
  final double volume;
  final bool isListening;

  CircularVoiceWavePainter({
    required this.animationValue,
    required this.volume,
    required this.isListening,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double baseRadius = 35.0 + (volume * 25.0);
    final double maxRadius = size.width * 0.4;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < 3; i++) {
      final double progress = (animationValue + (i / 3.0)) % 1.0;
      double radius = baseRadius + (maxRadius - baseRadius) * progress;
      if (isListening) radius += volume * 60.0 * progress;
      final double opacity = (1.0 - progress).clamp(0.0, 1.0);
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
