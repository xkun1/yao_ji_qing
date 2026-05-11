import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/inventory_service.dart';

class MedicationTaskCard extends StatefulWidget {
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
  State<MedicationTaskCard> createState() => _MedicationTaskCardState();
}

class _MedicationTaskCardState extends State<MedicationTaskCard> {
  MedicineInventory? _inventory;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    final inv = await InventoryService().get(widget.task.medicine.id);
    if (mounted) setState(() => _inventory = inv);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
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
          onTap: t.isTaken ? null : widget.onMarkTaken,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _buildTimeStatus(t),
                const SizedBox(width: 16),
                Expanded(child: _buildMedicineInfo(t)),
                const SizedBox(width: 12),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeStatus(TodayMedicationTask t) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: t.isTaken
            ? const Color(0xFF10B981).withValues(alpha: 0.1)
            : const Color(0xFF3B82F6).withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          t.isTaken ? Icons.check_rounded : Icons.access_time_rounded,
          color: t.isTaken ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
          size: 26,
        ),
      ),
    );
  }

  Widget _buildMedicineInfo(TodayMedicationTask t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              t.timeLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 8),
            if (t.isTaken)
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
          t.medicine.name,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1F2937),
            decoration: t.isTaken ? TextDecoration.lineThrough : null,
          ),
        ),
        if (t.medicine.dosage != null)
          Text(
            t.medicine.dosage!,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        if (_inventory != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 6,
              children: [
                if (_inventory!.isExpired)
                  _buildBadge('已过期', const Color(0xFFEF4444))
                else if (_inventory!.isExpiringSoon)
                  _buildBadge('即将过期', const Color(0xFFF59E0B)),
                if (_inventory!.isLow)
                  _buildBadge(
                    '仅剩${_inventory!.remainingCount}',
                    const Color(0xFFF59E0B),
                  )
                else if (_inventory!.totalQuantity > 0)
                  _buildBadge(
                    '余${_inventory!.remainingCount}/${_inventory!.totalQuantity}',
                    const Color(0xFF6B7280),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: widget.editKey,
          icon: const Icon(Icons.edit_note_rounded,
              color: Color(0xFF9CA3AF), size: 22),
          onPressed: widget.onEdit,
        ),
        IconButton(
          key: widget.deleteKey,
          icon: const Icon(Icons.delete_outline_rounded,
              color: Color(0xFFFCA5A5), size: 22),
          onPressed: widget.onDelete,
        ),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
