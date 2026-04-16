import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/medicine.dart';
import '../services/database_service.dart';
import 'scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  final ImagePicker _picker = ImagePicker();

  List<TodayMedicationTask> _tasks = [];
  late final List<_FireworkParticle> _fireworkParticles;
  bool _isLoading = true;
  int _currentIndex = 0;

  // 动效相关
  late AnimationController _animationController;
  late AnimationController _celebrationController;
  late Animation<double> _expandAnimation;
  OverlayEntry? _celebrationOverlay;
  int _celebrationRunId = 0;
  bool _isMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _initData();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _fireworkParticles = _buildFireworkParticles();
  }

  @override
  void dispose() {
    _celebrationOverlay?.remove();
    _animationController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Future<void> _handlePickImage(ImageSource source) async {
    _toggleMenu();
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null && mounted) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ScannerScreen(initialImage: image)),
      );
      if (result == true) _loadTodayTasks();
    }
  }

  Future<void> _handleManualEntry() async {
    _toggleMenu();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ManualMedicationSheet(),
    );
    if (saved == true) {
      await _loadTodayTasks();
    }
  }

  Future<void> _handleEditMedication(TodayMedicationTask task) async {
    await task.medicine.reminders.load();
    if (!mounted) return;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ManualMedicationSheet(medicine: task.medicine),
    );
    if (saved == true) {
      await _loadTodayTasks();
    }
  }

  Future<void> _handleDeleteMedication(TodayMedicationTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("删除用药"),
        content: Text("确定删除「${task.medicine.name}」及其提醒记录吗？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("取消"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text("删除"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _dbService.deleteMedication(task.medicine);
    await _loadTodayTasks();
  }

  Future<void> _initData() async {
    await _dbService.init();
    await _loadTodayTasks();
  }

  Future<void> _loadTodayTasks() async {
    final tasks = await _dbService.getTodayMedicationTasks();
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _isLoading = false;
    });
  }

  int get _totalTaskCount => _tasks.length;

  int get _takenTaskCount => _tasks.where((task) => task.isTaken).length;

  double get _progressValue =>
      _totalTaskCount == 0 ? 0 : _takenTaskCount / _totalTaskCount;

  bool get _isTodayCompleted =>
      _totalTaskCount > 0 && _takenTaskCount == _totalTaskCount;

  TodayMedicationTask? get _nextTask {
    for (final task in _tasks) {
      if (!task.isTaken) return task;
    }
    return null;
  }

  List<_FireworkParticle> _buildFireworkParticles() {
    final random = math.Random(20260416);
    final particles = <_FireworkParticle>[];
    const centers = [
      Offset(0.18, 0.18),
      Offset(0.50, 0.24),
      Offset(0.82, 0.18),
      Offset(0.25, 0.50),
      Offset(0.75, 0.54),
      Offset(0.50, 0.76),
    ];
    const colors = [
      Color(0xFFF97316),
      Color(0xFFFFD166),
      Color(0xFF10B981),
      Color(0xFF3B82F6),
      Color(0xFFEC4899),
    ];

    for (final center in centers) {
      for (var i = 0; i < 28; i++) {
        final angle = (math.pi * 2 / 28) * i + random.nextDouble() * 0.18;
        final distance = 90 + random.nextDouble() * 120;
        particles.add(_FireworkParticle(
          center: center,
          angle: angle,
          distance: distance,
          color: colors[(i + centers.indexOf(center)) % colors.length],
          delay: random.nextDouble() * 0.26,
          size: 3 + random.nextDouble() * 4,
        ));
      }
    }
    return particles;
  }

  void _showCompletionCelebration() {
    if (!mounted) return;
    final runId = ++_celebrationRunId;
    _celebrationController.stop();
    _celebrationController.forward(from: 0);
    _celebrationOverlay?.remove();
    _celebrationOverlay = OverlayEntry(
      builder: (context) => _buildCompletionCelebrationOverlay(),
    );
    Overlay.of(context).insert(_celebrationOverlay!);

    Future.delayed(const Duration(milliseconds: 2400), () {
      if (!mounted || runId != _celebrationRunId) return;
      _celebrationOverlay?.remove();
      _celebrationOverlay = null;
      _celebrationController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      // 允许 body 延伸到 BottomAppBar 下方，保证 Notch 效果
      body: Stack(
        children: [
          SafeArea(
            bottom: false, // 底部由 BottomAppBar 处理
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : CustomScrollView(
                    slivers: [
                      _buildHeader(),
                      _buildProgressCard(),
                      _buildMedListHeader(),
                      _buildMedList(),
                      const SliverToBoxAdapter(
                          child: SizedBox(height: 100)), // 底部占位
                    ],
                  ),
          ),
          // 1. 遮罩层
          if (_isMenuOpen)
            GestureDetector(
              onTap: _toggleMenu,
              child: Container(
                color: Colors.black.withValues(alpha: 0.2),
              ),
          ),
          // 2. 弧形弹出菜单（移入 Stack，不干扰 BottomAppBar 布局）
          _buildArcMenuOverlay(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildMainFab(),
      bottomNavigationBar: _buildBottomAppBar(),
    );
  }

  Widget _buildBottomAppBar() {
    return BottomAppBar(
      height: 70,
      color: Colors.white,
      padding: EdgeInsets.zero,
      notchMargin: 10,
      shape: const CircularNotchedRectangle(),
      child: Row(
        children: [
          Expanded(child: _buildNavItem(Icons.home_rounded, 0)),
          const SizedBox(width: 80), // 为 FAB 预留空间
          Expanded(child: _buildNavItem(Icons.bar_chart_rounded, 1)),
        ],
      ),
    );
  }

  Widget _buildMainFab() {
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _expandAnimation.value * math.pi / 4, // 旋转 45 度变成 X
          child: FloatingActionButton(
            onPressed: _toggleMenu,
            backgroundColor: const Color(0xFF3B82F6),
            shape: const CircleBorder(),
            elevation: 4,
            child: const Icon(Icons.add, color: Colors.white, size: 32),
          ),
        );
      },
    );
  }

  Widget _buildArcMenuOverlay() {
    return Positioned(
      bottom: 60, // 对应 FAB 的位置
      left: 0,
      right: 0,
      child: Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // 相机按钮
              _buildArcButton(
                angle: -math.pi / 5,
                icon: Icons.camera_alt_rounded,
                color: const Color(0xFF3B82F6),
                onPressed: () => _handlePickImage(ImageSource.camera),
              ),
              // 手动输入按钮
              _buildArcButton(
                angle: -math.pi / 2,
                icon: Icons.edit_note_rounded,
                color: const Color(0xFFF97316),
                onPressed: _handleManualEntry,
              ),
              // 相册按钮
              _buildArcButton(
                angle: -4 * math.pi / 5,
                icon: Icons.photo_library_rounded,
                color: const Color(0xFF10B981),
                onPressed: () => _handlePickImage(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArcButton({
    required double angle,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    const double distance = 90.0;
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        final double x = distance * math.cos(angle) * _expandAnimation.value;
        final double y = distance * math.sin(angle) * _expandAnimation.value;
        return Transform.translate(
          offset: Offset(x, y),
          child: Opacity(
            opacity: _expandAnimation.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: _expandAnimation.value,
              child: GestureDetector(
                onTap: onPressed,
                child: Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    bool isActive = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
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

  Widget _buildHeader() {
    final nextTask = _nextTask;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("早安，坤嫂",
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                const SizedBox(height: 4),
                const Text("今天状态不错！☀️",
                    style: TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    nextTask == null
                        ? "今日提醒已完成"
                        : "下次 ${nextTask.timeLabel} · ${nextTask.medicine.name}",
                    style: const TextStyle(
                        color: Color(0xFF059669),
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.person_outline_rounded,
                  color: Color(0xFF3B82F6)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    final progress = _progressValue;
    final remainingCount = _totalTaskCount - _takenTaskCount;
    final percentLabel = '${(progress * 100).round()}%';
    final isCompleted = _isTodayCompleted;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: GestureDetector(
          onTap: isCompleted ? _showCompletionCelebration : null,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                    blurRadius: 30,
                    spreadRadius: -5,
                    offset: const Offset(0, 15),
                  )
                ]),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isCompleted ? "今日全部完成" : "今日用药进度",
                          style: const TextStyle(
                              color: Color(0xFFDBEAFE), fontSize: 14)),
                      const SizedBox(height: 12),
                      Text("$_takenTaskCount / $_totalTaskCount",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                          _totalTaskCount == 0
                              ? "拍照添加药品后自动生成提醒"
                              : isCompleted
                                  ? "点击卡片，再放一次烟花"
                                  : "还差 $remainingCount 次，加油哦！",
                          style: const TextStyle(
                              color: Color(0xFFBFDBFE), fontSize: 12)),
                    ],
                  ),
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 84,
                      height: 84,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 10,
                        strokeCap: StrokeCap.round,
                        backgroundColor: const Color(0x33FFFFFF),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    Text(percentLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMedListHeader() {
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

  Widget _buildMedList() {
    final pendingTasks = _tasks.where((task) => !task.isTaken).toList();
    if (pendingTasks.isEmpty) {
      final emptyText = _tasks.isEmpty ? "还没有今日用药提醒" : "今日任务已全部完成";
      return SliverToBoxAdapter(
        child: Center(
            child: Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Column(
            children: [
              Icon(
                  _tasks.isEmpty
                      ? Icons.medication_liquid_rounded
                      : Icons.check_circle_rounded,
                  size: 64,
                  color: const Color(0xFFE5E7EB)),
              const SizedBox(height: 16),
              Text(emptyText,
                  style: const TextStyle(color: Color(0xFF9CA3AF))),
            ],
          ),
        )),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final task = pendingTasks[index];
            final med = task.medicine;
            return _SwipeMedicationTile(
              onEdit: () => _handleEditMedication(task),
              onDelete: () => _handleDeleteMedication(task),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ]),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.medication_rounded,
                          color: Color(0xFFF97316), size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(med.name,
                              style: const TextStyle(
                                  color: Color(0xFF1F2937),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text("${task.timeLabel} | ${med.dosage ?? '按医嘱'}",
                              style: const TextStyle(
                                  color: Color(0xFF6B7280), fontSize: 13)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final shouldCelebrate =
                            pendingTasks.length == 1;
                        await _dbService.markTaskTaken(task);
                        await _loadTodayTasks();
                        if (shouldCelebrate) {
                          _showCompletionCelebration();
                        }
                      },
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFEFF6FF),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("吃好了",
                            style: TextStyle(
                                color: Color(0xFF3B82F6),
                                fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: pendingTasks.length,
        ),
      ),
    );
  }

  Widget _buildCompletionCelebrationOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _celebrationController,
          builder: (context, child) {
            final value = _celebrationController.value;

            return CustomPaint(
              painter: _FireworkPainter(
                progress: value,
                particles: _fireworkParticles,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _FireworkParticle {
  const _FireworkParticle({
    required this.center,
    required this.angle,
    required this.distance,
    required this.color,
    required this.delay,
    required this.size,
  });

  final Offset center;
  final double angle;
  final double distance;
  final Color color;
  final double delay;
  final double size;
}

class _SwipeMedicationTile extends StatefulWidget {
  const _SwipeMedicationTile({
    required this.child,
    required this.onEdit,
    required this.onDelete,
  });

  final Widget child;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_SwipeMedicationTile> createState() => _SwipeMedicationTileState();
}

class _SwipeMedicationTileState extends State<_SwipeMedicationTile> {
  static const double _actionWidth = 144;
  double _dragOffset = 0;

  void _setOpen(bool isOpen) {
    setState(() => _dragOffset = isOpen ? -_actionWidth : 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final nextOffset =
            (_dragOffset + details.delta.dx).clamp(-_actionWidth, 0.0);
        setState(() => _dragOffset = nextOffset);
      },
      onHorizontalDragEnd: (_) => _setOpen(_dragOffset < -_actionWidth / 2),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Positioned(
            top: 0,
            right: 0,
            bottom: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Row(
                children: [
                  _SwipeActionButton(
                    color: const Color(0xFF3B82F6),
                    icon: Icons.edit_rounded,
                    label: "修改",
                    onTap: () {
                      _setOpen(false);
                      widget.onEdit();
                    },
                  ),
                  _SwipeActionButton(
                    color: const Color(0xFFEF4444),
                    icon: Icons.delete_rounded,
                    label: "删除",
                    onTap: () {
                      _setOpen(false);
                      widget.onDelete();
                    },
                  ),
                ],
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_dragOffset, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _SwipeActionButton extends StatelessWidget {
  const _SwipeActionButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: double.infinity,
        color: color,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualMedicationSheet extends StatefulWidget {
  const _ManualMedicationSheet({this.medicine});

  final Medicine? medicine;

  @override
  State<_ManualMedicationSheet> createState() => _ManualMedicationSheetState();
}

class _ManualMedicationSheetState extends State<_ManualMedicationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _noteController = TextEditingController();
  final _times = <TimeOfDay>[const TimeOfDay(hour: 8, minute: 30)];
  bool _isSaving = false;
  bool get _isEditing => widget.medicine != null;

  @override
  void initState() {
    super.initState();
    final medicine = widget.medicine;
    if (medicine == null) return;

    _nameController.text = medicine.name;
    _dosageController.text = medicine.dosage ?? '';
    _noteController.text = medicine.note ?? '';
    _times
      ..clear()
      ..addAll(medicine.reminders
          .map((reminder) =>
              TimeOfDay(hour: reminder.hour, minute: reminder.minute))
          .toList());
    if (_times.isEmpty) {
      _times.add(const TimeOfDay(hour: 8, minute: 30));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _times[index],
    );
    if (picked == null) return;
    setState(() => _times[index] = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final times = _times
        .map((time) => ReminderTime(time.hour, time.minute))
        .toList();
    final dosage = _dosageController.text.trim().isEmpty
        ? null
        : _dosageController.text.trim();
    final note =
        _noteController.text.trim().isEmpty ? null : _noteController.text.trim();

    if (_isEditing) {
      await DatabaseService().updateMedicationManual(
        medicine: widget.medicine!,
        name: _nameController.text.trim(),
        dosage: dosage,
        note: note,
        times: times,
      );
    } else {
      await DatabaseService().saveMedicationManual(
        name: _nameController.text.trim(),
        dosage: dosage,
        note: note,
        times: times,
      );
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    _isEditing ? "修改用药" : "手动添加用药",
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isEditing
                        ? "修改后会同步更新今日任务和每日提醒。"
                        : "填写药品信息后，会自动创建今日任务和每日提醒。",
                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  _buildTextField(
                    controller: _nameController,
                    label: "药品名称",
                    hint: "例如：阿莫西林胶囊",
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "请输入药品名称";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _dosageController,
                    label: "每次剂量",
                    hint: "例如：2粒 / 1片",
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _noteController,
                    label: "备注",
                    hint: "例如：饭后服用，忌酒",
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "提醒时间",
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _times.add(const TimeOfDay(hour: 12, minute: 30));
                          });
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text("添加时间"),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (var index = 0; index < _times.length; index++)
                        _buildTimeChip(index),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isEditing ? "保存修改" : "保存并开启提醒",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.4),
        ),
      ),
    );
  }

  Widget _buildTimeChip(int index) {
    return InkWell(
      onTap: () => _pickTime(index),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule_rounded,
                size: 16, color: Color(0xFF3B82F6)),
            const SizedBox(width: 6),
            Text(
              _formatTime(_times[index]),
              style: const TextStyle(
                color: Color(0xFF1D4ED8),
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_times.length > 1) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() => _times.removeAt(index)),
                child: const Icon(Icons.close_rounded,
                    size: 16, color: Color(0xFF60A5FA)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FireworkPainter extends CustomPainter {
  const _FireworkPainter({
    required this.progress,
    required this.particles,
  });

  final double progress;
  final List<_FireworkParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final particle in particles) {
      final localProgress =
          ((progress - particle.delay) / (1 - particle.delay)).clamp(0.0, 1.0);
      if (localProgress <= 0) continue;

      final eased = Curves.easeOutCubic.transform(localProgress);
      final fade = (1 - localProgress).clamp(0.0, 1.0);
      final center = Offset(
        particle.center.dx * size.width,
        particle.center.dy * size.height,
      );
      final offset = Offset(
        math.cos(particle.angle) * particle.distance * eased,
        math.sin(particle.angle) * particle.distance * eased +
            52 * localProgress * localProgress,
      );

      paint.color = particle.color.withValues(alpha: fade);
      canvas.drawCircle(center + offset, particle.size * fade + 1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FireworkPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.particles != particles;
  }
}
