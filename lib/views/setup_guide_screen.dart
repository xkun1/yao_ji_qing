import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SetupGuideScreen extends StatefulWidget {
  const SetupGuideScreen({super.key});

  static Future<void> checkAndShow(BuildContext context) async {
    if (!Platform.isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    final bool isDone = prefs.getBool('setup_guide_done') ?? false;

    if (!isDone && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => const SetupGuideScreen(),
        ),
      );
    }
  }

  @override
  State<SetupGuideScreen> createState() => _SetupGuideScreenState();
}

class _SetupGuideScreenState extends State<SetupGuideScreen> with WidgetsBindingObserver {
  bool _batteryDone = false;
  bool _alarmsDone = false;
  bool _notificationsDone = false;
  bool _autoStartDone = false; // 用户是否点过自启动设置
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateActualStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateActualStatus();
    }
  }

  Future<void> _updateActualStatus() async {
    try {
      final Map<dynamic, dynamic>? status = await const MethodChannel('yao_ji_qing/medication_vibration')
          .invokeMethod('checkActualPermissions');
      
      if (status != null && mounted) {
        setState(() {
          _batteryDone = status['batteryIgnored'] ?? false;
          _alarmsDone = status['alarmsEnabled'] ?? false;
          _notificationsDone = status['notificationsEnabled'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("检测权限失败: $e");
    }
  }

  Future<void> _markAsDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setup_guide_done', true);
  }

  void _openAppSettings() {
    const MethodChannel('yao_ji_qing/medication_vibration').invokeMethod('openAppSettings');
  }

  void _openBatterySettings() {
    const MethodChannel('yao_ji_qing/medication_vibration').invokeMethod('openBatterySettings');
  }

  void _openAutoStartSettings() {
    setState(() => _autoStartDone = true);
    const MethodChannel('yao_ji_qing/medication_vibration').invokeMethod('openAutoStartSettings');
  }

  @override
  Widget build(BuildContext context) {
    // 只有三项真实权限通过，且用户点过“自启动管理”，才允许进入
    final bool canProceed = _batteryDone && _alarmsDone && _notificationsDone && _autoStartDone;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              const Icon(Icons.verified_user_rounded, size: 56, color: Color(0xFF3B82F6)),
              const SizedBox(height: 20),
              const Text(
                "您好，检测到系统权限未就绪",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "安卓系统会自动拦截后台任务，请按以下顺序开启全部权限。",
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 24),
              
              Expanded(
                child: ListView(
                  children: [
                    _buildStepCard(
                      title: "1. 忽略电池优化",
                      desc: "允许 App 在后台持续运行不休眠。",
                      isDone: _batteryDone,
                      onTap: _openBatterySettings,
                    ),
                    const SizedBox(height: 14),
                    _buildStepCard(
                      title: "2. 开启精确闹钟",
                      desc: "获取最高提醒优先级，确保准时弹出。",
                      isDone: _alarmsDone,
                      onTap: _openAppSettings,
                    ),
                    const SizedBox(height: 14),
                    _buildStepCard(
                      title: "3. 开启自启动管理",
                      desc: "针对华为/荣耀/小米：设为“手动管理”并开启全部开关。",
                      isDone: _autoStartDone,
                      onTap: _openAutoStartSettings,
                    ),
                    const SizedBox(height: 14),
                    _buildStepCard(
                      title: "4. 允许显示通知",
                      desc: "若不开启此项，我们将无法在通知栏提醒。",
                      isDone: _notificationsDone,
                      onTap: _openAppSettings,
                    ),
                  ],
                ),
              ),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: canProceed
                      ? () {
                          _markAsDone();
                          Navigator.pop(context);
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    disabledBackgroundColor: const Color(0xFFE5E7EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    canProceed ? "全部就绪，开启守护" : "请完成以上真实授权",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required String title,
    required String desc,
    required bool isDone,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDone ? const Color(0xFFF0FDF4) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDone ? const Color(0xFFBBF7D0) : const Color(0xFFF3F4F6), width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                    if (isDone) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                    ]
                  ],
                ),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isDone)
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("去开启", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            )
          else
            const Text("已完成", style: TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
