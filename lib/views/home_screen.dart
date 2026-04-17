import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yao_ji_qing/views/settings_screen.dart';
import 'package:yao_ji_qing/views/stats_screen.dart';
import '../models/medicine.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import 'scanner_screen.dart';
import 'setup_guide_screen.dart';
import 'ai_chat_screen.dart';
import '../widgets/manual_medication_sheet.dart';
import '../widgets/firework_painter.dart';
import '../widgets/medication_task_card.dart';
import '../widgets/feature_guide_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  final NotificationService _notifService = NotificationService();
  final ImagePicker _picker = ImagePicker();

  // 定位锚点
  final GlobalKey _settingsKey = GlobalKey();
  final GlobalKey _progressKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _statsKey = GlobalKey();
  final GlobalKey _firstTaskKey = GlobalKey();
  final GlobalKey _editKey = GlobalKey();
  final GlobalKey _deleteKey = GlobalKey();

  static const List<String> _quotes = [
    "药到病除，心宽体健。☀️",
    "规律服药，是康复的基石。💪",
    "身体是革命的本钱，按时吃药哦。🌱",
    "但愿世间人无病，哪怕架上药生尘。✨",
    "早睡早起，适度运动，记得吃药。🏃‍♂️",
    "健康不是一切，但没有健康就没有一切。⚖️",
    "养生之道，莫先于食，莫急于药。🥣",
    "按时服药，爱惜自己，就是给家人最好的礼物。🧡",
    "每一粒药都是健康的种子，请按时播种。🌾",
    "心态平和，药效翻倍。🧘‍♂️",
  ];

  late String _currentQuote;
  List<TodayMedicationTask> _tasks = [];
  TodayMedicationTask? _guideTask;
  bool _isGuiding = false;
  late final List<FireworkParticle> _fireworkParticles;
  bool _isLoading = true;
  int _currentIndex = 0;

  late AnimationController _animationController;
  late AnimationController _celebrationController;
  OverlayEntry? _celebrationOverlay;
  int _celebrationRunId = 0;
  bool _isMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _currentQuote = _quotes[math.Random().nextInt(_quotes.length)];
    _initData();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      reverseDuration: const Duration(milliseconds: 400),
    );

    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _fireworkParticles = _buildFireworkParticles();

    // 启动引导逻辑
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await SetupGuideScreen.checkAndShow(context);
      
      final prefs = await SharedPreferences.getInstance();
      final bool needGuide = !(prefs.getBool('feature_guide_done_v5') ?? false);
      
      if (needGuide && mounted) {
        // 先构建模拟数据并强制刷新一次 UI
        setState(() {
          _isGuiding = true;
          _guideTask = TodayMedicationTask(
            medicine: Medicine()..name = "示例药品" ..dosage = "1粒",
            reminder: Reminder()..hour = 12 ..minute = 0,
            planTime: DateTime.now().copyWith(hour: 12, minute: 0),
            isTaken: false,
          );
        });
        
        await _loadTodayTasks();
        await Future.delayed(const Duration(milliseconds: 200)); // 等待渲染完成

        if (mounted) {
          await FeatureGuideOverlay.checkAndShow(
            context,
            settingsKey: _settingsKey,
            progressKey: _progressKey,
            fabKey: _fabKey,
            statsKey: _statsKey,
            firstTaskKey: _firstTaskKey,
            editKey: _editKey,
            deleteKey: _deleteKey,
            onFinish: () {
              if (mounted) {
                setState(() {
                  _isGuiding = false;
                  _guideTask = null;
                });
                _loadTodayTasks();
              }
            },
          );
        }
      }
    });
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

  Future<void> _handleCameraEntry() => _handlePickImage(ImageSource.camera);

  Future<void> _handleManualEntry() async {
    _toggleMenu();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ManualMedicationSheet(),
    );
    if (saved == true) {
      await _loadTodayTasks();
    }
  }

  Future<void> _handleEditMedication(TodayMedicationTask task) async {
    if (_isGuiding) return; // 引导期间禁用真实编辑
    await task.medicine.reminders.load();
    if (!mounted) return;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ManualMedicationSheet(medicine: task.medicine),
    );
    if (saved == true) {
      await _loadTodayTasks();
    }
  }

  Future<void> _handleDeleteMedication(TodayMedicationTask task) async {
    if (_isGuiding) return; // 引导期间禁用真实删除
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("删除用药"),
        content: Text("确定删除「${task.medicine.name}」及其提醒记录吗？"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("取消")),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
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
      if (_isGuiding && _guideTask != null) {
        _tasks = [_guideTask!, ...tasks];
      }
      _isLoading = false;
    });

    final hasPending = tasks.any((t) => !t.isTaken);
    if (tasks.isEmpty || !hasPending) {
      await _notifService.stopForegroundService();
    } else {
      await _notifService.startForegroundService();
      final nextTask = tasks.firstWhere((t) => !t.isTaken);
      await _notifService.updateForegroundService(
        title: "下一顿用药提醒",
        body: "${nextTask.medicine.name} ${nextTask.medicine.dosage ?? ''} (${nextTask.timeLabel})",
      );
    }
  }

  int get _totalTaskCount => _tasks.length;
  int get _takenTaskCount => _tasks.where((task) => task.isTaken).length;
  double get _progressValue => _totalTaskCount == 0 ? 0 : _takenTaskCount / _totalTaskCount;
  bool get _isTodayCompleted => _totalTaskCount > 0 && _takenTaskCount == _totalTaskCount;

  TodayMedicationTask? get _nextTask {
    for (final task in _tasks) {
      if (!task.isTaken) return task;
    }
    return null;
  }

  List<FireworkParticle> _buildFireworkParticles() {
    final random = math.Random(20260416);
    final particles = <FireworkParticle>[];
    const centers = [
      Offset(0.18, 0.18), Offset(0.50, 0.24), Offset(0.82, 0.18),
      Offset(0.25, 0.50), Offset(0.75, 0.54), Offset(0.50, 0.76),
    ];
    const colors = [Color(0xFFF97316), Color(0xFFFFD166), Color(0xFF10B981), Color(0xFF3B82F6), Color(0xFFEC4899)];

    for (final center in centers) {
      for (var i = 0; i < 28; i++) {
        particles.add(FireworkParticle(
          center: center,
          angle: (math.pi * 2 / 28) * i + random.nextDouble() * 0.18,
          distance: 90 + random.nextDouble() * 120,
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
    _celebrationOverlay = OverlayEntry(builder: (context) => _buildCompletionCelebrationOverlay());
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
      body: Stack(
        children: [
          _currentIndex == 0 ? _buildHomeBody() : const StatsScreen(),
          if (_isMenuOpen)
            GestureDetector(
              onTap: _toggleMenu,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) => Container(
                  color: Colors.black.withValues(alpha: 0.3 * _animationController.value),
                ),
              ),
            ),
          _buildArcMenuOverlay(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildMainFab(),
      bottomNavigationBar: _buildBottomAppBar(),
    );
  }

  Widget _buildHomeBody() {
    return SafeArea(
      bottom: false,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildHeader(),
                _buildProgressCard(),
                _buildMedListHeader(),
                _buildMedList(),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
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
          const SizedBox(width: 80),
          Expanded(
            child: Container(
              key: _statsKey,
              child: _buildNavItem(Icons.bar_chart_rounded, 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainFab() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _animationController.value * math.pi / 4,
          child: FloatingActionButton(
            key: _fabKey,
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
    if (!_isMenuOpen && _animationController.value == 0) return const SizedBox.shrink();
    
    return Positioned(
      bottom: 60,
      left: 0,
      right: 0,
      child: Center(
        child: SizedBox(
          width: 250,
          height: 250,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              _buildArcButton(
                index: 0,
                total: 3,
                angle: -4 * math.pi / 5,
                icon: Icons.camera_alt_rounded,
                color: const Color(0xFF3B82F6),
                onPressed: _handleCameraEntry,
              ),
              _buildArcButton(
                index: 1,
                total: 3,
                angle: -math.pi / 2,
                icon: Icons.psychology_rounded,
                color: const Color(0xFF8B5CF6),
                onPressed: () {
                  _toggleMenu();
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AIChatScreen()));
                },
              ),
              _buildArcButton(
                index: 2,
                total: 3,
                angle: -math.pi / 5,
                icon: Icons.edit_note_rounded,
                color: const Color(0xFF10B981),
                onPressed: _handleManualEntry,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArcButton({
    required int index,
    required int total,
    required double angle,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    const double distance = 110.0;
    final double start = (index / total) * 0.3;
    final double end = (start + 0.7).clamp(0.0, 1.0);
    
    final Animation<double> buttonAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(start, end, curve: Curves.easeOutBack),
      reverseCurve: Interval(1.0 - end, 1.0 - start, curve: Curves.easeInBack),
    );

    return AnimatedBuilder(
      animation: buttonAnimation,
      builder: (context, child) {
        final double v = buttonAnimation.value;
        if (v <= 0 && !_isMenuOpen) return const SizedBox.shrink();
        
        final double x = distance * math.cos(angle) * v;
        final double y = distance * math.sin(angle) * v;
        
        return Transform.translate(
          offset: Offset(x, y),
          child: Opacity(
            opacity: v.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.5 + 0.5 * v,
              child: Transform.rotate(
                angle: (1 - v) * 0.4,
                child: GestureDetector(
                  onTap: onPressed,
                  child: Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 8))
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
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
            Icon(icon, color: isActive ? const Color(0xFF3B82F6) : const Color(0xFFD1D5DB), size: 28),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 4, height: 4,
                decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_currentQuote, style: const TextStyle(color: Color(0xFF1F2937), fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(nextTask == null ? "今日提醒已完成" : "下次 ${nextTask.timeLabel} · ${nextTask.medicine.name}",
                      style: const TextStyle(color: Color(0xFF059669), fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                _loadTodayTasks();
              },
              child: Container(
                key: _settingsKey,
                width: 44, height: 44,
                decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
                child: const Icon(Icons.settings_rounded, color: Color(0xFF3B82F6), size: 24),
              ),
            ),
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
            key: _progressKey,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [BoxShadow(color: const Color(0xFF3B82F6).withValues(alpha: 0.4), blurRadius: 30, spreadRadius: -5, offset: const Offset(0, 15))]),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isCompleted ? "今日全部完成" : "今日用药进度", style: const TextStyle(color: Color(0xFFDBEAFE), fontSize: 14)),
                      const SizedBox(height: 12),
                      Text("$_takenTaskCount / $_totalTaskCount", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(_totalTaskCount == 0 ? "拍照添加药品后自动生成提醒" : isCompleted ? "点击卡片，再放一次烟花" : "还差 $remainingCount 次，加油哦！",
                          style: const TextStyle(color: Color(0xFFBFDBFE), fontSize: 12)),
                    ],
                  ),
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(width: 84, height: 84, child: CircularProgressIndicator(value: progress, strokeWidth: 10, strokeCap: StrokeCap.round, backgroundColor: const Color(0x33FFFFFF), valueColor: const AlwaysStoppedAnimation<Color>(Colors.white))),
                    Text(percentLabel, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
        child: Text("今日用药任务：", style: TextStyle(color: Color(0xFF1F2937), fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _handleMarkTaken(TodayMedicationTask task) async {
    if (_isGuiding) return;
    final pendingCount = _tasks.where((t) => !t.isTaken).length;
    await _dbService.markTaskTaken(task);
    await _loadTodayTasks();
    if (pendingCount == 1) _showCompletionCelebration();
  }

  Widget _buildMedList() {
    final pendingTasks = _tasks.where((task) => !task.isTaken).toList();
    if (pendingTasks.isEmpty) {
      final isAllDone = _tasks.isNotEmpty && _tasks.every((t) => t.isTaken);
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Center(
            child: Column(
              children: [
                Icon(isAllDone ? Icons.check_circle_outline_rounded : Icons.medication_liquid_rounded, size: 64, color: isAllDone ? const Color(0xFF10B981) : const Color(0xFFE5E7EB)),
                const SizedBox(height: 16),
                Text(isAllDone ? "您好，今天的药都吃完啦！🌟" : "今天暂时没有用药任务哦", style: TextStyle(color: isAllDone ? const Color(0xFF059669) : const Color(0xFF9CA3AF), fontSize: 16, fontWeight: isAllDone ? FontWeight.bold : FontWeight.normal)),
              ],
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
              key: index == 0 ? _firstTaskKey : null,
              editKey: index == 0 ? _editKey : null,
              deleteKey: index == 0 ? _deleteKey : null,
              task: task,
              onMarkTaken: () => _handleMarkTaken(task),
              onEdit: () => _handleEditMedication(task),
              onDelete: () => _handleDeleteMedication(task),
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
            return CustomPaint(painter: FireworkPainter(progress: _celebrationController.value, particles: _fireworkParticles), size: Size.infinite);
          },
        ),
      ),
    );
  }
}
