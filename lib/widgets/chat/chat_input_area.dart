import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../viewmodels/chat_viewmodel.dart';

class ChatInputArea extends StatefulWidget {
  final VoidCallback onScrollToBottom;
  const ChatInputArea({super.key, required this.onScrollToBottom});

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea> {
  final TextEditingController _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _showImageSourceSheet(ChatViewModel viewModel) async {
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
    await viewModel.pickImage(source);
    if (!mounted) return;
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ChatViewModel>();
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
                    onPressed: () => _showImageSourceSheet(viewModel),
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
                    viewModel.handleSend(text, scrollToBottom: widget.onScrollToBottom);
                  },
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  final text = _inputController.text;
                  _inputController.clear();
                  viewModel.handleSend(text, scrollToBottom: widget.onScrollToBottom);
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
