import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/stats_viewmodel.dart';

class TimeDistributionCard extends StatelessWidget {
  const TimeDistributionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<StatsViewModel>();
    final timeBucketStats = viewModel.timeBucketStats;
    final totalTaken = viewModel.totalTaken;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("分时段统计",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ...timeBucketStats.entries.map((e) {
            final double percent = totalTaken == 0 ? 0 : e.value / totalTaken;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF6B7280))),
                      Text("${e.value}次",
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: percent,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                    backgroundColor: const Color(0xFFF3F4F6),
                    color: const Color(0xFF3B82F6),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
