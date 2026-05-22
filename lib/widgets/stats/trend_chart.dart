import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/stats_viewmodel.dart';

class TrendChart extends StatelessWidget {
  const TrendChart({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<StatsViewModel>();
    final dailyStats = viewModel.dailyStats;

    if (dailyStats.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxVal =
        dailyStats.fold<int>(0, (m, s) => s.total > m ? s.total : m);
    final displayMax = maxVal < 1 ? 1 : maxVal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("30 天服药趋势",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  _legendDot(const Color(0xFF10B981), '已服'),
                  const SizedBox(width: 12),
                  _legendDot(const Color(0xFFFCA5A5), '漏服'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: dailyStats.length,
              itemBuilder: (context, index) {
                final stat = dailyStats[index];
                final takenHeight =
                    stat.total == 0 ? 0.0 : (stat.taken / displayMax * 80);
                final missedHeight =
                    stat.total == 0 ? 0.0 : (stat.missed / displayMax * 80);
                final isToday = index == dailyStats.length - 1;

                return Padding(
                  padding: EdgeInsets.only(
                      right: index < dailyStats.length - 1 ? 4 : 0),
                  child: SizedBox(
                    width: 16,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (stat.total > 0) ...[
                          if (stat.missed > 0)
                            Container(
                              height: missedHeight + takenHeight,
                              width: 14,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFCA5A5),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              alignment: Alignment.topCenter,
                              child: Container(
                                height: takenHeight,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            )
                          else
                            Container(
                              height: takenHeight,
                              width: 14,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                        ] else
                          Container(
                            height: 2,
                            width: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        const Spacer(),
                        Text(
                          DateFormat('d').format(stat.date),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
      ],
    );
  }
}
