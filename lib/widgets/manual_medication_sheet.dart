import 'package:flutter/material.dart';
import '../models/medicine.dart';
import '../services/database_service.dart';

class ManualMedicationSheet extends StatefulWidget {
  final Medicine? medicine; // 如果有，则是编辑模式

  const ManualMedicationSheet({super.key, this.medicine});

  @override
  State<ManualMedicationSheet> createState() => _ManualMedicationSheetState();
}

class _ManualMedicationSheetState extends State<ManualMedicationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _noteController = TextEditingController();
  final List<ReminderTime> _times = [];
  bool _isSaving = false;

  bool get _isEditing => widget.medicine != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.medicine!.name;
      _dosageController.text = widget.medicine!.dosage ?? '';
      _noteController.text = widget.medicine!.note ?? '';
      widget.medicine!.reminders.load().then((_) {
        setState(() {
          for (var r in widget.medicine!.reminders) {
            _times.add(ReminderTime(r.hour, r.minute));
          }
        });
      });
    } else {
      _times.add(const ReminderTime(8, 30));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _addTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 30),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF3B82F6)),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        _times.add(ReminderTime(time.hour, time.minute));
        _times.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请至少设置一个提醒时间")));
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_isEditing) {
        await DatabaseService().updateMedicationManual(
          medicine: widget.medicine!,
          name: _nameController.text.trim(),
          dosage: _dosageController.text.trim(),
          note: _noteController.text.trim(),
          times: _times,
        );
      } else {
        await DatabaseService().saveMedicationManual(
          name: _nameController.text.trim(),
          dosage: _dosageController.text.trim(),
          note: _noteController.text.trim(),
          times: _times,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("保存失败: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              Text(_isEditing ? "修改药品" : "手动录入药品", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: "药品名称", hintText: "例如：阿莫西林", border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
                validator: (v) => (v == null || v.isEmpty) ? "请输入药品名称" : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dosageController,
                      decoration: InputDecoration(labelText: "服用剂量", hintText: "例如：2粒", border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(labelText: "医生叮嘱/备注", hintText: "例如：饭后半小时服用", border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              const Text("提醒时间", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._times.asMap().entries.map((entry) {
                    final time = entry.value;
                    return Chip(
                      label: Text("${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}"),
                      onDeleted: () => setState(() => _times.removeAt(entry.key)),
                      backgroundColor: const Color(0xFFEFF6FF),
                      labelStyle: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold),
                      deleteIconColor: const Color(0xFF3B82F6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide.none),
                    );
                  }),
                  ActionChip(
                    label: const Icon(Icons.add, size: 20),
                    onPressed: _addTime,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: _isSaving ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(_isEditing ? "保存修改" : "开启守护提醒", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("结束并删除提醒"),
                          content: Text("确定要结束「${widget.medicine!.name}」的每日提醒吗？相关用药记录也将被永久删除。"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("取消")),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true), 
                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)), 
                              child: const Text("确定结束")
                            ),
                          ],
                        ),
                      );
                      
                      if (confirmed == true && context.mounted) {
                        setState(() => _isSaving = true);
                        try {
                          // 核心：彻底删除，内部已包含 iOS 连环提醒和 Android 止震逻辑
                          await DatabaseService().deleteMedication(widget.medicine!);
                          if (context.mounted) Navigator.pop(context, true);
                        } catch (e) {
                          if (context.mounted) {
                            setState(() => _isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("操作失败: $e")));
                          }
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFFCA5A5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: _isSaving 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Color(0xFFEF4444), strokeWidth: 2))
                      : const Text("结束此药品提醒", style: TextStyle(color: Color(0xFFEF4444), fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
