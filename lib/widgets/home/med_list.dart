import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../services/database_service.dart';
import '../medication_task_card.dart';
import '../animations.dart';

class MedListHeader extends StatelessWidget {
  const MedListHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 40, 24, 16),
        child: Text("今日用药任务：",
            style: TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 18,
                fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class MedList extends StatelessWidget {
  final GlobalKey firstTaskKey;
  final GlobalKey editKey;
  final GlobalKey deleteKey;
  final Function(TodayMedicationTask) onEdit;
  final Function(TodayMedicationTask) onMarkTaken;

  const MedList({
    super.key,
    required this.firstTaskKey,
    required this.editKey,
    required this.deleteKey,
    required this.onEdit,
    required this.onMarkTaken,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();
    final pendingTasks = viewModel.tasks.where((task) => !task.isTaken).toList();
    
    if (pendingTasks.isEmpty) {
      final isAllDone = viewModel.tasks.isNotEmpty && viewModel.tasks.every((t) => t.isTaken);
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Center(
            child: FloatingEmptyIcon(
              message: isAllDone ? "您好，今天的药都吃完啦！🌟" : "今天暂时没有用药任务哦",
              subMessage: isAllDone ? "规律服药的你最棒" : "拍照添加药品后自动生成提醒",
              isAllDone: isAllDone,
            ),
          ),
        ),
      );
    }
    
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final task = pendingTasks[index];
            return MedicationTaskCard(
              key: index == 0 ? firstTaskKey : null,
              editKey: index == 0 ? editKey : null,
              deleteKey: index == 0 ? deleteKey : null,
              task: task,
              onMarkTaken: () => onMarkTaken(task),
              onEdit: () => onEdit(task),
              onDelete: () => viewModel.deleteMedication(task),
            );
          },
          childCount: pendingTasks.length,
        ),
      ),
    );
  }
}
