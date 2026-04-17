import 'dart:async';
import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

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
  bool _isTyping = false;
  String _currentAiResponse = "";

  @override
  void initState() {
    super.initState();
    _messages.add(AIChatMessage(text: "您好，我是您的智能药师。请直接输入您想咨询的药品问题。", isUser: false));
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
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
      if (!FlutterGemma.hasActiveModel()) {
        final path = await _aiService.findExistingModelPath();
        if (path != null) {
          await FlutterGemma.installModel(modelType: ModelType.gemmaIt, fileType: ModelFileType.litertlm)
              .fromFile(path).install();
        }
      }

      final model = await FlutterGemma.getActiveModel(maxTokens: 2048);
      // 降低 temperature 至 0.1，确保 AI 回答更加稳定、直观、无废话
      final session = await model.createSession(temperature: 0.1, topK: 1);
      
      final prompt = "你是一位专业且表达温和的药师。请简洁、清晰地回答，直接呈现结果，不要包含客套话或多余说明：$text";
      await session.addQueryChunk(Message(text: prompt, isUser: true));
      
      final responseStream = session.getResponseAsync();
      await for (final chunk in responseStream) {
        setState(() {
          _currentAiResponse += chunk;
        });
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
      body: Column(
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
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
              ),
              child: Text(
                isStreaming && text.isEmpty ? "正在思考中..." : text,
                style: TextStyle(
                  color: isUser ? Colors.white : const Color(0xFF1F2937),
                  fontSize: 15,
                  height: 1.5,
                ),
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
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
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
