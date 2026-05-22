import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../viewmodels/chat_viewmodel.dart';

class ChatLiveOverlay extends StatefulWidget {
  const ChatLiveOverlay({super.key});

  @override
  State<ChatLiveOverlay> createState() => _ChatLiveOverlayState();
}

class _ChatLiveOverlayState extends State<ChatLiveOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  final ScrollController _liveScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ChatViewModel>().setOnLiveScroll(_scrollToBottomLive);
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

  @override
  void dispose() {
    _waveController.dispose();
    _liveScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ChatViewModel>();
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
      ..color = const Color(0xFF3B82F6);
    canvas.drawCircle(center, baseRadius * 0.8, centerPaint);
  }

  @override
  bool shouldRepaint(CircularVoiceWavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.volume != volume ||
        oldDelegate.isListening != isListening;
  }
}
