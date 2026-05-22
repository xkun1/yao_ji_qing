import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/home_viewmodel.dart';

class ProgressCard extends StatelessWidget {
  final GlobalKey progressKey;
  final VoidCallback onCelebrationRequested;

  const ProgressCard({
    super.key,
    required this.progressKey,
    required this.onCelebrationRequested,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();
    final progress = viewModel.progressValue;
    final totalTaskCount = viewModel.totalTaskCount;
    final takenTaskCount = viewModel.takenTaskCount;
    final remainingCount = totalTaskCount - takenTaskCount;
    final percentLabel = '${(progress * 100).round()}%';
    final isCompleted = viewModel.isTodayCompleted;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: GestureDetector(
          onTap: isCompleted ? onCelebrationRequested : null,
          child: Container(
            key: progressKey,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: -5,
                      offset: const Offset(0, 15))
                ]),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isCompleted ? "今日全部完成" : "今日用药进度",
                          style: const TextStyle(
                              color: Color(0xFFDBEAFE), fontSize: 14)),
                      const SizedBox(height: 12),
                      Text("$takenTaskCount / $totalTaskCount",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                          totalTaskCount == 0
                              ? "拍照添加药品后自动生成提醒"
                              : isCompleted
                                  ? "点击卡片，再放一次烟花"
                                  : "还差 $remainingCount 次，加油哦！",
                          style: const TextStyle(
                              color: Color(0xFFBFDBFE), fontSize: 12)),
                    ],
                  ),
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                        width: 84,
                        height: 84,
                        child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 10,
                            strokeCap: StrokeCap.round,
                            backgroundColor: const Color(0x33FFFFFF),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white))),
                    Text(percentLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
