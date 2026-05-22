import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/gemini_service.dart';
import '../../viewmodels/chat_viewmodel.dart';

class ChatInitUI extends StatelessWidget {
  const ChatInitUI({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ChatViewModel>();
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
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("安装完成"),
                          content: Text(errorMsg),
                          actions: [
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx),
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
}
