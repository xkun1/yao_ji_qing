import 'package:flutter/material.dart';
import '../services/database_service.dart';

class MedicationTaskCard extends StatelessWidget {
  final TodayMedicationTask task;
  final VoidCallback onMarkTaken;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final GlobalKey? editKey;
  final GlobalKey? deleteKey;

  const MedicationTaskCard({
    super.key,
    required this.task,
    required this.onMarkTaken,
    required this.onEdit,
    required this.onDelete,
    this.editKey,
    this.deleteKey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: task.isTaken ? null : onMarkTaken,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _buildTimeStatus(),
                const SizedBox(width: 16),
                Expanded(child: _buildMedicineInfo()),
                const SizedBox(width: 12),
                _buildActionButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeStatus() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: task.isTaken
            ? const Color(0xFF10B981).withValues(alpha: 0.1)
            : const Color(0xFF3B82F6).withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          task.isTaken ? Icons.check_rounded : Icons.access_time_rounded,
          color:
              task.isTaken ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
          size: 26,
        ),
      ),
    );
  }

  Widget _buildMedicineInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              task.timeLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 8),
            if (task.isTaken)
              const Text(
                "已服用",
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          task.medicine.name,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1F2937),
            decoration: task.isTaken ? TextDecoration.lineThrough : null,
          ),
        ),
        if (task.medicine.dosage != null)
          Text(
            task.medicine.dosage!,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: editKey,
          icon: const Icon(Icons.edit_note_rounded,
              color: Color(0xFF9CA3AF), size: 22),
          onPressed: onEdit,
        ),
        IconButton(
          key: deleteKey,
          icon: const Icon(Icons.delete_outline_rounded,
              color: Color(0xFFFCA5A5), size: 22),
          onPressed: onDelete,
        ),
      ],
    );
  }
}
