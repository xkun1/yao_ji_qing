import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("关于"),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 60),
            // Logo
            Center(
              child: Container(
                width: 100,
                height: 100,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: SvgPicture.asset('assets/images/logo.svg'),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "药 记 清",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1F2937),
                letterSpacing: 4,
              ),
            ),
            const Text(
              "Version 1.0.0",
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
            ),
            const SizedBox(height: 48),
            
            // 核心功能点
            _buildFeatureList(),
            
            const SizedBox(height: 60),
            
            // 品牌灵魂
            const Text(
              "准时服药",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "不 负 爱 与 嘱 托",
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 80),
            
            const Text(
              "Designed by KunGe with ❤️",
              style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureList() {
    final features = [
      {"icon": Icons.auto_awesome_rounded, "title": "AI 拍照智能录入", "desc": "Gemma 4强力驱动，医嘱一拍即得"},
      {"icon": Icons.alarm_on_rounded, "title": "系统级闹钟提醒", "desc": "强制弹窗与震动，确保用药不遗忘"},
      {"icon": Icons.security_update_good_rounded, "title": "多重保活机制", "desc": "Android 14 深度适配，后台长效守护"},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: features.map((f) => Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(
            children: [
              Icon(f['icon'] as IconData, color: const Color(0xFF3B82F6), size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f['title'] as String, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                    Text(f['desc'] as String, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
}
