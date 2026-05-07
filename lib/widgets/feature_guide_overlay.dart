import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeatureGuideOverlay extends StatefulWidget {
  final GlobalKey settingsKey;
  final GlobalKey progressKey;
  final GlobalKey fabKey;
  final GlobalKey statsKey;
  final GlobalKey firstTaskKey;
  final GlobalKey editKey;
  final GlobalKey deleteKey;
  final VoidCallback onFinish;

  const FeatureGuideOverlay({
    super.key,
    required this.settingsKey,
    required this.progressKey,
    required this.fabKey,
    required this.statsKey,
    required this.firstTaskKey,
    required this.editKey,
    required this.deleteKey,
    required this.onFinish,
  });

  static Future<void> checkAndShow(
    BuildContext context, {
    required GlobalKey settingsKey,
    required GlobalKey progressKey,
    required GlobalKey fabKey,
    required GlobalKey statsKey,
    required GlobalKey firstTaskKey,
    required GlobalKey editKey,
    required GlobalKey deleteKey,
    required VoidCallback onFinish,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bool isDone = prefs.getBool('feature_guide_done_v5') ?? false;
    if (isDone) return;

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => FeatureGuideOverlay(
        settingsKey: settingsKey,
        progressKey: progressKey,
        fabKey: fabKey,
        statsKey: statsKey,
        firstTaskKey: firstTaskKey,
        editKey: editKey,
        deleteKey: deleteKey,
        onFinish: () async {
          await prefs.setBool('feature_guide_done_v5', true);
          overlayEntry.remove();
          onFinish();
        },
      ),
    );
    if (!context.mounted) return;
    Overlay.of(context).insert(overlayEntry);
  }

  @override
  State<FeatureGuideOverlay> createState() => _FeatureGuideOverlayState();
}

class _FeatureGuideOverlayState extends State<FeatureGuideOverlay> {
  int _currentStep = 0;

  Rect _getRect(GlobalKey key) {
    try {
      final RenderBox? renderBox =
          key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return Rect.zero;
      final offset = renderBox.localToGlobal(Offset.zero);
      return offset & renderBox.size;
    } catch (e) {
      return Rect.zero;
    }
  }

  void _next() {
    if (_currentStep < 6) {
      setState(() => _currentStep++);
    } else {
      widget.onFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    late Rect targetRect;
    late String title;
    late String desc;
    late CrossAxisAlignment infoAlign;
    bool isCircle = true;

    switch (_currentStep) {
      case 0:
        targetRect = _getRect(widget.fabKey);
        title = "核心入口";
        desc = "点这里开启 AI 识药、咨询或录入。";
        infoAlign = CrossAxisAlignment.center;
        break;
      case 1:
        targetRect = _getRect(widget.progressKey);
        title = "今日进度";
        desc = "一目了然的用药清单，吃完即消。";
        infoAlign = CrossAxisAlignment.center;
        isCircle = false;
        break;
      case 2:
        targetRect = _getRect(widget.firstTaskKey);
        title = "确认服药";
        desc = "点击卡片左侧图标，即可标记本次服药完成，并触发烟花效果。";
        infoAlign = CrossAxisAlignment.start;
        isCircle = false;
        break;
      case 3:
        targetRect = _getRect(widget.editKey);
        title = "修改提醒";
        desc = "点击此处，可以修改药名、剂量或调整提醒时间。";
        infoAlign = CrossAxisAlignment.end;
        break;
      case 4:
        targetRect = _getRect(widget.deleteKey);
        title = "结束用药";
        desc = "点击此处即可删除该药品的每日计划。";
        infoAlign = CrossAxisAlignment.end;
        break;
      case 5:
        targetRect = _getRect(widget.statsKey);
        title = "健康统计";
        desc = "查看您的周服药遵从率，见证坚持。";
        infoAlign = CrossAxisAlignment.end;
        break;
      case 6:
      default:
        targetRect = _getRect(widget.settingsKey);
        title = "系统设置";
        desc = "配置系统权限与本地 AI 模型管理。";
        infoAlign = CrossAxisAlignment.end;
        break;
    }

    if (targetRect == Rect.zero) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          GestureDetector(
            onTap: _next,
            child: Container(color: Colors.black.withValues(alpha: 0.8)),
          ),

          // 高亮圆圈/方框
          Positioned(
            left: targetRect.left - 8,
            top: targetRect.top - 8,
            child: IgnorePointer(
              child: Container(
                width: targetRect.width + 16,
                height: targetRect.height + 16,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: isCircle ? null : BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF3B82F6), width: 3),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 4)
                  ],
                ),
              ),
            ),
          ),

          // 指引文案
          Positioned(
            left: 40,
            right: 40,
            top: targetRect.top > size.height / 2
                ? null
                : targetRect.bottom + 40,
            bottom: targetRect.top > size.height / 2
                ? (size.height - targetRect.top) + 40
                : null,
            child: IgnorePointer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: infoAlign,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(
                    desc,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 16, height: 1.5),
                    textAlign: infoAlign == CrossAxisAlignment.center
                        ? TextAlign.center
                        : (infoAlign == CrossAxisAlignment.start
                            ? TextAlign.left
                            : TextAlign.right),
                  ),
                  const SizedBox(height: 40),
                  const Text("点击屏幕继续 ➔",
                      style: TextStyle(
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
            ),
          ),

          // 跳过
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: TextButton(
              onPressed: widget.onFinish,
              child:
                  const Text("跳过引导", style: TextStyle(color: Colors.white54)),
            ),
          ),
        ],
      ),
    );
  }
}
