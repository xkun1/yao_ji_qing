import 'package:flutter/material.dart';

import '../services/gemini_service.dart';

class ScannerResultEditor extends StatefulWidget {
  final MedicationInfo result;
  final ValueChanged<MedicationInfo> onSave;

  const ScannerResultEditor({
    super.key,
    required this.result,
    required this.onSave,
  });

  @override
  State<ScannerResultEditor> createState() => _ScannerResultEditorState();
}

class _ScannerResultEditorState extends State<ScannerResultEditor> {
  late final TextEditingController _nameController;
  late final TextEditingController _dosageController;
  late final TextEditingController _frequencyController;
  late final TextEditingController _timesController;
  late final TextEditingController _precautionsController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.result.name);
    _dosageController = TextEditingController(text: widget.result.dosage);
    _frequencyController = TextEditingController(text: widget.result.frequency.toString());
    _timesController = TextEditingController(text: widget.result.times.join(', '));
    _precautionsController = TextEditingController(text: widget.result.precautions);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    _timesController.dispose();
    _precautionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF22C55E)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '本地识别成功，可先编辑再保存',
                    style: TextStyle(
                      color: Color(0xFF166534),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildField('药名', _nameController, const Key('scanner_name_field')),
          _buildField('剂量', _dosageController, const Key('scanner_dosage_field')),
          _buildField(
            '频次',
            _frequencyController,
            const Key('scanner_frequency_field'),
            keyboardType: TextInputType.number,
            hintText: '每天次数，例如 3',
          ),
          _buildField(
            '时间点',
            _timesController,
            const Key('scanner_times_field'),
            hintText: '多个时间用逗号分隔，例如 08:00, 20:00',
          ),
          _buildField(
            '注意事项',
            _precautionsController,
            const Key('scanner_precautions_field'),
            maxLines: 3,
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              key: const Key('scanner_save_button'),
              onPressed: () {
                final frequency = int.tryParse(_frequencyController.text.trim()) ?? 0;
                final times = _timesController.text
                    .split(RegExp(r'[,，]'))
                    .map((value) => value.trim())
                    .where((value) => value.isNotEmpty)
                    .toList();

                widget.onSave(
                  MedicationInfo(
                    name: _nameController.text.trim(),
                    dosage: _dosageController.text.trim(),
                    frequency: frequency,
                    times: times,
                    precautions: _precautionsController.text.trim(),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                '确定，开启提醒',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    Key key, {
    TextInputType? keyboardType,
    String? hintText,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: key,
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hintText,
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
