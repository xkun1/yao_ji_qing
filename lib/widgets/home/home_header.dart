import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../views/settings_screen.dart';

class HomeHeader extends StatelessWidget {
  final GlobalKey settingsKey;

  const HomeHeader({super.key, required this.settingsKey});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();
    final nextTask = viewModel.nextTask;
    
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(viewModel.currentQuote,
                      style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                        nextTask == null
                            ? "今日提醒已完成"
                            : "下次 ${nextTask.timeLabel} · ${nextTask.medicine.name}",
                        style: const TextStyle(
                            color: Color(0xFF059669),
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SettingsScreen()));
                viewModel.loadTodayTasks();
              },
              child: Container(
                key: settingsKey,
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF), shape: BoxShape.circle),
                child: const Icon(Icons.settings_rounded,
                    color: Color(0xFF3B82F6), size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
