import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/stats_viewmodel.dart';

class ComplianceCard extends StatelessWidget {
  const ComplianceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<StatsViewModel>();
    final rate = viewModel.complianceRate;
    final totalTaken = viewModel.totalTaken;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: CircularProgressIndicator(
                  value: rate,
                  strokeWidth: 8,
                  backgroundColor: const Color(0xFFF3F4F6),
                  color: const Color(0xFF10B981),
                ),
              ),
              Text("${(rate * 100).round()}%",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("7 天服药遵从率",
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                const SizedBox(height: 4),
                Text("近 7 天共坚持服药 $totalTaken 次",
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937))),
                const Text("保持这种节奏，坤哥棒棒哒！✨",
                    style: TextStyle(color: Color(0xFF10B981), fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
