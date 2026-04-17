import 'dart:async';
import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:background_downloader/background_downloader.dart';

class AIChatMessage {
  final String text;
  final bool isUser;
  AIChatMessage({required this.text, required this.isUser});
}

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final GeminiService _aiService = GeminiService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AIChatMessage> _messages = [];
  
  bool _isReady = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isTyping = false;
  String _currentAiResponse = "";
  StreamSubscription? _downloadSubscription;

  @override
  void initState() {
    super.initState();
    _messages.add(AIChatMessage(text: "您好，我是您的智能药师。请直接输入您想咨询的药品问题。", isUser: false));
    _checkEngineStatus();
    _listenToDownloads();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _downloadSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkEngineStatus() async {
    final ready = await _aiService.isModelReady();
    setState(() => _isReady = ready);
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
        }
      }
    });
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

  Future<void> _handleSend() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isTyping) return;

    _inputController.clear();
    setState(() {
      _messages.add(AIChatMessage(text: text, isUser: true));
      _isTyping = true;
      _currentAiResponse = "";
    });
    _scrollToBottom();

    try {
      final model = await FlutterGemma.getActiveModel(maxTokens: 2048);
      final session = await model.createSession(temperature: 0.1, topK: 1);
      final prompt = "你是一位极简主义的专业药师。请言简意赅地回答，直接呈现结果，不要有任何客套话：$text";
      await session.addQueryChunk(Message(text: prompt, isUser: true));
      
      final responseStream = session.getResponseAsync();
      await for (final chunk in responseStream) {
        setState(() => _currentAiResponse += chunk);
        _scrollToBottom();
      }

      setState(() {
        _messages.add(AIChatMessage(text: _currentAiResponse, isUser: false));
        _currentAiResponse = "";
        _isTyping = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(AIChatMessage(text: "抱歉，由于本地模型负载或硬件原因，咨询暂时中断，请重试。", isUser: false));
        _isTyping = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text("咨询药师"),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isReady ? _buildChatUI() : _buildInitUI(),
    );
  }

  Widget _buildChatUI() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            itemCount: _messages.length + (_isTyping ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length) {
                return _buildMessageBubble(_currentAiResponse, false, isStreaming: true);
              }
              final msg = _messages[index];
              return _buildMessageBubble(msg.text, msg.isUser);
            },
          ),
        ),
        _buildInputArea(),
      ],
    );
  }

  Widget _buildInitUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isDownloading ? Icons.cloud_download_rounded : Icons.psychology_rounded,
              size: 80,
              color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
            ),
            const SizedBox(height: 24),
            Text(
              _isDownloading ? "正在准备 AI 智慧大脑..." : "AI 咨询引擎尚未就绪",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              _isDownloading ? "正在下载模型文件，请稍候..." : "使用咨询功能需要初始化约 2.4GB 的本地模型。",
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
                  Text("${(_downloadProgress * 100).toStringAsFixed(1)}%", 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: () => _aiService.downloadModel(),
                  icon: const Icon(Icons.flash_on_rounded),
                  label: const Text("立即初始化 (2.41 GB)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser, {bool isStreaming = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(Icons.psychology_rounded, const Color(0xFF8B5CF6)),
          const SizedBox(width: 12),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF3B82F6) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20), topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4), bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
              ),
              child: Text(
                isStreaming && text.isEmpty ? "正在思考中..." : text,
                style: TextStyle(color: isUser ? Colors.white : const Color(0xFF1F2937), fontSize: 15, height: 1.5),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (isUser) _buildAvatar(Icons.person_rounded, const Color(0xFF3B82F6)),
        ],
      ),
    );
  }

  Widget _buildAvatar(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFF3F4F6)))),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              decoration: InputDecoration(
                hintText: "输入问题...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                filled: true, fillColor: const Color(0xFFF3F4F6),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: _handleSend,
            icon: Icon(Icons.send_rounded, color: _isTyping ? Colors.grey : const Color(0xFF3B82F6)),
          ),
        ],
      ),
    );
  }
}
