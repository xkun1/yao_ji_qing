import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/stats_viewmodel.dart';

class HistoryList extends StatelessWidget {
  const HistoryList({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<StatsViewModel>();
    final recentLogs = viewModel.recentLogs;

    if (recentLogs.isEmpty) {
      return const Center(
          child: Text("暂无服用记录", style: TextStyle(color: Color(0xFF9CA3AF))));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recentLogs.length,
      itemBuilder: (context, index) {
        final log = recentLogs[index];
        final String dateStr = DateFormat('MM-dd').format(log.planTime);
        final String timeStr = DateFormat('HH:mm').format(log.planTime);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: log.isTaken
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  log.isTaken ? Icons.check_rounded : Icons.close_rounded,
                  color: log.isTaken
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                  size: 18,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log.medicineName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text("计划: $dateStr $timeStr",
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
              Text(
                log.isTaken ? "已服" : "漏服",
                style: TextStyle(
                  color: log.isTaken
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
