import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../core/strings.dart';
import '../viewmodels/stats_viewmodel.dart';
import '../widgets/stats/compliance_card.dart';
import '../widgets/stats/history_list.dart';
import '../widgets/stats/missed_analysis_card.dart';
import '../widgets/stats/recent_history_header.dart';
import '../widgets/stats/time_distribution_card.dart';
import '../widgets/stats/trend_chart.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  void initState() {
    super.initState();
    final viewModel = context.read<StatsViewModel>();
    Future.microtask(() => viewModel.loadStats());
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<StatsViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(AppStrings.statsTitle),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!viewModel.isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Builder(builder: (context) {
                return GestureDetector(
                  onTap: () {
                    final box = context.findRenderObject() as RenderBox?;
                    final rect = box != null
                        ? box.localToGlobal(Offset.zero) & box.size
                        : null;
                    context.read<StatsViewModel>().exportCsv(rect);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: viewModel.isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF3B82F6),
                              ),
                            )
                          : SvgPicture.asset(
                              'assets/icons/share.svg',
                              colorFilter: const ColorFilter.mode(
                                  Color(0xFF3B82F6), BlendMode.srcIn),
                              width: 22,
                              height: 22,
                            ),
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => viewModel.loadStats(),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  ComplianceCard(),
                  SizedBox(height: 24),
                  TrendChart(),
                  SizedBox(height: 24),
                  TimeDistributionCard(),
                  SizedBox(height: 24),
                  MissedAnalysisCard(),
                  SizedBox(height: 24),
                  RecentHistoryHeader(),
                  SizedBox(height: 12),
                  HistoryList(),
                  SizedBox(height: 100),
                ],
              ),
            ),
    );
  }
}
