import 'package:flutter/material.dart';
import 'setup_guide_screen.dart';
import 'model_manager_screen.dart';
import 'about_screen.dart';
import 'privacy_policy_screen.dart';
import 'license_screen.dart';
import '../services/database_service.dart';
import '../services/gemini_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GeminiService _aiService = GeminiService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text("设置"),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          _buildSection(
            context,
            "语音与 AI",
            [
              SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.record_voice_over_rounded,
                      color: Color(0xFF10B981), size: 22),
                ),
                title: const Text("药师语音回复",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937))),
                subtitle: const Text("开启后，药师的回复将自动进行实时语音播报",
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                activeColor: const Color(0xFF10B981),
                value: _aiService.autoSpeak,
                onChanged: (bool value) async {
                  if (value) {
                    // 开启时，检查 TTS 模型是否已就绪
                    final ttsExist = await _aiService.checkTtsFilesExist();
                    if (!ttsExist) {
                      if (mounted) {
                        _showTtsMissingDialog();
                      }
                      return;
                    }
                  }
                  setState(() {
                    _aiService.autoSpeak = value;
                  });
                },
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              ),
              const Divider(height: 1, indent: 64),
              _buildTile(
                context,
                icon: Icons.psychology_rounded,
                color: const Color(0xFF8B5CF6),
                title: "模型管理",
                subtitle: "统一管理本地对话、语音识别及播报模型",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ModelManagerScreen()),
                ),
              ),
            ],
          ),
          _buildSection(
            context,
            "系统与安全",
            [
              _buildTile(
                context,
                icon: Icons.security_rounded,
                color: const Color(0xFF3B82F6),
                title: "保活与权限管理",
                subtitle: "设置自启动、电池优化等核心权限",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (context) => const SetupGuideScreen(),
                  ),
                ),
              ),
            ],
          ),
          _buildSection(
            context,
            "数据管理",
            [
              _buildTile(
                context,
                icon: Icons.delete_forever_rounded,
                color: const Color(0xFFEF4444),
                title: "重置所有药品",
                subtitle: "清除全部用药提醒和历史记录",
                onTap: () => _handleReset(context),
              ),
            ],
          ),
          _buildSection(
            context,
            "关于",
            [
              _buildTile(
                context,
                icon: Icons.info_outline_rounded,
                color: const Color(0xFF6B7280),
                title: "药记清 · 版本 1.0.0",
                subtitle: "了解更多功能与愿景",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutScreen()),
                ),
              ),
              const Divider(height: 1, indent: 64),
              _buildTile(
                context,
                icon: Icons.privacy_tip_outlined,
                color: const Color(0xFF6B7280),
                title: "隐私政策",
                subtitle: "了解我们如何保护您的数据",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PrivacyPolicyScreen()),
                ),
              ),
              const Divider(height: 1, indent: 64),
              _buildTile(
                context,
                icon: Icons.description_outlined,
                color: const Color(0xFF6B7280),
                title: "开源协议",
                subtitle: "本软件遵循 MIT 开源协议",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const LicenseScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF9CA3AF),
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937))),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
      trailing: onTap != null
          ? const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB))
          : null,
    );
  }

  void _showTtsMissingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("语音合成引擎尚未就绪"),
        content: const Text("开启自动播报功能需要先下载语音模型。是否现在前往管理页面？"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ModelManagerScreen()));
            },
            child: const Text("前往管理"),
          ),
        ],
      ),
    );
  }

  void _handleReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("确定要重置吗？"),
        content: const Text("此操作将永久删除所有药品提醒和用药记录，无法恢复。"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("取消")),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text("确定重置"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseService().isar.writeTxn(() async {
        await DatabaseService().isar.clear();
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("数据已全部重置")));
        Navigator.pop(context);
      }
    }
  }
}
