import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../services/gemini_service.dart';
import '../viewmodels/chat_viewmodel.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat/chat_init_ui.dart';
import '../widgets/chat/chat_input_area.dart';
import '../widgets/chat/chat_live_overlay.dart';
import 'model_manager_screen.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final viewModel = context.read<ChatViewModel>();
    viewModel.handleLostData();
    viewModel.addListener(_onViewModelError);

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        viewModel.initEngineIfNeeded();
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

  void _showAsrUnavailableMessage(String reason) {
    if (!mounted) return;
    final isPermission = reason.contains('权限');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(reason),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 5),
        action: isPermission
            ? SnackBarAction(
                label: '前往设置',
                textColor: Colors.white,
                onPressed: () => openAppSettings(),
              )
            : null,
      ),
    );
  }

  void _handleEnterLiveMode() async {
    final viewModel = context.read<ChatViewModel>();
    await viewModel.enterLiveMode(
      (modelName) => _showModelMissingDialog(modelName),
      (reason) => _showAsrUnavailableMessage(reason),
    );
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
                      : const ChatInitUI()),
              if (viewModel.isLiveMode) const ChatLiveOverlay(),
            ],
          ),
        );
      },
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
        ChatInputArea(onScrollToBottom: _scrollToBottom)
      ],
    );
  }
}
