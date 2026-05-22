import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/stats_viewmodel.dart';

class MissedAnalysisCard extends StatelessWidget {
  const MissedAnalysisCard({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<StatsViewModel>();
    final totalMissed = viewModel.totalMissed;
    final missedTimeSlots = viewModel.missedTimeSlots;

    if (totalMissed == 0) return const SizedBox.shrink();

    final topMissed = missedTimeSlots.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final displaySlots = topMissed.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 18, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Text("近 30 天共漏服 $totalMissed 次",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          if (displaySlots.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text("高频漏服时段：",
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: displaySlots.map((e) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${e.key}（${e.value}次）",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFD97706),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
