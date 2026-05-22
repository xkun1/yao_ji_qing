import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/home_viewmodel.dart';

class HomeBottomBar extends StatelessWidget {
  final GlobalKey statsKey;

  const HomeBottomBar({super.key, required this.statsKey});

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: 70,
      color: Colors.white,
      padding: EdgeInsets.zero,
      notchMargin: 10,
      shape: const CircularNotchedRectangle(),
      child: Row(
        children: [
          Expanded(child: _buildNavItem(context, Icons.home_rounded, 0)),
          const SizedBox(width: 80),
          Expanded(
            child: Container(
              key: statsKey,
              child: _buildNavItem(context, Icons.bar_chart_rounded, 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, int index) {
    final viewModel = context.watch<HomeViewModel>();
    final bool isActive = viewModel.currentIndex == index;
    return InkWell(
      onTap: () => viewModel.setCurrentIndex(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      child: AnimatedScale(
        scale: isActive ? 1.2 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isActive
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFFD1D5DB),
                size: 28),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                    color: Color(0xFF3B82F6), shape: BoxShape.circle),
              )
          ],
        ),
      ),
    );
  }
}
