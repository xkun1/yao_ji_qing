import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/stats_viewmodel.dart';

class RecentHistoryHeader extends StatelessWidget {
  const RecentHistoryHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<StatsViewModel>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("近期服用记录",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Builder(builder: (context) {
          return GestureDetector(
            onTap: () {
              final box = context.findRenderObject() as RenderBox?;
              final rect =
                  box != null ? box.localToGlobal(Offset.zero) & box.size : null;
              context.read<StatsViewModel>().exportCsv(rect);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (viewModel.isExporting)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF3B82F6),
                      ),
                    )
                  else
                    SvgPicture.asset(
                      'assets/icons/share.svg',
                      width: 16,
                      height: 16,
                      colorFilter: const ColorFilter.mode(
                          Color(0xFF3B82F6), BlendMode.srcIn),
                    ),
                  const SizedBox(width: 6),
                  Text(viewModel.isExporting ? "导出中..." : "导出CSV",
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
