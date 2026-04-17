import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("隐私政策"),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("隐私政策", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("更新日期：2026年4月16日", style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
            const SizedBox(height: 32),
            _buildSection("1. 数据存储说明", "「药记清」高度重视您的隐私。您的所有药品信息、用药记录、提醒设置均【仅存储在您的手机本地数据库】中，本应用不会将其上传至任何第三方服务器。"),
            _buildSection("2. AI 识别说明", "当您使用拍照识别功能时，图片将通过加密通道发送至 Google Gemma 4 引擎进行一次性文字提取。该过程不会存储您的个人身份信息，识别完成后图片数据将立即销毁。"),
            _buildSection("3. 权限使用说明", "本应用申请的摄像头、通知、自启动等权限，均仅用于实现拍照识药及准时提醒核心功能，不会用于收集您的其他隐私数据。"),
            _buildSection("4. 数据注销", "您可以随时在“设置 -> 重置所有药品”中一键清除所有本地数据，该操作不可撤销。"),
            const SizedBox(height: 40),
            const Center(
              child: Text("坤哥出品，必属精品 · 守护隐私，爱无负担", style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.6)),
        ],
      ),
    );
  }
}
